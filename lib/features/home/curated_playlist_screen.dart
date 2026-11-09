import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:melo_player/app/melo_theme.dart';
import 'package:melo_player/features/library/imported_track.dart';
import 'package:melo_player/features/library/music_library.dart';
import 'package:melo_player/features/library/song_details_sheet.dart';
import 'package:melo_player/features/mix/smart_playlist_service.dart';
import 'package:melo_player/features/player/animated_equalizer_indicator.dart';
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
    this.genre = 'All',
    this.isArtistRadio = false,
    this.artistAvatars = const [],
    this.artistName,
  });

  final String title;
  final String curatorSubtitle;
  final String badge;
  final String searchQuery;
  final List<Color> gradient;
  final IconData icon;
  final String? coverUrl;
  final SmartVibe? vibe;
  final String genre;
  final bool isArtistRadio;
  final List<String> artistAvatars;
  final String? artistName;
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
      if (widget.preset.artistName != null && widget.preset.artistName!.isNotEmpty) {
        final radio = await SmartPlaylistService.instance.generateArtistRadio(
          artist: widget.preset.artistName!,
          library: widget.library,
          artworkUri: widget.preset.coverUrl,
        );
        valid = radio.tracks.map((m) {
          final pId = m.extras?['providerTrackId'] as String? ?? m.id;
          return YoutubeTrack(
            id: pId,
            title: m.title,
            author: m.artist ?? widget.preset.artistName!,
            duration: m.duration ?? const Duration(minutes: 3, seconds: 20),
            thumbnailUrl: m.artUri?.toString(),
            album: m.album,
          );
        }).toList(growable: false);
      } else if (widget.preset.vibe != null) {
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
        final unDownloaded = _tracks.where((t) {
          return !library.isTrackDownloaded(
            providerTrackId: t.id,
            title: t.title,
            artist: t.author,
          );
        }).length;

        if (unDownloaded > 0) {
          unawaited(_downloadAllTracks());
        } else {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text('"${widget.preset.title}" is saved and fully downloaded!'),
                behavior: SnackBarBehavior.floating,
              ),
            );
        }
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

      final shouldDownload = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Download "${widget.preset.title}"?'),
          content: Text(
            'Saved "${widget.preset.title}" (${registeredTracks.length} tracks) to your Melo Library.\n\nDownload all tracks to phone storage (Music/Tone) now for genuine offline playback?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Save Only'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: MeloColors.cherry,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Download All to Phone'),
            ),
          ],
        ),
      );

      if (shouldDownload == true && mounted) {
        await _downloadAllTracks();
      }
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
                          // Hero Artwork: Triple Circular Avatars for Radio/Station (Image 1) OR Big Square (Image 2)
                          Builder(
                            builder: (context) {
                              final heroCoverUrl = widget.preset.coverUrl ?? thumbs.firstOrNull;
                              final bool showTripleAvatars = widget.preset.isArtistRadio;

                              if (showTripleAvatars) {
                                final avatarList = widget.preset.artistAvatars.isNotEmpty
                                    ? widget.preset.artistAvatars
                                    : (thumbs.isNotEmpty
                                        ? thumbs
                                        : [
                                            'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&q=80',
                                            'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=600&q=80',
                                            'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=600&q=80',
                                          ]);

                                final centerAvatar = avatarList.first;
                                final leftAvatar = avatarList.length > 1 ? avatarList[1] : avatarList.first;
                                final rightAvatar = avatarList.length > 2
                                    ? avatarList[2]
                                    : (avatarList.length > 1 ? avatarList[1] : avatarList.first);

                                return SizedBox(
                                  height: 180,
                                  width: double.infinity,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    clipBehavior: Clip.none,
                                    children: [
                                      // Left Circle
                                      Positioned(
                                        left: 18,
                                        top: 30,
                                        child: Container(
                                          width: 105,
                                          height: 105,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.5),
                                                blurRadius: 16,
                                                offset: const Offset(0, 8),
                                              ),
                                            ],
                                          ),
                                          child: ClipOval(
                                            child: Image.network(
                                              leftAvatar,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) => Container(color: Colors.white24),
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Right Circle
                                      Positioned(
                                        right: 18,
                                        top: 30,
                                        child: Container(
                                          width: 105,
                                          height: 105,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.5),
                                                blurRadius: 16,
                                                offset: const Offset(0, 8),
                                              ),
                                            ],
                                          ),
                                          child: ClipOval(
                                            child: Image.network(
                                              rightAvatar,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) => Container(color: Colors.white24),
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Center Main Circle (Prominent in foreground)
                                      Positioned(
                                        top: 8,
                                        child: Container(
                                          width: 155,
                                          height: 155,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white.withValues(alpha: 0.9),
                                              width: 2.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: headerColor.withValues(alpha: 0.6),
                                                blurRadius: 28,
                                                offset: const Offset(0, 10),
                                              ),
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.7),
                                                blurRadius: 18,
                                                offset: const Offset(0, 8),
                                              ),
                                            ],
                                          ),
                                          child: ClipOval(
                                            child: Image.network(
                                              centerAvatar,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) => Container(color: headerColor),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return Container(
                                width: 216,
                                height: 216,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
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
                                  borderRadius: BorderRadius.circular(16),
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
                          const SizedBox(height: 16),

                          // Playlist / Radio Title (Spotify Bold Style)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              widget.preset.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.6,
                                height: 1.15,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 4),

                          // Curator subtitle ("With B2c, Dax Vibez...")
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              widget.preset.curatorSubtitle,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Spotify Made for you row
                          Row(
                            children: [
                              const Icon(
                                Icons.graphic_eq_rounded,
                                size: 16,
                                color: MeloColors.cherry,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Made for you',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white38,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_tracks.length} tracks · $_totalDurationText',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
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

          // Spotify Signature Action Bar: [Mini Cover] [+] [↓] [Share] ... [🔀] [Big Circular Play Button]
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  // Mini Cover Art square
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      width: 38,
                      height: 38,
                      child: (widget.preset.coverUrl ?? thumbs.firstOrNull) != null
                          ? Image.network(
                              widget.preset.coverUrl ?? thumbs.first,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(color: headerColor),
                            )
                          : Container(color: headerColor),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Save to Library (+) or (✓)
                  IconButton(
                    tooltip: isPlaylistSaved ? 'Saved to Library' : 'Save Playlist to Phone',
                    onPressed: _savePlaylistToPhone,
                    icon: Icon(
                      isPlaylistSaved ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                      color: isPlaylistSaved ? MeloColors.cherry : Colors.white70,
                      size: 28,
                    ),
                  ),

                  // Download All to Phone (↓)
                  IconButton(
                    tooltip: 'Download All Songs to Phone',
                    onPressed: _isDownloadingAll ? null : _downloadAllTracks,
                    icon: _isDownloadingAll
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(
                            Icons.arrow_circle_down_rounded,
                            color: Colors.white70,
                            size: 28,
                          ),
                  ),

                  // Share button
                  IconButton(
                    tooltip: 'Share',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Sharing "${widget.preset.title}"'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.share_outlined, color: Colors.white70, size: 22),
                  ),

                  const Spacer(),

                  // Shuffle (🔀)
                  IconButton(
                    tooltip: 'Shuffle',
                    onPressed: _tracks.isEmpty ? null : () => _playPlaylist(shuffle: true),
                    icon: const Icon(Icons.shuffle_rounded, color: Colors.white70, size: 26),
                  ),
                  const SizedBox(width: 8),

                  // Spotify Big Circular Vibrant Play Button
                  Material(
                    shape: const CircleBorder(),
                    color: MeloColors.cherry,
                    elevation: 6,
                    shadowColor: MeloColors.cherry.withValues(alpha: 0.5),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _tracks.isEmpty ? null : () => _playPlaylist(shuffle: false),
                      child: const SizedBox(
                        width: 52,
                        height: 52,
                        child: Icon(
                          Icons.play_arrow_rounded,
                          size: 34,
                          color: Colors.white,
                        ),
                      ),
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
                                                child: AnimatedEqualizerIndicator(
                                                  color: MeloColors.cherry,
                                                  size: 20,
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
                                                color: MeloColors.cherrySoft,
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


