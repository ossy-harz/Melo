import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:melo_player/app/melo_theme.dart';
import 'package:melo_player/features/library/imported_track.dart';
import 'package:melo_player/features/library/music_library.dart';
import 'package:melo_player/features/library/song_metadata_enricher.dart';
import 'package:melo_player/features/player/lyrics_repository.dart';
import 'package:melo_player/features/spotify/spotify_service.dart';
import 'package:melo_player/features/youtube/youtube_audio_service.dart';

enum LosslessAudioQuality {
  flacHiRes, // Lossless FLAC (16/24-bit 1411kbps+)
  highOpus,  // Maximum Bitrate Opus/AAC (256-320kbps)
  standard;  // Standard 128-160kbps

  String get label => switch (this) {
    LosslessAudioQuality.flacHiRes => 'Hi-Res Lossless FLAC',
    LosslessAudioQuality.highOpus => 'High Quality Master',
    LosslessAudioQuality.standard => 'Standard Audio',
  };

  String get shortLabel => switch (this) {
    LosslessAudioQuality.flacHiRes => 'Lossless FLAC (.flac)',
    LosslessAudioQuality.highOpus => 'High 320 kbps (.m4a)',
    LosslessAudioQuality.standard => 'Standard 128 kbps (.m4a)',
  };

  String get subtitle => switch (this) {
    LosslessAudioQuality.flacHiRes =>
      '16-bit / 48 kHz · Uncompressed .flac + Artwork & Synced Lyrics (~24 MB)',
    LosslessAudioQuality.highOpus =>
      '256–320 kbps AAC/Opus · Studio .m4a + Artwork & Synced Lyrics (~8 MB)',
    LosslessAudioQuality.standard =>
      '128 kbps AAC · Compact .m4a + Artwork & Synced Lyrics (~3.5 MB)',
  };

  String get badge => switch (this) {
    LosslessAudioQuality.flacHiRes => 'LOSSLESS FLAC',
    LosslessAudioQuality.highOpus => '320 KBPS AAC',
    LosslessAudioQuality.standard => '128 KBPS',
  };
}

class UniversalMusicTrack {
  const UniversalMusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    this.album = 'Single',
    this.durationMs = 0,
    this.artworkUrl,
    this.isrc,
    this.sourceLink,
    this.provider = 'Universal',
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final int durationMs;
  final String? artworkUrl;
  final String? isrc;
  final String? sourceLink;
  final String provider;

