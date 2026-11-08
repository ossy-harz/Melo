String formatPlaybackTime(int milliseconds) {
  final totalSeconds = (milliseconds / 1000).floor();
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
