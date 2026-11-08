import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tone_player/features/library/library_platform_data_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'maps Android folder operations through the platform interface',
    () async {
      const channel = MethodChannel('tone.test/library-platform');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return switch (call.method) {
              'pickMusicFolder' => {
                'uri': 'content://tree/music',
                'name': 'Music',
              },
              'scanMusicFolder' => [
                {
                  'uri': 'content://music/track/1',
                  'name': 'song.mp3',
                  'title': 'Song',
                  'artist': 'Tone Test',
                  'album': 'First',
                  'durationMs': 123000,
                  'bpm': 120,
                  'sizeBytes': 4096,
                  'dateModifiedSeconds': 1700000000,
                },
              ],
              'releaseMusicFolder' => null,
              'deleteDeviceAudio' => false,
              'androidSdkVersion' => 35,
              'deleteDeviceAudioBatch' => true,
              _ => throw MissingPluginException('Unexpected ${call.method}'),
            };
          });
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      final source = MethodChannelLibraryPlatformDataSource(channel: channel);
      final folder = await source.pickMusicFolder();
      final tracks = await source.scanMusicFolder(folder!.uri);
      await source.releaseMusicFolder(folder.uri);
      final deleted = await source.deleteDeviceAudio('content://media/audio/1');
      final batchDeleted = await source.deleteDeviceAudioBatch([
        'content://media/audio/2',
        'content://media/audio/3',
      ]);

      expect(folder.name, 'Music');
      expect(tracks, hasLength(1));
      expect(tracks.single.title, 'Song');
      expect(tracks.single.durationMs, 123000);
      expect(tracks.single.bpm, 120);
      expect(tracks.single.sizeBytes, 4096);
      expect(tracks.single.dateModifiedSeconds, 1700000000);
      expect(deleted, isFalse);
      expect(batchDeleted, isTrue);
      expect(calls.map((call) => call.method), [
        'pickMusicFolder',
        'scanMusicFolder',
        'releaseMusicFolder',
        'deleteDeviceAudio',
        'androidSdkVersion',
        'deleteDeviceAudioBatch',
      ]);
      expect(calls[1].arguments, {'uri': 'content://tree/music'});
      expect(calls[3].arguments, {'uri': 'content://media/audio/1'});
      expect(calls[5].arguments, {
        'uris': ['content://media/audio/2', 'content://media/audio/3'],
      });
    },
  );

  test('rejects malformed Android folder data', () async {
    const channel = MethodChannel('tone.test/library-platform-invalid');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => {'name': 'Music'});
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final source = MethodChannelLibraryPlatformDataSource(channel: channel);

    await expectLater(source.pickMusicFolder(), throwsFormatException);
  });

  test('rejects Android-only operations on other platforms', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final source = MethodChannelLibraryPlatformDataSource();

    await expectLater(source.pickMusicFolder(), throwsUnsupportedError);
    await expectLater(
      source.deleteDeviceAudio('content://media/audio/1'),
      throwsUnsupportedError,
    );
    await expectLater(
      source.deleteDeviceAudioBatch(['content://media/audio/1']),
      throwsUnsupportedError,
    );
  });
}
