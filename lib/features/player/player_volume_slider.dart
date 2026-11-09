import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

class PlayerVolumeSlider extends StatefulWidget {
  const PlayerVolumeSlider({
    required this.audioHandler,
    this.accentColor = Colors.white,
    super.key,
  });

  final AudioHandler audioHandler;
  final Color accentColor;

  @override
  State<PlayerVolumeSlider> createState() => _PlayerVolumeSliderState();
}

class _PlayerVolumeSliderState extends State<PlayerVolumeSlider> {
  double _volume = 0.85;
  double _lastNonZeroVolume = 0.85;

  @override
  void initState() {
    super.initState();
    unawaited(_initVolume());
  }

  Future<void> _initVolume() async {
    try {
      final vol = await widget.audioHandler.customAction('getVolume');
      if (vol is num && mounted) {
        setState(() {
          _volume = vol.toDouble().clamp(0.0, 1.0);
          if (_volume > 0) _lastNonZeroVolume = _volume;
        });
      }
    } catch (_) {}
  }

  Future<void> _setVolume(double newVol) async {
    final clamped = newVol.clamp(0.0, 1.0);
    setState(() {
      _volume = clamped;
      if (clamped > 0) _lastNonZeroVolume = clamped;
    });
    try {
      await widget.audioHandler.customAction('setVolume', {'volume': clamped});
    } catch (_) {}
  }

  void _toggleMute() {
    if (_volume > 0) {
      _lastNonZeroVolume = _volume;
      unawaited(_setVolume(0.0));
    } else {
      unawaited(_setVolume(_lastNonZeroVolume > 0 ? _lastNonZeroVolume : 0.8));
    }
  }

  void _handleDrag(Offset localPosition, double width) {
    if (width <= 0) return;
    final ratio = (localPosition.dx / width).clamp(0.0, 1.0);
    _setVolume(ratio);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          IconButton(
            onPressed: _toggleMute,
            tooltip: _volume == 0 ? 'Unmute' : 'Mute',
            iconSize: 20,
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
            icon: Icon(
              _volume == 0
                  ? Icons.volume_off_rounded
                  : _volume < 0.4
                      ? Icons.volume_mute_rounded
                      : Icons.volume_down_rounded,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) =>
                      _handleDrag(details.localPosition, width),
                  onTapDown: (details) =>
                      _handleDrag(details.localPosition, width),
                  child: Container(
                    height: 24,
                    alignment: Alignment.center,
                    child: Stack(
                      children: [
                        // Background inactive track
                        Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        // Active filled bar
                        FractionallySizedBox(
                          widthFactor: _volume.clamp(0.0, 1.0),
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: () => _setVolume(1.0),
            tooltip: 'Max volume',
            iconSize: 20,
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
            icon: Icon(
              Icons.volume_up_rounded,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}
