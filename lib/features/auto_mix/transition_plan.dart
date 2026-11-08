import 'package:melo_player/features/auto_mix/auto_mix_profile.dart';

enum TempoCompatibility { unavailable, unreliable, compatible, incompatible }

class TransitionPlan {
  TransitionPlan({
    required this.outgoingTrackId,
    required this.incomingTrackId,
    required this.profile,
    required this.transitionDuration,
    required this.outgoingTransitionPosition,
    required this.incomingEntryPosition,
    required this.style,
    required this.tempoCompatibility,
    required this.bpmDifferencePercent,
    required this.confidenceScore,
  }) {
    if (outgoingTrackId.trim().isEmpty || incomingTrackId.trim().isEmpty) {
      throw ArgumentError('Transition track IDs must not be empty.');
    }
    if (outgoingTrackId == incomingTrackId) {
      throw ArgumentError('A transition requires two different tracks.');
    }
    if (transitionDuration <= Duration.zero) {
      throw ArgumentError.value(
        transitionDuration,
        'transitionDuration',
        'Must be greater than zero.',
      );
    }
    if (!confidenceScore.isFinite ||
        confidenceScore < 0 ||
        confidenceScore > 1) {
      throw RangeError.range(confidenceScore, 0, 1, 'confidenceScore');
    }
    final difference = bpmDifferencePercent;
    if (difference != null && (!difference.isFinite || difference < 0)) {
      throw ArgumentError.value(
        bpmDifferencePercent,
        'bpmDifferencePercent',
        'Must be finite and non-negative when provided.',
      );
    }
  }

  final String outgoingTrackId;
  final String incomingTrackId;
  final AutoMixProfile profile;
  final Duration transitionDuration;
  final Duration? outgoingTransitionPosition;
  final Duration incomingEntryPosition;
  final TransitionStyle style;
  final TempoCompatibility tempoCompatibility;
  final double? bpmDifferencePercent;

  /// Confidence in the plan's available evidence, not a measure of audio quality.
  final double confidenceScore;

  bool get usesConventionalFallback =>
      tempoCompatibility != TempoCompatibility.compatible;
}
