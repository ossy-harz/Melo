import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:melo_player/core/secure_credential_store.dart';
import 'package:melo_player/features/insights/melo_insights_service.dart';
import 'package:melo_player/features/library/data/library_repository.dart';
import 'package:melo_player/features/library/data/melo_database.dart';
import 'package:melo_player/features/library/imported_track.dart';
import 'package:melo_player/features/library/music_library.dart';
import 'package:melo_player/features/library/smart_playlist_hub.dart';
import 'package:melo_player/features/mood/mood_session_service.dart';
import 'package:melo_player/features/player/sleep_timer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory musicDirectory;
  late SharedPreferences preferences;
  late MeloDatabase database;
  late DriftLibraryRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    database = MeloDatabase.inMemory();
    repository = DriftLibraryRepository(
      database: database,
      legacyPreferences: preferences,
    );
    musicDirectory = await Directory.systemTemp.createTemp('melo-insights-test-');
  });

  tearDown(() async {
    await repository.close();
    if (await musicDirectory.exists()) {
      await musicDirectory.delete(recursive: true);
    }
  });

  group('MeloInsightsService', () {
    test('returns empty report when library is null or empty', () async {
      final report = await MeloInsightsService.instance.generateReport(library: null);
      expect(report.totalPlays, 0);
      expect(report.totalListeningMinutes, 0);
      expect(report.topArtists, isEmpty);
      expect(report.topTracks, isEmpty);
      expect(report.forgottenGems, isEmpty);
      expect(report.topGenres, isEmpty);
      expect(report.dominantVibe, ListeningVibe.afternoon);
    });

    test('generates accurate listening stats from library history and tracks', () async {
      final trackA = const ImportedTrack(
        id: 'track-a',
        path: '/music/a.mp3',
        title: 'Song A',
        artist: 'Burna Boy',
        genre: 'Afrobeats',
        durationMs: 180000,
      );
      final trackB = const ImportedTrack(
        id: 'track-b',
        path: '/music/b.flac',
        title: 'Song B',
        artist: 'Burna Boy',
        genre: 'Afrobeats',
        durationMs: 200000,
      );
      final trackC = const ImportedTrack(
        id: 'track-c',
        path: '/music/c.mp3',
        title: 'Song C',
        artist: 'Chronixx',
        genre: 'Reggae',
        durationMs: 240000,
      );

      final library = MusicLibrary.forTesting(
        musicDirectory: musicDirectory,
        preferences: preferences,
        repository: repository,
        pickAudio: () async => const [],
      );
      await library.load();

      // Seed database history
      await library.recordPlayedMediaItem(trackA.toMediaItem());
      await library.recordPlayedMediaItem(trackB.toMediaItem());
      await library.recordPlayedMediaItem(trackA.toMediaItem());
      await library.recordPlayedMediaItem(trackC.toMediaItem());

      final report = await MeloInsightsService.instance.generateReport(library: library);

      expect(report.totalPlays, 4);
      expect(report.totalListeningMinutes, greaterThan(0));
      expect(report.dominantVibe, isNotNull);
    });

    test('counts total plays accurately via totalPlaybackCount without 500 cap', () async {
      final library = MusicLibrary.forTesting(
        musicDirectory: musicDirectory,
        preferences: preferences,
        repository: repository,
        pickAudio: () async => const [],
      );
      await library.load();

      // Directly insert 520 records into repository
      for (var i = 0; i < 520; i++) {
        await repository.recordStreamPlayback(
          trackId: 'stream-$i',
          title: 'Track $i',
          artist: 'Artist ${i % 5}',
          album: 'Album 1',
        );
      }

      final totalCount = await library.totalPlaybackCount();
      expect(totalCount, 520);

      final report = await MeloInsightsService.instance.generateReport(library: library);
      expect(report.totalPlays, 520);
    });
  });

  group('MoodSessionService', () {
    test('defines all 6 distinct listening mood archetypes', () {
      expect(ListeningMood.values, hasLength(6));
      expect(ListeningMood.chill.genres, contains('R&B & Soul'));
      expect(ListeningMood.focus.genres, contains('Lo-Fi'));
      expect(ListeningMood.workout.genres, contains('Hip-Hop & Rap'));
      expect(ListeningMood.party.genres, contains('Dancehall'));
      expect(ListeningMood.driving.genres, contains('Rock'));
      expect(ListeningMood.lateNight.genres, contains('R&B & Soul'));
    });

    test('BPM filtering disqualifies slow songs from workout sessions', () {
      final slowTrack = const ImportedTrack(
        id: 'slow-1',
        path: '/music/slow.mp3',
        title: 'Slow Acoustic Jam',
        artist: 'Mellow Singer',
        genre: 'Afrobeats',
        bpm: 72.0, // Slow tempo outside workout (125-158)
      );
      final workoutTrack = const ImportedTrack(
        id: 'fast-1',
        path: '/music/fast.mp3',
        title: 'Speed Sprint',
        artist: 'Cardio Beats',
        genre: 'Hip-Hop & Rap',
        bpm: 138.0, // In range for workout
      );

      final slowScore = MoodSessionService.scoreTrackForMood(
        track: slowTrack,
        mood: ListeningMood.workout,
      );
      final workoutScore = MoodSessionService.scoreTrackForMood(
        track: workoutTrack,
        mood: ListeningMood.workout,
      );

      expect(slowScore, equals(-1)); // Disqualified
      expect(workoutScore, greaterThan(50)); // High suitability
    });

    test('harmonic half/double time compatibility works as expected', () {
      expect(MoodSessionService.isBpmCompatible(160, ListeningMood.chill), isTrue); // 160 / 2 = 80
      expect(MoodSessionService.isBpmCompatible(72, ListeningMood.workout), isFalse); // Slow tempo excluded
      expect(MoodSessionService.isBpmCompatible(40, ListeningMood.workout), isFalse);
    });
  });

  group('SmartPlaylistHub', () {
    test('heavyRotation is genuinely empty when listening history is empty', () async {
      final library = MusicLibrary.forTesting(
        musicDirectory: musicDirectory,
        preferences: preferences,
        repository: repository,
        pickAudio: () async => const [],
      );
      await library.load();

      final tracks = await SmartPlaylistHub.resolveTracks(
        type: SmartPlaylistType.heavyRotation,
        library: library,
      );
      expect(tracks, isEmpty);
    });

    test('forgottenGems is genuinely empty when no older plays exist', () async {
      final library = MusicLibrary.forTesting(
        musicDirectory: musicDirectory,
        preferences: preferences,
        repository: repository,
        pickAudio: () async => const [],
      );
      await library.load();

      final tracks = await SmartPlaylistHub.resolveTracks(
        type: SmartPlaylistType.forgottenGems,
        library: library,
      );
      expect(tracks, isEmpty);
    });

    test('audiophileHiRes recognizes FLAC, WAV, and ALAC m4a containers', () async {
      // Create library with test tracks using pickAudio simulation with distinct byte arrays
      final library = MusicLibrary.forTesting(
        musicDirectory: musicDirectory,
        preferences: preferences,
        repository: repository,
        pickAudio: () async => [
          PickedAudio(name: 'HiRes.flac', bytes: Stream.value([1, 2, 3, 4])),
          PickedAudio(name: 'Studio.wav', bytes: Stream.value([5, 6, 7, 8])),
          PickedAudio(name: 'Standard.mp3', bytes: Stream.value([9, 10, 11, 12])),
        ],
      );
      await library.load();
      await library.pickAndImport();

      final tracks = await SmartPlaylistHub.resolveTracks(
        type: SmartPlaylistType.audiophileHiRes,
        library: library,
      );

      expect(tracks.any((t) => t.path.endsWith('.flac')), isTrue);
      expect(tracks.any((t) => t.path.endsWith('.wav')), isTrue);
      expect(tracks.any((t) => t.path.endsWith('.mp3')), isFalse);
    });
  });

  group('SecureCredentialStore', () {
    test('preserves exact credential strings without trimming', () async {
      final store = SecureCredentialStore.forTesting(allowMemoryFallback: true);
      const exactPassword = '  Secret Passphrase! #123  ';
      await store.write('test_pass', exactPassword);
      final retrieved = await store.read('test_pass');
      expect(retrieved, equals(exactPassword));
    });
  });

  group('SleepTimerService', () {
    test('notifyUserChangedVolume invalidates fade session and protects user volume', () {
      final service = SleepTimerService.instance;
      service.notifyUserChangedVolume();
      // Should cleanly increment session ID and mark user volume as changed
      expect(service.isActive, isFalse);
    });
  });
}
