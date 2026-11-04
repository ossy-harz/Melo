import 'dart:ui' show ImageFilter;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:tone_player/app/tone_theme.dart';
import 'package:tone_player/features/library/imported_track.dart';
import 'package:tone_player/features/library/music_library.dart';
import 'package:tone_player/features/mix/local_discovery.dart';
import 'package:tone_player/features/player/mini_player.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.onBuildMix,
    required this.onOpenLibrary,
    this.onOpenSearch,
    this.audioHandler,
    this.library,
    super.key,
  });

  final VoidCallback onBuildMix;
  final VoidCallback onOpenLibrary;
  final VoidCallback? onOpenSearch;
  final AudioHandler? audioHandler;
  final MusicLibrary? library;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
        ? 'Good afternoon'
        : 'Good evening';
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          sliver: SliverList.list(
            children: [
              Row(
                children: [
                  const _ToneMark(),
                  const SizedBox(width: 10),
                  Text(
                    'tone',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const Spacer(),
                  IconButton.filledTonal(
                    tooltip: 'Your listening stays private',
                    onPressed: () => _showPrivacyNote(context),
                    icon: const Icon(Icons.shield_moon_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _HomeSearchBar(onTap: onOpenSearch),
              const SizedBox(height: 20),
              Text(
                '$greeting.',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'A little space for your sound.',
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
              if (audioHandler != null) ...[
                const SizedBox(height: 20),
                _ContinueListening(
                  audioHandler: audioHandler!,
                  library: library,
                ),
              ],
              const SizedBox(height: 24),
              _MixCard(onTap: onBuildMix),
              if (library != null && audioHandler != null) ...[
                const SizedBox(height: 22),
                _MoodMixCarousel(
                  moods: LocalDiscovery.moodMixes(library!.tracks),
                  onPlay: (mood) => _playMoodMix(context, mood),
                ),
              ],
              if (library != null) ...[
                const SizedBox(height: 28),
                _RecentMusic(
                  library: library!,
                  onPlay: (track) => _playTrack(context, track),
                  onOpenLibrary: onOpenLibrary,
                ),
                if (audioHandler != null) ...[
                  const SizedBox(height: 28),
                  _LocalDiscovery(
                    library: library!,
                    onPlayArtistRadio: (artist) =>
                        _playArtistRadio(context, artist),
                    onPlaySuggestion: (suggestion) =>
                        _playSuggestedPlaylist(context, suggestion),
                    onSaveSuggestion: (suggestion) =>
                        _saveSuggestedPlaylist(context, suggestion),
                  ),
                ],
              ],
              if (library?.isEmpty != false) ...[
                const SizedBox(height: 28),
                Text(
                  'Your library',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                _LibraryCard(onTap: onOpenLibrary),
              ],
            ],
          ),
        ),
      ],
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

  Future<void> _playArtistRadio(BuildContext context, String artist) async {
    final musicLibrary = library;
    final handler = audioHandler;
    if (musicLibrary == null || handler == null) return;
    try {
      await musicLibrary.playArtistRadio(handler, artist);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Playing $artist radio from your library.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not start artist radio: $error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<void> _playSuggestedPlaylist(
    BuildContext context,
    PlaylistSuggestion suggestion,
  ) async {
    final musicLibrary = library;
    final handler = audioHandler;
    if (musicLibrary == null || handler == null) return;
    try {
      await musicLibrary.playMix(handler, suggestion.tracks);
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not play this suggestion: $error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<void> _playMoodMix(BuildContext context, LocalMoodMix mood) async {
    final musicLibrary = library;
    final handler = audioHandler;
    if (musicLibrary == null || handler == null) return;
    try {
      await musicLibrary.playMix(handler, mood.tracks);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Playing ${mood.name} from your library tags.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not start ${mood.name}: $error'),
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

  void _showPrivacyNote(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your listening is yours',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              const Text(
                'Tone is being built local-first. The first release will not '
                'require an account to play music or create a personal mix.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocalDiscovery extends StatelessWidget {
  const _LocalDiscovery({
    required this.library,
    required this.onPlayArtistRadio,
    required this.onPlaySuggestion,
    required this.onSaveSuggestion,
  });

  final MusicLibrary library;
  final ValueChanged<String> onPlayArtistRadio;
  final ValueChanged<PlaylistSuggestion> onPlaySuggestion;
  final ValueChanged<PlaylistSuggestion> onSaveSuggestion;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: library,
    builder: (context, _) {
      final artistGroups = <String, List<ImportedTrack>>{};
      for (final track in library.tracks) {
        final artist = displayArtistName(track.artist);
        if (artist.isEmpty || artist == 'On-device audio') continue;
        artistGroups.putIfAbsent(artist.toLowerCase(), () => []).add(track);
      }
      final artistGroupsByCount = artistGroups.values.toList()
        ..sort((first, second) => second.length.compareTo(first.length));
      final artistTracks = artistGroupsByCount
          .take(8)
          .map((group) => group.first)
          .toList(growable: false);
      final suggestions = library.playlistSuggestions;
      if (artistTracks.isEmpty && suggestions.isEmpty) {
        return const SizedBox.shrink();
      }
      final colors = Theme.of(context).colorScheme;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A spark from your library',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            'Personal stations and playlist ideas, made on this device.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          if (artistTracks.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.radio_rounded, size: 18, color: colors.primary),
                const SizedBox(width: 7),
                Text(
                  'ARTIST RADIO',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.9,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 190,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: artistTracks.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final track = artistTracks[index];
                  final artist = displayArtistName(track.artist);
                  final count = library.artistRadioTracks(artist).length;
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.96, end: 1),
                    duration: Duration(milliseconds: 260 + index * 35),
                    curve: Curves.easeOutCubic,
                    child: _DiscoveryArtistCard(
                      track: track,
                      artist: artist,
                      stationCount: count,
                      onTap: () => onPlayArtistRadio(artist),
                    ),
                    builder: (context, scale, child) => Transform.scale(
                      scale: scale,
                      alignment: Alignment.bottomLeft,
                      child: child,
                    ),
                  );
                },
              ),
            ),
          ],
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 18,
                  color: colors.primary,
                ),
                const SizedBox(width: 7),
                Text(
                  'PLAYLIST SPARKS',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.9,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (var index = 0; index < suggestions.length; index++)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.98, end: 1),
                duration: Duration(milliseconds: 280 + index * 50),
                curve: Curves.easeOutCubic,
                child: _PlaylistSuggestionTile(
                  suggestion: suggestions[index],
                  isSaved: library.playlists.any(
                    (playlist) =>
                        playlist.name.toLowerCase() ==
                        suggestions[index].name.toLowerCase(),
                  ),
                  onPlay: () => onPlaySuggestion(suggestions[index]),
                  onSave: () => onSaveSuggestion(suggestions[index]),
                ),
                builder: (context, scale, child) => Transform.scale(
                  scale: scale,
                  alignment: Alignment.centerLeft,
                  child: child,
                ),
              ),
          ],
        ],
      );
    },
  );
}

