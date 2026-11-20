enum HarmonicCompatibility {
  exactMatch,
  relativeKey,
  adjacentKey,
  energyBoost,
  incompatible,
  unknown,
}

class TrackAnalysis {
  TrackAnalysis({
    required this.trackId,
    this.duration,
    this.bpm,
    this.bpmConfidence = 0,
    this.musicalKey,
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

  /// Optional musical key signature (e.g. "Am", "8A", "C major", "11B").
  final String? musicalKey;

  /// Normalized Camelot Wheel code (e.g. "8A", "8B"), or null if unavailable.
  String? get camelotCode => normalizeCamelot(musicalKey);

  /// Always available Camelot code, inferring deterministically from [trackId] if unknown.
  String get effectiveCamelotCode =>
      camelotCode ?? inferKey(trackId);

  static const List<String> camelotKeys = [
    '1A', '1B', '2A', '2B', '3A', '3B', '4A', '4B',
    '5A', '5B', '6A', '6B', '7A', '7B', '8A', '8B',
    '9A', '9B', '10A', '10B', '11A', '11B', '12A', '12B',
  ];

  static String inferKey(String seed) {
    if (seed.isEmpty) return '8A';
    final hash = seed.hashCode.abs();
    return camelotKeys[hash % camelotKeys.length];
  }

  bool get hasReliableBpm =>
      bpm != null &&
      bpm!.isFinite &&
      bpm! >= minimumPlausibleBpm &&
      bpm! <= maximumPlausibleBpm &&
      bpmConfidence >= minimumReliableBpmConfidence;

  static final Map<String, String> _standardKeyToCamelot = {
    // Minor keys (A)
    'abm': '1A', 'g#m': '1A', 'ab minor': '1A', 'g# minor': '1A',
    'ebm': '2A', 'd#m': '2A', 'eb minor': '2A', 'd# minor': '2A',
    'bbm': '3A', 'a#m': '3A', 'bb minor': '3A', 'a# minor': '3A',
    'fm': '4A', 'f minor': '4A',
    'cm': '5A', 'c minor': '5A',
    'gm': '6A', 'g minor': '6A',
    'dm': '7A', 'd minor': '7A',
    'am': '8A', 'a minor': '8A',
    'em': '9A', 'e minor': '9A',
    'bm': '10A', 'b minor': '10A',
    'f#m': '11A', 'gbm': '11A', 'f# minor': '11A', 'gb minor': '11A',
    'c#m': '12A', 'dbm': '12A', 'c# minor': '12A', 'db minor': '12A',

    // Major keys (B)
    'b': '1B', 'b major': '1B', 'cb': '1B',
    'f#': '2B', 'gb': '2B', 'f# major': '2B', 'gb major': '2B',
    'db': '3B', 'c#': '3B', 'db major': '3B', 'c# major': '3B',
    'ab': '4B', 'g#': '4B', 'ab major': '4B', 'g# major': '4B',
    'eb': '5B', 'd#': '5B', 'eb major': '5B', 'd# major': '5B',
    'bb': '6B', 'a#': '6B', 'bb major': '6B', 'a# major': '6B',
    'f': '7B', 'f major': '7B',
    'c': '8B', 'c major': '8B',
    'g': '9B', 'g major': '9B',
    'd': '10B', 'd major': '10B',
    'a': '11B', 'a major': '11B',
    'e': '12B', 'e major': '12B',
  };

  static String? normalizeCamelot(String? rawKey) {
    if (rawKey == null) return null;
    final trimmed = rawKey.trim().toLowerCase();
    if (trimmed.isEmpty) return null;

    final camelotMatch = RegExp(r'^([1-9]|1[0-2])([ab])$').firstMatch(trimmed);
    if (camelotMatch != null) {
      final num = camelotMatch.group(1);
      final letter = camelotMatch.group(2)!.toUpperCase();
      return '$num$letter';
    }

    return _standardKeyToCamelot[trimmed];
  }

  static HarmonicCompatibility assessHarmonic(String? key1, String? key2) {
    if (key1 == null || key2 == null) return HarmonicCompatibility.unknown;
    final c1 = normalizeCamelot(key1);
    final c2 = normalizeCamelot(key2);
    if (c1 == null || c2 == null) return HarmonicCompatibility.unknown;

    final num1 = int.tryParse(c1.substring(0, c1.length - 1));
    final letter1 = c1[c1.length - 1].toUpperCase();
    final num2 = int.tryParse(c2.substring(0, c2.length - 1));
    final letter2 = c2[c2.length - 1].toUpperCase();

    if (num1 == null || num2 == null) return HarmonicCompatibility.unknown;

    if (num1 == num2 && letter1 == letter2) {
      return HarmonicCompatibility.exactMatch;
    }
    if (num1 == num2 && letter1 != letter2) {
      return HarmonicCompatibility.relativeKey;
    }
    if (letter1 == letter2) {
      final diff = (num1 - num2).abs();
      if (diff == 1 || diff == 11) {
        return HarmonicCompatibility.adjacentKey;
      }
      final forwardDiff = (num2 - num1) % 12;
      if (forwardDiff == 2 || forwardDiff == -10) {
        return HarmonicCompatibility.energyBoost;
      }
    }
    return HarmonicCompatibility.incompatible;
  }
}
