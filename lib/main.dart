import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:tone_player/app/tone_appearance.dart';
import 'package:tone_player/app/tone_services.dart';
import 'package:tone_player/app/tone_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ToneAppearanceController.instance.load();
  const requestedDiagnosticMode = bool.fromEnvironment(
    'TONE_AUTOMIX_DIAGNOSTICS',
  );
  final diagnosticMode = kDebugMode && requestedDiagnosticMode;
  runApp(
    ToneApp(
      servicesFuture: ToneServices.initialize(
        persistPlaybackState: !diagnosticMode,
      ),
      diagnosticMode: diagnosticMode,
    ),
  );
}
