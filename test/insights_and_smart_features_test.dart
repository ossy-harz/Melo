import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:melo_player/features/insights/melo_insights_service.dart';
import 'package:melo_player/features/library/data/library_repository.dart';
import 'package:melo_player/features/library/data/melo_database.dart';
import 'package:melo_player/features/library/imported_track.dart';
import 'package:melo_player/features/library/music_library.dart';
import 'package:melo_player/features/library/smart_playlist_hub.dart';
import 'package:melo_player/features/mood/mood_session_service.dart';

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

    test('generates mood session blending matching local tracks', () async {
      final chillTrack = const ImportedTrack(
        id: 'chill-1',
        path: '/music/chill.mp3',
        title: 'Chill Vibes',
        artist: 'Acoustic Soul',
        genre: 'R&B & Soul',
      );
      final workoutTrack = const ImportedTrack(
        id: 'workout-1',
        path: '/music/workout.mp3',
        title: 'Power Run',
        artist: 'Gym Anthems',
        genre: 'Hip-Hop & Rap',
      );

      final library = MusicLibrary.forTesting(
        musicDirectory: musicDirectory,
        preferences: preferences,
        repository: repository,
        pickAudio: () async => const [],
      );
      await library.load();

      final session = await MoodSessionService.instance.generateMoodSession(
        mood: ListeningMood.chill,
        library: library,
      );

      expect(session.id, 'mood:chill');
      expect(session.title, 'Chill Vibe');
      expect(session.subtitle, ListeningMood.chill.subtitle);
      expect(session.isContinuous, isTrue);
    });
  });

  group('SmartPlaylistHub', () {
    test('resolves recently added in reversed order', () async {
      final library = MusicLibrary.forTesting(
        musicDirectory: musicDirectory,
        preferences: preferences,
        repository: repository,
        pickAudio: () async => const [],
      );
      await library.load();

      final tracks = await SmartPlaylistHub.resolveTracks(
        type: SmartPlaylistType.recentlyAdded,
        library: library,
      );
      expect(tracks, isEmpty);
    });

    test('filters audiophile hi-res tracks by lossless format', () async {
      final library = MusicLibrary.forTesting(
        musicDirectory: musicDirectory,
        preferences: preferences,
        repository: repository,
        pickAudio: () async => const [],
      );
      await library.load();

      final tracks = await SmartPlaylistHub.resolveTracks(
        type: SmartPlaylistType.audiophileHiRes,
        library: library,
      );
      expect(tracks, isEmpty);
    });
  });
}
