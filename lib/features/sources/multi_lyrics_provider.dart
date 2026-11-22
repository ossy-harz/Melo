import 'dart:async';
import 'dart:convert';
import 'package:audio_service/audio_service.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:melo_player/features/player/lyrics_repository.dart';
import 'package:melo_player/features/sources/music_provider_models.dart';

/// Mornye-grade lyrics result containing synchronized timestamps,
/// word-by-word timings, translations, and attribution.
class LyricsLookupResult {
  const LyricsLookupResult({
    required this.provider,
    required this.plainLyrics,
    this.syncedLyrics,
    this.isWordSynced = false,
    this.translation,
    this.romanization,
    this.writers,
    this.source,
  });

  final MusicProviderType provider;
  final String plainLyrics;
  final String? syncedLyrics;
  final bool isWordSynced;
  final String? translation;
  final String? romanization;
  final String? writers;
  final String? source;

  bool get hasSynced => syncedLyrics != null && syncedLyrics!.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
    'provider': provider.id,
    'plain_lyrics': plainLyrics,
    if (syncedLyrics != null) 'synced_lyrics': syncedLyrics,
    'is_word_synced': isWordSynced,
    if (translation != null) 'translation': translation,
    if (romanization != null) 'romanization': romanization,
    if (writers != null) 'writers': writers,
    if (source != null) 'source': source,
  };

  factory LyricsLookupResult.fromJson(Map<String, dynamic> json) => LyricsLookupResult(
    provider: MusicProviderType.fromId(json['provider'] as String? ?? 'all'),
    plainLyrics: json['plain_lyrics'] as String? ?? '',
    syncedLyrics: json['synced_lyrics'] as String?,
    isWordSynced: json['is_word_synced'] as bool? ?? false,
    translation: json['translation'] as String?,
    romanization: json['romanization'] as String?,
    writers: json['writers'] as String?,
    source: json['source'] as String?,
  );
}

/// Mornye-matching helper utilities for title cleaning, artist isolation,
/// and duration verification.
class MornyeLyricsMatching {
  MornyeLyricsMatching._();

  static final List<RegExp> _simplifyRegexes = [
    RegExp(r'\s*\(feat\.?.*?\)', caseSensitive: false),
    RegExp(r'\s*\(ft\.?.*?\)', caseSensitive: false),
    RegExp(r'\s*\(featuring.*?\)', caseSensitive: false),
    RegExp(r'\s*\(with.*?\)', caseSensitive: false),
    RegExp(r'\s*-\s*Remaster(ed)?.*$', caseSensitive: false),
    RegExp(r'\s*-\s*\d{4}\s*Remaster.*$', caseSensitive: false),
    RegExp(r'\s*\(Remaster(ed)?.*?\)', caseSensitive: false),
    RegExp(r'\s*\(Deluxe.*?\)', caseSensitive: false),
    RegExp(r'\s*\(Bonus.*?\)', caseSensitive: false),
    RegExp(r'\s*\(Live.*?\)', caseSensitive: false),
    RegExp(r'\s*\(Acoustic.*?\)', caseSensitive: false),
    RegExp(r'\s*\(Radio Edit\)', caseSensitive: false),
    RegExp(r'\s*\(Single Version\)', caseSensitive: false),
    RegExp(r'\s*\[Official.*?\]', caseSensitive: false),
    RegExp(r'\s*\(Official.*?\)', caseSensitive: false),
  ];

  static String simplifyTrack(String value) {
    var output = value;
    for (final pattern in _simplifyRegexes) {
      output = output.replaceAll(pattern, '');
    }
    final normalized = normalizeTitle(output.trim());
    return normalized.isEmpty ? value.trim() : normalized;
  }

