import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MeloThemePalette {
  cherry,
  cyberpunk,
  emerald,
  amber,
  titanium;

  String get displayName => switch (this) {
    MeloThemePalette.cherry => 'Obsidian Cherry',
    MeloThemePalette.cyberpunk => 'Neon Cyberpunk',
    MeloThemePalette.emerald => 'Tokyo Emerald',
    MeloThemePalette.amber => 'Sunset Amber',
    MeloThemePalette.titanium => 'Obsidian Titanium',
  };

  String get subtitle => switch (this) {
    MeloThemePalette.cherry => 'Signature deep crimson red on true pitch black',
    MeloThemePalette.cyberpunk => 'Vibrant electric violet & neon cyan accents',
    MeloThemePalette.emerald => 'Nordic emerald & fresh jade studio tone',
    MeloThemePalette.amber => 'Warm analog vinyl amber & sunset gold',
    MeloThemePalette.titanium => 'Pure minimalist monochrome silver & white',
  };

  Color get primaryColor => switch (this) {
    MeloThemePalette.cherry => const Color(0xFFFA243C),
    MeloThemePalette.cyberpunk => const Color(0xFFA855F7),
    MeloThemePalette.emerald => const Color(0xFF10B981),
    MeloThemePalette.amber => const Color(0xFFF59E0B),
    MeloThemePalette.titanium => const Color(0xFFE2E8F0),
  };

  Color get secondaryColor => switch (this) {
    MeloThemePalette.cherry => const Color(0xFFFF5368),
    MeloThemePalette.cyberpunk => const Color(0xFF06B6D4),
    MeloThemePalette.emerald => const Color(0xFF34D399),
    MeloThemePalette.amber => const Color(0xFFEA580C),
    MeloThemePalette.titanium => const Color(0xFF94A3B8),
  };

  List<Color> get gradient => switch (this) {
    MeloThemePalette.cherry => const [Color(0xFF351618), Color(0xFF76251F), Color(0xFFFF4B3E)],
    MeloThemePalette.cyberpunk => const [Color(0xFF2A103D), Color(0xFF6B21A8), Color(0xFFA855F7)],
    MeloThemePalette.emerald => const [Color(0xFF0A2E20), Color(0xFF047857), Color(0xFF10B981)],
    MeloThemePalette.amber => const [Color(0xFF3D2507), Color(0xFFB45309), Color(0xFFF59E0B)],
    MeloThemePalette.titanium => const [Color(0xFF18181B), Color(0xFF3F3F46), Color(0xFF71717A)],
  };
}

class MeloThemeSettings {
  const MeloThemeSettings({
    this.palette = MeloThemePalette.cherry,
    this.amoledPitchBlack = true,
    this.dynamicAlbumReactive = true,
  });

  final MeloThemePalette palette;
  final bool amoledPitchBlack;
  final bool dynamicAlbumReactive;

  MeloThemeSettings copyWith({
    MeloThemePalette? palette,
    bool? amoledPitchBlack,
    bool? dynamicAlbumReactive,
  }) => MeloThemeSettings(
    palette: palette ?? this.palette,
    amoledPitchBlack: amoledPitchBlack ?? this.amoledPitchBlack,
    dynamicAlbumReactive: dynamicAlbumReactive ?? this.dynamicAlbumReactive,
  );
}

class MeloThemeService extends ValueNotifier<MeloThemeSettings> {
  MeloThemeService._() : super(const MeloThemeSettings());
  static final MeloThemeService instance = MeloThemeService._();

  static const _paletteKey = 'tone_theme_palette_v2';
  static const _amoledKey = 'tone_theme_amoled_v2';
  static const _dynamicKey = 'tone_theme_dynamic_v2';
  bool _hasLoaded = false;

