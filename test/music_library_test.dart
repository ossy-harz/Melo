import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tone_player/features/library/library_screen.dart';
import 'package:tone_player/features/library/music_library.dart';
import 'package:tone_player/features/player/mini_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory musicDirectory;
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    musicDirectory = await Directory.systemTemp.createTemp('tone-library-');
  });

  tearDown(() async {
    if (await musicDirectory.exists()) {
      await musicDirectory.delete(recursive: true);
    }
  });

  test(
    'imports audio by streaming bytes and restores the private copy',
    () async {
      final original = [1, 2, 3, 4, 5, 6];
      final library = MusicLibrary.forTesting(
        musicDirectory: musicDirectory,
        preferences: preferences,
        pickAudio: () async => [
          PickedAudio(
            name: 'Evening Walk.mp3',
            bytes: Stream.fromIterable([
              original.sublist(0, 3),
              original.sublist(3),
            ]),
          ),
        ],
      );

      expect(await library.pickAndImport(), 1);
      expect(library.tracks.single.title, 'Evening Walk');
      expect(library.tracks.single.path, isNot('Evening Walk.mp3'));
      expect(await File(library.tracks.single.path).readAsBytes(), original);

      final restored = MusicLibrary.forTesting(
        musicDirectory: musicDirectory,
        preferences: preferences,
        pickAudio: () async => const [],
      );
      await restored.load();
      expect(restored.tracks.single.id, library.tracks.single.id);

      await restored.removeTrack(restored.tracks.single);
      expect(await File(library.tracks.single.path).exists(), isFalse);
      expect(restored.tracks, isEmpty);
    },
  );

  test(
    'refreshes and persists metadata for previously imported tracks',
    () async {
      final legacyLibrary = MusicLibrary.forTesting(
        musicDirectory: musicDirectory,
        preferences: preferences,
        pickAudio: () async => [
          PickedAudio(name: 'Evening Walk.mp3', bytes: Stream.value([1, 2, 3])),
        ],
      );
      await legacyLibrary.pickAndImport();
      expect(legacyLibrary.tracks.single.metadataReviewed, isFalse);

      var metadataReads = 0;
      final refreshedLibrary = MusicLibrary.forTesting(
        musicDirectory: musicDirectory,
        preferences: preferences,
        pickAudio: () async => const [],
        isAndroid: () => true,
        readImportedMetadata: (path, fallbackTitle) async {
          metadataReads++;
          expect(path, legacyLibrary.tracks.single.path);
          expect(fallbackTitle, 'Evening Walk');
          return {
            'title': 'Evening Walk (Remastered)',
            'artist': 'Tone Test',
            'album': 'Night Drive',
            'durationMs': 205000,
            'artworkUri': 'file:///covers/night-drive.jpg',
            'year': 2024,
            'trackNumber': 2,
            'genre': 'Electronic',
            'bpm': 128.5,
          };
        },
      );
      await refreshedLibrary.load();
      var notifications = 0;
      refreshedLibrary.addListener(() => notifications++);

      await refreshedLibrary.refreshImportedMetadata();

      final enriched = refreshedLibrary.tracks.single;
      expect(enriched.title, 'Evening Walk (Remastered)');
      expect(enriched.artist, 'Tone Test');
      expect(enriched.album, 'Night Drive');
      expect(enriched.durationMs, 205000);
      expect(enriched.artworkUri, 'file:///covers/night-drive.jpg');
      expect(enriched.year, 2024);
      expect(enriched.trackNumber, 2);
      expect(enriched.genre, 'Electronic');
      expect(enriched.bpm, 128.5);
      expect(enriched.metadataReviewed, isTrue);
      expect(notifications, 1);

      final restored = MusicLibrary.forTesting(
        musicDirectory: musicDirectory,
        preferences: preferences,
        pickAudio: () async => const [],
      );
      await restored.load();
      expect(restored.tracks.single.title, enriched.title);
      expect(restored.tracks.single.artworkUri, enriched.artworkUri);
      expect(restored.tracks.single.genre, 'Electronic');
      expect(restored.tracks.single.bpm, 128.5);
      expect(restored.tracks.single.metadataReviewed, isTrue);

      await refreshedLibrary.refreshImportedMetadata();
      expect(metadataReads, 1);
    },
  );

  test('removes partial copy and reports a failed import', () async {
    final library = MusicLibrary.forTesting(
      musicDirectory: musicDirectory,
      preferences: preferences,
      pickAudio: () async => [
        PickedAudio(
          name: 'broken.flac',
          bytes: Stream<List<int>>.error(StateError('read failed')),
        ),
      ],
    );

    await expectLater(library.pickAndImport(), throwsA(isA<StateError>()));
    expect(library.tracks, isEmpty);
    expect(await musicDirectory.list().toList(), isEmpty);
  });

  test('ignores files outside the supported audio list', () async {
    final library = MusicLibrary.forTesting(
      musicDirectory: musicDirectory,
      preferences: preferences,
      pickAudio: () async => [
        PickedAudio(name: 'notes.txt', bytes: Stream.value([1, 2])),
      ],
    );

    expect(await library.pickAndImport(), 0);
    expect(library.tracks, isEmpty);
    expect(await musicDirectory.list().toList(), isEmpty);
  });

  test(
    'scans all supported device audio without copying or deleting originals',
    () async {
      final original = File('${musicDirectory.path}\\device-song.mp3');
      await original.writeAsBytes([1, 2, 3]);
      final library = MusicLibrary.forTesting(
        musicDirectory: musicDirectory,
        preferences: preferences,
        pickAudio: () async => const [],
        scanDeviceAudio: () async => const [
          DeviceAudio(
            uri: 'content://media/external/audio/media/42',
            name: 'device-song.mp3',
            title: 'Device Song',
            artist: 'Tone Test',
            album: 'Evening Album',
            durationMs: 180000,
            artworkUri: 'content://media/external/audio/albumart/12',
            year: 2024,
            trackNumber: 3,
            genre: 'Electronic',
            bpm: 128,
          ),
          DeviceAudio(
            uri: 'content://media/external/audio/media/43',
            name: 'notes.txt',
            title: 'Not Music',
            artist: 'Unknown artist',
          ),
        ],
      );

      expect(await library.scanDeviceMusic(), 1);
      expect(library.tracks.single.title, 'Device Song');
      expect(library.tracks.single.isDeviceMedia, isTrue);
      expect(library.tracks.single.toMediaItem().id, startsWith('content://'));
      expect(library.tracks.single.toMediaItem().album, 'Evening Album');
      expect(library.tracks.single.genre, 'Electronic');
      expect(library.tracks.single.bpm, 128);
      expect(
        library.tracks.single.toMediaItem().artUri.toString(),
        'content://media/external/audio/albumart/12',
      );
      expect(
        library.tracks.single.toMediaItem().duration,
        const Duration(minutes: 3),
      );
      await library.removeTrack(library.tracks.single);
      expect(await original.exists(), isTrue);
    },
  );

  test('rescan refreshes device music but preserves imported files', () async {
    final imported = MusicLibrary.forTesting(
      musicDirectory: musicDirectory,
      preferences: preferences,
      pickAudio: () async => [
        PickedAudio(name: 'imported.wav', bytes: Stream.value([1, 2, 3])),
      ],
    );
    await imported.pickAndImport();
    final scanner = MusicLibrary.forTesting(
      musicDirectory: musicDirectory,
      preferences: preferences,
      pickAudio: () async => const [],
      scanDeviceAudio: () async => const [
        DeviceAudio(
          uri: 'content://media/external/audio/media/51',
          name: 'new-track.flac',
          title: 'New Track',
          artist: 'Tone Test',
        ),
      ],
    );
    await scanner.load();

    expect(await scanner.scanDeviceMusic(), 1);
    expect(scanner.tracks.map((track) => track.title), [
      'imported',
      'New Track',
    ]);
  });

  test(
    'folder access persists and removes only tracks from that folder',
    () async {
      var releasedUri = '';
      final folder = const MusicFolder(
        uri: 'content://com.android.externalstorage.documents/tree/primary%3AMusic',
        name: 'Music',
      );
      final library = MusicLibrary.forTesting(
        musicDirectory: musicDirectory,
        preferences: preferences,
        pickAudio: () async => const [],
        pickMusicFolder: () async => folder,
        scanMusicFolder: (uri) async => [
          DeviceAudio(
            uri: '$uri/document/primary%3AMusic%2Ffolder-song.mp3',
            name: 'folder-song.mp3',
            title: 'Folder Song',
            artist: 'Unknown artist',
            sourceFolderUri: uri,
            lyricsUri: '$uri/document/primary%3AMusic%2Ffolder-song.lrc',
          ),
        ],
        releaseMusicFolder: (uri) async => releasedUri = uri,
      );

      expect(await library.addMusicFolder(), 1);
      expect(library.musicFolders.single.name, 'Music');
      expect(library.tracks.single.sourceFolderUri, folder.uri);
      expect(
        library.tracks.single.toMediaItem().extras?['lyricsUri'],
        '${folder.uri}/document/primary%3AMusic%2Ffolder-song.lrc',
      );
      final trackId = library.tracks.single.id;
      await library.toggleFavorite(trackId);
      final playlist = await library.createPlaylist('Folder songs');
      await library.addTracksToPlaylist(playlist.id, [trackId]);

      final restored = MusicLibrary.forTesting(
        musicDirectory: musicDirectory,
        preferences: preferences,
        pickAudio: () async => const [],
      );
      await restored.load();
      expect(restored.musicFolders.single.uri, folder.uri);
      expect(restored.tracks.single.title, 'Folder Song');

      await library.removeMusicFolder(folder);
      expect(releasedUri, folder.uri);
      expect(library.musicFolders, isEmpty);
      expect(library.tracks, isEmpty);
      expect(library.favoriteTracks, isEmpty);
      expect(library.isFavorite(trackId), isFalse);
      expect(library.tracksForPlaylist(playlist.id), isEmpty);
    },
  );

  test('favorites persist and can be toggled off', () async {
    final library = MusicLibrary.forTesting(
      musicDirectory: musicDirectory,
      preferences: preferences,
      pickAudio: () async => [
        PickedAudio(name: 'Favorite Song.mp3', bytes: Stream.value([1, 2, 3])),
      ],
    );
    await library.pickAndImport();
    final trackId = library.tracks.single.id;

    expect(await library.toggleFavorite(trackId), isTrue);
    expect(library.favoriteTracks.single.id, trackId);

    final restored = MusicLibrary.forTesting(
      musicDirectory: musicDirectory,
      preferences: preferences,
      pickAudio: () async => const [],
    );
    await restored.load();
    expect(restored.isFavorite(trackId), isTrue);
    expect(await restored.toggleFavorite(trackId), isFalse);
    expect(restored.favoriteTracks, isEmpty);
  });

  test('mix exclusions persist and are respected by generated mixes', () async {
    final library = MusicLibrary.forTesting(
      musicDirectory: musicDirectory,
      preferences: preferences,
      pickAudio: () async => [
        PickedAudio(name: 'Keep.mp3', bytes: Stream.value([1])),
        PickedAudio(name: 'Avoid.mp3', bytes: Stream.value([2])),
      ],
      readImportedMetadata: (path, title) async => {
        'durationMs': 5 * 60 * 1000,
      },
    );
    await library.pickAndImport();
    final excludedId = library.tracks.last.id;

    await library.setMixExcluded(excludedId, true);

    final restored = MusicLibrary.forTesting(
      musicDirectory: musicDirectory,
      preferences: preferences,
      pickAudio: () async => const [],
    );
    await restored.load();

    expect(restored.isExcludedFromMixes(excludedId), isTrue);
    final mix = restored.generatePersonalMix(
      targetDuration: const Duration(minutes: 30),
      discovery: 1,
      randomSeed: 1,
    );
    expect(mix.map((pick) => pick.track.id), [restored.tracks.first.id]);

    await restored.resetMixExclusions();
    expect(restored.isExcludedFromMixes(excludedId), isFalse);
  });

  test(
    'clears local taste preferences without removing library tracks',
    () async {
      final library = MusicLibrary.forTesting(
        musicDirectory: musicDirectory,
        preferences: preferences,
        pickAudio: () async => [
          PickedAudio(name: 'Saved.mp3', bytes: Stream.value([1])),
        ],
        readImportedMetadata: (path, title) async => {
          'durationMs': 5 * 60 * 1000,
        },
      );
      await library.pickAndImport();
      final trackId = library.tracks.single.id;
      await library.toggleFavorite(trackId);
      await library.setMixExcluded(trackId, true);

      await library.clearPersonalPreferences();

      expect(library.tracks, hasLength(1));
      expect(library.isFavorite(trackId), isFalse);
      expect(library.isExcludedFromMixes(trackId), isFalse);
    },
  );

  test(
    'playlists persist, reorder, reject duplicates, and update membership',
    () async {
      final library = MusicLibrary.forTesting(
        musicDirectory: musicDirectory,
        preferences: preferences,
        pickAudio: () async => [
          PickedAudio(name: 'First.mp3', bytes: Stream.value([1])),
          PickedAudio(name: 'Second.mp3', bytes: Stream.value([2])),
        ],
      );
      await library.pickAndImport();
      final firstId = library.tracks[0].id;
      final secondId = library.tracks[1].id;
      final playlist = await library.createPlaylist('Road trip');

      await expectLater(
        library.createPlaylist(' road TRIP '),
        throwsA(isA<StateError>()),
      );
      await library.addTracksToPlaylist(playlist.id, [
        firstId,
        secondId,
        firstId,
      ]);
      expect(library.tracksForPlaylist(playlist.id).map((track) => track.id), [
        firstId,
        secondId,
      ]);
      await library.reorderPlaylistTrack(playlist.id, 0, 1);
      expect(library.tracksForPlaylist(playlist.id).map((track) => track.id), [
        secondId,
        firstId,
      ]);
      await library.renamePlaylist(playlist.id, 'Long drive');
      await library.removeTrackFromPlaylist(playlist.id, firstId);

      final restored = MusicLibrary.forTesting(
        musicDirectory: musicDirectory,
        preferences: preferences,
        pickAudio: () async => const [],
      );
      await restored.load();
      expect(restored.playlists.single.name, 'Long drive');
      expect(restored.tracksForPlaylist(playlist.id).map((track) => track.id), [
        secondId,
      ]);

      await restored.deletePlaylist(playlist.id);
      expect(restored.playlists, isEmpty);
      expect(restored.tracks, hasLength(2));
    },
  );

  test(
    'search matches track titles, artists, and albums without case sensitivity',
    () async {
      final library = MusicLibrary.forTesting(
        musicDirectory: musicDirectory,
        preferences: preferences,
        pickAudio: () async => [
          PickedAudio(name: 'Blue Hour.mp3', bytes: Stream.value([1])),
          PickedAudio(name: 'Quiet Road.mp3', bytes: Stream.value([2])),
        ],
        scanDeviceAudio: () async => const [
          DeviceAudio(
            uri: 'content://media/external/audio/media/72',
            name: 'live-set.mp3',
            title: 'Live Set',
            artist: 'Blue Artist',
          ),
        ],
      );
      await library.pickAndImport();
      await library.scanDeviceMusic();

      expect(library.searchTracks('BLUE').map((track) => track.title), [
        'Blue Hour',
        'Live Set',
      ]);
      expect(library.searchTracks('quiet').map((track) => track.title), [
        'Quiet Road',
      ]);
      expect(library.searchTracks('not found'), isEmpty);
      expect(library.searchTracks(''), hasLength(3));
    },
  );

  testWidgets('large libraries build song rows lazily', (tester) async {
    final library = MusicLibrary.forTesting(
      musicDirectory: musicDirectory,
      preferences: preferences,
      pickAudio: () async => const [],
      scanDeviceAudio: () async => List.generate(
        1000,
        (index) => DeviceAudio(
          uri: 'content://media/external/audio/media/$index',
          name: 'song-$index.mp3',
          title: 'Song $index',
          artist: 'Artist ${index % 10}',
          album: 'Album ${index % 25}',
        ),
      ),
    );
    await library.scanDeviceMusic();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LibraryScreen(onUnavailable: (_) {}, library: library),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(ListTile).evaluate().length, lessThanOrEqualTo(25));
    expect(find.text('Song 999'), findsNothing);
    await tester.tap(find.text('Albums'));
    await tester.pumpAndSettle();
    expect(find.text('Album 0'), findsWidgets);
    expect(find.byType(AlbumArtwork), findsWidgets);
    await tester.tap(find.text('Album 0').first);
    await tester.pumpAndSettle();
    expect(find.text('Song 0'), findsOneWidget);
    expect(find.textContaining('Album ·'), findsOneWidget);
    expect(find.text('Shuffle'), findsOneWidget);
    expect(find.text('Your library'), findsNothing);

    await tester.tap(find.byTooltip('Back to albums'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Artists'));
    await tester.pumpAndSettle();
    expect(find.text('Artist 0'), findsOneWidget);
  });

  testWidgets('library creates and opens a playlist', (tester) async {
    final library = MusicLibrary.forTesting(
      musicDirectory: musicDirectory,
      preferences: preferences,
      pickAudio: () async => const [],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LibraryScreen(onUnavailable: (_) {}, library: library),
        ),
      ),
    );
    await tester.tap(find.text('Playlists'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create playlist'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Quiet mornings');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Quiet mornings'), findsOneWidget);
    expect(find.text('Add songs'), findsOneWidget);
    expect(
      find.text('This playlist is ready for its first song.'),
      findsOneWidget,
    );
  });

  testWidgets('album play builds an ordered album-only playback queue', (
    tester,
  ) async {
    final library = MusicLibrary.forTesting(
      musicDirectory: musicDirectory,
      preferences: preferences,
      pickAudio: () async => const [],
      scanDeviceAudio: () async => const [
        DeviceAudio(
          uri: 'content://media/1',
          name: 'last.mp3',
          title: 'Last Light',
          artist: 'Tone Test',
          album: 'Evening Colors',
          trackNumber: 3,
          year: 2022,
          durationMs: 180000,
        ),
        DeviceAudio(
          uri: 'content://media/2',
          name: 'first.mp3',
          title: 'First Light',
          artist: 'Tone Test',
          album: 'Evening Colors',
          trackNumber: 1,
          year: 2022,
          durationMs: 180000,
        ),
        DeviceAudio(
          uri: 'content://media/3',
          name: 'other.mp3',
          title: 'Different Album',
          artist: 'Tone Test',
          album: 'Other Album',
          trackNumber: 1,
          year: 2021,
          durationMs: 180000,
        ),
      ],
    );
    await library.scanDeviceMusic();
    final handler = _LibraryTestAudioHandler();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LibraryScreen(
            onUnavailable: (feature) => fail('$feature is unavailable'),
            library: library,
            audioHandler: handler,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Albums'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Evening Colors').first);
    await tester.pumpAndSettle();
    expect(find.text('Album · 2 songs · 2022'), findsOneWidget);
    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();

    expect(handler.queue.value.map((item) => item.title), [
      'First Light',
      'Last Light',
    ]);
    expect(handler.actions, contains('play'));
    expect(
      handler.queue.value.map((item) => item.album),
      isNot(contains('Other Album')),
    );
    expect(tester.takeException(), isNull);
  });
}

class _LibraryTestAudioHandler extends BaseAudioHandler with QueueHandler {
  final List<String> actions = [];

  @override
  Future<void> play() async {
    actions.add('play');
    final current = queue.value.isEmpty ? null : queue.value.first;
    if (current != null) mediaItem.add(current);
  }
}
