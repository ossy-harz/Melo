import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FontFeature, ImageFilter;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tone_player/features/library/imported_track.dart';
import 'package:tone_player/features/library/music_library.dart';
import 'package:tone_player/features/player/audio_waveform.dart';
import 'package:tone_player/features/player/dj_transition.dart';
import 'package:tone_player/features/player/lyrics_repository.dart';

const _artworkChannel = MethodChannel('app.tone.tone_player/library');
final Map<Uri, Future<Uint8List?>> _artworkCache = {};
final Map<String, Future<Map<String, Object?>?>> _audioQualityCache = {};
final Map<String, Future<AudioWaveformData>> _audioWaveformCache = {};

Future<Map<String, Object?>?> _audioQualityFor(MediaItem item) =>
    _audioQualityCache.putIfAbsent(item.id, () async {
      if (defaultTargetPlatform != TargetPlatform.android) return null;
      return _artworkChannel.invokeMapMethod<String, Object?>(
        'readAudioQuality',
        {'uri': item.id},
      );
    });

String _audioQualityLabel(Map<String, Object?> details) {
  final mimeType = details['mimeType'] as String?;
  if (mimeType == null || mimeType.isEmpty) return 'Unavailable';
  final codec = switch (mimeType.toLowerCase()) {
    final value when value.contains('flac') => 'FLAC',
    final value when value.contains('mpeg') || value.contains('mp3') => 'MP3',
    final value when value.contains('aac') || value.contains('mp4a') => 'AAC',
    final value when value.contains('opus') => 'Opus',
    final value when value.contains('vorbis') => 'Vorbis',
    final value when value.contains('alac') => 'ALAC',
    final value
        when value.contains('pcm') ||
            value.contains('wav') ||
            value.contains('raw') =>
      'PCM',
    _ => mimeType.substring(mimeType.indexOf('/') + 1).toUpperCase(),
  };
  final sampleRate = (details['sampleRate'] as num?)?.toInt();
  final channels = (details['channelCount'] as num?)?.toInt();
  final bitRate = (details['bitRate'] as num?)?.toInt();
  return [
    codec,
    if (sampleRate != null && sampleRate > 0)
      '${(sampleRate / 1000).toStringAsFixed(sampleRate % 1000 == 0 ? 0 : 1)} kHz',
    if (channels != null && channels > 0)
      channels == 1
          ? 'Mono'
          : channels == 2
          ? 'Stereo'
          : '$channels ch',
    if (bitRate != null && bitRate > 0) '${bitRate ~/ 1000} kbps',
  ].join(' · ');
}

