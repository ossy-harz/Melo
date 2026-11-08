import 'package:flutter_test/flutter_test.dart';
import 'package:tone_player/features/auto_mix/waveform_transition_cues.dart';

void main() {
  const analyzer = WaveformTransitionAnalyzer();

  test('finds sustained quiet lead-in and tail regions', () {
    final amplitudes = [
      ...List<double>.filled(12, 0.02),
      ...List<double>.filled(232, 0.65),
      ...List<double>.filled(12, 0.01),
    ];

    final cues = analyzer.analyze(
      trackId: 'track',
      duration: const Duration(seconds: 256),
      amplitudes: amplitudes,
    );

    expect(cues.quietIntroEnd, const Duration(seconds: 12));
    expect(cues.quietOutroStart, const Duration(seconds: 244));
    expect(cues.introConfidence, greaterThanOrEqualTo(0.65));
    expect(cues.outroConfidence, greaterThanOrEqualTo(0.65));
  });

  test('ignores short quiet gaps and tracks with no sustained energy', () {
    final shortGap = [0.02, ...List<double>.filled(255, 0.6)];

    final cues = analyzer.analyze(
      trackId: 'track',
      duration: const Duration(minutes: 4, seconds: 16),
      amplitudes: shortGap,
    );
    final silent = analyzer.analyze(
      trackId: 'silent',
      duration: const Duration(minutes: 4, seconds: 16),
      amplitudes: List<double>.filled(256, 0),
    );

    expect(cues.quietIntroEnd, isNull);
    expect(cues.quietOutroStart, isNull);
    expect(silent.quietIntroEnd, isNull);
    expect(silent.quietOutroStart, isNull);
    expect(cues.confidence, 0.2);
  });

  test('rejects invalid track, duration, and waveform input', () {
    expect(
      () => analyzer.analyze(
        trackId: ' ',
        duration: const Duration(minutes: 1),
        amplitudes: List<double>.filled(64, 0.5),
      ),
      throwsArgumentError,
    );
    expect(
      () => analyzer.analyze(
        trackId: 'track',
        duration: Duration.zero,
        amplitudes: List<double>.filled(64, 0.5),
      ),
      throwsArgumentError,
    );
    expect(
      () => analyzer.analyze(
        trackId: 'track',
        duration: const Duration(minutes: 1),
        amplitudes: List<double>.filled(31, 0.5),
      ),
      throwsArgumentError,
    );
    expect(
      () => analyzer.analyze(
        trackId: 'track',
        duration: const Duration(minutes: 1),
        amplitudes: [...List<double>.filled(63, 0.5), double.nan],
      ),
      throwsArgumentError,
    );
  });
}
