enum TransitionStyle { equalPower, gradualAtmospheric, quickBlend }

enum AutoMixProfile {
  atmospheric,
  balanced,
  energetic;

  Duration get defaultTransitionDuration => switch (this) {
    AutoMixProfile.atmospheric => const Duration(seconds: 20),
    AutoMixProfile.balanced => const Duration(seconds: 10),
    AutoMixProfile.energetic => const Duration(seconds: 4),
  };

  TransitionStyle get preferredTransitionStyle => switch (this) {
    AutoMixProfile.atmospheric => TransitionStyle.gradualAtmospheric,
    AutoMixProfile.balanced => TransitionStyle.equalPower,
    AutoMixProfile.energetic => TransitionStyle.quickBlend,
  };
}
