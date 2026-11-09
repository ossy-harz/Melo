library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:melo_player/app/melo_glass.dart';
import 'package:melo_player/app/melo_palette.dart';
import 'package:melo_player/app/melo_theme.dart';
import 'package:melo_player/features/auto_mix/waveform_transition_cues.dart';
import 'package:melo_player/features/library/data/artwork_cache.dart';
import 'package:melo_player/features/library/imported_track.dart';
import 'package:melo_player/features/library/music_library.dart';
import 'package:melo_player/features/library/song_metadata_enricher.dart';
import 'package:melo_player/features/mix/local_discovery.dart';
import 'package:melo_player/features/mix/smart_playlist_service.dart';
import 'package:melo_player/features/player/audio_waveform.dart';
import 'package:melo_player/features/player/lyrics_repository.dart';
import 'package:melo_player/features/player/player_formatters.dart';
import 'package:melo_player/features/player/player_glass_icon_button.dart';
import 'package:melo_player/features/player/player_queue_sheet.dart';
import 'package:melo_player/features/player/player_device_helper.dart';
import 'package:melo_player/features/player/player_volume_slider.dart';
import 'package:melo_player/features/player/melo_audio_handler.dart';
import 'package:melo_player/features/sources/lossless_audio_service.dart';
import 'package:melo_player/features/youtube/youtube_audio_service.dart';

part 'album_artwork.dart';
part 'now_playing_details.dart';
part 'now_playing_seek_bar.dart';
part 'now_playing_controls.dart';
part 'now_playing_lyrics.dart';
part 'now_playing_screen.dart';
part 'now_playing_more_sheet.dart';

const _artworkChannel = MethodChannel('app.melo.melo_player/library');
final Map<Uri, Future<Uint8List?>> _artworkCache = {};
final Map<Uri, Future<MeloPalette?>> _paletteCache = {};
final Map<String, Future<Map<String, Object?>?>> _audioQualityCache = {};
final Map<String, Future<Map<String, Object?>?>> _audioTagsCache = {};
final Map<String, Future<AudioWaveformData>> _audioWaveformCache = {};

/// Ensures that [AnimatedSwitcher] layout never encounters duplicate widget keys
/// in its child stack during rapid state updates, line jumps, or seeks.
Widget _safeAnimatedSwitcherLayout(
  Widget? currentChild,
  List<Widget> previousChildren,
) {
  final seenKeys = <Key>{};
  final safePrevious = <Widget>[];
  if (currentChild?.key != null) {
    seenKeys.add(currentChild!.key!);
  }
  for (final child in previousChildren) {
    if (child.key == null || seenKeys.add(child.key!)) {
      safePrevious.add(child);
    }
  }
  return Stack(
    alignment: Alignment.center,
    children: [
      ...safePrevious,
      ?currentChild,
    ],
  );
}

/// A fade transition builder that omits a key on the [FadeTransition] so Flutter's
/// [AnimatedSwitcher] correctly assigns unique sequential child numbers to each
/// transition entry, avoiding key collisions during rapid toggles.
Widget _safeFadeSwitcherTransition(
  Widget child,
  Animation<double> animation,
) {
  return FadeTransition(opacity: animation, child: child);
}

