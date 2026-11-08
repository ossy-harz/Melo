part of 'mini_player.dart';

class _PlaybackSeekBar extends StatefulWidget {
  const _PlaybackSeekBar({
    required this.value,
    required this.max,
    required this.duration,
    required this.waveform,
    required this.waveformError,
    required this.bpm,
    required this.mixMarkerPosition,
    this.bufferedPosition,
    required this.onRetry,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final double value;
  final double max;
  final Duration duration;
  final List<double>? waveform;
  final Object? waveformError;
  final double? bpm;
  final Duration? mixMarkerPosition;
  final Duration? bufferedPosition;
  final VoidCallback onRetry;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  State<_PlaybackSeekBar> createState() => _PlaybackSeekBarState();
}

class _PlaybackSeekBarState extends State<_PlaybackSeekBar> {
  bool _isDragging = false;
  bool _showRemainingTime = false;

  @override
  Widget build(BuildContext context) {
    final hasWaveform = widget.waveform != null;
    final progressRatio = (widget.value / widget.max).clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            const horizontalPadding = 12.0;
            final trackWidth = math.max(
              0.0,
              constraints.maxWidth - horizontalPadding * 2,
            );
            final thumbX = horizontalPadding + trackWidth * progressRatio;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: hasWaveform ? 34 : 5.5,
                    trackShape: _ModernSeekBarTrack(
                      hasWaveform: hasWaveform,
                      waveform: widget.waveform,
                      durationMs: widget.duration.inMilliseconds,
                      bufferedPositionMs:
                          widget.bufferedPosition?.inMilliseconds,
                      activeColor: MeloColors.cherry,
                      inactiveColor: Colors.white.withValues(alpha: 0.18),
                      bpm: widget.bpm,
                      mixMarkerPositionMs:
                          widget.mixMarkerPosition?.inMilliseconds,
                      isDragging: _isDragging,
                    ),
                    thumbShape: _SeekBarThumb(
                      activeColor: MeloColors.cherry,
                      isDragging: _isDragging,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 18,
                    ),
                    activeTrackColor: Colors.transparent,
                    inactiveTrackColor: Colors.transparent,
                    thumbColor: MeloColors.cherry,
                    overlayColor: MeloColors.cherry.withValues(alpha: 0.22),
                  ),
                  child: Semantics(
                    label: hasWaveform
                        ? widget.mixMarkerPosition == null
                            ? 'Audio waveform playback position'
                            : 'Audio waveform playback position; quiet outro estimate at ${_formatTime(widget.mixMarkerPosition!.inMilliseconds)}'
                        : 'Playback position',
                    value:
                        '${_formatTime(widget.value.round())} of ${widget.duration > Duration.zero ? _formatTime(widget.duration.inMilliseconds) : '--:--'}',
                    child: Slider(
                      value: widget.value.clamp(0, widget.max),
                      max: widget.max,
                      onChangeStart: widget.duration > Duration.zero
                          ? (_) {
                              HapticFeedback.selectionClick();
                              setState(() => _isDragging = true);
                            }
                          : null,
                      onChanged: widget.duration > Duration.zero
                          ? (value) {
                              if (!_isDragging) {
                                setState(() => _isDragging = true);
                              }
                              widget.onChanged(value);
                            }
                          : null,
                      onChangeEnd: widget.duration > Duration.zero
                          ? (value) {
                              HapticFeedback.selectionClick();
                              setState(() => _isDragging = false);
                              widget.onChangeEnd(value);
                            }
                          : null,
                    ),
                  ),
                ),
                if (_isDragging)
                  Positioned(
                    left: (thumbX - 28).clamp(
                      0.0,
                      math.max(0.0, constraints.maxWidth - 56.0),
                    ),
                    top: hasWaveform ? -22 : -20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: MeloColors.cherrySoft.withValues(alpha: 0.5),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: MeloColors.cherry.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        _formatTime(widget.value.round()),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        if (widget.waveformError != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: widget.waveformError is UnsupportedError
                  ? null
                  : widget.onRetry,
              style: TextButton.styleFrom(
                foregroundColor: MeloColors.playerMuted,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: const Size(44, 28),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 14),
              label: Text(
                widget.waveformError is UnsupportedError
                    ? 'Waveform unavailable'
                    : 'Retry waveform',
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatTime(widget.value.round()),
                style: const TextStyle(
                  color: MeloColors.playerText,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _showRemainingTime = !_showRemainingTime);
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    widget.duration > Duration.zero
                        ? (_showRemainingTime
                            ? '-${_formatTime(math.max(0, widget.duration.inMilliseconds - widget.value.round()))}'
                            : _formatTime(widget.duration.inMilliseconds))
                        : '--:--',
                    style: TextStyle(
                      color: _showRemainingTime
                          ? MeloColors.cherrySoft
                          : MeloColors.playerMuted,
                      fontSize: 11.5,
                      fontWeight: _showRemainingTime
                          ? FontWeight.w700
                          : FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Custom slider track that paints the playback bar with a soft glow behind
/// the played segment, an optional waveform, a quiet-outro mix marker and BPM
/// measure lines. The default track colours are suppressed (transparent) so
/// this shape owns the entire track rendering.
class _ModernSeekBarTrack extends SliderTrackShape {
  const _ModernSeekBarTrack({
    required this.hasWaveform,
    required this.waveform,
    required this.durationMs,
    this.bufferedPositionMs,
    required this.activeColor,
    required this.inactiveColor,
    required this.bpm,
    required this.mixMarkerPositionMs,
    this.isDragging = false,
  });

  final bool hasWaveform;
  final List<double>? waveform;
  final int durationMs;
  final int? bufferedPositionMs;
  final Color activeColor;
  final Color inactiveColor;
  final double? bpm;
  final int? mixMarkerPositionMs;
  final bool isDragging;

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final height = hasWaveform ? 44.0 : 6.0;
    return Rect.fromLTWH(
      offset.dx,
      offset.dy + (parentBox.size.height - height) / 2,
      parentBox.size.width,
      height,
    );
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
  }) {
    final canvas = context.canvas;
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    if (rect.width <= 0 || rect.height <= 0) return;

    final midY = rect.center.dy;
    final playedRatio =
        ((thumbCenter.dx - rect.left) / rect.width).clamp(0.0, 1.0);
    final playedX = rect.left + rect.width * playedRatio;

    if (hasWaveform && waveform != null && waveform!.isNotEmpty) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(16)),
        Paint()..color = Colors.white.withValues(alpha: 0.04),
      );
      _paintWaveform(canvas, rect, midY, playedX);
    } else {
      final trackHeight = isDragging ? 8.5 : 5.5;
      final trackRect = Rect.fromCenter(
        center: Offset(rect.center.dx, midY),
        width: rect.width,
        height: trackHeight,
      );

      // Inactive bed
      canvas.drawRRect(
        RRect.fromRectAndRadius(trackRect, Radius.circular(trackHeight / 2)),
        Paint()..color = inactiveColor.withValues(alpha: 0.22),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(trackRect, Radius.circular(trackHeight / 2)),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );

      // Buffered segment (for streaming & preloading)
      final bufferedMs = bufferedPositionMs ?? 0;
      if (bufferedMs > 0 && durationMs > 0) {
        final bufferedRatio = (bufferedMs / durationMs).clamp(0.0, 1.0);
        final bufferedX = rect.left + rect.width * bufferedRatio;
        if (bufferedX > playedX) {
          final bufferedRect = Rect.fromLTRB(
            playedX,
            midY - trackHeight / 2,
            bufferedX,
            midY + trackHeight / 2,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              bufferedRect,
              Radius.circular(trackHeight / 2),
            ),
            Paint()..color = Colors.white.withValues(alpha: 0.16),
          );
        }
      }

      if (playedX > rect.left) {
        final playedRect = Rect.fromLTRB(
          rect.left,
          midY - trackHeight / 2,
          playedX,
          midY + trackHeight / 2,
        );

        // Soft outer glow
        final glowRect = Rect.fromLTRB(
          rect.left,
          midY - trackHeight / 2 - 4,
          playedX,
          midY + trackHeight / 2 + 4,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            glowRect,
            Radius.circular((trackHeight + 8) / 2),
          ),
          Paint()
            ..color = activeColor.withValues(alpha: 0.38)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
        );

        // Core played gradient
        final activePaint = Paint()
          ..shader = ui.Gradient.linear(
            Offset(rect.left, midY),
            Offset(math.max(rect.left + 1, playedX), midY),
            [activeColor, MeloColors.cherryGlow],
          );
        canvas.drawRRect(
          RRect.fromRectAndRadius(playedRect, Radius.circular(trackHeight / 2)),
          activePaint,
        );

        // Specular tip highlight
        canvas.drawCircle(
          Offset(playedX, midY),
          trackHeight / 2,
          Paint()..color = Colors.white.withValues(alpha: 0.6),
        );
      }
    }

