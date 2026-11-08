import 'package:flutter_test/flutter_test.dart';
import 'package:tone_player/features/auto_mix/auto_mix_profile.dart';
import 'package:tone_player/features/auto_mix/auto_mix_settings.dart';
import 'package:tone_player/features/auto_mix/track_analysis.dart';
import 'package:tone_player/features/auto_mix/transition_plan.dart';
import 'package:tone_player/features/auto_mix/transition_planner.dart';

void main() {
  const planner = TransitionPlanner();

  TrackAnalysis track(
    String id, {
    Duration? duration = const Duration(minutes: 3),
    double? bpm,
    double bpmConfidence = 0,
  }) => TrackAnalysis(
    trackId: id,
    duration: duration,
    bpm: bpm,
    bpmConfidence: bpmConfidence,
  );

  test('missing BPM uses a low-confidence conventional fallback', () {
    final plan = planner.plan(
      outgoing: track('outgoing'),
      incoming: track('incoming'),
      settings: AutoMixSettings(),
    );

    expect(plan.tempoCompatibility, TempoCompatibility.unavailable);
    expect(plan.usesConventionalFallback, isTrue);
    expect(plan.style, TransitionStyle.equalPower);
    expect(plan.confidenceScore, lessThan(0.5));
    expect(plan.transitionDuration, const Duration(seconds: 10));
  });

  test('matching reliable BPM values are compatible', () {
    final plan = planner.plan(
      outgoing: track('outgoing', bpm: 120, bpmConfidence: 0.9),
      incoming: track('incoming', bpm: 120, bpmConfidence: 0.8),
      settings: AutoMixSettings(),
    );

    expect(plan.tempoCompatibility, TempoCompatibility.compatible);
    expect(plan.bpmDifferencePercent, 0);
    expect(plan.usesConventionalFallback, isFalse);
    expect(plan.confidenceScore, closeTo(0.8, 0.0001));
  });

  test('tempo differences beyond five percent use the fallback', () {
    final plan = planner.plan(
      outgoing: track('outgoing', bpm: 120, bpmConfidence: 0.95),
      incoming: track('incoming', bpm: 130, bpmConfidence: 0.9),
      settings: AutoMixSettings(),
    );

    expect(plan.tempoCompatibility, TempoCompatibility.incompatible);
    expect(plan.bpmDifferencePercent, closeTo(8.3333, 0.001));
    expect(plan.usesConventionalFallback, isTrue);
    expect(plan.style, TransitionStyle.equalPower);
  });

  test('five-percent tempo difference is the compatibility boundary', () {
    final atBoundary = planner.plan(
      outgoing: track('outgoing', bpm: 120, bpmConfidence: 0.9),
      incoming: track('incoming', bpm: 126, bpmConfidence: 0.9),
      settings: AutoMixSettings(),
    );
    final outsideBoundary = planner.plan(
      outgoing: track('outgoing', bpm: 120, bpmConfidence: 0.9),
      incoming: track('incoming', bpm: 126.01, bpmConfidence: 0.9),
      settings: AutoMixSettings(),
    );

    expect(atBoundary.tempoCompatibility, TempoCompatibility.compatible);
    expect(outsideBoundary.tempoCompatibility, TempoCompatibility.incompatible);
  });

  test('invalid or low-confidence BPM is not treated as compatible', () {
    for (final bpm in [0.0, 39.0, 241.0, double.nan, double.infinity]) {
      final plan = planner.plan(
        outgoing: track('outgoing', bpm: bpm, bpmConfidence: 1),
        incoming: track('incoming', bpm: 120, bpmConfidence: 1),
        settings: AutoMixSettings(),
      );

      expect(plan.tempoCompatibility, TempoCompatibility.unreliable);
      expect(plan.usesConventionalFallback, isTrue);
      expect(plan.confidenceScore, lessThan(0.5));
    }

    final lowConfidencePlan = planner.plan(
      outgoing: track('outgoing', bpm: 120, bpmConfidence: 0.69),
      incoming: track('incoming', bpm: 120, bpmConfidence: 1),
      settings: AutoMixSettings(),
    );
    expect(lowConfidencePlan.tempoCompatibility, TempoCompatibility.unreliable);
  });

  test('missing analysis evidence remains distinct from incompatible BPM', () {
    final plan = planner.plan(
      outgoing: track('outgoing', duration: null),
      incoming: track('incoming', duration: null),
      settings: AutoMixSettings(profile: AutoMixProfile.atmospheric),
    );

    expect(plan.tempoCompatibility, TempoCompatibility.unavailable);
    expect(plan.confidenceScore, 0.2);
    expect(plan.outgoingTransitionPosition, isNull);
    expect(plan.transitionDuration, const Duration(seconds: 20));
    expect(plan.style, TransitionStyle.equalPower);
  });

  test('each profile selects its own duration and style with reliable BPM', () {
    final expected = {
      AutoMixProfile.atmospheric: (
        const Duration(seconds: 20),
        TransitionStyle.gradualAtmospheric,
      ),
      AutoMixProfile.balanced: (
        const Duration(seconds: 10),
        TransitionStyle.equalPower,
      ),
      AutoMixProfile.energetic: (
        const Duration(seconds: 4),
        TransitionStyle.quickBlend,
      ),
    };

    for (final entry in expected.entries) {
      final plan = planner.plan(
        outgoing: track('outgoing', bpm: 120, bpmConfidence: 0.9),
        incoming: track('incoming', bpm: 122, bpmConfidence: 0.9),
        settings: AutoMixSettings(profile: entry.key),
      );
      expect(plan.profile, entry.key);
      expect(plan.transitionDuration, entry.value.$1);
      expect(plan.style, entry.value.$2);
    }
  });

  test('configured duration is bounded and shortened for short tracks', () {
    expect(
      () => AutoMixSettings(
        transitionDuration: const Duration(milliseconds: 2999),
      ),
      throwsRangeError,
    );
    expect(
      () => AutoMixSettings(transitionDuration: const Duration(seconds: 31)),
      throwsRangeError,
    );
    expect(
      AutoMixSettings(
        transitionDuration: AutoMixSettings.minimumTransitionDuration,
      ).effectiveTransitionDuration,
      AutoMixSettings.minimumTransitionDuration,
    );
    expect(
      AutoMixSettings(
        transitionDuration: AutoMixSettings.maximumTransitionDuration,
      ).effectiveTransitionDuration,
      AutoMixSettings.maximumTransitionDuration,
    );

    final plan = planner.plan(
      outgoing: track(
        'outgoing',
        duration: const Duration(seconds: 6),
        bpm: 120,
        bpmConfidence: 0.9,
      ),
      incoming: track(
        'incoming',
        duration: const Duration(seconds: 2),
        bpm: 120,
        bpmConfidence: 0.9,
      ),
      settings: AutoMixSettings(
        transitionDuration: const Duration(seconds: 30),
      ),
    );

    expect(plan.transitionDuration, const Duration(seconds: 2));
    expect(plan.outgoingTransitionPosition, const Duration(seconds: 4));
    expect(plan.incomingEntryPosition, Duration.zero);
  });

  test('rejects invalid track identity and invalid duration metadata', () {
    expect(() => track(' '), throwsArgumentError);
    expect(
      () => track('outgoing', duration: Duration.zero),
      throwsArgumentError,
    );
    expect(
      () => planner.plan(
        outgoing: track('same'),
        incoming: track('same'),
        settings: AutoMixSettings(),
      ),
      throwsArgumentError,
    );
  });
}