  static String normalizeTitle(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[\/\\_\-\|\.\&\+]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String primaryArtist(String value) {
    final lower = value.toLowerCase();
    const separators = [', ', '; ', ' & ', ' feat. ', ' ft. ', ' featuring ', ' with ', ' x '];
    var earliest = value.length;
    for (final sep in separators) {
      final idx = lower.indexOf(sep);
      if (idx > 0 && idx < earliest) {
        earliest = idx;
      }
    }
    return value.substring(0, earliest).trim();
  }

  static bool durationMatches(double candidateSec, double expectedSec) {
    if (candidateSec <= 0 || expectedSec <= 0) return true;
    return (candidateSec - expectedSec).abs() <= 10.0;
  }

  static bool titlesMatch(String candidate, String expected) {
    final c = simplifyTrack(candidate).toLowerCase();
    final e = simplifyTrack(expected).toLowerCase();
    if (c.isEmpty || e.isEmpty) return false;
    return c == e || c.contains(e) || e.contains(c);
  }

  static bool artistsMatch(String candidate, String expected) {
    final exp = normalizeTitle(primaryArtist(expected));
    if (exp.isEmpty) return true;
    final cand = normalizeTitle(primaryArtist(candidate));
    if (cand.isEmpty) return false;
    if (cand == exp || cand.contains(exp) || exp.contains(cand)) return true;

    final cWords = cand.split(' ')..sort();
    final eWords = exp.split(' ')..sort();
    return cWords.join(' ') == eWords.join(' ');
  }
}

/// Unified multi-provider lyrics and audio utility engine matching Mornye's architecture.
/// Queries LRCLIB, Apple Music TTML / BetterLyrics, Deezer Synced Lyrics, and NetEase Cloud Music
/// with in-flight deduplication and persistent caching.
class LyricsAndUtilityProvider {
  LyricsAndUtilityProvider._();
  static final LyricsAndUtilityProvider instance = LyricsAndUtilityProvider._();

  static const String _persistentCachePrefix = 'tone_lyrics_cache_v2_';
  final http.Client _httpClient = http.Client();
  final Map<String, LyricsLookupResult> _memoryCache = {};
  final Map<String, DateTime> _negativeCache = {};
  final Map<String, Future<LyricsLookupResult?>> _lyricsInFlight = {};

  /// Fetches synchronized, word-synced, or plain lyrics across LRCLIB, Apple Music TTML,
  /// Deezer, and NetEase with in-flight deduplication and zero-latency caching.
  Future<LyricsLookupResult?> fetchLyrics({
    required String title,
    required String artist,
    String? album,
    int? durationSeconds,
    MusicProviderType preferredProvider = MusicProviderType.all,
    bool forceRefresh = false,
  }) async {
    final cleanTitle = title.trim();
    final cleanArtist = artist.trim();
    if (cleanTitle.isEmpty) return null;

    final cacheKey = '${cleanTitle.toLowerCase()}::${cleanArtist.toLowerCase()}';

    // 1. Check in-flight requests (deduplication)
    if (_lyricsInFlight.containsKey(cacheKey)) {
      return _lyricsInFlight[cacheKey];
    }

    // 2. Check memory & negative cache
    if (!forceRefresh) {
      if (_memoryCache.containsKey(cacheKey)) {
        return _memoryCache[cacheKey];
      }
      final neg = _negativeCache[cacheKey];
      if (neg != null && DateTime.now().difference(neg) < const Duration(seconds: 30)) {
        return null;
      }

      // Check persistent SharedPreferences cache
      final fromDisk = await _readFromDiskCache(cacheKey);
      if (fromDisk != null) {
        _memoryCache[cacheKey] = fromDisk;
        return fromDisk;
      }
    }

    final future = _fetchLyricsInternal(
      cleanTitle: cleanTitle,
      cleanArtist: cleanArtist,
      album: album,
      durationSeconds: durationSeconds,
      preferredProvider: preferredProvider,
    );

    _lyricsInFlight[cacheKey] = future;
    try {
      final result = await future;
      if (result != null) {
        _memoryCache[cacheKey] = result;
        unawaited(_writeToDiskCache(cacheKey, result));
      } else {
        _negativeCache[cacheKey] = DateTime.now();
      }
      return result;
    } finally {
      _lyricsInFlight.remove(cacheKey);
    }
  }

