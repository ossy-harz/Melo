import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:melo_player/app/melo_appearance.dart';
import 'package:melo_player/app/melo_services.dart';
import 'package:melo_player/app/melo_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MeloAppearanceController.instance.load();
  const requestedDiagnosticMode = bool.fromEnvironment(
    'TONE_AUTOMIX_DIAGNOSTICS',
  );
  final diagnosticMode = kDebugMode && requestedDiagnosticMode;
  runApp(
    MeloApp(
      servicesFuture: MeloServices.initialize(
        persistPlaybackState: !diagnosticMode,
      ),
      diagnosticMode: diagnosticMode,
    ),
  );
}
