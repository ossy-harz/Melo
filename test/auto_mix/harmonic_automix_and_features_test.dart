import 'package:flutter_test/flutter_test.dart';
import 'package:melo_player/features/auto_mix/auto_mix_profile.dart';
import 'package:melo_player/features/auto_mix/auto_mix_settings.dart';
import 'package:melo_player/features/auto_mix/track_analysis.dart';
import 'package:melo_player/features/auto_mix/transition_plan.dart';
import 'package:melo_player/features/auto_mix/transition_planner.dart';
import 'package:melo_player/features/player/audio_profile.dart';

void main() {
  group('Harmonic AutoMix 2.0 & Camelot Wheel', () {
    test('normalizes standard pitch notation to Camelot codes', () {
      expect(TrackAnalysis.normalizeCamelot('Am'), '8A');
      expect(TrackAnalysis.normalizeCamelot('a minor'), '8A');
      expect(TrackAnalysis.normalizeCamelot('C'), '8B');
      expect(TrackAnalysis.normalizeCamelot('C major'), '8B');
      expect(TrackAnalysis.normalizeCamelot('F#m'), '11A');
      expect(TrackAnalysis.normalizeCamelot('gb minor'), '11A');
      expect(TrackAnalysis.normalizeCamelot('8A'), '8A');
      expect(TrackAnalysis.normalizeCamelot('12B'), '12B');
    });

    test('assesses exact match harmonic compatibility', () {
      final compat = TrackAnalysis.assessHarmonic('8A', '8A');
      expect(compat, HarmonicCompatibility.exactMatch);

      final pitchCompat = TrackAnalysis.assessHarmonic('Am', 'a minor');
      expect(pitchCompat, HarmonicCompatibility.exactMatch);
    });

    test('assesses relative major/minor harmonic lift', () {
      // 8A (A minor) and 8B (C major) share the same key signature
      final compat = TrackAnalysis.assessHarmonic('8A', '8B');
      expect(compat, HarmonicCompatibility.relativeKey);
    });

    test('assesses adjacent key harmonic cadence (±1 step)', () {
      expect(TrackAnalysis.assessHarmonic('8A', '7A'), HarmonicCompatibility.adjacentKey);
      expect(TrackAnalysis.assessHarmonic('8A', '9A'), HarmonicCompatibility.adjacentKey);
      // Wraparound 12A <-> 1A
      expect(TrackAnalysis.assessHarmonic('12A', '1A'), HarmonicCompatibility.adjacentKey);
      expect(TrackAnalysis.assessHarmonic('1A', '12A'), HarmonicCompatibility.adjacentKey);
    });

    test('assesses energy boost (+2 steps clockwise)', () {
      expect(TrackAnalysis.assessHarmonic('8A', '10A'), HarmonicCompatibility.energyBoost);
    });

    test('assesses incompatible keys correctly', () {
      expect(TrackAnalysis.assessHarmonic('8A', '3B'), HarmonicCompatibility.incompatible);
    });

    test('deterministic key inference provides stable Camelot code for unknown tracks', () {
      final analysis1 = TrackAnalysis(trackId: 'track_alpha');
      final analysis2 = TrackAnalysis(trackId: 'track_alpha');
      expect(analysis1.effectiveCamelotCode, analysis2.effectiveCamelotCode);
      expect(TrackAnalysis.camelotKeys.contains(analysis1.effectiveCamelotCode), isTrue);
    });

    test('diagnostic badge text reflects Camelot harmonic transitions', () {
      final planner = const TransitionPlanner();
      final plan = planner.plan(
        outgoing: TrackAnalysis(
          trackId: 'song1',
          musicalKey: '8A',
        ),
        incoming: TrackAnalysis(
          trackId: 'song2',
          musicalKey: '9A',
        ),
        settings: AutoMixSettings(),
      );

      expect(plan.diagnosticBadgeText, 'Harmonic Flow (8A → 9A)');
    });

    test('planner automatically evaluates harmonic relationship between tracks', () {
      final planner = const TransitionPlanner();
      final plan = planner.plan(
        outgoing: TrackAnalysis(
          trackId: 'track_a',
          bpm: 124,
          bpmConfidence: 0.9,
          musicalKey: '8A',
        ),
        incoming: TrackAnalysis(
          trackId: 'track_b',
          bpm: 124,
          bpmConfidence: 0.9,
          musicalKey: '8B',
        ),
        settings: AutoMixSettings(),
      );

      expect(plan.harmonicCompatibility, HarmonicCompatibility.relativeKey);
      expect(plan.diagnosticBadgeText, 'Harmonic Lift (8A → 8B)');
    });
  });

  group('AudioProfile Vocal Control & Karaoke DSP', () {
    test('default profile has zero vocal attenuation', () {
      const profile = AudioProfile();
      expect(profile.vocalAttenuationDb, 0.0);
      expect(profile.isKaraokeMode, isFalse);
      expect(profile.isVocalBoostMode, isFalse);
    });

    test('withVocalAttenuation applies karaoke attenuation and vocal boost', () {
      const profile = AudioProfile();
      final karaoke = profile.withVocalAttenuation(-12.0);
      expect(karaoke.vocalAttenuationDb, -12.0);
      expect(karaoke.isKaraokeMode, isTrue);
      expect(karaoke.isVocalBoostMode, isFalse);

      final boost = profile.withVocalAttenuation(3.0);
      expect(boost.vocalAttenuationDb, 3.0);
      expect(boost.isKaraokeMode, isFalse);
      expect(boost.isVocalBoostMode, isTrue);
    });

    test('gainAt modifies vocal band (300 Hz - 3500 Hz)', () {
      const profile = AudioProfile();
      final karaoke = profile.withVocalAttenuation(-12.0);

      // Outside vocal range (e.g. 60 Hz bass) -> unchanged
      expect(karaoke.gainAt(60), profile.gainAt(60));

      // Inside vocal range (e.g. 1000 Hz midrange) -> attenuated by 12 dB
      expect(karaoke.gainAt(1000), profile.gainAt(1000) - 12.0);
    });

    test('serialization roundtrip preserves vocal attenuation', () {
      const original = AudioProfile(vocalAttenuationDb: -10.0);
      final json = original.toJson();
      final restored = AudioProfile.fromJson(json);

      expect(restored.vocalAttenuationDb, -10.0);
      expect(restored.isKaraokeMode, isTrue);
    });
  });
}
