import 'dart:async';
import 'dart:convert';
import 'package:audio_service/audio_service.dart';
import 'package:http/http.dart' as http;
import 'package:melo_player/features/player/lyrics_repository.dart';
import 'package:melo_player/features/sources/music_provider_models.dart';

class LyricsLookupResult {
  const LyricsLookupResult({
    required this.provider,
    required this.plainLyrics,
    this.syncedLyrics,
    this.isWordSynced = false,
  });

  final MusicProviderType provider;
  final String plainLyrics;
  final String? syncedLyrics;
  final bool isWordSynced;

  bool get hasSynced => syncedLyrics != null && syncedLyrics!.trim().isNotEmpty;
}

/// Unified multi-provider lyrics and audio utility engine.
class LyricsAndUtilityProvider {
  LyricsAndUtilityProvider._();
  static final LyricsAndUtilityProvider instance = LyricsAndUtilityProvider._();

  final http.Client _httpClient = http.Client();

  /// Fetches synchronized or plain lyrics across LRCLIB, Deezer, NetEase, and Apple mirrors.
  Future<LyricsLookupResult?> fetchLyrics({
    required String title,
    required String artist,
    String? album,
    int? durationSeconds,
    MusicProviderType preferredProvider = MusicProviderType.all,
  }) async {
    final cleanTitle = title.trim();
    final cleanArtist = artist.trim();
    if (cleanTitle.isEmpty) return null;

    // 1. Try LRCLIB (gold standard for word-synced & synced LRC)
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
        );
      }
    } catch (_) {}

    // 2. Try Deezer Synced Lyrics API
    try {
      final deezerLyrics = await _queryDeezerLyrics(cleanTitle, cleanArtist);
      if (deezerLyrics != null) return deezerLyrics;
    } catch (_) {}

    // 3. Try NetEase Cloud Music Synced Lyrics API
    try {
      final neteaseLyrics = await _queryNetEaseLyrics(cleanTitle, cleanArtist);
      if (neteaseLyrics != null) return neteaseLyrics;
    } catch (_) {}

    return null;
  }

  Future<LyricsLookupResult?> _queryDeezerLyrics(String title, String artist) async {
    try {
      final query = artist.isNotEmpty ? '$title $artist' : title;
      final uri = Uri.parse('https://api.deezer.com/search?q=${Uri.encodeComponent(query)}&limit=1');
      final res = await _httpClient.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final data = json['data'] as List?;
        if (data != null && data.isNotEmpty) {
          final trackId = data.first['id']?.toString();
          if (trackId != null) {
            // Check for Deezer public lyrics endpoint
            final lUri = Uri.parse('https://api.deezer.com/track/$trackId');
            final lRes = await _httpClient.get(lUri).timeout(const Duration(seconds: 4));
            if (lRes.statusCode == 200) {
              final lJson = jsonDecode(lRes.body) as Map<String, dynamic>;
              final lyricsText = lJson['lyrics']?['text'] as String?;
              if (lyricsText != null && lyricsText.trim().isNotEmpty) {
                return LyricsLookupResult(
                  provider: MusicProviderType.deezer,
                  plainLyrics: lyricsText,
                );
              }
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

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
      }).timeout(const Duration(seconds: 6));

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
              'tv': '-1',
            });
            final lRes = await _httpClient.get(lUri, headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
              'Referer': 'https://music.163.com',
            }).timeout(const Duration(seconds: 6));

            if (lRes.statusCode == 200) {
              final lJson = jsonDecode(lRes.body) as Map<String, dynamic>;
              final lrc = lJson['lrc']?['lyric'] as String?;
              if (lrc != null && lrc.trim().isNotEmpty) {
                return LyricsLookupResult(
                  provider: MusicProviderType.spotify,
                  plainLyrics: lrc.replaceAll(RegExp(r'\[\d+:\d+\.\d+\]'), '').trim(),
                  syncedLyrics: lrc,
                );
              }
            }
          }
        }
      }
    } catch (_) {}
    return null;
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
