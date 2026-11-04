enum DjMixMode { off, smooth, beatMatched }

class DjTransitionPlan {
  const DjTransitionPlan({
    required this.duration,
    required this.tempoMatched,
    this.incomingSpeed,
  });

  final Duration duration;
  final bool tempoMatched;
  final double? incomingSpeed;
}

abstract final class DjTransitionPlanner {
  static const _smoothDuration = Duration(milliseconds: 3200);
  static const _minimumDuration = Duration(milliseconds: 500);
  static const _maximumBeatMatchDuration = Duration(seconds: 6);

  static DjTransitionPlan? plan({
    required DjMixMode mode,
    required Duration outgoingDuration,
    required Duration incomingDuration,
    double? outgoingBpm,
    double? incomingBpm,
  }) {
    if (mode == DjMixMode.off ||
        outgoingDuration <= Duration.zero ||
        incomingDuration <= Duration.zero) {
      return null;
    }

    final speed = mode == DjMixMode.beatMatched
        ? _compatibleSpeed(outgoingBpm, incomingBpm)
        : null;
    final tempoMatched = speed != null;
    var transitionDuration = _smoothDuration;
    if (tempoMatched) {
      final bpm = outgoingBpm!;
      final beatDuration = (8 * 60000 / bpm).round();
      transitionDuration = Duration(
        milliseconds: beatDuration.clamp(
          _minimumDuration.inMilliseconds,
          _maximumBeatMatchDuration.inMilliseconds,
        ),
      );
    }

    final durationLimit = Duration(
      milliseconds:
          (outgoingDuration.inMilliseconds < incomingDuration.inMilliseconds
              ? outgoingDuration.inMilliseconds
              : incomingDuration.inMilliseconds) ~/
          3,
    );
    if (durationLimit < _minimumDuration) return null;
    if (transitionDuration > durationLimit) {
      transitionDuration = durationLimit;
    }

    return DjTransitionPlan(
      duration: transitionDuration,
      tempoMatched: tempoMatched,
      incomingSpeed: speed,
    );
  }

  static double? _compatibleSpeed(double? outgoingBpm, double? incomingBpm) {
    if (outgoingBpm == null ||
        incomingBpm == null ||
        outgoingBpm <= 0 ||
        incomingBpm <= 0) {
      return null;
    }
    final speed = outgoingBpm / incomingBpm;
    return speed >= 0.94 && speed <= 1.06 ? speed : null;
  }
}
