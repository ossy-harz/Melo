import 'dart:math' as math;

enum AudioEqPreset { flat, balanced, bass, vocal, custom }

class AudioProfile {
  const AudioProfile({
    this.preset = AudioEqPreset.flat,
    this.bandGainsDb = const [0, 0, 0, 0, 0],
    this.bassDb = 0,
    this.loudnessNormalization = false,
    this.targetLoudnessDb = -16,
    this.vocalAttenuationDb = 0,
  });

  static const bandCentersHz = [60.0, 230.0, 910.0, 3600.0, 14000.0];
  static const minimumGainDb = -6.0;
  static const maximumGainDb = 6.0;

  final AudioEqPreset preset;
  final List<double> bandGainsDb;
  final double bassDb;
  final bool loudnessNormalization;
  final double targetLoudnessDb;
  final double vocalAttenuationDb;

  bool get isKaraokeMode => vocalAttenuationDb <= -6.0;
  bool get isVocalBoostMode => vocalAttenuationDb >= 2.0;

  static AudioProfile forPreset(AudioEqPreset preset) {
    final gains = switch (preset) {
      AudioEqPreset.flat => const [0.0, 0.0, 0.0, 0.0, 0.0],
      AudioEqPreset.balanced => const [1.0, 0.5, 0.0, 0.5, 1.0],
      AudioEqPreset.bass => const [4.0, 3.0, 0.0, -0.5, -1.0],
      AudioEqPreset.vocal => const [-1.0, 0.0, 2.0, 2.0, 0.5],
      AudioEqPreset.custom => const [0.0, 0.0, 0.0, 0.0, 0.0],
    };
    return AudioProfile(preset: preset, bandGainsDb: gains);
  }

  AudioProfile copyWith({
    AudioEqPreset? preset,
    List<double>? bandGainsDb,
    double? bassDb,
    bool? loudnessNormalization,
    double? targetLoudnessDb,
    double? vocalAttenuationDb,
  }) => AudioProfile(
    preset: preset ?? this.preset,
    bandGainsDb: List.unmodifiable(bandGainsDb ?? this.bandGainsDb),
    bassDb: bassDb ?? this.bassDb,
    loudnessNormalization: loudnessNormalization ?? this.loudnessNormalization,
    targetLoudnessDb: targetLoudnessDb ?? this.targetLoudnessDb,
    vocalAttenuationDb: vocalAttenuationDb ?? this.vocalAttenuationDb,
  );

  AudioProfile withVocalAttenuation(double attenuationDb) => copyWith(
    vocalAttenuationDb: attenuationDb.clamp(-12.0, 4.0).toDouble(),
  );

  AudioProfile withBandGain(int index, double gainDb) {
    if (index < 0 || index >= bandGainsDb.length) {
      throw RangeError.index(index, bandGainsDb, 'index');
    }
    final gains = [...bandGainsDb];
    gains[index] = _clampGain(gainDb);
    return copyWith(preset: AudioEqPreset.custom, bandGainsDb: gains);
  }

  double gainAt(double frequencyHz) {
    final bounded = frequencyHz
        .clamp(bandCentersHz.first, bandCentersHz.last)
        .toDouble();
    final bassShelf = bounded <= bandCentersHz[1] ? bassDb : 0.0;
    final vocalEffect = (bounded >= 300.0 && bounded <= 3500.0)
        ? vocalAttenuationDb
        : 0.0;
    for (var index = 0; index < bandCentersHz.length - 1; index++) {
      final low = bandCentersHz[index];
      final high = bandCentersHz[index + 1];
      if (bounded > high) continue;
      final progress =
          (math.log(bounded) - math.log(low)) /
          (math.log(high) - math.log(low));
      final gain =
          bandGainsDb[index] +
          (bandGainsDb[index + 1] - bandGainsDb[index]) * progress;
      return gain + bassShelf + vocalEffect;
    }
    return bandGainsDb.last + vocalEffect;
  }

  double get outputHeadroom {
    var largestBoost = 0.0;
    for (var index = 0; index < bandCentersHz.length; index++) {
      largestBoost = math.max(
        largestBoost,
        bandGainsDb[index] + (index < 2 ? bassDb : 0),
      );
    }
    if (largestBoost <= 0) return 1;
    return math.pow(10, -largestBoost / 20).toDouble();
  }