Future<AudioWaveformData> _audioWaveformFor(MediaItem item) {
  final existing = _audioWaveformCache[item.id];
  if (existing != null) return existing;
  final request = () async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError(
        'Audio waveform analysis is currently available on Android.',
      );
    }
    final values = await _artworkChannel.invokeListMethod<Object?>(
      'readAudioWaveform',
      {'uri': item.id, 'binCount': 256},
    );
    if (values == null) {
      throw StateError('Android did not return an audio waveform.');
    }
    return AudioWaveformData.fromPlatform(values);
  }();
  _audioWaveformCache[item.id] = request;
  if (_audioWaveformCache.length > 24) {
    _audioWaveformCache.remove(_audioWaveformCache.keys.first);
  }
  return request;
}

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({
    required this.audioHandler,
    required this.onOpen,
    super.key,
  });

  final AudioHandler audioHandler;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => StreamBuilder<MediaItem?>(
    stream: audioHandler.mediaItem,
    builder: (context, mediaSnapshot) {
      final item = mediaSnapshot.data;
      if (item == null) return const SizedBox.shrink();
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF171A20),
          borderRadius: BorderRadius.circular(18),
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 6, 10),
                  child: Row(
                    children: [
                      Hero(
                        tag: 'tone-art-${item.id}',
                        child: AlbumArtwork(
                          size: 44,
                          title: item.title,
                          artworkUri: item.artUri,
                          sourceUri: Uri.tryParse(item.id),
                          borderRadius: 10,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                    color: Colors.white,
                                  ),
                            ),
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
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.64),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      StreamBuilder<PlaybackState>(
                        stream: audioHandler.playbackState,
                        builder: (context, stateSnapshot) {
                          final playing = stateSnapshot.data?.playing ?? false;
                          return IconButton(
                            tooltip: playing ? 'Pause' : 'Play',
                            onPressed: () => _run(context, () {
                              return playing
                                  ? audioHandler.pause()
                                  : audioHandler.play();
                            }),
                            style: IconButton.styleFrom(
                              minimumSize: const Size(38, 38),
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF171A20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: Icon(
                              playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 0,
                  child: StreamBuilder<Duration>(
                    stream: _positionStream(audioHandler),
                    builder: (context, positionSnapshot) {
                      final duration = item.duration?.inMilliseconds ?? 0;
                      final position =
                          positionSnapshot.data?.inMilliseconds ?? 0;
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: duration <= 0
                              ? 0
                              : (position / duration).clamp(0.0, 1.0),
                          minHeight: 2.5,
                          backgroundColor: Colors.white.withValues(alpha: 0.12),
                          color: Colors.white.withValues(alpha: 0.88),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({
    required this.audioHandler,
    this.musicLibrary,
    this.onNavigate,
    super.key,
  });

  final AudioHandler audioHandler;
  final MusicLibrary? musicLibrary;
  final ValueChanged<int>? onNavigate;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
    child: Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<MediaItem?>(
        stream: audioHandler.mediaItem,
        builder: (context, snapshot) {
          final item = snapshot.data;
          if (item == null) {
            return const Center(
              child: Text('Choose a song from your library.'),
            );
          }
          return _NowPlayingContent(
            item: item,
            audioHandler: audioHandler,
            musicLibrary: musicLibrary,
            onNavigate: onNavigate,
          );
        },
      ),
    ),
  );
}

class _NowPlayingContent extends StatefulWidget {
  const _NowPlayingContent({
    required this.item,
    required this.audioHandler,
    this.musicLibrary,
    this.onNavigate,
  });

  final MediaItem item;
  final AudioHandler audioHandler;
  final MusicLibrary? musicLibrary;
  final ValueChanged<int>? onNavigate;

  @override
  State<_NowPlayingContent> createState() => _NowPlayingContentState();
}

class _NowPlayingContentState extends State<_NowPlayingContent>
    with TickerProviderStateMixin {
  double? _dragPosition;
  SongLyrics? _lyrics;
  String? _lyricsMessage;
  bool _isLoadingLyrics = false;
  bool _isScratching = false;
  bool _scratchWasPlaying = false;
  double _scratchDistance = 0;
  int _lastScratchHaptic = 0;
  DjMixMode _djMixMode = DjMixMode.off;
  DjMixMode _lastActiveDjMixMode = DjMixMode.beatMatched;
  late final AnimationController _ambient;
  late final AnimationController _glow;
  bool _wasPlaying = false;

  @override
  void initState() {
    super.initState();
    _isLoadingLyrics = true;
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    );
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    unawaited(_restoreLyrics(widget.item));
    unawaited(_loadDjMixMode());
  }

  @override
  void dispose() {
    _ambient.dispose();
    _glow.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _NowPlayingContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _lyrics = null;
      _lyricsMessage = null;
      _isLoadingLyrics = true;
      unawaited(_restoreLyrics(widget.item));
    }
  }

  Future<void> _restoreLyrics(MediaItem item) async {
    try {
      final lyrics = await LyricsRepository.loadFor(item);
      if (!mounted || widget.item.id != item.id) return;
      setState(() {
        _lyrics = lyrics;
        _lyricsMessage = null;
      });
    } on LyricsServiceUnavailableException {
      if (mounted && widget.item.id == item.id) {
        setState(
          () => _lyricsMessage = 'Lyrics service unavailable · Tap to retry',
        );
      }
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'tone player',
          context: ErrorDescription('while loading local song lyrics'),
        ),
      );
      if (mounted && widget.item.id == item.id) {
        _showMessage('Could not load saved lyrics: $error');
      }
    } finally {
      if (mounted && widget.item.id == item.id) {
        setState(() => _isLoadingLyrics = false);
      }
    }
  }

  Future<void> _findLyrics() async {
    final item = widget.item;
    setState(() {
      _isLoadingLyrics = true;
    });
    try {
      final lyrics = await LyricsRepository.importFor(item);
      if (!mounted || widget.item.id != item.id) return;
      setState(() {
        _lyrics = lyrics;
        _lyricsMessage = null;
      });
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'tone player',
          context: ErrorDescription('while importing song lyrics'),
        ),
      );
      if (mounted) _showMessage('Could not add lyrics: $error');
    } finally {
      if (mounted) setState(() => _isLoadingLyrics = false);
    }
  }

  Future<void> _loadDjMixMode() async {
    try {
      final savedName = await widget.audioHandler.customAction('getDjMixMode');
      final mode = DjMixMode.values.firstWhere(
        (candidate) => candidate.name == savedName,
        orElse: () => throw FormatException(
          'The saved DJ mix mode is not recognized: $savedName',
        ),
      );
      if (!mounted) return;
      setState(() {
        _djMixMode = mode;
        if (mode != DjMixMode.off) _lastActiveDjMixMode = mode;
      });
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'tone player',
          context: ErrorDescription('while reading Now Playing DJ mode'),
        ),
      );
      if (mounted) _showMessage('Could not read the DJ mode: $error');
    }
  }

  Future<void> _toggleDjMode() async {
    final mode = _djMixMode == DjMixMode.off
        ? _lastActiveDjMixMode
        : DjMixMode.off;
    try {
      await widget.audioHandler.customAction('setDjMixMode', {
        'mode': mode.name,
      });
      if (!mounted) return;
      setState(() {
        _djMixMode = mode;
        if (mode != DjMixMode.off) _lastActiveDjMixMode = mode;
      });
      _showMessage(
        mode == DjMixMode.off
            ? 'DJ transitions are off.'
            : 'DJ transitions are on: ${_djModeLabel(mode)}.',
      );
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'tone player',
          context: ErrorDescription('while changing Now Playing DJ mode'),
        ),
      );
      if (mounted) _showMessage('Could not change DJ mode: $error');
    }
  }

  String _djModeLabel(DjMixMode mode) => switch (mode) {
    DjMixMode.off => 'off',
    DjMixMode.smooth => 'smooth blend',
    DjMixMode.beatMatched => 'beat-matched blend',
  };

  void _beginDeckNudge() {
    _scratchWasPlaying = widget.audioHandler.playbackState.value.playing;
    if (!_scratchWasPlaying || _djMixMode == DjMixMode.off) return;
    _scratchDistance = 0;
    _lastScratchHaptic = 0;
    setState(() => _isScratching = true);
  }

  void _updateDeckNudge(DragUpdateDetails details) {
    if (!_isScratching) return;
    _scratchDistance += details.delta.dx;
    final hapticStep = (_scratchDistance.abs() / 42).floor();
    if (hapticStep > _lastScratchHaptic) {
      _lastScratchHaptic = hapticStep;
      HapticFeedback.selectionClick();
    }
    final speed = (1 + details.delta.dx / 72).clamp(0.65, 1.35);
    _run(
      context,
      () async =>
          widget.audioHandler.customAction('scratchDeck', {'speed': speed}),
    );
  }

  void _endDeckNudge() {
    if (!_isScratching) return;
    setState(() => _isScratching = false);
    _run(
      context,
      () async =>
          widget.audioHandler.customAction('scratchDeck', {'speed': 1.0}),
    );
  }

  Future<void> _playArtistRadio() async {
    final library = widget.musicLibrary;
    final artist = widget.item.artist?.trim();
    if (library == null ||
        artist == null ||
        artist.isEmpty ||
        artist.toLowerCase() == 'unknown artist' ||
        artist.toLowerCase() == 'on-device audio') {
      _showMessage('Artist radio needs a known artist and local library.');
      return;
    }
    try {
      await library.playArtistRadio(widget.audioHandler, artist);
      if (mounted) _showMessage('Playing $artist radio from your library.');
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'tone player',
          context: ErrorDescription('while starting Now Playing artist radio'),
        ),
      );
      if (mounted) _showMessage('Could not start artist radio: $error');
    }
  }

  void _openTrackDetails() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.48),
      builder: (context) => _TrackDetailsSheet(item: widget.item),
    );
  }

  void _retryWaveform() {
    _audioWaveformCache.remove(widget.item.id);
    setState(() {});
  }

  Future<void> _findLyricsOnline() async {
    final item = widget.item;
    try {
      if (!await LyricsRepository.onlineLookupEnabled) {
        if (!mounted) return;
        final approved = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Find lyrics online?'),
            content: const Text(
              'Tone will send this song’s title, artist, album, and duration to '
              'LRCLIB to find matching lyrics. Your listening history is not sent. '
              'You can turn automatic online lyrics off in Privacy & your data.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Not now'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Enable & search'),
              ),
            ],
          ),
        );
        if (approved != true) return;
        await LyricsRepository.setOnlineLookupEnabled(true);
      }

      if (!mounted) return;
      setState(() => _isLoadingLyrics = true);
      final lyrics = await LyricsRepository.findOnlineFor(item);
      if (!mounted || widget.item.id != item.id) return;
      setState(() {
        _lyrics = lyrics;
        _lyricsMessage = lyrics == null ? 'No matching lyrics found' : null;
      });
      if (lyrics == null) {
        _showMessage('No matching lyrics found. You can add a lyrics file.');
      }
    } on LyricsServiceUnavailableException catch (error) {
      if (mounted && widget.item.id == item.id) {
        setState(() => _lyricsMessage = 'Lyrics service unavailable');
        _showMessage('$error Try again in a little while.');
      }
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'tone player',
          context: ErrorDescription('while enabling or finding online lyrics'),
        ),
      );
      if (mounted) _showMessage('Could not search online for lyrics: $error');
    } finally {
      if (mounted) setState(() => _isLoadingLyrics = false);
    }
  }

  Future<void> _toggleFavorite(String trackId) async {
    final library = widget.musicLibrary;
    if (library == null) {
      _showMessage('Favorites are unavailable in this preview.');
      return;
    }
    try {
      final isFavorite = await library.toggleFavorite(trackId);
      if (!mounted) return;
      _showMessage(
        isFavorite ? 'Added to favorites.' : 'Removed from favorites.',
      );
    } on Object catch (error) {
      if (!mounted) return;
      _showMessage('Could not update favorite: $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  void _openLyrics() {
    final lyrics = _lyrics;
    if (lyrics == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (context) => _FullLyricsSheet(
        title: widget.item.title,
        artist: displayArtistName(widget.item.artist),
        lyrics: lyrics,
        audioHandler: widget.audioHandler,
      ),
    );
  }

  void _openQueue() {
    final queue = widget.audioHandler.queue.value;
    if (queue.isEmpty) return;
    final currentIndex = widget.audioHandler.playbackState.value.queueIndex;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.48),
      builder: (context) => _QueueSheet(
        items: queue,
        currentIndex: currentIndex,
        onSelect: (index) {
          Navigator.of(context).pop();
          _run(context, () => widget.audioHandler.skipToQueueItem(index));
        },
      ),
    );
  }

  Future<void> _handleMenu(String action) async {
    if (action == 'lyrics') {
      await _findLyrics();
    } else if (action == 'online-lyrics') {
      await _findLyricsOnline();
    } else if (action == 'read-lyrics') {
      _openLyrics();
    } else if (action == 'queue') {
      _openQueue();
    } else if (action == 'details') {
      _openTrackDetails();
    } else if (action == 'artist-radio') {
      await _playArtistRadio();
    }
  }

  void _syncMotion(bool playing, bool reduceMotion) {
    if (reduceMotion) {
      _wasPlaying = playing;
      _ambient
        ..stop()
        ..value = 0.5;
      _glow
        ..stop()
        ..value = 0;
      return;
    }
    if (playing == _wasPlaying) return;
    _wasPlaying = playing;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (playing) {
        unawaited(_ambient.repeat(reverse: true));
        unawaited(_glow.repeat(reverse: true));
      } else {
        _ambient
          ..stop()
          ..animateTo(0.5, duration: const Duration(milliseconds: 900));
        _glow
          ..stop()
          ..animateTo(0, duration: const Duration(milliseconds: 280));
      }
    });
  }

  void _cycleRepeat(AudioServiceRepeatMode current) {
    final next = switch (current) {
      AudioServiceRepeatMode.none => AudioServiceRepeatMode.all,
      AudioServiceRepeatMode.all ||
      AudioServiceRepeatMode.group => AudioServiceRepeatMode.one,
      AudioServiceRepeatMode.one => AudioServiceRepeatMode.none,
    };
    HapticFeedback.selectionClick();
    _run(context, () => widget.audioHandler.setRepeatMode(next));
  }

  void _toggleShuffle(AudioServiceShuffleMode current) {
    final next = current == AudioServiceShuffleMode.all
        ? AudioServiceShuffleMode.none
        : AudioServiceShuffleMode.all;
    HapticFeedback.selectionClick();
    _run(context, () => widget.audioHandler.setShuffleMode(next));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlaybackState>(
      stream: widget.audioHandler.playbackState,
      builder: (context, stateSnapshot) {
        final state = stateSnapshot.data;
        final playing = state?.playing == true;
        final duration = widget.item.duration ?? Duration.zero;
        final trackId =
            widget.item.extras?['libraryId'] as String? ?? widget.item.id;
        return SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 48,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Close player',
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    ),
                    const Expanded(
                      child: Text(
                        'Now Playing',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF171A20),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Up next',
                      onPressed: _openQueue,
                      icon: const Icon(Icons.queue_music_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final artSize = math
                        .min(constraints.maxWidth * 0.64, constraints.maxHeight)
                        .clamp(0.0, 360.0);
                    return Center(
                      child: GestureDetector(
                        onHorizontalDragStart: (_) => _beginDeckNudge(),
                        onHorizontalDragUpdate: _updateDeckNudge,
                        onHorizontalDragEnd: (_) => _endDeckNudge(),
                        onHorizontalDragCancel: _endDeckNudge,
                        child: Hero(
                          tag: 'tone-art-${widget.item.id}',
                          child: AlbumArtwork(
                            size: artSize,
                            title: widget.item.title,
                            iconSize: 64,
                            artworkUri: widget.item.artUri,
                            sourceUri: Uri.tryParse(widget.item.id),
                            borderRadius: 22,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 16, 0),
                child: Row(
                  children: [
                    AnimatedBuilder(
                      animation:
                          widget.musicLibrary ?? _NoopListenable.instance,
                      builder: (context, _) {
                        final favorite =
                            widget.musicLibrary?.isFavorite(trackId) ?? false;
                        return IconButton(
                          tooltip: favorite
                              ? 'Remove from favorites'
                              : 'Add to favorites',
                          onPressed: () => _toggleFavorite(trackId),
                          icon: Icon(
                            favorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: favorite
                                ? const Color(0xFFB5122D)
                                : const Color(0xFF97A0AA),
                          ),
                        );
                      },
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: _openTrackDetails,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            children: [
                              Text(
                                widget.item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF171A20),
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                displayArtistName(
                                  widget.item.artist,
                                  fallback:
                                      widget.item.album == null ||
                                          widget.item.album == 'Unknown album'
                                      ? 'From your library'
                                      : widget.item.album,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF7B8490),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'More options',
                      onSelected: (action) {
                        if (action == 'dj') {
                          _toggleDjMode();
                        } else {
                          _handleMenu(action);
                        }
                      },
                      itemBuilder: (context) => [
                        if (widget.audioHandler.queue.value.length > 1)
                          const PopupMenuItem(
                            value: 'queue',
                            child: Text('Up next'),
                          ),
                        const PopupMenuItem(
                          value: 'details',
                          child: Text('Track details'),
                        ),
                        if (_lyrics != null)
                          const PopupMenuItem(
                            value: 'read-lyrics',
                            child: Text('Read lyrics'),
                          ),
                        PopupMenuItem(
                          value: 'online-lyrics',
                          enabled: !_isLoadingLyrics,
                          child: const Text('Find lyrics online'),
                        ),
                        PopupMenuItem(
                          value: 'lyrics',
                          enabled: !_isLoadingLyrics,
                          child: Text(
                            _lyrics == null
                                ? 'Choose lyrics file'
                                : 'Replace lyrics',
                          ),
                        ),
                        if (widget.musicLibrary != null)
                          const PopupMenuItem(
                            value: 'artist-radio',
                            child: Text('Start artist radio'),
                          ),
                        PopupMenuItem(
                          value: 'dj',
                          child: Text(
                            _djMixMode == DjMixMode.off
                                ? 'Turn DJ mode on'
                                : 'Turn DJ mode off',
                          ),
                        ),
                      ],
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.more_horiz_rounded,
                          color: Color(0xFF97A0AA),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 6),
                child: StreamBuilder<Duration>(
                  stream: _positionStream(widget.audioHandler),
                  builder: (context, positionSnapshot) {
                    final position =
                        _dragPosition ??
                        (positionSnapshot.data ?? Duration.zero).inMilliseconds
                            .toDouble();
                    final max = duration.inMilliseconds.toDouble().clamp(
                      1.0,
                      double.infinity,
                    );
                    return FutureBuilder<AudioWaveformData>(
                      future: _audioWaveformFor(widget.item),
                      builder: (context, waveformSnapshot) => _ReferenceSeekBar(
                        value: position.clamp(0, max),
                        max: max,
                        duration: duration,
                        waveform: waveformSnapshot.data?.amplitudes,
                        waveformError: waveformSnapshot.error,
                        onRetry: _retryWaveform,
                        onChanged: (value) =>
                            setState(() => _dragPosition = value),
                        onChangeEnd: (value) {
                          setState(() => _dragPosition = null);
                          _run(
                            context,
                            () => widget.audioHandler.seek(
                              Duration(milliseconds: value.round()),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
              _ReferencePlaybackControls(
                playing: playing,
                shuffleMode: state?.shuffleMode ?? AudioServiceShuffleMode.none,
                repeatMode: state?.repeatMode ?? AudioServiceRepeatMode.none,
                onShuffle: () => _toggleShuffle(
                  state?.shuffleMode ?? AudioServiceShuffleMode.none,
                ),
                onPrevious: () =>
                    _run(context, widget.audioHandler.skipToPrevious),
                onToggle: () => _run(
                  context,
                  playing
                      ? widget.audioHandler.pause
                      : widget.audioHandler.play,
                ),
                onNext: () => _run(context, widget.audioHandler.skipToNext),
                onRepeat: () => _cycleRepeat(
                  state?.repeatMode ?? AudioServiceRepeatMode.none,
                ),
              ),
              if (widget.onNavigate case final onNavigate?)
                _PlayerBottomNavigation(onNavigate: onNavigate),
            ],
          ),
        );
      },
    );
  }

  Widget buildLegacy(BuildContext context) {
    return StreamBuilder<PlaybackState>(
      stream: widget.audioHandler.playbackState,
      builder: (context, stateSnapshot) {
        final state = stateSnapshot.data;
        final playing = state?.playing == true;
        _syncMotion(playing, MediaQuery.of(context).disableAnimations);
        final duration = widget.item.duration ?? Duration.zero;
        return Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _ambient,
                builder: (context, child) {
                  final t = _ambient.value;
                  return Transform.scale(
                    scale: 1.22 + t * 0.1,
                    child: Transform.translate(
                      offset: Offset((t - 0.5) * 24, (0.5 - t) * 16),
                      child: child,
                    ),
                  );
                },
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 64, sigmaY: 64),
                  child: AlbumArtwork(
                    size: MediaQuery.sizeOf(context).longestSide,
                    title: widget.item.title,
                    artworkUri: widget.item.artUri,
                    sourceUri: Uri.tryParse(widget.item.id),
                    borderRadius: 0,
                  ),
                ),
              ),
            ),
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x26000000),
                      Color(0x40000000),
                      Color(0xD4000000),
                    ],
                    stops: [0, 0.38, 1],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _ambient,
                  builder: (context, _) => DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(
                          -0.72 + _ambient.value * 0.22,
                          -0.55 + _ambient.value * 0.18,
                        ),
                        radius: 1.05,
                        colors: [
                          const Color(0xFFFF263E).withValues(alpha: 0.34),
                          const Color(0xFF8F101F).withValues(alpha: 0.18),
                          Colors.transparent,
                        ],
                        stops: const [0, 0.52, 1],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
                    child: _NowPlayingHeader(
                      isPlaying: playing,
                      lyrics: _lyrics,
                      isLoadingLyrics: _isLoadingLyrics,
                      hasQueue: widget.audioHandler.queue.value.length > 1,
                      hasArtist:
                          widget.musicLibrary != null &&
                          widget.item.artist != null &&
                          widget.item.artist!.trim().isNotEmpty &&
                          widget.item.artist!.toLowerCase() != 'unknown artist',
                      onMenuSelected: _handleMenu,
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, playerBox) {
                        final compact =
                            playerBox.maxHeight < 680 ||
                            playerBox.maxWidth < 360;
                        return Column(
                          children: [
                            Expanded(
                              flex: compact ? 5 : 6,
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  compact ? 18 : 26,
                                  compact ? 2 : 8,
                                  compact ? 18 : 26,
                                  8,
                                ),
                                child: LayoutBuilder(
                                  builder: (context, artBox) {
                                    final artSize = math.min(
                                      artBox.maxWidth,
                                      artBox.maxHeight,
                                    );
                                    return Center(
                                      child: AnimatedScale(
                                        scale: playing ? 1 : 0.96,
                                        duration: const Duration(
                                          milliseconds: 720,
                                        ),
                                        curve: Curves.easeInOutCubic,
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 720,
                                          ),
                                          curve: Curves.easeInOutCubic,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              28,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: playing ? 0.5 : 0.3,
                                                ),
                                                blurRadius: playing ? 46 : 24,
                                                offset: Offset(
                                                  0,
                                                  playing ? 20 : 10,
                                                ),
                                              ),
                                            ],
                                          ),
                                          child: AnimatedBuilder(
                                            animation: _glow,
                                            builder: (context, child) =>
                                                Transform.scale(
                                                  scale:
                                                      1 +
                                                      (playing
                                                          ? _glow.value * 0.012
                                                          : 0),
                                                  child: child,
                                                ),
                                            child: GestureDetector(
                                              onHorizontalDragStart: (_) =>
                                                  _beginDeckNudge(),
                                              onHorizontalDragUpdate:
                                                  _updateDeckNudge,
                                              onHorizontalDragEnd: (_) =>
                                                  _endDeckNudge(),
                                              onHorizontalDragCancel:
                                                  _endDeckNudge,
                                              child: Stack(
                                                fit: StackFit.expand,
                                                children: [
                                                  IgnorePointer(
                                                    child: CustomPaint(
                                                      painter:
                                                          _ArtworkOrbitPainter(
                                                            phase: _glow.value,
                                                            isPlaying: playing,
                                                          ),
                                                    ),
                                                  ),
                                                  Center(
                                                    child: Hero(
                                                      tag:
                                                          'tone-art-${widget.item.id}',
                                                      child: AlbumArtwork(
                                                        size: artSize * 0.76,
                                                        title:
                                                            widget.item.title,
                                                        iconSize: 72,
                                                        artworkUri:
                                                            widget.item.artUri,
                                                        sourceUri: Uri.tryParse(
                                                          widget.item.id,
                                                        ),
                                                        borderRadius: 26,
                                                      ),
                                                    ),
                                                  ),
                                                  if (_isScratching)
                                                    IgnorePointer(
                                                      child: Center(
                                                        child: _FrostedGlass(
                                                          borderRadius: 99,
                                                          tint: Colors.black
                                                              .withValues(
                                                                alpha: 0.4,
                                                              ),
                                                          child: const Padding(
                                                            padding:
                                                                EdgeInsets.symmetric(
                                                                  horizontal:
                                                                      18,
                                                                  vertical: 10,
                                                                ),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .graphic_eq_rounded,
                                                                  color: Colors
                                                                      .white,
                                                                  size: 18,
                                                                ),
                                                                SizedBox(
                                                                  width: 8,
                                                                ),
                                                                Text(
                                                                  'DECK NUDGE',
                                                                  style: TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700,
                                                                    letterSpacing:
                                                                        1.2,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
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
                            ),
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                compact ? 16 : 22,
                                compact ? 0 : 6,
                                compact ? 16 : 22,
                                compact ? 6 : 12,
                              ),
                              child: _NowPlayingDetails(
                                item: widget.item,
                                audioHandler: widget.audioHandler,
                                musicLibrary: widget.musicLibrary,
                                djMixMode: _djMixMode,
                                lyrics: _lyrics,
                                lyricsMessage: _lyricsMessage,
                                isLoadingLyrics: _isLoadingLyrics,
                                duration: duration,
                                playing: playing,
                                state: state,
                                glow: _glow,
                                dragPosition: _dragPosition,
                                onDragPositionChanged: (value) =>
                                    setState(() => _dragPosition = value),
                                onToggleFavorite: _toggleFavorite,
                                onFindLyrics: _findLyricsOnline,
                                onOpenLyrics: _openLyrics,
                                onCycleRepeat: _cycleRepeat,
                                onToggleShuffle: _toggleShuffle,
                                onToggleDjMode: _toggleDjMode,
                                onOpenTrackDetails: _openTrackDetails,
                                onRetryWaveform: _retryWaveform,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ReferenceSeekBar extends StatelessWidget {
  const _ReferenceSeekBar({
    required this.value,
    required this.max,
    required this.duration,
    required this.waveform,
    required this.waveformError,
    required this.onRetry,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final double value;
  final double max;
  final Duration duration;
  final List<double>? waveform;
  final Object? waveformError;
  final VoidCallback onRetry;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final hasWaveform = waveform != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: hasWaveform ? 34 : 3,
            trackShape: hasWaveform
                ? AudioWaveformTrack(
                    amplitudes: waveform!,
                    durationMs: duration.inMilliseconds,
                    activeColor: const Color(0xFF171A20),
                    inactiveColor: const Color(0xFFCBD0D5),
                  )
                : const RoundedRectSliderTrackShape(),
            activeTrackColor: const Color(0xFF171A20),
            inactiveTrackColor: const Color(0xFFCBD0D5),
            thumbColor: const Color(0xFF171A20),
            overlayColor: const Color(0xFF171A20).withValues(alpha: 0.12),
            thumbShape: RoundSliderThumbShape(
              enabledThumbRadius: hasWaveform ? 3 : 5,
            ),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
          ),
          child: Semantics(
            label: hasWaveform
                ? 'Audio waveform playback position'
                : 'Playback position',
            value:
                '${_formatTime(value.round())} of ${duration > Duration.zero ? _formatTime(duration.inMilliseconds) : '--:--'}',
            child: Slider(
              value: value.clamp(0, max),
              max: max,
              onChanged: duration > Duration.zero ? onChanged : null,
              onChangeEnd: duration > Duration.zero ? onChangeEnd : null,
            ),
          ),
        ),
        if (waveformError != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: waveformError is UnsupportedError ? null : onRetry,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF69727D),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: const Size(44, 30),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 15),
              label: Text(
                waveformError is UnsupportedError
                    ? 'Waveform unavailable'
                    : 'Retry waveform',
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatTime(value.round()),
              style: const TextStyle(
                color: Color(0xFF171A20),
                fontSize: 11,
                fontWeight: FontWeight.w500,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              duration > Duration.zero
                  ? _formatTime(duration.inMilliseconds)
                  : '--:--',
              style: const TextStyle(
                color: Color(0xFF97A0AA),
                fontSize: 11,
                fontWeight: FontWeight.w500,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReferencePlaybackControls extends StatelessWidget {
  const _ReferencePlaybackControls({
    required this.playing,
    required this.shuffleMode,
    required this.repeatMode,
    required this.onShuffle,
    required this.onPrevious,
    required this.onToggle,
    required this.onNext,
    required this.onRepeat,
  });

  final bool playing;
  final AudioServiceShuffleMode shuffleMode;
  final AudioServiceRepeatMode repeatMode;
  final VoidCallback onShuffle;
  final VoidCallback onPrevious;
  final VoidCallback onToggle;
  final VoidCallback onNext;
  final VoidCallback onRepeat;

  @override
  Widget build(BuildContext context) {
    final shuffleOn = shuffleMode == AudioServiceShuffleMode.all;
    final repeatOn = repeatMode != AudioServiceRepeatMode.none;
    final controlColor = const Color(0xFF171A20);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: shuffleOn ? 'Turn shuffle off' : 'Turn shuffle on',
            onPressed: onShuffle,
            icon: const Icon(Icons.shuffle_rounded),
            color: shuffleOn
                ? const Color(0xFFB5122D)
                : const Color(0xFF97A0AA),
          ),
          IconButton(
            tooltip: 'Previous track',
            onPressed: onPrevious,
            icon: const Icon(Icons.skip_previous_rounded),
            color: controlColor,
            iconSize: 30,
          ),
          SizedBox(
            width: 58,
            height: 58,
            child: IconButton(
              tooltip: playing ? 'Pause' : 'Play',
              onPressed: onToggle,
              style: IconButton.styleFrom(
                backgroundColor: controlColor,
                foregroundColor: Colors.white,
                shape: const CircleBorder(),
              ),
              iconSize: 32,
              icon: Icon(
                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Next track',
            onPressed: onNext,
            icon: const Icon(Icons.skip_next_rounded),
            color: controlColor,
            iconSize: 30,
          ),
          IconButton(
            tooltip: repeatOn
                ? repeatMode == AudioServiceRepeatMode.one
                      ? 'Repeat one'
                      : 'Change repeat mode'
                : 'Repeat all',
            onPressed: onRepeat,
            icon: Icon(
              repeatMode == AudioServiceRepeatMode.one
                  ? Icons.repeat_one_rounded
                  : Icons.repeat_rounded,
            ),
            color: repeatOn ? const Color(0xFFB5122D) : const Color(0xFF97A0AA),
          ),
        ],
      ),
    );
  }
}

class _PlayerBottomNavigation extends StatelessWidget {
  const _PlayerBottomNavigation({required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) => NavigationBar(
    height: 66,
    backgroundColor: Colors.black,
    indicatorColor: const Color(0xFFE9EAEC),
    selectedIndex: 0,
    onDestinationSelected: onNavigate,
    destinations: const [
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_rounded),
        label: 'Home',
      ),
      NavigationDestination(icon: Icon(Icons.search_rounded), label: 'Search'),
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
  );
}

class _NowPlayingDetails extends StatelessWidget {
  const _NowPlayingDetails({
    required this.item,
    required this.audioHandler,
    required this.musicLibrary,
    required this.djMixMode,
    required this.lyrics,
    required this.lyricsMessage,
    required this.isLoadingLyrics,
    required this.duration,
    required this.playing,
    required this.state,
    required this.glow,
    required this.dragPosition,
    required this.onDragPositionChanged,
    required this.onToggleFavorite,
    required this.onFindLyrics,
    required this.onOpenLyrics,
    required this.onCycleRepeat,
    required this.onToggleShuffle,
    required this.onToggleDjMode,
    required this.onOpenTrackDetails,
    required this.onRetryWaveform,
  });

  final MediaItem item;
  final AudioHandler audioHandler;
  final MusicLibrary? musicLibrary;
  final DjMixMode djMixMode;
  final SongLyrics? lyrics;
  final String? lyricsMessage;
  final bool isLoadingLyrics;
  final Duration duration;
  final bool playing;
  final PlaybackState? state;
  final Animation<double> glow;
  final double? dragPosition;
  final ValueChanged<double?> onDragPositionChanged;
  final ValueChanged<String> onToggleFavorite;
  final VoidCallback onFindLyrics;
  final VoidCallback onOpenLyrics;
  final ValueChanged<AudioServiceRepeatMode> onCycleRepeat;
  final ValueChanged<AudioServiceShuffleMode> onToggleShuffle;
  final VoidCallback onToggleDjMode;
  final VoidCallback onOpenTrackDetails;
  final VoidCallback onRetryWaveform;

  @override
  Widget build(BuildContext context) {
    final trackId = item.extras?['libraryId'] as String? ?? item.id;
    final genre = item.extras?['genre'] as String?;
    final bpm = (item.extras?['bpm'] as num?)?.toDouble();
    final album = item.album?.trim();
    final audioSignature = [
      if (genre != null && genre.trim().isNotEmpty) genre.trim(),
      if (bpm != null && bpm > 0) '${bpm.round()} BPM',
    ].join(' · ');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: InkWell(
                onTap: onOpenTrackDetails,
                borderRadius: BorderRadius.circular(12),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  child: Column(
                    key: ValueKey(item.id),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
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
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (album != null &&
                          album.isNotEmpty &&
                          album != 'Unknown album') ...[
                        const SizedBox(height: 2),
                        Text(
                          album,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.62),
                              ),
                        ),
                      ],
                      if (audioSignature.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          audioSignature,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.58),
                                letterSpacing: 0.25,
                              ),
                        ),
                      ],
                      _AudioQualityDetails(item: item),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _GlassIconButton(
                  icon: Icons.graphic_eq_rounded,
                  tooltip: djMixMode == DjMixMode.off
                      ? 'Turn DJ mode on'
                      : 'Turn DJ mode off',
                  color: djMixMode == DjMixMode.off
                      ? Colors.white
                      : const Color(0xFFFF756C),
                  onPressed: onToggleDjMode,
                ),
                const SizedBox(height: 4),
                AnimatedBuilder(
                  animation: musicLibrary ?? _NoopListenable.instance,
                  builder: (context, _) {
                    final isFavorite =
                        musicLibrary?.isFavorite(trackId) ?? false;
                    return _GlassIconButton(
                      icon: isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      tooltip: isFavorite
                          ? 'Remove from favorites'
                          : 'Add to favorites',
                      color: isFavorite
                          ? const Color(0xFFFF6B6B)
                          : Colors.white,
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        onToggleFavorite(trackId);
                      },
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 5),
        _NowPlayingLyricLine(
          audioHandler: audioHandler,
          lyrics: lyrics,
          message: lyricsMessage,
          isLoading: isLoadingLyrics,
          onTap: lyrics == null ? onFindLyrics : onOpenLyrics,
        ),
        const SizedBox(height: 6),
        _FrostedGlass(
          borderRadius: 28,
          blur: 30,
          tint: const Color(0x3DFFFFFF),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StreamBuilder<Duration>(
                  stream: _positionStream(audioHandler),
                  builder: (context, positionSnapshot) {
                    final position =
                        dragPosition ??
                        (positionSnapshot.data ?? Duration.zero).inMilliseconds
                            .toDouble();
                    final max = duration.inMilliseconds.toDouble().clamp(
                      1.0,
                      double.infinity,
                    );
                    final hasDuration = duration > Duration.zero;
                    return FutureBuilder<AudioWaveformData>(
                      future: _audioWaveformFor(item),
                      builder: (context, waveformSnapshot) => AnimatedBuilder(
                        animation: glow,
                        builder: (context, _) => _ImmersiveSeekBar(
                          value: position.clamp(0, max),
                          max: max,
                          durationMs: duration.inMilliseconds,
                          bpm: bpm,
                          waveform: waveformSnapshot.data?.amplitudes,
                          waveformLoading:
                              waveformSnapshot.connectionState !=
                              ConnectionState.done,
                          waveformError: waveformSnapshot.error,
                          onRetryWaveform: onRetryWaveform,
                          glow: glow.value,
                          enabled: hasDuration,
                          elapsedLabel: _formatTime(position.round()),
                          durationLabel: hasDuration
                              ? _formatTime(duration.inMilliseconds)
                              : '--:--',
                          onChanged: (value) => onDragPositionChanged(value),
                          onChangeEnd: (value) {
                            onDragPositionChanged(null);
                            _run(
                              context,
                              () => audioHandler.seek(
                                Duration(milliseconds: value.round()),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 6),
                _GlassPlaybackControls(
                  isPlaying: playing,
                  shuffleMode:
                      state?.shuffleMode ?? AudioServiceShuffleMode.none,
                  repeatMode: state?.repeatMode ?? AudioServiceRepeatMode.none,
                  onShuffle: () => onToggleShuffle(
                    state?.shuffleMode ?? AudioServiceShuffleMode.none,
                  ),
                  onPrevious: () {
                    HapticFeedback.lightImpact();
                    _run(context, audioHandler.skipToPrevious);
                  },
                  onToggle: () {
                    HapticFeedback.mediumImpact();
                    _run(
                      context,
                      playing ? audioHandler.pause : audioHandler.play,
                    );
                  },
                  onNext: () {
                    HapticFeedback.lightImpact();
                    _run(context, audioHandler.skipToNext);
                  },
                  onRepeat: () => onCycleRepeat(
                    state?.repeatMode ?? AudioServiceRepeatMode.none,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ArtworkOrbitPainter extends CustomPainter {
  const _ArtworkOrbitPainter({required this.phase, required this.isPlaying});

  final double phase;
  final bool isPlaying;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.455;
    final angle = phase * math.pi * 2;
    final path = Path();
    const samples = 144;
    for (var index = 0; index <= samples; index++) {
      final theta = index / samples * math.pi * 2;
      final ripple =
          math.sin(theta * 4 + angle) * 0.026 +
          math.sin(theta * 7 - angle * 0.6) * 0.012;
      final breathe = isPlaying ? phase * 0.01 : 0;
      final pointRadius = radius * (1 + ripple + breathe);
      final point = Offset(
        center.dx + math.cos(theta) * pointRadius,
        center.dy + math.sin(theta) * pointRadius,
      );
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: isPlaying ? 0.43 : 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.15,
    );
    final markerAngle = angle - math.pi / 2;
    final markerRadius =
        radius * (1 + math.sin(markerAngle * 4 + angle) * 0.026);
    canvas.drawCircle(
      Offset(
        center.dx + math.cos(markerAngle) * markerRadius,
        center.dy + math.sin(markerAngle) * markerRadius,
      ),
      isPlaying ? 4 : 3,
      Paint()..color = const Color(0xFFFF5B6E),
    );
  }

  @override
  bool shouldRepaint(covariant _ArtworkOrbitPainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.isPlaying != isPlaying;
}

class _AudioQualityDetails extends StatelessWidget {
  const _AudioQualityDetails({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, Object?>?>(
    future: _audioQualityFor(item),
    builder: (context, snapshot) {
      final details = snapshot.data;
      if (snapshot.hasError) {
        return Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            'Audio details unavailable',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: Colors.white.withValues(alpha: 0.5)),
          ),
        );
      }
      if (details == null) return const SizedBox.shrink();
      final mimeType = details['mimeType'] as String?;
      if (mimeType == null || mimeType.isEmpty) return const SizedBox.shrink();
      final quality = _audioQualityLabel(details);
      return Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(
          children: [
            Icon(
              Icons.graphic_eq_rounded,
              size: 12,
              color: Colors.white.withValues(alpha: 0.56),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                quality,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.56),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _TrackDetailsSheet extends StatelessWidget {
  const _TrackDetailsSheet({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final extras = item.extras ?? const <String, dynamic>{};
    final genre = extras['genre'] as String?;
    final bpm = (extras['bpm'] as num?)?.toDouble();
    final year = extras['year'];
    final trackNumber = extras['trackNumber'];
    final downloadProvider = extras['downloadProvider'] as String?;
    final source = downloadProvider != null
        ? 'Downloaded from $downloadProvider'
        : extras['source'] == 'device'
        ? 'On-device library'
        : 'Imported audio';
    final licenseUrl = extras['licenseUrl'] as String?;
    final theme = Theme.of(context);
    final details = <(String, String)>[
      ('Artist', displayArtistName(item.artist)),
      if (item.album?.trim().isNotEmpty == true &&
          item.album!.trim().toLowerCase() != 'unknown album')
        ('Album', item.album!.trim()),
      ('Release year', year == null ? 'Not tagged' : '$year'),
      ('Track', trackNumber == null ? 'Not tagged' : '$trackNumber'),
      (
        'Genre',
        genre?.trim().isNotEmpty == true ? genre!.trim() : 'Not tagged',
      ),
      if (bpm != null && bpm > 0) ('Tempo', '${bpm.round()} BPM'),
      (
        'Duration',
        item.duration == null
            ? 'Unknown'
            : _formatTime(item.duration!.inMilliseconds),
      ),
      ('Source', source),
      if (licenseUrl != null) ('License', licenseUrl),
    ];
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.82,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: _FrostedGlass(
          borderRadius: 28,
          blur: 32,
          tint: const Color(0xE817171B),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.32),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
                child: Row(
                  children: [
                    AlbumArtwork(
                      size: 64,
                      title: item.title,
                      artworkUri: item.artUri,
                      sourceUri: Uri.tryParse(item.id),
                      borderRadius: 14,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Track details',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: const Color(0xFFFF827A),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _GlassIconButton(
                      icon: Icons.close_rounded,
                      tooltip: 'Close track details',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  children: [
                    for (final (label, value) in details)
                      _TrackDetailRow(label: label, value: value),
                    const SizedBox(height: 10),
                    Text(
                      'Audio quality',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<Map<String, Object?>?>(
                      future: _audioQualityFor(item),
                      builder: (context, snapshot) {
                        final quality = snapshot.data;
                        if (snapshot.hasError) {
                          return const _TrackDetailRow(
                            label: 'Source format',
                            value: 'Could not read audio stream details',
                          );
                        }
                        if (quality == null) {
                          return const _TrackDetailRow(
                            label: 'Source format',
                            value: 'Not available for this source',
                          );
                        }
                        return _TrackDetailRow(
                          label: 'Source format',
                          value: _audioQualityLabel(quality),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Details come from the file or device media index. '
                      'Missing tags are shown as not tagged.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.48),
                        height: 1.4,
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
  }
}

class _TrackDetailRow extends StatelessWidget {
  const _TrackDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.52)),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _NowPlayingHeader extends StatelessWidget {
  const _NowPlayingHeader({
    required this.isPlaying,
    required this.lyrics,
    required this.isLoadingLyrics,
    required this.hasQueue,
    required this.hasArtist,
    required this.onMenuSelected,
  });

  final bool isPlaying;
  final SongLyrics? lyrics;
  final bool isLoadingLyrics;
  final bool hasQueue;
  final bool hasArtist;
  final ValueChanged<String> onMenuSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              width: 38,
              height: 5,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.38),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Row(
              children: [
                _GlassIconButton(
                  icon: Icons.keyboard_arrow_down_rounded,
                  tooltip: 'Close player',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const Spacer(),
                AnimatedOpacity(
                  opacity: isPlaying ? 1 : 0.55,
                  duration: const Duration(milliseconds: 280),
                  child: Text(
                    isPlaying ? 'Now Playing' : 'Paused',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  tooltip: 'More options',
                  onSelected: onMenuSelected,
                  color: const Color(0xE618181C),
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  itemBuilder: (context) => [
                    if (hasQueue)
                      const PopupMenuItem(
                        value: 'queue',
                        child: Text('Up next'),
                      ),
                    const PopupMenuItem(
                      value: 'details',
                      child: Text('Track details'),
                    ),
                    if (hasArtist)
                      const PopupMenuItem(
                        value: 'artist-radio',
                        child: Text('Start artist radio'),
                      ),
                    if (lyrics != null)
                      const PopupMenuItem(
                        value: 'read-lyrics',
                        child: Text('Read lyrics'),
                      ),
                    PopupMenuItem(
                      value: 'lyrics',
                      enabled: !isLoadingLyrics,
                      child: Text(
                        lyrics == null
                            ? 'Choose lyrics file'
                            : 'Replace lyrics',
                      ),
                    ),
                  ],
                  child: const _GlassGlyph(icon: Icons.more_horiz_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AlbumArtwork extends StatelessWidget {
  const AlbumArtwork({
    required this.size,
    required this.title,
    this.iconSize = 25,
    this.artworkUri,
    this.sourceUri,
    this.borderRadius,
    super.key,
  });

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
    final artwork = artworkUri != null || sourceUri != null
        ? _loadArtwork(artworkUri, sourceUri)
        : null;
    return Semantics(
      label: 'Artwork for $title',
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius ?? size * 0.09),
          gradient: LinearGradient(
            colors: [glow, base, colors.primary.withValues(alpha: 0.9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: base.withValues(alpha: 0.2),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: artwork == null
            ? _fallbackIcon()
            : FutureBuilder<Uint8List?>(
                future: artwork,
                builder: (context, snapshot) {
                  final bytes = snapshot.data;
                  if (bytes == null || bytes.isEmpty) return _fallbackIcon();
                  final decodeSize =
                      (size * MediaQuery.devicePixelRatioOf(context))
                          .ceil()
                          .clamp(64, 1024);
                  return Image.memory(
                    bytes,
                    fit: BoxFit.cover,
                    cacheWidth: decodeSize,
                    cacheHeight: decodeSize,
                    errorBuilder: (_, _, _) => _fallbackIcon(),
                  );
                },
              ),
      ),
    );
  }

  Widget _fallbackIcon() =>
      Icon(Icons.graphic_eq_rounded, color: Colors.white, size: iconSize);
}

Future<Uint8List?> _loadArtwork(Uri? artworkUri, Uri? sourceUri) {
  final cacheKey = artworkUri ?? sourceUri!;
  return _artworkCache.putIfAbsent(cacheKey, () async {
    try {
      final bytes = await _artworkChannel.invokeMethod<Uint8List>(
        'getArtwork',
        {'uri': artworkUri?.toString(), 'sourceUri': sourceUri?.toString()},
      );
      if (bytes == null || bytes.isEmpty) {
        _artworkCache.remove(cacheKey);
        return null;
      }
      if (_artworkCache.length > 64) {
        _artworkCache.remove(_artworkCache.keys.first);
      }
      return bytes;
    } on PlatformException {
      _artworkCache.remove(cacheKey);
      return null;
    }
  });
}

class _FrostedGlass extends StatelessWidget {
  const _FrostedGlass({
    required this.child,
    this.borderRadius = 22,
    this.blur = 28,
    this.tint,
  });

  final Widget child;
  final double borderRadius;
  final double blur;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tint ?? Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlassGlyph extends StatelessWidget {
  const _GlassGlyph({required this.icon, this.color});

  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return _FrostedGlass(
      borderRadius: 99,
      blur: 22,
      tint: Colors.white.withValues(alpha: 0.14),
      child: SizedBox(
        width: 42,
        height: 42,
        child: Icon(icon, size: 22, color: color ?? Colors.white),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: const Size(42, 42),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: _GlassGlyph(icon: icon, color: color),
    );
  }
}

class _GlassPlaybackControls extends StatelessWidget {
  const _GlassPlaybackControls({
    required this.isPlaying,
    required this.shuffleMode,
    required this.repeatMode,
    required this.onShuffle,
    required this.onPrevious,
    required this.onToggle,
    required this.onNext,
    required this.onRepeat,
  });

  final bool isPlaying;
  final AudioServiceShuffleMode shuffleMode;
  final AudioServiceRepeatMode repeatMode;
  final VoidCallback onShuffle;
  final VoidCallback onPrevious;
  final VoidCallback onToggle;
  final VoidCallback onNext;
  final VoidCallback onRepeat;

  @override
  Widget build(BuildContext context) {
    final shuffleOn = shuffleMode == AudioServiceShuffleMode.all;
    final repeatOn = repeatMode != AudioServiceRepeatMode.none;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _TransportIcon(
              icon: Icons.shuffle_rounded,
              tooltip: shuffleOn ? 'Turn shuffle off' : 'Turn shuffle on',
              active: shuffleOn,
              onPressed: onShuffle,
            ),
            _TransportIcon(
              icon: repeatMode == AudioServiceRepeatMode.one
                  ? Icons.repeat_one_rounded
                  : Icons.repeat_rounded,
              tooltip: repeatOn ? 'Change repeat mode' : 'Repeat all',
              active: repeatOn,
              onPressed: onRepeat,
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _GlassIconButton(
              icon: Icons.skip_previous_rounded,
              tooltip: 'Previous track',
              onPressed: onPrevious,
            ),
            Tooltip(
              message: isPlaying ? 'Pause' : 'Play',
              child: Semantics(
                button: true,
                label: isPlaying ? 'Pause playback' : 'Resume playback',
                child: GestureDetector(
                  onTap: onToggle,
                  child: AnimatedScale(
                    scale: isPlaying ? 1 : 0.94,
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutBack,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      width: 66,
                      height: 66,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFFF514B).withValues(alpha: 0.8),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF4038)
                                .withValues(alpha: isPlaying ? 0.42 : 0.16),
                            blurRadius: isPlaying ? 28 : 12,
                            spreadRadius: isPlaying ? 2 : 0,
                          ),
                        ],
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Icon(
                          isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          key: ValueKey(isPlaying),
                          size: 38,
                          color: const Color(0xFF201014),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _GlassIconButton(
              icon: Icons.skip_next_rounded,
              tooltip: 'Next track',
              onPressed: onNext,
            ),
          ],
        ),
      ],
    );
  }
}

class _TransportIcon extends StatelessWidget {
  const _TransportIcon({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
      color: Colors.white.withValues(alpha: active ? 1 : 0.38),
    );
  }
}

class _NowPlayingLyricLine extends StatelessWidget {
  const _NowPlayingLyricLine({
    required this.audioHandler,
    required this.lyrics,
    required this.message,
    required this.isLoading,
    required this.onTap,
  });

  final AudioHandler audioHandler;
  final SongLyrics? lyrics;
  final String? message;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lyrics = this.lyrics;
    if (lyrics == null) {
      return isLoading
          ? Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Finding saved lyrics…',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: Colors.white.withValues(alpha: 0.58)),
              ),
            )
          : Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onTap,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white.withValues(alpha: 0.62),
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.lyrics_outlined, size: 16),
                label: Text(
                  message ?? 'Find lyrics online · Add a file',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
    }
    return StreamBuilder<Duration>(
      stream: _positionStream(audioHandler),
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final index = lyrics.activeLineAt(position);
        final lineIndex = index >= 0 && index < lyrics.lines.length ? index : 0;
        final line = lyrics.lines.isEmpty ? null : lyrics.lines[lineIndex];
        final activeWord = lyrics.activeWordAt(lineIndex, position);
        final lyricText = line == null
            ? const Text('Lyrics')
            : line.words.isEmpty
            ? Text(line.text)
            : Text.rich(
                TextSpan(
                  children: [
                    for (
                      var wordIndex = 0;
                      wordIndex < line.words.length;
                      wordIndex++
                    )
                      TextSpan(
                        text:
                            '${line.words[wordIndex].text}${wordIndex + 1 == line.words.length ? '' : ' '}',
                        style: TextStyle(
                          color: activeWord == wordIndex
                              ? const Color(0xFFFF827A)
                              : Colors.white.withValues(
                                  alpha: activeWord > wordIndex ? 0.96 : 0.65,
                                ),
                          fontWeight: activeWord == wordIndex
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              );
        return GestureDetector(
          onTap: onTap,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: DefaultTextStyle(
              key: ValueKey(lineIndex),
              style:
                  Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ) ??
                  const TextStyle(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              child: lyricText,
            ),
          ),
        );
      },
    );
  }
}

class _ImmersiveSeekBar extends StatelessWidget {
  const _ImmersiveSeekBar({
    required this.value,
    required this.max,
    required this.durationMs,
    required this.bpm,
    required this.waveform,
    required this.waveformLoading,
    required this.waveformError,
    required this.onRetryWaveform,
    required this.glow,
    required this.enabled,
    required this.elapsedLabel,
    required this.durationLabel,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final double value;
  final double max;
  final int durationMs;
  final double? bpm;
  final List<double>? waveform;
  final bool waveformLoading;
  final Object? waveformError;
  final VoidCallback onRetryWaveform;
  final double glow;
  final bool enabled;
  final String elapsedLabel;
  final String durationLabel;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final hasWaveform = waveform != null;
    final validBpm = bpm != null && bpm! >= 40 && bpm! <= 240;
    return Column(
      children: [
        if (hasWaveform)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'AUDIO WAVEFORM',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                if (validBpm)
                  Text(
                    '${bpm!.round()} BPM TAG · BAR GUIDE',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.35,
                    ),
                  ),
              ],
            ),
          ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: hasWaveform ? 34 : 4,
            trackShape: hasWaveform
                ? AudioWaveformTrack(
                    amplitudes: waveform!,
                    durationMs: durationMs,
                    activeColor: const Color(0xFFFF5B6E),
                    inactiveColor: Colors.white.withValues(alpha: 0.5),
                    bpm: bpm,
                  )
                : const RoundedRectSliderTrackShape(),
            activeTrackColor: Color.lerp(
              const Color(0xFFFF514B),
              Colors.white,
              glow * 0.18,
            ),
            inactiveTrackColor: Colors.white.withValues(alpha: 0.24),
            thumbColor: Colors.white,
            overlayColor: const Color(0xFFFF514B).withValues(alpha: 0.18),
            thumbShape: RoundSliderThumbShape(
              enabledThumbRadius: hasWaveform ? 4 : 6,
            ),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
          ),
          child: Semantics(
            label: hasWaveform
                ? validBpm
                      ? 'Audio waveform with approximate bar guides from the ${bpm!.round()} BPM tag'
                      : 'Audio waveform showing decoded audio amplitude'
                : 'Playback position',
            value: '$elapsedLabel of $durationLabel',
            child: Slider(
              value: enabled ? value.clamp(0.0, max) : 0,
              max: max,
              onChangeStart: enabled
                  ? (_) => HapticFeedback.selectionClick()
                  : null,
              onChanged: enabled ? onChanged : null,
              onChangeEnd: enabled ? onChangeEnd : null,
            ),
          ),
        ),
        if (waveformLoading || waveformError != null)
          SizedBox(
            height: 18,
            child: waveformLoading
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Reading audio peaks…',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.62),
                      ),
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Text(
                          waveformError is UnsupportedError
                              ? 'Waveform analysis is not available on this device.'
                              : 'Waveform unavailable. Your seek control still works.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.66),
                              ),
                        ),
                      ),
                      if (waveformError is! UnsupportedError)
                        TextButton(
                          onPressed: onRetryWaveform,
                          style: TextButton.styleFrom(
                            minimumSize: const Size(44, 32),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Retry'),
                        ),
                    ],
                  ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(elapsedLabel, style: _timeStyle),
            Text(durationLabel, style: _timeStyle),
          ],
        ),
      ],
    );
  }
}

const _timeStyle = TextStyle(
  color: Color(0x9EFFFFFF),
  fontSize: 12,
  fontWeight: FontWeight.w600,
  fontFeatures: [FontFeature.tabularFigures()],
);

class _QueueSheet extends StatelessWidget {
  const _QueueSheet({
    required this.items,
    required this.currentIndex,
    required this.onSelect,
  });

  final List<MediaItem> items;
  final int? currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final activeIndex = currentIndex ?? 0;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.72,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: _FrostedGlass(
          borderRadius: 28,
          blur: 34,
          tint: const Color(0xE8170B0F),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 38,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Up next',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${items.length} songs in this mix',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.62),
                                ),
                          ),
                        ],
                      ),
                    ),
                    _GlassIconButton(
                      icon: Icons.close_rounded,
                      tooltip: 'Close queue',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isCurrent = index == activeIndex;
                    return Material(
                      color: Colors.transparent,
                      child: ListTile(
                        onTap: () => onSelect(index),
                        leading: isCurrent
                            ? const Icon(
                                Icons.graphic_eq_rounded,
                                color: Color(0xFFFF655B),
                              )
                            : Text(
                                '${index + 1}'.padLeft(2, '0'),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.48),
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                        title: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: isCurrent
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          displayArtistName(
                            item.artist,
                            fallback:
                                item.album == null ||
                                    item.album == 'Unknown album'
                                ? 'On-device audio'
                                : item.album,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.62),
                          ),
                        ),
                        trailing: item.duration == null
                            ? null
                            : Text(
                                _formatTime(item.duration!.inMilliseconds),
                                style: _timeStyle,
                              ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FullLyricsSheet extends StatefulWidget {
  const _FullLyricsSheet({
    required this.title,
    required this.artist,
    required this.lyrics,
    required this.audioHandler,
  });

  final String title;
  final String artist;
  final SongLyrics lyrics;
  final AudioHandler audioHandler;

  @override
  State<_FullLyricsSheet> createState() => _FullLyricsSheetState();
}

class _FullLyricsSheetState extends State<_FullLyricsSheet> {
  late final ScrollController _scrollController;
  late final List<GlobalKey> _lineKeys;
  int? _lastScrolledIndex;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _lineKeys = List.generate(widget.lyrics.lines.length, (_) => GlobalKey());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToActiveLine(int index) {
    if (index < 0 || index == _lastScrolledIndex) return;
    _lastScrolledIndex = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final lineContext = _lineKeys[index].currentContext;
      if (lineContext == null) return;
      Scrollable.ensureVisible(
        lineContext,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
        alignment: 0.5,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.86,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: _FrostedGlass(
          borderRadius: 28,
          blur: 36,
          tint: Colors.black.withValues(alpha: 0.28),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.32),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              ListTile(
                title: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  widget.artist,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.62)),
                ),
                trailing: _GlassIconButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Close lyrics',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              Expanded(
                child: StreamBuilder<Duration>(
                  stream: _positionStream(widget.audioHandler),
                  builder: (context, snapshot) {
                    final activeIndex = widget.lyrics.isSynchronized
                        ? widget.lyrics.activeLineAt(
                            snapshot.data ?? Duration.zero,
                          )
                        : -1;
                    _scrollToActiveLine(activeIndex);
                    return ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                      children: List.generate(widget.lyrics.lines.length, (
                        index,
                      ) {
                        final isActive = index == activeIndex;
                        final line = widget.lyrics.lines[index];
                        final activeWord = isActive
                            ? widget.lyrics.activeWordAt(
                                index,
                                snapshot.data ?? Duration.zero,
                              )
                            : -1;
                        return Padding(
                          key: _lineKeys[index],
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 180),
                            style:
                                Theme.of(
                                  context,
                                ).textTheme.titleMedium?.copyWith(
                                  color: isActive
                                      ? const Color(0xFFFF756C)
                                      : Colors.white.withValues(alpha: 0.68),
                                  fontWeight: isActive
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ) ??
                                const TextStyle(),
                            child: line.words.isEmpty
                                ? Text(
                                    line.text,
                                    textAlign: TextAlign.center,
                                    key: isActive
                                        ? const ValueKey('active-lyrics-line')
                                        : null,
                                  )
                                : Text.rich(
                                    TextSpan(
                                      children: [
                                        for (
                                          var wordIndex = 0;
                                          wordIndex < line.words.length;
                                          wordIndex++
                                        )
                                          TextSpan(
                                            text:
                                                '${line.words[wordIndex].text}${wordIndex + 1 == line.words.length ? '' : ' '}',
                                            style: TextStyle(
                                              color:
                                                  isActive &&
                                                      activeWord == wordIndex
                                                  ? const Color(0xFFFF827A)
                                                  : null,
                                              fontWeight:
                                                  isActive &&
                                                      activeWord == wordIndex
                                                  ? FontWeight.w800
                                                  : null,
                                            ),
                                          ),
                                      ],
                                    ),
                                    textAlign: TextAlign.center,
                                    key: isActive
                                        ? const ValueKey('active-lyrics-line')
                                        : null,
                                  ),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoopListenable implements Listenable {
  const _NoopListenable._();

  static const instance = _NoopListenable._();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

String _formatTime(int milliseconds) {
  final totalSeconds = (milliseconds / 1000).floor();
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

Stream<Duration> _positionStream(AudioHandler audioHandler) =>
    Stream<Duration>.multi((controller) {
      var state = audioHandler.playbackState.value;
      var updatedAt = DateTime.now();
      controller.add(state.updatePosition);
      final subscription = audioHandler.playbackState.listen((nextState) {
        state = nextState;
        updatedAt = DateTime.now();
        controller.add(state.updatePosition);
      }, onError: controller.addError);
      final timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (!state.playing) return;
        final elapsed = DateTime.now().difference(updatedAt);
        final advance = Duration(
          milliseconds: (elapsed.inMilliseconds * state.speed).round(),
        );
        controller.add(state.updatePosition + advance);
      });
      controller.onCancel = () async {
        timer.cancel();
        await subscription.cancel();
      };
    });

void _run(BuildContext context, Future<void> Function() action) {
  action().catchError((Object error, StackTrace stackTrace) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Playback action failed: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  });
}