    // Quiet-outro mix marker.
    final mixMarker = mixMarkerPositionMs;
    if (mixMarker != null && durationMs > 0) {
      final markerRatio = mixMarker / durationMs;
      if (markerRatio >= 0 && markerRatio <= 1) {
        final x = rect.left + rect.width * markerRatio;
        canvas.drawLine(
          Offset(x, rect.top + 2),
          Offset(x, rect.bottom - 2),
          Paint()
            ..color = MeloColors.cherrySoft
            ..strokeWidth = 1.6,
        );
        canvas.drawCircle(
          Offset(x, rect.top + 3),
          3.0,
          Paint()..color = MeloColors.cherryGlow,
        );
        canvas.drawCircle(
          Offset(x, rect.top + 3),
          1.5,
          Paint()..color = Colors.white,
        );
      }
    }

    // BPM measure lines.
    final tempo = bpm;
    if (tempo == null || !tempo.isFinite || tempo < 40 || tempo > 240) return;
    final beatMs = 60000 / tempo;
    final measureMs = beatMs * 4;
    final measureCount = durationMs / measureMs;
    if (!measureCount.isFinite || measureCount > 3000) return;
    final measurePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = 1;
    for (var measure = 1; measure < measureCount; measure++) {
      final x = rect.left + rect.width * (measure * measureMs / durationMs);
      canvas.drawLine(
        Offset(x, rect.bottom - 6),
        Offset(x, rect.bottom - 2),
        measurePaint,
      );
    }
  }

  void _paintWaveform(
    Canvas canvas,
    Rect rect,
    double midY,
    double playedX,
  ) {
    final amplitudes = waveform!;
    final barCount = math.min(
      amplitudes.length,
      math.max(1, (rect.width / 3.4).floor()),
    );
    final step = rect.width / barCount;
    final barWidth = math.min(2.0, step * 0.58);
    final playedPaint = Paint()
      ..color = activeColor
      ..isAntiAlias = true;
    final remainingPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..isAntiAlias = true;
    final playedGlow = Paint()
      ..color = activeColor.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
      ..isAntiAlias = true;

    for (var index = 0; index < barCount; index++) {
      final start = (index * amplitudes.length / barCount).floor();
      final end = math.max(
        start + 1,
        ((index + 1) * amplitudes.length / barCount).ceil(),
      );
      var peak = 0.0;
      for (var sample = start; sample < end; sample++) {
        peak = math.max(peak, amplitudes[sample]);
      }
      final x = rect.left + step * (index + 0.5);
      final height = (4 + math.pow(peak, 0.72) * 32)
          .clamp(4.0, rect.height - 4)
          .toDouble();
      final bar = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x, midY),
          width: barWidth,
          height: height,
        ),
        Radius.circular(barWidth / 2),
      );
      if (x <= playedX) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(x, midY),
              width: barWidth * 2.2,
              height: height + 2,
            ),
            Radius.circular(barWidth * 1.1),
          ),
          playedGlow,
        );
        canvas.drawRRect(bar, playedPaint);
      } else {
        canvas.drawRRect(bar, remainingPaint);
      }
    }

    if (playedX >= rect.left && playedX <= rect.right) {
      canvas.drawLine(
        Offset(playedX, midY - 18),
        Offset(playedX, midY + 18),
        Paint()
          ..color = Colors.white
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round,
      );
    }
  }
}

/// Thumb with a soft cherry halo, specular center light and smooth active scale.
class _SeekBarThumb extends SliderComponentShape {
  const _SeekBarThumb({
    required this.activeColor,
    this.isDragging = false,
  });

  final Color activeColor;
  final bool isDragging;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size(20, 20);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final baseRadius = isDragging ? 10.5 : 8.5;

    // Radiant outer halo
    canvas.drawCircle(
      center,
      baseRadius + (isDragging ? 8.0 : 5.0),
      Paint()
        ..color = activeColor.withValues(alpha: isDragging ? 0.45 : 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Outer glass ring
    canvas.drawCircle(
      center,
      baseRadius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );

    // Thumb body
    canvas.drawCircle(
      center,
      baseRadius - 0.9,
      Paint()..color = activeColor,
    );

    // Specular center light
    canvas.drawCircle(
      center,
      baseRadius * 0.42,
      Paint()..color = Colors.white,
    );
  }
}
