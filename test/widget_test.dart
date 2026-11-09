import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:melo_player/app/melo_app.dart';
import 'package:melo_player/app/melo_theme.dart';
import 'package:melo_player/features/player/audio_profile.dart';
import 'package:melo_player/features/player/mini_player.dart';
import 'package:melo_player/features/player/audio_profile_service.dart';
import 'package:melo_player/features/player/lyrics_repository.dart';
import 'package:melo_player/features/mix/local_discovery.dart';
import 'package:melo_player/features/shell/app_shell.dart';
import 'package:melo_player/features/library/music_library.dart';
import 'package:melo_player/features/library/playlist_detail_screen.dart';
import 'package:melo_player/features/home/home_screen.dart';
import 'package:melo_player/features/settings/you_screen.dart';

void main() {
  test('app color system uses red as its primary accent', () {
    expect(MeloTheme.light.colorScheme.primary, const Color(0xFFFA243C));
    expect(MeloTheme.dark.colorScheme.primary, const Color(0xFFFA243C));
    expect(MeloTheme.dark.colorScheme.surface, const Color(0xFF000000));
  });

  testWidgets('artwork requests embedded cover from its audio source', (
    tester,
  ) async {
    const channel = MethodChannel('app.melo.melo_player/library');
    final calls = <MethodCall>[];
    final sourceUri = Uri.parse(
      'content://media/external/audio/cache-test-${DateTime.now().microsecondsSinceEpoch}',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AlbumArtwork(size: 96, title: 'A song', sourceUri: sourceUri),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();

    expect(calls, hasLength(1));
    expect(calls.single.method, 'getArtwork');
    expect(calls.single.arguments, {
      'uri': null,
      'sourceUri': sourceUri.toString(),
    });
  });

  testWidgets('now playing shows total duration and a clean artist fallback', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('app.melo.melo_player/library');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'readAudioWaveform') {
            return List<double>.filled(256, 0.4);
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    tester.view.physicalSize = const Size(432, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final handler = _PreviewAudioHandler()
      ..queue.add([
        const MediaItem(
          id: 'local-track',
          title: 'Evening Walk',
          duration: Duration(minutes: 5, seconds: 35),
        ),
        const MediaItem(
          id: 'next-track',
          title: 'Next Song',
          duration: Duration(minutes: 4),
        ),
      ])
      ..mediaItem.add(
        const MediaItem(
          id: 'local-track',
          title: 'Evening Walk',
          artist: 'Unknown artist',
          album: 'Unknown album',
          duration: Duration(minutes: 5, seconds: 35),
        ),
      )
      ..playbackState.add(
        PlaybackState(
          processingState: AudioProcessingState.ready,
          playing: false,
          updatePosition: const Duration(minutes: 2, seconds: 28),
        ),
      );

    await tester.pumpWidget(
      MaterialApp(home: NowPlayingScreen(audioHandler: handler)),
    );
    await tester.pumpAndSettle();

    expect(find.text('5:35'), findsOneWidget);
    expect(find.text('2:28'), findsOneWidget);
    expect(find.text('From your library'), findsOneWidget);
    expect(find.text('Unknown artist'), findsNothing);
    expect(find.byTooltip('Play'), findsOneWidget);
    expect(find.byTooltip('Turn shuffle on'), findsOneWidget);
    expect(find.byTooltip('Repeat all'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Play'));
    await tester.pump();
    expect(handler.actions, contains('play'));

    expect(find.text('MIX NEXT'), findsOneWidget);
    expect(find.text('Manual crossfade · 10 sec'), findsOneWidget);
    await tester.tap(
      find.byTooltip('Manually crossfade to the next track over 10 seconds'),
    );
    await tester.pump();
    expect(handler.actions, contains('custom:autoMix.transitionToNextTrack'));

    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    expect(handler.actions, contains('pause'));

    await tester.tap(find.byTooltip('Turn shuffle on'));
    await tester.pump();
    expect(handler.actions, contains('shuffle:all'));

    await tester.tap(find.byTooltip('Repeat all'));
    await tester.pump();
    expect(handler.actions, contains('repeat:all'));

    await tester.drag(find.byType(Slider), const Offset(90, 0));
    await tester.pump();
    expect(handler.actions.any((action) => action.startsWith('seek:')), isTrue);

    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Up next'));
    await tester.pumpAndSettle();
    expect(find.text('Next Song'), findsOneWidget);
    await tester.tap(find.text('Next Song'));
    await tester.pumpAndSettle();
    expect(handler.actions, contains('queue:1'));

    await tester.tap(find.byTooltip('Previous track'));
    await tester.pump();
    expect(handler.actions, contains('previous'));

    await tester.tap(find.byTooltip('Next track'));
    await tester.pump();
    expect(handler.actions, contains('next'));
  });

  testWidgets('now playing progress advances smoothly while playing', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('app.melo.melo_player/library');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    tester.view.physicalSize = const Size(432, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final handler = _PreviewAudioHandler()
      ..mediaItem.add(
        const MediaItem(
          id: 'moving-progress',
          title: 'Moving progress',
          artist: 'Tone Test',
          duration: Duration(minutes: 1),
        ),
      )
      ..playbackState.add(
        PlaybackState(
          processingState: AudioProcessingState.ready,
          playing: false,
          updatePosition: Duration.zero,
        ),
      );
    await tester.pumpWidget(
      MaterialApp(home: NowPlayingScreen(audioHandler: handler)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Play'));
    await tester.pump();
    handler.playbackState.add(
      handler.playbackState.value.copyWith(
        updatePosition: const Duration(milliseconds: 350),
      ),
    );
    await tester.pump();

    final progress = tester.widget<Slider>(find.byType(Slider));
    expect(progress.value, greaterThan(0));
    expect(progress.value, lessThan(const Duration(seconds: 1).inMilliseconds));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Now Playing disposes cleanly during a manual transition', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('app.melo.melo_player/library');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    final handler = _PreviewAudioHandler()
      ..queue.add([
        const MediaItem(
          id: 'current-track',
          title: 'Current track',
          duration: Duration(minutes: 3),
        ),
        const MediaItem(
          id: 'next-track',
          title: 'Next track',
          duration: Duration(minutes: 4),
        ),
      ])
      ..mediaItem.add(
        const MediaItem(
          id: 'current-track',
          title: 'Current track',
          duration: Duration(minutes: 3),
        ),
      )
      ..playbackState.add(
        PlaybackState(
          processingState: AudioProcessingState.ready,
          playing: true,
        ),
      );
    handler.transitionCompletion = Completer<dynamic>();

    await tester.pumpWidget(
      MaterialApp(home: NowPlayingScreen(audioHandler: handler)),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byTooltip('Manually crossfade to the next track over 10 seconds'),
    );
    await tester.pump();

    expect(find.text('MIXING'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);

    handler.transitionCompletion!.complete({'completed': false});
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Now Playing analyzes current and next waveform cues', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('app.melo.melo_player/library');
    final outgoing = [
      ...List<double>.filled(230, 0.65),
      ...List<double>.filled(26, 0.01),
    ];
    final incoming = [
      ...List<double>.filled(12, 0.02),
      ...List<double>.filled(244, 0.7),
    ];
    final waveformRequests = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method != 'readAudioWaveform') return null;
          final arguments = call.arguments! as Map;
          final uri = arguments['uri']! as String;
          waveformRequests.add(uri);
          return uri == 'outgoing-cue-track' ? outgoing : incoming;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    tester.view.physicalSize = const Size(432, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final handler = _PreviewAudioHandler()
      ..queue.add([
        const MediaItem(
          id: 'outgoing-cue-track',
          title: 'Outgoing',
          duration: Duration(seconds: 256),
        ),
        const MediaItem(
          id: 'incoming-cue-track',
          title: 'Incoming',
          duration: Duration(seconds: 256),
        ),
      ])
      ..mediaItem.add(
        const MediaItem(
          id: 'outgoing-cue-track',
          title: 'Outgoing',
          duration: Duration(seconds: 256),
        ),
      )
      ..playbackState.add(
        PlaybackState(
          processingState: AudioProcessingState.ready,
          playing: true,
        ),
      );

    await tester.pumpWidget(
      MaterialApp(home: NowPlayingScreen(audioHandler: handler)),
    );
    await tester.pumpAndSettle();

    expect(
      waveformRequests,
      containsAll(['outgoing-cue-track', 'incoming-cue-track']),
    );
    expect(
      find.textContaining('Quiet outro 3:50 · Quiet intro 0:12'),
      findsOneWidget,
    );
    expect(find.text('No quiet intro/outro detected'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home surfaces artist radio for library artists', (tester) async {
    final directory = await tester.runAsync(
      () => Directory.systemTemp.createTemp('tone-home-taste-'),
    );
    if (directory == null) fail('Could not create taste test directory.');
    addTearDown(() => tester.runAsync(() => directory.delete(recursive: true)));
    addTearDown(() => directory.delete(recursive: true));

    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final library = MusicLibrary.forTesting(
      musicDirectory: directory,
      preferences: preferences,
      pickAudio: () async => const [],
      scanDeviceAudio: () async => const [
        DeviceAudio(
          uri: 'content://media/external/audio/media/999',
          name: 'electronic.mp3',
          title: 'Night Signal',
          artist: 'Tone Test',
          genre: 'Electronic',
          bpm: 120,
        ),
      ],
    );
    await library.scanDeviceMusic();
    addTearDown(library.close);
    final handler = _PreviewAudioHandler();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeScreen(
            onOpenLibrary: () {},
            library: library,
            audioHandler: handler,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Artist Radio'), findsOneWidget);
    expect(find.text('Tone Test'), findsAtLeastNWidgets(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('queue sheet removes upcoming songs and protects current song', (
    tester,
  ) async {
    final handler = _PreviewAudioHandler()
      ..queue.add(const [
        MediaItem(id: 'previous', title: 'Previous song'),
        MediaItem(id: 'current', title: 'Current song'),
        MediaItem(id: 'next', title: 'Next song'),
        MediaItem(id: 'later', title: 'Later song'),
      ])
      ..mediaItem.add(const MediaItem(id: 'current', title: 'Current song'))
      ..playbackState.add(
        PlaybackState(
          processingState: AudioProcessingState.ready,
          playing: false,
          queueIndex: 1,
        ),
      );

    await tester.pumpWidget(
      MaterialApp(home: NowPlayingScreen(audioHandler: handler)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Up next'));
    await tester.pumpAndSettle();

    expect(find.text('Current song'), findsNWidgets(2));
    expect(find.text('Previous song'), findsNothing);
    expect(find.byTooltip('Remove from queue'), findsNWidgets(2));
    await tester.tap(find.byTooltip('Remove from queue').first);
    await tester.pumpAndSettle();

    expect(handler.queue.value, hasLength(3));
    expect(handler.queue.value[1].id, 'current');
    expect(find.text('Current song'), findsNWidgets(2));
    expect(find.byTooltip('Remove from queue'), findsOneWidget);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(handler.queue.value.map((item) => item.id), ['previous', 'current']);
    expect(find.text('Nothing else is queued.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Now Playing keeps the reference-inspired layout and app tabs', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('app.melo.melo_player/library');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    tester.view.physicalSize = const Size(432, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final handler = _PreviewAudioHandler()
      ..mediaItem.add(
        const MediaItem(
          id: 'reference-layout-track',
          title: 'Quiet Motion',
          artist: 'Tone Test',
          duration: Duration(minutes: 3),
        ),
      )
      ..playbackState.add(
        PlaybackState(
          processingState: AudioProcessingState.ready,
          playing: false,
        ),
      );
    int? destination;

    await tester.pumpWidget(
      MaterialApp(
        home: NowPlayingScreen(
          audioHandler: handler,
          onNavigate: (index) => destination = index,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      MeloColors.amoled,
    );
    expect(find.text('Quiet Motion'), findsOneWidget);
    expect(find.text('Tone Test'), findsOneWidget);
    expect(find.byType(AlbumArtwork), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('You'), findsOneWidget);

    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    expect(destination, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Now Playing shows decoded waveform and retries failures', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('app.melo.melo_player/library');
    var failWaveform = true;
    var waveformRequests = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'readAudioWaveform') {
            waveformRequests++;
            if (failWaveform) {
              throw PlatformException(
                code: 'AUDIO_WAVEFORM_READ_FAILED',
                message: 'The source cannot be decoded.',
              );
            }
            return List<double>.generate(256, (index) => (index % 16) / 15);
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    tester.view.physicalSize = const Size(432, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final handler = _PreviewAudioHandler()
      ..mediaItem.add(
        const MediaItem(
          id: 'waveform-track',
          title: 'Moving Shape',
          artist: 'Tone Test',
          duration: Duration(minutes: 3),
          extras: {'bpm': 120},
        ),
      )
      ..playbackState.add(
        PlaybackState(
          processingState: AudioProcessingState.ready,
          playing: false,
        ),
      );
    await tester.pumpWidget(
      MaterialApp(home: NowPlayingScreen(audioHandler: handler)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Retry waveform'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    expect(waveformRequests, 1);

    failWaveform = false;
    await tester.tap(find.text('Retry waveform'));
    await tester.pumpAndSettle();

    expect(find.byType(Slider), findsOneWidget);
    expect(SliderTheme.of(tester.element(find.byType(Slider))).trackHeight, 34);
    expect(waveformRequests, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('now playing automatically loads lyrics for the active song', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('app.melo.melo_player/library');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'readLyrics') {
            return '[00:00.00]A line that follows the song';
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    tester.view.physicalSize = const Size(432, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final handler = _PreviewAudioHandler()
      ..mediaItem.add(
        const MediaItem(
          id: 'song-with-lyrics',
          title: 'A song',
          artist: 'Tone Test',
          duration: Duration(minutes: 3),
          extras: {'lyricsUri': 'content://music/lyrics/song.lrc'},
        ),
      )
      ..playbackState.add(
        PlaybackState(
          processingState: AudioProcessingState.ready,
          playing: false,
          updatePosition: Duration.zero,
        ),
      );
    await tester.pumpWidget(
      MaterialApp(home: NowPlayingScreen(audioHandler: handler)),
    );
    await tester.pumpAndSettle();

    // The always-on lyric preview shows the current line before expanding.
    expect(find.text('A line that follows the song'), findsOneWidget);

    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read lyrics'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('A line that follows the song'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('live lyrics mode follows the song on the Now Playing screen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('app.melo.melo_player/library');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'readLyrics') {
            return '[00:00.00]First live line\n[00:10.00]Second live line';
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    tester.view.physicalSize = const Size(432, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final handler = _PreviewAudioHandler()
      ..mediaItem.add(
        const MediaItem(
          id: 'song-with-live-lyrics',
          title: 'A song',
          artist: 'Tone Test',
          duration: Duration(minutes: 3),
          extras: {'lyricsUri': 'content://music/lyrics/song.lrc'},
        ),
      )
      ..playbackState.add(
        PlaybackState(
          processingState: AudioProcessingState.ready,
          playing: false,
          updatePosition: const Duration(seconds: 12),
        ),
      );
    await tester.pumpWidget(
      MaterialApp(home: NowPlayingScreen(audioHandler: handler)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Show live lyrics'));
    await tester.pumpAndSettle();

    expect(find.text('LYRICS'), findsOneWidget);
    expect(find.text('LINE SYNC'), findsOneWidget);
    expect(find.text('First live line'), findsOneWidget);
    expect(find.text('Second live line'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Show artwork'));
    await tester.pumpAndSettle();
    expect(find.text('LYRICS'), findsNothing);
    expect(find.byTooltip('Show live lyrics'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('live lyrics mode offers to find lyrics when none are saved', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('app.melo.melo_player/library');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    tester.view.physicalSize = const Size(432, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final handler = _PreviewAudioHandler()
      ..mediaItem.add(
        const MediaItem(
          id: 'song-with-no-lyrics',
          title: 'A song',
          artist: 'Tone Test',
          duration: Duration(minutes: 3),
        ),
      )
      ..playbackState.add(
        PlaybackState(
          processingState: AudioProcessingState.ready,
          playing: false,
          updatePosition: Duration.zero,
        ),
      );
    await tester.pumpWidget(
      MaterialApp(home: NowPlayingScreen(audioHandler: handler)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Show live lyrics'));
    await tester.pumpAndSettle();

    expect(find.text('No lyrics yet'), findsOneWidget);
    expect(find.text('Find online'), findsOneWidget);
    expect(find.text('Add file'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('online lyrics explain the metadata request before opt-in', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('app.melo.melo_player/library');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    tester.view.physicalSize = const Size(432, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final handler = _PreviewAudioHandler()
      ..mediaItem.add(
        const MediaItem(
          id: 'song-without-lyrics',
          title: 'A song',
          artist: 'Tone Test',
        ),
      )
      ..playbackState.add(
        PlaybackState(
          processingState: AudioProcessingState.ready,
          playing: false,
          updatePosition: Duration.zero,
        ),
      );
    await tester.pumpWidget(
      MaterialApp(home: NowPlayingScreen(audioHandler: handler)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find lyrics online'));
    await tester.pumpAndSettle();
    expect(find.text('Find lyrics online?'), findsOneWidget);
    expect(
      find.textContaining('song’s title, artist, album, and duration'),
      findsOneWidget,
    );
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(await LyricsRepository.onlineLookupEnabled, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('synchronized lyrics sheet follows playback position', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('app.melo.melo_player/library');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'readLyrics') {
            return '[00:00.00]First line\n[00:01.00]Second line';
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    tester.view.physicalSize = const Size(432, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final handler = _PreviewAudioHandler()
      ..mediaItem.add(
        const MediaItem(
          id: 'song-with-synced-lyrics',
          title: 'A song',
          artist: 'Tone Test',
          duration: Duration(minutes: 3),
          extras: {'lyricsUri': 'content://music/lyrics/song.lrc'},
        ),
      )
      ..playbackState.add(
        PlaybackState(
          processingState: AudioProcessingState.ready,
          playing: false,
          updatePosition: Duration.zero,
        ),
      );
    await tester.pumpWidget(
      MaterialApp(home: NowPlayingScreen(audioHandler: handler)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read lyrics'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('First line'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('active-lyrics-line')))
          .data,
      'First line',
    );

    await handler.seek(const Duration(milliseconds: 1500));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('active-lyrics-line')))
          .data,
      'Second line',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('word-synced lyrics highlight each timed word', (tester) async {
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('app.melo.melo_player/library');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'readLyrics') {
            return '[00:00.00]<00:00.00>First <00:01.00>word';
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    tester.view.physicalSize = const Size(432, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final handler = _PreviewAudioHandler()
      ..mediaItem.add(
        const MediaItem(
          id: 'song-with-word-timing',
          title: 'A song',
          artist: 'Tone Test',
          duration: Duration(minutes: 3),
          extras: {'lyricsUri': 'content://music/lyrics/song.lrc'},
        ),
      )
      ..playbackState.add(
        PlaybackState(
          processingState: AudioProcessingState.ready,
          playing: false,
          updatePosition: const Duration(milliseconds: 500),
        ),
      );
    await tester.pumpWidget(
      MaterialApp(home: NowPlayingScreen(audioHandler: handler)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read lyrics'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('First word'),
      ),
    );
    await tester.pumpAndSettle();

    Text activeLine = tester.widget<Text>(
      find.byKey(const ValueKey('active-lyrics-line')),
    );
    var words = (activeLine.textSpan! as TextSpan).children!.cast<TextSpan>();
    expect(words[0].style?.color, const Color(0xFFFF827A));
    expect(words[1].style?.color, isNull);

    await handler.seek(const Duration(milliseconds: 1200));
    await tester.pump();

    activeLine = tester.widget<Text>(
      find.byKey(const ValueKey('active-lyrics-line')),
    );
    words = (activeLine.textSpan! as TextSpan).children!.cast<TextSpan>();
    expect(words[0].style?.color, isNull);
    expect(words[1].style?.color, const Color(0xFFFF827A));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Now Playing shows the source codec and encoded audio details', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('app.melo.melo_player/library');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'readAudioQuality') {
            return {
              'mimeType': 'audio/flac',
              'sampleRate': 96000,
              'channelCount': 2,
              'bitRate': 3000000,
            };
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    tester.view.physicalSize = const Size(432, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final handler = _PreviewAudioHandler()
      ..mediaItem.add(
        const MediaItem(
          id: 'flac-quality-details',
          title: 'A song',
          artist: 'Tone Test',
          duration: Duration(minutes: 3),
        ),
      )
      ..playbackState.add(
        PlaybackState(
          processingState: AudioProcessingState.ready,
          playing: false,
        ),
      );
    await tester.pumpWidget(
      MaterialApp(home: NowPlayingScreen(audioHandler: handler)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Track details'));
    await tester.pumpAndSettle();
    expect(calls.any((call) => call.method == 'readAudioQuality'), isTrue);
    await tester.scrollUntilVisible(
      find.text('Codec'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('FLAC'), findsAtLeastNWidgets(2));
    expect(find.text('96 kHz'), findsOneWidget);
    expect(find.text('Stereo'), findsOneWidget);
    expect(find.text('3000 kbps'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Now Playing exposes complete tagged track details', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('app.melo.melo_player/library');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'readAudioQuality') {
            return {
              'mimeType': 'audio/flac',
              'sampleRate': 96000,
              'channelCount': 2,
              'bitRate': 3000000,
            };
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    tester.view.physicalSize = const Size(432, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final handler = _PreviewAudioHandler()
      ..mediaItem.add(
        const MediaItem(
          id: 'detailed-track',
          title: 'A song',
          artist: 'Tone Test',
          album: 'An album',
          duration: Duration(minutes: 3, seconds: 12),
          extras: {
            'year': 2024,
            'trackNumber': 7,
            'genre': 'House',
            'bpm': 124,
            'source': 'device',
          },
        ),
      )
      ..playbackState.add(
        PlaybackState(
          processingState: AudioProcessingState.ready,
          playing: false,
        ),
      );
    await tester.pumpWidget(
      MaterialApp(home: NowPlayingScreen(audioHandler: handler)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Track details'));
    await tester.pumpAndSettle();
    expect(find.text('Release year'), findsOneWidget);
    expect(find.text('2024'), findsOneWidget);
    expect(find.text('An album'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('House'), findsOneWidget);
    expect(find.text('124 BPM'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Codec'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('FLAC'), findsAtLeastNWidgets(2));
    expect(find.text('96 kHz'), findsOneWidget);
    expect(find.text('Stereo'), findsOneWidget);
    expect(find.text('3000 kbps'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('artwork drags do not scratch the deck from Now Playing', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('app.melo.melo_player/library');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    tester.view.physicalSize = const Size(432, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final handler = _PreviewAudioHandler()
      ..mediaItem.add(
        const MediaItem(
          id: 'scratch-track',
          title: 'A song',
          artist: 'Tone Test',
          duration: Duration(minutes: 3),
        ),
      )
      ..playbackState.add(
        PlaybackState(
          processingState: AudioProcessingState.ready,
          playing: true,
        ),
      );
    await tester.pumpWidget(
      MaterialApp(home: NowPlayingScreen(audioHandler: handler)),
    );
    await tester.pump(const Duration(milliseconds: 350));

    await tester.drag(
      find.bySemanticsLabel('Artwork for A song').last,
      const Offset(80, 0),
    );
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('DECK NUDGE'), findsNothing);
    expect(
      handler.actions.where((action) => action.startsWith('scratch:')),
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Now Playing exposes standard playback controls', (tester) async {
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('app.melo.melo_player/library');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    tester.view.physicalSize = const Size(432, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final handler = _PreviewAudioHandler()
      ..mediaItem.add(
        const MediaItem(
          id: 'mix-track',
          title: 'A song',
          artist: 'Tone Test',
          duration: Duration(minutes: 3),
          extras: {'bpm': 124},
        ),
      )
      ..playbackState.add(
        PlaybackState(
          processingState: AudioProcessingState.ready,
          playing: true,
        ),
      );
    await tester.pumpWidget(
      MaterialApp(home: NowPlayingScreen(audioHandler: handler)),
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.text('VIRTUAL DECK'), findsNothing);
    expect(find.text('DECK A'), findsNothing);
    expect(find.text('DECK B'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('now playing fits compact phone layouts without overflow', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('app.melo.melo_player/library');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final handler = _PreviewAudioHandler()
      ..mediaItem.add(
        const MediaItem(
          id: 'compact-track',
          title: 'A song title long enough to wrap on a compact device',
          artist: 'A local artist',
          duration: Duration(minutes: 4, seconds: 12),
        ),
      )
      ..playbackState.add(
        PlaybackState(
          processingState: AudioProcessingState.ready,
          playing: false,
        ),
      );
    await tester.pumpWidget(
      MaterialApp(home: NowPlayingScreen(audioHandler: handler)),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Previous track'), findsOneWidget);
    expect(find.byTooltip('Next track'), findsOneWidget);
    expect(find.text('4:12'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Settings rows remain available in the reduced navigation', (
    tester,
  ) async {
    await tester.pumpWidget(const MeloApp.preview());

    expect(find.byType(NavigationDestination), findsNWidgets(3));
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(
      List.generate(
        3,
        (index) => tester
            .widget<TickerMode>(
              find.byKey(ValueKey('destination-$index'), skipOffstage: false),
            )
            .enabled,
      ),
      [true, false, false],
    );
    expect(find.text('Flow'), findsNothing);
    expect(find.text('Tone Flow'), findsNothing);

    await tester.tap(find.text('You'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Sound & playback'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Sound & playback'));
    await tester.pumpAndSettle();
    expect(find.text('Sound & playback'), findsWidgets);
  });

  testWidgets('Home surfaces stations and curated top picks', (tester) async {
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('app.melo.melo_player/library');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    tester.view.physicalSize = const Size(432, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final preferences = await SharedPreferences.getInstance();
    final directory = await tester.runAsync(
      () => Directory.systemTemp.createTemp('tone-mood-widget-'),
    );
    if (directory == null) fail('Could not create mood test directory.');
    addTearDown(() => tester.runAsync(() => directory.delete(recursive: true)));
    addTearDown(() => directory.delete(recursive: true));

    final library = MusicLibrary.forTesting(
      musicDirectory: directory,
      preferences: preferences,
      pickAudio: () async => const [],
      scanDeviceAudio: () async => const [
        DeviceAudio(
          uri: 'content://media/external/audio/media/801',
          name: 'soul.mp3',
          title: 'Warm Start',
          artist: 'Tone Test',
          genre: 'Soul',
          bpm: 100,
          durationMs: 180000,
        ),
      ],
    );
    await library.load();
    await library.scanDeviceMusic();
    final handler = _PreviewAudioHandler();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeScreen(
            onOpenLibrary: () {},
            library: library,
            audioHandler: handler,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Top Picks for You'), findsOneWidget);
    expect(find.text('Stations for You'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home surfaces favorites and saved playlists', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final directory = await tester.runAsync(
      () => Directory.systemTemp.createTemp('tone-home-listening-'),
    );
    if (directory == null) fail('Could not create home test directory.');
    addTearDown(() => tester.runAsync(() => directory.delete(recursive: true)));
    addTearDown(() => directory.delete(recursive: true));

    final library = MusicLibrary.forTesting(
      musicDirectory: directory,
      preferences: preferences,
      pickAudio: () async => const [],
      scanDeviceAudio: () async => const [
        DeviceAudio(
          uri: 'content://media/external/audio/media/901',
          name: 'favorite.mp3',
          title: 'Favorite Song',
          artist: 'Tone Test',
        ),
      ],
    );
    await library.scanDeviceMusic();
    final track = library.tracks.single;
    await library.toggleFavorite(track.id);
    final playlist = await library.createPlaylist('Mornye downloads');
    await library.addTracksToPlaylist(playlist.id, [track.id]);
    final handler = _PreviewAudioHandler();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeScreen(
            onOpenLibrary: () {},
            library: library,
            audioHandler: handler,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your listening'), findsOneWidget);
    expect(find.text('FAVORITES'), findsOneWidget);
    expect(find.textContaining('1 saved'), findsOneWidget);
    expect(find.text('MOST PLAYED'), findsOneWidget);
    expect(find.text('No plays yet'), findsOneWidget);
    expect(find.text('Your playlists'), findsOneWidget);
    await tester.ensureVisible(find.text('Mornye downloads'));
    await tester.pumpAndSettle();
    expect(find.text('Mornye downloads'), findsOneWidget);
    await tester.tap(find.text('Mornye downloads'));
    await tester.pumpAndSettle();
    expect(find.byType(PlaylistDetailScreen), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pumpAndSettle();
    expect(handler.queue.value.map((item) => item.title), ['Favorite Song']);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('FAVORITES'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('FAVORITES'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(handler.queue.value.map((item) => item.title), ['Favorite Song']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home does not duplicate current playback controls', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('app.melo.melo_player/library');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    tester.view.physicalSize = const Size(432, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final handler = _PreviewAudioHandler()
      ..mediaItem.add(
        const MediaItem(
          id: 'content://media/external/audio/media/90',
          title: 'Afterglow',
          artist: 'Tone Test',
          duration: Duration(minutes: 3),
        ),
      )
      ..playbackState.add(
        PlaybackState(
          processingState: AudioProcessingState.ready,
          playing: false,
          updatePosition: const Duration(seconds: 45),
        ),
      );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeScreen(onOpenLibrary: () {}, audioHandler: handler),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Continue listening'), findsNothing);
    expect(find.text('Afterglow'), findsNothing);
    expect(find.byTooltip('Play'), findsNothing);
    expect(find.text('Search'), findsNothing);
    expect(find.text('Library'), findsNothing);
    expect(find.text('Flow'), findsNothing);
    expect(find.text('You'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home starts local artist radio and saves playlist sparks', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('app.melo.melo_player/library');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    tester.view.physicalSize = const Size(432, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final preferences = await SharedPreferences.getInstance();
    final directory = await tester.runAsync(
      () => Directory.systemTemp.createTemp('tone-discovery-widget-'),
    );
    if (directory == null) fail('Could not create discovery test directory.');
    addTearDown(() => tester.runAsync(() => directory.delete(recursive: true)));
    addTearDown(() => directory.delete(recursive: true));

    final library = MusicLibrary.forTesting(
      musicDirectory: directory,
      preferences: preferences,
      pickAudio: () async => const [],
      scanDeviceAudio: () async => const [
        DeviceAudio(
          uri: 'content://media/external/audio/media/701',
          name: 'artist-one.mp3',
          title: 'Artist one',
          artist: 'Artist A',
          genre: 'Electronic',
          bpm: 120,
          durationMs: 180000,
        ),
        DeviceAudio(
          uri: 'content://media/external/audio/media/702',
          name: 'artist-two.mp3',
          title: 'Artist two',
          artist: 'Artist A',
          genre: 'Electronic',
          bpm: 122,
          durationMs: 180000,
        ),
        DeviceAudio(
          uri: 'content://media/external/audio/media/703',
          name: 'genre-three.mp3',
          title: 'Genre three',
          artist: 'Artist B',
          genre: 'Electronic',
          bpm: 124,
          durationMs: 180000,
        ),
      ],
    );
    await library.load();
    await library.scanDeviceMusic();
    await library.toggleFavorite('content://media/external/audio/media/701');
    await library.toggleFavorite('content://media/external/audio/media/702');
    final handler = _PreviewAudioHandler();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeScreen(
            onOpenLibrary: () {},
            library: library,
            audioHandler: handler,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Artist Radio'), findsOneWidget);
    expect(find.text('Artist A'), findsAtLeastNWidgets(1));
    await tester.tap(find.text('Artist A').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Artist A Radio'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();

    handler.playbackState.add(
      handler.playbackState.value.copyWith(playing: false),
    );
    handler.mediaItem.add(library.tracks.first.toMediaItem());
    await tester.pumpWidget(
      MaterialApp(
        home: NowPlayingScreen(audioHandler: handler, musicLibrary: library),
      ),
    );
    await tester.pumpAndSettle();
    final playCountBeforeRadio = handler.actions
        .where((action) => action == 'play')
        .length;
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    expect(find.text('Start artist radio'), findsOneWidget);
    await tester.tap(find.text('Start artist radio'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(handler.queue.value, hasLength(3));
    expect(
      handler.actions.where((action) => action == 'play').length,
      greaterThan(playCountBeforeRadio),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('mix preview starts a playable library queue', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final directory = await tester.runAsync(
      () => Directory.systemTemp.createTemp('tone-mix-widget-'),
    );
    if (directory == null) fail('Could not create the mix test directory.');
    addTearDown(() => tester.runAsync(() => directory.delete(recursive: true)));
    addTearDown(() => directory.delete(recursive: true));
    final library = MusicLibrary.forTesting(
      musicDirectory: directory,
      preferences: preferences,
      pickAudio: () async => [
        PickedAudio(name: 'First.mp3', bytes: Stream.value([1, 2, 3])),
        PickedAudio(name: 'Second.mp3', bytes: Stream.value([4, 5, 6])),
      ],
      readImportedMetadata: (path, title) async => {
        'title': title,
        'artist': 'Local Artist',
        'durationMs': 5 * 60 * 1000,
      },
    );
    await tester.runAsync(library.pickAndImport);
    expect(library.tracks.map((track) => track.title), ['First', 'Second']);
    expect(
      library.generatePersonalMix(
        targetDuration: const Duration(minutes: 30),
        discovery: 0.35,
        randomSeed: 1,
      ),
      hasLength(2),
    );
    final handler = _PreviewAudioHandler();

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      MixSetupScreen(library: library, audioHandler: handler),
                ),
              ),
              child: const Text('Open mix'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open mix'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('First'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('First'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Second'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Second'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Play this mix'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Play this mix'), findsOneWidget);
    await tester.tap(find.text('Play this mix'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(handler.actions, contains('play'));
    expect(handler.queue.value, hasLength(2));
    expect(
      handler.queue.value.map((item) => item.title),
      unorderedEquals(['First', 'Second']),
    );
  });

  testWidgets('bottom navigation opens the honest library empty state', (
    tester,
  ) async {
    await tester.pumpWidget(const MeloApp.preview());
    await tester.tap(find.byIcon(Icons.library_music_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Your library'), findsOneWidget);
    expect(find.text('Your library starts with you.'), findsOneWidget);
    expect(find.text('Scan device'), findsOneWidget);
    expect(find.text('Import files'), findsOneWidget);

    await tester.tap(find.text('Import files'));
    await tester.pump();
    expect(
      find.text('Music import is unavailable in this preview build.'),
      findsOneWidget,
    );
  });

  testWidgets('top-right search and personal settings are reachable', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MeloApp.preview());

    expect(find.text('Search'), findsNothing);
    await tester.tap(find.byTooltip('Search').first);
    await tester.pumpAndSettle();
    expect(find.text('Search'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Personal sources'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();

    for (final destination in ['Library', 'You']) {
      await tester.tap(find.text(destination));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Search'), findsNothing);
      expect(find.byType(NavigationDestination), findsNWidgets(3));
      if (destination == 'Library') {
        await tester.ensureVisible(
          find.byKey(const ValueKey('library-track-filter')),
        );
        expect(
          find.byKey(const ValueKey('library-track-filter')),
          findsOneWidget,
        );
      }
    }
    await tester.pumpAndSettle();
    expect(find.text('Your space'), findsOneWidget);
    expect(find.text('Offline & data'), findsOneWidget);

    await tester.tap(find.text('Offline & data'));
    await tester.pumpAndSettle();
    expect(find.text('Your music, without the signal.'), findsOneWidget);
    expect(
      find.textContaining('Automatic overnight downloads'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Appearance'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    expect(find.text('Built around the album art.'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Offline & data'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Offline & data'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Offline'), findsWidgets);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Privacy & your data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Privacy & your data'));
    await tester.pumpAndSettle();
    expect(find.text('Your data, in your control'), findsOneWidget);
    expect(find.text('Automatic online lyrics'), findsOneWidget);
    expect(find.text('Cached lyrics'), findsOneWidget);
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('There were no cached lyrics to clear.'), findsOneWidget);
  });

  testWidgets('audio settings remain available without DJ controls', (
    tester,
  ) async {
    final handler = _PreviewAudioHandler();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: YouScreen(
            onOpenLibrary: () {},
            onOpenMix: () {},
            audioHandler: handler,
            audioProfileService: AudioServiceAudioProfileService(handler),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Sound & playback'));
    await tester.pumpAndSettle();
    expect(find.text('Make playback sound like yours.'), findsOneWidget);
    expect(find.text('Crossfade duration'), findsNothing);
    expect(find.text('Beat-matched DJ blend'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Approximate loudness leveling'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(handler.audioProfile['loudnessNormalization'], isFalse);
    expect(tester.takeException(), isNull);
  });
}

class _PreviewAudioHandler extends BaseAudioHandler with QueueHandler {
  final List<String> actions = [];
  Map<String, Object?> audioProfile = const AudioProfile().toJson();
  Completer<dynamic>? transitionCompletion;

  @override
  Future<void> removeQueueItem(MediaItem mediaItem) async {
    queue.add(
      queue.value
          .where((item) => item.id != mediaItem.id)
          .toList(growable: false),
    );
  }

  @override
  Future<dynamic> customAction(
    String name, [
    Map<String, dynamic>? extras,
  ]) async {
    actions.add('custom:$name');
    if (name == 'autoMix.getNextTrackForAnalysis') {
      final currentId = mediaItem.value?.id;
      final currentIndex = queue.value.indexWhere(
        (item) => item.id == currentId,
      );
      final nextIndex = currentIndex + 1;
      if (currentIndex >= 0 && nextIndex < queue.value.length) {
        final item = queue.value[nextIndex];
        return {
          'id': item.id,
          'title': item.title,
          'durationMs': item.duration?.inMilliseconds,
        };
      }
      return null;
    }
    if (name == 'autoMix.transitionToNextTrack') {
      if (transitionCompletion case final completion?) {
        return completion.future;
      }
      return {'completed': true, 'trackId': 'next-track'};
    }
    if (name == 'getAudioProfile') return audioProfile;
    if (name == 'getAudioCapabilities') {
      return {
        'equalizer': false,
        'loudnessNormalization': false,
        'balance': false,
        'outputSelection': false,
        'headphoneProfiles': false,
      };
    }
    if (name == 'setAudioProfile') {
      audioProfile = Map<String, Object?>.from(extras!['profile']! as Map);
    }
    return null;
  }

  @override
  Future<void> play() async {
    actions.add('play');
    playbackState.add(playbackState.value.copyWith(playing: true));
  }

  @override
  Future<void> pause() async {
    actions.add('pause');
    playbackState.add(playbackState.value.copyWith(playing: false));
  }

  @override
  Future<void> seek(Duration position) async {
    actions.add('seek:${position.inMilliseconds}');
    playbackState.add(playbackState.value.copyWith(updatePosition: position));
  }

  @override
  Future<void> skipToPrevious() async {
    actions.add('previous');
  }

  @override
  Future<void> skipToNext() async {
    actions.add('next');
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    actions.add('queue:$index');
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    actions.add('repeat:${repeatMode.name}');
    playbackState.add(playbackState.value.copyWith(repeatMode: repeatMode));
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    actions.add('shuffle:${shuffleMode.name}');
    playbackState.add(playbackState.value.copyWith(shuffleMode: shuffleMode));
  }
}
