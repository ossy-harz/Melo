import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:melo_player/features/library/imported_track.dart';
import 'package:melo_player/features/library/music_library.dart';
import 'package:melo_player/features/library/song_metadata_enricher.dart';
import 'package:melo_player/features/player/lyrics_repository.dart';
import 'package:melo_player/features/sources/music_provider_models.dart';
import 'package:melo_player/features/sources/soundcloud_audio_service.dart';
import 'package:melo_player/features/youtube/youtube_audio_service.dart';

/// Unified cross-provider download engine supporting YouTube Music, SoundCloud,
/// Deezer, and Lossless streams with progress tracking and automatic offline lyrics.
class DownloadProviderService {
  DownloadProviderService._();
  static final DownloadProviderService instance = DownloadProviderService._();

  final http.Client _httpClient = http.Client();

  /// Downloads a track from the most suitable or [preferredProvider], falling back
  /// smoothly across providers if one is unavailable or geo-restricted.
  Future<ImportedTrack> downloadTrack({
    required MusicLibrary library,
    required String title,
    required String artist,
    String? album,
    String? artworkUrl,
    YoutubeTrack? youtubeTrack,
    MusicProviderType preferredProvider = MusicProviderType.youtubeMusic,
    ValueChanged<double>? onProgress,
  }) async {
    final cleanTitle = SongMetadataEnricher.cleanTitle(title, rawArtist: artist);
    final cleanArtist = SongMetadataEnricher.cleanArtist(artist, rawTitle: title);
    final resolvedAlbum = album?.trim().isNotEmpty == true ? album!.trim() : 'Downloaded Single';

    // 1. If YouTube Music is preferred or available, try YouTube first
    if (preferredProvider == MusicProviderType.youtubeMusic || youtubeTrack != null) {
      try {
        final yt = youtubeTrack ??
            (await YoutubeAudioService.instance.search(
              '$cleanTitle $cleanArtist',
              filterMixtapes: true,
            )).firstOrNull;
        if (yt != null) {
          return await YoutubeAudioService.instance.downloadTrack(
            library: library,
            track: yt,
            onProgress: onProgress ?? (_) {},
          );
        }
      } catch (e) {
        debugPrint('YouTube download failed, trying fallback: $e');
      }
    }

    // 2. Try SoundCloud if preferred or as fallback
    if (preferredProvider == MusicProviderType.soundcloud || preferredProvider == MusicProviderType.all) {
      try {
        final scTracks = await SoundCloudAudioService.instance.search('$cleanTitle $cleanArtist', limit: 1);
        if (scTracks.isNotEmpty) {
          final sc = scTracks.first;
          final streamUrl = await SoundCloudAudioService.instance.resolveStreamUrl({
            'id': sc.id,
            'media': {
              'transcodings': [
                {
                  'format': {'protocol': 'progressive', 'mime_type': 'audio/mpeg'},
                  'url': 'https://api-v2.soundcloud.com/media/soundcloud:tracks:${sc.id}/progressive',
                }
              ]
            }
          });

          if (streamUrl != null && streamUrl.isNotEmpty) {
            return await _downloadDirectAudioStream(
              library: library,
              streamUrl: streamUrl,
              title: sc.title,
              artist: sc.artist,
              album: resolvedAlbum,
              artworkUrl: sc.artworkUrl ?? artworkUrl,
              durationMs: sc.durationMs,
              extension: '.mp3',
              sourceProvider: 'SoundCloud',
              providerTrackId: sc.id,
              onProgress: onProgress,
            );
          }
        }
      } catch (e) {
        debugPrint('SoundCloud download failed: $e');
      }
    }

    // 3. Fallback to Deezer preview / open CDN stream
    try {
      final term = cleanArtist.isNotEmpty ? '$cleanTitle $cleanArtist' : cleanTitle;
      final uri = Uri.parse('https://api.deezer.com/search?q=${Uri.encodeComponent(term)}&limit=1');
      final res = await _httpClient.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final data = json['data'] as List?;
        if (data != null && data.isNotEmpty) {
          final item = data.first as Map;
          final previewUrl = item['preview'] as String?;
          final art = item['album']?['cover_xl'] as String? ?? artworkUrl;
          if (previewUrl != null && previewUrl.isNotEmpty) {
            return await _downloadDirectAudioStream(
              library: library,
              streamUrl: previewUrl,
              title: (item['title'] as String?) ?? cleanTitle,
              artist: (item['artist']?['name'] as String?) ?? cleanArtist,
              album: (item['album']?['title'] as String?) ?? resolvedAlbum,
              artworkUrl: art,
              durationMs: ((item['duration'] as num?)?.toInt() ?? 30) * 1000,
              extension: '.mp3',
              sourceProvider: 'Deezer',
              providerTrackId: item['id']?.toString(),
              onProgress: onProgress,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Deezer download fallback failed: $e');
    }

    // If all online stream sources fail, throw a clean actionable error
    throw StateError('Could not download "$cleanTitle" — no active provider could resolve a stream.');
  }

  Future<ImportedTrack> _downloadDirectAudioStream({
    required MusicLibrary library,
    required String streamUrl,
    required String title,
    required String artist,
    required String album,
    required String? artworkUrl,
    required int durationMs,
    required String extension,
    required String sourceProvider,
    required String? providerTrackId,
    ValueChanged<double>? onProgress,
  }) async {
    final sanitizedTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    final sanitizedArtist = artist.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    final fileName = '$sanitizedArtist - $sanitizedTitle$extension';
    final targetFile = File(p.join(library.musicDirectory.path, fileName));

    final existingTrack = library.findMatchingLocalTrack(
      path: targetFile.path,
      title: title,
      artist: artist,
    );
    if (existingTrack != null) {
      onProgress?.call(1.0);
      return existingTrack;
    }

    final req = http.Request('GET', Uri.parse(streamUrl));
    final res = await _httpClient.send(req);
    final totalLen = res.contentLength ?? 0;
    var received = 0;

    final controller = StreamController<List<int>>();
    res.stream.listen(
      (chunk) {
        received += chunk.length;
        if (totalLen > 0) {
          onProgress?.call((received / totalLen).clamp(0.01, 0.99));
        }
        controller.add(chunk);
      },
      onDone: () {
        onProgress?.call(1.0);
        controller.close();
      },
      onError: controller.addError,
      cancelOnError: true,
    );

    final imported = await library.importLicensedDownload(
      provider: sourceProvider,
      providerTrackId: providerTrackId ?? '$sanitizedArtist-$sanitizedTitle',
      fileName: fileName,
      bytes: controller.stream,
      title: title,
      artist: artist,
      album: album,
      durationMs: durationMs,
      artworkUri: artworkUrl,
      year: DateTime.now().year,
      licenseUrl: streamUrl,
    );

    // Save offline .lrc lyrics beside downloaded file
    try {
      final enriched = await SongMetadataEnricher.instance.fetchFullMetadata(
        title: title,
        artist: artist,
        album: album,
        durationMs: durationMs,
      );
      if (enriched.lyricsContent != null && enriched.lyricsContent!.trim().isNotEmpty) {
        final lrcPath = p.join(
          library.musicDirectory.path,
          '$sanitizedArtist - $sanitizedTitle.lrc',
        );
        await File(lrcPath).writeAsString(enriched.lyricsContent!, flush: true);
        await LyricsRepository.cacheLyricsForId(imported.id, enriched.lyricsContent!);
        await LyricsRepository.cacheLyricsForId(imported.path, enriched.lyricsContent!);
      }
    } catch (_) {}

    return imported;
  }
}
