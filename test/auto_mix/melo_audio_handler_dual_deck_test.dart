import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:melo_player/features/auto_mix/audio_engine.dart';
import 'package:melo_player/features/library/music_library.dart';
import 'package:melo_player/features/player/melo_audio_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'diagnostic duration selections propagate and repeat on the same handler',
    () async {
      SharedPreferences.setMockInitialValues({});
      final engine = _FakeAudioEngine();
      final handler = MeloAudioHandler(
        audioEngine: engine,
        transitionGainStep: const Duration(seconds: 30),
        transitionDelay: (_) async {},
      );
      addTearDown(handler.dispose);
      final tracks = [
        const MediaItem(id: '/music/outgoing.mp3', title: 'Outgoing'),
        const MediaItem(id: '/music/incoming.mp3', title: 'Incoming'),
      ];

      for (final duration in const [3, 5, 10, 15, 20, 30]) {
        await handler.replaceQueue(tracks, playWhenReady: true);
        final result = Map<String, Object?>.from(
          await handler.customAction('autoMix.transitionToNextTrack', {
            'diagnostic': true,
            'durationMs': duration * 1000,
          }) as Map,
        );

        expect(result['completed'], isTrue);
        expect(result['requestedDurationMs'], duration * 1000);
        expect(result['durationMs'], duration * 1000);
        expect(result['effectiveDurationMs'], duration * 1000);
        expect(result['actualElapsedMs'], isA<int>());
        expect(result['actualStartedAt'], isA<String>());
        expect(result['actualCompletedAt'], isA<String>());
        final actualStart = DateTime.parse(
          result['actualStartedAt']! as String,
        );
        final actualCompletion = DateTime.parse(
          result['actualCompletedAt']! as String,
        );
        expect(actualCompletion.isBefore(actualStart), isFalse);
        expect(result['trialId'], isA<String>());
        expect(result['incomingPromoted'], isTrue);
        expect(result['timingSource'], contains('not audio-output timing'));
        final events = result['lifecycleEvents'] as List;
        expect(
          events.any((event) => event['name'] == 'gainRampCompleted'),
          isTrue,
        );
        expect(
          events.any((event) => event['name'] == 'transitionCompleted'),
          isTrue,
        );
        final deckA = (result['gainUpdates'] as Map)['a'] as Map;
        final deckB = (result['gainUpdates'] as Map)['b'] as Map;
        expect(deckA['count'], greaterThan(0));
        expect(deckB['count'], greaterThan(0));
      }
    },
  );

  test('diagnostic duration validation rejects unsupported values', () async {
    SharedPreferences.setMockInitialValues({});
    final handler = MeloAudioHandler(audioEngine: _FakeAudioEngine());
    addTearDown(handler.dispose);

    for (final duration in [0, 2000, 4000, 31000]) {
      await expectLater(
        handler.customAction('autoMix.transitionToNextTrack', {
          'diagnostic': true,
          'durationMs': duration,
        }),
        throwsArgumentError,
      );
    }
    await expectLater(
      handler.customAction('autoMix.transitionToNextTrack', {
        'diagnostic': true,
        'durationMs': 3000.0,
      }),
      throwsArgumentError,
    );
  });

  test('analysis lookup reports the queue-owned next track', () async {
    SharedPreferences.setMockInitialValues({});
    final handler = MeloAudioHandler(audioEngine: _FakeAudioEngine());
    addTearDown(handler.dispose);
    await handler.replaceQueue([
      const MediaItem(
        id: '/music/current.mp3',
        title: 'Current',
        duration: Duration(minutes: 3),
      ),
      const MediaItem(
        id: '/music/next.mp3',
        title: 'Next',
        duration: Duration(minutes: 4),
      ),
    ], playWhenReady: true);

    final result =
        await handler.customAction('autoMix.getNextTrackForAnalysis') as Map;

    expect(result['id'], '/music/next.mp3');
    expect(result['title'], 'Next');
    expect(result['durationMs'], const Duration(minutes: 4).inMilliseconds);
  });

  test('diagnostic cancellation records reason and restores Deck A', () async {
    SharedPreferences.setMockInitialValues({});
    final engine = _FakeAudioEngine();
    final stepStarted = Completer<void>();
    final holdStep = Completer<void>();
    final handler = MeloAudioHandler(
      audioEngine: engine,
      transitionGainStep: const Duration(milliseconds: 10),
      transitionDelay: (_) async {
        if (!stepStarted.isCompleted) stepStarted.complete();
        await holdStep.future;
      },
    );
    addTearDown(handler.dispose);
    await handler.replaceQueue([
      const MediaItem(id: '/music/current.mp3', title: 'Current'),
      const MediaItem(id: '/music/next.mp3', title: 'Next'),
    ], playWhenReady: true);

    final transition = handler.customAction('autoMix.transitionToNextTrack', {
      'diagnostic': true,
      'durationMs': 3000,
    });
    await stepStarted.future;
    await handler.customAction('autoMix.cancelTransition', {
      'reason': 'diagnosticUserCancel',
    });
    final result = Map<String, Object?>.from(await transition as Map);
    holdStep.complete();

    expect(result['completed'], isFalse);
    expect(result['cancellationReason'], 'diagnosticUserCancel');
    expect(result['incomingPromoted'], isNull);
    expect(engine.stateFor(AudioDeck.a).playing, isTrue);
    expect(engine.stateFor(AudioDeck.a).gain, 1);
    expect(engine.stateFor(AudioDeck.b).playing, isFalse);
  });

  test('diagnostic trial rejects concurrent transitions', () async {
    SharedPreferences.setMockInitialValues({});
    final engine = _FakeAudioEngine();
    final stepStarted = Completer<void>();
    final holdStep = Completer<void>();
    final handler = MeloAudioHandler(
      audioEngine: engine,
      transitionGainStep: const Duration(milliseconds: 10),
      transitionDelay: (_) async {
        if (!stepStarted.isCompleted) stepStarted.complete();
        await holdStep.future;
      },
    );
    addTearDown(handler.dispose);
    await handler.replaceQueue([
      const MediaItem(id: '/music/current.mp3', title: 'Current'),
      const MediaItem(id: '/music/next.mp3', title: 'Next'),
    ], playWhenReady: true);

    final transition = handler.customAction('autoMix.transitionToNextTrack', {
      'diagnostic': true,
      'durationMs': 3000,
    });
    await stepStarted.future;
    await expectLater(
      handler.customAction('autoMix.transitionToNextTrack', {
        'diagnostic': true,
        'durationMs': 3000,
      }),
      throwsStateError,
    );
    await handler.customAction('autoMix.cancelTransition');
    await transition;
    holdStep.complete();
  });

  test(
    'queue replacement cancels an active diagnostic without promotion',
    () async {
      SharedPreferences.setMockInitialValues({});
      final engine = _FakeAudioEngine();
      final stepStarted = Completer<void>();
      final holdStep = Completer<void>();
      final handler = MeloAudioHandler(
        audioEngine: engine,
        transitionGainStep: const Duration(milliseconds: 10),
        transitionDelay: (_) async {
          if (!stepStarted.isCompleted) stepStarted.complete();
          await holdStep.future;
        },
      );
      addTearDown(handler.dispose);
      await handler.replaceQueue([
        const MediaItem(id: '/music/current.mp3', title: 'Current'),
        const MediaItem(id: '/music/next.mp3', title: 'Next'),
      ], playWhenReady: true);

      final transition = handler.customAction('autoMix.transitionToNextTrack', {
        'diagnostic': true,
        'durationMs': 3000,
      });
      await stepStarted.future;
      await handler.replaceQueue([
        const MediaItem(id: '/music/replacement.mp3', title: 'Replacement'),
      ], playWhenReady: true);
      final result = Map<String, Object?>.from(await transition as Map);
      holdStep.complete();

      expect(result['completed'], isFalse);
      expect(result['cancellationReason'], 'playbackOperation');
      expect(result['incomingPromoted'], isNull);
      expect(handler.mediaItem.value?.id, '/music/replacement.mp3');
      expect(engine.stateFor(AudioDeck.a).playing, isTrue);
    },
  );

  test('disposal ends an active diagnostic trial safely', () async {
    SharedPreferences.setMockInitialValues({});
    final engine = _FakeAudioEngine();
    final stepStarted = Completer<void>();
    final holdStep = Completer<void>();
    final handler = MeloAudioHandler(
      audioEngine: engine,
      transitionGainStep: const Duration(milliseconds: 10),
      transitionDelay: (_) async {
        if (!stepStarted.isCompleted) stepStarted.complete();
        await holdStep.future;
      },
    );
    await handler.replaceQueue([
      const MediaItem(id: '/music/current.mp3', title: 'Current'),
      const MediaItem(id: '/music/next.mp3', title: 'Next'),
    ], playWhenReady: true);

    final transition = handler.customAction('autoMix.transitionToNextTrack', {
      'diagnostic': true,
      'durationMs': 3000,
    });
    await stepStarted.future;
    await handler.dispose();
    holdStep.complete();
    final result = Map<String, Object?>.from(await transition as Map);

    expect(result['completed'], isFalse);
    expect(result['cancellationReason'], 'handlerDisposed');
    expect(result['actualCompletedAt'], isNull);
    expect(engine._disposed, isTrue);
  });

  test(
    'incoming preload failure is reported without stopping Deck A',
    () async {
      SharedPreferences.setMockInitialValues({});
      final engine = _FakeAudioEngine();
      final handler = MeloAudioHandler(audioEngine: engine);
      addTearDown(handler.dispose);
      await handler.replaceQueue([
        const MediaItem(id: '/music/current.mp3', title: 'Current'),
        const MediaItem(id: '/music/missing.mp3', title: 'Missing'),
      ], playWhenReady: true);
      await handler.customAction('autoMix.preloadNextTrack');
      await handler.customAction('autoMix.unloadDeckB');
      engine.failNextDeckBLoad = true;

      final result = Map<String, Object?>.from(
        await handler.customAction('autoMix.transitionToNextTrack', {
          'diagnostic': true,
          'durationMs': 3000,
        }) as Map,
      );

      expect(result['completed'], isFalse);
      expect(result['error'], contains('diagnostic source failure'));
      expect((result['recoveryBehavior'] as Map)['deckAPlaying'], isTrue);
      expect(engine.stateFor(AudioDeck.a).playing, isTrue);
      expect(handler.mediaItem.value?.id, '/music/current.mp3');
    },
  );

  test(
    'queue advancement stays on Deck A and clears the old Deck B preload',
    () async {
      SharedPreferences.setMockInitialValues({});
      final engine = _FakeAudioEngine();
      final handler = MeloAudioHandler(audioEngine: engine);
      addTearDown(handler.dispose);

      await handler.replaceQueue([
        const MediaItem(id: '/music/current.mp3', title: 'Current'),
        const MediaItem(id: '/music/next.mp3', title: 'Next'),
      ], playWhenReady: true);
      await handler.customAction('autoMix.preloadNextTrack');
      expect(engine.stateFor(AudioDeck.a).playing, isTrue);
      expect(engine.stateFor(AudioDeck.b).loaded, isTrue);

      final nextTrack = handler.mediaItem.firstWhere(
        (item) => item?.id == '/music/next.mp3',
      );
      final nextPlayback = handler.playbackState.firstWhere(
        (state) => state.queueIndex == 1 && state.playing,
      );
      engine.complete(AudioDeck.a);
      await Future.wait([nextTrack, nextPlayback]);

      expect(handler.mediaItem.value?.id, '/music/next.mp3');
      expect(engine.stateFor(AudioDeck.a).playing, isTrue);
      expect(engine.stateFor(AudioDeck.a).loaded, isTrue);
      expect(engine.stateFor(AudioDeck.b).playing, isFalse);
      expect(engine.stateFor(AudioDeck.b).loaded, isFalse);
      expect(handler.playbackState.value.queueIndex, 1);
    },
  );

  test('automatically crossfades before the outgoing track ends', () async {
    SharedPreferences.setMockInitialValues({});
    final engine = _FakeAudioEngine();
    final handler = MeloAudioHandler(
      audioEngine: engine,
      transitionGainStep: const Duration(seconds: 30),
      transitionDelay: (_) async {},
    );
    addTearDown(handler.dispose);
    await handler.replaceQueue([
      const MediaItem(id: '/music/current.mp3', title: 'Current'),
      const MediaItem(id: '/music/next.mp3', title: 'Next'),
    ], playWhenReady: true);
    if (!engine.stateFor(AudioDeck.b).loaded) {
      await engine.states.firstWhere(
        (state) => state.deck == AudioDeck.b && state.loaded,
      );
    }
    expect(engine.stateFor(AudioDeck.b).loaded, isTrue);

    final promoted = handler.mediaItem.firstWhere(
      (item) => item?.id == '/music/next.mp3',
    );
    await handler.seek(const Duration(minutes: 2, seconds: 50));
    await promoted.timeout(const Duration(seconds: 1));

    expect(handler.mediaItem.value?.id, '/music/next.mp3');
    expect(handler.playbackState.value.queueIndex, 1);
    expect(engine.stateFor(AudioDeck.a).playing, isTrue);
    expect(engine.stateFor(AudioDeck.a).position, Duration.zero);
    expect(engine.stateFor(AudioDeck.b).loaded, isFalse);
  });

  test('queue edits clear Deck B before changing the upcoming order', () async {
    SharedPreferences.setMockInitialValues({});
    final engine = _FakeAudioEngine();
    final handler = MeloAudioHandler(audioEngine: engine);
    addTearDown(handler.dispose);
    const current = MediaItem(id: '/music/current.mp3', title: 'Current');
    const next = MediaItem(id: '/music/next.mp3', title: 'Next');
    const later = MediaItem(id: '/music/later.mp3', title: 'Later');

    await handler.replaceQueue([current, next, later], playWhenReady: true);
    await handler.customAction('autoMix.preloadNextTrack');
    expect(engine.stateFor(AudioDeck.b).loaded, isTrue);

    await handler.reorderUpcomingQueue(0, 1);
    expect(engine.stateFor(AudioDeck.b).loaded, isFalse);

    await handler.customAction('autoMix.preloadNextTrack');
    expect(engine.stateFor(AudioDeck.b).loaded, isTrue);
    await handler.removeQueueItem(next);
    expect(engine.stateFor(AudioDeck.b).loaded, isFalse);
    expect(handler.upcomingQueueIndices, [1]);
  });

  test('transition fades Decks, promotes the incoming track, and keeps queue state', () async {
    SharedPreferences.setMockInitialValues({});
    final engine = _FakeAudioEngine();
    final handler = MeloAudioHandler(
      audioEngine: engine,
      transitionGainStep: const Duration(seconds: 1),
      transitionDelay: (_) async {},
    );
    addTearDown(handler.dispose);
    final transitionEvents = <Map>[];
    final transitionSubscription = handler.customEvent.listen((event) {
      if (event is Map && event['type'].toString().startsWith('autoMix.')) {
        transitionEvents.add(event);
      }
    });
    addTearDown(transitionSubscription.cancel);
    await handler.replaceQueue([
      const MediaItem(id: '/music/current.mp3', title: 'Current'),
      const MediaItem(id: '/music/next.mp3', title: 'Next'),
    ], playWhenReady: true);
    await engine.seekDeck(AudioDeck.a, const Duration(minutes: 1));

    final result = await handler.customAction(
      'autoMix.transitionToNextTrack',
    ) as Map<String, Object?>;

    expect(result['completed'], isTrue);
    expect(result['trackId'], '/music/next.mp3');
    expect(result['durationMs'], 10000);
    expect(handler.mediaItem.value?.id, '/music/next.mp3');
    expect(handler.playbackState.value.queueIndex, 1);
    expect(engine.stateFor(AudioDeck.a).playing, isTrue);
    expect(engine.stateFor(AudioDeck.a).loaded, isTrue);
    expect(engine.stateFor(AudioDeck.a).gain, 1);
    expect(engine.stateFor(AudioDeck.b).loaded, isFalse);
    expect(
      transitionEvents.map((event) => event['type']),
      containsAllInOrder([
        'autoMix.transitionStarted',
        'autoMix.transitionProgress',
        'autoMix.transitionEnded',
      ]),
    );
    final progressEvent = transitionEvents.firstWhere(
      (event) => event['type'] == 'autoMix.transitionProgress',
    );
    expect(progressEvent['progress'], 1);
    expect(progressEvent['durationMs'], 10000);
    expect(transitionEvents.last['completed'], isTrue);
  });
  test('pausing cancels a transition before queue promotion', () async {
    SharedPreferences.setMockInitialValues({});
    final engine = _FakeAudioEngine();
    final stepStarted = Completer<void>();
    final holdStep = Completer<void>();
    final handler = MeloAudioHandler(
      audioEngine: engine,
      transitionGainStep: const Duration(milliseconds: 10),
      transitionDelay: (_) async {
        if (!stepStarted.isCompleted) stepStarted.complete();
        await holdStep.future;
      },
    );
    addTearDown(handler.dispose);
    await handler.replaceQueue([
      const MediaItem(id: '/music/current.mp3', title: 'Current'),
      const MediaItem(id: '/music/next.mp3', title: 'Next'),
    ], playWhenReady: true);

    final transition = handler
        .customAction('autoMix.transitionToNextTrack')
        .then((result) => Map<String, Object?>.from(result as Map));
    await stepStarted.future;
    await handler.pause();
    holdStep.complete();

    expect((await transition)['completed'], isFalse);
    expect(handler.mediaItem.value?.id, '/music/current.mp3');
    expect(handler.playbackState.value.queueIndex, 0);
    expect(engine.stateFor(AudioDeck.a).playing, isFalse);
    expect(engine.stateFor(AudioDeck.a).gain, 1);
    expect(engine.stateFor(AudioDeck.b).playing, isFalse);
    expect(engine.stateFor(AudioDeck.b).gain, 1);
  });

  test('Deck B playback error cancels the ramp and restores Deck A', () async {
    SharedPreferences.setMockInitialValues({});
    final engine = _FakeAudioEngine();
    final stepStarted = Completer<void>();
    final holdStep = Completer<void>();
    final handler = MeloAudioHandler(
      audioEngine: engine,
      transitionGainStep: const Duration(milliseconds: 10),
      transitionDelay: (_) async {
        if (!stepStarted.isCompleted) stepStarted.complete();
        await holdStep.future;
      },
    );
    addTearDown(handler.dispose);
    await handler.replaceQueue([
      const MediaItem(id: '/music/current.mp3', title: 'Current'),
      const MediaItem(id: '/music/next.mp3', title: 'Next'),
    ], playWhenReady: true);

    final transition = handler
        .customAction('autoMix.transitionToNextTrack')
        .then((result) => Map<String, Object?>.from(result as Map));
    await stepStarted.future;
    engine.failDeck(AudioDeck.b);

    expect((await transition)['completed'], isFalse);
    holdStep.complete();
    expect(handler.mediaItem.value?.id, '/music/current.mp3');
    expect(engine.stateFor(AudioDeck.a).playing, isTrue);
    expect(engine.stateFor(AudioDeck.a).gain, 1);
    expect(engine.stateFor(AudioDeck.b).playing, isFalse);
  });

  test(
    'supports consecutive transitions with incoming-deck promotion',
    () async {
      SharedPreferences.setMockInitialValues({});
      final engine = _FakeAudioEngine();
      final handler = MeloAudioHandler(
        audioEngine: engine,
        transitionGainStep: const Duration(seconds: 1),
        transitionDelay: (_) async {},
      );
      addTearDown(handler.dispose);
      await handler.replaceQueue([
        const MediaItem(id: '/music/first.mp3', title: 'First'),
        const MediaItem(id: '/music/second.mp3', title: 'Second'),
        const MediaItem(id: '/music/third.mp3', title: 'Third'),
      ], playWhenReady: true);

      await handler.customAction('autoMix.transitionToNextTrack');
      expect(handler.mediaItem.value?.id, '/music/second.mp3');
      expect(engine.stateFor(AudioDeck.a).playing, isTrue);
      expect(engine.stateFor(AudioDeck.b).loaded, isFalse);

      await handler.customAction('autoMix.transitionToNextTrack');
      expect(handler.mediaItem.value?.id, '/music/third.mp3');
      expect(handler.playbackState.value.queueIndex, 2);
      expect(engine.stateFor(AudioDeck.a).playing, isTrue);
      expect(engine.stateFor(AudioDeck.b).loaded, isFalse);
    },
  );

  test(
    'disposal cancels an active transition before releasing the engine',
    () async {
      SharedPreferences.setMockInitialValues({});
      final engine = _FakeAudioEngine();
      final stepStarted = Completer<void>();
      final holdStep = Completer<void>();
      final handler = MeloAudioHandler(
        audioEngine: engine,
        transitionGainStep: const Duration(milliseconds: 10),
        transitionDelay: (_) async {
          if (!stepStarted.isCompleted) stepStarted.complete();
          await holdStep.future;
        },
      );
      await handler.replaceQueue([
        const MediaItem(id: '/music/current.mp3', title: 'Current'),
        const MediaItem(id: '/music/next.mp3', title: 'Next'),
      ], playWhenReady: true);

      final transition = handler
          .customAction('autoMix.transitionToNextTrack')
          .then((result) => Map<String, Object?>.from(result as Map));
      await stepStarted.future;
      await handler.dispose();
      holdStep.complete();

      expect((await transition)['completed'], isFalse);
      expect(engine._disposed, isTrue);
      expect(handler.mediaItem.value?.id, '/music/current.mp3');
    },
  );

  test('recovers gracefully from corrupted saved playback settings', () async {
    SharedPreferences.setMockInitialValues({
      'tone_playback_repeat_mode': 'invalid_mode',
      'tone_playback_shuffle_mode': 'invalid_shuffle',
      'tone_audio_profile': '{not valid json',
    });
    final previousOnError = FlutterError.onError;
    final reportedErrors = <FlutterErrorDetails>[];
    FlutterError.onError = reportedErrors.add;
    addTearDown(() => FlutterError.onError = previousOnError);

    final engine = _FakeAudioEngine();
    final handler = MeloAudioHandler(audioEngine: engine);
    addTearDown(handler.dispose);

    await handler.replaceQueue([
      const MediaItem(id: '/music/a.mp3', title: 'Track A'),
    ], playWhenReady: false);

    expect(handler.mediaItem.value?.id, '/music/a.mp3');
    expect(handler.playbackState.value.repeatMode, AudioServiceRepeatMode.none);
    expect(handler.playbackState.value.shuffleMode, AudioServiceShuffleMode.none);
    expect(reportedErrors, isNotEmpty);
  });

  test(
    'skipToNext with preloaded Deck B updates mediaItem and never reverts on duration mismatch',
    () async {
      SharedPreferences.setMockInitialValues({});
      final engine = _FakeAudioEngine()
        ..trackDurations[Uri.file('/music/first.mp3')] = const Duration(minutes: 3)
        ..trackDurations[Uri.file('/music/second.mp3')] =
            const Duration(minutes: 4, seconds: 15)
        ..trackDurations[Uri.file('/music/third.mp3')] = const Duration(minutes: 2);
      final handler = MeloAudioHandler(audioEngine: engine);
      addTearDown(handler.dispose);

      await handler.replaceQueue([
        const MediaItem(id: '/music/first.mp3', title: 'First'),
        const MediaItem(id: '/music/second.mp3', title: 'Second'),
        const MediaItem(id: '/music/third.mp3', title: 'Third'),
      ], playWhenReady: true);
      await handler.customAction('autoMix.preloadNextTrack');
      expect(engine.stateFor(AudioDeck.b).loaded, isTrue);

      await handler.skipToNext();
      await Future<void>.delayed(Duration.zero);

      expect(handler.mediaItem.value?.id, '/music/second.mp3');
      expect(
        handler.mediaItem.value?.duration,
        const Duration(minutes: 4, seconds: 15),
      );
      expect(handler.playbackState.value.queueIndex, 1);
      expect(engine.stateFor(AudioDeck.a).playing, isTrue);
      // Deck B preload (if started for upcoming track) must target Third, never Second.
      if (engine.stateFor(AudioDeck.b).loaded) {
        expect(
          engine.lastLoadedSource[AudioDeck.b]?.uri,
          Uri.file('/music/third.mp3'),
        );
      }
    },
  );

  test(
    'rapid double skipToNext advances two tracks without replaying the first next track',
    () async {
      SharedPreferences.setMockInitialValues({});
      final engine = _FakeAudioEngine();
      final handler = MeloAudioHandler(audioEngine: engine);
      addTearDown(handler.dispose);

      await handler.replaceQueue([
        const MediaItem(id: '/music/first.mp3', title: 'First'),
        const MediaItem(id: '/music/second.mp3', title: 'Second'),
        const MediaItem(id: '/music/third.mp3', title: 'Third'),
        const MediaItem(id: '/music/fourth.mp3', title: 'Fourth'),
      ], playWhenReady: true);
      await handler.customAction('autoMix.preloadNextTrack');

      final firstSkip = handler.skipToNext();
      final secondSkip = handler.skipToNext();
      await Future.wait([firstSkip, secondSkip]);

      expect(handler.mediaItem.value?.id, '/music/third.mp3');
      expect(handler.playbackState.value.queueIndex, 2);
      expect(engine.stateFor(AudioDeck.a).playing, isTrue);
    },
  );

  test(
    'respects user volume and prevents overlap gain spikes across skipToNext and AutoMix',
    () async {
      SharedPreferences.setMockInitialValues({});
      final engine = _FakeAudioEngine();
      final handler = MeloAudioHandler(
        audioEngine: engine,
        transitionGainStep: const Duration(seconds: 2),
        transitionDelay: (_) async {},
      );
      addTearDown(handler.dispose);

      await handler.replaceQueue([
        const MediaItem(id: '/music/first.mp3', title: 'First'),
        const MediaItem(id: '/music/second.mp3', title: 'Second'),
        const MediaItem(id: '/music/third.mp3', title: 'Third'),
      ], playWhenReady: true);

      await handler.customAction('setVolume', {'volume': 0.5});
      expect(engine.stateFor(AudioDeck.a).gain, closeTo(0.5, 1e-9));

      await handler.customAction('autoMix.preloadNextTrack');
      engine.overlapGainSums.clear();
      await handler.skipToNext();

      expect(handler.mediaItem.value?.id, '/music/second.mp3');
      expect(engine.stateFor(AudioDeck.a).gain, closeTo(0.5, 1e-9));
      expect(
        engine.overlapGainSums.every((sum) => sum <= 0.5 + 1e-9),
        isTrue,
      );

      engine.overlapGainSums.clear();
      final result = await handler.customAction('autoMix.transitionToNextTrack')
          as Map<String, Object?>;
      expect(result['completed'], isTrue);
      expect(handler.mediaItem.value?.id, '/music/third.mp3');
      expect(engine.stateFor(AudioDeck.a).gain, closeTo(0.5, 1e-9));
      expect(
        engine.overlapGainSums.every((sum) => sum <= 0.5 + 1e-9),
        isTrue,
      );
    },
  );

  test(
    'Media3 notification controls expose custom Like and Repeat actions and sync art URI',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final musicDir = await Directory.systemTemp.createTemp('melo-notif-');
      addTearDown(() async {
        if (await musicDir.exists()) await musicDir.delete(recursive: true);
      });
      final library = MusicLibrary.forTesting(
        musicDirectory: musicDir,
        preferences: preferences,
        pickAudio: () async => const [],
      );
      await library.load();

      final engine = _FakeAudioEngine();
      final handler = MeloAudioHandler(audioEngine: engine);
      addTearDown(handler.dispose);
      handler.attachMusicLibrary(library);

      await handler.replaceQueue([
        const MediaItem(
          id: 'youtube:abc123',
          title: 'Streaming Jam',
          artist: 'Melo Artist',
          extras: {
            'streamUrl': 'https://example.com/stream.m4a',
            'source': 'youtube',
            'providerTrackId': 'abc123',
          },
        ),
      ], playWhenReady: true);

      var controls = handler.playbackState.value.controls;
      expect(controls.length, 5);
      expect(controls.first.customAction?.name, 'notification.toggleLike');
      expect(controls.first.androidIcon, 'drawable/ic_notif_heart_outline');
      expect(controls.last.customAction?.name, 'notification.cycleRepeat');
      expect(controls.last.androidIcon, 'drawable/ic_notif_repeat_off');
      expect(handler.playbackState.value.androidCompactActionIndices, [1, 2, 3]);

      final liked = await handler.customAction('notification.toggleLike');
      expect(liked, isTrue);
      expect(library.favoriteTracks.map((t) => t.id), contains('youtube:abc123'));
      controls = handler.playbackState.value.controls;
      expect(controls.first.androidIcon, 'drawable/ic_notif_heart_filled');

      expect(await handler.customAction('notification.cycleRepeat'), 'all');
      expect(
        handler.playbackState.value.controls.last.androidIcon,
        'drawable/ic_notif_repeat_all',
      );
      expect(await handler.customAction('notification.cycleRepeat'), 'one');
      expect(
        handler.playbackState.value.controls.last.androidIcon,
        'drawable/ic_notif_repeat_one',
      );
      expect(await handler.customAction('notification.cycleRepeat'), 'none');
      expect(
        handler.playbackState.value.controls.last.androidIcon,
        'drawable/ic_notif_repeat_off',
      );

      await handler.customAction('player.updateMediaItemArtUri', {
        'id': 'youtube:abc123',
        'artUri': 'https://example.com/cover.jpg',
      });
      expect(
        handler.mediaItem.value?.artUri.toString(),
        'https://example.com/cover.jpg',
      );
    },
  );

  test(
    'permanent audio focus loss pauses playback and releases audio focus',
    () async {
      SharedPreferences.setMockInitialValues({});
      final session = _FakeAudioSession();
      addTearDown(session.dispose);
      final engine = _FakeAudioEngine();
      final handler = MeloAudioHandler(
        audioEngine: engine,
        audioSession: session,
      );
      addTearDown(handler.dispose);

      final tracks = [
        const MediaItem(id: '/music/track1.mp3', title: 'Track 1'),
      ];
      await handler.replaceQueue(tracks, playWhenReady: true);
      expect(engine.stateFor(AudioDeck.a).playing, isTrue);
      expect(session.active, isTrue);

      session.triggerInterruption(
        AudioInterruptionEvent(true, AudioInterruptionType.unknown),
      );
      await pumpEventQueue();

      expect(engine.stateFor(AudioDeck.a).playing, isFalse);
      expect(handler.playbackState.value.playing, isFalse);
      expect(handler.isInterruptionActive, isFalse);
      expect(handler.willResumeAfterInterruption, isFalse);
      expect(session.active, isFalse);
    },
  );

  test(
    'transient audio focus loss pauses and auto-resumes when interruption ends',
    () async {
      SharedPreferences.setMockInitialValues({});
      final session = _FakeAudioSession();
      addTearDown(session.dispose);
      final engine = _FakeAudioEngine();
      final handler = MeloAudioHandler(
        audioEngine: engine,
        audioSession: session,
      );
      addTearDown(handler.dispose);

      final tracks = [
        const MediaItem(id: '/music/track1.mp3', title: 'Track 1'),
      ];
      await handler.replaceQueue(tracks, playWhenReady: true);
      expect(engine.stateFor(AudioDeck.a).playing, isTrue);

      session.triggerInterruption(
        AudioInterruptionEvent(true, AudioInterruptionType.pause),
      );
      await pumpEventQueue();

      expect(engine.stateFor(AudioDeck.a).playing, isFalse);
      expect(handler.isInterruptionActive, isTrue);
      expect(handler.willResumeAfterInterruption, isTrue);

      session.triggerInterruption(
        AudioInterruptionEvent(false, AudioInterruptionType.pause),
      );
      await pumpEventQueue();

      expect(engine.stateFor(AudioDeck.a).playing, isTrue);
      expect(handler.playbackState.value.playing, isTrue);
      expect(handler.isInterruptionActive, isFalse);
      expect(handler.willResumeAfterInterruption, isFalse);
    },
  );

  test(
    'manual pause during transient interruption prevents auto-resuming',
    () async {
      SharedPreferences.setMockInitialValues({});
      final session = _FakeAudioSession();
      addTearDown(session.dispose);
      final engine = _FakeAudioEngine();
      final handler = MeloAudioHandler(
        audioEngine: engine,
        audioSession: session,
      );
      addTearDown(handler.dispose);

      final tracks = [
        const MediaItem(id: '/music/track1.mp3', title: 'Track 1'),
      ];
      await handler.replaceQueue(tracks, playWhenReady: true);
      expect(engine.stateFor(AudioDeck.a).playing, isTrue);

      session.triggerInterruption(
        AudioInterruptionEvent(true, AudioInterruptionType.pause),
      );
      await pumpEventQueue();
      expect(handler.isInterruptionActive, isTrue);

      await handler.pause();
      expect(handler.isInterruptionActive, isFalse);
      expect(handler.willResumeAfterInterruption, isFalse);

      session.triggerInterruption(
        AudioInterruptionEvent(false, AudioInterruptionType.pause),
      );
      await pumpEventQueue();

      expect(engine.stateFor(AudioDeck.a).playing, isFalse);
      expect(handler.playbackState.value.playing, isFalse);
    },
  );

  test(
    'becoming noisy event immediately pauses playback',
    () async {
      SharedPreferences.setMockInitialValues({});
      final session = _FakeAudioSession();
      addTearDown(session.dispose);
      final engine = _FakeAudioEngine();
      final handler = MeloAudioHandler(
        audioEngine: engine,
        audioSession: session,
      );
      addTearDown(handler.dispose);

      final tracks = [
        const MediaItem(id: '/music/track1.mp3', title: 'Track 1'),
      ];
      await handler.replaceQueue(tracks, playWhenReady: true);
      expect(engine.stateFor(AudioDeck.a).playing, isTrue);

      session.triggerBecomingNoisy();
      await pumpEventQueue();

      expect(engine.stateFor(AudioDeck.a).playing, isFalse);
      expect(handler.playbackState.value.playing, isFalse);
    },
  );
}

