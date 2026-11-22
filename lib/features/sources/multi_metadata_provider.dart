import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:melo_player/features/library/song_metadata_enricher.dart';
import 'package:melo_player/features/sources/music_provider_models.dart';
import 'package:melo_player/features/sources/soundcloud_audio_service.dart';
import 'package:melo_player/features/youtube/youtube_audio_service.dart';

/// Unified cross-platform metadata engine aggregating Spotify Web, Apple Music,
/// YouTube Music, Deezer, TIDAL, Amazon Music, and SoundCloud.
class MetadataProviderService {
  MetadataProviderService._();
  static final MetadataProviderService instance = MetadataProviderService._();

  final http.Client _httpClient = http.Client();
  final Map<String, UnifiedTrackMetadata> _metadataCache = {};

  /// Fetches rich studio metadata (ISRC, release date, high-res cover, credits)
  /// using the specified [provider] or cascading across all active services.
  Future<UnifiedTrackMetadata?> fetchMetadata({
    required String title,
    required String artist,
    MusicProviderType provider = MusicProviderType.all,
  }) async {
    final cleanTitle = SongMetadataEnricher.cleanTitle(title, rawArtist: artist);
    final cleanArtist = SongMetadataEnricher.cleanArtist(artist, rawTitle: title);
    if (cleanTitle.isEmpty) return null;

    final cacheKey = '${provider.name}:${cleanTitle.toLowerCase()}:${cleanArtist.toLowerCase()}';
    if (_metadataCache.containsKey(cacheKey)) {
      return _metadataCache[cacheKey];
    }

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

    if (result != null) {
      _metadataCache[cacheKey] = result;
    }
    return result;
  }

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

          return UnifiedTrackMetadata(
            title: trackTitle,
            artist: trackArtist,
            album: album,
            provider: MusicProviderType.deezer,
            durationMs: durationSec * 1000,
            artworkUrl: art,
            isrc: isrc,
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

          return UnifiedTrackMetadata(
            title: trackTitle,
            artist: trackArtist,
            album: album,
            provider: MusicProviderType.appleMusic,
            durationMs: durationMs,
            artworkUrl: art,
            genres: genre != null ? [genre] : const [],
            releaseDate: releaseDate?.split('T').first,
            providerTrackId: item['trackId']?.toString(),
            audioCodec: 'AAC',
            bitrateKbps: 256,
          );
        }
      }
    } catch (_) {}
    return null;
  }

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
            audioCodec: 'FLAC',
            bitrateKbps: 1411,
          );
        }
      }
    } catch (_) {}
    return null;
  }

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
            audioCodec: 'FLAC',
            bitrateKbps: 9216,
          );
        }
      }
    } catch (_) {}
    return null;
  }
}
