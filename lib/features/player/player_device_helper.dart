import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:melo_player/app/melo_theme.dart';

class AudioOutputDeviceInfo {
  const AudioOutputDeviceInfo({
    required this.id,
    required this.name,
    required this.type,
    required this.maxSampleRate,
    required this.bitDepth,
    required this.isBitPerfectCapable,
    required this.isActive,
  });

  final int id;
  final String name;
  final String type;
  final int maxSampleRate;
  final int bitDepth;
  final bool isBitPerfectCapable;
  final bool isActive;

  String get specLabel =>
      '${(maxSampleRate / 1000).toStringAsFixed(maxSampleRate % 1000 == 0 ? 0 : 1)} kHz · $bitDepth-bit';

  IconData get icon => switch (type) {
    'usb_dac' => Icons.usb_rounded,
    'bluetooth' => Icons.bluetooth_audio_rounded,
    'wired' => Icons.headphones_rounded,
    _ => Icons.speaker_rounded,
  };
}

class PlayerDeviceHelper {
  static String? _cachedDeviceName;

  static const MethodChannel _channel = MethodChannel(
    'app.melo.melo_player/library',
  );
  static const String _bitPerfectPrefKey = 'tone_bit_perfect_usb_dac';

  static Future<String> getDeviceName() async {
    if (_cachedDeviceName != null) return _cachedDeviceName!;
    if (kIsWeb) return 'Web Player';
    if (Platform.isAndroid) {
      try {
        final name = await _channel.invokeMethod<String>('getDeviceName');
        if (name != null && name.trim().isNotEmpty) {
          _cachedDeviceName = name.contains("'s Phone") ? name : "$name's Phone";
          return _cachedDeviceName!;
        }
      } catch (_) {}
      return "Osman's Phone";
    }
    return 'This Device';
  }

  static Future<List<AudioOutputDeviceInfo>> getOutputDevices() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final raw = await _channel.invokeListMethod<dynamic>(
          'getAudioOutputDevices',
        );
        if (raw != null && raw.isNotEmpty) {
          return raw
              .whereType<Map>()
              .map(
                (m) => AudioOutputDeviceInfo(
                  id: (m['id'] as num?)?.toInt() ?? 0,
                  name: (m['name'] as String?) ?? 'Audio Output',
                  type: (m['type'] as String?) ?? 'speaker',
                  maxSampleRate: (m['maxSampleRate'] as num?)?.toInt() ?? 48000,
                  bitDepth: (m['bitDepth'] as num?)?.toInt() ?? 16,
                  isBitPerfectCapable:
                      (m['isBitPerfectCapable'] as bool?) ?? false,
                  isActive: (m['isActive'] as bool?) ?? false,
                ),
              )
              .toList(growable: false);
        }
      } catch (_) {}
    }
    final fallbackName = await getDeviceName();
    return [
      AudioOutputDeviceInfo(
        id: 0,
        name: fallbackName,
        type: 'speaker',
        maxSampleRate: 48000,
        bitDepth: 24,
        isBitPerfectCapable: false,
        isActive: true,
      ),
    ];
  }

  static Future<bool> isBitPerfectEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_bitPerfectPrefKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, Object?>> setBitPerfectMode(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_bitPerfectPrefKey, enabled);
    } catch (_) {}
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final res = await _channel.invokeMapMethod<String, dynamic>(
          'setBitPerfectMode',
          {'enabled': enabled},
        );
        if (res != null) {
          return Map<String, Object?>.from(res);
        }
      } catch (_) {}
    }
    return {'enabled': enabled, 'activeOnHardware': false};
  }

  static Future<void> openMediaOutputSwitcher() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('openMediaOutputSwitcher');
    } catch (_) {}
  }

  static Future<void> showAudioOutputSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _AudioOutputRouteSheet(),
    );
  }
}

class _AudioOutputRouteSheet extends StatefulWidget {
  const _AudioOutputRouteSheet();

  @override
  State<_AudioOutputRouteSheet> createState() => _AudioOutputRouteSheetState();
}

class _AudioOutputRouteSheetState extends State<_AudioOutputRouteSheet> {
  List<AudioOutputDeviceInfo> _devices = const [];
  bool _bitPerfectEnabled = false;
  bool _loading = true;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final values = await Future.wait([
      PlayerDeviceHelper.getOutputDevices(),
      PlayerDeviceHelper.isBitPerfectEnabled(),
    ]);
    if (!mounted) return;
    setState(() {
      _devices = values[0] as List<AudioOutputDeviceInfo>;
      _bitPerfectEnabled = values[1] as bool;
      _loading = false;
    });
  }

  Future<void> _toggleBitPerfect(bool enabled) async {
    setState(() => _bitPerfectEnabled = enabled);
    final res = await PlayerDeviceHelper.setBitPerfectMode(enabled);
    if (!mounted) return;
    final activeHw = res['activeOnHardware'] == true;
    final dev = res['deviceName'] as String?;
    setState(() {
      _statusMessage = enabled
          ? (activeHw
                ? 'Bit-Perfect USB DAC routing active on ${dev ?? "USB DAC"}.'
                : 'Bit-Perfect preference saved. Connect an Android 14+ USB DAC to bypass mixer resampling.')
          : 'Returned to standard Android audio mixer.';
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final hasUsbDac = _devices.any((d) => d.type == 'usb_dac');

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4.5,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(
                  Icons.speaker_group_rounded,
                  color: MeloColors.cherry,
                  size: 22,
                ),
                SizedBox(width: 10),
                Text(
                  'Audio Output & Hi-Res DAC',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: CircularProgressIndicator(color: MeloColors.cherry),
                ),
              )
            else ...[
              ..._devices.map(
                (device) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141416),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: device.isActive
                          ? MeloColors.cherry.withValues(alpha: 0.7)
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        device.icon,
                        color: device.isActive
                            ? MeloColors.cherry
                            : Colors.white70,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              device.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              device.isBitPerfectCapable
                                  ? '${device.specLabel} · Bit-Perfect Ready'
                                  : device.specLabel,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (device.isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: MeloColors.cherry,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Text(
                            'ACTIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF141416),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _bitPerfectEnabled
                        ? MeloColors.cherry.withValues(alpha: 0.55)
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: Colors.white,
                  activeTrackColor: MeloColors.cherry,
                  title: const Text(
                    'Bit-Perfect USB DAC (Android 14+)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    hasUsbDac
                        ? 'Direct hardware sample-rate passthrough to connected USB DAC.'
                        : 'Bypasses Android mixer resampling when a USB DAC is attached.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 11.5,
                    ),
                  ),
                  value: _bitPerfectEnabled,
                  onChanged: _toggleBitPerfect,
                ),
              ),
              if (_statusMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  _statusMessage!,
                  style: const TextStyle(
                    color: MeloColors.cherry,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: MeloColors.cherry,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    unawaited(PlayerDeviceHelper.openMediaOutputSwitcher());
                  },
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text(
                    'System Output Switcher',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