  Future<void> load() async {
    if (_hasLoaded) return;
    _hasLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final pName = prefs.getString(_paletteKey);
      final amoled = prefs.getBool(_amoledKey) ?? true;
      final dynamicReactive = prefs.getBool(_dynamicKey) ?? true;

      final matchedPalette = MeloThemePalette.values.where((p) => p.name == pName).firstOrNull ?? MeloThemePalette.cherry;
      value = MeloThemeSettings(
        palette: matchedPalette,
        amoledPitchBlack: amoled,
        dynamicAlbumReactive: dynamicReactive,
      );
    } catch (_) {}
  }

  Future<void> setPalette(MeloThemePalette palette) async {
    if (value.palette == palette) return;
    value = value.copyWith(palette: palette);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_paletteKey, palette.name);
  }

  Future<void> setAmoledPitchBlack(bool enabled) async {
    if (value.amoledPitchBlack == enabled) return;
    value = value.copyWith(amoledPitchBlack: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_amoledKey, enabled);
  }

  Future<void> setDynamicAlbumReactive(bool enabled) async {
    if (value.dynamicAlbumReactive == enabled) return;
    value = value.copyWith(dynamicAlbumReactive: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dynamicKey, enabled);
  }
}

/// Tone's palette: cherry red on a deep, warm ink. The app shell stays dark
/// so the product always feels like the same place, while light mode offers a
/// warm cherry-tinted paper alternative.
abstract final class MeloColors {
  // Light theme ink and paper.
  static const ink = Color(0xFF1A1114);
  static const mutedInk = Color(0xFF6F5F66);
  static const paper = Color(0xFFFAF6F7);
  static const card = Color(0xFFFFFFFF);
  static const line = Color(0xFFECDDE2);

  // Cherry identity.
  static const plum = Color(0xFFFA243C);
  static const ember = Color(0xFFFA243C);
  static const cherry = Color(0xFFFA243C);
  static const cherrySoft = Color(0xFFFF8997);
  static const cherryDeep = Color(0xFF5E0A19);
  static const cherryGlow = Color(0xFFFF5368);

  // Player surfaces. The Now Playing shell is intentionally near-black so
  // artwork and colour do the talking.
  static const amoled = Color(0xFF000000);
  static const playerBackdrop = Color(0xFF000000);
  static const playerText = Color(0xFFFFFFFF);
  static const playerMuted = Color(0xFFA1A1A6);

  // Glass materials.
  static const glassTint = Color(0x14FFFFFF);
  static const glassBorder = Color(0x2EFFFFFF);
  static const glassShadow = Color(0xA6000000);

  // App shell surfaces (dark).
  static const shell = Color(0xFF000000);
  static const shellRaised = Color(0xFF111111);

  // Apple Music HDR dark & specular tokens (Red, Black, White only).
  static const hdrSpecular = Color(0x38FFFFFF);
  static const qledSurface = Color(0xFF080808);
  static const qledCard = Color(0xFF121214);
  static const qledElevated = Color(0xFF1C1C1E);
}

/// Corner radii used across the product so surfaces stay consistent.
abstract final class MeloRadii {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 22.0;
  static const xl = 28.0;
  static const pill = 999.0;
}

/// Motion tokens: durations and curves for a calm, premium feel.
abstract final class MeloMotion {
  static const fast = Duration(milliseconds: 180);
  static const slow = Duration(milliseconds: 520);

  static const emphasized = Cubic(0.2, 0.9, 0.2, 1);

  /// True when the platform asks for reduced motion, so decorative movement
  /// can stand down instead of playing against the user's setting.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  /// Collapses [duration] to zero while reduced motion is on, so a surface
  /// still changes state but never animates into it.
  static Duration respecting(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;
}

/// Reusable shadow recipes. Dark surfaces lean on glow, light surfaces on a
/// soft, wide drop shadow.
abstract final class MeloShadows {
  static List<BoxShadow> soft(Color color, {double opacity = 0.16}) => [
    BoxShadow(
      color: color.withValues(alpha: opacity),
      blurRadius: 34,
      spreadRadius: -10,
      offset: const Offset(0, 16),
    ),
  ];

  static List<BoxShadow> glow(Color color, {double opacity = 0.34}) => [
    BoxShadow(
      color: color.withValues(alpha: opacity),
      blurRadius: 46,
      spreadRadius: -10,
      offset: const Offset(0, 20),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.5),
      blurRadius: 34,
      offset: const Offset(0, 20),
    ),
  ];

