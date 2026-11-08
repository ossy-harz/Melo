import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:melo_player/app/melo_theme.dart';
import 'package:melo_player/features/library/music_library.dart';
import 'package:melo_player/features/player/mini_player.dart';
import 'package:melo_player/features/settings/youtube_settings_screen.dart';
import 'package:melo_player/features/sources/lossless_audio_service.dart';
import 'package:melo_player/features/youtube/youtube_audio_service.dart';
import 'package:melo_player/features/youtube/youtube_auth_service.dart';

class YoutubeSearchScreen extends StatefulWidget {
  const YoutubeSearchScreen({
    this.audioHandler,
    this.library,
    this.initialQuery,
    super.key,
  });

  final AudioHandler? audioHandler;
  final MusicLibrary? library;
  final String? initialQuery;

  @override
  State<YoutubeSearchScreen> createState() => _YoutubeSearchScreenState();
}

class _YoutubeSearchScreenState extends State<YoutubeSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounce;

  bool _isLoading = false;
  String? _errorMessage;
  List<YoutubeTrack> _results = [];
  String? _playingTrackId;
  String _selectedCategory = 'Top Hits';
  final Map<String, double> _downloadProgress = {};

  static const List<(String, String)> _categories = [
    ('Top Hits', 'Top Songs 2025'),
    ('Chill', 'Chill Lofi Study Beats'),
    ('Workout', 'High Energy Workout Hits'),
    ('Late Night', 'Late Night R&B Chill'),
    ('Electronic', 'Melodic House & Synthwave'),
    ('Acoustic', 'Acoustic Indie Covers'),
    ('Pop', 'Pop Hits'),
    ('Jazz', 'Smooth Jazz Lounge'),
  ];

  @override
  void initState() {
    super.initState();
    widget.library?.addListener(_onLibraryChanged);
    final initial = widget.initialQuery?.trim();
    if (initial != null && initial.isNotEmpty) {
      _searchController.text = initial;
      _selectedCategory = '';
      _performSearch(initial);
    } else {
      _performSearch(_categories.first.$2, keepCategory: true);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.library?.removeListener(_onLibraryChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onLibraryChanged() {
    if (mounted) setState(() {});
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    setState(() {});
    final clean = value.trim();
    if (clean.isEmpty) return;
    _debounce = Timer(const Duration(milliseconds: 280), () {
      _performSearch(clean);
    });
  }

  Future<void> _performSearch(String query, {bool keepCategory = false}) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      if (!keepCategory) _selectedCategory = '';
    });

    try {
      final tracks = await YoutubeAudioService.instance.search(cleanQuery);
      if (!mounted) return;
      setState(() {
        _results = tracks;
        _isLoading = false;
        if (tracks.isEmpty) {
          _errorMessage = 'No songs found for "$cleanQuery".';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load songs. Check your connection.';
      });
    }
  }

  Future<void> _loadPersonalTaste() async {
    _searchFocusNode.unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedCategory = 'Made for You';
      _searchController.clear();
    });

    try {
      final tracks = await YoutubeAuthService.instance.getPersonalTasteTracks();
      if (!mounted) return;
      setState(() {
        _results = tracks;
        _isLoading = false;
        if (tracks.isEmpty) {
          _errorMessage = 'No personalized recommendations available yet.';
        }
      });
      if (tracks.isNotEmpty) {
        unawaited(
          YoutubeAudioService.instance.prefetchStreams(
            tracks.take(3).map((t) => t.id),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load recommendations.';
      });
    }
  }

  Future<void> _loadLikedSongs() async {
    _searchFocusNode.unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedCategory = 'Liked Songs';
      _searchController.clear();
    });

    try {
      final tracks = await YoutubeAuthService.instance.getLikedMusic();
      if (!mounted) return;
      setState(() {
        _results = tracks;
        _isLoading = false;
        if (tracks.isEmpty) {
          _errorMessage = 'No liked songs found in your connected account.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load liked songs.';
      });
    }
  }

  Future<void> _playTrack(YoutubeTrack track) async {
    final handler = widget.audioHandler;
    if (handler == null) return;

    setState(() => _playingTrackId = track.id);

    try {
      final localMatch = widget.library?.findMatchingLocalTrack(
        providerTrackId: track.id,
        title: track.title,
        artist: track.author,
      );
      if (localMatch != null) {
        await handler.playMediaItem(localMatch.toMediaItem());
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Playing "${track.title}" from your device'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        return;
      }

      final item = track.toMediaItem();
      await handler.playMediaItem(item);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Streaming "${track.title}" — tap Download anytime to save to device'),
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
            content: Text('Could not play "${track.title}": $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) {
        setState(() => _playingTrackId = null);
      }
    }
  }

  Future<void> _playAllResults({required bool shuffle}) async {
    final handler = widget.audioHandler;
    if (handler == null || _results.isEmpty) return;

    final tracks = [..._results];
    if (shuffle) tracks.shuffle();
    final items = tracks.map((t) {
      final localMatch = widget.library?.findMatchingLocalTrack(
        providerTrackId: t.id,
        title: t.title,
        artist: t.author,
      );
      return localMatch != null ? localMatch.toMediaItem() : t.toMediaItem();
    }).toList(growable: false);

    setState(() => _playingTrackId = tracks.first.id);
    try {
      await handler.updateQueue(items);
      await handler.play();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not start playback: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) {
        setState(() => _playingTrackId = null);
      }
    }
  }

  Future<void> _addToQueue(YoutubeTrack track) async {
    final handler = widget.audioHandler;
    if (handler == null) return;

    try {
      final localMatch = widget.library?.findMatchingLocalTrack(
        providerTrackId: track.id,
        title: track.title,
        artist: track.author,
      );
      final item = localMatch != null ? localMatch.toMediaItem() : track.toMediaItem();
      await handler.addQueueItem(item);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Added "${track.title}" to Up Next'),
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
            content: Text('Could not add to queue: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<void> _downloadToDevice(YoutubeTrack track) async {
    final musicLibrary = widget.library;
    if (musicLibrary == null) return;
    if (_downloadProgress.containsKey(track.id)) return;
    if (musicLibrary.isTrackDownloaded(
      providerTrackId: track.id,
      title: track.title,
      artist: track.author,
    )) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('"${track.title}" is already on your device.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }

    final chosenQuality = await LosslessAudioService.instance.selectDownloadQuality(
      context,
      title: track.title,
      artist: track.author,
    );
    if (chosenQuality == null || !mounted) return;

    setState(() => _downloadProgress[track.id] = 0.01);

    try {
      await YoutubeAudioService.instance.downloadTrack(
        track: track,
        library: musicLibrary,
        qualityOverride: chosenQuality,
        onProgress: (p) {
          if (mounted) {
            setState(() => _downloadProgress[track.id] = p.clamp(0.01, 1.0));
          }
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Saved "${track.title}" (${chosenQuality.shortLabel} + Artwork & Lyrics) to Music/Tone',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not save "${track.title}": $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) {
        setState(() => _downloadProgress.remove(track.id));
      }
    }
  }

  void _showAddToPlaylistDialog(YoutubeTrack track) {
    final musicLibrary = widget.library;
    if (musicLibrary == null) return;

    final playlists = musicLibrary.playlists;
    final importedTrack = track.toImportedTrack();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(sheetContext).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
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
              const SizedBox(height: 16),
              Text(
                'Add to Playlist',
                style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              if (playlists.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('No playlists yet. Create one in Library.'),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: playlists.length,
                    itemBuilder: (context, index) {
                      final pl = playlists[index];
                      return ListTile(
                        leading: const Icon(Icons.playlist_play_rounded),
                        title: Text(pl.name),
                        subtitle: Text('${pl.trackIds.length} songs'),
                        onTap: () async {
                          Navigator.of(sheetContext).pop();
                          await musicLibrary.importExternalTracks([
                            importedTrack,
                          ]);
                          await musicLibrary.addTracksToPlaylist(pl.id, [
                            importedTrack.id,
                          ]);
                          if (!mounted) return;
                          ScaffoldMessenger.of(this.context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(
                                content: Text('Added to "${pl.name}"'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: YoutubeAuthService.instance.authState,
            builder: (context, isLoggedIn, _) {
              return IconButton(
                tooltip: isLoggedIn
                    ? 'Account connected'
                    : 'Streaming quality & account',
                icon: Icon(
                  isLoggedIn
                      ? Icons.account_circle_rounded
                      : Icons.tune_rounded,
                  color: isLoggedIn ? MeloColors.cherry : null,
                ),
                onPressed: () => Navigator.of(context)
                    .push(
                      MaterialPageRoute<void>(
                        builder: (_) => YoutubeSettingsScreen(
                          library: widget.library,
                          audioHandler: widget.audioHandler,
                        ),
                      ),
                    )
                    .then((_) {
                      if (mounted) setState(() {});
                    }),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              textInputAction: TextInputAction.search,
              onChanged: _onQueryChanged,
              onSubmitted: _performSearch,
              decoration: InputDecoration(
                hintText: 'Songs, artists, or albums',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _debounce?.cancel();
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
            ),
          ),
          SizedBox(
            height: 38,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              children: [
                _CategoryChip(
                  label: 'Made for You',
                  icon: Icons.auto_awesome_rounded,
                  selected: _selectedCategory == 'Made for You',
                  onTap: _loadPersonalTaste,
                ),
                const SizedBox(width: 8),
                if (YoutubeAuthService.instance.isLoggedIn) ...[
                  _CategoryChip(
                    label: 'Liked Songs',
                    icon: Icons.favorite_rounded,
                    selected: _selectedCategory == 'Liked Songs',
                    onTap: _loadLikedSongs,
                  ),
                  const SizedBox(width: 8),
                ],
                for (final (label, query) in _categories) ...[
                  _CategoryChip(
                    label: label,
                    selected: _selectedCategory == label,
                    onTap: () {
                      _searchFocusNode.unfocus();
                      _searchController.clear();
                      setState(() => _selectedCategory = label);
                      _performSearch(query, keepCategory: true);
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          if (!_isLoading && _results.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedCategory.isNotEmpty
                          ? _selectedCategory
                          : 'Top Results',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _playAllResults(shuffle: true),
                    icon: const Icon(Icons.shuffle_rounded, size: 17),
                    label: const Text('Shuffle'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton.tonalIcon(
                    onPressed: () => _playAllResults(shuffle: false),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Play'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final track = _results[index];
                      final isDownloaded =
                          widget.library?.isTrackDownloaded(
                            providerTrackId: track.id,
                            title: track.title,
                            artist: track.author,
                          ) ??
                          false;
                      final progress = _downloadProgress[track.id];
                      final isPlaying = _playingTrackId == track.id;
                      final meta = track.duration > Duration.zero
                          ? '${track.displaySubtitle} · ${track.durationString}'
                          : track.displaySubtitle;

                      return Semantics(
                        button: true,
                        label: '${track.title} by ${track.author}',
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(MeloRadii.md),
                            onTap: () => _playTrack(track),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 6,
                              ),
                              child: Row(
                                children: [
                                  AlbumArtwork(
                                    size: 52,
                                    title: track.title,
                                    artworkUri: track.thumbnailUrl == null
                                        ? null
                                        : Uri.tryParse(track.thumbnailUrl!),
                                    borderRadius: 12,
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
                                          style: textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          meta,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: textTheme.bodySmall?.copyWith(
                                            color: colors.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isPlaying)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: MeloColors.cherry,
                                        ),
                                      ),
                                    )
                                  else if (progress != null)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      child: SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          value: progress > 0.05
                                              ? progress
                                              : null,
                                          strokeWidth: 2.2,
                                        ),
                                      ),
                                    )
                                  else if (isDownloaded)
                                    Tooltip(
                                      message: 'Saved on device',
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                        ),
                                        child: Icon(
                                          Icons.download_done_rounded,
                                          size: 20,
                                          color: colors.primary,
                                        ),
                                      ),
                                    )
                                  else if (widget.library != null)
                                    IconButton(
                                      tooltip: 'Save to device',
                                      icon: Icon(
                                        Icons.download_for_offline_outlined,
                                        color: colors.onSurfaceVariant,
                                        size: 22,
                                      ),
                                      onPressed: () => _downloadToDevice(track),
                                    ),
                                  PopupMenuButton<String>(
                                    tooltip: 'More options',
                                    icon: Icon(
                                      Icons.more_horiz_rounded,
                                      size: 20,
                                      color: colors.onSurfaceVariant,
                                    ),
                                    onSelected: (val) {
                                      if (val == 'queue') {
                                        _addToQueue(track);
                                      } else if (val == 'playlist') {
                                        _showAddToPlaylistDialog(track);
                                      } else if (val == 'download') {
                                        _downloadToDevice(track);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'queue',
                                        child: Text('Add to Up Next'),
                                      ),
                                      if (widget.library != null)
                                        const PopupMenuItem(
                                          value: 'playlist',
                                          child: Text('Add to playlist'),
                                        ),
                                      if (widget.library != null &&
                                          !isDownloaded)
                                        const PopupMenuItem(
                                          value: 'download',
                                          child: Text('Save to device'),
                                        ),
                                    ],
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

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MeloRadii.pill),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? MeloColors.cherry
                  : colors.surfaceContainerHighest.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(MeloRadii.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 15,
                    color: selected ? Colors.white : MeloColors.cherry,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : colors.onSurface,
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
