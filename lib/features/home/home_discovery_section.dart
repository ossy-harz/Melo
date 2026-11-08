import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:melo_player/app/melo_theme.dart';
import 'package:melo_player/features/library/music_library.dart';
import 'package:melo_player/features/player/mini_player.dart';
import 'package:melo_player/features/sources/lossless_audio_service.dart';
import 'package:melo_player/features/youtube/youtube_audio_service.dart';

class LiveDiscoverySection extends StatefulWidget {
  const LiveDiscoverySection({
    required this.audioHandler,
    required this.library,
    super.key,
  });

  final AudioHandler? audioHandler;
  final MusicLibrary? library;

  @override
  State<LiveDiscoverySection> createState() => _LiveDiscoverySectionState();
}

class _LiveDiscoverySectionState extends State<LiveDiscoverySection> {
  static const Map<String, String> _genreQueries = {
    'Trending': 'Top Global Hits 2025 Official Audio',
    'Afrobeats': 'Afrobeats Hits 2025 Official Audio',
    'Hip-Hop': 'Hip Hop Rap Hits 2025 Official Audio',
    'R&B': 'RnB Soul Hits 2025 Official Audio',
    'Pop': 'Pop Hits 2025 Official Audio',
    'House & Dance': 'Melodic House Electronic Hits Official Audio',
  };

  static final Map<String, List<YoutubeTrack>> _cachedByCategory = {};

  String _selectedCategory = 'Trending';
  List<YoutubeTrack> _tracks = const [];
  bool _isLoading = false;
  final Map<String, double> _downloadProgress = {};

  @override
  void initState() {
    super.initState();
    final cached = _cachedByCategory[_selectedCategory];
    if (cached != null && cached.isNotEmpty) {
      _tracks = cached;
    } else if (!kIsWeb && Platform.isAndroid) {
      unawaited(_loadCategory(_selectedCategory));
    }
  }

  Future<void> _loadCategory(String category) async {
    final cached = _cachedByCategory[category];
    if (cached != null && cached.isNotEmpty) {
      if (mounted) {
        setState(() {
          _selectedCategory = category;
          _tracks = cached;
          _isLoading = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _selectedCategory = category;
        _isLoading = true;
      });
    }
    try {
      final query = _genreQueries[category] ?? _genreQueries['Trending']!;
      final results = await YoutubeAudioService.instance.search(query);
      final validSongs = results
          .where((t) => t.duration.inSeconds == 0 || t.duration.inSeconds >= 30)
          .take(8)
          .toList(growable: false);
      _cachedByCategory[category] = validSongs;
      if (mounted && _selectedCategory == category) {
        setState(() {
          _tracks = validSongs;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted && _selectedCategory == category) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _streamTrack(YoutubeTrack track) async {
    final handler = widget.audioHandler;
    if (handler == null) return;

    final localMatch = widget.library?.findMatchingLocalTrack(
      providerTrackId: track.id,
      title: track.title,
      artist: track.author,
    );
    if (localMatch != null && widget.library != null) {
      final idx = widget.library!.indexOfTrack(localMatch.id);
      if (idx >= 0) {
        await widget.library!.playTrack(handler, idx);
        return;
      }
    }

    final ordered = [
      track,
      ..._tracks.where((t) => t.id != track.id).take(7),
    ];
    final items = ordered
        .map(
          (t) => MediaItem(
            id: 'youtube:${t.id}',
            title: t.title,
            artist: t.author,
            album: t.album ?? 'Melo Discovery',
            duration: t.duration > Duration.zero ? t.duration : null,
            artUri: t.thumbnailUrl != null
                ? Uri.tryParse(t.thumbnailUrl!)
                : null,
            extras: <String, Object?>{
              'videoId': t.id,
              'source': 'youtube',
            },
          ),
        )
        .toList(growable: false);

    await handler.updateQueue(items);
    await handler.skipToQueueItem(0);
    await handler.play();
  }

  Future<void> _downloadFlac(YoutubeTrack track) async {
    final library = widget.library;
    if (library == null) return;
    if (_downloadProgress.containsKey(track.id)) return;

    final chosenQuality = await LosslessAudioService.instance.selectDownloadQuality(
      context,
      title: track.title,
      artist: track.author,
    );
    if (chosenQuality == null || !mounted) return;

    setState(() => _downloadProgress[track.id] = 0.02);
    try {
      await YoutubeAudioService.instance.downloadTrack(
        track: track,
        library: library,
        qualityOverride: chosenQuality,
        onProgress: (p) {
          if (mounted) {
            setState(() => _downloadProgress[track.id] = p);
          }
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Saved "${track.title}" (${chosenQuality.shortLabel} + Artwork + Synced Lyrics)',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) {
        setState(() => _downloadProgress.remove(track.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.explore_rounded,
              size: 18,
              color: MeloColors.cherry,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Discover New Music',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Refresh discovery',
              visualDensity: VisualDensity.compact,
              onPressed: _isLoading
                  ? null
                  : () {
                      _cachedByCategory.remove(_selectedCategory);
                      unawaited(_loadCategory(_selectedCategory));
                    },
              icon: const Icon(Icons.refresh_rounded, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final category in _genreQueries.keys) ...[
                ChoiceChip(
                  label: Text(category),
                  selected: _selectedCategory == category,
                  onSelected: (selected) {
                    if (selected) {
                      unawaited(_loadCategory(category));
                    }
                  },
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
            ),
          )
        else if (_tracks.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(MeloRadii.md),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.music_note_rounded,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tap any genre above to load trending studio songs (>30s) with instant stream & Lossless FLAC download.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => unawaited(_loadCategory(_selectedCategory)),
                  child: const Text('Load'),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 214,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: (_tracks.length / 2).ceil(),
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, colIndex) {
                final firstIdx = colIndex * 2;
                final secondIdx = firstIdx + 1;
                return SizedBox(
                  width: 288,
                  child: Column(
                    children: [
                      _buildDiscoveryTrackTile(_tracks[firstIdx], colors),
                      const SizedBox(height: 10),
                      if (secondIdx < _tracks.length)
                        _buildDiscoveryTrackTile(_tracks[secondIdx], colors),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildDiscoveryTrackTile(YoutubeTrack track, ColorScheme colors) {
    final progress = _downloadProgress[track.id];
    final isDownloaded =
        widget.library?.isTrackDownloaded(
          providerTrackId: track.id,
          title: track.title,
          artist: track.author,
        ) ??
        false;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _streamTrack(track),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              AlbumArtwork(
                size: 48,
                title: track.title,
                artworkUri: track.thumbnailUrl != null
                    ? Uri.tryParse(track.thumbnailUrl!)
                    : null,
                borderRadius: 10,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${track.author} · ${track.durationFormatted}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (progress != null)
                SizedBox(
                  width: 28,
                  height: 28,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: CircularProgressIndicator(
                      value: progress > 0.05 ? progress : null,
                      strokeWidth: 2.2,
                    ),
                  ),
                )
              else if (isDownloaded)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: Colors.greenAccent,
                    size: 20,
                  ),
                )
              else if (widget.library != null)
                IconButton(
                  tooltip: 'Download to device',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _downloadFlac(track),
                  icon: const Icon(
                    Icons.download_for_offline_outlined,
                    size: 21,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
