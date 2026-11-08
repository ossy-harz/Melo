part of 'mini_player.dart';

class _MixNextControl extends StatelessWidget {
  const _MixNextControl({
    required this.transitioning,
    required this.enabled,
    required this.accent,
    required this.progress,
    required this.transitionDuration,
    required this.analysisHint,
    required this.nextTrackTitle,
    required this.onPressed,
  });

  final bool transitioning;
  final bool enabled;
  final Color accent;
  final double progress;
  final Duration? transitionDuration;
  final String? analysisHint;
  final String? nextTrackTitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: transitioning
        ? 'Cancel the manual crossfade. Progress tracks gain-ramp commands, not rendered audio output.'
        : 'Manually crossfade to the next track over 10 seconds',
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: ToneMotion.respecting(context, ToneMotion.fast),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: transitioning
                  ? [
                      accent.withValues(alpha: 0.26),
                      Colors.white.withValues(alpha: 0.09),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.09),
                      Colors.white.withValues(alpha: 0.035),
                    ],
            ),
            border: Border.all(
              color: transitioning
                  ? accent.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.13),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  AnimatedContainer(
                    duration: ToneMotion.respecting(context, ToneMotion.fast),
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: transitioning
                          ? accent.withValues(alpha: 0.26)
                          : Colors.white.withValues(alpha: 0.08),
                    ),
                    child: Icon(
                      transitioning
                          ? Icons.close_rounded
                          : Icons.multitrack_audio_rounded,
                      color: ToneColors.playerText,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          transitioning ? 'MIXING' : 'MIX NEXT',
                          style: TextStyle(
                            color: transitioning
                                ? accent
                                : ToneColors.playerMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _transitionLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ToneColors.playerText,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (analysisHint != null) ...[
                          const SizedBox(height: 2),
                          Semantics(
                            label:
                                '$analysisHint. Relative waveform energy estimate; not beat or phrase detection.',
                            child: Text(
                              analysisHint!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: ToneColors.playerMuted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (transitioning) ...[
                    const SizedBox(width: 8),
                    _MixActivityWaveform(
                      active: true,
                      color: accent,
                    ),
                  ],
                ],
              ),
              if (transitioning) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0, 1),
                    minHeight: 4,
                    backgroundColor: Colors.white.withValues(alpha: 0.14),
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                    semanticsLabel:
                        'Gain ramp command progress; not rendered audio output',
                    semanticsValue:
                        '${(progress.clamp(0, 1) * 100).round()}',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );

  String get _transitionLabel {
    if (!transitioning) return 'Manual crossfade · 10 sec';
    final duration = transitionDuration;
    if (duration == null) return 'Preparing mix · tap to cancel';
    final percentage = (progress.clamp(0, 1) * 100).round();
    return 'Gain ramp $percentage% · '
        '${_formatTime(duration.inMilliseconds)} target';
  }
}

class _MixActivityWaveform extends StatefulWidget {
  const _MixActivityWaveform({required this.active, required this.color});

  final bool active;
  final Color color;

  @override
  State<_MixActivityWaveform> createState() => _MixActivityWaveformState();
}

class _MixActivityWaveformState extends State<_MixActivityWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _MixActivityWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active || oldWidget.color != widget.color) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (widget.active && !ToneMotion.reduced(context)) {
      _controller.repeat();
    } else {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        size: const Size(42, 28),
        painter: _MixActivityWaveformPainter(
          phase: _controller.value,
          color: widget.color,
          active: widget.active,
        ),
      ),
    ),
  );
}

class _MixActivityWaveformPainter extends CustomPainter {
  const _MixActivityWaveformPainter({
    required this.phase,
    required this.color,
    required this.active,
  });

  final double phase;
  final Color color;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    const count = 9;
    const barWidth = 2.5;
    final gap = (size.width - count * barWidth) / (count - 1);
    final paint = Paint()
      ..color = color.withValues(alpha: active ? 0.95 : 0.68)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;

