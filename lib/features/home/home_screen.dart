import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:melo_player/app/melo_glass.dart';
import 'package:melo_player/app/melo_theme.dart';
import 'package:melo_player/features/library/imported_track.dart';
import 'package:melo_player/features/library/data/library_repository.dart'
    show MostPlayedTrack;
import 'package:melo_player/features/library/music_library.dart';
import 'package:melo_player/features/library/playlist_detail_screen.dart';
import 'package:melo_player/features/mix/local_discovery.dart';
import 'package:melo_player/features/mix/smart_playlist_service.dart';
import 'package:melo_player/features/player/mini_player.dart';
import 'package:melo_player/features/sources/lossless_audio_service.dart';
import 'package:melo_player/features/spotify/spotify_import_sheet.dart';
import 'package:melo_player/features/youtube/youtube_audio_service.dart';
import 'package:melo_player/features/home/curated_playlist_screen.dart';
import 'package:melo_player/features/youtube/youtube_search_screen.dart';

/// Tone's home is a discovery surface; playback and destinations stay in the
/// persistent player and app navigation.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.onOpenLibrary,
    this.onSearch,
    this.audioHandler,
    this.library,
    super.key,
  });

  final VoidCallback onOpenLibrary;
  final VoidCallback? onSearch;
  final AudioHandler? audioHandler;
  final MusicLibrary? library;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Apple Music Style Home Header (Reference Screenshot 3)
              Row(
                children: [
                  Text(
                    'Home',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.0,
                    ),
                  ),
                  const Spacer(),
                  if (onSearch != null)
                    IconButton(
                      tooltip: 'Search',
                      onPressed: onSearch,
                      icon: const Icon(Icons.search_rounded),
                    ),
                  PopupMenuButton<String>(
                    tooltip: 'More options',
                    icon: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                      child: const Icon(Icons.more_horiz_rounded, size: 20),
                    ),
                    onSelected: (val) {
                      if (val == 'cloud') {
                        SpotifyImportSheet.show(
                          context,
                          library: library,
                          audioHandler: audioHandler,
                        );
                      }
                      if (val == 'stream') {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => YoutubeSearchScreen(
                              audioHandler: audioHandler,
                              library: library,
                            ),
                          ),
                        );
                      }
                      if (val == 'library') onOpenLibrary();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'cloud',
                        child: Row(
                          children: [
                            Icon(Icons.cloud_download_rounded, size: 20),
                            SizedBox(width: 10),
                            Text('Import Online Playlist'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'stream',
                        child: Row(
                          children: [
                            Icon(Icons.stream_rounded, size: 20),
                            SizedBox(width: 10),
                            Text('Search Streaming Music'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'library',
                        child: Row(
                          children: [
                            Icon(Icons.library_music_rounded, size: 20),
                            SizedBox(width: 10),
                            Text('Device Library'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Shelf 1: Listening Pulse (Your listening: FAVORITES, MOST PLAYED, YOUR SOUND)
              if (library != null && audioHandler != null && library!.tracks.isNotEmpty) ...[
                _ListeningPulse(
                  library: library!,
                  onPlayFavorites: () => _playFavorites(context),
                  onPlayTrack: (track) => _playTrack(context, track),
                  onPlayMix: (tracks) => _playTracks(context, tracks),
                ),
                if (library!.playlists.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _SavedPlaylists(
                    library: library!,
                    audioHandler: audioHandler,
                    onPlay: (playlistId) => _playPlaylist(context, playlistId),
                  ),
                ],
                const SizedBox(height: 14),
                _LibraryPicks(
                  library: library!,
                  onPlay: (suggestion) =>
                      _playDiscoveryPick(context, suggestion),
                  onSaveSuggestion: (suggestion) =>
                      _saveSuggestedPlaylist(context, suggestion),
                ),
                const SizedBox(height: 24),
              ],

              // Shelf 2: Top Picks for You (Hero Showcase Carousel)
              _TopPicksShelf(
                onPlayVibe: (vibe) => _playSmartVibe(context, vibe),
                onPlayPreset: (preset) => _openCuratedPreset(context, preset),
              ),
              const SizedBox(height: 24),

              // Shelf 3: Recently Played >
              if (library != null && library!.tracks.isNotEmpty) ...[
                _RecentlyPlayedShelf(
                  library: library!,
                  onPlay: (track) => _playTrack(context, track),
                  onOpenLibrary: onOpenLibrary,
                ),
                const SizedBox(height: 24),
              ],

              // Shelf 4: Stations for You (Continuous Radio Flow with Real Art)
              _StationsForYouShelf(
                library: library,
                onPlayVibe: (vibe) => _playSmartVibe(context, vibe),
              ),
              const SizedBox(height: 24),

              // Shelf 5: Recommended Editorial Playlists
              if (!kIsWeb && Platform.isAndroid) ...[
                _RecommendedPlaylistsSection(
                  audioHandler: audioHandler,
                  library: library,
                ),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
      ],
    );
  }

  void _openCuratedPreset(BuildContext context, CuratedPlaylistPreset preset) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CuratedPlaylistScreen(
          preset: preset,
          audioHandler: audioHandler,
          library: library,
        ),
      ),
    );
  }

  Future<void> _playSmartVibe(BuildContext context, SmartVibe vibe) async {
    final handler = audioHandler;
    if (handler == null) return;

    final vibeName = switch (vibe) {
      SmartVibe.dailyFlow => 'My Daily Flow',
      SmartVibe.highEnergy => 'High Energy Workout',
      SmartVibe.deepFocus => 'Deep Focus & Study',
      SmartVibe.lateNightChill => 'Late Night Chill',
    };

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Starting $vibeName (Continuous autoplay)...'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );

    try {
      final playlist = await SmartPlaylistService.instance.generateVibeMix(
        vibe: vibe,
        library: library,
      );
      await SmartPlaylistService.instance.playSmartPlaylist(
        audioHandler: handler,
        playlist: playlist,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not start $vibeName: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<void> _playTrack(BuildContext context, ImportedTrack track) async {
    final handler = audioHandler;
    final musicLibrary = library;
    if (handler == null || musicLibrary == null) return;
    try {
      final index = musicLibrary.indexOfTrack(track.id);
      if (index < 0) throw StateError('This song is no longer in the library.');
      await musicLibrary.playTrack(handler, index);
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not play this song: $error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<void> _playTracks(
    BuildContext context,
    List<ImportedTrack> tracks,
  ) async {
    final handler = audioHandler;
    final musicLibrary = library;
    if (handler == null || musicLibrary == null || tracks.isEmpty) return;
    try {
      await musicLibrary.playMix(handler, tracks);
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not start this mix: $error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<void> _playFavorites(BuildContext context) async {
    final musicLibrary = library;
    final handler = audioHandler;
    if (musicLibrary == null || handler == null) return;
    final favorites = musicLibrary.favoriteTracks
        .where((track) => track.isAvailable)
        .toList(growable: false);
    if (favorites.isEmpty) return;
    try {
      await musicLibrary.playMix(handler, favorites);
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not play your favorites: $error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<void> _playPlaylist(BuildContext context, String playlistId) async {
    final musicLibrary = library;
    final handler = audioHandler;
    if (musicLibrary == null || handler == null) return;
    try {
      await musicLibrary.playPlaylist(handler, playlistId);
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not play this playlist: $error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<void> _playDiscoveryPick(
    BuildContext context,
    PlaylistSuggestion suggestion,
  ) async {
    final musicLibrary = library;
    final handler = audioHandler;
    if (musicLibrary == null || handler == null) return;
    try {
      if (suggestion.type == DiscoveryPickType.artistRadio) {
        await musicLibrary.playArtistRadio(
          handler,
          suggestion.name.replaceFirst(RegExp(r' Radio$'), ''),
        );
      } else {
        await musicLibrary.playMix(handler, suggestion.tracks);
      }
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not play ${suggestion.name}: $error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<void> _saveSuggestedPlaylist(
    BuildContext context,
    PlaylistSuggestion suggestion,
  ) async {
    final musicLibrary = library;
    if (musicLibrary == null) return;
    try {
      final playlist = await musicLibrary.createPlaylist(suggestion.name);
      try {
        await musicLibrary.addTracksToPlaylist(
          playlist.id,
          suggestion.tracks.map((track) => track.id),
        );
      } on Object {
        await musicLibrary.deletePlaylist(playlist.id);
        rethrow;
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Added “${suggestion.name}” to your playlists.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not save this playlist: $error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }
}

class _ListeningPulse extends StatefulWidget {
  const _ListeningPulse({
    required this.library,
    required this.onPlayFavorites,
    required this.onPlayTrack,
    required this.onPlayMix,
  });

  final MusicLibrary library;
  final VoidCallback onPlayFavorites;
  final ValueChanged<ImportedTrack> onPlayTrack;
  final ValueChanged<List<ImportedTrack>> onPlayMix;

  @override
  State<_ListeningPulse> createState() => _ListeningPulseState();
}

class _ListeningPulseState extends State<_ListeningPulse> {
  late Future<List<MostPlayedTrack>> _mostPlayed;

  @override
  void initState() {
    super.initState();
    _mostPlayed = _loadMostPlayed();
    widget.library.addListener(_onLibraryChanged);
    widget.library.playbackHistoryRevision.addListener(_onHistoryChanged);
  }

  @override
  void didUpdateWidget(covariant _ListeningPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.library == widget.library) return;
    oldWidget.library.removeListener(_onLibraryChanged);
    oldWidget.library.playbackHistoryRevision.removeListener(_onHistoryChanged);
    widget.library.addListener(_onLibraryChanged);
    widget.library.playbackHistoryRevision.addListener(_onHistoryChanged);
    _mostPlayed = _loadMostPlayed();
  }

  @override
  void dispose() {
    widget.library.removeListener(_onLibraryChanged);
    widget.library.playbackHistoryRevision.removeListener(_onHistoryChanged);
    super.dispose();
  }

  void _onLibraryChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _onHistoryChanged() {
    if (!mounted) return;
    setState(() {
      _mostPlayed = _loadMostPlayed();
    });
  }

  Future<List<MostPlayedTrack>> _loadMostPlayed() async {
    try {
      return await widget.library.mostPlayedTracks(
        limit: widget.library.tracks.length,
      );
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'tone home',
          context: ErrorDescription('while loading most-played tracks'),
        ),
      );
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final allFavorites = widget.library.favoriteTracks;
    final favorites = allFavorites
        .where((track) => track.isAvailable)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'Your listening',
          subtitle: 'A quick read of what you love and replay.',
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<MostPlayedTrack>>(
          future: _mostPlayed,
          builder: (context, snapshot) {
            final topPlayedTracks = snapshot.data ?? const <MostPlayedTrack>[];
            final topPlayed = topPlayedTracks.isEmpty
                ? null
                : topPlayedTracks.first;
            final favoriteTrack = favorites.isEmpty ? null : favorites.first;
            final playCounts = {
              for (final item in topPlayedTracks) item.track.id: item.playCount,
            };
            final favoriteIds = {for (final track in allFavorites) track.id};
            final genres = LocalDiscovery.genreMixes(
              widget.library.tracks,
              favoriteTrackIds: favoriteIds,
              playCounts: playCounts,
              limit: 2,
            );
            final moods = LocalDiscovery.moodMixes(
              widget.library.tracks,
              favoriteTrackIds: favoriteIds,
              playCounts: playCounts,
            ).take(2);
            final loading = snapshot.connectionState != ConnectionState.done;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _ListeningCard(
                        label: 'FAVORITES',
                        track: favoriteTrack,
                        summary: '${allFavorites.length} saved',
                        emptyMessage: allFavorites.isEmpty
                            ? 'Save songs you love'
                            : 'Saved songs unavailable',
                        icon: Icons.favorite_rounded,
                        onTap: favorites.isEmpty
                            ? null
                            : widget.onPlayFavorites,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ListeningCard(
                        label: 'MOST PLAYED',
                        track: topPlayed?.track,
                        summary: snapshot.hasError
                            ? 'Stats unavailable'
                            : loading
                            ? 'Loading plays…'
                            : topPlayed == null
                            ? 'No plays yet'
                            : topPlayed.track.isAvailable
                            ? '${topPlayed.playCount} plays'
                            : '${topPlayed.playCount} plays · unavailable',
                        emptyMessage: snapshot.hasError
                            ? 'Could not load plays'
                            : loading
                            ? 'Loading listening history'
                            : 'Your repeats will show here',
                        icon: Icons.replay_rounded,
                        onTap: topPlayed == null || !topPlayed.track.isAvailable
                            ? null
                            : () => widget.onPlayTrack(topPlayed.track),
                      ),
                    ),
                  ],
                ),
                if (genres.isNotEmpty || moods.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'YOUR SOUND',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      letterSpacing: 0.9,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final genre in genres)
                          Padding(
                            padding: const EdgeInsets.only(right: 7),
                            child: ActionChip(
                              avatar: const Icon(
                                Icons.library_music_rounded,
                                size: 16,
                              ),
                              label: Text(genre.genre),
                              onPressed: () => widget.onPlayMix(genre.tracks),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        for (final mood in moods)
                          Padding(
                            padding: const EdgeInsets.only(right: 7),
                            child: ActionChip(
                              avatar: const Icon(
                                Icons.wb_twilight_rounded,
                                size: 16,
                              ),
                              label: Text(mood.name),
                              onPressed: () => widget.onPlayMix(mood.tracks),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ListeningCard extends StatelessWidget {
  const _ListeningCard({
    required this.label,
    required this.summary,
    required this.emptyMessage,
    required this.icon,
    required this.onTap,
    this.track,
  });

  final String label;
  final String summary;
  final String emptyMessage;
  final IconData icon;
  final VoidCallback? onTap;
  final ImportedTrack? track;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return MeloGlass(
      borderRadius: MeloRadii.md,
      shadow: false,
      padding: EdgeInsets.zero,
      child: Material(
        color: colors.surfaceContainerLow.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(MeloRadii.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 15, color: MeloColors.cherry),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (track != null)
                      AlbumArtwork(
                        size: 44,
                        title: track!.title,
                        artworkUri: track!.artworkUri == null
                            ? null
                            : Uri.tryParse(track!.artworkUri!),
                        sourceUri: Uri.tryParse(track!.path),
                        borderRadius: 10,
                      )
                    else
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: colors.onSurfaceVariant),
                      ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track?.title ?? emptyMessage,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            track == null
                                ? summary
                                : '$summary · ${displayArtistName(track!.artist)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SavedPlaylists extends StatelessWidget {
  const _SavedPlaylists({
    required this.library,
    required this.onPlay,
    this.audioHandler,
  });

  final MusicLibrary library;
  final ValueChanged<String> onPlay;
  final AudioHandler? audioHandler;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: library,
    builder: (context, _) {
      final playlists = library.playlists;
      if (playlists.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(title: 'Your playlists'),
          const SizedBox(height: 12),
          SizedBox(
            height: 198,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: playlists.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final playlist = playlists[index];
                final playlistTracks = library.tracksForPlaylist(playlist.id);
                final count = playlistTracks.length;
                final themeIndex = playlist.coverStyle != null ? int.tryParse(playlist.coverStyle!) : null;

                return SizedBox(
                  width: 142,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => onPlay(playlist.id),
                      onLongPress: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PlaylistDetailScreen(
                              playlist: playlist,
                              library: library,
                              audioHandler: audioHandler,
                            ),
                          ),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Apple Music Style Square Cover with Play Badge
                          Stack(
                            children: [
                              PlaylistArtwork(
                                playlistName: playlist.name,
                                tracks: playlistTracks,
                                library: library,
                                size: 142,
                                borderRadius: 14,
                                customArtworkUri: playlist.customArtworkUri,
                                themeIndex: themeIndex,
                              ),
                              if (count > 0)
                                Positioned(
                                  right: 8,
                                  bottom: 8,
                                  child: Material(
                                    color: MeloColors.cherry,
                                    shape: const CircleBorder(),
                                    elevation: 4,
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: () => onPlay(playlist.id),
                                      child: const Padding(
                                        padding: EdgeInsets.all(7),
                                        child: Icon(
                                          Icons.play_arrow_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Playlist Title & Count
                          Text(
                            playlist.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$count ${count == 1 ? 'song' : 'songs'}',
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.55),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    },
  );
}

/// A shared heading: a title, an optional one-line explanation, and an
/// optional trailing action. Keeps section rhythm identical across Home.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            ?trailing,
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

class _LibraryPicks extends StatefulWidget {
  const _LibraryPicks({
    required this.library,
    required this.onPlay,
    required this.onSaveSuggestion,
  });

  final MusicLibrary library;
  final ValueChanged<PlaylistSuggestion> onPlay;
  final ValueChanged<PlaylistSuggestion> onSaveSuggestion;

  @override
  State<_LibraryPicks> createState() => _LibraryPicksState();
}

class _LibraryPicksState extends State<_LibraryPicks> {
  int _rotation = 0;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.library,
    builder: (context, _) {
      final suggestions = LocalDiscovery.recommendations(
        widget.library.tracks,
        favoriteTrackIds: {
          for (final track in widget.library.favoriteTracks) track.id,
        },
        rotation: _rotation,
      );
      if (suggestions.isEmpty) {
        return const SizedBox.shrink();
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'Picked for you',
            subtitle: 'One considered pick from the music you already love.',
            trailing: IconButton(
              tooltip: 'Refresh recommendations',
              onPressed: () => setState(() => _rotation++),
              icon: const Icon(Icons.refresh_rounded),
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(height: 12),
          _DiscoveryPickCard(
            suggestion: suggestions.first,
            isSaved: widget.library.playlists.any(
              (playlist) =>
                  playlist.name.toLowerCase() ==
                  suggestions.first.name.toLowerCase(),
            ),
            onPlay: () => widget.onPlay(suggestions.first),
            onSave: () => widget.onSaveSuggestion(suggestions.first),
          ),
        ],
      );
    },
  );
}

class _DiscoveryPickCard extends StatelessWidget {
  const _DiscoveryPickCard({
    required this.suggestion,
    required this.isSaved,
    required this.onPlay,
    required this.onSave,
  });

  final PlaylistSuggestion suggestion;
  final bool isSaved;
  final VoidCallback onPlay;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final artwork = suggestion.tracks.first;
    final (label, icon) = switch (suggestion.type) {
      DiscoveryPickType.artistRadio => ('ARTIST RADIO', Icons.radio_rounded),
      DiscoveryPickType.moodMix => ('MOOD MIX', Icons.wb_twilight_rounded),
      DiscoveryPickType.playlist => (
        'FROM YOUR LIBRARY',
        Icons.auto_awesome_rounded,
      ),
    };
    final radius = BorderRadius.circular(MeloRadii.lg);
    return Tooltip(
      message:
          'Play ${suggestion.name} · ${suggestion.tracks.length} songs from your library',
      child: SizedBox(
        width: double.infinity,
        height: 224,
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPlay,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: AlbumArtwork(
                    size: 184,
                    title: artwork.title,
                    artworkUri: artwork.artworkUri == null
                        ? null
                        : Uri.tryParse(artwork.artworkUri!),
                    sourceUri: Uri.tryParse(artwork.path),
                    borderRadius: 0,
                  ),
                ),
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x22000000),
                          Color(0x28000000),
                          Color(0xF0000000),
                        ],
                        stops: [0, 0.34, 1],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.52),
                      borderRadius: BorderRadius.circular(MeloRadii.pill),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 7,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 12, color: MeloColors.cherrySoft),
                          const SizedBox(width: 5),
                          Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton(
                    tooltip: isSaved ? 'Already in playlists' : 'Save playlist',
                    onPressed: isSaved ? null : onSave,
                    icon: Icon(
                      isSaved ? Icons.check_rounded : Icons.add_rounded,
                      color: Colors.white,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.48),
                      minimumSize: const Size(36, 36),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              suggestion.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${suggestion.tracks.length} songs · ${suggestion.description}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.76),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: onPlay,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(
                          suggestion.type == DiscoveryPickType.artistRadio
                              ? 'Radio'
                              : 'Play mix',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: MeloColors.cherry,
                          foregroundColor: Colors.white,
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
    );
  }
}




class _TopPicksShelf extends StatelessWidget {
  const _TopPicksShelf({
    required this.onPlayVibe,
    required this.onPlayPreset,
  });

  final ValueChanged<SmartVibe> onPlayVibe;
  final ValueChanged<CuratedPlaylistPreset> onPlayPreset;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top Picks for You',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: 22,
                letterSpacing: -0.5,
              ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 195,
          child: ListView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            children: [
              _TopPickCard(
                categoryBadge: 'WE RECOMMEND',
                title: 'Rap Life: Best of 2026',
                description: 'Heavyweight bars and modern street anthems.',
                gradient: const [Color(0xFF2C3E50), Color(0xFF000000)],
                icon: Icons.local_fire_department_rounded,
                onTap: () =>
                    onPlayPreset(_RecommendedPlaylistsSection._playlists[4]),
              ),
              const SizedBox(width: 14),
              _TopPickCard(
                categoryBadge: 'MADE FOR YOU',
                title: "Personal Station",
                description:
                    'Continuous flow tailored to your favorites & library.',
                gradient: const [
                  Color(0xFFD31027),
                  Color(0xFFEA384D),
                  Color(0xFF2B0A12),
                ],
                icon: Icons.graphic_eq_rounded,
                onTap: () => onPlayVibe(SmartVibe.dailyFlow),
              ),
              const SizedBox(width: 14),
              _TopPickCard(
                categoryBadge: 'TRENDING',
                title: 'Afrobeats Essentials',
                description: 'Global heat: Burna, Rema, Tems, Asake & more.',
                gradient: const [Color(0xFFF37335), Color(0xFFFDC830)],
                icon: Icons.bolt_rounded,
                onTap: () =>
                    onPlayPreset(_RecommendedPlaylistsSection._playlists[1]),
              ),
              const SizedBox(width: 14),
              _TopPickCard(
                categoryBadge: 'INSTRUMENTAL',
                title: 'Deep Focus & Study',
                description: 'Ambient lofi and calm instrumental grooves.',
                gradient: const [Color(0xFF0B486B), Color(0xFFF56217)],
                icon: Icons.headphones_rounded,
                onTap: () => onPlayVibe(SmartVibe.deepFocus),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopPickCard extends StatelessWidget {
  const _TopPickCard({
    required this.categoryBadge,
    required this.title,
    required this.description,
    required this.gradient,
    required this.icon,
    required this.onTap,
  });

  final String categoryBadge;
  final String title;
  final String description;
  final List<Color> gradient;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 250,
          height: 195,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            boxShadow: [
              BoxShadow(
                color: gradient.first.withValues(alpha: 0.32),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    categoryBadge,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.72),
                      letterSpacing: 0.8,
                    ),
                  ),
                  Icon(
                    icon,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 20,
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.15,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.7),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentlyPlayedShelf extends StatelessWidget {
  const _RecentlyPlayedShelf({
    required this.library,
    required this.onPlay,
    required this.onOpenLibrary,
  });

  final MusicLibrary library;
  final ValueChanged<ImportedTrack> onPlay;
  final VoidCallback onOpenLibrary;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: library,
      builder: (context, _) {
        final allTracks = library.tracks;
        if (allTracks.isEmpty) return const SizedBox.shrink();

        final recents = allTracks.reversed.take(10).toList(growable: false);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onOpenLibrary,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Recently Played',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                            letterSpacing: -0.5,
                          ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 24,
                      color: Colors.white70,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 182,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: recents.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final track = recents[index];
                  return SizedBox(
                    width: 128,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => onPlay(track),
                        onLongPress: () => TrackDetailsSheet.show(
                          context,
                          track.toMediaItem(),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AlbumArtwork(
                              size: 128,
                              title: track.title,
                              artworkUri: track.artworkUri != null
                                  ? Uri.tryParse(track.artworkUri!)
                                  : null,
                              sourceUri: Uri.tryParse(track.path),
                              borderRadius: 14,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              displayArtistName(track.artist),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StationsForYouShelf extends StatelessWidget {
  const _StationsForYouShelf({
    required this.onPlayVibe,
    this.library,
  });

  final ValueChanged<SmartVibe> onPlayVibe;
  final MusicLibrary? library;

  @override
  Widget build(BuildContext context) {
    final tracks = library?.tracks ?? const [];
    final favorites = library?.favoriteTracks ?? const [];

    final personalTrack = favorites.isNotEmpty
        ? favorites.first
        : (tracks.isNotEmpty ? tracks.first : null);
    final discoveryTrack = tracks.length > 1 ? tracks[1] : null;
    final focusTrack = tracks.length > 2 ? tracks[2] : null;
    final chillTrack = tracks.length > 3 ? tracks[3] : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Stations for You',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      letterSpacing: -0.5,
                    ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: MeloColors.cherry.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sensors_rounded,
                      size: 13, color: MeloColors.cherry),
                  SizedBox(width: 4),
                  Text(
                    'LIVE RADIO',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: MeloColors.cherry,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 194,
          child: ListView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            children: [
              _StationTile(
                title: "Personal Station",
                subtitle: 'Radio Station · Personal flow',
                artworkTrack: personalTrack,
                gradient: const [
                  Color(0xFFE52D27),
                  Color(0xFFB31217),
                  Color(0xFF1E0608),
                ],
                icon: Icons.graphic_eq_rounded,
                onTap: () => onPlayVibe(SmartVibe.dailyFlow),
              ),
              const SizedBox(width: 14),
              _StationTile(
                title: 'Discovery Station',
                subtitle: 'Radio Station · Exploration',
                artworkTrack: discoveryTrack,
                gradient: const [
                  Color(0xFF4A00E0),
                  Color(0xFF8E2DE2),
                  Color(0xFF0F051D),
                ],
                icon: Icons.radar_rounded,
                onTap: () => onPlayVibe(SmartVibe.highEnergy),
              ),
              const SizedBox(width: 14),
              _StationTile(
                title: 'Deep Focus & Study',
                subtitle: 'Radio Station · Instrumental',
                artworkTrack: focusTrack,
                gradient: const [
                  Color(0xFF134E5E),
                  Color(0xFF71B280),
                  Color(0xFF061A21),
                ],
                icon: Icons.headphones_rounded,
                onTap: () => onPlayVibe(SmartVibe.deepFocus),
              ),
              const SizedBox(width: 14),
              _StationTile(
                title: 'Late Night Chill',
                subtitle: 'Radio Station · Midnight soul',
                artworkTrack: chillTrack,
                gradient: const [
                  Color(0xFF3A1C71),
                  Color(0xFFD76D77),
                  Color(0xFF190A2E),
                ],
                icon: Icons.nightlight_round,
                onTap: () => onPlayVibe(SmartVibe.lateNightChill),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StationTile extends StatelessWidget {
  const _StationTile({
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.icon,
    required this.onTap,
    this.artworkTrack,
  });

  final String title;
  final String subtitle;
  final List<Color> gradient;
  final IconData icon;
  final VoidCallback onTap;
  final ImportedTrack? artworkTrack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 136,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 136,
                height: 136,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradient,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: gradient.first.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    children: [
                      if (artworkTrack != null)
                        Positioned.fill(
                          child: AlbumArtwork(
                            size: 136,
                            title: artworkTrack!.title,
                            artworkUri: artworkTrack!.artworkUri != null
                                ? Uri.tryParse(artworkTrack!.artworkUri!)
                                : null,
                            sourceUri: Uri.tryParse(artworkTrack!.path),
                            borderRadius: 0,
                          ),
                        ),
                      if (artworkTrack != null)
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.72),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _FoldedPrismPainter(
                              color: Colors.white.withValues(alpha: 0.14),
                            ),
                          ),
                        ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'melo',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        bottom: 12,
                        child: Icon(
                          icon,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.black,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FoldedPrismPainter extends CustomPainter {
  const _FoldedPrismPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height * 0.4)
      ..lineTo(size.width * 0.7, 0)
      ..lineTo(size.width, size.height * 0.3)
      ..lineTo(size.width * 0.3, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FoldedPrismPainter oldDelegate) => false;
}


class _DjMixPreset {
  const _DjMixPreset({
    required this.title,
    required this.djSubtitle,
    required this.durationBadge,
    required this.searchQuery,
    required this.gradient,
    required this.icon,
  });

  final String title;
  final String djSubtitle;
  final String durationBadge;
  final String searchQuery;
  final List<Color> gradient;
  final IconData icon;
}

class _DjMixShowcaseSection extends StatefulWidget {
  const _DjMixShowcaseSection({
    required this.audioHandler,
    required this.library,
  });

  final AudioHandler? audioHandler;
  final MusicLibrary? library;

  @override
  State<_DjMixShowcaseSection> createState() => _DjMixShowcaseSectionState();
}

class _DjMixShowcaseSectionState extends State<_DjMixShowcaseSection> {
  static const List<_DjMixPreset> _presets = [
    _DjMixPreset(
      title: 'Afrobeats & Amapiano Mix',
      djSubtitle: 'Live Club DJ Set · Turntable Transitions',
      durationBadge: '45+ MIN SET',
      searchQuery: 'Afrobeats Amapiano DJ Mix Nonstop Set 2025',
      gradient: [Color(0xFFFF4E50), Color(0xFFF9D423)],
      icon: Icons.album_rounded,
    ),
    _DjMixPreset(
      title: 'Boiler Room Live Session',
      djSubtitle: 'Underground House & Electronic DJ Set',
      durationBadge: '60+ MIN SET',
      searchQuery: 'Boiler Room DJ Set House Techno Live Mix',
      gradient: [Color(0xFF1F1C2C), Color(0xFF928DAB)],
      icon: Icons.speaker_group_rounded,
    ),
    _DjMixPreset(
      title: 'Hip-Hop & R&B Club Mix',
      djSubtitle: 'Mixed by DJs · Classics & Anthems',
      durationBadge: '50+ MIN SET',
      searchQuery: 'Hip Hop RnB Club DJ Mix Nonstop Turntable Set',
      gradient: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
      icon: Icons.queue_music_rounded,
    ),
    _DjMixPreset(
      title: 'Afro House Sunset Set',
      djSubtitle: 'Deep Melodic & Tribal Rooftop Mix',
      durationBadge: '60+ MIN SET',
      searchQuery: 'Afro House Sunset DJ Mix Keinemusik Style Set',
      gradient: [Color(0xFFEB3349), Color(0xFFF45C43)],
      icon: Icons.wb_twilight_rounded,
    ),
    _DjMixPreset(
      title: 'Dancehall & Party Megamix',
      djSubtitle: 'High-Energy Weekend DJ Blend',
      durationBadge: '45+ MIN SET',
      searchQuery: 'Dancehall Reggae Party DJ Mix Nonstop',
      gradient: [Color(0xFF11998E), Color(0xFF38EF7D)],
      icon: Icons.graphic_eq_rounded,
    ),
  ];

  String? _loadingMixTitle;

  Future<void> _startDjMix(_DjMixPreset preset) async {
    final handler = widget.audioHandler;
    if (handler == null) return;
    if (_loadingMixTitle != null) return;

    setState(() => _loadingMixTitle = preset.title);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Loading DJ Mix: ${preset.title}...'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );

    try {
      final sets = await YoutubeAudioService.instance.searchDjMixes(
        preset.searchQuery,
      );
      if (sets.isEmpty) {
        throw StateError('No DJ mix streams found right now.');
      }
      final leadSet = sets.first;
      final localMatch = widget.library?.findMatchingLocalTrack(
        providerTrackId: leadSet.id,
        title: leadSet.title,
        artist: leadSet.author,
      );
      if (localMatch != null && widget.library != null) {
        final idx = widget.library!.indexOfTrack(localMatch.id);
        if (idx >= 0) {
          await widget.library!.playTrack(handler, idx);
          return;
        }
      }

      final queueItems = sets
          .take(5)
          .map(
            (setTrack) => MediaItem(
              id: 'youtube:${setTrack.id}',
              title: setTrack.title,
              artist: setTrack.author,
              album: 'DJ Mix Set',
              duration: setTrack.duration > Duration.zero
                  ? setTrack.duration
                  : null,
              artUri: setTrack.thumbnailUrl != null
                  ? Uri.tryParse(setTrack.thumbnailUrl!)
                  : null,
              extras: <String, Object?>{
                'videoId': setTrack.id,
                'source': 'youtube',
                'isDjMix': true,
              },
            ),
          )
          .toList(growable: false);

      await handler.updateQueue(queueItems);
      await handler.skipToQueueItem(0);
      await handler.play();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not start DJ mix: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) {
        setState(() => _loadingMixTitle = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.disc_full_rounded,
              size: 18,
              color: MeloColors.cherry,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'DJ Mix Sets · Mixed by DJs',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: MeloColors.cherry.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(MeloRadii.pill),
              ),
              child: const Text(
                'NON-STOP SETS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: MeloColors.cherry,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Real continuous DJ-mixed sets — not individual 3-minute songs.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 148,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: _presets.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final preset = _presets[index];
              final isLoading = _loadingMixTitle == preset.title;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _startDjMix(preset),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 224,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          preset.gradient.first.withValues(alpha: 0.36),
                          preset.gradient.last.withValues(alpha: 0.16),
                        ],
                      ),
                      border: Border.all(
                        color: preset.gradient.first.withValues(alpha: 0.38),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    preset.icon,
                                    color: Colors.white,
                                    size: 13,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    preset.durationBadge,
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 30,
                              height: 30,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: isLoading
                                  ? const Padding(
                                      padding: EdgeInsets.all(7),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.play_arrow_rounded,
                                      color: Colors.black,
                                      size: 18,
                                    ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              preset.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              preset.djSubtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.76),
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
        ),
      ],
    );
  }
}

class _LiveDiscoverySection extends StatefulWidget {
  const _LiveDiscoverySection({
    required this.audioHandler,
    required this.library,
  });

  final AudioHandler? audioHandler;
  final MusicLibrary? library;

  @override
  State<_LiveDiscoverySection> createState() => _LiveDiscoverySectionState();
}

class _LiveDiscoverySectionState extends State<_LiveDiscoverySection> {
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

class _RecommendedPlaylistsSection extends StatelessWidget {
  const _RecommendedPlaylistsSection({
    required this.audioHandler,
    required this.library,
  });

  final AudioHandler? audioHandler;
  final MusicLibrary? library;

  static const List<CuratedPlaylistPreset> _playlists = [
    CuratedPlaylistPreset(
      title: "Today's Top Hits",
      curatorSubtitle: 'Melo Editorial · Global Chart Toppers',
      badge: 'UPDATED TODAY',
      searchQuery: 'Top Pop Global Hits 2025 Official Audio',
      gradient: [Color(0xFFE8173B), Color(0xFF6A051D)],
      icon: Icons.local_fire_department_rounded,
    ),
    CuratedPlaylistPreset(
      title: 'Afrobeats Essentials',
      curatorSubtitle: 'Lagos to the World · Burna, Rema, Tems, Asake',
      badge: 'ESSENTIALS',
      searchQuery: 'Afrobeats Hits 2025 Official Audio',
      gradient: [Color(0xFFFF6B35), Color(0xFF9E2A2B)],
      icon: Icons.bolt_rounded,
    ),
    CuratedPlaylistPreset(
      title: 'Late Night R&B',
      curatorSubtitle: 'Smooth Soul & Midnight Moods',
      badge: 'CHILL & SOUL',
      searchQuery: 'Late Night R&B Soul Hits Official Audio',
      gradient: [Color(0xFF5F0F40), Color(0xFF310E68)],
      icon: Icons.nightlight_round,
    ),
    CuratedPlaylistPreset(
      title: 'Amapiano Grooves',
      curatorSubtitle: 'Log Drums & Private School Piano',
      badge: 'DANCE FLOOR',
      searchQuery: 'Amapiano Hits 2025 Official Audio',
      gradient: [Color(0xFF007991), Color(0xFF222E50)],
      icon: Icons.graphic_eq_rounded,
    ),
    CuratedPlaylistPreset(
      title: 'Rap Life',
      curatorSubtitle: 'Heavyweight Bars & Street Anthems',
      badge: 'HIP-HOP',
      searchQuery: 'Hip Hop Rap Hits 2025 Official Audio',
      gradient: [Color(0xFF232526), Color(0xFF414345)],
      icon: Icons.mic_external_on_rounded,
    ),
    CuratedPlaylistPreset(
      title: 'Pure Focus',
      curatorSubtitle: 'Instrumental Beats for Deep Work',
      badge: 'INSTRUMENTAL',
      searchQuery: 'Chill Lofi Study Beats Instrumental',
      gradient: [Color(0xFF134E5E), Color(0xFF71B280)],
      icon: Icons.headphones_rounded,
    ),
  ];

  void _openPlaylist(BuildContext context, CuratedPlaylistPreset preset) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CuratedPlaylistScreen(
          preset: preset,
          audioHandler: audioHandler,
          library: library,
        ),
      ),
    );
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
              Icons.stars_rounded,
              size: 19,
              color: MeloColors.cherry,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Recommended Playlists',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            Text(
              'Melo Curated Picks',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 204,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: _playlists.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final preset = _playlists[index];
              return SizedBox(
                width: 156,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _openPlaylist(context, preset),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 156,
                          height: 150,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: preset.gradient,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: preset.gradient.first.withValues(
                                  alpha: 0.28,
                                ),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.28,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      preset.badge,
                                      style: const TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    preset.icon,
                                    color: Colors.white.withValues(alpha: 0.85),
                                    size: 18,
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    preset.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      height: 1.15,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.play_arrow_rounded,
                                          color: Colors.black,
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Stream or Save',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white.withValues(
                                            alpha: 0.88,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          preset.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          preset.curatorSubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: colors.onSurfaceVariant,
                                fontSize: 11.5,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}