  String get durationFormatted {
    final d = Duration(milliseconds: durationMs);
    final minutes = d.inMinutes;
    final seconds = d.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class UniversalPlaylistResult {
  const UniversalPlaylistResult({
    required this.name,
    required this.author,
    required this.tracks,
    this.artworkUrl,
    this.sourceUrl = '',
  });

  final String name;
  final String author;
  final List<UniversalMusicTrack> tracks;
  final String? artworkUrl;
  final String sourceUrl;
}

class LosslessAudioService {
  LosslessAudioService._();
  static final LosslessAudioService instance = LosslessAudioService._();

  static const String _userQualityPrefKey = 'tone_lossless_audio_quality';
  static const String _askQualityPrefKey = 'tone_ask_quality_before_download';

  Future<LosslessAudioQuality> getPreferredQuality() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(_userQualityPrefKey);
    if (val == 'standard') return LosslessAudioQuality.standard;
    if (val == 'highOpus') return LosslessAudioQuality.highOpus;
    return LosslessAudioQuality.flacHiRes;
  }

  Future<void> setPreferredQuality(LosslessAudioQuality quality) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userQualityPrefKey, quality.name);
  }

  Future<bool> getAskQualityBeforeDownload() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_askQualityPrefKey) ?? true;
  }

  Future<void> setAskQualityBeforeDownload(bool ask) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_askQualityPrefKey, ask);
  }

  /// Displays a clean Mornye / Apple Music style Download Quality selector sheet
  /// when the user taps Download (or returns their saved default if "Ask every time" is off).
  Future<LosslessAudioQuality?> selectDownloadQuality(
    BuildContext context, {
    required String title,
    String? artist,
    bool forceSheet = false,
  }) async {
    final currentQuality = await getPreferredQuality();
    final askEveryTime = await getAskQualityBeforeDownload();
    if (!forceSheet && !askEveryTime) {
      return currentQuality;
    }
    if (!context.mounted) return currentQuality;

    return showModalBottomSheet<LosslessAudioQuality>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _DownloadQualityPickerSheet(
        title: title,
        artist: artist,
        initialQuality: currentQuality,
        initialAskEveryTime: askEveryTime,
      ),
    );
  }

  /// Parses and resolves any universal music link: Spotify, YouTube, Deezer, Apple Music.
  Future<UniversalPlaylistResult> resolveMusicLink(String rawInput) async {
    final input = rawInput.trim();
    if (input.isEmpty) {
      throw const FormatException('Please enter a music link or playlist URL.');
    }

    final uri = Uri.tryParse(input);
    if (uri == null || (!input.startsWith('http://') && !input.startsWith('https://'))) {
      throw const FormatException('Invalid URL format. Please paste a valid https:// link.');
    }

    final host = uri.host.toLowerCase();

    // 1. Spotify Link
    if (host.contains('spotify.com')) {
      final playlistId = SpotifyService.instance.extractPlaylistId(input);
      if (playlistId != null) {
        final data = await SpotifyService.instance.fetchPlaylist(playlistId);
        return UniversalPlaylistResult(
          name: data.title,
          author: data.owner ?? data.description,
          artworkUrl: data.artworkUrl,
          sourceUrl: input,
          tracks: data.tracks.map((t) => UniversalMusicTrack(
            id: t.id,
            title: t.title,
            artist: t.artist,
            album: t.album,
            durationMs: t.durationMs,
            artworkUrl: t.artworkUrl ?? data.artworkUrl,
            provider: 'Spotify',
            sourceLink: 'https://open.spotify.com/track/${t.id}',
          )).toList(),
        );
      }
      
      final trackMatch = RegExp(r'open\.spotify\.com/(?:intl-[a-z]{2}/)?track/([a-zA-Z0-9]+)').firstMatch(input);
      if (trackMatch != null) {
        final trackId = trackMatch.group(1)!;
        String title = 'Spotify Track';
        String artist = 'Spotify Artist';
        String? artworkUrl;
        try {
          final oe = await http.get(Uri.parse('https://open.spotify.com/oembed?url=https://open.spotify.com/track/$trackId'));
          if (oe.statusCode == 200) {
            final oeData = jsonDecode(oe.body) as Map<String, dynamic>;
            title = oeData['title'] as String? ?? title;
            artist = oeData['author_name'] as String? ?? artist;
            artworkUrl = oeData['thumbnail_url'] as String?;
          }
        } catch (_) {}

        return UniversalPlaylistResult(
          name: title,
          author: artist,
          artworkUrl: artworkUrl,
          sourceUrl: input,
          tracks: [
            UniversalMusicTrack(
              id: trackId,
              title: title,
              artist: artist,
              durationMs: 0,
              artworkUrl: artworkUrl,
              provider: 'Spotify',
              sourceLink: input,
            ),
          ],
        );
      }
    }

    // 2. Deezer Link (Playlist, Album, or Track)
    if (host.contains('deezer.com')) {
      return _resolveDeezerLink(uri);
    }

    // 3. YouTube / YouTube Music Link
    if (host.contains('youtube.com') || host.contains('youtu.be')) {
      return _resolveYoutubeLink(uri, input);
    }

    // 4. Apple Music / Universal fallback
    return _resolveGenericMusicLink(uri, input);
  }

  Future<UniversalPlaylistResult> _resolveDeezerLink(Uri uri) async {
    final segments = uri.pathSegments;
    final typeIndex = segments.indexWhere((s) => ['playlist', 'album', 'track'].contains(s.toLowerCase()));
    if (typeIndex == -1 || typeIndex + 1 >= segments.length) {
      throw const FormatException('Could not identify Deezer playlist, album, or track identifier.');
    }

    final type = segments[typeIndex].toLowerCase();
    final id = segments[typeIndex + 1];

    final res = await http.get(Uri.parse('https://api.deezer.com/$type/$id')).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw StateError('Deezer API returned status ${res.statusCode}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data.containsKey('error')) {
      throw StateError('Deezer error: ${data['error']?['message'] ?? 'Unknown'}');
    }

    if (type == 'track') {
      final title = data['title'] as String? ?? 'Unknown Title';
      final artist = data['artist']?['name'] as String? ?? 'Unknown Artist';
      final album = data['album']?['title'] as String? ?? 'Single';
      final cover = data['album']?['cover_big'] as String? ?? data['album']?['cover_medium'] as String?;
      final duration = (data['duration'] as num? ?? 0).toInt() * 1000;
      final isrc = data['isrc'] as String?;

      return UniversalPlaylistResult(
        name: title,
        author: artist,
        artworkUrl: cover,
        sourceUrl: uri.toString(),
        tracks: [
          UniversalMusicTrack(
            id: 'dz_$id',
            title: title,
            artist: artist,
            album: album,
            durationMs: duration,
            artworkUrl: cover,
            isrc: isrc,
            provider: 'Deezer',
            sourceLink: uri.toString(),
          ),
        ],
      );
    }

    // Playlist or Album
    final name = (data['title'] ?? data['name']) as String? ?? 'Deezer Collection';
    final author = (data['creator']?['name'] ?? data['artist']?['name']) as String? ?? 'Deezer';
    final cover = (data['picture_big'] ?? data['cover_big'] ?? data['picture_medium']) as String?;
    final tracksList = (data['tracks']?['data'] ?? data['tracks']) as List? ?? [];

    final tracks = <UniversalMusicTrack>[];
    for (final item in tracksList) {
      if (item is! Map<String, dynamic>) continue;
      final tId = item['id']?.toString() ?? '';
      final tTitle = item['title'] as String? ?? 'Unknown';
      final tArtist = item['artist']?['name'] as String? ?? author;
      final tDuration = (item['duration'] as num? ?? 0).toInt() * 1000;
      final tCover = item['album']?['cover_big'] as String? ?? cover;
      final isrc = item['isrc'] as String?;

      tracks.add(
        UniversalMusicTrack(
          id: 'dz_$tId',
          title: tTitle,
          artist: tArtist,
          album: name,
          durationMs: tDuration,
          artworkUrl: tCover,
          isrc: isrc,
          provider: 'Deezer',
          sourceLink: uri.toString(),
        ),
      );
    }

    return UniversalPlaylistResult(
      name: name,
      author: author,
      artworkUrl: cover,
      sourceUrl: uri.toString(),
      tracks: tracks,
    );
  }

  Future<UniversalPlaylistResult> _resolveYoutubeLink(Uri uri, String input) async {
    final listParam = uri.queryParameters['list'];
    final vParam = uri.queryParameters['v'] ?? (uri.host == 'youtu.be' ? uri.pathSegments.firstOrNull : null);

    // If it's a playlist
    if (listParam != null && listParam.isNotEmpty) {
      final endpoint = 'https://yt.chocolatemoo53.com/api/v1/playlists/$listParam';
      try {
        final res = await http.get(Uri.parse(endpoint)).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final name = data['title'] as String? ?? 'YouTube Playlist';
          final author = data['author'] as String? ?? 'YouTube';
          final videos = (data['videos'] as List?) ?? [];
          final tracks = <UniversalMusicTrack>[];

          for (final v in videos) {
            if (v is! Map<String, dynamic>) continue;
            final vId = v['videoId'] as String? ?? '';
            final vTitle = v['title'] as String? ?? 'Unknown';
            final vAuthor = v['author'] as String? ?? author;
            final vSeconds = (v['lengthSeconds'] as num? ?? 0).toInt();
            final thumbs = v['videoThumbnails'] as List?;
            final thumbUrl = thumbs?.isNotEmpty == true ? thumbs!.last['url'] as String? : null;

            tracks.add(
              UniversalMusicTrack(
                id: vId,
                title: vTitle,
                artist: vAuthor,
                album: name,
                durationMs: vSeconds * 1000,
                artworkUrl: thumbUrl,
                provider: 'YouTube',
                sourceLink: 'https://www.youtube.com/watch?v=$vId',
              ),
            );
          }

          if (tracks.isNotEmpty) {
            return UniversalPlaylistResult(
              name: name,
              author: author,
              artworkUrl: tracks.first.artworkUrl,
              sourceUrl: input,
              tracks: tracks,
            );
          }
        }
      } catch (e) {
        debugPrint('Direct Invidious playlist resolution failed: $e');
      }
    }

    // Single YouTube video
    if (vParam != null && vParam.isNotEmpty) {
      // Fetch oEmbed for clean title/author
      String title = 'YouTube Track';
      String author = 'YouTube';
      String? thumb;
      try {
        final oe = await http.get(Uri.parse('https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=$vParam&format=json'));
        if (oe.statusCode == 200) {
          final oeData = jsonDecode(oe.body) as Map<String, dynamic>;
          title = oeData['title'] as String? ?? title;
          author = oeData['author_name'] as String? ?? author;
          thumb = oeData['thumbnail_url'] as String?;
        }
      } catch (_) {}

      return UniversalPlaylistResult(
        name: title,
        author: author,
        artworkUrl: thumb,
        sourceUrl: input,
        tracks: [
          UniversalMusicTrack(
            id: vParam,
            title: title,
            artist: author,
            album: 'YouTube Stream',
            durationMs: 0,
            artworkUrl: thumb,
            provider: 'YouTube',
            sourceLink: input,
          ),
        ],
      );
    }

    throw const FormatException('Could not extract playlist or video ID from YouTube link.');
  }

  Future<UniversalPlaylistResult> _resolveGenericMusicLink(Uri uri, String input) async {
    // Attempt search based on URL path segments
    final cleanSegments = uri.pathSegments.where((s) => s.isNotEmpty && s.length > 2).join(' ');
    if (cleanSegments.isNotEmpty) {
      final results = await YoutubeAudioService.instance.search(cleanSegments);
      if (results.isNotEmpty) {
        final first = results.first;
        return UniversalPlaylistResult(
          name: first.title,
          author: first.author,
          artworkUrl: first.thumbnailUrl,
          sourceUrl: input,
          tracks: [
            UniversalMusicTrack(
              id: first.id,
              title: first.title,
              artist: first.author,
              album: 'Music Link',
              durationMs: first.duration.inMilliseconds,
              artworkUrl: first.thumbnailUrl,
              provider: 'Universal',
              sourceLink: input,
            ),
          ],
        );
      }
    }
    throw FormatException('Unable to resolve music metadata from: $input');
  }

  /// Downloads a universal track with requested quality and ensures no duplicates are downloaded.
  Future<ImportedTrack> downloadTrackInQuality({
    required UniversalMusicTrack track,
    required MusicLibrary library,
    required LosslessAudioQuality quality,
    required ValueChanged<double> onProgress,
  }) async {
    // 0. Coordinate with library: if track is already downloaded on device, return it immediately
    if (library.isTrackDownloaded(
      providerTrackId: track.id,
      title: track.title,
      artist: track.artist,
    )) {
      final existing = library.findMatchingLocalTrack(
        providerTrackId: track.id,
        title: track.title,
        artist: track.artist,
      );
      if (existing != null) {
        debugPrint('Track "${track.title}" is already in local library: ${existing.path}');
        onProgress(1.0);
        return existing;
      }
    }

    // 1. Resolve matching high-fidelity stream & rich metadata/lyrics in parallel
    final ytQuery = '${track.title} ${track.artist}';
    final results = await YoutubeAudioService.instance.search(ytQuery);
    if (results.isEmpty) {
      throw StateError('Could not find matching audio source for "${track.title}"');
    }

    final matched = results.first;
    final metadataFuture = SongMetadataEnricher.instance.fetchFullMetadata(
      title: track.title,
      artist: track.artist,
      album: track.album,
      durationMs: track.durationMs > 0
          ? track.durationMs
          : matched.duration.inMilliseconds,
      fallbackArtworkUrl: track.artworkUrl ?? matched.thumbnailUrl,
      artworkDirectory: library.musicDirectory,
      trackIdForCache: track.id,
    );

    final streamDetails = await YoutubeAudioService.instance.getStreamDetails(
      matched.id,
      quality: quality == LosslessAudioQuality.standard
          ? YoutubeAudioQuality.standard
          : YoutubeAudioQuality.highest,
    );
    final enriched = await metadataFuture;

    final codec = streamDetails.codec;
    final fileExt = streamDetails.codec == 'AAC' ? 'm4a' : 'webm';
    debugPrint('Downloading "${track.title}" using codec: $codec');

    final localArtworkUri =
        enriched.localArtworkUri ??
        enriched.artworkUrl ??
        track.artworkUrl ??
        matched.thumbnailUrl;

    // 3. Stream binary chunks to disk using 512 KB range chunks to bypass YouTube's 1 MiB throttle
    final streamWithProgress = YoutubeAudioService.instance.streamAudioBytes(
      streamDetails,
      onProgress: onProgress,
    );

    final finalTitle = enriched.title.isNotEmpty ? enriched.title : track.title;
    final finalArtist = enriched.artist.isNotEmpty ? enriched.artist : track.artist;
    final finalAlbum = enriched.album.isNotEmpty ? enriched.album : track.album;

    final safeTitle = finalTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final fileName = '$safeTitle.$fileExt';

    final imported = await library.importLicensedDownload(
      provider: track.provider,
      providerTrackId: track.id,
      fileName: fileName,
      bytes: streamWithProgress,
      title: finalTitle,
      artist: finalArtist,
      album: finalAlbum,
      durationMs: track.durationMs > 0
          ? track.durationMs
          : (enriched.durationMs ?? matched.duration.inMilliseconds),
      artworkUri: localArtworkUri,
      year: enriched.year ?? DateTime.now().year,
      genre: enriched.genre,
      trackNumber: enriched.trackNumber,
      licenseUrl: track.sourceLink ?? 'https://tone.player',
      convertToFlac: quality == LosslessAudioQuality.flacHiRes,
    );

    if (enriched.lyricsContent != null && enriched.lyricsContent!.trim().isNotEmpty) {
      try {
        final audioPath = imported.path;
        final dotIndex = audioPath.lastIndexOf('.');
        final baseAudioPath = dotIndex > 0 ? audioPath.substring(0, dotIndex) : audioPath;
        final lrcFile = File('$baseAudioPath.lrc');
        await lrcFile.writeAsString(enriched.lyricsContent!);
        await LyricsRepository.cacheLyricsForId(imported.id, enriched.lyricsContent!);
        await LyricsRepository.cacheLyricsForId(imported.path, enriched.lyricsContent!);
        await LyricsRepository.cacheLyricsForSong(
          title: finalTitle,
          artist: finalArtist,
          rawLrc: enriched.lyricsContent!,
        );
      } catch (e) {
        debugPrint('Failed to write synchronized .lrc lyrics: $e');
      }
    }

    onProgress(1.0);
    return imported;
  }

  /// Downloads an entire playlist, skipping duplicate tracks and creating a local library playlist.
  Future<void> downloadFullPlaylist({
    required UniversalPlaylistResult playlist,
    required MusicLibrary library,
    required LosslessAudioQuality quality,
    required void Function(int current, int total, String trackTitle) onProgress,
    required void Function(int downloaded, int skipped) onComplete,
  }) async {
    var downloaded = 0;
    var skipped = 0;
    final importedTrackIds = <String>[];

    for (var i = 0; i < playlist.tracks.length; i++) {
      final track = playlist.tracks[i];
      onProgress(i + 1, playlist.tracks.length, track.title);

      if (library.isTrackDownloaded(
        providerTrackId: track.id,
        title: track.title,
        artist: track.artist,
      )) {
        final existing = library.findMatchingLocalTrack(
          providerTrackId: track.id,
          title: track.title,
          artist: track.artist,
        );
        if (existing != null) importedTrackIds.add(existing.id);
        skipped++;
        continue;
      }

      try {
        final imported = await downloadTrackInQuality(
          track: track,
          library: library,
          quality: quality,
          onProgress: (_) {},
        );
        importedTrackIds.add(imported.id);
        downloaded++;
      } catch (e) {
        debugPrint('Failed to download "${track.title}": $e');
      }
    }

    // Create or update local Tone playlist
    if (importedTrackIds.isNotEmpty) {
      try {
        final newPlaylist = await library.createPlaylist(playlist.name);
        await library.addTracksToPlaylist(newPlaylist.id, importedTrackIds);
      } catch (e) {
        debugPrint('Could not create local playlist entry: $e');
      }
    }

    onComplete(downloaded, skipped);
  }
}

