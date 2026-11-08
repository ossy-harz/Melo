import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tone_player/app/tone_services.dart';
import 'package:tone_player/features/auto_mix/auto_mix_settings.dart';
import 'package:tone_player/features/library/imported_track.dart';

class AutoMixDiagnosticScreen extends StatefulWidget {
  const AutoMixDiagnosticScreen({super.key, required this.services});

  final ToneServices services;

  @override
  State<AutoMixDiagnosticScreen> createState() =>
      _AutoMixDiagnosticScreenState();
}

class _AutoMixDiagnosticScreenState extends State<AutoMixDiagnosticScreen> {
  final List<Map<String, Object?>> _records = [];
  String? _outgoingTrackId;
  String? _incomingTrackId;
  Duration _duration = AutoMixSettings.diagnosticTransitionDurations[2];
  Map<String, Object?>? _latestResult;
  String? _status;
  String? _recordPath;
  bool _running = false;
  bool _transitionStarted = false;
  bool _cancelRequested = false;

  List<ImportedTrack> get _availableTracks => widget
      .services
      .musicLibrary
      .tracks
      .where((track) => track.isAvailable)
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    final tracks = _availableTracks;
    if (tracks.isNotEmpty) _outgoingTrackId = tracks.first.id;
    if (tracks.length > 1) _incomingTrackId = tracks[1].id;
  }

  ImportedTrack? _trackById(String? id) {
    for (final track in _availableTracks) {
      if (track.id == id) return track;
    }
    return null;
  }

  Future<void> _runTrial() async {
    final outgoing = _trackById(_outgoingTrackId);
    final incoming = _trackById(_incomingTrackId);
    if (outgoing == null || incoming == null || outgoing.id == incoming.id) {
      _showMessage('Choose two different available library tracks.');
      return;
    }

    setState(() {
      _running = true;
      _transitionStarted = false;
      _cancelRequested = false;
      _status = 'Loading selected tracks into the diagnostic queue';
      _latestResult = null;
    });
    final handler = widget.services.audioHandler;
    try {
      await handler.updateQueue([
        outgoing.toMediaItem(),
        incoming.toMediaItem(),
      ]);
      if (_cancelRequested) return;
      await handler.play();
      if (_cancelRequested) return;

      setState(() {
        _transitionStarted = true;
        _status = 'Transition running';
      });
      final operation = handler.customAction('autoMix.transitionToNextTrack', {
        'diagnostic': true,
        'durationMs': _duration.inMilliseconds,
      });
      final completed = Completer<void>();
      final observedOperation = operation.then(
        (value) {
          completed.complete();
          return value;
        },
        onError: (Object error, StackTrace stackTrace) {
          completed.complete();
          Error.throwWithStackTrace(error, stackTrace);
        },
      );
      while (!completed.isCompleted) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        if (completed.isCompleted || !mounted) break;
        final status = await handler.customAction(
          'autoMix.getDiagnosticStatus',
        );
        if (mounted && status is Map) {
          setState(() {
            _status =
                'Transition running; ${_gainUpdateCount(status)} Dart-side gain updates observed';
            _latestResult = Map<String, Object?>.from(status);
          });
        }
      }

      final rawResult = await observedOperation;
      if (rawResult is! Map) {
        throw StateError('The handler returned an invalid diagnostic result.');
      }
      final result = Map<String, Object?>.from(rawResult);
      if (mounted) {
        setState(() {
          _latestResult = result;
          _status = result['completed'] == true
              ? 'Transition completed'
              : 'Transition did not complete';
        });
      }
      await _saveRecord({
        ...result,
        'recordedAt': DateTime.now().toUtc().toIso8601String(),
        'outgoingFormat': _formatLabel(outgoing.path),
        'incomingFormat': _formatLabel(incoming.path),
      });
    } on Object catch (error) {
      final record = <String, Object?>{
        'trialId': DateTime.now().toUtc().microsecondsSinceEpoch.toString(),
        'outgoingTrackId': outgoing.id,
        'incomingTrackId': incoming.id,
        'requestedDurationMs': _duration.inMilliseconds,
        'recordedAt': DateTime.now().toUtc().toIso8601String(),
        'error': error.toString(),
        'timingSource':
            'Dart-side player-state updates are not audio-output timings',
      };
      if (mounted) {
        setState(() {
          _latestResult = record;
          _status = 'Trial failed';
        });
      }
      await _saveRecord({
        ...record,
        'outgoingFormat': _formatLabel(outgoing.path),
        'incomingFormat': _formatLabel(incoming.path),
      });
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
          _transitionStarted = false;
        });
      }
    }
  }

  int _gainUpdateCount(Map status) {
    final updates = status['gainUpdates'];
    if (updates is! Map) return 0;
    return updates.values.fold<int>(0, (total, deck) {
      if (deck is! Map) return total;
      final count = deck['count'];
      return total + (count is int ? count : 0);
    });
  }

  Future<void> _cancelTrial() async {
    _cancelRequested = true;
    if (!_transitionStarted) return;
    try {
      await widget.services.audioHandler.customAction(
        'autoMix.cancelTransition',
        {'reason': 'diagnosticUserCancel'},
      );
    } on Object catch (error) {
      _showMessage('Could not cancel transition: $error');
    }
  }

  Future<void> _saveRecord(Map<String, Object?> record) async {
    _records.add(record);
    try {
      final directory = await getApplicationSupportDirectory();
      final file = File(
        '${directory.path}${Platform.pathSeparator}automix-diagnostic-results.jsonl',
      );
      await file.writeAsString(
        '${jsonEncode(record)}\n',
        mode: FileMode.append,
        flush: true,
      );
      if (mounted) setState(() => _recordPath = file.path);
    } on Object catch (error) {
      _showMessage('Could not write diagnostic result: $error');
    }
  }

  String _formatLabel(String path) {
    final normalizedPath = Uri.tryParse(path)?.path ?? path;
    final fileName = normalizedPath.split(Platform.pathSeparator).last;
    final dot = fileName.lastIndexOf('.');
    return dot < 0 ? 'unknown' : fileName.substring(dot + 1).toUpperCase();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    if (_running) {
      _cancelRequested = true;
      if (_transitionStarted) unawaited(_cancelTrial());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tracks = _availableTracks;
    return Scaffold(
      appBar: AppBar(title: const Text('AutoMix diagnostics')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Developer-only transition trials. Listening observations must be recorded separately; gain-state timing is not audio-output timing.',
            ),
            const SizedBox(height: 16),
            _trackSelector(
              label: 'Outgoing track',
              value: _outgoingTrackId,
              tracks: tracks,
              onChanged: (value) => setState(() => _outgoingTrackId = value),
            ),
            const SizedBox(height: 12),
            _trackSelector(
              label: 'Incoming track',
              value: _incomingTrackId,
              tracks: tracks,
              onChanged: (value) => setState(() => _incomingTrackId = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Duration>(
              initialValue: _duration,
              decoration: const InputDecoration(
                labelText: 'Transition duration',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final duration
                    in AutoMixSettings.diagnosticTransitionDurations)
                  DropdownMenuItem(
                    value: duration,
                    child: Text('${duration.inSeconds} seconds'),
                  ),
              ],
              onChanged: _running
                  ? null
                  : (value) {
                      if (value != null) setState(() => _duration = value);
                    },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _running ? null : _runTrial,
                    child: const Text('Start trial'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: _transitionStarted ? _cancelTrial : null,
                  child: const Text('Cancel'),
                ),
              ],
            ),
            if (_status != null) ...[
              const SizedBox(height: 16),
              Text(_status!, style: Theme.of(context).textTheme.titleMedium),
            ],
            if (_latestResult != null) ...[
              const SizedBox(height: 12),
              SelectableText(
                const JsonEncoder.withIndent('  ').convert(_latestResult),
              ),
            ],
            if (_recordPath != null) ...[
              const SizedBox(height: 12),
              SelectableText('Results file: $_recordPath'),
              Text('Trials recorded this session: ${_records.length}'),
            ],
            if (tracks.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Text('No available library tracks to test.'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _trackSelector({
    required String label,
    required String? value,
    required List<ImportedTrack> tracks,
    required ValueChanged<String?> onChanged,
  }) => DropdownButtonFormField<String>(
    initialValue: value,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    items: [
      for (final track in tracks)
        DropdownMenuItem(
          value: track.id,
          child: Text(
            '${track.title} — ${track.displayArtist}',
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ],
    onChanged: _running ? null : onChanged,
  );
}
