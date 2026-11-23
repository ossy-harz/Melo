import 'dart:async';
import 'dart:math' as math;

import 'package:melo_player/features/auto_mix/audio_engine.dart';
import 'package:melo_player/features/auto_mix/auto_mix_settings.dart';
import 'package:melo_player/features/auto_mix/track_analysis.dart';
import 'package:melo_player/features/auto_mix/transition_plan.dart';
import 'package:melo_player/features/auto_mix/transition_gain_curve.dart';
import 'package:melo_player/features/auto_mix/transition_planner.dart';

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
  bool _restoreDecksOnCancel = true;
  double _liveTargetGain = 1.0;
  double _liveOutgoingGain = 1.0;
  double _masterMultiplier = 1.0;

  AutoMixSettings get settings => _settings;
  bool get isTransitioning => _activeTransition != null;

  /// Dynamically updates target and outgoing gains or master ducking multiplier during an active transition.
  /// This ensures volume slider changes and notification ducking propagate immediately
  /// across both decks rather than using frozen initial gains.
  void updateTransitionGains({
    double? targetGain,
    double? outgoingGain,
    double? masterMultiplier,
  }) {
    if (targetGain != null && targetGain.isFinite) {
      _liveTargetGain = targetGain.clamp(0.0, 1.0);
    }
    if (outgoingGain != null && outgoingGain.isFinite) {
      _liveOutgoingGain = outgoingGain.clamp(0.0, 1.0);
    }
    if (masterMultiplier != null && masterMultiplier.isFinite) {
      _masterMultiplier = masterMultiplier.clamp(0.0, 1.0);
    }
  }

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
    _restoreDecksOnCancel = true;
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

  Future<void> cancelTransition({bool restoreDecks = true}) async {
    final active = _activeTransition;
    final signal = _cancelSignal;
    if (active == null || signal == null) return;
    _restoreDecksOnCancel = restoreDecks;
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
    _liveTargetGain = targetGain;
    _liveOutgoingGain = outgoingGain;
    _masterMultiplier = 1.0;
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
        final deckAGain = _liveOutgoingGain * _masterMultiplier * gains.outgoing;
        final deckBGain = _liveTargetGain * _masterMultiplier * gains.incoming;
        await Future.wait([
          _audioEngine.setDeckGain(AudioDeck.a, deckAGain),
          _audioEngine.setDeckGain(AudioDeck.b, deckBGain),
        ]);
        onProgress?.call(step / steps);
      }
      await _audioEngine.setDeckGain(AudioDeck.a, 0);
      await _audioEngine.setDeckGain(
        AudioDeck.b,
        _liveTargetGain * _masterMultiplier,
      );
      await _audioEngine.pauseDeck(AudioDeck.a);
      return true;
    } on _TransitionCancelled {
      if (_restoreDecksOnCancel) {
        await _restoreDecks(
          outgoingGain: _liveOutgoingGain * _masterMultiplier,
          incomingGain: incomingGain,
          incomingWasPlaying: incomingWasPlaying,
          incomingPosition: incomingPosition,
        );
      }
      return false;
    } on Object catch (error, stackTrace) {
      try {
        if (_restoreDecksOnCancel) {
          await _restoreDecks(
            outgoingGain: _liveOutgoingGain * _masterMultiplier,
            incomingGain: incomingGain,
            incomingWasPlaying: incomingWasPlaying,
            incomingPosition: incomingPosition,
          );
        }
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