class _FakeAudioEngine implements AudioEngine {
  final _states = StreamController<AudioDeckState>.broadcast();
  final _errors = StreamController<AudioEngineError>.broadcast();
  final Map<Uri, Duration> trackDurations = {};
  final Map<AudioDeck, AudioDeckSource> lastLoadedSource = {};
  final List<double> overlapGainSums = [];
  final _deckStates = {
    for (final deck in AudioDeck.values)
      deck: AudioDeckState(
        deck: deck,
        processingState: AudioDeckProcessingState.idle,
        playing: false,
        position: Duration.zero,
        bufferedPosition: Duration.zero,
        duration: null,
        gain: 1,
        playbackRate: 1,
        loaded: false,
      ),
  };
  bool _initialized = false;
  bool _disposed = false;
  bool failNextDeckBLoad = false;

  @override
  Stream<AudioDeckState> get states => _states.stream;

  @override
  Stream<AudioEngineError> get errors => _errors.stream;

  @override
  Future<void> initialize() async {
    _initialized = true;
  }

  @override
  AudioDeckState stateFor(AudioDeck deck) => _deckStates[deck]!;

  @override
  Future<void> loadDeck(AudioDeck deck, AudioDeckSource source) async {
    _checkReady();
    if (deck == AudioDeck.b && failNextDeckBLoad) {
      failNextDeckBLoad = false;
      throw StateError('diagnostic source failure');
    }
    lastLoadedSource[deck] = source;
    _update(
      deck,
      processingState: AudioDeckProcessingState.ready,
      playing: false,
      position: Duration.zero,
      duration: trackDurations[source.uri] ?? const Duration(minutes: 3),
      loaded: true,
    );
  }

