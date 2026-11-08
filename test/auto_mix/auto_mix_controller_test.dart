import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:melo_player/features/auto_mix/audio_engine.dart';
import 'package:melo_player/features/auto_mix/auto_mix_controller.dart';
import 'package:melo_player/features/auto_mix/auto_mix_profile.dart';
import 'package:melo_player/features/auto_mix/transition_gain_curve.dart';
import 'package:melo_player/features/auto_mix/transition_plan.dart';

void main() {
  test('gain curves have exact endpoints and style-specific midpoints', () {
    for (final style in TransitionStyle.values) {
      expect(TransitionGainCurve.gainsAt(style, 0).outgoing, 1);
      expect(TransitionGainCurve.gainsAt(style, 0).incoming, 0);
      expect(TransitionGainCurve.gainsAt(style, 1).outgoing, closeTo(0, 1e-12));
      expect(TransitionGainCurve.gainsAt(style, 1).incoming, closeTo(1, 1e-12));
    }

    final equalPower = TransitionGainCurve.gainsAt(
      TransitionStyle.equalPower,
      0.5,
    );
    expect(equalPower.outgoing, closeTo(math.sqrt(0.5), 1e-12));
    expect(equalPower.incoming, closeTo(math.sqrt(0.5), 1e-12));

    final gradual = TransitionGainCurve.gainsAt(
      TransitionStyle.gradualAtmospheric,
      0.25,
    );
    final quick = TransitionGainCurve.gainsAt(TransitionStyle.quickBlend, 0.25);
    expect(gradual.incoming, lessThan(quick.incoming));
    expect(quick.outgoing, 0.75);
    expect(quick.incoming, 0.25);
    expect(
      () => TransitionGainCurve.gainsAt(TransitionStyle.equalPower, double.nan),
      throwsRangeError,
    );
  });

  test(
    'runs an equal-power ramp and preserves its final incoming deck',
    () async {
      final engine = _FakeAudioEngine();
      addTearDown(engine.dispose);
      final controller = AutoMixController(
        audioEngine: engine,
        gainStep: const Duration(milliseconds: 25),
        delay: (_) async {},
      );
      await engine.initialize();
      engine.loadForTest(AudioDeck.a, playing: true, gain: 0.8);
      engine.loadForTest(AudioDeck.b, gain: 0.4);

      final progress = <double>[];
      final completed = await controller.transitionIncoming(
        plan: _plan(
          style: TransitionStyle.equalPower,
          duration: const Duration(milliseconds: 100),
        ),
        targetGain: 0.6,
        onProgress: progress.add,
      );

      expect(completed, isTrue);
      expect(progress, [0.25, 0.5, 0.75, 1]);
      expect(engine.gainHistory[AudioDeck.a], hasLength(5));
      expect(engine.gainHistory[AudioDeck.b], hasLength(6));
      expect(
        engine.gainHistory[AudioDeck.a]!.first,
        closeTo(0.8 * math.cos(math.pi / 8), 1e-9),
      );
      expect(engine.gainHistory[AudioDeck.a]!.last, 0);
      expect(engine.gainHistory[AudioDeck.b]!.first, 0);
      expect(engine.gainHistory[AudioDeck.b]!.last, 0.6);
      expect(engine.stateFor(AudioDeck.a).playing, isFalse);
      expect(engine.stateFor(AudioDeck.b).playing, isTrue);
      expect(
        engine.gainHistory[AudioDeck.a]![1],
        closeTo(0.8 * math.sqrt(0.5), 1e-9),
      );
      expect(
        engine.gainHistory[AudioDeck.b]![2],
        closeTo(0.6 * math.sqrt(0.5), 1e-9),
      );

      await controller.promoteIncomingDeck();
      expect(engine.stateFor(AudioDeck.a).playing, isTrue);
      expect(engine.stateFor(AudioDeck.a).gain, 0.6);
      expect(engine.stateFor(AudioDeck.b).playing, isFalse);
    },
  );

  test('cancellation restores deck gains and leaves Deck A playing', () async {
    final stepStarted = Completer<void>();
    final holdStep = Completer<void>();
    final engine = _FakeAudioEngine();
    addTearDown(engine.dispose);
    late final AutoMixController controller;
    controller = AutoMixController(
      audioEngine: engine,
      gainStep: const Duration(milliseconds: 25),
      delay: (_) async {
        if (!stepStarted.isCompleted) stepStarted.complete();
        await holdStep.future;
      },
    );
    await engine.initialize();
    engine.loadForTest(AudioDeck.a, playing: true, gain: 0.7);
    engine.loadForTest(AudioDeck.b, gain: 0.3);

    final transition = controller.transitionIncoming(
      plan: _plan(duration: const Duration(milliseconds: 200)),
      targetGain: 0.7,
    );
    await stepStarted.future;
    await controller.cancelTransition();
    holdStep.complete();

    expect(await transition, isFalse);
    expect(engine.stateFor(AudioDeck.a).playing, isTrue);
    expect(engine.stateFor(AudioDeck.a).gain, 0.7);
    expect(engine.stateFor(AudioDeck.b).playing, isFalse);
    expect(engine.stateFor(AudioDeck.b).gain, 0.3);
    expect(engine.stateFor(AudioDeck.b).position, Duration.zero);
    expect(controller.isTransitioning, isFalse);
  });

  test(
    'requires a loaded, playing outgoing deck and loaded incoming deck',
    () async {
      final engine = _FakeAudioEngine();
      addTearDown(engine.dispose);
      final controller = AutoMixController(
        audioEngine: engine,
        delay: (_) async {},
      );
      await engine.initialize();

      await expectLater(
        controller.transitionIncoming(plan: _plan(), targetGain: 1),
        throwsStateError,
      );
      engine.loadForTest(AudioDeck.a, playing: true);
      await expectLater(
        controller.transitionIncoming(plan: _plan(), targetGain: 1),
        throwsStateError,
      );
      engine.loadForTest(AudioDeck.b);
      await expectLater(
        controller.transitionIncoming(plan: _plan(), targetGain: double.nan),
        throwsRangeError,
      );
    },
  );
}

