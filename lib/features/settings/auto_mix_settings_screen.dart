import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:tone_player/app/tone_glass.dart';
import 'package:tone_player/app/tone_theme.dart';
import 'package:tone_player/features/auto_mix/auto_mix_profile.dart';
import 'package:tone_player/features/auto_mix/auto_mix_settings.dart';

/// Settings screen for AutoMix crossfade behaviour.
///
/// Lets the user choose a mix profile, set a manual transition duration, and
/// enable or disable automatic transitions near the end of each track.
class AutoMixSettingsScreen extends StatefulWidget {
  const AutoMixSettingsScreen({
    required this.audioHandler,
    super.key,
  });

  final AudioHandler audioHandler;

  @override
  State<AutoMixSettingsScreen> createState() => _AutoMixSettingsScreenState();
}

class _AutoMixSettingsScreenState extends State<AutoMixSettingsScreen> {
  bool _isLoading = true;
  String? _error;
  AutoMixProfile _profile = AutoMixProfile.balanced;
  Duration? _transitionDuration;
  bool _automaticTransitions = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSettings());
  }

  Future<void> _loadSettings() async {
    try {
      final result = await widget.audioHandler.customAction(
        'autoMix.getSettings',
      );
      if (result is! Map) throw const FormatException('Invalid settings.');
      if (!mounted) return;
      setState(() {
        _profile = AutoMixProfile.values.firstWhere(
          (p) => p.name == result['profile'],
          orElse: () => AutoMixProfile.balanced,
        );
        final ms = result['transitionDurationMs'];
        _transitionDuration = ms is int && ms > 0
            ? Duration(milliseconds: ms)
            : null;
        _automaticTransitions = result['automaticTransitions'] as bool? ??
            true;
        _isLoading = false;
      });
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'automix settings',
          context: ErrorDescription('while loading AutoMix settings'),
        ),
      );
      if (mounted) {
        setState(() {
          _error = 'Could not load AutoMix settings.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    try {
      await widget.audioHandler.customAction(
        'autoMix.updateSettings',
        <String, Object?>{
          'profile': _profile.name,
          if (_transitionDuration != null)
            'transitionDurationMs': _transitionDuration!.inMilliseconds,
          'automaticTransitions': _automaticTransitions,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AutoMix settings saved.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'automix settings',
          context: ErrorDescription('while saving AutoMix settings'),
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Could not save AutoMix settings: $error'),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleAutomatic() async {
    try {
      final result = await widget.audioHandler.customAction(
        'autoMix.toggleAutomatic',
      );
      if (!mounted) return;
      setState(() {
        _automaticTransitions =
            result is Map && result['automaticTransitions'] is bool
                ? result['automaticTransitions'] as bool
                : !_automaticTransitions;
      });
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'automix settings',
          context: ErrorDescription('while toggling automatic transitions'),
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Could not update automatic transitions: $error'),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    }
  }

  String _profileTitle(AutoMixProfile profile) => switch (profile) {
        AutoMixProfile.atmospheric => 'Atmospheric',
        AutoMixProfile.balanced => 'Balanced',
        AutoMixProfile.energetic => 'Energetic',
      };

  String _profileSubtitle(AutoMixProfile profile) => switch (profile) {
        AutoMixProfile.atmospheric =>
          'Long, gentle crossfades (~20s) for ambient sets.',
        AutoMixProfile.balanced =>
          'Smooth equal-power crossfades (~10s) for most listening.',
        AutoMixProfile.energetic =>
          'Quick blends (~4s) that keep the energy moving.',
      };

  String _durationLabel(Duration? duration) {
    if (duration == null) return 'Profile default';
    return '${duration.inSeconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('AutoMix transitions')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
        children: [
          Text(
            'Blend tracks together.',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'AutoMix crossfades between the current track and the next one '
            'in your queue. It works with local files on this device.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 26),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Text(_error!, style: TextStyle(color: colors.error))
          else ...[
            Text(
              'Mix profile',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Chooses the crossfade style and default length.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            ...AutoMixProfile.values.map(
              (profile) => RadioListTile<AutoMixProfile>(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _profileTitle(profile),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  _profileSubtitle(profile),
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                value: profile,
                // ignore: deprecated_member_use
                groupValue: _profile,
                activeColor: colors.primary,
                // ignore: deprecated_member_use
                onChanged: _isLoading
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _profile = value);
                        if (_transitionDuration == null) {
                          // Reset to profile default when switching profiles.
                          // The saved duration is profile-agnostic; only
                          // explicitly set durations are preserved.
                        }
                      },
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Manual transition duration',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Override the profile default for manual “Mix next” transitions. '
              '3–30 seconds. Automatic transitions use the outgoing track\'s '
              'remaining time when shorter.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            ToneGlass(
              borderRadius: ToneRadii.md,
              tint: Colors.black.withValues(alpha: 0.12),
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: colors.primary,
                  inactiveTrackColor:
                      colors.primary.withValues(alpha: 0.25),
                  thumbColor: colors.primary,
                  valueIndicatorColor: colors.primary,
                ),
                child: Slider(
                  min: AutoMixSettings.minimumTransitionDuration
                      .inSeconds
                      .toDouble(),
                  max: AutoMixSettings.maximumTransitionDuration
                      .inSeconds
                      .toDouble(),
                  divisions: 27,
                  label: _durationLabel(_transitionDuration),
                  value:
                      (_transitionDuration ??
                          _profile.defaultTransitionDuration)
                          .inSeconds
                          .toDouble(),
                  onChanged: _isLoading
                      ? null
                      : (value) {
                          setState(() {
                            _transitionDuration = Duration(seconds: value.round());
                          });
                        },
                ),
              ),
            ),
            const SizedBox(height: 22),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Automatic transitions'),
              subtitle: const Text(
                'Start a crossfade to the next track near the end of the '
                'current track instead of a hard stop.',
              ),
              value: _automaticTransitions,
              onChanged: _isLoading
                  ? null
                  : (_) => unawaited(_toggleAutomatic()),
            ),
            const SizedBox(height: 26),
            FilledButton.icon(
              onPressed: _isLoading ? null : _saveSettings,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Save settings'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ],
      ),
    );
  }
}