  static List<BoxShadow> hdrBloom(
    Color primary, {
    Color? secondary,
    double opacity = 0.38,
  }) => [
    BoxShadow(
      color: primary.withValues(alpha: opacity),
      blurRadius: 36,
      spreadRadius: -8,
      offset: const Offset(0, 14),
    ),
    BoxShadow(
      color: (secondary ?? MeloColors.cherryDeep).withValues(
        alpha: opacity * 0.55,
      ),
      blurRadius: 48,
      spreadRadius: -12,
      offset: const Offset(0, 20),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.65),
      blurRadius: 28,
      offset: const Offset(0, 16),
    ),
  ];
}

/// Tone's type scale: a single, characterful family (Plus Jakarta Sans) with
/// discipline in weight and tracking instead of shouting on every heading.
abstract final class MeloTypography {
  static const fontFamily = 'Plus Jakarta Sans';

  static TextTheme textTheme(Color onSurface, Color onSurfaceVariant) {
    TextStyle c({
      required double size,
      required FontWeight weight,
      double spacing = 0,
      double height = 1.25,
      Color? color,
    }) => TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: spacing,
      height: height,
      color: color ?? onSurface,
    );

    return TextTheme(
      displayLarge: c(size: 56, weight: FontWeight.w800, spacing: -1.8),
      displayMedium: c(size: 44, weight: FontWeight.w800, spacing: -1.4),
      displaySmall: c(size: 35, weight: FontWeight.w800, spacing: -1.1),
      headlineLarge: c(size: 31, weight: FontWeight.w800, spacing: -0.9),
      headlineMedium: c(size: 26, weight: FontWeight.w800, spacing: -0.7),
      headlineSmall: c(size: 22, weight: FontWeight.w700, spacing: -0.4),
      titleLarge: c(size: 19.5, weight: FontWeight.w700, spacing: -0.3),
      titleMedium: c(size: 16.5, weight: FontWeight.w600, spacing: -0.1),
      titleSmall: c(size: 14.5, weight: FontWeight.w600),
      bodyLarge: c(size: 15.5, weight: FontWeight.w500, height: 1.45),
      bodyMedium: c(
        size: 14,
        weight: FontWeight.w500,
        height: 1.45,
        color: onSurfaceVariant,
      ),
      bodySmall: c(
        size: 12.5,
        weight: FontWeight.w500,
        height: 1.4,
        color: onSurfaceVariant,
      ),
      labelLarge: c(size: 14, weight: FontWeight.w700, spacing: 0.1),
      labelMedium: c(size: 12, weight: FontWeight.w700, spacing: 0.7),
      labelSmall: c(size: 11, weight: FontWeight.w600, spacing: 0.5),
    );
  }
}

/// A calm, premium page transition: fade with a gentle rise and settle.
class MeloPageTransitionsBuilder extends PageTransitionsBuilder {
  const MeloPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MeloMotion.reduced(context)) return child;
    final curved = CurvedAnimation(
      parent: animation,
      curve: MeloMotion.emphasized,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.035),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

abstract final class MeloTheme {
  static ThemeData get light => themeFor(Brightness.light, MeloThemeService.instance.value);
  static ThemeData get dark => themeFor(Brightness.dark, MeloThemeService.instance.value);