TransitionPlan _plan({
  TransitionStyle style = TransitionStyle.equalPower,
  Duration duration = const Duration(milliseconds: 100),
}) => TransitionPlan(
  outgoingTrackId: 'outgoing',
  incomingTrackId: 'incoming',
  profile: AutoMixProfile.balanced,
  transitionDuration: duration,
  outgoingTransitionPosition: Duration.zero,
  incomingEntryPosition: Duration.zero,
  style: style,
  tempoCompatibility: TempoCompatibility.unavailable,
  bpmDifferencePercent: null,
  confidenceScore: 0.2,
);

class _FakeAudioEngine implements AudioEngine {
  final _states = StreamController<AudioDeckState>.broadcast();
  final _errors = StreamController<AudioEngineError>.broadcast();
  final _deckStates = <AudioDeck, AudioDeckState>{};
  final gainHistory = <AudioDeck, List<double>>{
    AudioDeck.a: [],
    AudioDeck.b: [],
  };
  bool _initialized = false;
  bool _disposed = false;

  @override
  Stream<AudioDeckState> get states => _states.stream;

  @override
  Stream<AudioEngineError> get errors => _errors.stream;

  @override
  Future<void> initialize() async {
    _initialized = true;
    for (final deck in AudioDeck.values) {
      _deckStates.putIfAbsent(deck, () => _state(deck));
    }
  }

  @override
  AudioDeckState stateFor(AudioDeck deck) => _deckStates[deck]!;

  void loadForTest(AudioDeck deck, {bool playing = false, double gain = 1}) {
    _update(
      deck,
      loaded: true,
      playing: playing,
      processingState: AudioDeckProcessingState.ready,
      gain: gain,
    );
    gainHistory[deck]!.clear();
  }

  @override
  Future<void> loadDeck(AudioDeck deck, AudioDeckSource source) async {
    _checkReady();
    _update(
      deck,
      loaded: true,
      processingState: AudioDeckProcessingState.ready,
    );
  }

  @override
  Future<void> unloadDeck(AudioDeck deck) async {
    _checkReady();
    _update(
      deck,
      loaded: false,
      playing: false,
      processingState: AudioDeckProcessingState.idle,
    );
  }

  @override
  Future<void> playDeck(AudioDeck deck) async {
    _checkReady();
    _update(deck, playing: true);
  }

  @override
  Future<void> pauseDeck(AudioDeck deck) async {
    _checkReady();
    _update(deck, playing: false);
  }

  @override
  Future<void> stopDeck(AudioDeck deck) => pauseDeck(deck);

  @override
  Future<void> seekDeck(AudioDeck deck, Duration position) async {
    _checkReady();
    _update(deck, position: position);
  }

  @override
  Future<void> setDeckGain(AudioDeck deck, double gain) async {
    _checkReady();
    gainHistory[deck]!.add(gain);
    _update(deck, gain: gain);
  }

  @override
  Future<void> promoteIncomingDeck() async {
    _checkReady();
    final outgoing = stateFor(AudioDeck.a);
    final incoming = stateFor(AudioDeck.b);
    _deckStates[AudioDeck.a] = _copyAs(incoming, AudioDeck.a);
    _deckStates[AudioDeck.b] = _copyAs(outgoing, AudioDeck.b);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _states.close();
    await _errors.close();
  }

  AudioDeckState _state(AudioDeck deck) => AudioDeckState(
    deck: deck,
    processingState: AudioDeckProcessingState.idle,
    playing: false,
    position: Duration.zero,
    bufferedPosition: Duration.zero,
    duration: null,
    gain: 1,
    playbackRate: 1,
    loaded: false,
  );

  void _update(
    AudioDeck deck, {
    AudioDeckProcessingState? processingState,
    bool? playing,
    Duration? position,
    double? gain,
    bool? loaded,
  }) {
    final previous = _deckStates[deck]!;
    final next = AudioDeckState(
      deck: deck,
      processingState: processingState ?? previous.processingState,
      playing: playing ?? previous.playing,
      position: position ?? previous.position,
      bufferedPosition: previous.bufferedPosition,
      duration: previous.duration,
      gain: gain ?? previous.gain,
      playbackRate: previous.playbackRate,
      loaded: loaded ?? previous.loaded,
    );
    _deckStates[deck] = next;
    _states.add(next);
  }

  AudioDeckState _copyAs(AudioDeckState state, AudioDeck deck) =>
      AudioDeckState(
        deck: deck,
        processingState: state.processingState,
        playing: state.playing,
        position: state.position,
        bufferedPosition: state.bufferedPosition,
        duration: state.duration,
        gain: state.gain,
        playbackRate: state.playbackRate,
        loaded: state.loaded,
        error: state.error,
      );

  void _checkReady() {
    if (!_initialized) throw StateError('Engine is not initialized.');
    if (_disposed) throw StateError('Engine is disposed.');
  }
}
