import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:melo_player/app/melo_theme.dart';

class SleepTimerService extends ChangeNotifier {
  SleepTimerService._();
  static final SleepTimerService instance = SleepTimerService._();

  Timer? _timer;
  Timer? _uiTicker;
  DateTime? _targetTime;
  String? _label;
  int _sessionId = 0;

  bool get isActive => _timer != null && _timer!.isActive;
  String? get activeLabel => _label;

  Duration get remaining {
    if (_targetTime == null) return Duration.zero;
    final diff = _targetTime!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  String get compactRemainingLabel {
    final rem = remaining;
    if (rem <= Duration.zero) return '';
    final totalSeconds = rem.inSeconds;
    if (totalSeconds < 60) return '${totalSeconds}s';
    final minutes = (totalSeconds / 60).ceil();
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return m == 0 ? '${h}h' : '${h}h ${m}m';
    }
    return '${minutes}m';
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
      _clearState();
      onFinish();
    });
    _uiTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!isActive) {
        _uiTicker?.cancel();
        _uiTicker = null;
        return;
      }
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> _pauseWithFadeOut(AudioHandler audioHandler) async {
    final activeSession = ++_sessionId;
    var originalVolume = 1.0;
    var adjustedVolume = false;
    try {
      final currentVol = await audioHandler.customAction('getVolume');
      if (currentVol is num && currentVol.isFinite) {
        originalVolume = currentVol.toDouble().clamp(0.0, 1.0);
      }
      if (originalVolume > 0.05) {
        for (var step = 5; step >= 1; step--) {
          if (activeSession != _sessionId || isActive) break;
          await Future<void>.delayed(const Duration(milliseconds: 240));
          if (activeSession != _sessionId || isActive) break;
          await audioHandler.customAction('setVolume', {
            'volume': originalVolume * (step / 6),
          });
          adjustedVolume = true;
        }
      }
    } catch (_) {}
    if (activeSession == _sessionId && !isActive) {
      await audioHandler.pause();
    }
    if (adjustedVolume) {
      try {
        await audioHandler.customAction('setVolume', {'volume': originalVolume});
      } catch (_) {}
    }
  }

  void _clearState() {
    _timer?.cancel();
    _timer = null;
    _uiTicker?.cancel();
    _uiTicker = null;
    _targetTime = null;
    _label = null;
    notifyListeners();
  }

  void cancel() {
    _sessionId++;
    _clearState();
  }

  static Future<void> showSleepTimerDialog(
    BuildContext context,
    AudioHandler audioHandler,
  ) async {
    final timerService = instance;
    var customMinutes = 25.0;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return ListenableBuilder(
              listenable: timerService,
              builder: (context, _) {
                final active = timerService.isActive;
                final remainingText = timerService.compactRemainingLabel;
                void startPreset(Duration duration, String label) {
                  timerService.start(
                    duration: duration,
                    label: label,
                    onFinish: () =>
                        unawaited(timerService._pauseWithFadeOut(audioHandler)),
                  );
                  Navigator.of(sheetContext).pop();
                }

                return Material(
                  color: const Color(0xF01B1419),
                  shape: RoundedRectangleBorder(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.12),
                      width: 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: SafeArea(
                    top: false,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 38,
                              height: 4.5,
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(
                                Icons.bedtime_rounded,
                                color: MeloColors.cherry,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Sleep Timer',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                ),
                              ),
                              if (active && remainingText.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: MeloColors.cherry.withValues(
                                      alpha: 0.2,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: MeloColors.cherry,
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    '$remainingText left',
                                    style: TextStyle(
                                      color: MeloColors.cherrySoft,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 14),
                          _TimerOptionTile(
                            label: '15 Minutes',
                            selected: timerService.activeLabel == '15m',
                            onTap: () => startPreset(
                              const Duration(minutes: 15),
                              '15m',
                            ),
                          ),
                          _TimerOptionTile(
                            label: '30 Minutes',
                            selected: timerService.activeLabel == '30m',
                            onTap: () => startPreset(
                              const Duration(minutes: 30),
                              '30m',
                            ),
                          ),
                          _TimerOptionTile(
                            label: '45 Minutes',
                            selected: timerService.activeLabel == '45m',
                            onTap: () => startPreset(
                              const Duration(minutes: 45),
                              '45m',
                            ),
                          ),
                          _TimerOptionTile(
                            label: '1 Hour',
                            selected: timerService.activeLabel == '1h',
                            onTap: () => startPreset(
                              const Duration(hours: 1),
                              '1h',
                            ),
                          ),
                          _TimerOptionTile(
                            label: 'End of current track',
                            selected: timerService.activeLabel == 'track',
                            onTap: () {
                              final currentItem = audioHandler.mediaItem.value;
                              final playback = audioHandler.playbackState.value;
                              final total =
                                  currentItem?.duration ??
                                  const Duration(minutes: 3);
                              final pos = playback.position;
                              final remainingTime = total - pos;
                              final target = remainingTime <= Duration.zero
                                  ? const Duration(seconds: 30)
                                  : remainingTime;
                              startPreset(target, 'track');
                            },
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'Custom duration',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${customMinutes.round()} min',
                                      style: TextStyle(
                                        color: MeloColors.cherrySoft,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    activeTrackColor: MeloColors.cherry,
                                    inactiveTrackColor: Colors.white12,
                                    thumbColor: Colors.white,
                                    overlayColor: MeloColors.cherry.withValues(
                                      alpha: 0.2,
                                    ),
                                  ),
                                  child: Slider(
                                    value: customMinutes,
                                    min: 5,
                                    max: 120,
                                    divisions: 23,
                                    onChanged: (value) => setSheetState(
                                      () => customMinutes = value,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: MeloColors.cherry,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: () {
                                      final mins = customMinutes.round();
                                      startPreset(
                                        Duration(minutes: mins),
                                        'custom:$mins',
                                      );
                                    },
                                    child: Text(
                                      'Start ${customMinutes.round()}m timer',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (active) ...[
                            const SizedBox(height: 10),
                            Material(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(14),
                              clipBehavior: Clip.antiAlias,
                              child: ListTile(
                                tileColor: Colors.transparent,
                                leading: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white70,
                                ),
                                title: const Text(
                                  'Turn Off Timer',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                onTap: () {
                                  timerService.cancel();
                                  Navigator.of(sheetContext).pop();
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
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
      child: Material(
        color: selected
            ? MeloColors.cherry.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          tileColor: Colors.transparent,
          title: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
          trailing: selected
              ? Icon(
                  Icons.check_circle_rounded,
                  color: MeloColors.cherry,
                  size: 20,
                )
              : null,
          onTap: onTap,
        ),
      ),
    );
  }
}