  @override
  Future<void> unloadDeck(AudioDeck deck) async {
    _checkReady();
    _update(
      deck,
      processingState: AudioDeckProcessingState.idle,
      playing: false,
      position: Duration.zero,
      duration: null,
      loaded: false,
    );
  }

  @override
  Future<void> playDeck(AudioDeck deck) async {
    _checkReady();
    _update(
      deck,
      processingState: AudioDeckProcessingState.ready,
      playing: true,
    );
    _recordActiveGainSum();
  }

  @override
  Future<void> pauseDeck(AudioDeck deck) async {
    _checkReady();
    _update(deck, playing: false);
  }

  @override
  Future<void> stopDeck(AudioDeck deck) async {
    _checkReady();
    _update(deck, playing: false);
  }

  @override
  Future<void> seekDeck(AudioDeck deck, Duration position) async {
    _checkReady();
    _update(deck, position: position);
  }

  @override
  Future<void> setDeckGain(AudioDeck deck, double gain) async {
    _checkReady();
    _update(deck, gain: gain);
    _recordActiveGainSum();
  }

  void _recordActiveGainSum() {
    final a = _deckStates[AudioDeck.a]!;
    final b = _deckStates[AudioDeck.b]!;
    if (a.playing && b.playing) {
      overlapGainSums.add(a.gain + b.gain);
    } else if (a.playing) {
      overlapGainSums.add(a.gain);
    } else if (b.playing) {
      overlapGainSums.add(b.gain);
    }
  }

