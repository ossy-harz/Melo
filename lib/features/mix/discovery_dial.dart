import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:melo_player/app/melo_theme.dart';

class DiscoveryDialSheet extends StatefulWidget {
  const DiscoveryDialSheet({
    super.key,
    required this.audioHandler,
    this.initialLevel = 0.5,
  });

  final AudioHandler audioHandler;
  final double initialLevel;

  static Future<void> show(
    BuildContext context, {
    required AudioHandler audioHandler,
    double initialLevel = 0.5,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DiscoveryDialSheet(
        audioHandler: audioHandler,
        initialLevel: initialLevel,
      ),
    );
  }

  @override
  State<DiscoveryDialSheet> createState() => _DiscoveryDialSheetState();
}

class _DiscoveryDialSheetState extends State<DiscoveryDialSheet> {
  late double _level;

  @override
  void initState() {
    super.initState();
    _level = widget.initialLevel.clamp(0.0, 1.0);
    _loadCurrentLevel();
  }

  Future<void> _loadCurrentLevel() async {
    try {
      final res = await widget.audioHandler.customAction('getDiscoveryLevel');
      if (res is num && mounted) {
        setState(() => _level = res.toDouble().clamp(0.0, 1.0));
      }
    } catch (_) {}
  }

  void _onLevelChanged(double value) {
    setState(() => _level = value);
    HapticFeedback.selectionClick();
    widget.audioHandler.customAction('setDiscoveryLevel', {
      'discoveryLevel': value,
    });
  }

  String get _modeTitle {
    if (_level < 0.3) return 'Comfort Zone';
    if (_level > 0.7) return 'Deep Exploration';
    return 'Balanced Flow';
  }

  String get _modeDescription {
    if (_level < 0.3) {
      return 'Prioritizes your heart-liked songs and most played tracks. Familiar, warm, and safe.';
    }
    if (_level > 0.7) {
      return 'Prioritizes unplayed tracks, hidden gems, and deep library cuts you haven\'t heard in a while.';
    }
    return 'A harmonious mix of beloved favorites and fresh discoveries, intelligently spaced.';
  }

  IconData get _modeIcon {
    if (_level < 0.3) return Icons.favorite_rounded;
    if (_level > 0.7) return Icons.explore_rounded;
    return Icons.auto_awesome_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final percent = (_level * 100).round();

    return Container(
      padding: EdgeInsets.only(
        top: 14,
        left: 20,
        right: 20,
        bottom: MediaQuery.paddingOf(context).bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F12),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: Color(0xFF22222A), width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: MeloColors.cherry.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.tune_rounded,
                  color: MeloColors.cherry,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Discovery vs. Familiarity Dial',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Smart Shuffle & Queue Biasing',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: MeloColors.cherry.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$percent%',
                  style: TextStyle(
                    color: MeloColors.cherry,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Dynamic card reflecting the current mode
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF16161C),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: MeloColors.cherry.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MeloColors.cherry.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(_modeIcon, color: MeloColors.cherry, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _modeTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _modeDescription,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: MeloColors.cherry,
              inactiveTrackColor: Colors.white12,
              thumbColor: MeloColors.cherry,
              overlayColor: MeloColors.cherry.withValues(alpha: 0.2),
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: _level,
              min: 0.0,
              max: 1.0,
              onChanged: _onLevelChanged,
            ),
          ),

          // Presets row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _PresetChip(
                label: 'Familiar (0%)',
                isSelected: _level < 0.2,
                onTap: () => _onLevelChanged(0.0),
              ),
              _PresetChip(
                label: 'Balanced (50%)',
                isSelected: _level >= 0.4 && _level <= 0.6,
                onTap: () => _onLevelChanged(0.5),
              ),
              _PresetChip(
                label: 'Explore (100%)',
                isSelected: _level > 0.8,
                onTap: () => _onLevelChanged(1.0),
              ),
            ],
          ),

          const SizedBox(height: 22),

          // Fair Shuffle Guarantees
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF34C759),
                      size: 15,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Fair Shuffle: Zero repeats until every song in queue plays.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF34C759),
                      size: 15,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Anti-Clustering: Never plays back-to-back songs by one artist.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? MeloColors.cherry.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? MeloColors.cherry : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? MeloColors.cherry : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
