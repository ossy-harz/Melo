import 'dart:async';
import 'dart:math' as math;

import 'package:tone_player/features/auto_mix/audio_engine.dart';
import 'package:tone_player/features/auto_mix/auto_mix_settings.dart';
import 'package:tone_player/features/auto_mix/track_analysis.dart';
import 'package:tone_player/features/auto_mix/transition_plan.dart';
import 'package:tone_player/features/auto_mix/transition_gain_curve.dart';
import 'package:tone_player/features/auto_mix/transition_planner.dart';

typedef TransitionDelay = Future<void> Function(Duration duration);

/// Coordinates transition planning with an injected audio engine.
///
/// Tone owns this controller inside its audio-service handler so deck
/// operations share the queue's audio-session and lifecycle boundary.
class AutoMixController {
  AutoMixController({
    required this._audioEngine,
    this._planner = const TransitionPlanner(),
    AutoMixSettings? settings,
    Duration gainStep = defaultGainStep,
    TransitionDelay? delay,
  }) : _settings = settings ?? AutoMixSettings(),
       _gainStep = gainStep,
       _delay = delay ?? _wait {
    if (gainStep <= Duration.zero) {
      throw ArgumentError.value(
        gainStep,
        'gainStep',
        'Must be greater than zero.',
      );
    }
  }

  static const defaultGainStep = Duration(milliseconds: 20);

  final AudioEngine _audioEngine;
  final TransitionPlanner _planner;
  final Duration _gainStep;
  final TransitionDelay _delay;
  AutoMixSettings _settings;
  Future<bool>? _activeTransition;
  Completer<void>? _cancelSignal;

  AutoMixSettings get settings => _settings;
  bool get isTransitioning => _activeTransition != null;

  void updateSettings(AutoMixSettings settings) {
    _settings = settings;
  }

  TransitionPlan planTransition({
    required TrackAnalysis outgoing,
    required TrackAnalysis incoming,
    Duration? transitionDuration,
  }) => _planner.plan(
    outgoing: outgoing,
    incoming: incoming,
    settings: transitionDuration == null
        ? _settings
        : AutoMixSettings(
            profile: _settings.profile,
            transitionDuration: transitionDuration,
          ),
  );

  Future<void> preloadIncoming(AudioDeckSource source) =>
      _audioEngine.loadDeck(AudioDeck.b, source);

  AudioDeckState get incomingDeckState => _audioEngine.stateFor(AudioDeck.b);

  Future<void> playIncomingDeck() => _audioEngine.playDeck(AudioDeck.b);

  Future<void> pauseIncomingDeck() => _audioEngine.pauseDeck(AudioDeck.b);

  Future<void> seekIncomingDeck(Duration position) =>
      _audioEngine.seekDeck(AudioDeck.b, position);

  Future<void> setIncomingDeckGain(double gain) =>
      _audioEngine.setDeckGain(AudioDeck.b, gain);

  Future<void> unloadIncomingDeck() => _audioEngine.unloadDeck(AudioDeck.b);

  Future<void> promoteIncomingDeck() => _audioEngine.promoteIncomingDeck();

  Future<bool> transitionIncoming({
    required TransitionPlan plan,
    required double targetGain,
    void Function()? onStarted,
    void Function(double progress)? onProgress,
  }) async {
    if (_activeTransition != null) {
      throw StateError('An AutoMix gain transition is already running.');
    }
    if (!targetGain.isFinite || targetGain < 0 || targetGain > 1) {
      throw RangeError.range(targetGain, 0, 1, 'targetGain');
    }
    final outgoing = _audioEngine.stateFor(AudioDeck.a);
    final incoming = _audioEngine.stateFor(AudioDeck.b);
    if (!outgoing.loaded || !outgoing.playing) {
      throw StateError('Deck A must be loaded and playing to transition.');
    }
    if (!incoming.loaded) {
      throw StateError('Deck B must be loaded to transition.');
    }

    final cancelSignal = Completer<void>();
    _cancelSignal = cancelSignal;
    final operation = _runGainTransition(
      plan: plan,
      outgoingGain: outgoing.gain,
      incomingGain: incoming.gain,
      incomingWasPlaying: incoming.playing,
      incomingPosition: incoming.position,
      targetGain: targetGain,
      cancelSignal: cancelSignal,
      onStarted: onStarted,
      onProgress: onProgress,
    );
    _activeTransition = operation;
    try {
      return await operation;
    } finally {
      if (identical(_activeTransition, operation)) {
        _activeTransition = null;
        _cancelSignal = null;
      }
    }
  }

