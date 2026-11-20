import 'package:melo_player/features/auto_mix/auto_mix_profile.dart';
import 'package:melo_player/features/auto_mix/track_analysis.dart';

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
    this.harmonicCompatibility = HarmonicCompatibility.unknown,
    this.outgoingKey,
    this.incomingKey,
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
  final HarmonicCompatibility harmonicCompatibility;
  final String? outgoingKey;
  final String? incomingKey;

  /// Confidence in the plan's available evidence, not a measure of audio quality.
  final double confidenceScore;

  bool get usesConventionalFallback =>
      tempoCompatibility != TempoCompatibility.compatible;

  String get diagnosticBadgeText {
    final styleName = switch (style) {
      TransitionStyle.equalPower => 'Equal Power Crossfade',
      TransitionStyle.gradualAtmospheric => 'Atmospheric Fade',
      TransitionStyle.quickBlend => 'Quick Drop Blend',
    };

    if (harmonicCompatibility != HarmonicCompatibility.unknown &&
        outgoingKey != null &&
        incomingKey != null) {
      final matchLabel = switch (harmonicCompatibility) {
        HarmonicCompatibility.exactMatch => 'Harmonic Lock',
        HarmonicCompatibility.relativeKey => 'Harmonic Lift',
        HarmonicCompatibility.adjacentKey => 'Harmonic Flow',
        HarmonicCompatibility.energyBoost => 'Energy Surge',
        HarmonicCompatibility.incompatible => 'Tempo Cross',
        HarmonicCompatibility.unknown => styleName,
      };
      return '$matchLabel ($outgoingKey → $incomingKey)';
    }

    if (tempoCompatibility == TempoCompatibility.compatible &&
        bpmDifferencePercent != null) {
      return 'BPM Sync (${bpmDifferencePercent!.toStringAsFixed(1)}% diff) · $styleName';
    }

    return styleName;
  }
}
