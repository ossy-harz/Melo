class TrackAnalysis {
  TrackAnalysis({
    required this.trackId,
    this.duration,
    this.bpm,
    this.bpmConfidence = 0,
  }) {
    if (trackId.trim().isEmpty) {
      throw ArgumentError.value(trackId, 'trackId', 'Must not be empty.');
    }
    if (duration != null && duration! <= Duration.zero) {
      throw ArgumentError.value(
        duration,
        'duration',
        'Must be greater than zero when provided.',
      );
    }
    if (!bpmConfidence.isFinite || bpmConfidence < 0 || bpmConfidence > 1) {
      throw RangeError.range(bpmConfidence, 0, 1, 'bpmConfidence');
    }
    if (bpm == null && bpmConfidence != 0) {
      throw ArgumentError.value(
        bpmConfidence,
        'bpmConfidence',
        'Must be zero when BPM is missing.',
      );
    }
  }

  static const minimumPlausibleBpm = 40.0;
  static const maximumPlausibleBpm = 240.0;
  static const minimumReliableBpmConfidence = 0.7;

  final String trackId;
  final Duration? duration;

  /// Optional metadata or analysis input; this model does not detect BPM.
  final double? bpm;

  /// Confidence supplied by the source of [bpm], not inferred by AutoMix.
  final double bpmConfidence;

  bool get hasReliableBpm =>
      bpm != null &&
      bpm!.isFinite &&
      bpm! >= minimumPlausibleBpm &&
      bpm! <= maximumPlausibleBpm &&
      bpmConfidence >= minimumReliableBpmConfidence;
}
