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

import 'package:melo_player/features/spotify/spotify_import_sheet.dart';

import 'package:melo_player/features/home/curated_playlist_screen.dart';
import 'package:melo_player/features/home/home_shelves.dart';
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
              TopPicksShelf(
                onPlayVibe: (vibe) => _openStation(context, vibe),
                onPlayPreset: (preset) => _openCuratedPreset(context, preset),
              ),
              const SizedBox(height: 24),

              // Shelf 3: Recently Played >
              if (library != null && library!.tracks.isNotEmpty) ...[
                RecentlyPlayedShelf(
                  library: library!,
                  onPlay: (track) => _playTrack(context, track),
                  onOpenLibrary: onOpenLibrary,
                ),
                const SizedBox(height: 24),
              ],

              // Shelf 4: Stations for You (Continuous Radio Flow with Real Art)
              StationsForYouShelf(
                library: library,
                onPlayVibe: (vibe) => _openStation(context, vibe),
              ),
              const SizedBox(height: 24),

              // Shelf 5: Recommended Editorial Playlists
              if (!kIsWeb && Platform.isAndroid) ...[
                RecommendedPlaylistsSection(
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

  void _openStation(BuildContext context, SmartVibe vibe) {
    final (title, subtitle, badge, gradient, icon) = switch (vibe) {
      SmartVibe.dailyFlow => (
        'Personal Station',
        'Continuous dynamic stream tailored to your favorites',
        'PERSONAL STATION',
        const [Color(0xFFE52D27), Color(0xFFB31217), Color(0xFF1E0608)],
        Icons.graphic_eq_rounded,
      ),
      SmartVibe.highEnergy => (
        'Discovery Station',
        'Endless exploration & fresh music discoveries',
        'DISCOVERY',
        const [Color(0xFF4A00E0), Color(0xFF8E2DE2), Color(0xFF0F051D)],
        Icons.radar_rounded,
      ),
      SmartVibe.deepFocus => (
        'Deep Focus & Study',
        'Calm instrumental grooves and ambient lofi beats',
        'INSTRUMENTAL',
        const [Color(0xFF134E5E), Color(0xFF71B280), Color(0xFF061A21)],
        Icons.headphones_rounded,
      ),
      SmartVibe.lateNightChill => (
        'Late Night Chill',
        'Mellow acoustic & atmospheric midnight soul',
        'LATE NIGHT',
        const [Color(0xFF3A1C71), Color(0xFFD76D77), Color(0xFF190A2E)],
        Icons.nightlight_round,
      ),
    };

    final preset = CuratedPlaylistPreset(
      title: title,
      curatorSubtitle: subtitle,
      badge: badge,
      searchQuery: '',
      gradient: gradient,
      icon: icon,
      vibe: vibe,
    );

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