    for (var index = 0; index < count; index++) {
      final wave = math.sin(index * 1.15 + phase * math.pi * 2).abs();
      final level = active ? 0.2 + wave * 0.8 : 0.25 + wave * 0.35;
      final height = 6 + (size.height - 6) * level;
      final x = index * (barWidth + gap) + barWidth / 2;
      canvas.drawLine(
        Offset(x, (size.height - height) / 2),
        Offset(x, (size.height + height) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MixActivityWaveformPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.color != color ||
      oldDelegate.active != active;
}

/// A soft, tempo-adaptive pulse around the artwork. It reads the live playback
/// position so it stays honest: a tagged tempo drives a beat pulse, and a track
/// without one falls back to a slow ambient breath.
class _BeatPulse extends StatelessWidget {
  const _BeatPulse({
    required this.audioHandler,
    required this.bpm,
    required this.live,
    required this.palette,
    required this.child,
  });

  final AudioHandler audioHandler;
  final double? bpm;
  final bool live;
  final TonePalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // The pulse is purely decorative, so stand down entirely when the platform
    // asks for reduced motion.
    if (ToneMotion.reduced(context)) return child;
    return StreamBuilder<Duration>(
      stream: playbackPositionStream(audioHandler),
      builder: (context, snapshot) {
        final playing = audioHandler.playbackState.value.playing;
        final level = (!playing || !live)
            ? 0.0
            : _beatLevel(snapshot.data ?? Duration.zero, bpm);
        return AnimatedScale(
          scale: 1 + level * 0.03,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: palette.accent.withValues(alpha: 0.2 * level),
                  blurRadius: 72 * level,
                  spreadRadius: 16 * level,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
    );
  }
}

/// How far we are into the current beat (or ambient breath): 1 on the beat,
/// decaying toward 0 before the next one.
double _beatLevel(Duration position, double? bpm) {
  final period = bpm == null ? 2400.0 : (60000 / bpm).clamp(200.0, 2400.0);
  return 1 - (position.inMilliseconds % period) / period;
}

class _PlaybackControls extends StatefulWidget {
  const _PlaybackControls({
    required this.playing,
    required this.shuffleMode,
    required this.repeatMode,
    required this.onShuffle,
    required this.onPrevious,
    required this.onToggle,
    required this.onNext,
    required this.onRepeat,
  });

  final bool playing;
  final AudioServiceShuffleMode shuffleMode;
  final AudioServiceRepeatMode repeatMode;
  final VoidCallback onShuffle;
  final VoidCallback onPrevious;
  final VoidCallback onToggle;
  final VoidCallback onNext;
  final VoidCallback onRepeat;

  @override
  State<_PlaybackControls> createState() => _PlaybackControlsState();
}

class _PlaybackControlsState extends State<_PlaybackControls> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final shuffleOn = widget.shuffleMode == AudioServiceShuffleMode.all;
    final repeatOn = widget.repeatMode != AudioServiceRepeatMode.none;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: shuffleOn ? 'Turn shuffle off' : 'Turn shuffle on',
                onPressed: widget.onShuffle,
                icon: const Icon(Icons.shuffle_rounded),
                color: shuffleOn ? ToneColors.cherry : ToneColors.playerMuted,
                iconSize: 22,
              ),
              if (shuffleOn)
                Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: ToneColors.cherry,
                  ),
                )
              else
                const SizedBox(height: 4),
            ],
          ),
          IconButton(
            tooltip: 'Previous track',
            onPressed: widget.onPrevious,
            icon: const Icon(Icons.skip_previous_rounded),
            color: ToneColors.playerText,
            iconSize: 34,
          ),
          GestureDetector(
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            child: AnimatedScale(
              scale: _isPressed ? 0.92 : 1.0,
              duration: ToneMotion.fast,
              curve: Curves.easeOutCubic,
              child: Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      ToneColors.cherryGlow,
                      ToneColors.cherry,
                      ToneColors.cherryDeep,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: ToneColors.cherry.withValues(
                        alpha: widget.playing ? 0.52 : 0.35,
                      ),
                      blurRadius: widget.playing ? 28 : 20,
                      spreadRadius: widget.playing ? 0 : -2,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.28),
                    width: 1.2,
                  ),
                ),
                child: IconButton(
                  tooltip: widget.playing ? 'Pause' : 'Play',
                  onPressed: widget.onToggle,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: const CircleBorder(),
                  ),
                  iconSize: 36,
                  icon: AnimatedSwitcher(
                    duration: ToneMotion.fast,
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    layoutBuilder: _safeAnimatedSwitcherLayout,
                    child: Icon(
                      widget.playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      key: ValueKey(widget.playing),
                    ),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Next track',
            onPressed: widget.onNext,
            icon: const Icon(Icons.skip_next_rounded),
            color: ToneColors.playerText,
            iconSize: 34,
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: repeatOn
                    ? widget.repeatMode == AudioServiceRepeatMode.one
                          ? 'Repeat one'
                          : 'Change repeat mode'
                    : 'Repeat all',
                onPressed: widget.onRepeat,
                icon: Icon(
                  widget.repeatMode == AudioServiceRepeatMode.one
                      ? Icons.repeat_one_rounded
                      : Icons.repeat_rounded,
                ),
                color: repeatOn ? ToneColors.cherry : ToneColors.playerMuted,
                iconSize: 22,
              ),
              if (repeatOn)
                Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: ToneColors.cherry,
                  ),
                )
              else
                const SizedBox(height: 4),
            ],
          ),
        ],
      ),
    );
  }
}
