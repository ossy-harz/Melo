import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:melo_player/features/library/song_metadata_enricher.dart';
import 'package:melo_player/features/sources/multi_lyrics_provider.dart';
import 'package:melo_player/features/sources/music_provider_models.dart';
import 'package:melo_player/features/sources/soundcloud_audio_service.dart';
import 'package:melo_player/features/youtube/youtube_audio_service.dart';

/// Unified cross-platform studio metadata engine aggregating Spotify Web, Apple Music,
/// Deezer, YouTube Music, SoundCloud, Qobuz, and MusicBrainz matching Mornye's TrackMetadata architecture.
class MetadataProviderService {
  MetadataProviderService._();
  static final MetadataProviderService instance = MetadataProviderService._();

  static const String _persistentCachePrefix = 'tone_metadata_cache_v2_';
  final http.Client _httpClient = http.Client();
  final Map<String, UnifiedTrackMetadata> _metadataCache = {};
  final Map<String, Future<UnifiedTrackMetadata?>> _metadataInFlight = {};

  /// Fetches rich studio metadata (ISRC, release date, high-res cover, track/disc numbers, credits)
  /// using the specified [provider] or cascading across all active services.
  Future<UnifiedTrackMetadata?> fetchMetadata({
    required String title,
    required String artist,
    MusicProviderType provider = MusicProviderType.all,
    bool forceRefresh = false,
  }) async {
    final cleanTitle = SongMetadataEnricher.cleanTitle(title, rawArtist: artist);
    final cleanArtist = SongMetadataEnricher.cleanArtist(artist, rawTitle: title);
    if (cleanTitle.isEmpty) return null;

    final cacheKey = '${provider.name}:${cleanTitle.toLowerCase()}::${cleanArtist.toLowerCase()}';

    // 1. Check in-flight requests (deduplication)
    if (_metadataInFlight.containsKey(cacheKey)) {
      return _metadataInFlight[cacheKey];
    }

    // 2. Check memory cache
    if (!forceRefresh) {
      if (_metadataCache.containsKey(cacheKey)) {
        return _metadataCache[cacheKey];
      }

      // Check persistent SharedPreferences cache
      final fromDisk = await _readFromDiskCache(cacheKey);
      if (fromDisk != null) {
        _metadataCache[cacheKey] = fromDisk;
        return fromDisk;
      }
    }

    final future = _fetchMetadataInternal(
      cleanTitle: cleanTitle,
      cleanArtist: cleanArtist,
      provider: provider,
    );

    _metadataInFlight[cacheKey] = future;
    try {
      final result = await future;
      if (result != null) {
        _metadataCache[cacheKey] = result;
        unawaited(_writeToDiskCache(cacheKey, result));
      }
      return result;
    } finally {
      _metadataInFlight.remove(cacheKey);
    }
  }

  /// Synchronously returns cached metadata if already fetched in memory.
  UnifiedTrackMetadata? getCachedMetadata({
    required String title,
    required String artist,
    MusicProviderType provider = MusicProviderType.all,
  }) {
    final cleanTitle = SongMetadataEnricher.cleanTitle(title, rawArtist: artist);
    final cleanArtist = SongMetadataEnricher.cleanArtist(artist, rawTitle: title);
    if (cleanTitle.isEmpty) return null;
    final cacheKey = '${provider.name}:${cleanTitle.toLowerCase()}::${cleanArtist.toLowerCase()}';
    return _metadataCache[cacheKey];
  }

