import 'dart:math' as math;

import 'package:tone_player/features/auto_mix/auto_mix_profile.dart';
import 'package:tone_player/features/auto_mix/auto_mix_settings.dart';
import 'package:tone_player/features/auto_mix/track_analysis.dart';
import 'package:tone_player/features/auto_mix/transition_plan.dart';

class TransitionPlanner {
  const TransitionPlanner();

  static const maximumTempoDifferencePercent = 5.0;
  static const _fallbackConfidence = 0.2;
  static const _unreliableConfidence = 0.25;

  TransitionPlan plan({
    required TrackAnalysis outgoing,
    required TrackAnalysis incoming,
    required AutoMixSettings settings,
  }) {
    if (outgoing.trackId == incoming.trackId) {
      throw ArgumentError('A transition requires two different tracks.');
    }

    final compatibility = _assessTempo(outgoing, incoming);
    final duration = _transitionDuration(outgoing, incoming, settings);
    final isCompatible = compatibility.status == TempoCompatibility.compatible;
    final confidence = switch (compatibility.status) {
      TempoCompatibility.compatible =>
        compatibility.evidenceConfidence *
            (1 -
                compatibility.differencePercent! /
                    maximumTempoDifferencePercent *
                    0.1),
      TempoCompatibility.incompatible => compatibility.evidenceConfidence * 0.7,
      TempoCompatibility.unavailable => _fallbackConfidence,
      TempoCompatibility.unreliable => _unreliableConfidence,
    };

    return TransitionPlan(
      outgoingTrackId: outgoing.trackId,
      incomingTrackId: incoming.trackId,
      profile: settings.profile,
      transitionDuration: duration,
      outgoingTransitionPosition: outgoing.duration == null
          ? null
          : outgoing.duration! - duration,
      incomingEntryPosition: Duration.zero,
      style: isCompatible
          ? settings.profile.preferredTransitionStyle
          : TransitionStyle.equalPower,
      tempoCompatibility: compatibility.status,
      bpmDifferencePercent: compatibility.differencePercent,
      confidenceScore: confidence.clamp(0.0, 1.0).toDouble(),
    );
  }

  _TempoAssessment _assessTempo(
    TrackAnalysis outgoing,
    TrackAnalysis incoming,
  ) {
    if (outgoing.bpm == null || incoming.bpm == null) {
      return const _TempoAssessment(
        status: TempoCompatibility.unavailable,
        evidenceConfidence: 0,
      );
    }
    if (!outgoing.hasReliableBpm || !incoming.hasReliableBpm) {
      return const _TempoAssessment(
        status: TempoCompatibility.unreliable,
        evidenceConfidence: 0,
      );
    }

    final differencePercent =
        ((incoming.bpm! - outgoing.bpm!).abs() / outgoing.bpm!) * 100;
    return _TempoAssessment(
      status: differencePercent <= maximumTempoDifferencePercent
          ? TempoCompatibility.compatible
          : TempoCompatibility.incompatible,
      evidenceConfidence: math.min(
        outgoing.bpmConfidence,
        incoming.bpmConfidence,
      ),
      differencePercent: differencePercent,
    );
  }

  Duration _transitionDuration(
    TrackAnalysis outgoing,
    TrackAnalysis incoming,
    AutoMixSettings settings,
  ) {
    var milliseconds = settings.effectiveTransitionDuration.inMilliseconds;
    final outgoingDuration = outgoing.duration;
    final incomingDuration = incoming.duration;
    if (outgoingDuration != null) {
      milliseconds = math.min(milliseconds, outgoingDuration.inMilliseconds);
    }
    if (incomingDuration != null) {
      milliseconds = math.min(milliseconds, incomingDuration.inMilliseconds);
    }
    return Duration(milliseconds: milliseconds);
  }
}

class _TempoAssessment {
  const _TempoAssessment({
    required this.status,
    required this.evidenceConfidence,
    this.differencePercent,
  });

  final TempoCompatibility status;
  final double evidenceConfidence;
  final double? differencePercent;
}
