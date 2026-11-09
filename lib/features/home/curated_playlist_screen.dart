import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:melo_player/app/melo_theme.dart';
import 'package:melo_player/features/library/imported_track.dart';
import 'package:melo_player/features/library/music_library.dart';
import 'package:melo_player/features/library/song_details_sheet.dart';
import 'package:melo_player/features/mix/smart_playlist_service.dart';
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
    this.coverUrl,
    this.vibe,
  });

  final String title;
  final String curatorSubtitle;
  final String badge;
  final String searchQuery;
  final List<Color> gradient;
  final IconData icon;
  final String? coverUrl;
  final SmartVibe? vibe;
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
      List<YoutubeTrack> valid;
      if (widget.preset.vibe != null) {
        final smart = await SmartPlaylistService.instance.generateVibeMix(
          vibe: widget.preset.vibe!,
          library: widget.library,
        );
        valid = smart.tracks.map((m) {
          final pId = m.extras?['providerTrackId'] as String? ?? m.id;
          return YoutubeTrack(
            id: pId,
            title: m.title,
            author: m.artist ?? 'Melo Artist',
            duration: m.duration ?? const Duration(minutes: 3, seconds: 20),
            thumbnailUrl: m.artUri?.toString(),
            album: m.album,
          );
        }).toList(growable: false);
      } else {
        final results = await YoutubeAudioService.instance.search(
          widget.preset.searchQuery,
          filterMixtapes: true,
        );
        // Strictly filter out long mixtapes, nonstop DJ sets, and compilation rips
        final filtered = results.where((t) {
          if (t.duration.inSeconds > 660) return false;
          if (t.duration.inSeconds > 0 && t.duration.inSeconds < 40) return false;
          if (YoutubeAudioService.isMixtapeOrNonstop(t.title, t.duration)) return false;
          return true;
        }).take(25).toList(growable: false);
        valid = filtered;
      }
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

    try {
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not play playlist: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
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

  Future<void> _savePlaylistToPhone() async {
    final library = widget.library;
    if (library == null) return;

    try {
      final existing = library.playlists.where(
        (p) => p.name.toLowerCase() == widget.preset.title.toLowerCase(),
      ).firstOrNull;

      if (existing != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('"${widget.preset.title}" is already in your Melo Library Playlists.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        return;
      }

      final playlist = await library.createPlaylist(widget.preset.title);
      final firstThumb = _tracks.map((t) => t.thumbnailUrl).whereType<String>().firstOrNull;
      if (firstThumb != null) {
        await library.updatePlaylistCover(
          playlist.id,
          customArtworkUri: firstThumb,
        );
      }

      final remoteTracks = _tracks.map((t) {
        return ImportedTrack(
          id: 'youtube:${t.id}',
          path: 'youtube:${t.id}',
          title: t.title,
          artist: t.author,
          album: t.album ?? widget.preset.title,
          durationMs: t.duration.inMilliseconds,
          artworkUri: t.thumbnailUrl,
          sourceProvider: 'youtube',
          providerTrackId: t.id,
          isAvailable: true,
          isDeviceMedia: false,
        );
      }).toList(growable: false);

      final registeredTracks = await library.registerOrFindRemoteTracks(remoteTracks);
      await library.addTracksToPlaylist(
        playlist.id,
        registeredTracks.map((t) => t.id),
      );

      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF1ED760), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Saved "${widget.preset.title}" (${registeredTracks.length} tracks) to Library Playlists',
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Download All',
              textColor: MeloColors.cherrySoft,
              onPressed: _downloadAllTracks,
            ),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not save playlist: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  void _showTrackDetails(YoutubeTrack track) {
    SongDetailsSheet.show(
      context,
      ytTrack: track,
      audioHandler: widget.audioHandler,
      library: widget.library,
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryGradient = widget.preset.gradient;
    final headerColor = primaryGradient.first;
    final isPlaylistSaved = widget.library?.playlists.any(
          (p) => p.name.toLowerCase() == widget.preset.title.toLowerCase(),
        ) ??
        false;

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
            expandedHeight: 440,
            pinned: true,
            stretch: true,
            backgroundColor: const Color(0xFF0F0F12),
            leading: Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Center(
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 17),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
            actions: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.16),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.share_outlined, color: Colors.white, size: 19),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Share "${widget.preset.title}"'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.16),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 20),
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: 14),
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
                          // Large Single Hero Artwork (Apple Music & Spotify Signature)
                          Builder(
                            builder: (context) {
                              final heroCoverUrl = widget.preset.coverUrl ?? thumbs.firstOrNull;
                              return Container(
                                width: 216,
                                height: 216,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: headerColor.withValues(alpha: 0.5),
                                      blurRadius: 32,
                                      offset: const Offset(0, 14),
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.7),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: heroCoverUrl != null && heroCoverUrl.isNotEmpty
                                      ? Image.network(
                                          heroCoverUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => Container(
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
                                                size: 80,
                                                color: Colors.white.withValues(alpha: 0.9),
                                              ),
                                            ),
                                          ),
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
                                              size: 80,
                                              color: Colors.white.withValues(alpha: 0.9),
                                            ),
                                          ),
                                        ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 18),

                          // Playlist Title
                          Text(
                            widget.preset.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
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
                              fontSize: 13.5,
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

          // Apple Music Action row: Centered [ 🔀 Shuffle ]  [ ▶ Play ]  [ ➕ Save ]  [ ⬇ Download ]
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Circular glass Shuffle button
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.shuffle_rounded, color: Colors.white, size: 20),
                      tooltip: 'Shuffle',
                      onPressed: _tracks.isEmpty ? null : () => _playPlaylist(shuffle: true),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Center solid White Stadium Play Pill (Apple Music signature)
                  SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
                        shape: const StadiumBorder(),
                        elevation: 0,
                      ),
                      onPressed: _tracks.isEmpty ? null : () => _playPlaylist(shuffle: false),
                      icon: const Icon(Icons.play_arrow_rounded, size: 26, color: Colors.black),
                      label: const Text(
                        'Play',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Circular glass Save to Library button
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isPlaylistSaved
                          ? MeloColors.cherry.withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.14),
                    ),
                    child: IconButton(
                      tooltip: isPlaylistSaved ? 'Saved to Melo Library' : 'Save Playlist to Phone',
                      onPressed: _savePlaylistToPhone,
                      icon: Icon(
                        isPlaylistSaved ? Icons.check_rounded : Icons.add_rounded,
                        color: isPlaylistSaved ? MeloColors.cherrySoft : Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Circular glass Download All button
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                    child: IconButton(
                      tooltip: 'Download All Songs',
                      onPressed: _isDownloadingAll ? null : _downloadAllTracks,
                      icon: _isDownloadingAll
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.arrow_downward_rounded, color: Colors.white, size: 22),
                    ),
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
            StreamBuilder<MediaItem?>(
              stream: widget.audioHandler?.mediaItem,
              initialData: widget.audioHandler?.mediaItem.value,
              builder: (context, mediaSnapshot) {
                final currentItem = mediaSnapshot.data;
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                  sliver: SliverList.separated(
                    itemCount: _tracks.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      thickness: 0.5,
                      indent: 70,
                      endIndent: 8,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    itemBuilder: (context, index) {
                        final track = _tracks[index];
                        final isDownloaded = widget.library?.isTrackDownloaded(
                              providerTrackId: track.id,
                              title: track.title,
                              artist: track.author,
                            ) ??
                            false;
                        final progress = _downloadProgress[track.id];
                        final isPlaying = currentItem != null &&
                            (currentItem.id == track.id ||
                                currentItem.extras?['providerTrackId'] == track.id ||
                                (currentItem.title.trim().toLowerCase() ==
                                        track.title.trim().toLowerCase() &&
                                    currentItem.artist?.trim().toLowerCase() ==
                                        track.author.trim().toLowerCase()));

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _playPlaylist(shuffle: false, startIndex: index),
                            onLongPress: () => _showTrackDetails(track),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                              child: Row(
                                children: [
                                  // Track index or cover art with active playing overlay
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: SizedBox(
                                      width: 48,
                                      height: 48,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          track.thumbnailUrl != null
                                              ? Image.network(
                                                  track.thumbnailUrl!,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, _, _) => Image.network(
                                                    'https://i.ytimg.com/vi/${track.id}/hqdefault.jpg',
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, _, _) => Container(
                                                      color: Colors.white10,
                                                      child: const Icon(
                                                        Icons.music_note_rounded,
                                                        color: Colors.white38,
                                                        size: 20,
                                                      ),
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
                                          if (isPlaying)
                                            Container(
                                              color: Colors.black.withValues(alpha: 0.55),
                                              child: const Center(
                                                child: Icon(
                                                  Icons.graphic_eq_rounded,
                                                  color: MeloColors.cherry,
                                                  size: 22,
                                                ),
                                              ),
                                            ),
                                        ],
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
                                          style: TextStyle(
                                            color: isPlaying ? MeloColors.cherrySoft : Colors.white,
                                            fontSize: 15,
                                            fontWeight:
                                                isPlaying ? FontWeight.w800 : FontWeight.w600,
                                            letterSpacing: -0.2,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            if (isPlaying) ...[
                                              const Icon(
                                                Icons.volume_up_rounded,
                                                size: 14,
                                                color: MeloColors.cherrySoft,
                                              ),
                                              const SizedBox(width: 4),
                                            ],
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
                                    value: 'details',
                                    child: Row(
                                      children: [
                                        Icon(Icons.info_outline_rounded, size: 20),
                                        SizedBox(width: 12),
                                        Text('Song details & artwork'),
                                      ],
                                    ),
                                  ),
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
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}


