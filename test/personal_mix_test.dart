import 'package:flutter_test/flutter_test.dart';
import 'package:tone_player/features/library/imported_track.dart';
import 'package:tone_player/features/mix/personal_mix.dart';

void main() {
  final tracks = [
    const ImportedTrack(
      id: 'favorite-a',
      path: '/music/favorite-a.mp3',
      title: 'Favorite A',
      durationMs: 300000,
    ),
    const ImportedTrack(
      id: 'favorite-b',
      path: '/music/favorite-b.mp3',
      title: 'Favorite B',
      durationMs: 300000,
    ),
    const ImportedTrack(
      id: 'other-a',
      path: '/music/other-a.mp3',
      title: 'Other A',
      durationMs: 300000,
    ),
    const ImportedTrack(
      id: 'unknown-duration',
      path: '/music/unknown.mp3',
      title: 'Unknown duration',
    ),
    const ImportedTrack(
      id: 'excluded',
      path: '/music/excluded.mp3',
      title: 'Excluded',
      durationMs: 300000,
    ),
  ];

  test('builds a unique, duration-bounded mix from eligible tracks', () {
    final mix = PersonalMixGenerator.generate(
      tracks: tracks,
      favoriteTrackIds: const {'favorite-a', 'favorite-b'},
      excludedTrackIds: const {'excluded'},
      targetDuration: const Duration(minutes: 15),
      discovery: 0.5,
      randomSeed: 11,
    );

    expect(mix, hasLength(3));
    expect(mix.map((pick) => pick.track.id).toSet(), hasLength(3));
    expect(
      mix.fold<int>(0, (total, pick) => total + pick.track.durationMs!),
      lessThanOrEqualTo(const Duration(minutes: 15).inMilliseconds),
    );
    expect(
      mix.map((pick) => pick.track.id),
      isNot(contains('unknown-duration')),
    );
    expect(mix.map((pick) => pick.track.id), isNot(contains('excluded')));
    expect(
      mix
          .where((pick) => pick.track.id.startsWith('favorite-'))
          .every((pick) => pick.reason == 'A favorite you saved'),
      isTrue,
    );
  });

  test('favors saved favorites at the familiar end of the slider', () {
    final mix = PersonalMixGenerator.generate(
      tracks: tracks,
      favoriteTrackIds: const {'favorite-a', 'favorite-b'},
      excludedTrackIds: const {},
      targetDuration: const Duration(minutes: 15),
      discovery: 0,
      randomSeed: 4,
    );

    expect(
      mix.take(2).every((pick) => pick.track.id.startsWith('favorite-')),
      isTrue,
    );
  });

  test('does not exceed the requested duration for a long track', () {
    final longTrack = const ImportedTrack(
      id: 'long',
      path: '/music/long.mp3',
      title: 'Long track',
      durationMs: 20 * 60 * 1000,
    );

    final mix = PersonalMixGenerator.generate(
      tracks: [longTrack],
      favoriteTrackIds: const {},
      excludedTrackIds: const {},
      targetDuration: const Duration(minutes: 15),
      discovery: 0.5,
      randomSeed: 2,
    );

    expect(mix, isEmpty);
  });

  test('keeps tagged genre and compatible tempo tracks together', () {
    final metadataTracks = [
      const ImportedTrack(
        id: 'rock-120',
        path: '/music/rock-120.mp3',
        title: 'Rock 120',
        durationMs: 180000,
        genre: 'Rock',
        bpm: 120,
      ),
      const ImportedTrack(
        id: 'rock-124',
        path: '/music/rock-124.mp3',
        title: 'Rock 124',
        durationMs: 180000,
        genre: 'rock',
        bpm: 124,
      ),
      const ImportedTrack(
        id: 'jazz-80',
        path: '/music/jazz-80.mp3',
        title: 'Jazz 80',
        durationMs: 180000,
        genre: 'Jazz',
        bpm: 80,
      ),
    ];

    final mix = PersonalMixGenerator.generate(
      tracks: metadataTracks,
      favoriteTrackIds: const {},
      excludedTrackIds: const {},
      targetDuration: const Duration(minutes: 10),
      discovery: 0.5,
      randomSeed: 3,
    );

    expect(mix, hasLength(3));
    expect(mix.any((pick) => pick.reason.startsWith('DJ flow')), isTrue);
  });

  test('persists optional genre and BPM metadata', () {
    const track = ImportedTrack(
      id: 'tagged',
      path: '/music/tagged.mp3',
      title: 'Tagged song',
      genre: 'Electronic',
      bpm: 128.5,
    );

    final restored = ImportedTrack.fromJson(track.toJson());

    expect(restored.genre, 'Electronic');
    expect(restored.bpm, 128.5);
    expect(restored.toMediaItem().extras?['genre'], 'Electronic');
    expect(restored.toMediaItem().extras?['bpm'], 128.5);
  });
}
