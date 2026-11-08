import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:melo_player/app/melo_theme.dart';

/// A tinted surface with optional backdrop blur.
///
/// The tint and border adapt to the ambient theme, but callers can override
/// both when a surface should always read as dark (for example the lyrics
/// sheet that floats above the player). Blur is opt-in to keep scrolling and
/// playback surfaces inexpensive to composite.
class MeloGlass extends StatelessWidget {
  const MeloGlass({
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.borderRadius = 26,
    this.blur = 0,
    this.tint,
    this.borderColor,
    this.shadow = true,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final double borderRadius;
  final double blur;
  final Color? tint;
  final Color? borderColor;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final radius = BorderRadius.circular(borderRadius);
    final resolvedTint =
        tint ??
        (isLight ? Colors.white.withValues(alpha: 0.62) : MeloColors.glassTint);
    final resolvedBorder =
        borderColor ??
        (isLight
            ? Colors.white.withValues(alpha: 0.85)
            : MeloColors.glassBorder);

    final decoratedSurface = DecoratedBox(
      decoration: BoxDecoration(
        color: resolvedTint,
        borderRadius: radius,
        border: Border.all(color: resolvedBorder),
      ),
      child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
    );
    final effectiveBlur = blur.clamp(0, 14).toDouble();
    Widget surface = ClipRRect(
      borderRadius: radius,
      child: effectiveBlur > 0
          ? BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: effectiveBlur,
                sigmaY: effectiveBlur,
              ),
              child: decoratedSurface,
            )
          : decoratedSurface,
    );

    if (shadow) {
      surface = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: isLight
                  ? Colors.black.withValues(alpha: 0.08)
                  : MeloColors.glassShadow,
              blurRadius: isLight ? 22 : 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: surface,
      );
    }

    return Container(
      width: width,
      height: height,
      margin: margin,
      child: surface,
    );
  }
}

/// A whisper of film grain. Applied over large artwork-driven surfaces so they
/// read as physical material rather than flat digital colour.
class MeloGrain extends StatelessWidget {
  const MeloGrain({this.opacity = 0.05, this.density = 0.00028, super.key});

  final double opacity;
  final double density;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: CustomPaint(
        painter: _GrainPainter(opacity: opacity, density: density),
        size: Size.infinite,
      ),
    ),
  );
}

class _GrainPainter extends CustomPainter {
  const _GrainPainter({required this.opacity, required this.density});

  final double opacity;
  final double density;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final count = (size.width * size.height * density)
        .clamp(96.0, 900.0)
        .toInt();
    final random = math.Random(7);
    final points = List<Offset>.generate(
      count,
      (_) => Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      ),
      growable: false,
    );
    canvas.drawPoints(
      PointMode.points,
      points,
      Paint()
        ..color = Colors.white.withValues(alpha: opacity)
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_GrainPainter oldDelegate) =>
      oldDelegate.opacity != opacity || oldDelegate.density != density;
}
