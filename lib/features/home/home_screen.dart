import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:melo_player/app/melo_theme.dart';
import 'package:melo_player/features/library/music_library.dart';
import 'package:melo_player/features/library/song_metadata_enricher.dart';
import 'package:melo_player/features/mix/smart_playlist_service.dart';

import 'package:melo_player/features/spotify/spotify_import_sheet.dart';

import 'package:melo_player/features/home/curated_playlist_screen.dart';
import 'package:melo_player/features/home/home_shelves.dart';
import 'package:melo_player/features/search/search_screen.dart';

/// Tone's home is a discovery surface; playback and destinations stay in the
/// persistent player and app navigation.
class HomeScreen extends StatefulWidget {
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

  static String timeOfDayGreeting([DateTime? now]) {
    final hour = (now ?? DateTime.now()).hour;
    if (hour >= 4 && hour < 12) return 'Good morning';
    if (hour >= 12 && hour < 17) return 'Good afternoon';
    if (hour >= 17 && hour < 22) return 'Good evening';
    return 'Late night vibes';
  }

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late String _greeting = HomeScreen.timeOfDayGreeting();
  int _refreshGeneration = 0;
  String _selectedMood = 'All';
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      _clockTimer = Timer.periodic(
        const Duration(seconds: 60),
        (_) => _syncGreeting(),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncGreeting();
    }
  }

  void _syncGreeting() {
    final next = HomeScreen.timeOfDayGreeting();
    if (next != _greeting && mounted) {
      setState(() {
        _greeting = next;
        _refreshGeneration++;
      });
    }
  }

  Future<void> _handleRefresh() async {
    final next = HomeScreen.timeOfDayGreeting();
    if (mounted) {
      setState(() {
        _greeting = next;
        _refreshGeneration++;
      });
    }
    await Future<void>.delayed(const Duration(milliseconds: 260));
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentGreeting = HomeScreen.timeOfDayGreeting();
    if (currentGreeting != _greeting) {
      _greeting = currentGreeting;
    }
    void openSearch() {
      if (widget.onSearch != null) {
        widget.onSearch!();
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SearchScreen(
            audioHandler: widget.audioHandler,
            library: widget.library,
          ),
        ),
      );
    }

    return Container(
      color: MeloColors.amoled,
      child: RefreshIndicator(
        color: MeloColors.cherry,
        backgroundColor: MeloColors.amoled,
        onRefresh: _handleRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Clean Editorial Home Header
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isDark
                                            ? MeloColors.cherry
                                            : colors.primary,
                                        boxShadow: isDark
                                            ? [
                                                BoxShadow(
                                                  color: MeloColors.cherry
                                                      .withValues(alpha: 0.7),
                                                  blurRadius: 6,
                                                ),
                                              ]
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        _greeting.toUpperCase(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: colors.onSurfaceVariant,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 1.0,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Home',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.9,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'More options',
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark
                                    ? MeloColors.qledElevated
                                    : colors.surfaceContainerHigh,
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.16)
                                      : colors.outlineVariant.withValues(
                                          alpha: 0.4,
                                        ),
                                  width: 0.8,
                                ),
                              ),
                              child: Icon(
                                Icons.more_horiz_rounded,
                                size: 20,
                                color: colors.onSurface,
                              ),
                            ),
                            onSelected: (val) {
                              if (val == 'cloud') {
                                SpotifyImportSheet.show(
                                  context,
                                  library: widget.library,
                                  audioHandler: widget.audioHandler,
                                );
                              }
                              if (val == 'stream') {
                                openSearch();
                              }
                              if (val == 'library') widget.onOpenLibrary();
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
                                    Icon(Icons.search_rounded, size: 20),
                                    SizedBox(width: 10),
                                    Text('Search Online & Library'),
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
                      const SizedBox(height: 14),
                      Semantics(
                        button: true,
                        label: 'Search songs, artists, online or library',
                        child: Material(
                          color: isDark
                              ? MeloColors.qledElevated.withValues(alpha: 0.85)
                              : colors.surfaceContainerHigh.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            onTap: openSearch,
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark
                                      ? MeloColors.hdrSpecular.withValues(
                                          alpha: 0.16,
                                        )
                                      : colors.outlineVariant.withValues(
                                          alpha: 0.35,
                                        ),
                                  width: 0.9,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.search_rounded,
                                    size: 20,
                                    color: colors.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Search songs, artists, online or library...',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: colors.onSurfaceVariant,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Mornye-Style Mood & Activity Speed Dial Pills
                      MornyeMoodFilterBar(
                        selectedMood: _selectedMood,
                        onSelectMood: (mood) {
                          setState(() {
                            _selectedMood = mood;
                            _refreshGeneration++;
                          });
                        },
                      ),
                      const SizedBox(height: 20),

                      // Shelf 1: Top Picks for You (Hero Editorial Showcase)
                      TopPicksShelf(
                        library: widget.library,
                        refreshGeneration: _refreshGeneration,
                        onPlayVibe: (vibe) => _openStation(context, vibe),
                        onPlayPreset: (preset) =>
                            _openCuratedPreset(context, preset),
                        onOpenArtistRadio: (artist) =>
                            _openArtistRadio(context, artist),
                      ),
                      const SizedBox(height: 28),

                      // Mornye Shelf: Quick Picks (4-Row Multi-Column Swiper)
                      QuickPicksShelf(
                        audioHandler: widget.audioHandler,
                        library: widget.library,
                        activeMood: _selectedMood,
                      ),
                      const SizedBox(height: 28),

                      // Trace & Soundcity Broadcast Channels
                      BroadcastChannelsShelf(
                        onPlayPreset: (preset) =>
                            _openCuratedPreset(context, preset),
                      ),
                      const SizedBox(height: 28),

                      // Shelf 2: Popular Songs (Global Hits with 1-Tap Play)
                      PopularSongsShelf(
                        audioHandler: widget.audioHandler,
                        library: widget.library,
                      ),
                      const SizedBox(height: 28),

                      // Shelf 3: Live Spotify Feed & Playlist Sync
                      SpotifyFeedShelf(
                        audioHandler: widget.audioHandler,
                        library: widget.library,
                      ),
                      const SizedBox(height: 28),

                      // Shelf 4: Recommended Editorial Playlists (Genre Channel Filtering)
                      if (!kIsWeb && Platform.isAndroid) ...[
                        RecommendedPlaylistsSection(
                          audioHandler: widget.audioHandler,
                          library: widget.library,
                          refreshGeneration: _refreshGeneration,
                        ),
                        const SizedBox(height: 28),
                      ],

                      // Shelf 5: Dynamic Artist Radio Carousel (Songs & Features by Artist)
                      ArtistRadioShelf(
                        library: widget.library,
                        onOpenArtistRadio: (artist) =>
                            _openArtistRadio(context, artist),
                      ),
                      const SizedBox(height: 28),

                      // Shelf 6: Stations for You (Continuous Radio Flow)
                      StationsForYouShelf(
                        library: widget.library,
                        audioHandler: widget.audioHandler,
                        refreshGeneration: _refreshGeneration,
                        onPlayVibe: (vibe) => _openStation(context, vibe),
                        onPlayPreset: (preset) =>
                            _openCuratedPreset(context, preset),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  void _openStation(BuildContext context, SmartVibe vibe) {
    final preset = smartVibeStationPreset(vibe);

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CuratedPlaylistScreen(
          preset: preset,
          audioHandler: widget.audioHandler,
          library: widget.library,
        ),
      ),
    );
  }

  void _openCuratedPreset(BuildContext context, CuratedPlaylistPreset preset) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CuratedPlaylistScreen(
          preset: preset,
          audioHandler: widget.audioHandler,
          library: widget.library,
        ),
      ),
    );
  }

  void _openArtistRadio(BuildContext context, String artistName) {
    final cachedCover = SongMetadataEnricher.instance.cachedArtistImageUrl(
      artistName,
    );
    final preset = CuratedPlaylistPreset(
      title: '$artistName Radio',
      curatorSubtitle: 'With similar artists & trending tracks',
      badge: 'ARTIST RADIO',
      searchQuery: '$artistName songs',
      gradient: [MeloColors.cherry, MeloColors.cherryDeep, const Color(0xFF0A0A0C)],
      icon: Icons.sensors_rounded,
      coverUrl: cachedCover,
      isArtistRadio: true,
      artistName: artistName,
    );

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CuratedPlaylistScreen(
          preset: preset,
          audioHandler: widget.audioHandler,
          library: widget.library,
        ),
      ),
    );
  }
}






