class AudioWaveformData {
  AudioWaveformData._(this.amplitudes);

  factory AudioWaveformData.fromPlatform(Object? value) {
    if (value is! List || value.length < 32 || value.length > 512) {
      throw const FormatException('The audio waveform has an invalid shape.');
    }
    final amplitudes = <double>[];
    for (final sample in value) {
      if (sample is! num || !sample.isFinite || sample < 0 || sample > 1) {
        throw const FormatException(
          'The audio waveform contains an invalid amplitude.',
        );
      }
      amplitudes.add(sample.toDouble());
    }
    return AudioWaveformData._(List.unmodifiable(amplitudes));
  }

  final List<double> amplitudes;
}

