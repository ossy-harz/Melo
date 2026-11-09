import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:melo_player/app/melo_theme.dart';
import 'package:melo_player/features/library/imported_track.dart';
import 'package:melo_player/features/player/animated_equalizer_indicator.dart';
import 'package:melo_player/features/player/mini_player.dart';
import 'package:melo_player/features/player/player_device_helper.dart';
import 'package:melo_player/features/player/player_formatters.dart';
import 'package:melo_player/features/player/player_volume_slider.dart';
import 'package:melo_player/features/player/melo_audio_handler.dart';

void showPlayerQueue(BuildContext context, AudioHandler handler) {
  final queue = handler.queue.value;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.60),
    builder: (context) => StreamBuilder<List<MediaItem>>(
      stream: handler.queue,
      initialData: queue,
      builder: (context, queueSnapshot) {
        final currentQueue = queueSnapshot.data ?? const <MediaItem>[];
        return StreamBuilder<PlaybackState>(
          stream: handler.playbackState,
          initialData: handler.playbackState.value,
          builder: (context, stateSnapshot) {
            if (currentQueue.isEmpty) {
              return const SizedBox(
                height: 200,
                child: Center(
                  child: Text(
                    'The queue is empty.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              );
            }
            final reportedIndex =
                stateSnapshot.data?.queueIndex ??
                currentQueue.indexWhere(
                  (item) => item.id == handler.mediaItem.value?.id,
                );
            final currentIndex =
                reportedIndex >= 0 && reportedIndex < currentQueue.length
                    ? reportedIndex
                    : 0;
            final upcomingIndices = handler is MeloAudioHandler
                ? handler.upcomingQueueIndices
                : List<int>.generate(
                    currentQueue.length - currentIndex - 1,
                    (index) => currentIndex + index + 1,
                  );
            final isAutoplay = handler is MeloAudioHandler
                ? handler.autoplayContinuous
                : true;

            return PlayerQueueSheet(
              items: currentQueue,
              currentIndex: currentIndex,
              upcomingIndices: upcomingIndices,
              isAutoplay: isAutoplay,
              audioHandler: handler,
              playbackState: stateSnapshot.data,
              onToggleAutoplay: () => handler.customAction('autoplay.toggle'),
              onSelect: (index) {
                Navigator.of(context).pop();
                _runQueueAction(
                  context,
                  () => handler.skipToQueueItem(index),
                  'Could not play that queued track',
                );
              },
              onRemove: (item) => _runQueueAction(
                context,
                () => handler.removeQueueItem(item),
                'Could not remove that queued track',
              ),
              onReorder: handler is MeloAudioHandler
                  ? (oldIndex, newIndex) => _runQueueAction(
                      context,
                      () async {
                        await handler.customAction('reorderUpcomingQueue', {
                          'oldIndex': oldIndex,
                          'newIndex': newIndex,
                        });
                      },
                      'Could not reorder the queue',
                    )
                  : null,
              onClear: () => _runQueueAction(
                context,
                () => _clearQueue(handler, currentQueue, upcomingIndices),
                'Could not clear the queue',
              ),
            );
          },
        );
      },
    ),
  );
}

Future<void> _clearQueue(
  AudioHandler handler,
  List<MediaItem> queue,
  List<int> upcomingIndices,
) async {
  if (handler is MeloAudioHandler) {
    await handler.customAction('clearUpcomingQueue');
    return;
  }
  for (final index in upcomingIndices.reversed) {
    await handler.removeQueueItem(queue[index]);
  }
}

Future<void> _runQueueAction(
  BuildContext context,
  Future<void> Function() action,
  String message,
) async {
  try {
    await action();
  } on Object catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'Tone queue',
        context: ErrorDescription(message),
      ),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('$message: $error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }
}

class PlayerQueueSheet extends StatefulWidget {
  const PlayerQueueSheet({
    required this.items,
    required this.currentIndex,
    required this.upcomingIndices,
    required this.onSelect,
    required this.onRemove,
    required this.onReorder,
    required this.onClear,
    required this.audioHandler,
    this.playbackState,
    this.isAutoplay = true,
    this.onToggleAutoplay,
    super.key,
  });

  final List<MediaItem> items;
  final int currentIndex;
  final List<int> upcomingIndices;
  final ValueChanged<int> onSelect;
  final ValueChanged<MediaItem> onRemove;
  final void Function(int oldIndex, int newIndex)? onReorder;
  final VoidCallback onClear;
  final AudioHandler audioHandler;
  final PlaybackState? playbackState;
  final bool isAutoplay;
  final VoidCallback? onToggleAutoplay;

  @override
  State<PlayerQueueSheet> createState() => _PlayerQueueSheetState();
}

class _PlayerQueueSheetState extends State<PlayerQueueSheet> {
  double? _dragSeekPosition;

  String get _sourceSectionName {
    final cur = widget.items.isNotEmpty && widget.currentIndex < widget.items.length
        ? widget.items[widget.currentIndex]
        : null;
    if (cur?.album != null &&
        cur!.album!.isNotEmpty &&
        cur.album != 'Unknown album' &&
        cur.album != 'On-device audio') {
      return cur.album!;
    }
    return 'Energy';
  }

  void _toggleShuffle() {
    final mode = widget.playbackState?.shuffleMode ?? AudioServiceShuffleMode.none;
    final next = mode == AudioServiceShuffleMode.none
        ? AudioServiceShuffleMode.all
        : AudioServiceShuffleMode.none;
    widget.audioHandler.setShuffleMode(next);
  }

  void _cycleRepeat() {
    final mode = widget.playbackState?.repeatMode ?? AudioServiceRepeatMode.none;
    final next = switch (mode) {
      AudioServiceRepeatMode.none => AudioServiceRepeatMode.all,
      AudioServiceRepeatMode.all => AudioServiceRepeatMode.one,
      AudioServiceRepeatMode.one => AudioServiceRepeatMode.none,
      _ => AudioServiceRepeatMode.none,
    };
    widget.audioHandler.setRepeatMode(next);
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.items.isNotEmpty && widget.currentIndex < widget.items.length
        ? widget.items[widget.currentIndex]
        : null;
    final isPlaying = widget.playbackState?.playing ?? false;
    final shuffleMode = widget.playbackState?.shuffleMode ?? AudioServiceShuffleMode.none;
    final repeatMode = widget.playbackState?.repeatMode ?? AudioServiceRepeatMode.none;
    final duration = current?.duration ?? const Duration(minutes: 3, seconds: 28);

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.94,
      decoration: const BoxDecoration(
        color: Color(0xF2161418),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
              // Top Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),

              // Bold "Queue" title and Clear / Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
                child: Row(
                  children: [
                    Text(
                      'Queue',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                    ),
                    const Spacer(),
                    if (widget.upcomingIndices.isNotEmpty)
                      TextButton(
                        onPressed: widget.onClear,
                        child: const Text(
                          'Clear',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.star_border_rounded, color: Colors.white70, size: 22),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.more_horiz_rounded, color: Colors.white70, size: 22),
                    ),
                  ],
                ),
              ),

              // Scrollable Queue List
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    // "Now playing" Section
                    if (current != null) ...[
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(20, 10, 20, 6),
                          child: Text(
                            'Now playing',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: AlbumArtwork(
                                      size: 48,
                                      title: current.title,
                                      artworkUri: current.artUri,
                                      sourceUri: Uri.tryParse(current.id),
                                      borderRadius: 10,
                                      iconSize: 22,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        current.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        displayArtistName(current.artist),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white60,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                AnimatedEqualizerIndicator(
                                  color: Colors.white,
                                  barCount: 4,
                                  size: 16,
                                  isPlaying: isPlaying,
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: 'Dismiss current',
                                  icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                                  onPressed: () => widget.audioHandler.skipToNext(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],

                    // "Next from: Energy" Header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                        child: Text(
                          'Next from: $_sourceSectionName',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    // Upcoming Tracks Reorderable List
                    if (widget.upcomingIndices.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  widget.isAutoplay
                                      ? Icons.all_inclusive_rounded
                                      : Icons.queue_music_rounded,
                                  size: 36,
                                  color: Colors.white30,
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Nothing else is queued.',
                                  style: TextStyle(color: Colors.white60),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      SliverReorderableList(
                        itemCount: widget.upcomingIndices.length,
                        onReorderItem: widget.onReorder ?? (_, _) {},
                        itemBuilder: (context, index) {
                          final queueIndex = widget.upcomingIndices[index];
                          final item = widget.items[queueIndex];
                          return Material(
                            key: ValueKey(item.id),
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => widget.onSelect(queueIndex),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                child: Row(
                                  children: [
                                    ReorderableDragStartListener(
                                      index: index,
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 8),
                                        child: Icon(Icons.drag_handle_rounded, color: Colors.white38, size: 20),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: SizedBox(
                                        width: 44,
                                        height: 44,
                                        child: AlbumArtwork(
                                          size: 44,
                                          title: item.title,
                                          artworkUri: item.artUri,
                                          sourceUri: Uri.tryParse(item.id),
                                          borderRadius: 8,
                                          iconSize: 18,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            displayArtistName(item.artist),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Remove from queue',
                                      icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                                      onPressed: () => widget.onRemove(item),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),

              // Pinned Bottom Player Controls Inside Queue (Matching Screenshot 3)
              Container(
              decoration: BoxDecoration(
                color: const Color(0xF7151218),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 20,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Lyrics Preview Line: "First notes in >"
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 2),
                      child: Row(
                        children: [
                          const Icon(Icons.music_note_rounded, color: Colors.white70, size: 16),
                          const SizedBox(width: 6),
                          const Text(
                            'First notes in',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 16),
                        ],
                      ),
                    ),

                    // Scrubber with Elapsed Time and Negative Remaining Time
                    StreamBuilder<Duration>(
                      stream: playbackPositionStream(widget.audioHandler),
                      builder: (context, posSnapshot) {
                        final currentMs = _dragSeekPosition ??
                            (posSnapshot.data ?? Duration.zero).inMilliseconds.toDouble();
                        final totalMs = duration.inMilliseconds.toDouble().clamp(1.0, double.infinity);
                        final elapsedStr = formatPlaybackTime(currentMs.round());
                        final remainingStr = formatNegativeRemainingTime(
                          currentMs.round(),
                          totalMs.round(),
                        );

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 3.5,
                                activeTrackColor: Colors.white,
                                inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                                thumbColor: Colors.white,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                                trackShape: const RectangularSliderTrackShape(),
                              ),
                              child: Slider(
                                value: currentMs.clamp(0.0, totalMs),
                                min: 0.0,
                                max: totalMs,
                                onChanged: (val) {
                                  setState(() => _dragSeekPosition = val);
                                },
                                onChangeEnd: (val) {
                                  setState(() => _dragSeekPosition = null);
                                  widget.audioHandler.seek(Duration(milliseconds: val.round()));
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    elapsedStr,
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 11.5,
                                      fontFeatures: [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                  Text(
                                    remainingStr,
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 11.5,
                                      fontFeatures: [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    // Previous, Play/Pause, Next
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            iconSize: 36,
                            onPressed: () => widget.audioHandler.skipToPrevious(),
                            icon: const Icon(Icons.fast_rewind_rounded, color: Colors.white),
                          ),
                          Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            child: IconButton(
                              iconSize: 42,
                              color: Colors.black,
                              onPressed: () {
                                if (isPlaying) {
                                  widget.audioHandler.pause();
                                } else {
                                  widget.audioHandler.play();
                                }
                              },
                              icon: Icon(
                                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              ),
                            ),
                          ),
                          IconButton(
                            iconSize: 36,
                            onPressed: () => widget.audioHandler.skipToNext(),
                            icon: const Icon(Icons.fast_forward_rounded, color: Colors.white),
                          ),
                        ],
                      ),
                    ),

                    // Volume Slider
                    PlayerVolumeSlider(audioHandler: widget.audioHandler),

                    // Bottom Pill Dock Toolbar: [Lyrics] [Shuffle] [Repeat] [Autoplay (∞)] [Queue (highlighted)]
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            IconButton(
                              tooltip: 'Lyrics',
                              icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white70, size: 20),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            IconButton(
                              tooltip: 'Shuffle',
                              icon: Icon(
                                Icons.shuffle_rounded,
                                color: shuffleMode != AudioServiceShuffleMode.none
                                    ? MeloColors.cherry
                                    : Colors.white70,
                                size: 20,
                              ),
                              onPressed: _toggleShuffle,
                            ),
                            IconButton(
                              tooltip: 'Repeat',
                              icon: Icon(
                                repeatMode == AudioServiceRepeatMode.one
                                    ? Icons.repeat_one_rounded
                                    : Icons.repeat_rounded,
                                color: repeatMode != AudioServiceRepeatMode.none
                                    ? MeloColors.cherry
                                    : Colors.white70,
                                size: 20,
                              ),
                              onPressed: _cycleRepeat,
                            ),
                            IconButton(
                              tooltip: widget.isAutoplay ? 'Autoplay: ON' : 'Autoplay: OFF',
                              icon: Icon(
                                Icons.all_inclusive_rounded,
                                color: widget.isAutoplay ? MeloColors.cherry : Colors.white38,
                                size: 20,
                              ),
                              onPressed: widget.onToggleAutoplay,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.format_list_bulleted_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Active Output Device Label
                    FutureBuilder<String>(
                      future: PlayerDeviceHelper.getDeviceName(),
                      builder: (context, snapshot) {
                        final deviceName = snapshot.data ?? "Osman's Phone";
                        return Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 8),
                          child: Text(
                            deviceName,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
  }
}
