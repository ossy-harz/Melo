import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:melo_player/features/player/mini_player.dart';

void main() {
  testWidgets('track details expose embedded tags and source audio quality', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    const channel = MethodChannel('app.melo.melo_player/library');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'readLocalAudioMetadata' => {
              'albumArtist': 'Tone Ensemble',
              'discNumber': 2,
              'trackCount': 11,
              'composer': 'A. Composer',
            },
            'readAudioQuality' => {
              'mimeType': 'audio/flac',
              'bitRate': 960000,
              'sampleRate': 96000,
              'channelCount': 2,
            },
            'readAudioWaveform' => List<double>.filled(64, 0.4),
            _ => null,
          };
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    const item = MediaItem(
      id: '/music/Blue%20Hour.flac',
      title: 'Blue Hour',
      artist: 'Tone Ensemble',
      album: 'Afterlight',
      duration: Duration(minutes: 4, seconds: 12),
      extras: {
        'genre': 'Ambient',
        'year': 2024,
        'trackNumber': 5,
        'bpm': 96,
        'fileSizeBytes': 10485760,
        'dateModifiedAt': '2025-03-04T10:30:00.000',
        'source': 'local',
      },
    );
    final handler = _TrackDetailsAudioHandler()
      ..queue.add(const [item])
      ..mediaItem.add(item)
      ..playbackState.add(
        PlaybackState(
          processingState: AudioProcessingState.ready,
          playing: false,
          queueIndex: 0,
        ),
      );

    tester.view.physicalSize = const Size(432, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: NowPlayingScreen(audioHandler: handler)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Track details'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('10.0 MB'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('File size'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Album artist'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.text('Album artist'), findsOneWidget);
    expect(find.text('Tone Ensemble'), findsAtLeastNWidgets(1));
    expect(find.text('Disc'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Track count'), findsOneWidget);
    expect(find.text('A. Composer'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('960 kbps'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.text('96 kHz'), findsOneWidget);
    expect(find.text('Stereo'), findsOneWidget);
    expect(find.text('960 kbps'), findsOneWidget);
    expect(
      calls.map((call) => call.method),
      contains('readLocalAudioMetadata'),
    );
    expect(tester.takeException(), isNull);
  });
}

class _TrackDetailsAudioHandler extends BaseAudioHandler with QueueHandler {
  @override
  Future<dynamic> customAction(
    String name, [
    Map<String, dynamic>? extras,
  ]) async {
    return null;
  }
}
