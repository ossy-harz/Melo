import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _lyricsChannel = MethodChannel('app.tone.tone_player/library');
typedef OnlineLyricsLookup = Future<Object?> Function(Uri uri);

class LyricsServiceUnavailableException implements Exception {
  const LyricsServiceUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LyricLine {
  const LyricLine({required this.text, this.time, this.words = const []});

  final String text;
  final Duration? time;
  final List<LyricWord> words;
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
  bool get hasWordTiming => lines.any((line) => line.words.isNotEmpty);

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
              ),
            );
          }
          continue;
        }
        for (final match in matches) {
          syncedLines.add(
            LyricLine(
              time: _timeFromMatch(match, offset),
              text: text,
              words: _parseWords(body, wordTimestamp, offset),
            ),
          );
        }
      }
    }
    if (syncedLines.isNotEmpty) {
      syncedLines.sort((a, b) => a.time!.compareTo(b.time!));
      return SongLyrics(lines: List.unmodifiable(syncedLines));
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
  static const _onlineLyricsKey = 'tone_online_lyrics_enabled';

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

    if (!await onlineLookupEnabled) return null;
    return findOnlineFor(item, onlineLookup: onlineLookup);
  }

  static Future<SongLyrics?> findOnlineFor(
    MediaItem item, {
    OnlineLyricsLookup? onlineLookup,
  }) async {
    if (!await onlineLookupEnabled) return null;
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

    final candidates = searchResults
        .whereType<Map>()
        .map((candidate) => Map<String, Object?>.from(candidate))
        .where((candidate) => _matchesTrack(item, candidate))
        .toList(growable: true);
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
    return null;
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
    await (await SharedPreferences.getInstance()).setString(
      cacheKey,
      cacheValue,
    );
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
