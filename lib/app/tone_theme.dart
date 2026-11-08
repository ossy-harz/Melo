import 'package:flutter/material.dart';

/// Tone's palette: cherry red on a deep, warm ink. The app shell stays dark
/// so the product always feels like the same place, while light mode offers a
/// warm cherry-tinted paper alternative.
abstract final class ToneColors {
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
}

/// Corner radii used across the product so surfaces stay consistent.
abstract final class ToneRadii {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 22.0;
  static const xl = 28.0;
  static const pill = 999.0;
}

/// Motion tokens: durations and curves for a calm, premium feel.
abstract final class ToneMotion {
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
abstract final class ToneShadows {
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
}

/// Tone's type scale: a single, characterful family (Plus Jakarta Sans) with
/// discipline in weight and tracking instead of shouting on every heading.
abstract final class ToneTypography {
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
class TonePageTransitionsBuilder extends PageTransitionsBuilder {
  const TonePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (ToneMotion.reduced(context)) return child;
    final curved = CurvedAnimation(
      parent: animation,
      curve: ToneMotion.emphasized,
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

abstract final class ToneTheme {
  static ThemeData get light => _theme(Brightness.light);
  static ThemeData get dark => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: ToneColors.cherry,
          brightness: brightness,
        ).copyWith(
          primary: isLight ? ToneColors.plum : ToneColors.ember,
          onPrimary: isLight ? Colors.white : const Color(0xFF2A0008),
          primaryContainer: isLight
              ? const Color(0xFFFFDDE3)
              : const Color(0xFF5C0A1C),
          onPrimaryContainer: isLight
              ? const Color(0xFF5A0A1B)
              : const Color(0xFFFFD9E0),
          secondary: isLight
              ? const Color(0xFF9B2C42)
              : const Color(0xFFFFA3B2),
          onSecondary: isLight ? Colors.white : const Color(0xFF3A0712),
          secondaryContainer: isLight
              ? const Color(0xFFF7E0E6)
              : const Color(0xFF3A1119),
          onSecondaryContainer: isLight
              ? const Color(0xFF4E1624)
              : const Color(0xFFFFD9E0),
          tertiary: isLight ? const Color(0xFF9A4439) : const Color(0xFFFFB09E),
          onTertiary: isLight ? Colors.white : const Color(0xFF3A0A02),
          surface: isLight ? ToneColors.paper : ToneColors.shell,
          onSurface: isLight ? ToneColors.ink : ToneColors.playerText,
          onSurfaceVariant: isLight
              ? ToneColors.mutedInk
              : ToneColors.playerMuted,
          surfaceContainerLowest: isLight
              ? ToneColors.card
              : const Color(0xFF0B0B0B),
          surfaceContainerLow: isLight
              ? const Color(0xFFF6EDF0)
              : const Color(0xFF111111),
          surfaceContainer: isLight
              ? const Color(0xFFF1E6EA)
              : const Color(0xFF181818),
          surfaceContainerHigh: isLight
              ? const Color(0xFFEADCE1)
              : const Color(0xFF202020),
          surfaceContainerHighest: isLight
              ? const Color(0xFFE3D3D8)
              : const Color(0xFF292929),
          outline: isLight ? const Color(0xFFC9B2B9) : const Color(0xFF5A5A5A),
          outlineVariant: isLight ? ToneColors.line : const Color(0xFF2D2D2D),
          shadow: Colors.black,
          scrim: Colors.black,
          inverseSurface: isLight
              ? const Color(0xFF2A1A1F)
              : const Color(0xFFFBF3F5),
          onInverseSurface: isLight
              ? const Color(0xFFFAF6F7)
              : const Color(0xFF1A1114),
        );

    final textTheme = ToneTypography.textTheme(
      scheme.onSurface,
      scheme.onSurfaceVariant,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: ToneTypography.fontFamily,
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
          borderRadius: BorderRadius.circular(ToneRadii.xl),
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
            fontFamily: ToneTypography.fontFamily,
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: 0.1,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: TonePageTransitionsBuilder(),
          TargetPlatform.iOS: TonePageTransitionsBuilder(),
          TargetPlatform.macOS: TonePageTransitionsBuilder(),
          TargetPlatform.windows: TonePageTransitionsBuilder(),
          TargetPlatform.linux: TonePageTransitionsBuilder(),
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
          borderRadius: BorderRadius.circular(ToneRadii.lg),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ToneRadii.lg),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ToneRadii.lg),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ToneRadii.lg),
          ),
          textStyle: const TextStyle(
            fontFamily: ToneTypography.fontFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ToneRadii.md),
          ),
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: const TextStyle(
            fontFamily: ToneTypography.fontFamily,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(
            fontFamily: ToneTypography.fontFamily,
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
          borderRadius: BorderRadius.circular(ToneRadii.xl),
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
          color: isLight ? Colors.white : ToneColors.playerText,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ToneRadii.md),
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
          borderRadius: BorderRadius.circular(ToneRadii.pill),
        ),
      ),
    );
  }
}
