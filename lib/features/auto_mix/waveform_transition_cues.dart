import 'dart:math' as math;

class WaveformTransitionCues {
  const WaveformTransitionCues({
    required this.trackId,
    required this.duration,
    required this.quietIntroEnd,
    required this.quietOutroStart,
    required this.introConfidence,
    required this.outroConfidence,
  });

  final String trackId;
  final Duration duration;
  final Duration? quietIntroEnd;
  final Duration? quietOutroStart;
  final double introConfidence;
  final double outroConfidence;

  double get confidence {
    final detected = [
      if (quietIntroEnd != null) introConfidence,
      if (quietOutroStart != null) outroConfidence,
    ];
    if (detected.isEmpty) return 0.2;
    return detected.reduce(math.min);
  }
}

/// Finds sustained low-energy regions in a decoded, per-track normalized
/// waveform. These are energy cues, not musical phrase or beat detection.
class WaveformTransitionAnalyzer {
  const WaveformTransitionAnalyzer();

  static const minimumQuietDuration = Duration(seconds: 2);
  static const _quietThreshold = 0.08;
  static const _activeThreshold = 0.16;
  static const _activeRunLength = 2;

  WaveformTransitionCues analyze({
    required String trackId,
    required Duration duration,
    required List<double> amplitudes,
  }) {
    if (trackId.trim().isEmpty) {
      throw ArgumentError.value(trackId, 'trackId', 'Must not be empty.');
    }
    if (duration <= Duration.zero) {
      throw ArgumentError.value(duration, 'duration', 'Must be positive.');
    }
    if (amplitudes.length < 32 || amplitudes.length > 512) {
      throw ArgumentError.value(
        amplitudes.length,
        'amplitudes',
        'Must contain between 32 and 512 samples.',
      );
    }
    for (final amplitude in amplitudes) {
      if (!amplitude.isFinite || amplitude < 0 || amplitude > 1) {
        throw ArgumentError.value(
          amplitude,
          'amplitudes',
          'Samples must be finite values between zero and one.',
        );
      }
    }

    final binDurationUs = duration.inMicroseconds / amplitudes.length;
    final minimumQuietBins = math
        .max(2, (minimumQuietDuration.inMicroseconds / binDurationUs).ceil())
        .toInt();
    final introBoundary = _introBoundary(amplitudes, minimumQuietBins);
    final outroBoundary = _outroBoundary(amplitudes, minimumQuietBins);

    return WaveformTransitionCues(
      trackId: trackId,
      duration: duration,
      quietIntroEnd: introBoundary == null
          ? null
          : _positionAtBin(introBoundary, amplitudes.length, duration),
      quietOutroStart: outroBoundary == null
          ? null
          : _positionAtBin(outroBoundary, amplitudes.length, duration),
      introConfidence: introBoundary == null
          ? 0
          : _confidenceForQuietBins(introBoundary, minimumQuietBins),
      outroConfidence: outroBoundary == null
          ? 0
          : _confidenceForQuietBins(
              amplitudes.length - outroBoundary,
              minimumQuietBins,
            ),
    );
  }

  int? _introBoundary(List<double> amplitudes, int minimumQuietBins) {
    for (
      var index = 0;
      index <= amplitudes.length - _activeRunLength;
      index++
    ) {
      if (amplitudes[index] < _activeThreshold ||
          amplitudes[index + 1] < _activeThreshold) {
        continue;
      }

      if (index < minimumQuietBins ||
          amplitudes.take(index).any((sample) => sample > _quietThreshold)) {
        return null;
      }
      return index;
    }
    return null;
  }

  int? _outroBoundary(List<double> amplitudes, int minimumQuietBins) {
    for (
      var index = amplitudes.length - _activeRunLength;
      index >= 0;
      index--
    ) {
      if (amplitudes[index] < _activeThreshold ||
          amplitudes[index + 1] < _activeThreshold) {
        continue;
      }

      final boundary = index + _activeRunLength;
      final quietSamples = amplitudes.skip(boundary);
      if (amplitudes.length - boundary < minimumQuietBins ||
          quietSamples.any((sample) => sample > _quietThreshold)) {
        return null;
      }
      return boundary;
    }
    return null;
  }

  Duration _positionAtBin(int bin, int count, Duration duration) =>
      Duration(microseconds: (duration.inMicroseconds * bin / count).round());

  double _confidenceForQuietBins(int runLength, int minimumQuietBins) {
    final relativeLength = runLength / minimumQuietBins;
    return (0.65 + math.min(0.3, (relativeLength - 1) * 0.08))
        .clamp(0.0, 0.95)
        .toDouble();
  }
}
