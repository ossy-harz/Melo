import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:tone_player/features/player/dj_transition.dart';

class DjMixSettingsScreen extends StatefulWidget {
  const DjMixSettingsScreen({required this.audioHandler, super.key});

  final AudioHandler? audioHandler;

  @override
  State<DjMixSettingsScreen> createState() => _DjMixSettingsScreenState();
}

class _DjMixSettingsScreenState extends State<DjMixSettingsScreen> {
  DjMixMode _mode = DjMixMode.beatMatched;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadMode());
  }

  Future<void> _loadMode() async {
    final handler = widget.audioHandler;
    if (handler == null) {
      setState(() {
        _isLoading = false;
        _error = 'Audio playback is not available in this preview.';
      });
      return;
    }
    try {
      final savedName = await handler.customAction('getDjMixMode');
      final mode = DjMixMode.values.firstWhere(
        (candidate) => candidate.name == savedName,
        orElse: () => throw FormatException(
          'The saved DJ mix mode is not recognized: $savedName',
        ),
      );
      if (mounted) setState(() => _mode = mode);
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'tone settings',
          context: ErrorDescription('while loading DJ mix settings'),
        ),
      );
      if (mounted) setState(() => _error = 'Could not load DJ mix settings.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _setMode(DjMixMode mode) async {
    final handler = widget.audioHandler;
    if (handler == null) return;
    setState(() => _isSaving = true);
    try {
      await handler.customAction('setDjMixMode', {'mode': mode.name});
      if (mounted) setState(() => _mode = mode);
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'tone settings',
          context: ErrorDescription('while saving DJ mix settings'),
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Could not save DJ mix settings: $error'),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Sound & DJ mix')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
        children: [
          Text(
            'Let the songs flow.',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Tone uses two local playback decks to overlap tracks, then hands '
            'the queue to the next song with a softer, intentional handoff.',
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          Text(
            'You can toggle DJ mode from Now Playing. While it is on, swipe '
            'the artwork left or right for a brief pitch-corrected deck nudge; '
            'release to return to normal speed.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Text(_error!, style: TextStyle(color: colors.error))
          else
            RadioGroup<DjMixMode>(
              groupValue: _mode,
              onChanged: (mode) {
                if (!_isSaving && mode != null) unawaited(_setMode(mode));
              },
              child: AbsorbPointer(
                absorbing: _isSaving,
                child: Column(
                  children: [
                    for (final mode in DjMixMode.values)
                      RadioListTile<DjMixMode>(
                        value: mode,
                        title: Text(_modeTitle(mode)),
                        subtitle: Text(_modeDescription(mode)),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    if (_isSaving)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: LinearProgressIndicator(),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.graphic_eq_rounded, color: colors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Beat matching only adjusts tempo by a small, '
                    'pitch-corrected amount when both songs have compatible '
                    'embedded BPM tags. Otherwise Tone uses a smooth blend; '
                    'it never invents tempo data.',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: colors.onSurfaceVariant, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _modeTitle(DjMixMode mode) => switch (mode) {
    DjMixMode.off => 'No automatic transition',
    DjMixMode.smooth => 'Smooth blend',
    DjMixMode.beatMatched => 'Beat-matched DJ blend',
  };

  String _modeDescription(DjMixMode mode) => switch (mode) {
    DjMixMode.off => 'Songs play one after another with no automatic overlap.',
    DjMixMode.smooth => 'A gentle, equal-power overlap between local songs.',
    DjMixMode.beatMatched =>
      'Match tagged tempos when close; otherwise use a smooth overlap.',
  };
}
