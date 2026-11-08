import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tone_player/features/library/data/library_repository.dart';
import 'package:tone_player/features/library/data/tone_database.dart';
import 'package:tone_player/features/library/imported_track.dart';
import 'package:tone_player/features/library/library_platform_data_source.dart';
import 'package:tone_player/features/library/music_playlist.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences preferences;
  late ToneDatabase database;
  late DriftLibraryRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    database = ToneDatabase.inMemory();
    repository = DriftLibraryRepository(
      database: database,
      legacyPreferences: preferences,
    );
  });

  tearDown(() async {
    await repository.close();
  });

  test('migrates legacy library data atomically and only once', () async {
    final first = _track('track-a', title: 'Blue Hour');
    final second = _track('track-b', title: 'Quiet Streets');
    final playlist = MusicPlaylist(
      id: 'playlist-night',
      name: 'Night drive',
      trackIds: [first.id, second.id],
      createdAt: DateTime.utc(2025, 1, 2),
    );
    await preferences.setString(
      'tone_library_tracks_v1',
      jsonEncode([first.toJson(), second.toJson()]),
    );
    await preferences.setString(
      'tone_library_playlists_v1',
      jsonEncode([playlist.toJson()]),
    );
    await preferences.setString(
      'tone_library_folders_v1',
      jsonEncode([
        const MusicFolder(uri: 'content://music', name: 'Music').toJson(),
      ]),
    );
    await preferences.setStringList('tone_library_favorites_v1', [first.id]);
    await preferences.setStringList('tone_mix_exclusions_v1', [second.id]);
    await preferences.setString(
      'tone_playback_queue_v1',
      jsonEncode([second.id, first.id]),
    );
    await preferences.setString('tone_playback_current_v1', first.id);
    await preferences.setInt('tone_playback_position_ms_v1', 14000);

    await repository.initialize();
    var snapshot = await repository.load();
    expect(snapshot.tracks.map((track) => track.title), [
      'Blue Hour',
      'Quiet Streets',
    ]);
    expect(snapshot.playlists.single.trackIds, [first.id, second.id]);
    expect(snapshot.folders.single.name, 'Music');
    expect(snapshot.favoriteTrackIds, {first.id});
    expect(snapshot.excludedTrackIds, {second.id});
    expect(snapshot.queueTrackIds, [second.id, first.id]);
    expect(snapshot.currentTrackId, first.id);
    expect(snapshot.positionMs, 14000);

    await preferences.setString('tone_library_tracks_v1', '[]');
    await repository.initialize();
    snapshot = await repository.load();
    expect(snapshot.tracks, hasLength(2));
  });

  test('persists normalized library data and playback history', () async {
    await repository.initialize();
    final first = _track(
      'track-a',
      title: 'Blue Hour',
      artist: 'Tone Test',
    ).withMetadata(sourceName: 'Original File.flac');
    final second = _track(
      'track-b',
      title: 'Quiet Streets',
      artist: 'Tone Test',
    );
    await repository.saveTracks([first, second]);
    await repository.savePlaylists([
      MusicPlaylist(
        id: 'playlist-one',
        name: 'Favorites',
        trackIds: [second.id, first.id],
        createdAt: DateTime.utc(2025, 1, 1),
      ),
    ]);
    await repository.saveFolders([
      const MusicFolder(uri: 'content://music', name: 'Music'),
    ]);
    await repository.saveFavorites({first.id});
    await repository.saveExclusions({second.id});
    await repository.saveQueue(
      [second.id, first.id],
      currentTrackId: second.id,
      positionMs: 2000,
    );
    await repository.saveCurrentTrack(first.id);
    await repository.saveCurrentTrack(first.id);
    await repository.saveCurrentTrack(second.id);
    await repository.saveCurrentTrack(first.id);
    await repository.savePlaybackPosition(5400);

    final snapshot = await repository.load();
    expect(snapshot.tracks.map((track) => track.id), [first.id, second.id]);
    expect(snapshot.playlists.single.trackIds, [second.id, first.id]);
    expect(snapshot.favoriteTrackIds, {first.id});
    expect(snapshot.excludedTrackIds, {second.id});
    expect(snapshot.queueTrackIds, [second.id, first.id]);
    expect(snapshot.currentTrackId, first.id);
    expect(snapshot.positionMs, 5400);
    expect(snapshot.tracks.first.sourceName, 'Original File.flac');
    expect((await repository.recentlyPlayed()).map((track) => track.id), [
      first.id,
      second.id,
    ]);
    expect(
      (await repository.listeningHistory()).map((entry) => entry.trackId),
      [first.id, second.id, first.id],
    );
    expect(
      (await repository.mostPlayedTracks()).map(
        (entry) => (entry.track.id, entry.playCount),
      ),
      [(first.id, 2), (second.id, 1)],
    );

    await repository.saveTracks([second]);
    final afterRemoval = await repository.load();
    expect(afterRemoval.tracks.map((track) => track.id), [second.id]);
    expect(afterRemoval.favoriteTrackIds, isEmpty);
    expect(afterRemoval.playlists.single.trackIds, [second.id]);
    expect(
      (await repository.listeningHistory()).map((entry) => entry.title),
      contains(first.title),
    );
  });

  test(
    'uses the full-text index and refreshes it with track changes',
    () async {
      await repository.initialize();
      final blue = _track(
        'track-blue',
        title: 'Blue Hour',
        artist: 'Tone Test',
      );
      final quiet = _track('track-quiet', title: 'Quiet Streets');
      await repository.saveTracks([blue, quiet]);

      expect(
        (await repository.searchTracks('blu test')).map((track) => track.id),
        [blue.id],
      );

      await repository.saveTracks([
        blue.withMetadata(title: 'New Dawn'),
        quiet,
      ]);
      expect(await repository.searchTracks('blue'), isEmpty);
      expect(
        (await repository.searchTracks('new daw')).map((track) => track.id),
        [blue.id],
      );
      expect((await repository.searchTracks('')).map((track) => track.id), [
        blue.id,
        quiet.id,
      ]);
    },
  );

  test('finds likely duplicates without deleting either source', () async {
    await repository.initialize();
    final first = _track('track-a', title: 'Blue Hour', artist: 'Tone Test');
    final second = ImportedTrack(
      id: 'track-b',
      path: 'content://external/track-b',
      title: 'Blue Hour',
      artist: ' tone test ',
      album: 'Different release',
      durationMs: 181500,
      isDeviceMedia: true,
    );
    final differentDuration = ImportedTrack(
      id: 'track-c',
      path: 'content://external/track-c',
      title: 'Blue Hour',
      artist: 'Tone Test',
      durationMs: 190000,
      isDeviceMedia: true,
    );
    await repository.saveTracks([first, second, differentDuration]);

    final groups = await repository.possibleDuplicateGroups();
    expect(groups, hasLength(1));
    expect(groups.single.map((track) => track.id), [first.id, second.id]);
    expect((await repository.load()).tracks, hasLength(3));
  });

  test(
    'persists versioned track analysis and validates summary values',
    () async {
      await repository.initialize();
      final track = _track('analyzed-track', title: 'Blue Hour');
      await repository.saveTracks([track]);
      final analyzedAt = DateTime.utc(2026, 1, 1);
      const analysisJson = '{"version":1,"tempoConfidence":0.8}';

      await repository.saveTrackAnalysis(
        StoredTrackAnalysis(
          trackId: track.id,
          analysisJson: analysisJson,
          analyzedAt: analyzedAt,
          bpm: 120,
          musicalKey: 'C major',
          energy: 0.6,
        ),
      );

      final stored = await repository.trackAnalysisFor(track.id);
      expect(stored?.analysisJson, analysisJson);
      expect(stored?.bpm, 120);
      expect(stored?.musicalKey, 'C major');
      expect(stored?.energy, 0.6);
      expect(stored?.analyzedAt.isAtSameMomentAs(analyzedAt), isTrue);

      await expectLater(
        repository.saveTrackAnalysis(
          StoredTrackAnalysis(
            trackId: track.id,
            analysisJson: analysisJson,
            analyzedAt: analyzedAt,
            bpm: -1,
          ),
        ),
        throwsFormatException,
      );
      await expectLater(
        repository.saveTrackAnalysis(
          StoredTrackAnalysis(
            trackId: track.id,
            analysisJson: '[]',
            analyzedAt: analyzedAt,
          ),
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'loads analyses for a candidate set in one repository request',
    () async {
      await repository.initialize();
      final first = _track('analysis-a', title: 'First');
      final second = _track('analysis-b', title: 'Second');
      await repository.saveTracks([first, second]);
      await repository.saveTrackAnalysis(
        StoredTrackAnalysis(
          trackId: first.id,
          analysisJson: '{"version":1}',
          analyzedAt: DateTime.utc(2026),
          bpm: 120,
        ),
      );

      final analyses = await repository.trackAnalysesFor({
        first.id,
        second.id,
        'missing',
      });

      expect(analyses.keys, {first.id});
      expect(analyses[first.id]?.bpm, 120);
      expect(await repository.trackAnalysesFor({}), isEmpty);
    },
  );

  test(
    'keeps the legacy source intact when migration data is malformed',
    () async {
      await preferences.setString('tone_library_tracks_v1', 'not json');

      await expectLater(repository.initialize(), throwsFormatException);
      expect(preferences.getString('tone_library_tracks_v1'), 'not json');
      expect(
        await (database.select(database.userPreferences)..where(
              (row) => row.key.equals('migration.shared_preferences.v1'),
            ))
            .getSingleOrNull(),
        isNull,
      );
    },
  );
}

ImportedTrack _track(
  String id, {
  required String title,
  String artist = 'Test Artist',
}) => ImportedTrack(
  id: id,
  path: 'content://media/$id',
  title: title,
  artist: artist,
  album: 'Test Album',
  durationMs: 180000,
  isDeviceMedia: true,
);
