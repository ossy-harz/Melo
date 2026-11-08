import 'dart:math' as math;

import 'package:melo_player/features/auto_mix/auto_mix_profile.dart';

class DeckGainPair {
  const DeckGainPair({required this.outgoing, required this.incoming});

  final double outgoing;
  final double incoming;
}

class TransitionGainCurve {
  const TransitionGainCurve._();

  static DeckGainPair gainsAt(TransitionStyle style, double progress) {
    if (!progress.isFinite || progress < 0 || progress > 1) {
      throw RangeError.range(progress, 0, 1, 'progress');
    }

    final shapedProgress = switch (style) {
      TransitionStyle.equalPower => progress,
      TransitionStyle.gradualAtmospheric =>
        progress * progress * (3 - 2 * progress),
      TransitionStyle.quickBlend => progress,
    };

    return switch (style) {
      TransitionStyle.equalPower ||
      TransitionStyle.gradualAtmospheric => DeckGainPair(
        outgoing: math.cos(shapedProgress * math.pi / 2),
        incoming: math.sin(shapedProgress * math.pi / 2),
      ),
      TransitionStyle.quickBlend => DeckGainPair(
        outgoing: 1 - shapedProgress,
        incoming: shapedProgress,
      ),
    };
  }
}
