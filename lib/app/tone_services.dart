import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:tone_player/features/library/music_library.dart';
import 'package:tone_player/features/player/tone_audio_handler.dart';

class ToneServices {
  const ToneServices({
    required this.audioHandler,
    required this.musicLibrary,
    required this._subscriptions,
  });

  final AudioHandler audioHandler;
  final MusicLibrary musicLibrary;
  final List<StreamSubscription<dynamic>> _subscriptions;

  static Future<ToneServices> initialize() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    final handler = await AudioService.init(
      builder: ToneAudioHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'app.tone.player.audio',
        androidNotificationChannelName: 'Tone music playback',
        androidNotificationOngoing: true,
      ),
    );
    final library = await MusicLibrary.open();
    await library.restoreQueue(handler);
    final subscriptions = <StreamSubscription<dynamic>>[];
    subscriptions.add(
      handler.mediaItem.listen(
        (item) => _reportPersistence(library.saveCurrentTrack(item?.id)),
        onError: (Object error, StackTrace stackTrace) =>
            _reportStreamError(error, stackTrace, 'current media item'),
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
    return ToneServices(
      audioHandler: handler,
      musicLibrary: library,
      subscriptions: subscriptions,
    );
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    musicLibrary.dispose();
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