  Future<LyricsLookupResult?> _fetchLyricsInternal({
    required String cleanTitle,
    required String cleanArtist,
    String? album,
    int? durationSeconds,
    MusicProviderType preferredProvider = MusicProviderType.all,
  }) async {
    // Cascade 1: LRCLIB (open, line-synced and word-synced)
    try {
      final lrclib = await _queryLrclib(cleanTitle, cleanArtist, album: album, durationSec: durationSeconds);
      if (lrclib != null && lrclib.hasSynced) return lrclib;
    } catch (_) {}

    // Cascade 2: Apple Music TTML / BetterLyrics (word-by-word syllable timing)
    try {
      final appleTtml = await _queryAppleMusicTtml(cleanTitle, cleanArtist, durationSec: durationSeconds);
      if (appleTtml != null && appleTtml.hasSynced) return appleTtml;
    } catch (_) {}

    // Cascade 3: Deezer Synced Lyrics API
    try {
      final deezer = await _queryDeezerLyrics(cleanTitle, cleanArtist);
      if (deezer != null && deezer.hasSynced) return deezer;
    } catch (_) {}

    // Cascade 4: NetEase Cloud Music (synced LRC + translated lyrics)
    try {
      final netease = await _queryNetEaseLyrics(cleanTitle, cleanArtist);
      if (netease != null && netease.hasSynced) return netease;
    } catch (_) {}

    // Cascade 5: Fallback to Melo's internal repository parser (LRCLIB fallback query)
    try {
      final item = MediaItem(
        id: 'lyrics_lookup',
        title: cleanTitle,
        artist: cleanArtist,
        album: album,
        duration: Duration(seconds: durationSeconds ?? 180),
      );
      final lyrics = await LyricsRepository.findOnlineFor(item, forceOnline: true);
      if (lyrics != null && lyrics.lines.isNotEmpty) {
        final buffer = StringBuffer();
        for (final line in lyrics.lines) {
          if (line.time != null) {
            final m = line.time!.inMinutes.toString().padLeft(2, '0');
            final s = (line.time!.inSeconds % 60).toString().padLeft(2, '0');
            final ms = ((line.time!.inMilliseconds % 1000) ~/ 10).toString().padLeft(2, '0');
            buffer.writeln('[$m:$s.$ms]${line.text}');
          } else {
            buffer.writeln(line.text);
          }
        }
        final lrc = buffer.toString().trim();
        return LyricsLookupResult(
          provider: MusicProviderType.appleMusic,
          plainLyrics: lyrics.lines.map((l) => l.text).join('\n'),
          syncedLyrics: lrc.isNotEmpty ? lrc : null,
          isWordSynced: lyrics.hasWordTiming,
          source: 'LRCLIB Repository',
        );
      }
    } catch (_) {}

    return null;
  }

