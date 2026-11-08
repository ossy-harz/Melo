import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tone_player/app/tone_glass.dart';
import 'package:tone_player/app/tone_services.dart';
import 'package:tone_player/app/tone_theme.dart';
import 'package:tone_player/features/home/home_screen.dart';
import 'package:tone_player/features/library/imported_track.dart';
import 'package:tone_player/features/library/library_screen.dart';
import 'package:tone_player/features/library/music_library.dart';
import 'package:tone_player/features/mix/personal_mix.dart';
import 'package:tone_player/features/player/mini_player.dart';
import 'package:tone_player/features/search/search_screen.dart';
import 'package:tone_player/features/settings/you_screen.dart';
import 'package:tone_player/features/youtube/youtube_audio_service.dart';

class AppShell extends StatefulWidget {
  const AppShell({this.services, super.key});

  final ToneServices? services;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  final Set<int> _visitedDestinations = {0};
  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = _createScreens();
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.services != widget.services) {
      _screens = _createScreens();
    }
  }

  void _showUnavailable(String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$feature is unavailable in this preview build.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _openMix() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => MixSetupScreen(
          library: widget.services?.musicLibrary,
          audioHandler: widget.services?.audioHandler,
        ),
      ),
    );
  }

  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SearchScreen(
          library: widget.services?.musicLibrary,
          audioHandler: widget.services?.audioHandler,
        ),
      ),
    );
  }

  void _selectDestination(int index) {
    if (index == _selectedIndex) return;
    setState(() {
      _selectedIndex = index;
      _visitedDestinations.add(index);
    });
  }

  List<Widget> _createScreens() => [
    HomeScreen(
      onOpenLibrary: () => _selectDestination(1),
      onSearch: _openSearch,
      audioHandler: widget.services?.audioHandler,
      library: widget.services?.musicLibrary,
    ),
    LibraryScreen(
      onUnavailable: _showUnavailable,
      library: widget.services?.musicLibrary,
      audioHandler: widget.services?.audioHandler,
    ),
    YouScreen(
      onOpenLibrary: () => _selectDestination(1),
      onOpenMix: _openMix,
      audioHandler: widget.services?.audioHandler,
      audioProfileService: widget.services?.audioProfileService,
      library: widget.services?.musicLibrary,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final destinationPages = [
      for (var index = 0; index < _screens.length; index++)
        TickerMode(
          key: ValueKey('destination-$index'),
          enabled: index == _selectedIndex,
          child: _visitedDestinations.contains(index)
              ? _screens[index]
              : const SizedBox.shrink(),
        ),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _selectedIndex, children: destinationPages),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.services != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.bottomCenter,
                    child: MiniPlayer(
                      audioHandler: widget.services!.audioHandler,
                      onOpen: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          fullscreenDialog: true,
                          builder: (context) => NowPlayingScreen(
                            audioHandler: widget.services!.audioHandler,
                            musicLibrary: widget.services!.musicLibrary,
                            onNavigate: (index) {
                              Navigator.of(context).pop();
                              _selectDestination(index);
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (widget.services != null) const SizedBox(height: 6),
              ToneGlass(
                borderRadius: 25,
                blur: 12,
                tint: const Color(0xC9000000),
                borderColor: Colors.white.withValues(alpha: 0.1),
                padding: EdgeInsets.zero,
                child: NavigationBarTheme(
                  data: Theme.of(context).navigationBarTheme.copyWith(
                    backgroundColor: Colors.transparent,
                    indicatorColor: ToneColors.cherry.withValues(alpha: 0.16),
                    height: 68,
                  ),
                  child: NavigationBar(
                    height: 68,
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: (index) {
                      _selectDestination(index);
                    },
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home_rounded),
                        label: 'Home',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.library_music_outlined),
                        selectedIcon: Icon(Icons.library_music_rounded),
                        label: 'Library',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.person_outline_rounded),
                        selectedIcon: Icon(Icons.person_rounded),
                        label: 'You',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MixSetupScreen extends StatefulWidget {
  const MixSetupScreen({this.library, this.audioHandler, super.key});

  final MusicLibrary? library;
  final AudioHandler? audioHandler;

  @override
  State<MixSetupScreen> createState() => _MixSetupScreenState();
}

class _MixSetupScreenState extends State<MixSetupScreen> {
  static const _sessionLengths = [15, 30, 45, 60];
  int _sessionLength = 30;
  double _discovery = 0.35;
  int _seed = 0;
  List<MixPick> _picks = const [];
  final Set<String> _removedFromPreview = {};
  bool _isStarting = false;
  bool _isGenerating = false;
  int _previewRequest = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshMix());
  }

  Future<void> _refreshMix() async {
    final request = ++_previewRequest;
    final library = widget.library;
    if (library == null) {
      if (mounted) {
        setState(() {
          _picks = const [];
          _isGenerating = false;
        });
      }
      return;
    }
    if (mounted) setState(() => _isGenerating = true);
    try {
      final picks = library.generatePersonalMix(
        targetDuration: Duration(minutes: _sessionLength),
        discovery: _discovery,
        randomSeed: _seed,
      );
      if (!mounted || request != _previewRequest) return;
      setState(() {
        _picks = picks
            .where((pick) => !_removedFromPreview.contains(pick.track.id))
            .toList(growable: false);
      });
    } on Object catch (error) {
      if (mounted && request == _previewRequest) {
        setState(() => _picks = const []);
        _showMessage('Could not update mix preview: $error');
      }
    } finally {
      if (mounted && request == _previewRequest) {
        setState(() => _isGenerating = false);
      }
    }
  }

  void _changeSessionLength(int minutes) {
    setState(() {
      _sessionLength = minutes;
      _removedFromPreview.clear();
    });
    unawaited(_refreshMix());
  }

  /// Updates the label while the finger drags, without rebuilding the whole
  /// preview on every frame. The mix is regenerated once the drag ends.
  void _previewDiscovery(double value) => setState(() => _discovery = value);

  void _commitDiscovery(double value) {
    if (value == _discovery && _picks.isNotEmpty) return;
    setState(() {
      _discovery = value;
      _removedFromPreview.clear();
    });
    unawaited(_refreshMix());
  }

  void _shuffleMix() {
    setState(() {
      _seed++;
      _removedFromPreview.clear();
    });
    unawaited(_refreshMix());
  }

  Future<void> _toggleFavorite(ImportedTrack track) async {
    final library = widget.library;
    if (library == null) return;
    try {
      await library.toggleFavorite(track.id);
      if (!mounted) return;
      unawaited(_refreshMix());
    } on Object catch (error) {
      if (!mounted) return;
      _showMessage('Could not update favorite: $error');
    }
  }

  Future<void> _excludeFromFutureMixes(ImportedTrack track) async {
    final library = widget.library;
    if (library == null) return;
    try {
      await library.setMixExcluded(track.id, true);
      if (!mounted) return;
      unawaited(_refreshMix());
      _showMessage('This song will no longer appear in personal mixes.');
    } on Object catch (error) {
      if (!mounted) return;
      _showMessage('Could not update mix preference: $error');
    }
  }

  Future<void> _resetMixExclusions() async {
    final library = widget.library;
    if (library == null) return;
    try {
      await library.resetMixExclusions();
      if (!mounted) return;
      unawaited(_refreshMix());
      _showMessage('Mix exclusions cleared.');
    } on Object catch (error) {
      if (!mounted) return;
      _showMessage('Could not reset mix exclusions: $error');
    }
  }

  Future<void> _startMix() async {
    final library = widget.library;
    final handler = widget.audioHandler;
    if (library == null || handler == null || _picks.isEmpty) return;
    setState(() => _isStarting = true);
    try {
      await library.playMix(handler, _picks.map((pick) => pick.track));
      if (mounted) Navigator.of(context).pop();
    } on Object catch (error) {
      if (mounted) _showMessage('Could not start this mix: $error');
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Duration get _mixDuration => Duration(
    milliseconds: _picks.fold<int>(
      0,
      (total, pick) => total + (pick.track.durationMs ?? 0),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Make a mix'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        children: [
          Text(
            'Make a mix from your music',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.8),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a session length and how familiar or exploratory it feels. '
            'Melo uses available, unexcluded songs that fit the time, then '
            'builds a set that opens gently, rises, and settles with compatible '
            'genre and BPM where those tags are present.',
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          Text('SESSION LENGTH', style: _eyebrowStyle(colors)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final minutes in _sessionLengths)
                ChoiceChip(
                  label: Text('$minutes min'),
                  selected: _sessionLength == minutes,
                  onSelected: (_) => _changeSessionLength(minutes),
                ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: Text(
                  'FAMILIARITY ↔ DISCOVERY',
                  style: _eyebrowStyle(colors),
                ),
              ),
              Text(
                _discovery < 0.34
                    ? 'More favorites'
                    : _discovery > 0.66
                    ? 'More variety'
                    : 'A balance',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Slider(
            value: _discovery,
            onChanged: _previewDiscovery,
            onChangeEnd: _commitDiscovery,
            semanticFormatterCallback: (value) =>
                '${(value * 100).round()} percent preference for other songs',
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text('Your favorites'), Text('Other library songs')],
          ),
          const SizedBox(height: 8),
          Text(
            'This balance changes how strongly saved favorites influence the '
            'selection. It does not send your listening data anywhere.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.secondaryContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  color: colors.onSecondaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Recommendations stay on this device. Melo uses favorites '
                    'and embedded genre/BPM tags when available; it never '
                    'guesses your mood or sends listening history.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSecondaryContainer,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: Text('YOUR MIX', style: _eyebrowStyle(colors))),
              Text(
                '${_picks.length} songs · ${_formatMixDuration(_mixDuration)}',
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
              IconButton(
                tooltip: 'Refresh mix',
                onPressed: widget.library == null || _isGenerating
                    ? null
                    : _shuffleMix,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          if (_isGenerating) const LinearProgressIndicator(),
          if (widget.library?.hasMixExclusions == true)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _resetMixExclusions,
                child: Text(
                  'Clear ${widget.library!.mixExclusionCount} mix exclusions',
                ),
              ),
            ),
          if (widget.library == null || widget.audioHandler == null)
            const _MixEmptyState(
              message: 'Music services are not available in this preview. Open the installed app to build a mix from your library.',
            )
          else if (_picks.isEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MixEmptyState(
                  message: widget.library!.tracks.isEmpty
                      ? 'Your library is empty. Add local audio from Library to make a mix.'
                      : widget.library!.tracksWithDuration == 0
                      ? 'No mixable tracks have a known duration. Rescan your device or grant a music folder so Melo can read track lengths.'
                      : widget.library!.hasMixExclusions
                      ? 'No songs fit the session length with your current exclusions. Choose a longer session or clear the exclusions above.'
                      : 'No tracks fit this session length. Choose a longer session or check the track durations.',
                ),
              ],
            )
          else ...[
            if (widget.library!.tracksWithoutDuration > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${widget.library!.tracksWithoutDuration} songs without a known duration are left out so the session length stays meaningful.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ),
            for (final pick in _picks)
              _MixPickTile(
                pick: pick,
                isFavorite: widget.library!.isFavorite(pick.track.id),
                onToggleFavorite: () => _toggleFavorite(pick.track),
                onRemove: () => setState(() {
                  _removedFromPreview.add(pick.track.id);
                  _picks = _picks
                      .where((candidate) => candidate.track.id != pick.track.id)
                      .toList(growable: false);
                }),
                onExclude: () => _excludeFromFutureMixes(pick.track),
              ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _isStarting || _isGenerating ? null : _startMix,
              icon: _isStarting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label: Text(_isStarting ? 'Starting…' : 'Play this mix'),
            ),
          ],
          const SizedBox(height: 28),
          _DjMixSetsSection(
            audioHandler: widget.audioHandler,
            library: widget.library,
          ),
        ],
      ),
    );
  }

  TextStyle _eyebrowStyle(ColorScheme colors) => Theme.of(context)
      .textTheme
      .labelMedium!
      .copyWith(
        color: colors.onSurfaceVariant,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
      );
}

class _MixEmptyState extends StatelessWidget {
  const _MixEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
  );
}

class _MixPickTile extends StatelessWidget {
  const _MixPickTile({
    required this.pick,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onRemove,
    required this.onExclude,
  });

  final MixPick pick;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onRemove;
  final VoidCallback onExclude;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 2),
    leading: AlbumArtwork(
      size: 48,
      title: pick.track.title,
      artworkUri: pick.track.artworkUri == null
          ? null
          : Uri.tryParse(pick.track.artworkUri!),
      sourceUri: Uri.tryParse(pick.track.path),
      borderRadius: 10,
    ),
    title: Text(pick.track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
    subtitle: Text(
      '${displayArtistName(pick.track.artist)} · ${pick.reason}',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatMixDuration(Duration(milliseconds: pick.track.durationMs!)),
        ),
        IconButton(
          tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
          onPressed: onToggleFavorite,
          icon: Icon(
            isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: isFavorite ? Theme.of(context).colorScheme.primary : null,
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'Mix song options',
          onSelected: (value) {
            if (value == 'remove') onRemove();
            if (value == 'exclude') onExclude();
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'remove', child: Text('Remove from this mix')),
            PopupMenuItem(
              value: 'exclude',
              child: Text('Never include in mixes'),
            ),
          ],
        ),
      ],
    ),
  );
}

