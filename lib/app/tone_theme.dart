import 'package:flutter/material.dart';

abstract final class ToneColors {
  static const ink = Color(0xFF25221F);
  static const mutedInk = Color(0xFF726D66);
  static const paper = Color(0xFFF7F5F0);
  static const card = Color(0xFFFFFEFB);
  static const plum = Color(0xFFB5122D);
  static const ember = Color(0xFFFF334F);
  static const apricot = Color(0xFFE9A875);
  static const sage = Color(0xFF8A9B82);
  static const line = Color(0xFFE9E4DC);
}

abstract final class ToneTheme {
  static ThemeData get light => _theme(Brightness.light);
  static ThemeData get dark => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: ToneColors.plum,
          brightness: brightness,
        ).copyWith(
          primary: isLight ? ToneColors.plum : ToneColors.ember,
          onPrimary: Colors.white,
          primaryContainer: isLight
              ? const Color(0xFFF8DDE2)
              : const Color(0xFF49101E),
          onPrimaryContainer: isLight
              ? const Color(0xFF50101D)
              : const Color(0xFFFFDCE2),
          secondary: isLight
              ? const Color(0xFF8B3042)
              : const Color(0xFFFF8A9A),
          onSecondary: Colors.white,
          secondaryContainer: isLight
              ? const Color(0xFFF4E0E4)
              : const Color(0xFF35151D),
          onSecondaryContainer: isLight
              ? const Color(0xFF491C27)
              : const Color(0xFFFFD9DF),
          tertiary: isLight ? const Color(0xFF9A4439) : const Color(0xFFFFA18F),
          surface: isLight ? ToneColors.paper : const Color(0xFF0D090B),
          surfaceContainerLowest: isLight
              ? ToneColors.card
              : const Color(0xFF171014),
          surfaceContainerLow: isLight
              ? const Color(0xFFF2EDE9)
              : const Color(0xFF1D1217),
          surfaceContainer: isLight
              ? const Color(0xFFEFE9E5)
              : const Color(0xFF24151B),
          surfaceContainerHigh: isLight
              ? const Color(0xFFE9E2DE)
              : const Color(0xFF2C1A20),
          outlineVariant: isLight
              ? const Color(0xFFE7D7D9)
              : const Color(0xFF49323A),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: isLight ? ToneColors.ink : scheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLowest,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isLight ? scheme.surface : scheme.surfaceContainerLow,
        indicatorColor: scheme.primary.withValues(alpha: 0.18),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {TargetPlatform.android: FadeUpwardsPageTransitionsBuilder()},
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      textTheme: ThemeData(brightness: brightness).textTheme.apply(
        bodyColor: isLight ? ToneColors.ink : scheme.onSurface,
        displayColor: isLight ? ToneColors.ink : scheme.onSurface,
      ),
    );
  }
}
