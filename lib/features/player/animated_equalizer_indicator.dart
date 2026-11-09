import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:melo_player/app/melo_theme.dart';

/// A sleek, lightweight animated equalizer indicator featuring 3-4 bouncing
/// audio visualizer bars. Used in song rows, artwork overlays, and active queues.
class AnimatedEqualizerIndicator extends StatefulWidget {
  const AnimatedEqualizerIndicator({
    this.color = MeloColors.cherry,
    this.size = 20,
    this.barCount = 3,
    this.isPlaying = true,
    super.key,
  });

  final Color color;
  final double size;
  final int barCount;
  final bool isPlaying;

  @override
  State<AnimatedEqualizerIndicator> createState() =>
      _AnimatedEqualizerIndicatorState();
}

class _AnimatedEqualizerIndicatorState
    extends State<AnimatedEqualizerIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedEqualizerIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _EqualizerBarsPainter(
              progress: _controller.value,
              color: widget.color,
              barCount: widget.barCount,
            ),
          );
        },
      ),
    );
  }
}

class _EqualizerBarsPainter extends CustomPainter {
  const _EqualizerBarsPainter({
    required this.progress,
    required this.color,
    required this.barCount,
  });

  final double progress;
  final Color color;
  final int barCount;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final barWidth = size.width / (barCount * 2 - 1);
    final maxHeight = size.height * 0.95;
    final minHeight = size.height * 0.22;

    for (var i = 0; i < barCount; i++) {
      // Stagger phases so bars dance independently
      final phaseOffset = (i * 0.33 * math.pi * 2);
      final rawFactor = (math.sin((progress * math.pi * 2) + phaseOffset) + 1) / 2;
      // Shape the curve so bars feel responsive like real sound levels
      final factor = math.pow(rawFactor, 1.2).toDouble();
      final barHeight = minHeight + (maxHeight - minHeight) * factor;

      final left = i * (barWidth * 2);
      final top = size.height - barHeight;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, barWidth, barHeight),
        Radius.circular(barWidth * 0.5),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _EqualizerBarsPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
