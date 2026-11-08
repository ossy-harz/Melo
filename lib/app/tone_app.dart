import 'package:flutter/material.dart';
import 'package:tone_player/app/tone_appearance.dart';
import 'package:tone_player/app/tone_services.dart';
import 'package:tone_player/app/tone_theme.dart';
import 'package:tone_player/features/auto_mix/auto_mix_diagnostic_screen.dart';
import 'package:tone_player/features/shell/app_shell.dart';

class ToneApp extends StatelessWidget {
  const ToneApp.preview({super.key})
    : services = null,
      servicesFuture = null,
      diagnosticMode = false;

  const ToneApp({
    super.key,
    required this.servicesFuture,
    this.diagnosticMode = false,
  }) : services = null;

  const ToneApp.ready({super.key, required this.services})
    : servicesFuture = null,
      diagnosticMode = false;

  final ToneServices? services;
  final Future<ToneServices>? servicesFuture;
  final bool diagnosticMode;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ToneAppearanceController.instance,
      builder: (context, themeMode, _) => MaterialApp(
        title: 'Melo',
        debugShowCheckedModeBanner: false,
        theme: ToneTheme.light,
        darkTheme: ToneTheme.dark,
        themeMode: themeMode,
        home: services != null
            ? _home(services!)
            : servicesFuture != null
            ? _ServicesLoader(
                future: servicesFuture!,
                diagnosticMode: diagnosticMode,
              )
            : const AppShell(),
      ),
    );
  }

  Widget _home(ToneServices services) => diagnosticMode
      ? AutoMixDiagnosticScreen(services: services)
      : AppShell(services: services);
}

class _ServicesLoader extends StatefulWidget {
  const _ServicesLoader({required this.future, required this.diagnosticMode});

  final Future<ToneServices> future;
  final bool diagnosticMode;

  @override
  State<_ServicesLoader> createState() => _ServicesLoaderState();
}

class _ServicesLoaderState extends State<_ServicesLoader> {
  late Future<ToneServices> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.future;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ToneServices>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.music_off_rounded, size: 40),
                  const SizedBox(height: 16),
                  Text(
                    'Melo couldn’t start audio services.',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => setState(
                      () => _future = ToneServices.initialize(
                        persistPlaybackState: !widget.diagnosticMode,
                      ),
                    ),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final services = snapshot.requireData;
      return widget.diagnosticMode
          ? AutoMixDiagnosticScreen(services: services)
          : AppShell(services: services);
    },
  );
}
