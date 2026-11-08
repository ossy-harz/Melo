import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A small, artwork-derived colour set used to tint player and hero surfaces.
///
/// Tone never shows a flat, generic backdrop: the current album drives the
/// accent glow and the deep gradient wash behind the Now Playing screen.
@immutable
class TonePalette {
  const TonePalette({
    required this.accent,
    required this.deep,
    required this.muted,
  });

  /// Vivid, artwork-forward colour for accents and glows.
  final Color accent;

  /// Very dark, low-saturation wash used as the gradient base.
  final Color deep;

  /// Mid-tone, desaturated colour for layering.
  final Color muted;

  /// Used when artwork is missing or effectively monochrome.
  static const fallback = TonePalette(
    accent: Color(0xFFFF3D5A),
    deep: Color(0xFF180509),
    muted: Color(0xFF50101F),
  );

  /// A tasteful, deterministic palette for artwork-less items so the UI never
  /// degrades into random pastel gradients.
  factory TonePalette.fromSeed(int seed) {
    final hue = (seed.abs() % 360).toDouble();
    final accent = HSLColor.fromAHSL(1, hue, 0.66, 0.58).toColor();
    final deep = HSLColor.fromAHSL(1, hue, 0.55, 0.1).toColor();
    final muted = HSLColor.fromAHSL(1, hue, 0.5, 0.24).toColor();
    return TonePalette(accent: accent, deep: deep, muted: muted);
  }
}

/// Downsamples [bytes] and extracts a dominant palette. Returns `null` when the
/// image is unreadable or effectively monochrome.
Future<TonePalette?> tonePaletteFromBytes(Uint8List? bytes) async {
  if (bytes == null || bytes.isEmpty) return null;
  ui.Image? image;
  ui.Codec? codec;
  try {
    codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 40,
      targetHeight: 40,
    );
    final frame = await codec.getNextFrame();
    image = frame.image;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;
    return _paletteFromPixels(data);
  } on Object {
    return null;
  } finally {
    image?.dispose();
    codec?.dispose();
  }
}

TonePalette? _paletteFromPixels(ByteData data) {
  final bytes = data.buffer.asUint8List();
  const buckets = 12;
  final weights = List<double>.filled(buckets, 0);
  final reds = List<double>.filled(buckets, 0);
  final greens = List<double>.filled(buckets, 0);
  final blues = List<double>.filled(buckets, 0);

  for (var i = 0; i + 3 < bytes.length; i += 4) {
    if (bytes[i + 3] < 128) continue;
    final hsl = HSLColor.fromColor(
      Color.fromARGB(255, bytes[i], bytes[i + 1], bytes[i + 2]),
    );
    final lightness = hsl.lightness;
    final saturation = hsl.saturation;
    if (lightness < 0.12 || lightness > 0.94 || saturation < 0.12) continue;
    final bucket = (hsl.hue / 360 * buckets).floor().clamp(0, buckets - 1);
    final centered = 1 - (lightness - 0.5).abs() * 1.6;
    final weight = saturation * centered.clamp(0.0, 1.0);
    weights[bucket] += weight;
    reds[bucket] += bytes[i] * weight;
    greens[bucket] += bytes[i + 1] * weight;
    blues[bucket] += bytes[i + 2] * weight;
  }

  var best = -1;
  var bestWeight = 0.0;
  var total = 0.0;
  for (var i = 0; i < buckets; i++) {
    total += weights[i];
    if (weights[i] > bestWeight) {
      bestWeight = weights[i];
      best = i;
    }
  }
  if (best < 0 || total < 6 || bestWeight <= 0) return null;

  final avg = Color.fromARGB(
    255,
    (reds[best] / bestWeight).round().clamp(0, 255),
    (greens[best] / bestWeight).round().clamp(0, 255),
    (blues[best] / bestWeight).round().clamp(0, 255),
  );
  final hsl = HSLColor.fromColor(avg);

  return TonePalette(
    accent: HSLColor.fromAHSL(
      1,
      hsl.hue,
      hsl.saturation.clamp(0.55, 0.95),
      hsl.lightness.clamp(0.52, 0.66),
    ).toColor(),
    deep: HSLColor.fromAHSL(1, hsl.hue, 0.6, 0.09).toColor(),
    muted: HSLColor.fromAHSL(1, hsl.hue, 0.55, 0.22).toColor(),
  );
}
