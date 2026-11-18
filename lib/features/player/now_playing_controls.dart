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
  Widget build(BuildContext context) {
    final tooltipText = transitioning
        ? 'Cancel the manual crossfade. Progress tracks gain-ramp commands, not rendered audio output.'
        : 'Manually crossfade to the next track over 10 seconds';
    return Tooltip(
      message: tooltipText,
      child: Semantics(
        button: true,
        label: transitioning
            ? 'Cancel crossfade'
            : (nextTrackTitle == null || nextTrackTitle!.isEmpty
                ? 'Crossfade to next track'
                : 'Crossfade to $nextTrackTitle'),
        value: transitioning
            ? '${(progress.clamp(0, 1) * 100).round()}%'
            : null,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            customBorder: const CircleBorder(),
            child: AnimatedContainer(
              duration: MeloMotion.respecting(context, MeloMotion.fast),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: transitioning
                    ? accent.withValues(alpha: 0.22)
                    : Colors.white.withValues(alpha: 0.08),
                border: Border.all(
                  color: transitioning
                      ? accent.withValues(alpha: 0.55)
                      : Colors.white.withValues(alpha: 0.14),
                  width: 0.9,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (transitioning)
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        value: progress > 0 ? progress.clamp(0, 1) : null,
                        strokeWidth: 2.2,
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        valueColor: AlwaysStoppedAnimation<Color>(accent),
                      ),
                    ),
                  Icon(
                    transitioning
                        ? Icons.close_rounded
                        : Icons.multitrack_audio_rounded,
                    color: enabled
                        ? (transitioning ? accent : Colors.white)
                        : Colors.white38,
                    size: transitioning ? 17 : 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A soft, tempo-adaptive pulse around the artwork. It reads the live playback
/// position so it stays honest: a tagged tempo drives a beat pulse, and a track
/// without one falls back to a slow ambient breath.
class _BeatPulse extends StatelessWidget {
  const _BeatPulse({
    required this.audioHandler,
    required this.bpm,
    required this.live,
    required this.child,
  });

  final AudioHandler audioHandler;
  final double? bpm;
  final bool live;
  final Widget child;

  double _quantizedLevel(Duration position) {
    if (!audioHandler.playbackState.value.playing) return 0.0;
    final raw = _beatLevel(position, bpm);
    return (raw * 20).round() / 20.0;
  }

  @override
  Widget build(BuildContext context) {
    // The pulse is purely decorative, so stand down entirely when not live or
    // when the platform asks for reduced motion.
    if (!live || MeloMotion.reduced(context)) return child;
    final initialLevel = _quantizedLevel(
      audioHandler.playbackState.value.updatePosition,
    );
    return StreamBuilder<double>(
      initialData: initialLevel,
      stream: playbackPositionStream(
        audioHandler,
      ).map(_quantizedLevel).distinct(),
      builder: (context, snapshot) {
        final level = audioHandler.playbackState.value.playing
            ? (snapshot.data ?? 0.0)
            : 0.0;
        return AnimatedScale(
          scale: 1 + level * 0.018,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          child: child,
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
                color: shuffleOn ? MeloColors.cherry : MeloColors.playerMuted,
                iconSize: 22,
              ),
              if (shuffleOn)
                Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: MeloColors.cherry,
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
            color: MeloColors.playerText,
            iconSize: 34,
          ),
          GestureDetector(
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            child: AnimatedScale(
              scale: _isPressed ? 0.92 : 1.0,
              duration: MeloMotion.fast,
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
                      MeloColors.cherryGlow,
                      MeloColors.cherry,
                      MeloColors.cherryDeep,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: MeloColors.cherry.withValues(
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
                    duration: MeloMotion.fast,
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
            color: MeloColors.playerText,
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
                color: repeatOn ? MeloColors.cherry : MeloColors.playerMuted,
                iconSize: 22,
              ),
              if (repeatOn)
                Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: MeloColors.cherry,
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