  static ThemeData themeFor(Brightness brightness, [MeloThemeSettings? settings]) {
    final effectiveSettings = settings ?? MeloThemeService.instance.value;
    final isLight = brightness == Brightness.light;
    final primary = effectiveSettings.palette.primaryColor;
    final secondary = effectiveSettings.palette.secondaryColor;
    final surface = isLight
        ? MeloColors.paper
        : (effectiveSettings.amoledPitchBlack ? const Color(0xFF000000) : const Color(0xFF0D0D11));

    final scheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: brightness,
        ).copyWith(
          primary: primary,
          onPrimary: isLight ? Colors.white : const Color(0xFF2A0008),
          primaryContainer: isLight
              ? primary.withValues(alpha: 0.16)
              : primary.withValues(alpha: 0.28),
          onPrimaryContainer: isLight
              ? const Color(0xFF5A0A1B)
              : Colors.white,
          secondary: secondary,
          onSecondary: Colors.white,
          secondaryContainer: isLight
              ? secondary.withValues(alpha: 0.14)
              : secondary.withValues(alpha: 0.22),
          surface: surface,
          onSurface: isLight ? MeloColors.ink : MeloColors.playerText,
          onSurfaceVariant: isLight
              ? MeloColors.mutedInk
              : MeloColors.playerMuted,
          surfaceContainerLowest: isLight
              ? MeloColors.card
              : (effectiveSettings.amoledPitchBlack ? const Color(0xFF000000) : const Color(0xFF08080A)),
          surfaceContainerLow: isLight
              ? const Color(0xFFF6EDF0)
              : (effectiveSettings.amoledPitchBlack ? const Color(0xFF0D0D0D) : const Color(0xFF111114)),
          surfaceContainer: isLight
              ? const Color(0xFFF1E6EA)
              : (effectiveSettings.amoledPitchBlack ? const Color(0xFF141414) : const Color(0xFF18181D)),
          surfaceContainerHigh: isLight
              ? const Color(0xFFEADCE1)
              : (effectiveSettings.amoledPitchBlack ? const Color(0xFF1E1E1E) : const Color(0xFF222228)),
          surfaceContainerHighest: isLight
              ? const Color(0xFFE3D3D8)
              : (effectiveSettings.amoledPitchBlack ? const Color(0xFF282828) : const Color(0xFF2B2B33)),
          outline: isLight ? const Color(0xFFC9B2B9) : const Color(0xFF5A5A5A),
          outlineVariant: isLight ? MeloColors.line : const Color(0xFF2D2D2D),
          shadow: Colors.black,
          scrim: Colors.black,
          inverseSurface: isLight
              ? const Color(0xFF2A1A1F)
              : const Color(0xFFFBF3F5),
          onInverseSurface: isLight
              ? const Color(0xFFFAF6F7)
              : const Color(0xFF1A1114),
        );

    final textTheme = MeloTypography.textTheme(
      scheme.onSurface,
      scheme.onSurfaceVariant,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: MeloTypography.fontFamily,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MeloRadii.xl),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: isLight ? 1 : 0.7),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: isLight ? scheme.surface : const Color(0xFF0A0608),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: scheme.primary.withValues(alpha: isLight ? 0.14 : 0.22),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: MeloTypography.fontFamily,
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: 0.1,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: MeloPageTransitionsBuilder(),
          TargetPlatform.iOS: MeloPageTransitionsBuilder(),
          TargetPlatform.macOS: MeloPageTransitionsBuilder(),
          TargetPlatform.windows: MeloPageTransitionsBuilder(),
          TargetPlatform.linux: MeloPageTransitionsBuilder(),
        },
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        hintStyle: textTheme.bodyMedium,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MeloRadii.lg),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MeloRadii.lg),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MeloRadii.lg),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MeloRadii.lg),
          ),
          textStyle: const TextStyle(
            fontFamily: MeloTypography.fontFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MeloRadii.md),
          ),
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: const TextStyle(
            fontFamily: MeloTypography.fontFamily,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(
            fontFamily: MeloTypography.fontFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        titleTextStyle: textTheme.titleSmall,
        subtitleTextStyle: textTheme.bodySmall,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MeloRadii.xl),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isLight
            ? const Color(0xFF2A1A1F)
            : const Color(0xFF1C1116),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: isLight ? Colors.white : MeloColors.playerText,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MeloRadii.md),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.primary.withValues(alpha: 0.18),
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.16),
        trackHeight: 4,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.primary.withValues(alpha: 0.18),
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: textTheme.labelLarge?.copyWith(color: scheme.onSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MeloRadii.pill),
        ),
      ),
    );
  }
}