  Future<void> cancelTransition() async {
    final active = _activeTransition;
    final signal = _cancelSignal;
    if (active == null || signal == null) return;
    if (!signal.isCompleted) signal.complete();
    await active;
  }

  Future<bool> _runGainTransition({
    required TransitionPlan plan,
    required double outgoingGain,
    required double incomingGain,
    required bool incomingWasPlaying,
    required Duration incomingPosition,
    required double targetGain,
    required Completer<void> cancelSignal,
    void Function()? onStarted,
    void Function(double progress)? onProgress,
  }) async {
    try {
      await _audioEngine.seekDeck(AudioDeck.b, plan.incomingEntryPosition);
      await _audioEngine.setDeckGain(AudioDeck.b, 0);
      if (!incomingWasPlaying) await _audioEngine.playDeck(AudioDeck.b);
      onStarted?.call();

      final steps = math.max(
        1,
        (plan.transitionDuration.inMicroseconds / _gainStep.inMicroseconds)
            .ceil(),
      );
      for (var step = 1; step <= steps; step++) {
        await Future.any<void>([_delay(_gainStep), cancelSignal.future]);
        if (cancelSignal.isCompleted) throw const _TransitionCancelled();
        final gains = TransitionGainCurve.gainsAt(plan.style, step / steps);
        await Future.wait([
          _audioEngine.setDeckGain(AudioDeck.a, outgoingGain * gains.outgoing),
          _audioEngine.setDeckGain(AudioDeck.b, targetGain * gains.incoming),
        ]);
        onProgress?.call(step / steps);
      }
      await _audioEngine.setDeckGain(AudioDeck.a, 0);
      await _audioEngine.setDeckGain(AudioDeck.b, targetGain);
      await _audioEngine.pauseDeck(AudioDeck.a);
      return true;
    } on _TransitionCancelled {
      await _restoreDecks(
        outgoingGain: outgoingGain,
        incomingGain: incomingGain,
        incomingWasPlaying: incomingWasPlaying,
        incomingPosition: incomingPosition,
      );
      return false;
    } on Object catch (error, stackTrace) {
      try {
        await _restoreDecks(
          outgoingGain: outgoingGain,
          incomingGain: incomingGain,
          incomingWasPlaying: incomingWasPlaying,
          incomingPosition: incomingPosition,
        );
      } on Object catch (restoreError, restoreStackTrace) {
        Error.throwWithStackTrace(
          StateError(
            'Transition failed ($error); deck recovery also failed '
            '($restoreError).',
          ),
          restoreStackTrace,
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _restoreDecks({
    required double outgoingGain,
    required double incomingGain,
    required bool incomingWasPlaying,
    required Duration incomingPosition,
  }) async {
    if (!incomingWasPlaying) await _audioEngine.pauseDeck(AudioDeck.b);
    await Future.wait([
      _audioEngine.setDeckGain(AudioDeck.a, outgoingGain),
      _audioEngine.setDeckGain(AudioDeck.b, incomingGain),
      _audioEngine.seekDeck(AudioDeck.b, incomingPosition),
    ]);
  }

  static Future<void> _wait(Duration duration) =>
      Future<void>.delayed(duration);
}

class _TransitionCancelled implements Exception {
  const _TransitionCancelled();
}