String _formatMixDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60);
  return seconds == 0
      ? '${minutes}m'
      : '$minutes:${seconds.toString().padLeft(2, '0')}';
}

class _DjMixSetsSection extends StatefulWidget {
  const _DjMixSetsSection({
    required this.audioHandler,
    required this.library,
  });

  final AudioHandler? audioHandler;
  final MusicLibrary? library;

  @override
  State<_DjMixSetsSection> createState() => _DjMixSetsSectionState();
}

class _DjMixSetsSectionState extends State<_DjMixSetsSection> {
  static const Map<String, String> _vibeQueries = {
    'Afrobeats & Amapiano': 'Afrobeats Amapiano DJ Mix Nonstop Live Set',
    'Boiler Room Sets': 'Boiler Room DJ Set Live Mix',
    'Hip-Hop & R&B Club': 'Hip Hop RnB Club DJ Mix Nonstop Set',
    'Afro House Sunset': 'Afro House Sunset DJ Mix Set',
    'Dancehall & Party': 'Dancehall Reggae Party DJ Mix Nonstop',
  };

  final TextEditingController _searchController = TextEditingController();
  String _selectedVibe = 'Afrobeats & Amapiano';
  List<YoutubeTrack> _djSets = const [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && Platform.isAndroid) {
      unawaited(_fetchSets(_vibeQueries[_selectedVibe]!));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchSets(String query) async {
    if (mounted) {
      setState(() => _isLoading = true);
    }
    try {
      final results = await YoutubeAudioService.instance.searchDjMixes(query);
      if (mounted) {
        setState(() {
          _djSets = results.take(8).toList(growable: false);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _streamSet(YoutubeTrack djSet) async {
    final handler = widget.audioHandler;
    if (handler == null) return;

    final item = MediaItem(
      id: 'youtube:${djSet.id}',
      title: djSet.title,
      artist: djSet.author,
      album: 'DJ Mix Set',
      duration: djSet.duration > Duration.zero ? djSet.duration : null,
      artUri: djSet.thumbnailUrl != null
          ? Uri.tryParse(djSet.thumbnailUrl!)
          : null,
      extras: <String, Object?>{
        'videoId': djSet.id,
        'source': 'youtube',
        'isDjMix': true,
      },
    );

    await handler.updateQueue([item]);
    await handler.skipToQueueItem(0);
    await handler.play();
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
              Icons.disc_full_rounded,
              size: 18,
              color: ToneColors.cherry,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'LIVE DJ MIX SETS · MIXED BY DJS',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Want a real DJ-made continuous mix instead of normal songs? Stream long-form club, lounge, and Boiler Room sets mixed by DJs.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          onSubmitted: (value) {
            final q = value.trim();
            if (q.isNotEmpty) {
              unawaited(_fetchSets(q));
            }
          },
          decoration: InputDecoration(
            hintText: 'Search DJ mixes, Boiler Room, DJ Spinall, Major League...',
            prefixIcon: const Icon(Icons.search_rounded),
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final entry in _vibeQueries.entries) ...[
                ChoiceChip(
                  label: Text(entry.key),
                  selected: _selectedVibe == entry.key,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedVibe = entry.key);
                      unawaited(_fetchSets(entry.value));
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
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.2)),
          )
        else if (_djSets.isEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () =>
                  unawaited(_fetchSets(_vibeQueries[_selectedVibe]!)),
              icon: const Icon(Icons.headphones_rounded, size: 18),
              label: const Text('Load DJ Mix Sets'),
            ),
          )
        else
          for (final djSet in _djSets)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
              leading: AlbumArtwork(
                size: 52,
                title: djSet.title,
                artworkUri: djSet.thumbnailUrl != null
                    ? Uri.tryParse(djSet.thumbnailUrl!)
                    : null,
                borderRadius: 10,
              ),
              title: Text(
                djSet.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${djSet.author} · ${djSet.durationFormatted} DJ Set',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                tooltip: 'Stream DJ Set',
                onPressed: widget.audioHandler == null
                    ? null
                    : () => _streamSet(djSet),
                icon: const Icon(Icons.play_circle_fill_rounded, size: 28),
              ),
              onTap: widget.audioHandler == null
                  ? null
                  : () => _streamSet(djSet),
            ),
      ],
    );
  }
}
