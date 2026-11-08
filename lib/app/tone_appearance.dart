import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the user's appearance choice in memory and in local preferences.
///
/// Tone defaults to its dark listening shell. The Now Playing surface stays
/// light by design, so switching themes changes the app shell without making
/// the player unreadable.
class ToneAppearanceController extends ValueNotifier<ThemeMode> {
  ToneAppearanceController._() : super(ThemeMode.dark);

  static final ToneAppearanceController instance = ToneAppearanceController._();

  static const _preferenceKey = 'tone.themeMode';
  bool _hasLoaded = false;

  Future<void> load() async {
    if (_hasLoaded) return;
    _hasLoaded = true;
    try {
      final preferences = await SharedPreferences.getInstance();
      final stored = preferences.getString(_preferenceKey);
      if (stored == null) return;
      final mode = ThemeMode.values.where((mode) => mode.name == stored);
      if (mode.isNotEmpty) value = mode.first;
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'tone appearance',
          context: ErrorDescription('while loading the saved theme mode'),
        ),
      );
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    if (value == mode) return;
    value = mode;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_preferenceKey, mode.name);
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'tone appearance',
          context: ErrorDescription('while saving the theme mode'),
        ),
      );
    }
  }

  static String labelFor(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'Follow device',
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
  };
}
