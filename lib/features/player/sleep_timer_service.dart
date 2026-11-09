import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:melo_player/app/melo_theme.dart';

class SleepTimerService extends ChangeNotifier {
  SleepTimerService._();
  static final SleepTimerService instance = SleepTimerService._();

  Timer? _timer;
  DateTime? _targetTime;
  String? _label;

  bool get isActive => _timer != null && _timer!.isActive;
  String? get activeLabel => _label;

  Duration get remaining {
    if (_targetTime == null) return Duration.zero;
    final diff = _targetTime!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  void start({
    required Duration duration,
    required String label,
    required VoidCallback onFinish,
  }) {
    cancel();
    _targetTime = DateTime.now().add(duration);
    _label = label;
    _timer = Timer(duration, () {
      cancel();
      onFinish();
    });
    notifyListeners();
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _targetTime = null;
    _label = null;
    notifyListeners();
  }

  static Future<void> showSleepTimerDialog(
    BuildContext context,
    AudioHandler audioHandler,
  ) async {
    final timerService = instance;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return ListenableBuilder(
          listenable: timerService,
          builder: (context, _) {
            final active = timerService.isActive;
            final remaining = timerService.remaining;
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1E151A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.bedtime_outlined, color: MeloColors.cherry, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Sleep Timer',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                      ),
                      const Spacer(),
                      if (active)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: MeloColors.cherry.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: MeloColors.cherry, width: 1),
                          ),
                          child: Text(
                            '${remaining.inMinutes}m left',
                            style: const TextStyle(
                              color: MeloColors.cherrySoft,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _TimerOptionTile(
                    label: '15 Minutes',
                    selected: timerService.activeLabel == '15m',
                    onTap: () {
                      timerService.start(
                        duration: const Duration(minutes: 15),
                        label: '15m',
                        onFinish: () => audioHandler.pause(),
                      );
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                  _TimerOptionTile(
                    label: '30 Minutes',
                    selected: timerService.activeLabel == '30m',
                    onTap: () {
                      timerService.start(
                        duration: const Duration(minutes: 30),
                        label: '30m',
                        onFinish: () => audioHandler.pause(),
                      );
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                  _TimerOptionTile(
                    label: '45 Minutes',
                    selected: timerService.activeLabel == '45m',
                    onTap: () {
                      timerService.start(
                        duration: const Duration(minutes: 45),
                        label: '45m',
                        onFinish: () => audioHandler.pause(),
                      );
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                  _TimerOptionTile(
                    label: '1 Hour',
                    selected: timerService.activeLabel == '1h',
                    onTap: () {
                      timerService.start(
                        duration: const Duration(hours: 1),
                        label: '1h',
                        onFinish: () => audioHandler.pause(),
                      );
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                  _TimerOptionTile(
                    label: 'End of current track',
                    selected: timerService.activeLabel == 'track',
                    onTap: () {
                      final currentItem = audioHandler.mediaItem.value;
                      final playback = audioHandler.playbackState.value;
                      final total = currentItem?.duration ?? const Duration(minutes: 3);
                      final pos = playback.position;
                      final remainingTime = total - pos;
                      final target = remainingTime.isNegative
                          ? const Duration(seconds: 30)
                          : remainingTime;
                      timerService.start(
                        duration: target,
                        label: 'track',
                        onFinish: () => audioHandler.pause(),
                      );
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                  if (active) ...[
                    const SizedBox(height: 10),
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      tileColor: Colors.white.withValues(alpha: 0.06),
                      leading: const Icon(Icons.close_rounded, color: Colors.white70),
                      title: const Text(
                        'Turn Off Timer',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                      onTap: () {
                        timerService.cancel();
                        Navigator.of(sheetContext).pop();
                      },
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _TimerOptionTile extends StatelessWidget {
  const _TimerOptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        tileColor: selected
            ? MeloColors.cherry.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.05),
        title: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        trailing: selected
            ? const Icon(Icons.check_circle_rounded, color: MeloColors.cherry, size: 20)
            : null,
        onTap: onTap,
      ),
    );
  }
}