class _DiscoveryArtistCard extends StatelessWidget {
  const _DiscoveryArtistCard({
    required this.track,
    required this.artist,
    required this.stationCount,
    required this.onTap,
  });

  final ImportedTrack track;
  final String artist;
  final int stationCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 142,
      child: Tooltip(
        message: 'Play $artist radio · $stationCount songs from your library',
        child: Material(
          color: colors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AlbumArtwork(
                          size: 120,
                          title: track.title,
                          artworkUri: track.artworkUri == null
                              ? null
                              : Uri.tryParse(track.artworkUri!),
                          sourceUri: Uri.tryParse(track.path),
                          borderRadius: 14,
                        ),
                        Positioned(
                          right: 7,
                          bottom: 7,
                          child: Icon(
                            Icons.radio_rounded,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.75),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '$stationCount tracks · from your library',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaylistSuggestionTile extends StatelessWidget {
  const _PlaylistSuggestionTile({
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
    final colors = Theme.of(context).colorScheme;
    final artwork = suggestion.tracks.isEmpty ? null : suggestion.tracks.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onPlay,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                if (artwork != null)
                  AlbumArtwork(
                    size: 54,
                    title: artwork.title,
                    artworkUri: artwork.artworkUri == null
                        ? null
                        : Uri.tryParse(artwork.artworkUri!),
                    sourceUri: Uri.tryParse(artwork.path),
                    borderRadius: 13,
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        suggestion.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${suggestion.description} · ${suggestion.tracks.length} songs',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: isSaved ? 'Already in playlists' : 'Save playlist',
                  onPressed: isSaved ? null : onSave,
                  icon: Icon(
                    isSaved
                        ? Icons.playlist_add_check_rounded
                        : Icons.playlist_add_rounded,
                  ),
                ),
                IconButton(
                  tooltip: 'Play ${suggestion.name}',
                  onPressed: onPlay,
                  icon: const Icon(Icons.play_arrow_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MoodMixCarousel extends StatelessWidget {
  const _MoodMixCarousel({required this.moods, required this.onPlay});

  final List<LocalMoodMix> moods;
  final ValueChanged<LocalMoodMix> onPlay;

  @override
  Widget build(BuildContext context) {
    if (moods.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Set the scene',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'Your mood, matched to real tags in your library.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: moods.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final mood = moods[index];
              return SizedBox(
                width: 178,
                child: Material(
                  color: colors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(20),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onPlay(mood),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF701B2B).withValues(alpha: 0.88),
                            colors.surfaceContainerLowest,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _moodIcon(mood.mood),
                                  color: const Color(0xFFFF827A),
                                  size: 19,
                                ),
                                const Spacer(),
                                const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mood.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  mood.description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.65,
                                        ),
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
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

  IconData _moodIcon(LocalMood mood) => switch (mood) {
    LocalMood.morningGlow => Icons.wb_twilight_rounded,
    LocalMood.nightDrive => Icons.nightlight_round,
    LocalMood.softLanding => Icons.spa_rounded,
    LocalMood.fullVolume => Icons.bolt_rounded,
  };
}

class _ContinueListening extends StatelessWidget {
  const _ContinueListening({required this.audioHandler, this.library});

  final AudioHandler audioHandler;
  final MusicLibrary? library;

  @override
  Widget build(BuildContext context) => StreamBuilder<MediaItem?>(
    stream: audioHandler.mediaItem,
    builder: (context, mediaSnapshot) {
      final item = mediaSnapshot.data;
      if (item == null) return const SizedBox.shrink();
      return StreamBuilder<PlaybackState>(
        stream: audioHandler.playbackState,
        builder: (context, stateSnapshot) {
          final isPlaying = stateSnapshot.data?.playing ?? false;
          final position =
              stateSnapshot.data?.updatePosition.inMilliseconds.toDouble() ?? 0;
          final duration = item.duration?.inMilliseconds.toDouble() ?? 0;
          return Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(28),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  fullscreenDialog: true,
                  builder: (_) => NowPlayingScreen(
                    audioHandler: audioHandler,
                    musicLibrary: library,
                  ),
                ),
              ),
              child: SizedBox(
                height: 184,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Opacity(
                      opacity: 0.5,
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                        child: AlbumArtwork(
                          size: 360,
                          title: item.title,
                          artworkUri: item.artUri,
                          sourceUri: Uri.tryParse(item.id),
                          borderRadius: 0,
                        ),
                      ),
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xB8141116),
                            Color(0xA6101014),
                            Color(0xEC08080A),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 15, 18, 15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.graphic_eq_rounded,
                                size: 17,
                                color: Color(0xFFFF7667),
                              ),
                              const SizedBox(width: 7),
                              Text(
                                isPlaying
                                    ? 'NOW IN YOUR FLOW'
                                    : 'PICK UP THE VIBE',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.88,
                                      ),
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1,
                                    ),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.arrow_outward_rounded,
                                size: 17,
                                color: Colors.white.withValues(alpha: 0.76),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Hero(
                                tag: 'tone-art-${item.id}',
                                child: AlbumArtwork(
                                  size: 62,
                                  title: item.title,
                                  artworkUri: item.artUri,
                                  sourceUri: Uri.tryParse(item.id),
                                  borderRadius: 16,
                                ),
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      displayArtistName(
                                        item.artist,
                                        fallback:
                                            item.album == null ||
                                                item.album == 'Unknown album'
                                            ? 'From your library'
                                            : item.album,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Colors.white.withValues(
                                              alpha: 0.72,
                                            ),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton.filled(
                                tooltip: isPlaying ? 'Pause' : 'Play',
                                onPressed: () =>
                                    _togglePlayback(context, isPlaying),
                                style: IconButton.styleFrom(
                                  foregroundColor: const Color(0xFF3A1116),
                                  backgroundColor: Colors.white,
                                  minimumSize: const Size(44, 44),
                                ),
                                icon: Icon(
                                  isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: duration <= 0
                                  ? 0
                                  : (position / duration).clamp(0.0, 1.0),
                              minHeight: 3,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.18,
                              ),
                              color: const Color(0xFFFF7667),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );

  void _togglePlayback(BuildContext context, bool isPlaying) {
    final action = isPlaying ? audioHandler.pause() : audioHandler.play();
    action.catchError((Object error, StackTrace stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'tone home',
          context: ErrorDescription('while toggling playback from Home'),
        ),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not control playback: $error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    });
  }
}

class _RecentMusic extends StatelessWidget {
  const _RecentMusic({
    required this.library,
    required this.onPlay,
    required this.onOpenLibrary,
  });

  final MusicLibrary library;
  final ValueChanged<ImportedTrack> onPlay;
  final VoidCallback onOpenLibrary;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: library,
    builder: (context, _) {
      final allTracks = library.tracks;
      if (allTracks.isEmpty) return const SizedBox.shrink();
      final colors = Theme.of(context).colorScheme;
      final albums = <String, ImportedTrack>{};
      for (final track in allTracks) {
        final key = track.album == 'Unknown album'
            ? track.id
            : '${track.album}\u001f${track.artist}';
        albums.putIfAbsent(key, () => track);
      }
      final speedDial = LocalDiscovery.dailyRotation(
        albums.values,
        date: DateTime.now(),
      ).take(8).toList(growable: false);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Today’s shelf',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              TextButton(
                onPressed: onOpenLibrary,
                child: const Text('Library'),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            'A different corner of your library each day.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 188,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: speedDial.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final track = speedDial[index];
                return SizedBox(
                  width: 136,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onPlay(track),
                      borderRadius: BorderRadius.circular(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AlbumArtwork(
                            size: 132,
                            title: track.album,
                            artworkUri: track.artworkUri == null
                                ? null
                                : Uri.tryParse(track.artworkUri!),
                            sourceUri: Uri.tryParse(track.path),
                            borderRadius: 18,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            track.album == 'Unknown album'
                                ? track.title
                                : track.album,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            displayArtistName(track.artist),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: colors.onSurfaceVariant),
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

class _HomeSearchBar extends StatelessWidget {
  const _HomeSearchBar({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.primary.withValues(alpha: 0.18)),
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: colors.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Search songs, artists, albums',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: colors.onSurfaceVariant.withValues(alpha: 0.72),
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToneMark extends StatelessWidget {
  const _ToneMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF5C111B), ToneColors.ember],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(
        Icons.graphic_eq_rounded,
        color: Colors.white,
        size: 20,
      ),
    );
  }
}

class _MixCard extends StatefulWidget {
  const _MixCard({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_MixCard> createState() => _MixCardState();
}

class _MixCardState extends State<_MixCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ambient;
  bool? _reduceMotion;

  @override
  void initState() {
    super.initState();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (_reduceMotion == reduceMotion) return;
    _reduceMotion = reduceMotion;
    if (reduceMotion) {
      _ambient
        ..stop()
        ..value = 0.5;
    } else {
      _ambient.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ambient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Make a personal mix',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(28),
          child: Ink(
            height: 232,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF351618),
                  Color(0xFF76251F),
                  Color(0xFFB63C2D),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                AnimatedBuilder(
                  animation: _ambient,
                  child: _Orb(size: 210, color: ToneColors.ember),
                  builder: (context, child) => Positioned(
                    top: -56,
                    right: -24,
                    child: Transform.translate(
                      offset: Offset(0, -12 + _ambient.value * 24),
                      child: child,
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: _ambient,
                  child: _Orb(size: 190, color: const Color(0xFFFF7667)),
                  builder: (context, child) => Positioned(
                    right: 68,
                    bottom: -96,
                    child: Transform.translate(
                      offset: Offset(10 - _ambient.value * 20, 0),
                      child: child,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Text(
                          'MADE FOR THIS MOMENT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Set the tone.',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.7,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'A mix that moves with you.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              size: 17,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              'Build your mix',
                              style: TextStyle(
                                color: colors.onSurface,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
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

class _Orb extends StatelessWidget {
  const _Orb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.2),
        border: Border.all(color: color.withValues(alpha: 0.16), width: 22),
      ),
    ),
  );
}

class _LibraryCard extends StatelessWidget {
  const _LibraryCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colors.tertiaryContainer,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(
                  Icons.library_music_rounded,
                  color: colors.onTertiaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bring your music in',
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Start with the songs you already love.',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
