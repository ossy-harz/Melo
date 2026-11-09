import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:melo_player/app/melo_theme.dart';
import 'package:melo_player/features/home/curated_playlist_screen.dart';
import 'package:melo_player/features/library/music_library.dart';
import 'package:melo_player/features/player/animated_equalizer_indicator.dart';
import 'package:melo_player/features/sources/lossless_audio_service.dart';
import 'package:melo_player/features/youtube/youtube_audio_service.dart';

void showCuratedPlaylistPreviewSheet({
  required BuildContext context,
  required CuratedPlaylistPreset preset,
  required AudioHandler? audioHandler,
  required MusicLibrary? library,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => CuratedPlaylistPreviewSheet(
      preset: preset,
      audioHandler: audioHandler,
      library: library,
    ),
  );
}

class CuratedPlaylistPreviewSheet extends StatefulWidget {
  const CuratedPlaylistPreviewSheet({
    required this.preset,
    required this.audioHandler,
    required this.library,
    super.key,
  });

  final CuratedPlaylistPreset preset;
  final AudioHandler? audioHandler;
  final MusicLibrary? library;

  @override
  State<CuratedPlaylistPreviewSheet> createState() =>
      _CuratedPlaylistPreviewSheetState();
}

class _CuratedPlaylistPreviewSheetState
    extends State<CuratedPlaylistPreviewSheet> {
  static final Map<String, List<YoutubeTrack>> _previewCache = {};
  List<YoutubeTrack> _tracks = const [];
  bool _loading = true;
  String? _errorMessage;
  final Map<String, double> _downloadProgress = {};

  @override
  void initState() {
    super.initState();
    unawaited(_loadTracks());
  }

  Future<void> _loadTracks() async {
    final cached = _previewCache[widget.preset.title];
    if (cached != null && cached.isNotEmpty) {
      if (mounted) {
        setState(() {
          _tracks = cached;
          _loading = false;
        });
      }
      return;
    }

    try {
      final results = await YoutubeAudioService.instance.search(
        widget.preset.searchQuery,
        filterMixtapes: true,
      );
      final filtered = results.where((t) {
        if (t.duration.inSeconds > 660) return false;
        if (t.duration.inSeconds > 0 && t.duration.inSeconds < 40) return false;
        if (YoutubeAudioService.isMixtapeOrNonstop(t.title, t.duration)) {
          return false;
        }
        return true;
      }).toList();

      _previewCache[widget.preset.title] = filtered;
      if (mounted) {
        setState(() {
          _tracks = filtered;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _playTrack(int index, {bool shuffle = false}) async {
    final handler = widget.audioHandler;
    if (handler == null || _tracks.isEmpty) return;

    final mediaItems = _tracks.map((t) {
      return MediaItem(
        id: 'yt_${t.id}',
        title: t.title,
        artist: t.author,
        album: widget.preset.title,
        duration: t.duration,
        artUri: t.thumbnailUrl != null ? Uri.tryParse(t.thumbnailUrl!) : null,
        extras: {
          'source': 'youtube',
          'youtubeId': t.id,
          'playlistTitle': widget.preset.title,
        },
      );
    }).toList();

    await handler.updateQueue(mediaItems);
    if (shuffle) {
      await handler.setShuffleMode(AudioServiceShuffleMode.all);
    } else {
      await handler.setShuffleMode(AudioServiceShuffleMode.none);
    }
    await handler.skipToQueueItem(index);
    await handler.play();
  }

  Future<void> _downloadSingleTrack(YoutubeTrack track) async {
    final lib = widget.library;
    if (lib == null || _downloadProgress.containsKey(track.id)) return;

    final chosen = await LosslessAudioService.instance.selectDownloadQuality(
      context,
      title: track.title,
      artist: track.author,
    );
    if (chosen == null || !mounted) return;

    setState(() => _downloadProgress[track.id] = 0.05);
    try {
      await YoutubeAudioService.instance.downloadTrack(
        track: track,
        library: lib,
        qualityOverride: chosen,
        onProgress: (p) {
          if (mounted) setState(() => _downloadProgress[track.id] = p);
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded "${track.title}" to phone'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not download track: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _downloadProgress.remove(track.id));
      }
    }
  }

  void _openFullScreen() {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CuratedPlaylistScreen(
          preset: widget.preset,
          audioHandler: widget.audioHandler,
          library: widget.library,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preset = widget.preset;
    final currentItem = widget.audioHandler?.mediaItem.value;

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xF2121014),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4.5,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header Row with Cover Thumbnail, Genre Badge, Title, Subtitle, Close (X)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _openFullScreen,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 58,
                      height: 58,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: preset.gradient,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ),
                          if (preset.coverUrl != null &&
                              preset.coverUrl!.isNotEmpty)
                            Image.network(
                              preset.coverUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Center(
                                child: Icon(preset.icon,
                                    color: Colors.white, size: 28),
                              ),
                            )
                          else
                            Center(
                              child: Icon(preset.icon,
                                  color: Colors.white, size: 28),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: GestureDetector(
                    onTap: _openFullScreen,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          preset.genre.toUpperCase(),
                          style: const TextStyle(
                            color: MeloColors.cherry,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          preset.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          preset.curatorSubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Dual Action Row: [Stream Playlist] (red) & [Shuffle] (glass)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: MeloColors.cherry,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 22),
                    label: const Text(
                      'Stream Playlist',
                      style:
                          TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                    ),
                    onPressed: _tracks.isEmpty
                        ? null
                        : () => _playTrack(0, shuffle: false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.10),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.shuffle_rounded, size: 20),
                    label: const Text(
                      'Shuffle',
                      style:
                          TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                    ),
                    onPressed: _tracks.isEmpty
                        ? null
                        : () => _playTrack(0, shuffle: true),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Track List
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: MeloColors.cherry,
                      strokeWidth: 2.5,
                    ),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Could not load tracks: $_errorMessage',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white70),
                              ),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: () {
                                  setState(() => _loading = true);
                                  unawaited(_loadTracks());
                                },
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: _tracks.length,
                        itemBuilder: (context, index) {
                          final track = _tracks[index];
                          final isPlaying = currentItem != null &&
                              (currentItem.id == 'yt_${track.id}' ||
                                  currentItem.title.trim().toLowerCase() ==
                                      track.title.trim().toLowerCase());
                          final progress = _downloadProgress[track.id];

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Material(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _playTrack(index),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: SizedBox(
                                          width: 46,
                                          height: 46,
                                          child: track.thumbnailUrl != null
                                              ? Image.network(
                                                  track.thumbnailUrl!,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (_, _, _) => Container(
                                                    color: Colors.white10,
                                                    child: const Icon(
                                                      Icons.music_note_rounded,
                                                      color: Colors.white54,
                                                    ),
                                                  ),
                                                )
                                              : Container(
                                                  color: Colors.white10,
                                                  child: const Icon(
                                                    Icons.music_note_rounded,
                                                    color: Colors.white54,
                                                  ),
                                                ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              track.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: isPlaying
                                                    ? MeloColors.cherry
                                                    : Colors.white,
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${track.author} · ${track.durationString}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white54,
                                                fontSize: 12.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isPlaying) ...[
                                        const AnimatedEqualizerIndicator(
                                          color: MeloColors.cherry,
                                          barCount: 3,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      if (progress != null)
                                        SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            value: progress,
                                            strokeWidth: 2.2,
                                            color: MeloColors.cherry,
                                          ),
                                        )
                                      else
                                        IconButton(
                                          tooltip: 'Download track',
                                          icon: const Icon(
                                            Icons.arrow_circle_down_outlined,
                                            color: Colors.white60,
                                            size: 22,
                                          ),
                                          onPressed: () =>
                                              _downloadSingleTrack(track),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