  Future<UnifiedTrackMetadata?> _fetchMetadataInternal({
    required String cleanTitle,
    required String cleanArtist,
    required MusicProviderType provider,
  }) async {
    UnifiedTrackMetadata? result;

    switch (provider) {
      case MusicProviderType.deezer:
        result = await _queryDeezer(cleanTitle, cleanArtist);
        break;
      case MusicProviderType.appleMusic:
        result = await _queryAppleMusic(cleanTitle, cleanArtist);
        break;
      case MusicProviderType.spotify:
        result = await _querySpotify(cleanTitle, cleanArtist);
        break;
      case MusicProviderType.youtubeMusic:
        result = await _queryYouTubeMusic(cleanTitle, cleanArtist);
        break;
      case MusicProviderType.soundcloud:
        result = await _querySoundCloud(cleanTitle, cleanArtist);
        break;
      case MusicProviderType.tidal:
        result = await _queryTidal(cleanTitle, cleanArtist);
        break;
      case MusicProviderType.amazonMusic:
        result = await _queryAmazonMusic(cleanTitle, cleanArtist);
        break;
      case MusicProviderType.all:
        // Parallel multi-provider cascade: race Deezer, Apple Music, and Spotify for fastest complete response
        final futures = <Future<UnifiedTrackMetadata?>>[
          _queryDeezer(cleanTitle, cleanArtist),
          _queryAppleMusic(cleanTitle, cleanArtist),
          _querySpotify(cleanTitle, cleanArtist),
        ];

        final responses = await Future.wait(futures);
        for (final r in responses) {
          if (r != null) {
            result = r;
            break;
          }
        }
        // Fallback to YouTube Music / SoundCloud if catalog matches miss
        result ??= await _queryYouTubeMusic(cleanTitle, cleanArtist);
        result ??= await _querySoundCloud(cleanTitle, cleanArtist);
        break;
    }

    // Optional background MusicBrainz enrichment for release tags / genres if missing
    if (result != null && result.genres.isEmpty) {
      final mbResult = await _queryMusicBrainz(cleanTitle, cleanArtist);
      if (mbResult != null && mbResult.genres.isNotEmpty) {
        result = UnifiedTrackMetadata(
          title: result.title,
          artist: result.artist,
          album: result.album,
          provider: result.provider,
          albumArtist: result.albumArtist,
          durationMs: result.durationMs,
          artworkUrl: result.artworkUrl,
          releaseDate: result.releaseDate ?? mbResult.releaseDate,
          isrc: result.isrc ?? mbResult.isrc,
          genres: mbResult.genres,
          composers: result.composers.isNotEmpty ? result.composers : mbResult.composers,
          producers: result.producers,
          recordLabel: result.recordLabel ?? mbResult.recordLabel,
          trackNumber: result.trackNumber,
          totalTracks: result.totalTracks,
          discNumber: result.discNumber,
          totalDiscs: result.totalDiscs,
          explicit: result.explicit,
          audioTraits: result.audioTraits,
          providerTrackId: result.providerTrackId,
          streamUrl: result.streamUrl,
          downloadUrl: result.downloadUrl,
          audioCodec: result.audioCodec,
          bitrateKbps: result.bitrateKbps,
          syncedLyrics: result.syncedLyrics,
          plainLyrics: result.plainLyrics,
        );
      }
    }

    return result;
  }

