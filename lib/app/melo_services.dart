import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:melo_player/features/library/music_library.dart';
import 'package:melo_player/features/player/audio_profile_service.dart';
import 'package:melo_player/features/player/melo_audio_handler.dart';
import 'package:melo_player/features/updates/app_update_service.dart';

class MeloServices {
  const MeloServices({
    required this.audioHandler,
    required this.audioProfileService,
    required this.musicLibrary,
    required this._subscriptions,
  });

  final AudioHandler audioHandler;
  final AudioProfileService audioProfileService;
  final MusicLibrary musicLibrary;
  final List<StreamSubscription<dynamic>> _subscriptions;

  static Future<MeloServices> initialize({
    bool persistPlaybackState = true,
  }) async {
    final libraryFuture = MusicLibrary.open(
      platformDataSource: const MethodChannelLibraryPlatformDataSource(),
    );
    final sessionFuture = () async {
      final session = await AudioSession.instance;
      await session.configure(
        const AudioSessionConfiguration.music().copyWith(
          androidWillPauseWhenDucked: true,
        ),
      );
      return session;
    }();
    final handler = await AudioService.init<MeloAudioHandler>(
      builder: MeloAudioHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'app.melo.player.audio',
        androidNotificationChannelName: 'Melo music playback',
        androidNotificationChannelDescription:
            'Playback controls for music playing in Melo.',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
    final session = await sessionFuture;
    final library = await libraryFuture;
    unawaited(handler.attachAudioSession(session));
    handler.attachMusicLibrary(library);
    final audioProfileService = AudioServiceAudioProfileService(handler);
    unawaited(
      library.restoreQueue(handler).catchError((Object error, StackTrace st) {
        _reportStreamError(error, st, 'restore playback queue');
      }),
    );
    unawaited(AppUpdateService.instance.initialize(runStartupCheck: true));
    final subscriptions = <StreamSubscription<dynamic>>[];
    Future<void> persistPlaybackQueue() => library.persistPlaybackQueue(
      items: handler.queue.value,
      currentMediaId: handler.mediaItem.value?.id,
      positionMs: handler.playbackState.value.updatePosition.inMilliseconds,
    );
    if (persistPlaybackState) {
      subscriptions.add(
        handler.queue.listen(
          (_) => _reportPersistence(persistPlaybackQueue()),
          onError: (Object error, StackTrace stackTrace) =>
              _reportStreamError(error, stackTrace, 'playback queue'),
        ),
      );
      subscriptions.add(
        handler.mediaItem.listen(
          (item) {
            _reportPersistence(library.saveCurrentTrack(item?.id));
            _reportPersistence(persistPlaybackQueue());
          },
          onError: (Object error, StackTrace stackTrace) =>
              _reportStreamError(error, stackTrace, 'current media item'),
        ),
      );
      var wasPlaying = handler.playbackState.value.playing;
      subscriptions.add(
        handler.playbackState.listen(
          (state) {
            if (wasPlaying && !state.playing) {
              _reportPersistence(persistPlaybackQueue());
            }
            wasPlaying = state.playing;
          },
          onError: (Object error, StackTrace stackTrace) =>
              _reportStreamError(error, stackTrace, 'playback state'),
        ),
      );
      var lastPositionSave = DateTime.fromMillisecondsSinceEpoch(0);
      subscriptions.add(
        AudioService.position.listen(
          (position) {
            final now = DateTime.now();
            if (now.difference(lastPositionSave) < const Duration(seconds: 5)) {
              return;
            }
            lastPositionSave = now;
            _reportPersistence(library.savePlaybackPosition(position));
          },
          onError: (Object error, StackTrace stackTrace) =>
              _reportStreamError(error, stackTrace, 'playback position'),
        ),
      );
    }
    return MeloServices(
      audioHandler: handler,
      audioProfileService: audioProfileService,
      musicLibrary: library,
      subscriptions: subscriptions,
    );
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await musicLibrary.close();
  }

  static void _reportPersistence(Future<void> operation) {
    unawaited(
      operation.catchError((Object error, StackTrace stackTrace) {
        _reportStreamError(error, stackTrace, 'playback persistence');
      }),
    );
  }

  static void _reportStreamError(
    Object error,
    StackTrace stackTrace,
    String context,
  ) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'tone playback',
        context: ErrorDescription('while handling $context'),
      ),
    );
  }
}
