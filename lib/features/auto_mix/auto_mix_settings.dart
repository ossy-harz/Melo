import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:tone_player/features/auto_mix/auto_mix_profile.dart';

/// Persisted user preferences for AutoMix.
///
/// Settings are loaded lazily from `SharedPreferences` and written back on
/// change. The in-memory controller settings are updated separately through
/// `ToneAudioHandler`.
class AutoMixSettings {
  AutoMixSettings({
    this.profile = AutoMixProfile.balanced,
    this.transitionDuration,
    this.automaticTransitions = true,
  }) {
    if (transitionDuration != null &&
        (transitionDuration! < minimumTransitionDuration ||
            transitionDuration! > maximumTransitionDuration)) {
      throw RangeError.range(
        transitionDuration!.inMilliseconds,
        minimumTransitionDuration.inMilliseconds,
        maximumTransitionDuration.inMilliseconds,
        'transitionDuration',
      );
    }
  }

  static const String _prefsKey = 'tone_auto_mix_settings.v1';
  static const String _profileKey = 'profile';
  static const String _durationKey = 'transitionDurationMs';
  static const String _automaticKey = 'automaticTransitions';

  static const minimumTransitionDuration = Duration(seconds: 3);
  static const maximumTransitionDuration = Duration(seconds: 30);
  static const diagnosticTransitionDurations = [
    Duration(seconds: 3),
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 15),
    Duration(seconds: 20),
    Duration(seconds: 30),
  ];

  final AutoMixProfile profile;
  final Duration? transitionDuration;
  final bool automaticTransitions;

  Duration get effectiveTransitionDuration =>
      transitionDuration ?? profile.defaultTransitionDuration;

  /// Load persisted settings, returning defaults when nothing is saved.
  static Future<AutoMixSettings> load() async {
    final preferences = await SharedPreferences.getInstance();
    final json = preferences.getString(_prefsKey);
    if (json == null) return AutoMixSettings();

    final decoded = jsonDecode(json);
    if (decoded is! Map) {
      return AutoMixSettings();
    }
    final map = Map<String, Object?>.from(decoded);

    AutoMixProfile profile;
    try {
      profile = AutoMixProfile.values.firstWhere(
        (p) => p.name == map[_profileKey],
        orElse: () => AutoMixProfile.balanced,
      );
    } on Object {
      profile = AutoMixProfile.balanced;
    }

    Duration? transitionDuration;
    final durationMs = map[_durationKey];
    if (durationMs is int && durationMs > 0) {
      final candidate = Duration(milliseconds: durationMs);
      if (candidate >= minimumTransitionDuration &&
          candidate <= maximumTransitionDuration) {
        transitionDuration = candidate;
      }
    }

    final automatic =
        map[_automaticKey] is bool ? map[_automaticKey]! as bool : true;

    return AutoMixSettings(
      profile: profile,
      transitionDuration: transitionDuration,
      automaticTransitions: automatic,
    );
  }

  /// Persist these settings to `SharedPreferences`.
  Future<void> save() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = jsonEncode(<String, Object?>{
      _profileKey: profile.name,
      if (transitionDuration != null)
        _durationKey: transitionDuration!.inMilliseconds,
      _automaticKey: automaticTransitions,
    });
    await preferences.setString(_prefsKey, encoded);
  }

  AutoMixSettings copyWith({
    AutoMixProfile? profile,
    Duration? transitionDuration,
    bool? automaticTransitions,
  }) {
    return AutoMixSettings(
      profile: profile ?? this.profile,
      transitionDuration: transitionDuration ?? this.transitionDuration,
      automaticTransitions:
          automaticTransitions ?? this.automaticTransitions,
    );
  }

  @override
  String toString() {
    return 'AutoMixSettings(profile: $profile, '
        'transitionDuration: $transitionDuration, '
        'automaticTransitions: $automaticTransitions)';
  }
}
