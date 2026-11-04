import 'package:flutter_test/flutter_test.dart';
import 'package:tone_player/features/player/dj_transition.dart';

void main() {
  test('smooth mode crossfades even without BPM metadata', () {
    final plan = DjTransitionPlanner.plan(
      mode: DjMixMode.smooth,
      outgoingDuration: const Duration(minutes: 3),
      incomingDuration: const Duration(minutes: 4),
    );

    expect(plan, isNotNull);
    expect(plan!.duration, const Duration(milliseconds: 3200));
    expect(plan.tempoMatched, isFalse);
    expect(plan.incomingSpeed, isNull);
  });

  test('beat-matched mode uses compatible tagged tempos', () {
    final plan = DjTransitionPlanner.plan(
      mode: DjMixMode.beatMatched,
      outgoingDuration: const Duration(minutes: 3),
      incomingDuration: const Duration(minutes: 4),
      outgoingBpm: 120,
      incomingBpm: 124,
    );

    expect(plan, isNotNull);
    expect(plan!.duration, const Duration(seconds: 4));
    expect(plan.tempoMatched, isTrue);
    expect(plan.incomingSpeed, closeTo(120 / 124, 0.0001));
  });

  test(
    'beat matching falls back to a smooth blend without compatible tags',
    () {
      final plan = DjTransitionPlanner.plan(
        mode: DjMixMode.beatMatched,
        outgoingDuration: const Duration(minutes: 3),
        incomingDuration: const Duration(minutes: 4),
        outgoingBpm: 120,
      );

      expect(plan, isNotNull);
      expect(plan!.duration, const Duration(milliseconds: 3200));
      expect(plan.tempoMatched, isFalse);
      expect(plan.incomingSpeed, isNull);
    },
  );

  test('disabled mode and very short tracks do not overlap', () {
    expect(
      DjTransitionPlanner.plan(
        mode: DjMixMode.off,
        outgoingDuration: const Duration(minutes: 3),
        incomingDuration: const Duration(minutes: 3),
      ),
      isNull,
    );
    expect(
      DjTransitionPlanner.plan(
        mode: DjMixMode.smooth,
        outgoingDuration: const Duration(milliseconds: 1200),
        incomingDuration: const Duration(milliseconds: 900),
      ),
      isNull,
    );
  });
}