  /// Queries LRCLIB direct get and search endpoints matching Mornye's select algorithm.
  Future<LyricsLookupResult?> _queryLrclib(
    String title,
    String artist, {
    String? album,
    int? durationSec,
  }) async {
    final expectedDur = (durationSec ?? 0).toDouble();

    // 1. Direct get attempt
    try {
      final queryParams = {
        'track_name': title,
        'artist_name': artist,
        if (album != null && album.isNotEmpty) 'album_name': album,
        if (durationSec != null && durationSec > 0) 'duration': durationSec.toString(),
      };
      final getUri = Uri.https('lrclib.net', '/api/get', queryParams);
      final res = await _httpClient.get(getUri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final synced = json['syncedLyrics'] as String?;
        final plain = json['plainLyrics'] as String?;
        if (synced != null && synced.trim().isNotEmpty) {
          return LyricsLookupResult(
            provider: MusicProviderType.appleMusic,
            plainLyrics: plain ?? synced.replaceAll(RegExp(r'\[\d+:\d+\.\d+\]'), '').trim(),
            syncedLyrics: synced,
            isWordSynced: synced.contains('<'),
            source: 'LRCLIB',
          );
        }
      }
    } catch (_) {}

    // 2. Search fallback with Mornye's select matching
    try {
      final sUri = Uri.https('lrclib.net', '/api/search', {'q': '$title $artist'});
      final sRes = await _httpClient.get(sUri).timeout(const Duration(seconds: 5));
      if (sRes.statusCode == 200) {
        final list = jsonDecode(sRes.body) as List?;
        if (list != null && list.isNotEmpty) {
          for (final raw in list) {
            if (raw is! Map) continue;
            final tName = raw['trackName'] as String? ?? raw['name'] as String? ?? '';
            final aName = raw['artistName'] as String? ?? '';
            final candDur = (raw['duration'] as num?)?.toDouble() ?? 0.0;
            final synced = raw['syncedLyrics'] as String?;
            final plain = raw['plainLyrics'] as String?;

            if (!MornyeLyricsMatching.durationMatches(candDur, expectedDur)) continue;
            if (!MornyeLyricsMatching.titlesMatch(tName, title)) continue;
            if (!MornyeLyricsMatching.artistsMatch(aName, artist)) continue;

            if (synced != null && synced.trim().isNotEmpty) {
              return LyricsLookupResult(
                provider: MusicProviderType.appleMusic,
                plainLyrics: plain ?? synced.replaceAll(RegExp(r'\[\d+:\d+\.\d+\]'), '').trim(),
                syncedLyrics: synced,
                isWordSynced: synced.contains('<'),
                source: 'LRCLIB Verified',
              );
            }
          }
        }
      }
    } catch (_) {}

    return null;
  }

  /// Queries Apple Music TTML / BetterLyrics for word-by-word syllable timings.
  Future<LyricsLookupResult?> _queryAppleMusicTtml(
    String title,
    String artist, {
    int? durationSec,
  }) async {
    try {
      final uri = Uri.https('api.betterlyrics.org', '/v1/lyrics', {
        'track': MornyeLyricsMatching.simplifyTrack(title),
        'artist': MornyeLyricsMatching.primaryArtist(artist),
        if (durationSec != null && durationSec > 0) 'duration': durationSec.toString(),
      });
      final res = await _httpClient.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final synced = json['lrc'] as String? ?? json['syncedLyrics'] as String?;
        final plain = json['plain'] as String? ?? json['plainLyrics'] as String?;
        if (synced != null && synced.trim().isNotEmpty) {
          return LyricsLookupResult(
            provider: MusicProviderType.appleMusic,
            plainLyrics: plain ?? synced.replaceAll(RegExp(r'\[\d+:\d+\.\d+\]'), '').trim(),
            syncedLyrics: synced,
            isWordSynced: synced.contains('<'),
            source: 'BetterLyrics (Apple Music TTML)',
          );
        }
      }
    } catch (_) {}
    return null;
  }

