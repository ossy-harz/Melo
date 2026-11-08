import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:melo_player/app/melo_theme.dart';
import 'package:melo_player/features/library/music_library.dart';
import 'package:melo_player/features/sources/lossless_audio_service.dart';
import 'package:melo_player/features/youtube/youtube_audio_service.dart';

class CuratedPlaylistPreset {
  const CuratedPlaylistPreset({
    required this.title,
    required this.curatorSubtitle,
    required this.badge,
    required this.searchQuery,
    required this.gradient,
    required this.icon,
  });

  final String title;
  final String curatorSubtitle;
  final String badge;
  final String searchQuery;
  final List<Color> gradient;
  final IconData icon;
}

/// Full-screen Apple Music & Spotify-inspired curated playlist view.
/// Features ambient gradient header, high-res 4-cover collage, curator metadata,
/// dual Play/Shuffle action row, and clean, seamless transparent song rows.
class CuratedPlaylistScreen extends StatefulWidget {
  const CuratedPlaylistScreen({
    required this.preset,
    required this.audioHandler,
    required this.library,
    super.key,
  });

  final CuratedPlaylistPreset preset;
  final AudioHandler? audioHandler;
  final MusicLibrary? library;

  @override
  State<CuratedPlaylistScreen> createState() => _CuratedPlaylistScreenState();
}

