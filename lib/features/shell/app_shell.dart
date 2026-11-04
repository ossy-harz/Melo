import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:tone_player/app/tone_services.dart';
import 'package:tone_player/features/home/home_screen.dart';
import 'package:tone_player/features/library/imported_track.dart';
import 'package:tone_player/features/library/library_screen.dart';
import 'package:tone_player/features/library/music_library.dart';
import 'package:tone_player/features/mix/personal_mix.dart';
import 'package:tone_player/features/player/mini_player.dart';
import 'package:tone_player/features/search/search_screen.dart';
import 'package:tone_player/features/settings/you_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({this.services, super.key});

  final ToneServices? services;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$feature is planned for an upcoming build.'),
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

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        onBuildMix: _openMix,
        onOpenLibrary: () => setState(() => _selectedIndex = 2),
        onOpenSearch: () => setState(() => _selectedIndex = 1),
        audioHandler: widget.services?.audioHandler,
        library: widget.services?.musicLibrary,
      ),
      SearchScreen(
        library: widget.services?.musicLibrary,
        audioHandler: widget.services?.audioHandler,
      ),
      LibraryScreen(
        onUnavailable: _showComingSoon,
        onSearch: () => setState(() => _selectedIndex = 1),
        library: widget.services?.musicLibrary,
        audioHandler: widget.services?.audioHandler,
      ),
      YouScreen(
        onOpenLibrary: () => setState(() => _selectedIndex = 2),
        onOpenMix: _openMix,
        audioHandler: widget.services?.audioHandler,
        library: widget.services?.musicLibrary,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _selectedIndex, children: screens),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.services != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
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
                          setState(() => _selectedIndex = index);
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],
            NavigationBar(
              height: 68,
              backgroundColor: Colors.white,
              indicatorColor: const Color(0xFFE9EAEC),
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() => _selectedIndex = index);
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.search_rounded),
                  label: 'Search',
                ),
                NavigationDestination(
                  icon: Icon(Icons.library_music_outlined),
                  selectedIcon: Icon(Icons.library_music_rounded),
                  label: 'Library',
                ),
                NavigationDestination(
                  icon: Icon(Icons.local_fire_department_outlined),
                  selectedIcon: Icon(Icons.local_fire_department_rounded),
                  label: 'Hotlist',
                ),
              ],
            ),
          ],
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
  List<MixPick> _picks = const [];
  final Set<String> _removedFromPreview = {};
  bool _isStarting = false;

  @override
  void initState() {
    super.initState();
    _refreshMix();
  }

  void _refreshMix() {
    final library = widget.library;
    if (library == null) {
      _picks = const [];
      return;
    }
    _picks = library
        .generatePersonalMix(
          targetDuration: Duration(minutes: _sessionLength),
          discovery: _discovery,
        )
        .where((pick) => !_removedFromPreview.contains(pick.track.id))
        .toList(growable: false);
  }

  void _changeIntent({int? minutes, double? discovery}) {
    setState(() {
      if (minutes != null) _sessionLength = minutes;
      if (discovery != null) _discovery = discovery;
      _removedFromPreview.clear();
      _refreshMix();
    });
  }

  Future<void> _toggleFavorite(ImportedTrack track) async {
    final library = widget.library;
    if (library == null) return;
    try {
      await library.toggleFavorite(track.id);
      if (!mounted) return;
      setState(_refreshMix);
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
      setState(_refreshMix);
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
      setState(_refreshMix);
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
            'Choose a session length and how much to lean toward your favorites. '
            'Tone uses tagged genre and BPM metadata to keep compatible songs '
            'together, then makes a gentle fade handoff between tracks.',
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
                  onSelected: (_) => _changeIntent(minutes: minutes),
                ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: Text(
                  'FAVORITES ↔ OTHER SONGS',
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
            onChanged: (value) => _changeIntent(discovery: value),
            semanticFormatterCallback: (value) =>
                '${(value * 100).round()} percent preference for other songs',
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text('Your favorites'), Text('Other library songs')],
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
                    'Recommendations stay on this device. Tone uses favorites '
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
                onPressed: widget.library == null
                    ? null
                    : () => setState(() {
                        _removedFromPreview.clear();
                        _refreshMix();
                      }),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
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
                      ? 'No mixable tracks have a known duration. Rescan your device or grant a music folder so Tone can read track lengths.'
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
              onPressed: _isStarting ? null : _startMix,
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
