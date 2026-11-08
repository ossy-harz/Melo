import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _lyricsChannel = MethodChannel('app.melo.melo_player/library');
typedef OnlineLyricsLookup = Future<Object?> Function(Uri uri);

class LyricsServiceUnavailableException implements Exception {
  const LyricsServiceUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LyricLine {
  const LyricLine({
    required this.text,
    this.time,
    this.words = const [],
    this.hasExplicitWords = false,
  });

  final String text;
  final Duration? time;
  final List<LyricWord> words;
  final bool hasExplicitWords;

  int activeWordAt(Duration position) {
    if (words.isEmpty) return -1;
    var active = -1;
    for (var i = 0; i < words.length; i++) {
      if (words[i].time <= position) {
        active = i;
      } else {
        break;
      }
    }
    return active;
  }
}

class LyricWord {
  const LyricWord({required this.text, required this.time});

  final String text;
  final Duration time;
}

class SongLyrics {
  const SongLyrics({required this.lines});

  final List<LyricLine> lines;

  bool get isSynchronized => lines.any((line) => line.time != null);
  bool get hasWordTiming => lines.any((line) => line.hasExplicitWords);

  int activeLineAt(Duration position) {
    var low = 0;
    var high = lines.length - 1;
    var active = -1;
    while (low <= high) {
      final middle = (low + high) ~/ 2;
      final time = lines[middle].time;
      if (time == null || time > position) {
        high = middle - 1;
      } else {
        active = middle;
        low = middle + 1;
      }
    }
    return active;
  }

  int activeWordAt(int lineIndex, Duration position) {
    if (lineIndex < 0 || lineIndex >= lines.length) return -1;
    final words = lines[lineIndex].words;
    var low = 0;
    var high = words.length - 1;
    var active = -1;
    while (low <= high) {
      final middle = (low + high) ~/ 2;
      if (words[middle].time > position) {
        high = middle - 1;
      } else {
        active = middle;
        low = middle + 1;
      }
    }
    return active;
  }

