import 'dart:async';
import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tone_player/features/player/dj_transition.dart';

class ToneAudioHandler extends BaseAudioHandler with SeekHandler {
  ToneAudioHandler() {
    _deckA = AudioPlayer(handleAudioSessionActivation: false);
    _deckB = AudioPlayer(handleAudioSessionActivation: false);
    _player = _deckA;
    _standby = _deckB;
    _listenToDeck(_deckA);
    _listenToDeck(_deckB);
    _settingsReady = _loadDjMixMode();
  }

  static const _djMixModeKey = 'tone_dj_mix_mode';
  static const _transitionSafetyMargin = Duration(milliseconds: 150);
  static const _transitionPollMargin = Duration(milliseconds: 250);
  static const _minimumTransitionTime = Duration(milliseconds: 400);

  late final AudioPlayer _deckA;
  late final AudioPlayer _deckB;
  late AudioPlayer _player;
  late AudioPlayer _standby;
  late final Future<void> _settingsReady;
  final List<StreamSubscription<dynamic>> _deckSubscriptions = [];

  List<MediaItem> _items = const [];
  List<int> _playOrder = const [];
  int _currentIndex = 0;
  int _orderPosition = 0;
  int? _preparedIndex;
  int _transitionGeneration = 0;
  bool _isTransitioning = false;
  bool _isAdvancing = false;
  bool _isScratching = false;
  AudioServiceRepeatMode _repeatMode = AudioServiceRepeatMode.none;
  AudioServiceShuffleMode _shuffleMode = AudioServiceShuffleMode.none;
  DjMixMode _djMixMode = DjMixMode.beatMatched;

  Future<void> _loadDjMixMode() async {
    final preferences = await SharedPreferences.getInstance();
    final savedMode = preferences.getString(_djMixModeKey);
    if (savedMode == null) return;
    _djMixMode = DjMixMode.values.firstWhere(
      (mode) => mode.name == savedMode,
      orElse: () =>
          throw FormatException('Unknown saved DJ mix mode: $savedMode'),
    );
  }