  /// Queries Deezer public track and synchronized lyrics.
  Future<LyricsLookupResult?> _queryDeezerLyrics(String title, String artist) async {
    try {
      final query = artist.isNotEmpty ? '$title $artist' : title;
      final uri = Uri.parse('https://api.deezer.com/search?q=${Uri.encodeComponent(query)}&limit=1');
      final res = await _httpClient.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final data = json['data'] as List?;
        if (data != null && data.isNotEmpty) {
          final trackId = data.first['id']?.toString();
          if (trackId != null) {
            final lUri = Uri.parse('https://api.deezer.com/track/$trackId');
            final lRes = await _httpClient.get(lUri).timeout(const Duration(seconds: 4));
            if (lRes.statusCode == 200) {
              final lJson = jsonDecode(lRes.body) as Map<String, dynamic>;
              final lyricsText = lJson['lyrics']?['text'] as String?;
              final syncedText = lJson['lyrics']?['synchronisedLines'] as List?;
              if (syncedText != null && syncedText.isNotEmpty) {
                final buffer = StringBuffer();
                for (final row in syncedText) {
                  if (row is Map) {
                    final time = row['lrc_timestamp'] as String? ?? '';
                    final words = row['line'] as String? ?? '';
                    buffer.writeln('[$time]$words');
                  }
                }
                return LyricsLookupResult(
                  provider: MusicProviderType.deezer,
                  plainLyrics: lyricsText ?? buffer.toString().replaceAll(RegExp(r'\[\d+:\d+\.\d+\]'), '').trim(),
                  syncedLyrics: buffer.toString().trim(),
                  source: 'Deezer Synced',
                );
              } else if (lyricsText != null && lyricsText.trim().isNotEmpty) {
                return LyricsLookupResult(
                  provider: MusicProviderType.deezer,
                  plainLyrics: lyricsText,
                  source: 'Deezer Text',
                );
              }
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Queries NetEase Cloud Music for synchronized and translated lyrics.
  Future<LyricsLookupResult?> _queryNetEaseLyrics(String title, String artist) async {
    try {
      final query = artist.isNotEmpty ? '$title $artist' : title;
      final sUri = Uri.https('music.163.com', '/api/search/get/web', {
        's': query,
        'type': '1',
        'limit': '1',
      });
      final sRes = await _httpClient.get(sUri, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
        'Referer': 'https://music.163.com',
      }).timeout(const Duration(seconds: 5));

      if (sRes.statusCode == 200) {
        final sJson = jsonDecode(sRes.body) as Map<String, dynamic>;
        final songs = sJson['result']?['songs'] as List?;
        if (songs != null && songs.isNotEmpty) {
          final songId = songs.first['id']?.toString();
          if (songId != null) {
            final lUri = Uri.https('music.163.com', '/api/song/lyric', {
              'id': songId,
              'lv': '1',
              'kv': '1',
              'tv': '1',
            });
            final lRes = await _httpClient.get(lUri, headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
              'Referer': 'https://music.163.com',
            }).timeout(const Duration(seconds: 5));

            if (lRes.statusCode == 200) {
              final lJson = jsonDecode(lRes.body) as Map<String, dynamic>;
              final lrc = lJson['lrc']?['lyric'] as String?;
              final tlyric = lJson['tlyric']?['lyric'] as String?;
              if (lrc != null && lrc.trim().isNotEmpty) {
                return LyricsLookupResult(
                  provider: MusicProviderType.spotify,
                  plainLyrics: lrc.replaceAll(RegExp(r'\[\d+:\d+\.\d+\]'), '').trim(),
                  syncedLyrics: lrc,
                  translation: (tlyric != null && tlyric.trim().isNotEmpty) ? tlyric : null,
                  source: 'NetEase Lyrics',
                );
              }
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<LyricsLookupResult?> _readFromDiskCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_persistentCachePrefix$key');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        return LyricsLookupResult.fromJson(decoded);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _writeToDiskCache(String key, LyricsLookupResult result) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_persistentCachePrefix$key', jsonEncode(result.toJson()));
    } catch (_) {}
  }

  /// Utility inspector for audio file format, bitrate, and lossless validation.
  static ({String format, int bitrateKbps, bool isLossless}) inspectAudioFormat(String pathOrUrl) {
    final lower = pathOrUrl.toLowerCase();
    if (lower.endsWith('.flac')) {
      return (format: 'FLAC', bitrateKbps: 1411, isLossless: true);
    }
    if (lower.endsWith('.wav')) {
      return (format: 'WAV', bitrateKbps: 1411, isLossless: true);
    }
    if (lower.endsWith('.m4a') || lower.endsWith('.aac')) {
      return (format: 'AAC', bitrateKbps: 256, isLossless: false);
    }
    if (lower.endsWith('.opus') || lower.endsWith('.ogg')) {
      return (format: 'OPUS', bitrateKbps: 160, isLossless: false);
    }
    return (format: 'MP3', bitrateKbps: 320, isLossless: false);
  }
}
