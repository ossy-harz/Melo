import 'package:flutter_test/flutter_test.dart';
import 'package:tone_player/features/player/audio_profile.dart';

void main() {
  test('presets round-trip and custom bands stay inside safe limits', () {
    final profile = AudioProfile.forPreset(
      AudioEqPreset.bass,
    ).copyWith(bassDb: 2, loudnessNormalization: true);
    final decoded = AudioProfile.fromJson(profile.toJson());

    expect(decoded.preset, AudioEqPreset.bass);
    expect(decoded.bandGainsDb, profile.bandGainsDb);
    expect(decoded.bassDb, 2);
    expect(decoded.loudnessNormalization, isTrue);
    expect(decoded.withBandGain(0, 20).bandGainsDb.first, 6);
    expect(decoded.withBandGain(0, -20).bandGainsDb.first, -6);
    expect(() => decoded.withBandGain(5, 1), throwsRangeError);
  });

  test('interpolates five-band response by logarithmic frequency', () {
    final profile = AudioProfile.forPreset(AudioEqPreset.custom)
        .withBandGain(0, -4)
        .withBandGain(1, 4);

    expect(profile.gainAt(60), -4);
    expect(profile.gainAt(230), 4);
    expect(profile.gainAt(120), closeTo(0, 0.15));
  });

  test('EQ headroom and RMS leveling only attenuate output', () {
    final profile = AudioProfile.forPreset(AudioEqPreset.bass)
        .copyWith(loudnessNormalization: true, targetLoudnessDb: -16);

    expect(profile.outputHeadroom, lessThan(1));
    expect(
      profile.gainForTrack(relativeLoudnessDb: -10, peakToRmsDb: 6),
      lessThanOrEqualTo(profile.outputHeadroom),
    );
    expect(
      profile.gainForTrack(relativeLoudnessDb: -20, peakToRmsDb: 8),
      profile.outputHeadroom,
    );
    expect(
      profile.gainForTrack(
        relativeLoudnessDb: -10,
        peakToRmsDb: 6,
        applyEqHeadroom: false,
      ),
      lessThanOrEqualTo(1),
    );
    expect(
      profile.gainForTrack(relativeLoudnessDb: null, peakToRmsDb: null),
      profile.outputHeadroom,
    );
  });

  test('rejects invalid persisted values and malformed capabilities', () {
    final invalid = AudioProfile.forPreset(AudioEqPreset.flat).toJson()
      ..['preset'] = 'future';
    expect(() => AudioProfile.fromJson(invalid), throwsFormatException);
    expect(
      () => AudioOutputCapabilities.fromPlatform({'equalizer': true}),
      throwsFormatException,
    );
    expect(
      AudioOutputCapabilities.fromPlatform({
        'equalizer': false,
        'loudnessNormalization': true,
        'balance': false,
        'outputSelection': false,
        'headphoneProfiles': false,
      }).equalizer,
      isFalse,
    );
  });
}
