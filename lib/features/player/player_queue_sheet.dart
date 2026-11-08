import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:melo_player/app/melo_glass.dart';
import 'package:melo_player/features/library/imported_track.dart';
import 'package:melo_player/features/player/player_formatters.dart';
import 'package:melo_player/features/player/player_glass_icon_button.dart';
import 'package:melo_player/features/player/melo_audio_handler.dart';

void showPlayerQueue(BuildContext context, AudioHandler handler) {
  final queue = handler.queue.value;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.48),
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
                height: 180,
                child: Center(child: Text('The queue is empty.')),
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

class PlayerQueueSheet extends StatelessWidget {
  const PlayerQueueSheet({
    required this.items,
    required this.currentIndex,
    required this.upcomingIndices,
    required this.onSelect,
    required this.onRemove,
    required this.onReorder,
    required this.onClear,
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
  final bool isAutoplay;
  final VoidCallback? onToggleAutoplay;

  @override
  Widget build(BuildContext context) {
    final current = items[currentIndex];
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.78,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: MeloGlass(
          borderRadius: 28,
          tint: const Color(0xE8170B0F),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 38,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Queue',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '1 playing · ${upcomingIndices.length} up next',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.62),
                                ),
                          ),
                        ],
                      ),
                    ),
                    if (upcomingIndices.isNotEmpty)
                      TextButton(
                        onPressed: onClear,
                        child: const Text('Clear'),
                      ),
                    PlayerGlassIconButton(
                      icon: Icons.close_rounded,
                      tooltip: 'Close queue',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _CurrentQueueItem(item: current),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(
                  children: [
                    Text(
                      'UP NEXT',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const Spacer(),
                    if (onToggleAutoplay != null)
                      InkWell(
                        onTap: onToggleAutoplay,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isAutoplay
                                ? const Color(0xFFFA243C).withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isAutoplay
                                  ? const Color(0xFFFA243C)
                                  : Colors.white.withValues(alpha: 0.15),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.all_inclusive_rounded,
                                size: 13,
                                color: isAutoplay ? const Color(0xFFFA243C) : Colors.white60,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                isAutoplay ? 'Autoplay: ON' : 'Autoplay: OFF',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: isAutoplay ? Colors.white : Colors.white60,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (onReorder != null && upcomingIndices.length > 1) ...[
                      const SizedBox(width: 10),
                      Text(
                        'Hold to reorder',
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: upcomingIndices.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isAutoplay ? Icons.all_inclusive_rounded : Icons.queue_music_rounded,
                                size: 36,
                                color: isAutoplay
                                    ? const Color(0xFFFA243C)
                                    : Colors.white.withValues(alpha: 0.35),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Nothing else is queued.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.white.withValues(alpha: 0.72),
                                    ),
                              ),
                              if (isAutoplay) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Continuous stream active: similar tracks will follow.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: const Color(0xFFFA243C),
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    : ReorderableListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                        buildDefaultDragHandles: false,
                        itemCount: upcomingIndices.length,
                        onReorderItem: onReorder ?? (_, _) {},
                        itemBuilder: (context, index) {
                          final queueIndex = upcomingIndices[index];
                          final item = items[queueIndex];
                          return _UpcomingQueueItem(
                            key: ValueKey(item.id),
                            item: item,
                            index: index,
                            canReorder: onReorder != null,
                            onTap: () => onSelect(queueIndex),
                            onRemove: () => onRemove(item),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrentQueueItem extends StatelessWidget {
  const _CurrentQueueItem({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFA243C).withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFFA243C).withValues(alpha: 0.4)),
    ),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFFA243C).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.graphic_eq_rounded, color: Color(0xFFFF827A)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'NOW PLAYING',
                style: TextStyle(
                  color: Color(0xFFFF827A),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                displayArtistName(
                  item.artist,
                  fallback: item.album == null || item.album == 'Unknown album'
                      ? 'On-device audio'
                      : item.album,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        if (item.duration != null) ...[
          const SizedBox(width: 8),
          Text(
            formatPlaybackTime(item.duration!.inMilliseconds),
            style: _queueTimeStyle,
          ),
        ],
      ],
    ),
  );
}

class _UpcomingQueueItem extends StatelessWidget {
  const _UpcomingQueueItem({
    required this.item,
    required this.index,
    required this.canReorder,
    required this.onTap,
    required this.onRemove,
    super.key,
  });

  final MediaItem item;
  final int index;
  final bool canReorder;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Material(
    key: key,
    color: Colors.transparent,
    child: ListTile(
      onTap: onTap,
      leading: Text(
        '${index + 1}'.padLeft(2, '0'),
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.48),
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      title: Text(
        item.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        displayArtistName(
          item.artist,
          fallback: item.album == null || item.album == 'Unknown album'
              ? 'On-device audio'
              : item.album,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.62)),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.duration != null)
            Text(
              formatPlaybackTime(item.duration!.inMilliseconds),
              style: _queueTimeStyle,
            ),
          IconButton(
            tooltip: 'Remove from queue',
            onPressed: onRemove,
            icon: const Icon(
              Icons.remove_circle_outline_rounded,
              color: Colors.white70,
            ),
          ),
          if (canReorder)
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.drag_handle_rounded, color: Colors.white54),
              ),
            ),
        ],
      ),
    ),
  );
}

const _queueTimeStyle = TextStyle(
  color: Color(0x9EFFFFFF),
  fontSize: 12,
  fontWeight: FontWeight.w600,
  fontFeatures: [FontFeature.tabularFigures()],
);
