import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:melo_player/features/library/music_library.dart';
import 'package:melo_player/features/player/lyrics_repository.dart';

class EnrichedSongMetadata {
  const EnrichedSongMetadata({
    required this.title,
    required this.artist,
    required this.album,
    this.year,
    this.genre,
    this.trackNumber,
    this.durationMs,
    this.artworkUrl,
    this.localArtworkUri,
    this.lyricsContent,
    this.parsedLyrics,
  });

  final String title;
  final String artist;
  final String album;
  final int? year;
  final String? genre;
  final int? trackNumber;
  final int? durationMs;
  final String? artworkUrl;
  final String? localArtworkUri;
  final String? lyricsContent;
  final SongLyrics? parsedLyrics;
}

class SongMetadataEnricher {
  SongMetadataEnricher._();
  static final SongMetadataEnricher instance = SongMetadataEnricher._();

  /// Cleans noisy video/filename suffixes from a track title so metadata and
  /// lyrics APIs match accurately.
  static String cleanTitle(String rawTitle, {String? rawArtist}) {
    var cleaned = rawTitle.trim();
    // Strip common file extensions if present
    cleaned = cleaned.replaceFirst(
      RegExp(r'\.(mp3|m4a|flac|wav|ogg|opus|aac|webm)$', caseSensitive: false),
      '',
    );
    // Strip leading track numbers like "01 - " or "01. "
    cleaned = cleaned.replaceFirst(RegExp(r'^\d{1,3}\s*[-._]\s*'), '');
    // Strip parenthetical/bracketed video noise
    cleaned = cleaned.replaceAll(
      RegExp(
        r'[\(\[](?:official\s*(?:music\s*)?(?:video|audio|lyric\s*video|visualizer)|lyrics?|audio|hd|hq|4k|remastered.*?|live.*?)[\)\]]',
        caseSensitive: false,
      ),
      '',
    );
    // If title is "Artist - Title" and matches artist, split it
    if (cleaned.contains(' - ')) {
      final parts = cleaned.split(' - ');
      if (parts.length == 2) {
        final left = parts[0].trim();
        final right = parts[1].trim();
        if (rawArtist == null ||
            rawArtist.trim().isEmpty ||
            rawArtist.toLowerCase() == 'unknown artist' ||
            rawArtist.toLowerCase() == 'on-device audio' ||
            left.toLowerCase() == rawArtist.trim().toLowerCase()) {
          cleaned = right;
        }
      }
    }
    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Extracts artist from "Artist - Title" if the artist tag is missing/unknown.
  static String cleanArtist(String? rawArtist, {String? rawTitle}) {
    var artist = (rawArtist ?? '').trim();
    artist = artist.replaceFirst(RegExp(r'\s*-\s*Topic$', caseSensitive: false), '').trim();
    if (artist.isEmpty ||
        artist.toLowerCase() == 'unknown artist' ||
        artist.toLowerCase() == 'on-device audio' ||
        artist.toLowerCase() == 'youtube') {
      if (rawTitle != null && rawTitle.contains(' - ')) {
        final parts = rawTitle.split(' - ');
        if (parts.length == 2 && parts[0].trim().isNotEmpty) {
          return parts[0].trim();
        }
      }
      return '';
    }
    return artist;
  }

  /// Normalizes a (title, artist) pair into a canonical deduplication key.
  static String canonicalSongKey(String title, String? artist) {
    final cTitle = cleanTitle(title, rawArtist: artist)
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final cArtist = cleanArtist(artist, rawTitle: title)
        .toLowerCase()
        .replaceAll(RegExp(r'\s*(?:feat\.?|ft\.?|&|,)\s*.*$'), '')
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return '$cTitle|$cArtist';
  }

  /// Fetches complete studio metadata, high-res 1000x1000 album artwork, and
  /// synchronized lyrics for any song.
  Future<EnrichedSongMetadata> fetchFullMetadata({
    required String title,
    String? artist,
    String? album,
    int? durationMs,
    String? fallbackArtworkUrl,
    Directory? artworkDirectory,
    String? trackIdForCache,
  }) async {
    final cleanedTitle = cleanTitle(title, rawArtist: artist);
    final cleanedArtist = cleanArtist(artist, rawTitle: title);

    String resolvedTitle = cleanedTitle.isNotEmpty ? cleanedTitle : title.trim();
    String resolvedArtist =
        cleanedArtist.isNotEmpty ? cleanedArtist : (artist?.trim() ?? 'Unknown artist');
    String resolvedAlbum = (album != null &&
            album.trim().isNotEmpty &&
            album.trim().toLowerCase() != 'unknown album' &&
            album.trim().toLowerCase() != 'youtube music' &&
            album.trim().toLowerCase() != 'single')
        ? album.trim()
        : '';
    int? resolvedYear;
    String? resolvedGenre;
    int? resolvedTrackNumber;
    int? resolvedDurationMs = durationMs;
    String? resolvedArtworkUrl = fallbackArtworkUrl;

    // 1. Query iTunes Search API + Deezer API in parallel for studio tags & 1000x1000 cover art
    final searchTerm = cleanedArtist.isNotEmpty
        ? '$cleanedTitle $cleanedArtist'
        : cleanedTitle;

    try {
      final results = await Future.wait([
        _queryItunesCatalog(searchTerm, cleanedTitle, cleanedArtist),
        _queryDeezerCatalog(searchTerm, cleanedTitle, cleanedArtist),
      ]);

      final itunes = results[0];
      final deezer = results[1];
      final best = itunes ?? deezer;

      if (best != null) {
        if ((best['title'] as String?)?.isNotEmpty == true) {
          resolvedTitle = best['title']! as String;
        }
        if ((best['artist'] as String?)?.isNotEmpty == true) {
          resolvedArtist = best['artist']! as String;
        }
        if (resolvedAlbum.isEmpty &&
            (best['album'] as String?)?.isNotEmpty == true) {
          resolvedAlbum = best['album']! as String;
        }
        resolvedYear = best['year'] as int? ?? resolvedYear;
        resolvedGenre = best['genre'] as String? ?? resolvedGenre;
        resolvedTrackNumber = best['trackNumber'] as int? ?? resolvedTrackNumber;
        if ((resolvedDurationMs == null || resolvedDurationMs <= 0) &&
            best['durationMs'] is int) {
          resolvedDurationMs = best['durationMs'] as int;
        }
        if ((best['artworkUrl'] as String?)?.isNotEmpty == true) {
          resolvedArtworkUrl = best['artworkUrl'] as String;
        }
      }
    } catch (e) {
      debugPrint('Catalog metadata lookup error: $e');
    }

    if (resolvedAlbum.isEmpty) {
      resolvedAlbum = (album != null && album.trim().isNotEmpty)
          ? album.trim()
          : 'Single';
    }

    // 2. Download high-res artwork to local disk if directory is provided
    String? localArtworkUri = resolvedArtworkUrl;
    if (resolvedArtworkUrl != null &&
        resolvedArtworkUrl.startsWith('http') &&
        artworkDirectory != null) {
      try {
        final artRes = await http
            .get(Uri.parse(resolvedArtworkUrl))
            .timeout(const Duration(seconds: 8));
        if (artRes.statusCode == 200 && artRes.bodyBytes.isNotEmpty) {
          final safeKey = (trackIdForCache ?? '${resolvedArtist}_$resolvedTitle')
              .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
          final artFile = File(p.join(artworkDirectory.path, '${safeKey}_art.jpg'));
          await artFile.writeAsBytes(artRes.bodyBytes, flush: true);
          localArtworkUri = Uri.file(artFile.path).toString();
        }
      } catch (e) {
        debugPrint('Artwork download fallback: $e');
      }
    }

    // 3. Fetch synchronized (or plain) lyrics from LRCLIB
    String? lyricsContent;
    SongLyrics? parsedLyrics;
    try {
      lyricsContent = await _fetchLrcLibLyrics(
        title: resolvedTitle,
        artist: resolvedArtist,
        album: resolvedAlbum,
        durationSeconds:
            resolvedDurationMs != null && resolvedDurationMs > 0
                ? (resolvedDurationMs / 1000).round()
                : null,
      );
      if (lyricsContent != null && lyricsContent.trim().isNotEmpty) {
        parsedLyrics = SongLyrics.parse(
          synchronized: lyricsContent,
          plain: lyricsContent,
        );
      }
    } catch (e) {
      debugPrint('Lyrics enrichment lookup error: $e');
    }

    return EnrichedSongMetadata(
      title: resolvedTitle,
      artist: resolvedArtist,
      album: resolvedAlbum,
      year: resolvedYear,
      genre: resolvedGenre,
      trackNumber: resolvedTrackNumber,
      durationMs: resolvedDurationMs,
      artworkUrl: resolvedArtworkUrl,
      localArtworkUri: localArtworkUri,
      lyricsContent: lyricsContent,
      parsedLyrics: parsedLyrics,
    );
  }

  /// Enriches an existing track or active [MediaItem] in [MusicLibrary] and saves
  /// its artwork, tags, and synchronized lyrics for offline use.
  Future<EnrichedSongMetadata> enrichAndSaveForMediaItem({
    required MediaItem item,
    MusicLibrary? library,
  }) async {
    final enriched = await fetchFullMetadata(
      title: item.title,
      artist: item.artist,
      album: item.album,
      durationMs: item.duration?.inMilliseconds,
      fallbackArtworkUrl: item.artUri?.toString(),
      artworkDirectory: library?.musicDirectory,
      trackIdForCache: item.id,
    );

    // Save lyrics into LyricsRepository cache for this MediaItem ID
    if (enriched.lyricsContent != null &&
        enriched.lyricsContent!.trim().isNotEmpty) {
      await LyricsRepository.cacheLyricsForId(item.id, enriched.lyricsContent!);

      // Also write .lrc next to local audio file if applicable
      if ((item.id.contains('/') || item.id.contains(r'\')) &&
          !item.id.startsWith('http') &&
          !item.id.startsWith('youtube:') &&
          !item.id.startsWith('spotify:')) {
        try {
          final dot = item.id.lastIndexOf('.');
          final lrcPath =
              dot > 0 ? '${item.id.substring(0, dot)}.lrc' : '${item.id}.lrc';
          await File(lrcPath).writeAsString(enriched.lyricsContent!, flush: true);
        } catch (_) {}
      }
    }

    // Update the track in MusicLibrary if it belongs to the library
    if (library != null) {
      final trackId = item.extras?['libraryId'] as String? ?? item.id;
      final existing = library.trackForId(trackId) ??
          library.findMatchingLocalTrack(
            title: item.title,
            artist: item.artist,
            path: item.id,
          );
      if (existing != null) {
        await library.updateTrackEnrichedMetadata(
          existing.id,
          title: enriched.title,
          artist: enriched.artist,
          album: enriched.album,
          year: enriched.year,
          genre: enriched.genre,
          trackNumber: enriched.trackNumber,
          artworkUri: enriched.localArtworkUri ?? enriched.artworkUrl,
        );
        if (enriched.lyricsContent != null) {
          await LyricsRepository.cacheLyricsForId(
            existing.id,
            enriched.lyricsContent!,
          );
          await LyricsRepository.cacheLyricsForId(
            existing.path,
            enriched.lyricsContent!,
          );
        }
      }
    }

    return enriched;
  }

  Future<Map<String, Object?>?> _queryItunesCatalog(
    String searchTerm,
    String targetTitle,
    String targetArtist,
  ) async {
    try {
      final uri = Uri.https('itunes.apple.com', '/search', {
        'term': searchTerm,
        'entity': 'song',
        'limit': '5',
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final results = (data['results'] as List?)?.cast<Map<String, dynamic>>();
      if (results == null || results.isEmpty) return null;

      Map<String, dynamic> chosen = results.first;
      for (final item in results) {
        final tName = (item['trackName'] as String? ?? '').toLowerCase();
        final aName = (item['artistName'] as String? ?? '').toLowerCase();
        if (tName.contains(targetTitle.toLowerCase()) &&
            (targetArtist.isEmpty ||
                aName.contains(targetArtist.toLowerCase()))) {
          chosen = item;
          break;
        }
      }

      final rawArt = chosen['artworkUrl100'] as String?;
      final hiResArt = rawArt?.replaceAll('100x100bb', '1000x1000bb');
      final releaseDate = chosen['releaseDate'] as String?;
      final year = releaseDate != null && releaseDate.length >= 4
          ? int.tryParse(releaseDate.substring(0, 4))
          : null;

      return {
        'title': chosen['trackName'] as String?,
        'artist': chosen['artistName'] as String?,
        'album': chosen['collectionName'] as String?,
        'year': year,
        'genre': chosen['primaryGenreName'] as String?,
        'trackNumber': (chosen['trackNumber'] as num?)?.toInt(),
        'durationMs': (chosen['trackTimeMillis'] as num?)?.toInt(),
        'artworkUrl': hiResArt ?? rawArt,
      };
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, Object?>?> _queryDeezerCatalog(
    String searchTerm,
    String targetTitle,
    String targetArtist,
  ) async {
    try {
      final uri = Uri.https('api.deezer.com', '/search', {
        'q': searchTerm,
        'limit': '5',
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final results = (data['data'] as List?)?.cast<Map<String, dynamic>>();
      if (results == null || results.isEmpty) return null;

      Map<String, dynamic> chosen = results.first;
      for (final item in results) {
        final tName = (item['title'] as String? ?? '').toLowerCase();
        final aName =
            (item['artist']?['name'] as String? ?? '').toLowerCase();
        if (tName.contains(targetTitle.toLowerCase()) &&
            (targetArtist.isEmpty ||
                aName.contains(targetArtist.toLowerCase()))) {
          chosen = item;
          break;
        }
      }

      final albumMap = chosen['album'] as Map<String, dynamic>?;
      final cover = (albumMap?['cover_xl'] ??
          albumMap?['cover_big'] ??
          albumMap?['cover_medium']) as String?;
      final durationSec = (chosen['duration'] as num?)?.toInt();

      return {
        'title': chosen['title'] as String?,
        'artist': chosen['artist']?['name'] as String?,
        'album': albumMap?['title'] as String?,
        'durationMs': durationSec != null ? durationSec * 1000 : null,
        'artworkUrl': cover,
      };
    } catch (_) {
      return null;
    }
  }

  Future<String?> _fetchLrcLibLyrics({
    required String title,
    required String artist,
    String? album,
    int? durationSeconds,
  }) async {
    const headers = {'User-Agent': 'Tone/1.0.0 (music player)'};
    // 1. Try exact get if artist is known
    if (artist.isNotEmpty && artist.toLowerCase() != 'unknown artist') {
      try {
        final getUri = Uri.https('lrclib.net', '/api/get', {
          'track_name': title,
          'artist_name': artist,
          if (album != null &&
              album.isNotEmpty &&
              album.toLowerCase() != 'single' &&
              album.toLowerCase() != 'unknown album')
            'album_name': album,
          if (durationSeconds != null &&
              durationSeconds > 0 &&
              durationSeconds <= 3600)
            'duration': '$durationSeconds',
        });
        final getRes = await http
            .get(getUri, headers: headers)
            .timeout(const Duration(seconds: 5));
        if (getRes.statusCode == 200) {
          final map = jsonDecode(getRes.body) as Map<String, dynamic>;
          final synced = map['syncedLyrics'] as String?;
          final plain = map['plainLyrics'] as String?;
          if (synced != null && synced.trim().isNotEmpty) return synced;
          if (plain != null && plain.trim().isNotEmpty) return plain;
        }
      } catch (_) {}
    }

    // 2. Search LRCLIB with cleaned query
    try {
      final q = (artist.isNotEmpty && artist.toLowerCase() != 'unknown artist')
          ? '$title $artist'
          : title;
      final searchUri = Uri.https('lrclib.net', '/api/search', {'q': q});
      final searchRes = await http
          .get(searchUri, headers: headers)
          .timeout(const Duration(seconds: 6));
      if (searchRes.statusCode == 200) {
        final list = jsonDecode(searchRes.body) as List?;
        if (list != null && list.isNotEmpty) {
          final candidates = list.whereType<Map<String, dynamic>>().toList();
          // Prefer candidates with syncedLyrics
          for (final c in candidates) {
            final synced = c['syncedLyrics'] as String?;
            if (synced != null && synced.trim().isNotEmpty) {
              return synced;
            }
          }
          for (final c in candidates) {
            final plain = c['plainLyrics'] as String?;
            if (plain != null && plain.trim().isNotEmpty) {
              return plain;
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }
}
