import 'dart:async';

import 'package:flutter/material.dart';
import 'package:melo_player/features/player/audio_profile.dart';
import 'package:melo_player/features/player/audio_profile_service.dart';

class AudioSettingsScreen extends StatefulWidget {
  const AudioSettingsScreen({required this.audioProfileService, super.key});

  final AudioProfileService? audioProfileService;

  @override
  State<AudioSettingsScreen> createState() => _AudioSettingsScreenState();
}

class _AudioSettingsScreenState extends State<AudioSettingsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  AudioProfile _profile = const AudioProfile();
  AudioOutputCapabilities? _capabilities;

  @override
  void initState() {
    super.initState();
    unawaited(_loadAudioProfile());
  }

  Future<void> _loadAudioProfile() async {
    final service = widget.audioProfileService;
    if (service == null) {
      setState(() {
        _isLoading = false;
        _error = 'Audio playback is not available in this preview.';
      });
      return;
    }
    try {
      final values = await Future.wait([
        service.loadAudioProfile(),
        service.loadAudioCapabilities(),
      ]);
      if (mounted) {
        setState(() {
          _profile = values[0] as AudioProfile;
          _capabilities = values[1] as AudioOutputCapabilities;
        });
      }
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'audio settings',
          context: ErrorDescription('while loading audio settings'),
        ),
      );
      if (mounted) setState(() => _error = 'Could not load audio settings.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _setProfile(AudioProfile profile) async {
    final service = widget.audioProfileService;
    if (service == null) return;
    setState(() => _isSaving = true);
    try {
      await service.setAudioProfile(profile);
      if (mounted) setState(() => _profile = profile);
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'audio settings',
          context: ErrorDescription('while saving audio quality settings'),
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Could not save audio settings: $error'),
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
      appBar: AppBar(title: const Text('Sound & playback')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
        children: [
          Text(
            'Make playback sound like yours.',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const SizedBox(height: 24),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Text(_error!, style: TextStyle(color: colors.error)),
          const SizedBox(height: 32),
          Text(
            'Audio quality',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Equalizer settings apply on supported Android playback routes. '
            'Tone does not claim bit-perfect or universal Hi-Res output.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          if (_capabilities?.equalizer ?? false) ...[
            DropdownButtonFormField<AudioEqPreset>(
              initialValue: _profile.preset,
              decoration: const InputDecoration(labelText: 'Equalizer preset'),
              items: [
                for (final preset in AudioEqPreset.values)
                  DropdownMenuItem(
                    value: preset,
                    child: Text(_presetTitle(preset)),
                  ),
              ],
              onChanged: _isSaving || widget.audioProfileService == null
                  ? null
                  : (preset) {
                      if (preset == null) return;
                      final selected =
                          AudioProfile.forPreset(
                            preset,
                          ).copyWith(
                            bassDb: _profile.bassDb,
                            loudnessNormalization:
                                _profile.loudnessNormalization,
                            targetLoudnessDb: _profile.targetLoudnessDb,
                          );
                      unawaited(_setProfile(selected));
                    },
            ),
            if (_profile.preset == AudioEqPreset.custom)
              for (
                var index = 0;
                index < AudioProfile.bandCentersHz.length;
                index++
              )
                _gainSlider(
                  label: _bandLabel(AudioProfile.bandCentersHz[index]),
                  value: _profile.bandGainsDb[index],
                  onChanged: (value) =>
                      _updateProfile(_profile.withBandGain(index, value)),
                  onChangeEnd: (_) => unawaited(_setProfile(_profile)),
                ),
            _gainSlider(
              label: 'Bass adjustment',
              value: _profile.bassDb,
              onChanged: (value) =>
                  _updateProfile(_profile.copyWith(bassDb: value)),
              onChangeEnd: (_) => unawaited(_setProfile(_profile)),
            ),
          ] else
            Text(
              _capabilities == null
                  ? 'Equalizer capability is unavailable.'
                  : 'A usable Android equalizer is not currently available '
                        'on this route. Tracks will play without EQ.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Approximate loudness leveling'),
            subtitle: const Text(
              'Uses local RMS analysis when available. This is not ReplayGain '
              'or LUFS normalization and only attenuates audio.',
            ),
            value: _profile.loudnessNormalization,
            onChanged:
                _isSaving ||
                    widget.audioProfileService == null ||
                    !(_capabilities?.loudnessNormalization ?? false)
                ? null
                : (enabled) => unawaited(
                    _setProfile(
                      _profile.copyWith(loudnessNormalization: enabled),
                    ),
                  ),
          ),
          if (_profile.loudnessNormalization)
            _gainSlider(
              label:
                  'RMS target (${_profile.targetLoudnessDb.toStringAsFixed(0)} dBFS)',
              value: _profile.targetLoudnessDb,
              minimum: -24,
              maximum: -10,
              onChanged: (value) =>
                  _updateProfile(_profile.copyWith(targetLoudnessDb: value)),
              onChangeEnd: (_) => unawaited(_setProfile(_profile)),
            ),
          const SizedBox(height: 12),
          Text(
            'Balance, manual output routing, and headphone-specific profiles '
            'are not exposed because this device integration cannot reliably '
            'control them.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
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
                    'Audio processing is optional and happens on this device. '
                    'Unsupported equalizers stay unavailable, and Tone does not '
                    'claim bit-perfect or universal Hi-Res output.',
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

  Widget _gainSlider({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangeEnd,
    double minimum = AudioProfile.minimumGainDb,
    double maximum = AudioProfile.maximumGainDb,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('$label: ${value.toStringAsFixed(1)} dB'),
      Slider(
        value: value.clamp(minimum, maximum).toDouble(),
        min: minimum,
        max: maximum,
        divisions: ((maximum - minimum) * 2).round(),
        label: '${value.toStringAsFixed(1)} dB',
        onChanged: _isSaving || widget.audioProfileService == null
            ? null
            : onChanged,
        onChangeEnd: _isSaving || widget.audioProfileService == null
            ? null
            : onChangeEnd,
      ),
    ],
  );

  void _updateProfile(AudioProfile profile) {
    setState(() => _profile = profile);
  }

  String _presetTitle(AudioEqPreset preset) => switch (preset) {
    AudioEqPreset.flat => 'Flat',
    AudioEqPreset.balanced => 'Balanced',
    AudioEqPreset.bass => 'Bass',
    AudioEqPreset.vocal => 'Vocal clarity',
    AudioEqPreset.custom => 'Custom',
  };

  String _bandLabel(double centerHz) => centerHz >= 1000
      ? '${(centerHz / 1000).toStringAsFixed(centerHz >= 10000 ? 0 : 1)} kHz'
      : '${centerHz.toStringAsFixed(0)} Hz';

}