Future<AudioWaveformData> _audioWaveformFor(MediaItem item) {
  final existing = _audioWaveformCache[item.id];
  if (existing != null) return existing;
  final request = () async {
    final isRemoteStream = item.id.startsWith('youtube:') ||
        item.id.startsWith('spotify:') ||
        item.id.startsWith('http://') ||
        item.id.startsWith('https://') ||
        item.extras?['source'] == 'youtube' ||
        item.extras?['source'] == 'spotify' ||
        item.extras?['isLiveStream'] == true;
    if (isRemoteStream) {
      final seed = item.id.codeUnits.fold<int>(17, (acc, c) => (acc * 31 + c) & 0x7fffffff);
      final bins = List<double>.generate(128, (i) {
        final t = i / 127.0;
        final envelope = math.sin(t * math.pi).clamp(0.22, 1.0);
        final wave1 = math.sin(i * 0.43 + (seed % 97)) * 0.25;
        final wave2 = math.cos(i * 1.17 + (seed % 53)) * 0.18;
        return ((0.52 + wave1 + wave2) * envelope).clamp(0.14, 0.96);
      }, growable: false);
      return AudioWaveformData.fromPlatform(bins);
    }
    if (defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError(
        'Audio waveform analysis is currently available on Android.',
      );
    }
    final values = await _artworkChannel.invokeListMethod<Object?>(
      'readAudioWaveform',
      {'uri': item.id, 'binCount': 256},
    );
    if (values == null) {
      throw StateError('Android did not return an audio waveform.');
    }
    return AudioWaveformData.fromPlatform(values);
  }();
  _audioWaveformCache[item.id] = request;
  if (_audioWaveformCache.length > 24) {
    _audioWaveformCache.remove(_audioWaveformCache.keys.first);
  }
  return request;
}

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({
    required this.audioHandler,
    required this.onOpen,
    super.key,
  });

  final AudioHandler audioHandler;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => StreamBuilder<MediaItem?>(
    stream: audioHandler.mediaItem,
    builder: (context, mediaSnapshot) {
      final item = mediaSnapshot.data;
      if (item == null) return const SizedBox.shrink();
      final radius = BorderRadius.circular(MeloRadii.lg);
      return Container(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 26,
              spreadRadius: -4,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: MeloColors.cherry.withValues(alpha: 0.22),
              blurRadius: 30,
              spreadRadius: -14,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: MeloGlass(
          borderRadius: MeloRadii.lg,
          blur: 9,
          tint: Colors.black.withValues(alpha: 0.7),
          borderColor: Colors.white.withValues(alpha: 0.12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onOpen,
              borderRadius: radius,
              child: ClipRRect(
                borderRadius: radius,
                child: Stack(
                  children: [
                    const Positioned.fill(child: MeloGrain(opacity: 0.05)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 6, 10),
                      child: Row(
                        children: [
                          Hero(
                            tag: 'tone-art-${item.id}',
                            child: AlbumArtwork(
                              size: 44,
                              title: item.title,
                              artworkUri: item.artUri,
                              sourceUri: Uri.tryParse(item.id),
                              borderRadius: 10,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.2,
                                        color: Colors.white,
                                      ),
                                ),
                                Text(
                                  displayArtistName(
                                    item.artist,
                                    fallback:
                                        item.album == null ||
                                            item.album == 'Unknown album'
                                        ? 'From your library'
                                        : item.album,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.64,
                                        ),
                                      ),
                                ),
                              ],
                            ),
                          ),
                          StreamBuilder<PlaybackState>(
                            stream: audioHandler.playbackState,
                            builder: (context, stateSnapshot) {
                              final playing =
                                  stateSnapshot.data?.playing ?? false;
                              return Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      MeloColors.cherryGlow,
                                      MeloColors.cherry,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: MeloColors.cherry.withValues(
                                        alpha: 0.5,
                                      ),
                                      blurRadius: 16,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  tooltip: playing ? 'Pause' : 'Play',
                                  onPressed: () => _run(context, () {
                                    return playing
                                        ? audioHandler.pause()
                                        : audioHandler.play();
                                  }),
                                  style: IconButton.styleFrom(
                                    minimumSize: const Size(38, 38),
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: AnimatedSwitcher(
                                    duration: MeloMotion.fast,
                                    transitionBuilder: (child, animation) =>
                                        ScaleTransition(
                                          scale: animation,
                                          child: child,
                                        ),
                                    layoutBuilder: _safeAnimatedSwitcherLayout,
                                    child: Icon(
                                      playing
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      key: ValueKey(playing),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            tooltip: 'Next track',
                            onPressed: () =>
                                _run(context, audioHandler.skipToNext),
                            style: IconButton.styleFrom(
                              minimumSize: const Size(34, 34),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              foregroundColor: Colors.white.withValues(
                                alpha: 0.88,
                              ),
                            ),
                            icon: const Icon(Icons.skip_next_rounded, size: 22),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 0,
                      child: StreamBuilder<Duration>(
                        stream: playbackPositionStream(audioHandler),
                        builder: (context, positionSnapshot) {
                          final duration = item.duration?.inMilliseconds ?? 0;
                          final position =
                              positionSnapshot.data?.inMilliseconds ?? 0;
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: duration <= 0
                                  ? 0
                                  : (position / duration).clamp(0.0, 1.0),
                              minHeight: 2.5,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.14,
                              ),
                              valueColor: const AlwaysStoppedAnimation(
                                MeloColors.cherry,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _NoopListenable implements Listenable {
  const _NoopListenable._();

  static const instance = _NoopListenable._();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

String _formatTime(int milliseconds) => formatPlaybackTime(milliseconds);

/// One stable position stream per handler.
///
/// The stream has to be stable across rebuilds: handing `StreamBuilder` a fresh
/// stream each build makes it tear down and re-subscribe, throwing away the
/// accumulated time between real updates and making progress stutter or jump
/// backwards.
final _positionStreams = Expando<Stream<Duration>>('tonePlaybackPosition');

/// Emits the live playback position for [audioHandler].
///
/// Tone's audio handler reports its own position straight from the player, so the
/// value is always the truth and can never drift. Any other handler (previews,
/// tests) keeps the lighter behaviour of projecting forward from the last
/// published state, so the UI still moves between updates.
Stream<Duration> playbackPositionStream(AudioHandler audioHandler) =>
    _positionStreams[audioHandler] ??= _createPositionStream(audioHandler);

Stream<Duration> _createPositionStream(AudioHandler audioHandler) {
  if (audioHandler is MeloAudioHandler) return audioHandler.positionStream;
  // Any other handler publishes a position with each state change and projects
  // forward from it. It deliberately avoids a free-running timer: a handler
  // that never stops ticking would repaint the bar forever and leave the
  // screen permanently busy.
  return Stream<Duration>.multi((controller) {
    var state = audioHandler.playbackState.value;
    var updatedAt = DateTime.now();
    Duration current() {
      if (!state.playing) return state.updatePosition;
      final elapsed = DateTime.now().difference(updatedAt);
      return state.updatePosition +
          Duration(
            milliseconds: (elapsed.inMilliseconds * state.speed).round(),
          );
    }

    controller.add(current());
    final subscription = audioHandler.playbackState.listen((nextState) {
      state = nextState;
      updatedAt = DateTime.now();
      controller.add(current());
    }, onError: controller.addError);
    controller.onCancel = subscription.cancel;
  }, isBroadcast: true);
}

void _run(BuildContext context, Future<void> Function() action) {
  action().catchError((Object error, StackTrace stackTrace) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Playback action failed: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  });
}
