import os

content = r'''import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tone_player/features/library/imported_track.dart';
import 'package:tone_player/features/library/music_library.dart';
import 'package:tone_player/features/player/lyrics_repository.dart';

const _artworkChannel = MethodChannel('app.tone.tone_player/library');
final Map<Uri, Future<Uint8List?>> _artworkCache = {};

Widget _glass({required child, double blur=24, double borderRadius=20, Color? background, double borderWidth=1}) {
  return BackdropFilter(
    filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
    child: Container(
      color: background ?? Colors.transparent,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07), width: borderWidth),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(borderRadius), child: child),
    ),
  );
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child, this.borderRadius=24});
  final Widget child;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _glass(
      child: Container(decoration: BoxDecoration(color: isDark ? const Color(0xFF151518) : const Color(0xFFF7F5F0), borderRadius: BorderRadius.circular(borderRadius))),
      blur: 32,
      borderRadius: borderRadius,
    );
  }
}

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({required this.audioHandler, required this.onOpen, super.key});
  final AudioHandler audioHandler;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, mediaSnapshot) {
        final item = mediaSnapshot.data;
        if (item == null) return const SizedBox.shrink();
        return _GlassPanel(
          child: InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
              child: Row(
                children: [
                  _ArtworkThumb(item: item, size: 44),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                        Text(item.artist ?? 'Unknown artist', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 4),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(width: 36, height: 3, decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.35), borderRadius: const BorderRadius.all(Radius.circular(2)))),
                          const SizedBox(width: 8),
                          Container(width: 52, height: 3, decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.22), borderRadius: const BorderRadius.all(Radius.circular(2)))),
                        ]),
                      ],
                    ),
                  ),
                  StreamBuilder<PlaybackState>(stream: audioHandler.playbackState, builder: (context, stateSnapshot) {
                    final playing = stateSnapshot.data?.playing ?? false;
                    return IconButton(tooltip: playing ? 'Pause' : 'Play', onPressed: () => _run(context, () => playing ? audioHandler.pause() : audioHandler.play()), icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 24));
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({required this.audioHandler, this.musicLibrary, super.key});
  final AudioHandler audioHandler;
  final MusicLibrary? musicLibrary;

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: const Color(0xFF0A0708), body: SafeArea(bottom: false, child: StreamBuilder<MediaItem?>(stream: audioHandler.mediaItem, builder: (context, snapshot) {
      final item = snapshot.data;
      if (item == null) return const Center(child: Text('Select a track to play', style: TextStyle(color: Colors.white70)));
      return _NowPlayingContent(item: item, audioHandler: audioHandler, musicLibrary: musicLibrary);
    })));
  }
}

class _NowPlayingContent extends StatefulWidget {
  const _NowPlayingContent({required this.item, required this.audioHandler, this.musicLibrary});
  final MediaItem item;
  final AudioHandler audioHandler;
  final MusicLibrary? musicLibrary;

  @override
  State<_NowPlayingContent> createState() => _NowPlayingContentState();
}

class _NowPlayingContentState extends State<_NowPlayingContent> {
  final ScrollController _lyricsController = ScrollController();
  SongLyrics? _lyrics;
  bool _isLoadingLyrics = false;
  String? _lyricsError;

  @override
  void initState() {
    super.initState();
    _isLoadingLyrics = true;
    _lyricsError = null;
    unawaited(_restoreLyrics(widget.item));
  }

  @override
  void didUpdateWidget(covariant _NowPlayingContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _lyrics = null;
      _lyricsError = null;
      _isLoadingLyrics = true;
      unawaited(_restoreLyrics(widget.item));
    }
  }

  @override
  void dispose() {
    _lyricsController.dispose();
    super.dispose();
  }

  Future<void> _restoreLyrics(MediaItem item) async {
    try {
      final lyrics = await LyricsRepository.loadFor(item);
      if (!mounted || widget.item.id != item.id) return;
      setState(() { _lyrics = lyrics; _lyricsError = null; });
      _scrollToActiveLine();
    } finally {
      if (mounted && widget.item.id == item.id) setState(() => _isLoadingLyrics = false);
    }
  }

  Future<void> _findLyrics() async {
    setState(() { _isLoadingLyrics = true; _lyricsError = null; });
    try {
      final lyrics = await LyricsRepository.importFor(widget.item);
      if (!mounted || widget.item.id != widget.item.id) return;
      setState(() { _lyrics = lyrics; _lyricsError = null; });
      _scrollToActiveLine();
    } catch (error) {
      if (!mounted || widget.item.id != widget.item.id) return;
      setState(() => _lyricsError = 'Could not load lyrics: \$error');
    } finally {
      if (mounted) setState(() => _isLoadingLyrics = false);
    }
  }

  void _scrollToActiveLine() {
    if (_lyrics == null || !_lyrics!.isSynchronized) return;
    final position = AudioService.position.value ?? Duration.zero;
    final active = _lyrics!.activeLineAt(position);
    if (active < 0) return;
    final line = _lyrics!.lines[active];
    if (line.time == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _lyricsController.jumpTo(_lyricsController.position.min(_lyricsController.position.max(_lyricsController.position.min(_lyricsController.position.positionAt(_lyricsController.position.pixels + 50 + (line.time!.inMilliseconds - 50).toDouble()).clamp(0, _lyricsController.position.maxScrollExtent)), _lyricsController.position.min(_lyricsController.position.maxScrollExtent))));
    });
  }

  Future<void> _toggleFavorite(String trackId) async {
    final library = widget.musicLibrary;
    if (library == null) { _showMessage('Favorites are unavailable in this preview.'); return; }
    try {
      final isFavorite = await library.toggleFavorite(trackId);
      if (!mounted) return;
      _showMessage(isFavorite ? 'Added to favorites.' : 'Removed from favorites.');
    } catch (error) {
      if (!mounted) return;
      _showMessage('Could not update favorite: \$error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  void _openLyrics() {
    final lyrics = _lyrics;
    if (lyrics == null) return;
    showModalBottomSheet(context: context, isScrollControlled: true, useSafeArea: true, backgroundColor: const Color(0xFF100609), builder: (context) => _FullLyricsSheet(title: widget.item.title, artist: displayArtistName(widget.item.artist), lyrics: lyrics));
  }

  Future<void> _handleMenu(String action) async {
    if (action == 'lyrics') {
      await _findLyrics();
    } else if (action == 'read-lyrics') {
      _openLyrics();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlaybackState>(stream: widget.audioHandler.playbackState, builder: (context, stateSnapshot) {
      final state = stateSnapshot.data;
      final duration = widget.item.duration ?? Duration.zero;
      return LayoutBuilder(builder: (context, constraints) {
        final artSize = (constraints.maxWidth - 96).clamp(220.0, (constraints.maxHeight * 0.42).clamp(220, 420)).toDouble();
        return Stack(children: [
          Positioned.fill(child: IgnorePointer(child: Opacity(opacity: 0.48, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 54, sigmaY: 54), child: Align(alignment: const Alignment(0, -0.35), child: AlbumArtwork(size: constraints.maxHeight * 1.35, title: widget.item.title, artworkUri: widget.item.artUri, sourceUri: Uri.tryParse(widget.item.id), borderRadius: 0)))))),
          Positioned.fill(child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: const [Color(0xFF140508).withValues(alpha: 0.42), Color(0xFF2E0B14).withValues(alpha: 0.58), Color(0xFF0A0708).withValues(alpha: 0.97)], stops: [0, 0.5, 1]))))),
          SingleChildScrollView(padding: const EdgeInsets.fromLTRB(24, 20, 24, 28), child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              _GlassIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Close player', onPressed: () => Navigator.of(context).maybePop()),
              const Spacer(),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text('NOW PLAYING', style: Theme.of(context).textTheme.labelMedium?.copyWith(letterSpacing: 1.8, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 2),
                Text(state?.playing == true ? 'IN YOUR FLOW' : 'YOUR MUSIC', style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.2, color: Colors.white70)),
              ]),
              const Spacer(),
              PopupMenuButton<String>(tooltip: 'More options', onSelected: _handleMenu, color: const Color(0xFF1A0A0E), shadowColor: Colors.black, elevation: 8, icon: const Icon(Icons.more_vert_rounded, color: Colors.white), itemBuilder: (context) => [
                if (_lyrics != null) const PopupMenuItem(value: 'read-lyrics', child: Text('Read lyrics')),
                PopupMenuItem(value: 'lyrics', enabled: !_isLoadingLyrics, child: Text(_lyrics == null ? 'Choose lyrics file' : 'Replace lyrics')),
              ]),
            ]),
            const SizedBox(height: 20),
            Hero(tag: 'tone-art-\${widget.item.id}', child: AlbumArtwork(size: artSize, title: widget.item.title, artworkUri: widget.item.artUri, sourceUri: Uri.tryParse(widget.item.id), borderRadius: 24)),
            const SizedBox(height: 18),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(widget.item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5, color: Colors.white)),
                const SizedBox(height: 4),
                Text(widget.item.album == 'Unknown album' ? displayArtistName(widget.item.artist, fallback: 'From your library') : '\${displayArtistName(widget.item.artist)} · \${widget.item.album}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.white70)),
              ])),
              AnimatedBuilder(animation: widget.musicLibrary ?? _NoopListenable.instance, builder: (context, _) {
                final trackId = widget.item.extras?['libraryId'] as String? ?? widget.item.id;
                final isFavorite = widget.musicLibrary?.isFavorite(trackId) ?? false;
                return _GlassIconButton(icon: isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded, tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites', color: isFavorite ? const Color(0xFFFF6258) : Colors.white, onPressed: () => _toggleFavorite(trackId));
              }),
            ]),
            if (_lyrics != null) ...[
              const SizedBox(height: 16),
              _ActiveLyricsPanel(lyrics: _lyrics!, onOpenFull: _openLyrics),
            ] else ...[
              const SizedBox(height: 16),
              _LyricsPanel(isLoading: _isLoadingLyrics, error: _lyricsError, onFindLyrics: _findLyrics),
            ],
            const SizedBox(height: 16),
            _GlassPlaybackControls(isPlaying: state?.playing == true, onPrevious: () => _run(context, widget.audioHandler.skipToPrevious), onToggle: () => _run(context, state?.playing == true ? widget.audioHandler.pause : widget.audioHandler.play), onNext: () => _run(context, widget.audioHandler.skipToNext)),
            const SizedBox(height: 12),
            StreamBuilder<Duration>(stream: AudioService.position, builder: (context, positionSnapshot) {
              final position = _dragPosition ?? (positionSnapshot.data ?? Duration.zero).inMilliseconds.toDouble();
              final max = duration.inMilliseconds.toDouble().clamp(1.0, double.infinity);
              final hasDuration = duration > Duration.zero;
              return Column(children: [
                SliderTheme(data: SliderTheme.of(context).copyWith(trackHeight: 4, activeTrackColor: const Color(0xFFFF554B), inactiveTrackColor: Colors.white24, thumbColor: Colors.white, overlayColor: const Color(0xFFFF554B).withValues(alpha: 0.18), thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8), valueIndicatorShape: const RoundSliderValueIndicatorShape(), valueIndicatorColor: Colors.white, valueIndicatorTextStyle: const TextStyle(color: Color(0xFF1A0A0E), fontSize: 11, fontWeight: FontWeight.w700)), child: Slider(value: position.clamp(0, max), max: max, onChanged: !hasDuration ? null : (value) => setState(() => _dragPosition = value), onChangeEnd: !hasDuration ? null : (value) { setState(() => _dragPosition = null); _run(context, () => widget.audioHandler.seek(Duration(milliseconds: value.round()))); }),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(_formatTime(position.round()), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  Text(hasDuration ? _formatTime(duration.inMilliseconds) : '--:--', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ]);
            }),
          ]),
        ]);
      });
    });
  }

  double? _dragPosition;
}

class AlbumArtwork extends StatelessWidget {
  const AlbumArtwork({required this.size, required this.title, this.iconSize=25, this.artworkUri, this.sourceUri, this.borderRadius, super.key});
  final double size;
  final String title;
  final double iconSize;
  final Uri? artworkUri;
  final Uri? sourceUri;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hue = title.hashCode.abs() % 360;
    final base = HSLColor.fromAHSL(1, hue.toDouble(), 0.32, 0.35).toColor();
    final glow = HSLColor.fromAHSL(1, (hue + 48) % 360, 0.52, 0.65).toColor();
    final artwork = artworkUri != null || sourceUri != null ? _loadArtwork(artworkUri, sourceUri) : null;
    return Semantics(label: 'Artwork for \$title', image: true, child: Container(width: size, height: size, decoration: BoxDecoration(borderRadius: BorderRadius.circular(borderRadius ?? size * 0.12), gradient: LinearGradient(colors: [glow, base, colors.primary.withValues(alpha: 0.85)], begin: Alignment.topLeft, end: Alignment.bottomRight), boxShadow: [BoxShadow(color: base.withValues(alpha: 0.25), blurRadius: 32, offset: const Offset(0, 16))]), clipBehavior: Clip.antiAlias, child: artwork == null ? _fallbackIcon() : FutureBuilder<Uint8List?>(future: artwork, builder: (context, snapshot) { final bytes = snapshot.data; if (bytes == null || bytes.isEmpty) return _fallbackIcon(); final decodeSize = (size * MediaQuery.devicePixelRatioOf(context)).ceil().clamp(64, 1024); return Image.memory(bytes, fit: BoxFit.cover, cacheWidth: decodeSize, cacheHeight: decodeSize, errorBuilder: (_, __, ___) => _fallbackIcon()); })),
  );

  Widget _fallbackIcon() => Icon(Icons.graphic_eq_rounded, color: Colors.white, size: iconSize);
}

Future<Uint8List?> _loadArtwork(Uri? artworkUri, Uri? sourceUri) {
  final cacheKey = artworkUri ?? sourceUri!;
  return _artworkCache.putIfAbsent(cacheKey, () async {
    try {
      final bytes = await _artworkChannel.invokeMethod<Uint8List>('getArtwork', {'uri': artworkUri?.toString(), 'sourceUri': sourceUri?.toString()});
      if (bytes == null || bytes.isEmpty) { _artworkCache.remove(cacheKey); return null; }
      if (_artworkCache.length > 64) { _artworkCache.remove(_artworkCache.keys.first); }
      return bytes;
    } on PlatformException { _artworkCache.remove(cacheKey); return null; }
  });
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.tooltip, required this.onPressed, this.color});
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(tooltip: tooltip, onPressed: onPressed, icon: Icon(icon, color: color ?? Theme.of(context).colorScheme.onSurface, size: 22), style: IconButton.styleFrom(backgroundColor: Colors.transparent, padding: const EdgeInsets.all(8), minimumSize: const Size(40, 40), tapTargetSize: MaterialTapTargetSize.shrinkWrap));
  }
}

class _GlassPlaybackControls extends StatelessWidget {
  const _GlassPlaybackControls({required this.isPlaying, required this.onPrevious, required this.onToggle, required this.onNext});
  final bool isPlaying;
  final VoidCallback onPrevious;
  final VoidCallback onToggle;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      _GlassIconButton(icon: Icons.skip_previous_rounded, tooltip: 'Previous', onPressed: onPrevious),
      _GlassIconButton(icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, tooltip: isPlaying ? 'Pause' : 'Play', onPressed: onToggle, color: Theme.of(context).colorScheme.primary),
      _GlassIconButton(icon: Icons.skip_next_rounded, tooltip: 'Next', onPressed: onNext),
    ]);
  }
}

class _ActiveLyricsPanel extends StatefulWidget {
  const _ActiveLyricsPanel({required this.lyrics, required this.onOpenFull});
  final SongLyrics lyrics;
  final VoidCallback onOpenFull;

  @override
  State<_ActiveLyricsPanel> createState() => _ActiveLyricsPanelState();
}

class _ActiveLyricsPanelState extends State<_ActiveLyricsPanel> {
  final ScrollController _controller = ScrollController();
  int _hoveredLine = -1;
  int _activeLine = 0;

  @override
  void initState() {
    super.initState();
    _activeLine = widget.lyrics.activeLineAt(AudioService.position.value ?? Duration.zero);
  }

  @override
  void didUpdateWidget(covariant _ActiveLyricsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lyrics != widget.lyrics) {
      _activeLine = widget.lyrics.activeLineAt(AudioService.position.value ?? Duration.zero);
      _controller.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(stream: AudioService.position, builder: (context, snapshot) {
      final position = snapshot.data ?? Duration.zero;
      final active = widget.lyrics.activeLineAt(position);
      if (active != _activeLine) { _activeLine = active; _controller.jumpTo(0); }
      return _glass(child: InkWell(onTap: widget.onOpenFull, borderRadius: 20, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Lyrics', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
          if (widget.lyrics.isSynchronized) Text('\${widget.lyrics.lines.length} lines', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6))),
        ]),
        const SizedBox(height: 10),
        SizedBox(height: 180, child: ListView.separated(controller: _controller, scrollDirection: Axis.vertical, itemCount: widget.lyrics.lines.length, separatorBuilder: (_, __) => const SizedBox(height: 4), itemBuilder: (context, index) {
          final line = widget.lyrics.lines[index];
          final isActive = index == _activeLine;
          return GestureDetector(onHover: (hovering) => setState(() => _hoveredLine = hovering ? index : -1), child: AnimatedContainer(duration: const Duration(milliseconds: 120), decoration: BoxDecoration(color: isActive ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12) : _hoveredLine == index ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.06) : Colors.transparent, borderRadius: BorderRadius.circular(6)), child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(line.text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 15, fontWeight: isActive ? FontWeight.w700 : FontWeight.w400, color: isActive ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.85)))));
        })),
      ]))));
    });
  }
}

class _LyricsPanel extends StatelessWidget {
  const _LyricsPanel({required this.isLoading, required this.error, required this.onFindLyrics});
  final bool isLoading;
  final String? error;
  final VoidCallback onFindLyrics;

  @override
  Widget build(BuildContext context) {
    return _glass(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Lyrics', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      if (isLoading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(strokeWidth: 2)))
      else if (error != null) Column(children: [
        Text(error!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error)),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: onFindLyrics, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
      ]) else Column(children: [
        Text('No matching lyrics file was found. Add one once and Tone will keep it on this device.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: onFindLyrics, icon: const Icon(Icons.lyrics_outlined), label: const Text('Choose lyrics file')),
      ]),
    ])),
    blur: 16,
    );
  }
}

class _FullLyricsSheet extends StatelessWidget {
  const _FullLyricsSheet({required this.title, required this.artist, required this.lyrics});
  final String title;
  final String artist;
  final SongLyrics lyrics;

  @override
  Widget build(BuildContext context) {
    return Container(color: const Color(0xFF0A0708), child: Column(children: [
      Container(color: const Color(0xFF140A0C), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), child: Row(children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: Colors.white)),
        const Spacer(),
        IconButton(tooltip: 'Close lyrics', onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded, color: Colors.white)),
      ])),
      Expanded(child: _glass(child: Container(padding: const EdgeInsets.fromLTRB(24, 12, 24, 32), alignment: Alignment.center, child: ListView.separated(controller: ScrollController(), itemCount: lyrics.lines.length, separatorBuilder: (_, __) => const SizedBox(height: 6), itemBuilder: (context, index) { final line = lyrics.lines[index]; return Text(line.text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface)); }), blur: 12))),
    ]));
  }
}

class _NoopListenable implements Listenable {
  const _NoopListenable._();
  static const instance = _NoopListenable._();
  @override void addListener(VoidCallback listener) {}
  @override void removeListener(VoidCallback listener) {}
}

class _ArtworkThumb extends StatelessWidget {
  const _ArtworkThumb({required this.item, required this.size});
  final MediaItem item;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AlbumArtwork(size: size, title: item.title, artworkUri: item.artUri, sourceUri: Uri.tryParse(item.id), borderRadius: 12);
  }
}

String _formatTime(int milliseconds) {
  final totalSeconds = (milliseconds / 1000).floor();
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '\$minutes:\${seconds.toString().padLeft(2, '0')}';
}

void _run(BuildContext context, Future<void> Function() action) {
  action().catchError((Object error, StackTrace stackTrace) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text('Playback action failed: \$error'), behavior: SnackBarBehavior.floating));
  });
}
'''
with open('lib/features/player/mini_player.dart', 'w', encoding='utf-8', newline='\n') as f:
    f.write(content)
print('written', len(content), 'bytes')