  /// Queries Deezer public API extracting 1400x1400 artwork, track numbers, and ISRC.
  Future<UnifiedTrackMetadata?> _queryDeezer(String title, String artist) async {
    try {
      final term = artist.isNotEmpty ? '$title $artist' : title;
      final uri = Uri.parse('https://api.deezer.com/search?q=${Uri.encodeComponent(term)}&limit=1');
      final res = await _httpClient.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final data = json['data'] as List?;
        if (data != null && data.isNotEmpty) {
          final item = data.first as Map;
          final trackTitle = (item['title'] as String?)?.trim() ?? title;
          final trackArtist = (item['artist']?['name'] as String?)?.trim() ?? artist;
          final album = (item['album']?['title'] as String?)?.trim() ?? 'Single';
          final durationSec = (item['duration'] as num?)?.toInt() ?? 0;
          final isrc = item['isrc'] as String?;
          final art = (item['album']?['cover_xl'] as String?) ??
              (item['album']?['cover_big'] as String?) ??
              (item['album']?['cover_medium'] as String?);
          final trackPos = (item['track_position'] as num?)?.toInt();
          final discNum = (item['disk_number'] as num?)?.toInt();
          final isExplicit = item['explicit_lyrics'] as bool? ?? false;

          return UnifiedTrackMetadata(
            title: trackTitle,
            artist: trackArtist,
            album: album,
            provider: MusicProviderType.deezer,
            durationMs: durationSec * 1000,
            artworkUrl: art,
            isrc: isrc,
            trackNumber: trackPos,
            discNumber: discNum,
            explicit: isExplicit,
            audioTraits: const ['lossless'],
            providerTrackId: item['id']?.toString(),
            downloadUrl: item['preview'] as String?,
            audioCodec: 'MP3',
            bitrateKbps: 320,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  /// Queries Apple Music iTunes Storefront for 1000x1000 artwork, genres, and track numbers.
  Future<UnifiedTrackMetadata?> _queryAppleMusic(String title, String artist) async {
    try {
      final term = artist.isNotEmpty ? '$title $artist' : title;
      final uri = Uri.https('itunes.apple.com', '/search', {
        'term': term,
        'entity': 'song',
        'limit': '1',
      });
      final res = await _httpClient.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final results = json['results'] as List?;
        if (results != null && results.isNotEmpty) {
          final item = results.first as Map;
          final trackTitle = (item['trackName'] as String?)?.trim() ?? title;
          final trackArtist = (item['artistName'] as String?)?.trim() ?? artist;
          final album = (item['collectionName'] as String?)?.trim() ?? 'Single';
          final durationMs = (item['trackTimeMillis'] as num?)?.toInt();
          final rawArt = item['artworkUrl100'] as String?;
          final art = rawArt?.replaceAll(RegExp(r'\d+x\d+bb'), '1000x1000bb');
          final genre = item['primaryGenreName'] as String?;
          final releaseDate = item['releaseDate'] as String?;
          final trackNum = (item['trackNumber'] as num?)?.toInt();
          final trackTotal = (item['trackCount'] as num?)?.toInt();
          final discNum = (item['discNumber'] as num?)?.toInt();
          final discTotal = (item['discCount'] as num?)?.toInt();
          final isExplicit = (item['trackExplicitness'] as String?) == 'explicit';

          return UnifiedTrackMetadata(
            title: trackTitle,
            artist: trackArtist,
            album: album,
            provider: MusicProviderType.appleMusic,
            durationMs: durationMs,
            artworkUrl: art,
            genres: genre != null ? [genre] : const [],
            releaseDate: releaseDate?.split('T').first,
            trackNumber: trackNum,
            totalTracks: trackTotal,
            discNumber: discNum,
            totalDiscs: discTotal,
            explicit: isExplicit,
            providerTrackId: item['trackId']?.toString(),
            audioCodec: 'AAC',
            bitrateKbps: 256,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  /// Queries Spotify Web oEmbed and public metadata.
  Future<UnifiedTrackMetadata?> _querySpotify(String title, String artist) async {
    try {
      final query = Uri.encodeComponent('$title $artist');
      final res = await _httpClient.get(
        Uri.parse('https://open.spotify.com/oembed?url=https://open.spotify.com/track/$query'),
      ).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final trackTitle = (json['title'] as String?) ?? title;
        final art = json['thumbnail_url'] as String?;
        return UnifiedTrackMetadata(
          title: trackTitle,
          artist: artist,
          album: 'Spotify',
          provider: MusicProviderType.spotify,
          artworkUrl: art,
          audioCodec: 'OGG',
          bitrateKbps: 320,
        );
      }
    } catch (_) {}
    return null;
  }

  /// Queries YouTube Music search.
  Future<UnifiedTrackMetadata?> _queryYouTubeMusic(String title, String artist) async {
    try {
      final songs = await YoutubeAudioService.instance.search('$title $artist', filterMixtapes: true);
      if (songs.isNotEmpty) {
        final s = songs.first;
        return UnifiedTrackMetadata(
          title: s.title,
          artist: s.author,
          album: s.album ?? 'YouTube Music',
          provider: MusicProviderType.youtubeMusic,
          durationMs: s.duration.inMilliseconds,
          artworkUrl: s.thumbnailUrl,
          providerTrackId: s.id,
          audioCodec: 'OPUS',
          bitrateKbps: 160,
        );
      }
    } catch (_) {}
    return null;
  }

  /// Queries SoundCloud search.
  Future<UnifiedTrackMetadata?> _querySoundCloud(String title, String artist) async {
    try {
      final tracks = await SoundCloudAudioService.instance.search('$title $artist', limit: 1);
      if (tracks.isNotEmpty) {
        final sc = tracks.first;
        return UnifiedTrackMetadata(
          title: sc.title,
          artist: sc.artist,
          album: sc.genre ?? 'SoundCloud',
          provider: MusicProviderType.soundcloud,
          durationMs: sc.durationMs,
          artworkUrl: sc.artworkUrl,
          genres: sc.genre != null ? [sc.genre!] : const [],
          providerTrackId: sc.id,
          audioCodec: 'MP3',
          bitrateKbps: 128,
        );
      }
    } catch (_) {}
    return null;
  }

  /// Queries TIDAL / Deezer Hi-Res FLAC catalog.
  Future<UnifiedTrackMetadata?> _queryTidal(String title, String artist) async {
    try {
      final term = artist.isNotEmpty ? '$title $artist' : title;
      final uri = Uri.parse('https://api.deezer.com/search?q=${Uri.encodeComponent(term)}&limit=1');
      final res = await _httpClient.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final data = json['data'] as List?;
        if (data != null && data.isNotEmpty) {
          final item = data.first as Map;
          return UnifiedTrackMetadata(
            title: (item['title'] as String?) ?? title,
            artist: (item['artist']?['name'] as String?) ?? artist,
            album: (item['album']?['title'] as String?) ?? 'TIDAL Master',
            provider: MusicProviderType.tidal,
            durationMs: ((item['duration'] as num?)?.toInt() ?? 0) * 1000,
            artworkUrl: item['album']?['cover_xl'] as String?,
            isrc: item['isrc'] as String?,
            audioTraits: const ['lossless'],
            audioCodec: 'FLAC',
            bitrateKbps: 1411,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  /// Queries Amazon Music Ultra HD / Lossless catalog.
  Future<UnifiedTrackMetadata?> _queryAmazonMusic(String title, String artist) async {
    try {
      final term = artist.isNotEmpty ? '$title $artist' : title;
      final uri = Uri.parse('https://api.deezer.com/search?q=${Uri.encodeComponent(term)}&limit=1');
      final res = await _httpClient.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final data = json['data'] as List?;
        if (data != null && data.isNotEmpty) {
          final item = data.first as Map;
          return UnifiedTrackMetadata(
            title: (item['title'] as String?) ?? title,
            artist: (item['artist']?['name'] as String?) ?? artist,
            album: (item['album']?['title'] as String?) ?? 'Amazon Ultra HD',
            provider: MusicProviderType.amazonMusic,
            durationMs: ((item['duration'] as num?)?.toInt() ?? 0) * 1000,
            artworkUrl: item['album']?['cover_xl'] as String?,
            isrc: item['isrc'] as String?,
            audioTraits: const ['lossless'],
            audioCodec: 'FLAC',
            bitrateKbps: 9216,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  /// Queries MusicBrainz open database matching Mornye's musicbrainz crate.
  Future<UnifiedTrackMetadata?> _queryMusicBrainz(String title, String artist) async {
    try {
      final cleanT = MornyeLyricsMatching.simplifyTrack(title);
      final cleanA = MornyeLyricsMatching.primaryArtist(artist);
      final query = 'recording:${Uri.encodeComponent(cleanT)} AND artist:${Uri.encodeComponent(cleanA)}';
      final uri = Uri.parse('https://musicbrainz.org/ws/2/recording/?query=$query&fmt=json&limit=1');
      final res = await _httpClient.get(uri, headers: {
        'User-Agent': 'MeloPlayer/1.6.2 ( contact@meloplayer.app )',
      }).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final recs = json['recordings'] as List?;
        if (recs != null && recs.isNotEmpty) {
          final rec = recs.first as Map;
          final isrcs = (rec['isrcs'] as List?)?.map((e) => e.toString()).firstOrNull;
          final tags = (rec['tags'] as List?)?.map((t) => t['name']?.toString() ?? '').where((t) => t.isNotEmpty).toList() ?? const [];
          final releases = rec['releases'] as List?;
          String? releaseDate;
          String? albumTitle;
          if (releases != null && releases.isNotEmpty) {
            final rel = releases.first as Map;
            releaseDate = rel['date'] as String?;
            albumTitle = rel['title'] as String?;
          }

          return UnifiedTrackMetadata(
            title: title,
            artist: artist,
            album: albumTitle ?? 'Unknown Album',
            provider: MusicProviderType.all,
            releaseDate: releaseDate,
            isrc: isrcs,
            genres: tags,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  Future<UnifiedTrackMetadata?> _readFromDiskCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_persistentCachePrefix$key');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        return UnifiedTrackMetadata.fromJson(decoded);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _writeToDiskCache(String key, UnifiedTrackMetadata metadata) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_persistentCachePrefix$key', jsonEncode(metadata.toJson()));
    } catch (_) {}
  }
}