  static SongLyrics? parse({String? synchronized, String? plain}) {
    final syncedLines = <LyricLine>[];
    final plainLines = <LyricLine>[];
    if (synchronized != null) {
      final timestamp = RegExp(r'\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]');
      final wordTimestamp = RegExp(r'<(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?>');
      final offsetMatch = RegExp(
        r'^\s*\[offset:([+-]?\d+)\]',
        caseSensitive: false,
        multiLine: true,
      ).firstMatch(synchronized);
      final offset = int.tryParse(offsetMatch?.group(1) ?? '') ?? 0;
      for (final line in const LineSplitter().convert(synchronized)) {
        if (RegExp(
          r'^\s*\[(?:ar|ti|al|by|re|ve|length|offset):',
          caseSensitive: false,
        ).hasMatch(line)) {
          continue;
        }
        final matches = timestamp.allMatches(line).toList(growable: false);
        final body = line.replaceAll(timestamp, '');
        final wordMatches = wordTimestamp
            .allMatches(body)
            .toList(growable: false);
        final text = body
            .replaceAll(wordTimestamp, '')
            .trim()
            .replaceAll(RegExp(r'\s+'), ' ');
        if (text.isEmpty) continue;
        if (matches.isEmpty) {
          if (wordMatches.isEmpty) {
            plainLines.add(LyricLine(text: text));
          } else {
            syncedLines.add(
              LyricLine(
                time: _timeFromMatch(wordMatches.first, offset),
                text: text,
                words: _parseWords(body, wordTimestamp, offset),
                hasExplicitWords: true,
              ),
            );
          }
          continue;
        }
        for (final match in matches) {
          final words = _parseWords(body, wordTimestamp, offset);
          syncedLines.add(
            LyricLine(
              time: _timeFromMatch(match, offset),
              text: text,
              words: words,
              hasExplicitWords: words.isNotEmpty,
            ),
          );
        }
      }
    }
    if (syncedLines.isNotEmpty) {
      syncedLines.sort((a, b) => a.time!.compareTo(b.time!));

      // Auto-interpolate word timings for Mornye-style karaoke sing-along
      final enrichedLines = <LyricLine>[];
      for (var i = 0; i < syncedLines.length; i++) {
        final current = syncedLines[i];
        if (current.words.isNotEmpty || current.time == null) {
          enrichedLines.add(current);
          continue;
        }

        final wordsList = current.text
            .split(RegExp(r'\s+'))
            .where((w) => w.isNotEmpty)
            .toList();
        if (wordsList.isEmpty) {
          enrichedLines.add(current);
          continue;
        }

        final nextTime =
            (i + 1 < syncedLines.length && syncedLines[i + 1].time != null)
                ? syncedLines[i + 1].time!
                : current.time! + const Duration(seconds: 4);

        final totalDurationMs =
            (nextTime - current.time!).inMilliseconds.clamp(1000, 8000);
        final totalChars = wordsList.fold<int>(
          0,
          (sum, w) => sum + w.length,
        ).clamp(1, 9999);

        final generatedWords = <LyricWord>[];
        var accumulatedChars = 0;
        for (final word in wordsList) {
          final wordStartMs =
              (totalDurationMs * (accumulatedChars / totalChars)).round();
          generatedWords.add(
            LyricWord(
              text: word,
              time: current.time! + Duration(milliseconds: wordStartMs),
            ),
          );
          accumulatedChars += word.length;
        }

        enrichedLines.add(
          LyricLine(
            text: current.text,
            time: current.time,
            words: List.unmodifiable(generatedWords),
            hasExplicitWords: false,
          ),
        );
      }

      return SongLyrics(lines: List.unmodifiable(enrichedLines));
    }

    if (plainLines.isEmpty && plain != null) {
      plainLines.addAll(
        plain
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .map((line) => LyricLine(text: line)),
      );
    }
    return plainLines.isEmpty
        ? null
        : SongLyrics(lines: List.unmodifiable(plainLines));
  }

  static Duration _timeFromMatch(RegExpMatch match, int offset) {
    final fraction = (match.group(3) ?? '0').padRight(3, '0');
    return Duration(
          minutes: int.parse(match.group(1)!),
          seconds: int.parse(match.group(2)!),
          milliseconds: int.parse(fraction.substring(0, 3)),
        ) +
        Duration(milliseconds: offset);
  }

  static List<LyricWord> _parseWords(
    String line,
    RegExp timestamp,
    int offset,
  ) {
    final matches = timestamp.allMatches(line).toList(growable: false);
    if (matches.isEmpty) return const [];
    final words = <LyricWord>[];
    for (var index = 0; index < matches.length; index++) {
      final match = matches[index];
      final end = index + 1 < matches.length
          ? matches[index + 1].start
          : line.length;
      final text = line.substring(match.end, end).trim();
      if (text.isEmpty) continue;
      final time = _timeFromMatch(match, offset);
      for (final word in text.split(RegExp(r'\s+'))) {
        if (word.isNotEmpty) words.add(LyricWord(text: word, time: time));
      }
    }
    words.sort((first, second) => first.time.compareTo(second.time));
    return List.unmodifiable(words);
  }
}

class LyricsRepository {
  static const _cachePrefix = 'tone_lyrics_v1_';
  static const _songCachePrefix = 'tone_lyrics_song_v1_';
  static const _offsetPrefix = 'tone_lyrics_offset_v1_';
  static const _onlineLyricsKey = 'tone_online_lyrics_enabled';

  static String _canonicalSongKey(String title, String? artist) {
    final cleanT = _cleanTitleForMatch(title);
    final cleanA = _cleanTitleForMatch(artist ?? '');
    return '$_songCachePrefix${Uri.encodeComponent('$cleanT|$cleanA')}';
  }

