import 'dart:math' as math;

import 'audio_engine.dart';
import 'auto_mix_profile.dart';

class TransitionDiagnostic {
  TransitionDiagnostic({
    required this.trialId,
    required this.outgoingTrackId,
    required this.incomingTrackId,
    required this.profile,
    required this.requestedDuration,
  });

  final String trialId;
  final String outgoingTrackId;
  final String incomingTrackId;
  final AutoMixProfile profile;
  final Duration requestedDuration;
  final List<Map<String, Object?>> _events = [];
  final Map<AudioDeck, List<int>> _gainUpdateTicks = {
    AudioDeck.a: [],
    AudioDeck.b: [],
  };
  final Map<AudioDeck, double?> _lastGains = {
    AudioDeck.a: null,
    AudioDeck.b: null,
  };
  final Map<AudioDeck, double> _minimumGains = {};
  final Map<AudioDeck, double> _maximumGains = {};
  DateTime? startedAt;
  DateTime? completedAt;
  DateTime? trialEndedAt;
  int? elapsedMilliseconds;
  String? cancellationReason;
  String? error;
  bool? incomingPromoted;
  Map<String, Object?>? recoveryBehavior;
  final Stopwatch _measurementClock = Stopwatch()..start();
  bool _recordingGainUpdates = false;

  void seedDeckState(AudioDeckState state) {
    _lastGains[state.deck] = state.gain;
    _minimumGains[state.deck] = state.gain;
    _maximumGains[state.deck] = state.gain;
  }

  void recordEvent(String name, {Map<String, Object?> details = const {}}) {
    _events.add({
      'name': name,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      ...details,
    });
  }

  void recordDeckState(AudioDeckState state) {
    if (!_recordingGainUpdates) return;
    final previous = _lastGains[state.deck];
    if (previous != state.gain) {
      _lastGains[state.deck] = state.gain;
      _gainUpdateTicks[state.deck]!.add(_measurementClock.elapsedMicroseconds);
      _minimumGains.update(
        state.deck,
        (value) => math.min(value, state.gain),
        ifAbsent: () => state.gain,
      );
      _maximumGains.update(
        state.deck,
        (value) => math.max(value, state.gain),
        ifAbsent: () => state.gain,
      );
      recordEvent(
        'gainStateChanged',
        details: {
          'deck': state.deck.name,
          'gain': state.gain,
          'timingSource': 'dartAudioEngineStateStream',
        },
      );
    }
  }

  void start() {
    startedAt = DateTime.now().toUtc();
    _stopwatch.start();
    _recordingGainUpdates = true;
    recordEvent('transitionStarted');
  }

  void finish(String lifecycleEvent) {
    final now = DateTime.now().toUtc();
    if (lifecycleEvent == 'gainRampCompleted') completedAt ??= now;
    if (lifecycleEvent == 'transitionCompleted') {
      trialEndedAt = now;
    } else {
      trialEndedAt ??= now;
    }
    _recordingGainUpdates = false;
    if (_stopwatch.isRunning) {
      _stopwatch.stop();
      elapsedMilliseconds = _stopwatch.elapsedMilliseconds;
    }
    recordEvent(lifecycleEvent);
  }

  final Stopwatch _stopwatch = Stopwatch();

  Map<String, Object?> toJson() => {
    'trialId': trialId,
    'outgoingTrackId': outgoingTrackId,
    'incomingTrackId': incomingTrackId,
    'profile': profile.name,
    'requestedDurationMs': requestedDuration.inMilliseconds,
    'actualStartedAt': startedAt?.toIso8601String(),
    'actualCompletedAt': completedAt?.toIso8601String(),
    'trialEndedAt': trialEndedAt?.toIso8601String(),
    'actualElapsedMs': elapsedMilliseconds,
    'timingSource': 'Dart-side player-state updates; not audio-output timing',
    'gainUpdates': {
      for (final deck in AudioDeck.values)
        deck.name: {
          'count': _gainUpdateTicks[deck]!.length,
          'medianIntervalMs': _medianInterval(_gainUpdateTicks[deck]!),
          'maximumIntervalMs': _maximumInterval(_gainUpdateTicks[deck]!),
          'minimumGain': _minimumGains[deck],
          'maximumGain': _maximumGains[deck],
        },
    },
    'lifecycleEvents': List.unmodifiable(_events),
    'cancellationReason': cancellationReason,
    'error': error,
    'incomingPromoted': incomingPromoted,
    'recoveryBehavior': recoveryBehavior,
  };

  int? _medianInterval(List<int> timestamps) {
    if (timestamps.length < 2) return null;
    final intervals = [
      for (var index = 1; index < timestamps.length; index++)
        timestamps[index] - timestamps[index - 1],
    ]..sort();
    final middle = intervals.length ~/ 2;
    final median = intervals.length.isOdd
        ? intervals[middle]
        : (intervals[middle - 1] + intervals[middle]) ~/ 2;
    return (median / 1000).round();
  }

  int? _maximumInterval(List<int> timestamps) {
    if (timestamps.length < 2) return null;
    var maximum = 0;
    for (var index = 1; index < timestamps.length; index++) {
      maximum = math.max(maximum, timestamps[index] - timestamps[index - 1]);
    }
    return (maximum / 1000).round();
  }
}