  @override
  Future<void> promoteIncomingDeck() async {
    _checkReady();
    final previousA = _deckStates[AudioDeck.a]!;
    final previousB = _deckStates[AudioDeck.b]!;
    _deckStates[AudioDeck.a] = _withDeck(previousB, AudioDeck.a);
    _deckStates[AudioDeck.b] = _withDeck(previousA, AudioDeck.b);
    _states
      ..add(_deckStates[AudioDeck.a]!)
      ..add(_deckStates[AudioDeck.b]!);
  }

  void complete(AudioDeck deck) {
    _update(
      deck,
      processingState: AudioDeckProcessingState.completed,
      playing: false,
    );
  }

  void failDeck(AudioDeck deck) {
    final error = StateError('Test playback failure');
    _errors.add(
      AudioEngineError(
        deck: deck,
        error: error,
        stackTrace: StackTrace.current,
      ),
    );
  }

  void _update(
    AudioDeck deck, {
    AudioDeckProcessingState? processingState,
    bool? playing,
    Duration? position,
    Duration? duration,
    double? gain,
    bool? loaded,
  }) {
    final previous = _deckStates[deck]!;
    final next = AudioDeckState(
      deck: deck,
      processingState: processingState ?? previous.processingState,
      playing: playing ?? previous.playing,
      position: position ?? previous.position,
      bufferedPosition: position ?? previous.bufferedPosition,
      duration: duration ?? previous.duration,
      gain: gain ?? previous.gain,
      playbackRate: previous.playbackRate,
      loaded: loaded ?? previous.loaded,
    );
    _deckStates[deck] = next;
    _states.add(next);
  }