class _DownloadQualityPickerSheet extends StatefulWidget {
  const _DownloadQualityPickerSheet({
    required this.title,
    this.artist,
    required this.initialQuality,
    required this.initialAskEveryTime,
  });

  final String title;
  final String? artist;
  final LosslessAudioQuality initialQuality;
  final bool initialAskEveryTime;

  @override
  State<_DownloadQualityPickerSheet> createState() =>
      _DownloadQualityPickerSheetState();
}

class _DownloadQualityPickerSheetState
    extends State<_DownloadQualityPickerSheet> {
  late LosslessAudioQuality _selected;
  late bool _askEveryTime;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialQuality;
    _askEveryTime = widget.initialAskEveryTime;
  }

  Future<void> _confirm(LosslessAudioQuality quality) async {
    await LosslessAudioService.instance.setPreferredQuality(quality);
    await LosslessAudioService.instance.setAskQualityBeforeDownload(
      _askEveryTime,
    );
    if (!mounted) return;
    Navigator.of(context).pop(quality);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Material(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(28),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: colors.onSurfaceVariant.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: MeloColors.cherry.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.high_quality_rounded,
                        color: MeloColors.cherry,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Download Audio Quality',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.artist != null && widget.artist!.isNotEmpty
                                ? '${widget.title} · ${widget.artist}'
                                : widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                for (final q in LosslessAudioQuality.values) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        setState(() => _selected = q);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: _selected == q
                              ? MeloColors.cherry.withValues(alpha: 0.13)
                              : colors.surfaceContainerLow,
                          border: Border.all(
                            color: _selected == q
                                ? MeloColors.cherry
                                : colors.outlineVariant.withValues(alpha: 0.35),
                            width: _selected == q ? 1.6 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _selected == q
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_off_rounded,
                              color: _selected == q
                                  ? MeloColors.cherry
                                  : colors.onSurfaceVariant,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          q.label,
                                          style: textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _selected == q
                                              ? MeloColors.cherry
                                              : colors.surfaceContainerHighest,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          q.badge,
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            color: _selected == q
                                                ? Colors.white
                                                : colors.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    q.subtitle,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colors.onSurfaceVariant,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                SwitchListTile.adaptive(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  dense: true,
                  title: const Text(
                    'Ask quality before every download',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Turn off to always download in ${_selected.shortLabel} automatically.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  value: _askEveryTime,
                  onChanged: (v) => setState(() => _askEveryTime = v),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: () => _confirm(_selected),
                    icon: const Icon(Icons.download_rounded),
                    label: Text('Download in ${_selected.shortLabel}'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