  double gainForTrack({
    required double? relativeLoudnessDb,
    required double? peakToRmsDb,
    bool applyEqHeadroom = true,
  }) {
    var gain = applyEqHeadroom ? outputHeadroom : 1.0;
    if (!loudnessNormalization || relativeLoudnessDb == null) return gain;
    final levelGain = math
        .pow(10, (targetLoudnessDb - relativeLoudnessDb) / 20)
        .toDouble();
    gain = math.min(gain, levelGain);
    if (peakToRmsDb != null) {
      final estimatedPeakDb = relativeLoudnessDb + peakToRmsDb;
      final peakCeilingGain = math
          .pow(10, (-1 - estimatedPeakDb) / 20)
          .toDouble();
      gain = math.min(gain, peakCeilingGain);
    }
    if (!gain.isFinite || gain <= 0.0) return 1.0;
    return gain.clamp(0.0, 1.0).toDouble();
  }

  Map<String, Object?> toJson() => {
    'preset': preset.name,
    'bandGainsDb': bandGainsDb,
    'bassDb': bassDb,
    'loudnessNormalization': loudnessNormalization,
    'targetLoudnessDb': targetLoudnessDb,
    if (vocalAttenuationDb != 0) 'vocalAttenuationDb': vocalAttenuationDb,
  };

  factory AudioProfile.fromJson(Map<String, Object?> json) {
    final presetValue = json['preset'];
    final gainsValue = json['bandGainsDb'];
    final bass = json['bassDb'];
    final normalize = json['loudnessNormalization'];
    final target = json['targetLoudnessDb'];
    final vocalAtten = (json['vocalAttenuationDb'] as num?)?.toDouble() ?? 0.0;
    final presets = AudioEqPreset.values.where(
      (value) => value.name == presetValue,
    );
    if (presets.isEmpty ||
        gainsValue is! List ||
        gainsValue.length != bandCentersHz.length ||
        gainsValue.any((value) => value is! num || !value.isFinite) ||
        bass is! num ||
        !bass.isFinite ||
        normalize is! bool ||
        target is! num ||
        !target.isFinite ||
        !vocalAtten.isFinite) {
      throw const FormatException('Stored audio profile is invalid.');
    }
    final gains = gainsValue.map((value) => (value as num).toDouble()).toList();
    if (gains.any((value) => value < minimumGainDb || value > maximumGainDb) ||
        bass < minimumGainDb ||
        bass > maximumGainDb ||
        target < -24 ||
        target > -10 ||
        vocalAtten < -12.0 ||
        vocalAtten > 6.0) {
      throw const FormatException('Stored audio profile is out of range.');
    }
    return AudioProfile(
      preset: presets.first,
      bandGainsDb: List.unmodifiable(gains),
      bassDb: bass.toDouble(),
      loudnessNormalization: normalize,
      targetLoudnessDb: target.toDouble(),
      vocalAttenuationDb: vocalAtten,
    );
  }

  static double _clampGain(double value) =>
      value.clamp(minimumGainDb, maximumGainDb).toDouble();
}

class AudioOutputCapabilities {
  const AudioOutputCapabilities({
    required this.equalizer,
    required this.loudnessNormalization,
    required this.balance,
    required this.outputSelection,
    required this.headphoneProfiles,
  });

  final bool equalizer;
  final bool loudnessNormalization;
  final bool balance;
  final bool outputSelection;
  final bool headphoneProfiles;

  factory AudioOutputCapabilities.fromPlatform(Object? value) {
    if (value is! Map) {
      throw const FormatException('Audio output capabilities are missing.');
    }
    bool read(String key) {
      final result = value[key];
      if (result is! bool) {
        throw FormatException('Audio output capability "$key" is invalid.');
      }
      return result;
    }

    return AudioOutputCapabilities(
      equalizer: read('equalizer'),
      loudnessNormalization: read('loudnessNormalization'),
      balance: read('balance'),
      outputSelection: read('outputSelection'),
      headphoneProfiles: read('headphoneProfiles'),
    );
  }
}
