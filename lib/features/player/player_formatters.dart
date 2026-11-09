String formatPlaybackTime(int milliseconds) {
  final totalSeconds = (milliseconds / 1000).floor();
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

String formatNegativeRemainingTime(int elapsedMs, int totalMs) {
  if (totalMs <= 0) return '-0:00';
  final remainingMs = (totalMs - elapsedMs).clamp(0, totalMs);
  final totalSeconds = (remainingMs / 1000).floor();
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '-$minutes:${seconds.toString().padLeft(2, '0')}';
}

