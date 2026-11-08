import 'package:flutter_test/flutter_test.dart';
import 'package:melo_player/features/player/audio_waveform.dart';

void main() {
  test('accepts finite normalized audio peaks', () {
    final waveform = AudioWaveformData.fromPlatform([
      ...List<double>.filled(255, 0.25),
      1.0,
    ]);

    expect(waveform.amplitudes, hasLength(256));
    expect(waveform.amplitudes.last, 1);
  });

  test('rejects missing, undersized, or oversized waveforms', () {
    expect(() => AudioWaveformData.fromPlatform(null), throwsFormatException);
    expect(
      () => AudioWaveformData.fromPlatform(List<double>.filled(31, 0.5)),
      throwsFormatException,
    );
    expect(
      () => AudioWaveformData.fromPlatform(List<double>.filled(513, 0.5)),
      throwsFormatException,
    );
  });

  test('rejects invalid amplitude values', () {
    for (final invalid in [
      [...List<double>.filled(255, 0.5), double.nan],
      [...List<double>.filled(255, 0.5), -0.1],
      [...List<double>.filled(255, 0.5), 1.1],
      [...List<Object?>.filled(255, 0.5), 'loud'],
    ]) {
      expect(
        () => AudioWaveformData.fromPlatform(invalid),
        throwsFormatException,
      );
    }
  });
}