  static Future<int> getSyncOffsetMs(String itemId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_offsetPrefix${Uri.encodeComponent(itemId)}') ?? 0;
  }

  static Future<void> setSyncOffsetMs(String itemId, int offsetMs) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_offsetPrefix${Uri.encodeComponent(itemId)}';
    if (offsetMs == 0) {
      await prefs.remove(key);
    } else {
      await prefs.setInt(key, offsetMs);
    }
  }

  static Future<void> cacheLyricsForSong({
    required String title,
    required String? artist,
    required String rawLrc,
  }) async {
    if (title.trim().isEmpty || rawLrc.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_canonicalSongKey(title, artist), rawLrc);
  }

  static Future<bool> get onlineLookupEnabled async =>
      (await SharedPreferences.getInstance()).getBool(_onlineLyricsKey) ??
      false;

  static Future<void> setOnlineLookupEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_onlineLyricsKey, enabled);
  }

  static Future<int> clearCache() async {
    final preferences = await SharedPreferences.getInstance();
    final keys = preferences
        .getKeys()
        .where((key) => key.startsWith(_cachePrefix))
        .toList(growable: false);
    for (final key in keys) {
      await preferences.remove(key);
    }
    return keys.length;
  }

  static Future<SongLyrics?> loadFor(
    MediaItem item, {
    OnlineLyricsLookup? onlineLookup,
  }) async {
    final cacheKey = '$_cachePrefix${Uri.encodeComponent(item.id)}';
    final preferences = await SharedPreferences.getInstance();
    final cached = preferences.getString(cacheKey);
    if (cached != null) {
      return SongLyrics.parse(synchronized: cached, plain: cached);
    }
    if (onlineLookup == null && item.title.trim().isNotEmpty) {
      final songCached = preferences.getString(
        _canonicalSongKey(item.title, item.artist),
      );
      if (songCached != null && songCached.trim().isNotEmpty) {
        final lyrics = SongLyrics.parse(
          synchronized: songCached,
          plain: songCached,
        );
        if (lyrics != null) {
          await preferences.setString(cacheKey, songCached);
          return lyrics;
        }
      }
    }

    final lyricsUri = item.extras?['lyricsUri'] as String?;
    if (lyricsUri != null) {
      final lyricsText = await _lyricsChannel.invokeMethod<String>(
        'readLyrics',
        {'uri': lyricsUri},
      );
      if (lyricsText != null && lyricsText.trim().isNotEmpty) {
        final lyrics = SongLyrics.parse(
          synchronized: lyricsText,
          plain: lyricsText,
        );
        if (lyrics != null) {
          await preferences.setString(cacheKey, lyricsText);
          return lyrics;
        }
      }
    }

    // Check if an offline .lrc file exists alongside the track on disk
    if ((item.id.contains('/') || item.id.contains(r'\')) &&
        !item.id.startsWith('http://') &&
        !item.id.startsWith('https://') &&
        !item.id.startsWith('youtube:') &&
        !item.id.startsWith('spotify:')) {
      final lastDot = item.id.lastIndexOf('.');
      final localLrcPath = lastDot > 0
          ? '${item.id.substring(0, lastDot)}.lrc'
          : '${item.id}.lrc';
      try {
        final localFile = File(localLrcPath);
        if (localFile.existsSync()) {
          final text = localFile.readAsStringSync();
          if (text.trim().isNotEmpty) {
            final lyrics = SongLyrics.parse(synchronized: text, plain: text);
            if (lyrics != null) {
              await preferences.setString(cacheKey, text);
              return lyrics;
            }
          }
        }
      } catch (_) {}
    }

    final isOnlineStream = _isOnlineStreamItem(item);
    if (!isOnlineStream && !await onlineLookupEnabled) return null;
    return findOnlineFor(
      item,
      onlineLookup: onlineLookup,
      forceOnline: isOnlineStream,
    );
  }

  static bool _isOnlineStreamItem(MediaItem item) {
    final source = item.extras?['source'] as String?;
    return item.id.startsWith('youtube:') ||
        item.id.startsWith('spotify:') ||
        item.id.startsWith('http://') ||
        item.id.startsWith('https://') ||
        source == 'youtube' ||
        source == 'spotify';
  }

  static Future<void> cacheLyricsForId(String id, String lyricsText) async {
    final cacheKey = '$_cachePrefix${Uri.encodeComponent(id)}';
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(cacheKey, lyricsText);
  }

  static Future<SongLyrics?> findOnlineFor(
    MediaItem item, {
    OnlineLyricsLookup? onlineLookup,
    bool forceOnline = false,
  }) async {
    if (!forceOnline && !await onlineLookupEnabled) return null;
    final uri = buildLookupUri(item);
    if (uri == null) return null;
    final lookup = onlineLookup ?? _requestLyrics;
    final exactMatch = await lookup(uri);
    if (exactMatch is Map<String, Object?>) {
      final lyrics = await _cacheResponse(item, exactMatch);
      if (lyrics != null) return lyrics;
    }

    final searchUri = buildSearchLookupUri(item);
    if (searchUri == null) return null;
    final searchResults = await lookup(searchUri);
    if (searchResults is! List) return null;

    var candidates = searchResults
        .whereType<Map>()
        .map((candidate) => Map<String, Object?>.from(candidate))
        .where((candidate) => _matchesTrack(item, candidate))
        .toList(growable: true);
    if (candidates.isEmpty && onlineLookup == null) {
      candidates = searchResults
          .whereType<Map>()
          .map((candidate) => Map<String, Object?>.from(candidate))
          .where((candidate) => _matchesTrackRelaxed(item, candidate))
          .toList(growable: true);
    }
    if (candidates.isEmpty) return null;

    candidates.sort((first, second) {
      final albumComparison = _albumMatchScore(
        item,
        second['albumName'] as String?,
      ).compareTo(_albumMatchScore(item, first['albumName'] as String?));
      if (albumComparison != 0) return albumComparison;
      return _durationDifference(
        item,
        first['duration'],
      ).compareTo(_durationDifference(item, second['duration']));
    });

    for (final candidate in candidates) {
      final lyrics = await _cacheResponse(item, candidate);
      if (lyrics != null) return lyrics;
    }

    // Fallback with cleaned title/artist (stripping Official Video, Lyrics, Topic, etc.) in live runtime
    if (onlineLookup == null) {
      final cleaned = _cleanedMediaItemForLyrics(item);
      if (cleaned != null) {
        final cleanedSearch = buildSearchLookupUri(cleaned);
        if (cleanedSearch != null) {
          final cleanedResults = await lookup(cleanedSearch);
          if (cleanedResults is List) {
            final cleanedCandidates = cleanedResults
                .whereType<Map>()
                .map((c) => Map<String, Object?>.from(c))
                .where((c) => _matchesTrackRelaxed(cleaned, c))
                .toList(growable: true);
            cleanedCandidates.sort(
              (a, b) => _durationDifference(
                cleaned,
                a['duration'],
              ).compareTo(_durationDifference(cleaned, b['duration'])),
            );
            for (final candidate in cleanedCandidates) {
              final lyrics = await _cacheResponse(item, candidate);
              if (lyrics != null) return lyrics;
            }
          }
        }
      }
    }
    return null;
  }

  static MediaItem? _cleanedMediaItemForLyrics(MediaItem item) {
    final cleanedTitle = item.title
        .replaceAll(
          RegExp(
            r'\s*[\(\[](?:official|music|lyric|lyrics|audio|video|hd|hq|4k|visualizer|remaster|live).*?[\)\]]',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(r'\s+(?:feat\.?|ft\.?)\s+.*$', caseSensitive: false),
          '',
        )
        .trim();
    final cleanedArtist = (item.artist ?? '')
        .replaceFirst(RegExp(r'\s*-\s*Topic$', caseSensitive: false), '')
        .replaceFirst(RegExp(r'VEVO$', caseSensitive: false), '')
        .split(RegExp(r'\s*(?:,|&|feat\.?|ft\.?|x)\s*', caseSensitive: false))
        .first
        .trim();
    if (cleanedTitle == item.title.trim() &&
        cleanedArtist == (item.artist ?? '').trim()) {
      return null;
    }
    if (cleanedTitle.isEmpty) return null;
    return item.copyWith(
      title: cleanedTitle,
      artist: cleanedArtist.isEmpty ? item.artist : cleanedArtist,
    );
  }

  static Uri? buildLookupUri(MediaItem item) {
    final title = item.title.trim();
    final artist = item.artist?.trim() ?? '';
    if (title.isEmpty ||
        title.toLowerCase() == 'unknown title' ||
        artist.isEmpty ||
        const {
          'unknown artist',
          'on-device audio',
        }.contains(artist.toLowerCase())) {
      return null;
    }
    final album = item.album?.trim();
    final durationSeconds = item.duration?.inSeconds;
    return Uri.https('lrclib.net', '/api/get', {
      'track_name': title,
      'artist_name': artist,
      if (album != null && album.isNotEmpty && album != 'Unknown album')
        'album_name': album,
      if (durationSeconds != null &&
          durationSeconds > 0 &&
          durationSeconds <= 3600)
        'duration': '$durationSeconds',
    });
  }

  static Uri? buildSearchLookupUri(MediaItem item) {
    final title = item.title.trim();
    final artist = item.artist?.trim() ?? '';
    if (title.isEmpty ||
        title.toLowerCase() == 'unknown title' ||
        artist.isEmpty ||
        const {
          'unknown artist',
          'on-device audio',
        }.contains(artist.toLowerCase())) {
      return null;
    }
    return Uri.https('lrclib.net', '/api/search', {'q': '$title $artist'});
  }

  static Future<SongLyrics?> _cacheResponse(
    MediaItem item,
    Map<String, Object?> response,
  ) async {
    if (response['instrumental'] == true) return null;
    final synchronized = response['syncedLyrics'] as String?;
    final plain = response['plainLyrics'] as String?;
    final lyrics = SongLyrics.parse(synchronized: synchronized, plain: plain);
    if (lyrics == null) return null;

    final cacheValue = synchronized?.trim().isNotEmpty == true
        ? synchronized!
        : plain!;
    final cacheKey = '$_cachePrefix${Uri.encodeComponent(item.id)}';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(cacheKey, cacheValue);
    if (item.title.trim().isNotEmpty) {
      await prefs.setString(
        _canonicalSongKey(item.title, item.artist),
        cacheValue,
      );
    }
    return lyrics;
  }

  static bool _matchesTrack(MediaItem item, Map<String, Object?> candidate) {
    final title = candidate['trackName'];
    final artist = candidate['artistName'];
    if (title is! String ||
        artist is! String ||
        _normalizeMatchText(title) != _normalizeMatchText(item.title) ||
        _normalizeMatchText(artist) != _normalizeMatchText(item.artist ?? '')) {
      return false;
    }

    final difference = _durationDifference(item, candidate['duration']);
    return difference == 0 || difference <= 12;
  }

  static bool _matchesTrackRelaxed(
    MediaItem item,
    Map<String, Object?> candidate,
  ) {
    final title = candidate['trackName'];
    final artist = candidate['artistName'];
    if (title is! String || artist is! String) return false;

    // Strict Artist Validation: NEVER download lyrics if the artist is completely wrong!
    final cleanCandidateArtist = _cleanTitleForMatch(artist);
    final cleanItemArtist = _cleanTitleForMatch(item.artist ?? '');
    if (cleanItemArtist.isNotEmpty && cleanCandidateArtist.isNotEmpty) {
      final artistMatches = cleanCandidateArtist == cleanItemArtist ||
          cleanCandidateArtist.contains(cleanItemArtist) ||
          cleanItemArtist.contains(cleanCandidateArtist);
      if (!artistMatches) return false;
    }

    // Strict Title Validation: require matching root title without short substring accidents
    final cleanCandidateTitle = _cleanTitleForMatch(title);
    final cleanItemTitle = _cleanTitleForMatch(item.title);
    if (cleanCandidateTitle.isEmpty || cleanItemTitle.isEmpty) return false;

    final titleMatches = cleanCandidateTitle == cleanItemTitle ||
        (cleanCandidateTitle.length >= 4 &&
            cleanItemTitle.length >= 4 &&
            (cleanCandidateTitle.startsWith(cleanItemTitle) ||
                cleanItemTitle.startsWith(cleanCandidateTitle)));
    if (!titleMatches) return false;

    // Strict Duration Validation (max 10 seconds difference if track duration is known)
    final difference = _durationDifference(item, candidate['duration']);
    if (item.duration != null && item.duration!.inSeconds > 0) {
      return difference <= 10;
    }
    return difference == 0 || difference <= 12;
  }

  static String _cleanTitleForMatch(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '')
      .replaceAll(RegExp(r'[^\w\s]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String _normalizeMatchText(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static int _albumMatchScore(MediaItem item, String? candidateAlbum) {
    final album = item.album?.trim();
    if (album == null ||
        album.isEmpty ||
        album.toLowerCase() == 'unknown album' ||
        candidateAlbum == null) {
      return 0;
    }
    return _normalizeMatchText(album) == _normalizeMatchText(candidateAlbum)
        ? 1
        : 0;
  }

  static int _durationDifference(MediaItem item, Object? candidateDuration) {
    final itemDuration = item.duration?.inSeconds;
    final seconds = (candidateDuration as num?)?.round();
    if (itemDuration == null || seconds == null) return 0;
    return (itemDuration - seconds).abs();
  }

  static Future<SongLyrics?> importFor(MediaItem item) async {
    final selected = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['lrc', 'txt'],
      dialogTitle: 'Choose lyrics for ${item.title}',
    );
    if (selected.isEmpty) return null;
    final lyricsText = await utf8.decoder
        .bind(selected.first.readAsByteStream())
        .join();
    final lyrics = SongLyrics.parse(
      synchronized: lyricsText,
      plain: lyricsText,
    );
    if (lyrics == null) {
      throw const FormatException('The selected file contains no lyrics.');
    }
    final cacheKey = '$_cachePrefix${Uri.encodeComponent(item.id)}';
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(cacheKey, lyricsText);
    return lyrics;
  }

  static Future<Object?> _requestLyrics(Uri uri) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 10));
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Tone/1.0.0 (local music player)',
      );
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      if (response.statusCode == HttpStatus.notFound) {
        await response.drain<void>();
        return null;
      }
      if (response.statusCode == HttpStatus.tooManyRequests ||
          response.statusCode >= HttpStatus.internalServerError) {
        await response.drain<void>();
        throw LyricsServiceUnavailableException(
          'Lyrics service is temporarily unavailable '
          '(HTTP ${response.statusCode}).',
        );
      }
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw HttpException(
          'Lyrics service returned HTTP ${response.statusCode}.',
          uri: uri,
        );
      }
      final contentType = response.headers.contentType;
      if (contentType?.mimeType != 'application/json') {
        await response.drain<void>();
        throw const FormatException(
          'Lyrics service returned a non-JSON response.',
        );
      }
      final decoded = jsonDecode(await utf8.decoder.bind(response).join());
      if (decoded is! Map<String, dynamic> && decoded is! List) {
        throw const FormatException('Lyrics response was not valid JSON data.');
      }
      return decoded;
    } finally {
      client.close(force: true);
    }
  }
}
