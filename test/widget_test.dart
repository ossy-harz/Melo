import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tone_player/app/tone_app.dart';
import 'package:tone_player/app/tone_theme.dart';
import 'package:tone_player/features/player/dj_transition.dart';
import 'package:tone_player/features/player/mini_player.dart';
import 'package:tone_player/features/player/lyrics_repository.dart';
import 'package:tone_player/features/shell/app_shell.dart';
import 'package:tone_player/features/library/music_library.dart';
import 'package:tone_player/features/home/home_screen.dart';
import 'package:tone_player/features/settings/you_screen.dart';

void main() {
  test('app color system uses red as its primary accent', () {
    expect(ToneTheme.light.colorScheme.primary, ToneColors.plum);
    expect(ToneTheme.dark.colorScheme.primary, ToneColors.ember);
    expect(ToneTheme.dark.colorScheme.surface, const Color(0xFF0D090B));
  });

  testWidgets('artwork requests embedded cover from its audio source', (
    tester,
  ) async {
    const channel = MethodChannel('app.tone.tone_player/library');
    final calls = <MethodCall>[];
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
          body: AlbumArtwork(
            size: 96,
            title: 'A song',
            sourceUri: Uri.parse('content://media/external/audio/media/17'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(calls, hasLength(1));
    expect(calls.single.method, 'getArtwork');
    expect(calls.single.arguments, {
      'uri': null,
      'sourceUri': 'content://media/external/audio/media/17',
    });
  });

  testWidgets('now playing shows total duration and a clean artist fallback', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('app.tone.tone_player/library');
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
      ..queue.add([
        const MediaItem(id: 'local-track', title: 'Evening Walk'),
        const MediaItem(id: 'next-track', title: 'Next Song'),
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
    const channel = MethodChannel('app.tone.tone_player/library');
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

  testWidgets('Now Playing keeps the reference-inspired layout and app tabs', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('app.tone.tone_player/library');
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
      Colors.white,
    );
    expect(find.text('Quiet Motion'), findsOneWidget);
    expect(find.text('Tone Test'), findsOneWidget);
    expect(find.byType(AlbumArtwork), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('Hotlist'), findsOneWidget);

    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    expect(destination, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Now Playing shows decoded waveform and retries failures', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('app.tone.tone_player/library');
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
    const channel = MethodChannel('app.tone.tone_player/library');
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

    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read lyrics'));
    await tester.pumpAndSettle();
    expect(find.text('A line that follows the song'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('online lyrics explain the metadata request before opt-in', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('app.tone.tone_player/library');
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
    const channel = MethodChannel('app.tone.tone_player/library');
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
    await tester.tap(find.text('First line').first);
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
    const channel = MethodChannel('app.tone.tone_player/library');
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
    await tester.tap(find.text('First word').first);
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
    const channel = MethodChannel('app.tone.tone_player/library');
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
    expect(find.text('FLAC · 96 kHz · Stereo · 3000 kbps'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Now Playing exposes DJ mode and complete tagged track details', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('app.tone.tone_player/library');
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
    await tester.tap(find.text('Turn DJ mode off'));
    await tester.pumpAndSettle();
    expect(handler.actions, contains('dj:off'));

    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    expect(find.text('Turn DJ mode on'), findsOneWidget);
    await tester.tap(find.text('Turn DJ mode on'));
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
    expect(find.text('FLAC · 96 kHz · Stereo · 3000 kbps'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deck nudge responds to artwork drags and resets on release', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('app.tone.tone_player/library');
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
      handler.actions.any(
        (action) => action.startsWith('scratch:') && action != 'scratch:1.0',
      ),
      isTrue,
    );
    expect(handler.actions, contains('scratch:1.0'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('now playing fits compact phone layouts without overflow', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('app.tone.tone_player/library');
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

  testWidgets('home opens a local music mix setup', (tester) async {
    await tester.pumpWidget(const ToneApp.preview());

    expect(find.text('A little space for your sound.'), findsOneWidget);
    await tester.tap(find.text('Build your mix'));
    await tester.pumpAndSettle();

    expect(find.text('Make a mix from your music'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -450));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Music services are not available in this preview'),
      findsOneWidget,
    );
  });

  testWidgets('Home plays a selected mood mix from tagged local songs', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('app.tone.tone_player/library');
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
        DeviceAudio(
          uri: 'content://media/external/audio/media/802',
          name: 'electronic.mp3',
          title: 'Fast Lane',
          artist: 'Tone Test',
          genre: 'Electronic',
          bpm: 150,
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
            onBuildMix: () {},
            onOpenLibrary: () {},
            library: library,
            audioHandler: handler,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Morning glow'));
    await tester.pumpAndSettle();

    expect(find.text('Set the scene'), findsOneWidget);
    await tester.tap(find.text('Morning glow'));
    await tester.pumpAndSettle();

    expect(handler.queue.value.map((item) => item.title), ['Warm Start']);
    expect(handler.actions, contains('play'));
    expect(
      find.text('Playing Morning glow from your library tags.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home makes the current song a playable artwork-led hero', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('app.tone.tone_player/library');
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
          body: HomeScreen(
            onBuildMix: () {},
            onOpenLibrary: () {},
            audioHandler: handler,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PICK UP THE VIBE'), findsOneWidget);
    expect(find.text('Afterglow'), findsOneWidget);
    await tester.tap(find.byTooltip('Play'));
    await tester.pump();
    expect(handler.actions, contains('play'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('home starts local artist radio and saves playlist sparks', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('app.tone.tone_player/library');
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
            onBuildMix: () {},
            onOpenLibrary: () {},
            library: library,
            audioHandler: handler,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('A spark from your library'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final radioTooltip = find.byTooltip(
      'Play Artist A radio · 3 songs from your library',
    );
    expect(radioTooltip, findsOneWidget);
    expect(find.text('Electronic flow'), findsOneWidget);

    await tester.tap(radioTooltip);
    await tester.pumpAndSettle();
    expect(handler.queue.value, hasLength(3));
    expect(handler.actions, contains('play'));

    await tester.tap(find.byTooltip('Save playlist').first);
    await tester.pumpAndSettle();
    expect(library.playlists, hasLength(1));
    expect(library.playlists.single.name, 'Artist A on repeat');
    expect(
      library.tracksForPlaylist(library.playlists.single.id),
      hasLength(3),
    );

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
    await tester.pumpWidget(const ToneApp.preview());
    await tester.tap(find.byIcon(Icons.library_music_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Your library'), findsOneWidget);
    expect(find.text('Your library starts with you.'), findsOneWidget);
    expect(find.text('Scan device'), findsOneWidget);
    expect(find.text('Import files'), findsOneWidget);

    await tester.tap(find.text('Import files'));
    await tester.pump();
    expect(
      find.text('Music import is planned for an upcoming build.'),
      findsOneWidget,
    );
  });

  testWidgets('search and personal settings destinations are reachable', (
    tester,
  ) async {
    await tester.pumpWidget(const ToneApp.preview());

    await tester.tap(find.text('Search songs, artists, albums'));
    await tester.pumpAndSettle();
    expect(find.text('Find your next favorite.'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Personal sources'), findsNothing);

    await tester.tap(find.byIcon(Icons.local_fire_department_outlined));
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
      find.text('Personal DJ'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Personal DJ'));
    await tester.pumpAndSettle();
    expect(find.text('Make a mix from your music'), findsOneWidget);

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

  testWidgets('DJ mix settings control the active playback transition', (
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
          ),
        ),
      ),
    );

    await tester.tap(find.text('Sound & playback'));
    await tester.pumpAndSettle();
    expect(find.text('Let the songs flow.'), findsOneWidget);
    expect(find.text('Beat-matched DJ blend'), findsOneWidget);

    await tester.tap(find.text('Smooth blend'));
    await tester.pumpAndSettle();
    expect(handler.djMixMode, DjMixMode.smooth.name);
    expect(tester.takeException(), isNull);
  });
}

class _PreviewAudioHandler extends BaseAudioHandler with QueueHandler {
  final List<String> actions = [];
  String djMixMode = DjMixMode.beatMatched.name;

  @override
  Future<dynamic> customAction(
    String name, [
    Map<String, dynamic>? extras,
  ]) async {
    if (name == 'getDjMixMode') return djMixMode;
    if (name == 'setDjMixMode') {
      djMixMode = extras!['mode']! as String;
      actions.add('dj:$djMixMode');
    }
    if (name == 'scratchDeck') {
      actions.add('scratch:${extras!['speed']}');
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