  AudioDeckState _withDeck(AudioDeckState state, AudioDeck deck) =>
      AudioDeckState(
        deck: deck,
        processingState: state.processingState,
        playing: state.playing,
        position: state.position,
        bufferedPosition: state.bufferedPosition,
        duration: state.duration,
        gain: state.gain,
        playbackRate: state.playbackRate,
        loaded: state.loaded,
        error: state.error,
      );

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _states.close();
    await _errors.close();
  }

  void _checkReady() {
    if (!_initialized) throw StateError('Engine is not initialized.');
    if (_disposed) throw StateError('Engine is disposed.');
  }
}

class _FakeAudioSession extends Fake implements AudioSession {
  final StreamController<AudioInterruptionEvent> _interruptionController =
      StreamController<AudioInterruptionEvent>.broadcast();
  final StreamController<void> _noisyController =
      StreamController<void>.broadcast();

  bool active = false;

  @override
  Stream<AudioInterruptionEvent> get interruptionEventStream =>
      _interruptionController.stream;

  @override
  Stream<void> get becomingNoisyEventStream => _noisyController.stream;

  @override
  Future<bool> setActive(
    bool active, {
    AVAudioSessionSetActiveOptions? avAudioSessionSetActiveOptions,
    AndroidAudioFocusGainType? androidAudioFocusGainType,
    AndroidAudioAttributes? androidAudioAttributes,
    bool? androidWillPauseWhenDucked,
    AudioSessionConfiguration fallbackConfiguration =
        const AudioSessionConfiguration.music(),
  }) async {
    this.active = active;
    return true;
  }

  @override
  Future<void> configure(AudioSessionConfiguration configuration) async {}

  void triggerInterruption(AudioInterruptionEvent event) {
    _interruptionController.add(event);
  }

  void triggerBecomingNoisy() {
    _noisyController.add(null);
  }

  void dispose() {
    _interruptionController.close();
    _noisyController.close();
  }
}