  @override
  Future<dynamic> customAction(
    String name, [
    Map<String, dynamic>? extras,
  ]) async {
    await _settingsReady;
    if (name == 'getDjMixMode') return _djMixMode.name;
    if (name == 'setDjMixMode') {
      final name = extras?['mode'];
      if (name is! String) {
        throw ArgumentError.value(name, 'mode', 'Expected a DJ mix mode name.');
      }
      final mode = DjMixMode.values.firstWhere(
        (candidate) => candidate.name == name,
        orElse: () =>
            throw ArgumentError.value(name, 'mode', 'Unknown DJ mix mode.'),
      );
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_djMixModeKey, mode.name);
      _djMixMode = mode;
      if (mode == DjMixMode.off) {
        await _cancelTransition();
        await _resetScratchSpeed();
      }
      return null;
    }
    if (name == 'scratchDeck') {
      final requestedSpeed = extras?['speed'];
      if (requestedSpeed is! num || !requestedSpeed.isFinite) {
        throw ArgumentError.value(
          requestedSpeed,
          'speed',
          'Expected a finite deck speed.',
        );
      }
      final speed = requestedSpeed.toDouble();
      if (speed < 0.65 || speed > 1.35) {
        throw ArgumentError.value(
          speed,
          'speed',
          'Expected a deck speed between 0.65 and 1.35.',
        );
      }
      if (speed != 1 && _djMixMode == DjMixMode.off) {
        throw StateError('Turn on DJ mode before scratching the deck.');
      }
      if (!_isScratching && speed != 1) {
        await _cancelTransition();
        _isScratching = true;
      }
      await _player.setPitch(1);
      await _player.setSpeed(speed);
      if (speed == 1) _isScratching = false;
      _publishState();
      return null;
    }
    return super.customAction(name, extras);
  }

  void _listenToDeck(AudioPlayer deck) {
    _deckSubscriptions
      ..add(
        deck.playbackEventStream.listen(
          (_) {
            if (identical(deck, _player)) _publishState();
          },
          onError: (Object error, StackTrace stackTrace) {
            if (identical(deck, _player)) {
              playbackState.add(
                playbackState.value.copyWith(
                  processingState: AudioProcessingState.error,
                  errorMessage: error.toString(),
                ),
              );
            }
            _reportPlaybackError(
              error,
              stackTrace,
              'while receiving audio playback events',
            );
          },
        ),
      )
      ..add(
        deck.positionStream.listen(
          (position) {
            if (identical(deck, _player)) _considerDjHandoff(position);
          },
          onError: (Object error, StackTrace stackTrace) =>
              _reportPlaybackError(
                error,
                stackTrace,
                'while monitoring DJ transition timing',
              ),
        ),
      )
      ..add(
        deck.durationStream.listen(
          (duration) {
            if (identical(deck, _player)) _publishDuration(duration);
          },
          onError: (Object error, StackTrace stackTrace) =>
              _reportPlaybackError(
                error,
                stackTrace,
                'while reading track duration',
              ),
        ),
      )
      ..add(
        deck.processingStateStream.listen(
          (state) {
            if (!identical(deck, _player)) return;
            _publishState();
            if (state == ProcessingState.completed &&
                !_isTransitioning &&
                !_isAdvancing) {
              unawaited(_advanceAtEnd());
            }
          },
          onError: (Object error, StackTrace stackTrace) =>
              _reportPlaybackError(
                error,
                stackTrace,
                'while monitoring audio processing state',
              ),
        ),
      );
  }

  @override
  Future<void> play() async {
    await _settingsReady;
    if (_items.isEmpty) return;
    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
    }
    final session = await AudioSession.instance;
    if (!await session.setActive(true)) {
      throw StateError('The audio session is unavailable for playback.');
    }
    _startDeck(_player);
    if (_isTransitioning) _startDeck(_standby);
  }

  void _startDeck(AudioPlayer deck) {
    unawaited(
      deck.play().catchError((Object error, StackTrace stackTrace) {
        if (identical(deck, _player)) {
          playbackState.add(
            playbackState.value.copyWith(
              processingState: AudioProcessingState.error,
              errorMessage: error.toString(),
            ),
          );
        }
        _reportPlaybackError(error, stackTrace, 'while starting audio');
      }),
    );
  }

  @override
  Future<void> pause() async {
    await _cancelTransition();
    await _resetScratchSpeed();
    await _player.pause();
    await _standby.pause();
    _publishState();
  }

  @override
  Future<void> stop() async {
    await pause();
    await _player.stop();
    await _standby.stop();
    await super.stop();
    _publishState();
  }

  @override
  Future<void> seek(Duration position) async {
    await _cancelTransition();
    await _resetScratchSpeed();
    await _player.seek(position);
    _publishState();
  }

  @override
  Future<void> skipToNext() async {
    final nextIndex = _nextQueueIndex();
    if (nextIndex == null) return;
    await _loadIndex(nextIndex, playWhenReady: _isPlaying);
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.position > const Duration(seconds: 3)) {
      await seek(Duration.zero);
      return;
    }
    if (_orderPosition > 0) {
      await _loadIndex(
        _playOrder[_orderPosition - 1],
        playWhenReady: _isPlaying,
      );
    } else {
      await seek(Duration.zero);
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _items.length) return;
    await _loadIndex(index, playWhenReady: _isPlaying);
  }

  @override
  Future<void> updateQueue(List<MediaItem> queue) async {
    await replaceQueue(queue, initialIndex: 0, playWhenReady: false);
  }

  Future<void> replaceQueue(
    List<MediaItem> items, {
    int initialIndex = 0,
    required bool playWhenReady,
  }) async {
    await _settingsReady;
    await _cancelTransition();
    await _resetScratchSpeed();
    if (items.isEmpty) {
      await _player.stop();
      await _standby.stop();
      _items = const [];
      _playOrder = const [];
      _preparedIndex = null;
      _currentIndex = 0;
      _orderPosition = 0;
      queue.add(_items);
      mediaItem.add(null);
      _publishState();
      return;
    }
    if (initialIndex < 0 || initialIndex >= items.length) {
      throw RangeError.index(initialIndex, items, 'initialIndex');
    }

    await _player.stop();
    await _standby.stop();
    _items = List.unmodifiable(items);
    _currentIndex = initialIndex;
    _rebuildPlayOrder(initialIndex);
    _preparedIndex = null;
    queue.add(_items);
    mediaItem.add(_items[initialIndex]);
    await _player.setAudioSource(_sourceFor(_items[initialIndex]));
    await _player.setVolume(1);
    _publishState();
    await _prepareStandby();
    if (playWhenReady) await play();
  }

  bool get _isPlaying =>
      _player.playing || (_isTransitioning && _standby.playing);

  AudioSource _sourceFor(MediaItem item) {
    if (item.extras?['source'] == 'device') {
      return AudioSource.uri(Uri.parse(item.id), tag: item);
    }
    return AudioSource.file(item.id, tag: item);
  }

  Future<void> _loadIndex(int index, {required bool playWhenReady}) async {
    await _cancelTransition();
    await _resetScratchSpeed();
    await _player.stop();
    await _standby.stop();
    _currentIndex = index;
    _orderPosition = _playOrder.indexOf(index);
    if (_orderPosition < 0) {
      _rebuildPlayOrder(index);
    }
    _preparedIndex = null;
    mediaItem.add(_items[index]);
    await _player.setAudioSource(_sourceFor(_items[index]));
    await _player.setVolume(1);
    _publishState();
    await _prepareStandby();
    if (playWhenReady) await play();
  }

  void _rebuildPlayOrder(int currentIndex) {
    final order = List<int>.generate(_items.length, (index) => index);
    if (_shuffleMode == AudioServiceShuffleMode.all) {
      order.remove(currentIndex);
      order.shuffle();
      _playOrder = List.unmodifiable([currentIndex, ...order]);
      _orderPosition = 0;
      return;
    }
    _playOrder = List.unmodifiable(order);
    _orderPosition = currentIndex;
  }

  int? _nextQueueIndex({bool automatic = false}) {
    if (_items.isEmpty) return null;
    if (automatic && _repeatMode == AudioServiceRepeatMode.one) {
      return _currentIndex;
    }
    if (_orderPosition + 1 < _playOrder.length) {
      return _playOrder[_orderPosition + 1];
    }
    if (_repeatMode == AudioServiceRepeatMode.all) {
      return _playOrder.first;
    }
    return null;
  }

  Future<void> _prepareStandby() async {
    final nextIndex = _nextQueueIndex(automatic: true);
    _preparedIndex = null;
    if (nextIndex == null) {
      await _standby.stop();
      return;
    }
    try {
      await _standby.stop();
      await _standby.setVolume(0);
      await _standby.setAudioSource(_sourceFor(_items[nextIndex]));
      _preparedIndex = nextIndex;
    } on Object catch (error, stackTrace) {
      _reportPlaybackError(
        error,
        stackTrace,
        'while preparing the next DJ deck',
      );
    }
  }

  void _considerDjHandoff(Duration position) {
    if (!_player.playing ||
        _isTransitioning ||
        _items.isEmpty ||
        _djMixMode == DjMixMode.off) {
      return;
    }
    final nextIndex = _nextQueueIndex(automatic: true);
    if (nextIndex == null || _preparedIndex != nextIndex) return;
    final outgoingDuration = _player.duration ?? _items[_currentIndex].duration;
    final incomingDuration = _standby.duration ?? _items[nextIndex].duration;
    if (outgoingDuration == null || incomingDuration == null) return;
    final plan = DjTransitionPlanner.plan(
      mode: _djMixMode,
      outgoingDuration: outgoingDuration,
      incomingDuration: incomingDuration,
      outgoingBpm: (_items[_currentIndex].extras?['bpm'] as num?)?.toDouble(),
      incomingBpm: (_items[nextIndex].extras?['bpm'] as num?)?.toDouble(),
    );
    if (plan == null ||
        outgoingDuration - position > plan.duration + _transitionPollMargin) {
      return;
    }
    unawaited(_beginTransition(nextIndex, plan));
  }

  Future<void> _beginTransition(int nextIndex, DjTransitionPlan plan) async {
    if (_isTransitioning || _preparedIndex != nextIndex) return;
    final outgoing = _player;
    final incoming = _standby;
    final remaining = (outgoing.duration ?? Duration.zero) - outgoing.position;
    final transitionDuration = remaining - _transitionSafetyMargin;
    if (transitionDuration < _minimumTransitionTime) return;
    final generation = ++_transitionGeneration;
    _isTransitioning = true;
    _publishState();

    try {
      await incoming.setVolume(0);
      if (plan.incomingSpeed != null) {
        await incoming.setPitch(1);
        await incoming.setSpeed(plan.incomingSpeed!);
      }
      _startDeck(incoming);
      await _crossfade(
        outgoing: outgoing,
        incoming: incoming,
        duration: transitionDuration,
        initialSpeed: plan.incomingSpeed,
        generation: generation,
      );
      if (generation != _transitionGeneration) return;

      await outgoing.pause();
      await outgoing.setVolume(0);
      await incoming.setVolume(1);
      if (plan.incomingSpeed != null) {
        await incoming.setSpeed(1);
        await incoming.setPitch(1);
      }
      _player = incoming;
      _standby = outgoing;
      _currentIndex = nextIndex;
      _orderPosition = _playOrder.indexOf(nextIndex);
      _preparedIndex = null;
      _isTransitioning = false;
      mediaItem.add(_items[nextIndex]);
      _publishState();
      unawaited(_prepareStandby());
    } on Object catch (error, stackTrace) {
      if (generation != _transitionGeneration) return;
      _isTransitioning = false;
      await incoming.pause();
      await incoming.setVolume(0);
      await outgoing.setVolume(1);
      _reportPlaybackError(error, stackTrace, 'while mixing between tracks');
      _publishState();
    }
  }

  Future<void> _crossfade({
    required AudioPlayer outgoing,
    required AudioPlayer incoming,
    required Duration duration,
    required double? initialSpeed,
    required int generation,
  }) async {
    final steps = (duration.inMilliseconds / 100).ceil().clamp(8, 60);
    final stepDuration = Duration(
      milliseconds: duration.inMilliseconds ~/ steps,
    );
    for (var step = 1; step <= steps; step++) {
      await Future<void>.delayed(stepDuration);
      if (generation != _transitionGeneration) return;
      final progress = step / steps;
      await Future.wait([
        outgoing.setVolume(math.cos(progress * math.pi / 2)),
        incoming.setVolume(math.sin(progress * math.pi / 2)),
        if (initialSpeed != null)
          incoming.setSpeed(initialSpeed + (1 - initialSpeed) * progress),
      ]);
    }
  }

  Future<void> _cancelTransition() async {
    _transitionGeneration++;
    final wasTransitioning = _isTransitioning;
    _isTransitioning = false;
    if (wasTransitioning) {
      await _standby.pause();
      await _standby.setVolume(0);
      await _player.setVolume(1);
    }
  }

  Future<void> _resetScratchSpeed() async {
    if (!_isScratching) return;
    _isScratching = false;
    await _player.setPitch(1);
    await _player.setSpeed(1);
  }

  Future<void> _advanceAtEnd() async {
    if (_isAdvancing) return;
    final nextIndex = _nextQueueIndex(automatic: true);
    if (nextIndex == null) {
      _publishState();
      return;
    }
    _isAdvancing = true;
    try {
      await _loadIndex(nextIndex, playWhenReady: true);
    } on Object catch (error, stackTrace) {
      playbackState.add(
        playbackState.value.copyWith(
          processingState: AudioProcessingState.error,
          errorMessage: error.toString(),
        ),
      );
      _reportPlaybackError(error, stackTrace, 'while advancing the queue');
    } finally {
      _isAdvancing = false;
    }
  }

  void _publishDuration(Duration? duration) {
    if (duration == null ||
        _items.isEmpty ||
        _currentIndex >= _items.length ||
        _items[_currentIndex].duration == duration) {
      return;
    }
    final updatedItems = [..._items];
    updatedItems[_currentIndex] = updatedItems[_currentIndex].copyWith(
      duration: duration,
    );
    _items = List.unmodifiable(updatedItems);
    queue.add(_items);
    mediaItem.add(_items[_currentIndex]);
  }

  void _publishState() {
    final processingState = switch (_player.processingState) {
      ProcessingState.idle => AudioProcessingState.idle,
      ProcessingState.loading => AudioProcessingState.loading,
      ProcessingState.buffering => AudioProcessingState.buffering,
      ProcessingState.ready => AudioProcessingState.ready,
      ProcessingState.completed => AudioProcessingState.completed,
    };
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          _isPlaying ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: processingState,
        playing: _isPlaying,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _items.isEmpty ? null : _currentIndex,
        repeatMode: _repeatMode,
        shuffleMode: _shuffleMode,
      ),
    );
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    await _cancelTransition();
    _repeatMode = repeatMode == AudioServiceRepeatMode.group
        ? AudioServiceRepeatMode.all
        : repeatMode;
    await _prepareStandby();
    _publishState();
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    await _cancelTransition();
    _shuffleMode = shuffleMode == AudioServiceShuffleMode.all
        ? AudioServiceShuffleMode.all
        : AudioServiceShuffleMode.none;
    if (_items.isNotEmpty) _rebuildPlayOrder(_currentIndex);
    await _prepareStandby();
    _publishState();
  }

  Future<void> dispose() async {
    await _cancelTransition();
    for (final subscription in _deckSubscriptions) {
      await subscription.cancel();
    }
    await _deckA.dispose();
    await _deckB.dispose();
  }

  static void _reportPlaybackError(
    Object error,
    StackTrace stackTrace,
    String context,
  ) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'tone playback',
        context: ErrorDescription(context),
      ),
    );
  }
}