class _CuratedPlaylistScreenState extends State<CuratedPlaylistScreen> {
  static final Map<String, List<YoutubeTrack>> _cache = {};
  List<YoutubeTrack> _tracks = const [];
  bool _loading = true;
  String? _errorMessage;
  final Map<String, double> _downloadProgress = {};
  bool _isDownloadingAll = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadTracks());
  }

  Future<void> _loadTracks() async {
    final cached = _cache[widget.preset.title];
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

      // Take top 25 individual tracks for the playlist
      final valid = results.take(25).toList(growable: false);
      _cache[widget.preset.title] = valid;

      if (mounted) {
        setState(() {
          _tracks = valid;
          _loading = false;
          _errorMessage = valid.isEmpty ? 'No tracks found for this playlist.' : null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = 'Could not load playlist tracks: $e';
        });
      }
    }
  }

  String get _totalDurationText {
    var totalSec = 0;
    for (final t in _tracks) {
      totalSec += t.duration.inSeconds;
    }
    final duration = Duration(seconds: totalSec);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '$hours hr ${minutes > 0 ? '$minutes min' : ''}';
    }
    return '$minutes min';
  }

  Future<void> _playPlaylist({required bool shuffle, int startIndex = 0}) async {
    final handler = widget.audioHandler;
    if (handler == null || _tracks.isEmpty) return;

    final ordered = [..._tracks];
    if (shuffle) {
      ordered.shuffle();
    } else if (startIndex > 0 && startIndex < ordered.length) {
      final lead = ordered.removeAt(startIndex);
      ordered.insert(0, lead);
    }

    final items = ordered.map((t) {
      final local = widget.library?.findMatchingLocalTrack(
        providerTrackId: t.id,
        title: t.title,
        artist: t.author,
      );
      return local != null ? local.toMediaItem() : t.toMediaItem();
    }).toList(growable: false);

    await handler.updateQueue(items);
    await handler.skipToQueueItem(0);
    await handler.play();

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Playing "${widget.preset.title}"'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _downloadSingleTrack(YoutubeTrack track) async {
    final library = widget.library;
    if (library == null || _downloadProgress.containsKey(track.id)) return;

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
          if (mounted) setState(() => _downloadProgress[track.id] = p);
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Saved "${track.title}" (${chosenQuality.shortLabel}) to Melo Library'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not download "${track.title}": $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) setState(() => _downloadProgress.remove(track.id));
    }
  }

  Future<void> _downloadAllTracks() async {
    final library = widget.library;
    if (library == null || _tracks.isEmpty || _isDownloadingAll) return;

    final unDownloaded = _tracks.where((t) {
      return !library.isTrackDownloaded(
        providerTrackId: t.id,
        title: t.title,
        artist: t.author,
      );
    }).toList();

    if (unDownloaded.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All tracks in this playlist are already downloaded!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Download ${unDownloaded.length} tracks?'),
        content: Text(
          'Download all songs in "${widget.preset.title}" for offline listening with high-res artwork and synced lyrics.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Download All'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDownloadingAll = true);
    var savedCount = 0;

    for (final track in unDownloaded) {
      if (!mounted) break;
      try {
        setState(() => _downloadProgress[track.id] = 0.05);
        await YoutubeAudioService.instance.downloadTrack(
          track: track,
          library: library,
          onProgress: (p) {
            if (mounted) setState(() => _downloadProgress[track.id] = p);
          },
        );
        savedCount++;
      } catch (_) {} finally {
        if (mounted) setState(() => _downloadProgress.remove(track.id));
      }
    }

    if (!mounted) return;
    setState(() => _isDownloadingAll = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloaded $savedCount tracks from "${widget.preset.title}"'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showTrackDetails(YoutubeTrack track) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: track.thumbnailUrl != null
                          ? Image.network(
                              track.thumbnailUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: Colors.white10,
                                child: const Icon(Icons.music_note_rounded),
                              ),
                            )
                          : Container(
                              color: Colors.white10,
                              child: const Icon(Icons.music_note_rounded),
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          track.author,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: Colors.white12),
              _TrackDetailRow(label: 'Track Title', value: track.title),
              _TrackDetailRow(label: 'Artist', value: track.author),
              if (track.album != null && track.album!.isNotEmpty)
                _TrackDetailRow(label: 'Album', value: track.album!),
              _TrackDetailRow(label: 'Duration', value: track.durationString),
              if (track.viewCount != null && track.viewCount!.isNotEmpty)
                _TrackDetailRow(label: 'Popularity', value: track.viewCount!),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryGradient = widget.preset.gradient;
    final headerColor = primaryGradient.first;

    // Pick 4 artwork urls for 2x2 collage
    final thumbs = _tracks
        .map((t) => t.thumbnailUrl)
        .whereType<String>()
        .where((u) => u.isNotEmpty)
        .take(4)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F12),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 390,
            pinned: true,
            stretch: true,
            backgroundColor: const Color(0xFF0F0F12),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined, color: Colors.white),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Share "${widget.preset.title}"'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Ambient vibrant gradient background
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.6),
                        radius: 1.2,
                        colors: [
                          headerColor.withValues(alpha: 0.65),
                          primaryGradient.last.withValues(alpha: 0.35),
                          const Color(0xFF0F0F12),
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),

                  // Hero Content
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Artwork Hero: 2x2 collage if tracks available, or iconic preset cover
                          Container(
                            width: 178,
                            height: 178,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: headerColor.withValues(alpha: 0.45),
                                  blurRadius: 28,
                                  offset: const Offset(0, 12),
                                ),
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: thumbs.length >= 4
                                  ? GridView.count(
                                      crossAxisCount: 2,
                                      physics: const NeverScrollableScrollPhysics(),
                                      padding: EdgeInsets.zero,
                                      children: [
                                        for (final url in thumbs)
                                          Image.network(
                                            url,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) => Container(
                                              color: headerColor.withValues(alpha: 0.3),
                                              child: const Icon(Icons.music_note, color: Colors.white54),
                                            ),
                                          ),
                                      ],
                                    )
                                  : Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: primaryGradient,
                                        ),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          widget.preset.icon,
                                          size: 72,
                                          color: Colors.white.withValues(alpha: 0.9),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Playlist Title
                          Text(
                            widget.preset.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.6,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),

                          // Curator subtitle
                          Text(
                            widget.preset.curatorSubtitle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),

                          // Pill metadata line (Apple/Spotify aesthetic)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  widget.preset.badge,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_tracks.length} tracks · $_totalDurationText',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Action row: Play / Shuffle pills & Quick actions
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  // Play button pill
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _tracks.isEmpty
                          ? null
                          : () => _playPlaylist(shuffle: false),
                      icon: const Icon(Icons.play_arrow_rounded, size: 24, color: Colors.black),
                      label: const Text(
                        'Play',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Shuffle button pill
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _tracks.isEmpty
                          ? null
                          : () => _playPlaylist(shuffle: true),
                      icon: const Icon(Icons.shuffle_rounded, size: 20, color: Colors.white),
                      label: const Text(
                        'Shuffle',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Download All Button
                  IconButton.filledTonal(
                    tooltip: 'Download All Tracks',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.all(12),
                    ),
                    onPressed: _isDownloadingAll ? null : _downloadAllTracks,
                    icon: _isDownloadingAll
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.arrow_downward_rounded, size: 22),
                  ),
                ],
              ),
            ),
          ),

          // Loading indicator
          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: MeloColors.cherry),
                    SizedBox(height: 16),
                    Text(
                      'Curating songs & lossless streams...',
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),

          // Error State
          if (!_loading && _errorMessage != null && _tracks.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.white38),
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
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
              ),
            ),

          // Track List: Apple / Spotify style transparent seamless rows
          if (!_loading && _tracks.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final track = _tracks[index];
                    final isDownloaded = widget.library?.isTrackDownloaded(
                          providerTrackId: track.id,
                          title: track.title,
                          artist: track.author,
                        ) ??
                        false;
                    final progress = _downloadProgress[track.id];

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _playPlaylist(shuffle: false, startIndex: index),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          child: Row(
                            children: [
                              // Track index or cover art
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: track.thumbnailUrl != null
                                      ? Image.network(
                                          track.thumbnailUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => Container(
                                            color: Colors.white10,
                                            child: const Icon(
                                              Icons.music_note_rounded,
                                              color: Colors.white38,
                                              size: 20,
                                            ),
                                          ),
                                        )
                                      : Container(
                                          color: Colors.white10,
                                          child: const Icon(
                                            Icons.music_note_rounded,
                                            color: Colors.white38,
                                            size: 20,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Title & Artist
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      track.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: -0.2,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        if (isDownloaded) ...[
                                          const Icon(
                                            Icons.check_circle_rounded,
                                            size: 14,
                                            color: Color(0xFF1ED760), // Spotify Green
                                          ),
                                          const SizedBox(width: 4),
                                        ],
                                        Expanded(
                                          child: Text(
                                            track.author,
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.6),
                                              fontSize: 13,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Duration or download progress
                              if (progress != null) ...[
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    value: progress > 0 ? progress : null,
                                    strokeWidth: 2.2,
                                    color: MeloColors.cherry,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ] else if (track.durationString.isNotEmpty) ...[
                                Text(
                                  track.durationString,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],

                              // 3-dots popup menu
                              PopupMenuButton<String>(
                                icon: Icon(
                                  Icons.more_vert_rounded,
                                  color: Colors.white.withValues(alpha: 0.5),
                                  size: 20,
                                ),
                                color: const Color(0xFF242426),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                onSelected: (value) async {
                                  switch (value) {
                                    case 'play':
                                      await _playPlaylist(shuffle: false, startIndex: index);
                                      break;
                                    case 'queue':
                                      final item = track.toMediaItem();
                                      await widget.audioHandler?.addQueueItem(item);
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Added "${track.title}" to queue'),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                      break;
                                    case 'download':
                                      await _downloadSingleTrack(track);
                                      break;
                                    case 'details':
                                      _showTrackDetails(track);
                                      break;
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: 'play',
                                    child: Row(
                                      children: [
                                        Icon(Icons.play_arrow_rounded, size: 20),
                                        SizedBox(width: 12),
                                        Text('Play track'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'queue',
                                    child: Row(
                                      children: [
                                        Icon(Icons.queue_music_rounded, size: 20),
                                        SizedBox(width: 12),
                                        Text('Add to queue'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'download',
                                    child: Row(
                                      children: [
                                        Icon(
                                          isDownloaded
                                              ? Icons.file_download_done_rounded
                                              : Icons.download_rounded,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(isDownloaded ? 'Redownload track' : 'Download track'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'details',
                                    child: Row(
                                      children: [
                                        Icon(Icons.info_outline_rounded, size: 20),
                                        SizedBox(width: 12),
                                        Text('Song details'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: _tracks.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TrackDetailRow extends StatelessWidget {
  const _TrackDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
