import 'package:flutter_test/flutter_test.dart';
import 'package:tone_player/features/library/imported_track.dart';
import 'package:tone_player/features/mix/local_discovery.dart';

void main() {
  const tracks = [
    ImportedTrack(
      id: 'artist-a-1',
      path: '/music/artist-a-1.mp3',
      title: 'Artist A one',
      artist: 'Artist A',
      genre: 'Electronic',
      bpm: 120,
    ),
    ImportedTrack(
      id: 'artist-a-2',
      path: '/music/artist-a-2.mp3',
      title: 'Artist A two',
      artist: 'Artist A',
      genre: 'Electronic',
      bpm: 122,
    ),
    ImportedTrack(
      id: 'related-genre',
      path: '/music/related-genre.mp3',
      title: 'Related genre',
      artist: 'Artist B',
      genre: 'electronic',
    ),
    ImportedTrack(
      id: 'related-tempo',
      path: '/music/related-tempo.mp3',
      title: 'Related tempo',
      artist: 'Artist C',
      bpm: 124,
    ),
    ImportedTrack(
      id: 'unrelated',
      path: '/music/unrelated.mp3',
      title: 'Unrelated',
      artist: 'Artist D',
      genre: 'Ambient',
      bpm: 72,
    ),
  ];

  test('artist radio starts with the artist and uses actual local signals', () {
    final station = LocalDiscovery.artistRadio(tracks, 'artist a');

    expect(station.first.id, 'artist-a-1');
    expect(station[1].id, 'related-genre');
    expect(station.map((track) => track.id), contains('related-genre'));
    expect(station.map((track) => track.id), contains('related-tempo'));
    expect(station.map((track) => track.id), isNot(contains('unrelated')));
    expect(LocalDiscovery.artistRadio(tracks, 'not in library'), isEmpty);
  });

  test('artist radio rotates seeds and alternates related artists', () {
    final firstRotation = LocalDiscovery.artistRadio(
      tracks,
      'Artist A',
      rotation: 0,
    );
    final nextRotation = LocalDiscovery.artistRadio(
      tracks,
      'Artist A',
      rotation: 1,
    );

    expect(firstRotation.first.id, 'artist-a-1');
    expect(nextRotation.first.id, 'artist-a-2');
    expect(
      firstRotation.take(3).map((track) => track.artist).toSet(),
      hasLength(3),
    );
    expect(
      firstRotation.map((track) => track.id),
      isNot(nextRotation.map((track) => track.id)),
    );
  });

  test('artist radio explores across artists when tags are missing', () {
    const untagged = [
      ImportedTrack(
        id: 'a-one',
        path: '/music/a-one.mp3',
        title: 'A one',
        artist: 'Artist A',
      ),
      ImportedTrack(
        id: 'a-two',
        path: '/music/a-two.mp3',
        title: 'A two',
        artist: 'Artist A',
      ),
      ImportedTrack(
        id: 'b-one',
        path: '/music/b-one.mp3',
        title: 'B one',
        artist: 'Artist B',
      ),
      ImportedTrack(
        id: 'c-one',
        path: '/music/c-one.mp3',
        title: 'C one',
        artist: 'Artist C',
      ),
    ];

    final station = LocalDiscovery.artistRadio(untagged, 'Artist A');

    expect(station.take(3).map((track) => track.artist).toSet(), hasLength(3));
  });

  test('artist radio uses related genre families and listening signals', () {
    const stationTracks = [
      ImportedTrack(
        id: 'seed',
        path: '/music/seed.mp3',
        title: 'Seed',
        artist: 'Seed Artist',
        genre: 'Electronic',
        bpm: 120,
      ),
      ImportedTrack(
        id: 'genre-neighbor',
        path: '/music/genre-neighbor.mp3',
        title: 'Genre Neighbor',
        artist: 'Genre Artist',
        genre: 'Electronic Dance',
        bpm: 121,
      ),
      ImportedTrack(
        id: 'favorite',
        path: '/music/favorite.mp3',
        title: 'Favorite',
        artist: 'Favorite Artist',
      ),
      ImportedTrack(
        id: 'most-played',
        path: '/music/most-played.mp3',
        title: 'Most Played',
        artist: 'Played Artist',
      ),
    ];

    final station = LocalDiscovery.artistRadio(
      stationTracks,
      'Seed Artist',
      favoriteTrackIds: const {'favorite'},
      playCounts: const {'most-played': 20},
    );

    expect(station.first.id, 'seed');
    expect(station[1].id, 'genre-neighbor');
    expect(station, contains(stationTracks[2]));
    expect(station, contains(stationTracks[3]));
  });

  test('suggestions require real genre or favorite signals', () {
    final suggestions = LocalDiscovery.suggestions(
      tracks,
      favoriteTrackIds: const {'artist-a-1', 'artist-a-2'},
    );

    expect(suggestions, hasLength(2));
    expect(suggestions.first.name, 'Artist A on repeat');
    expect(
      suggestions.first.tracks.map((track) => track.id),
      contains('artist-a-2'),
    );
    expect(suggestions.last.name, 'Electronic flow');
    expect(suggestions.last.tracks, hasLength(3));
    expect(
      LocalDiscovery.suggestions([tracks.last], favoriteTrackIds: const {}),
      isEmpty,
    );
  });

  test('recommendations rank favorites and rotate a diverse local slate', () {
    final firstPage = LocalDiscovery.recommendations(
      tracks,
      favoriteTrackIds: const {'artist-a-1', 'artist-a-2'},
      limit: 2,
    );
    final nextPage = LocalDiscovery.recommendations(
      tracks,
      favoriteTrackIds: const {'artist-a-1', 'artist-a-2'},
      rotation: 1,
      limit: 2,
    );

    expect(firstPage, hasLength(2));
    expect(firstPage.first.type, DiscoveryPickType.artistRadio);
    expect(firstPage.map((pick) => pick.type).toSet(), hasLength(2));
    expect(
      firstPage.map((pick) => pick.name),
      isNot(nextPage.map((pick) => pick.name)),
    );
    expect(
      [
        ...firstPage,
        ...nextPage,
      ].expand((pick) => pick.tracks).every((track) => track.isAvailable),
      isTrue,
    );
  });

  test(
    'recommendations avoid duplicate moods and handle untagged libraries',
    () {
      const oneTaggedTrack = ImportedTrack(
        id: 'tagged',
        path: '/music/tagged.mp3',
        title: 'Tagged song',
        artist: 'Tone Test',
        genre: 'Afrobeats',
        bpm: 120,
      );
      const untaggedTrack = ImportedTrack(
        id: 'untagged',
        path: '/music/untagged.mp3',
        title: 'Untagged song',
      );

      final recommendations = LocalDiscovery.recommendations([
        oneTaggedTrack,
      ], favoriteTrackIds: const {});

      expect(recommendations, hasLength(1));
      expect(
        LocalDiscovery.recommendations([
          untaggedTrack,
        ], favoriteTrackIds: const {}),
        isEmpty,
      );
    },
  );

  test('mood mixes use explicit library genre and BPM metadata', () {
    final moods = LocalDiscovery.moodMixes(tracks);
    final morning = moods.firstWhere(
      (mood) => mood.mood == LocalMood.morningGlow,
    );
    final nightDrive = moods.firstWhere(
      (mood) => mood.mood == LocalMood.nightDrive,
    );
    final softLanding = moods.firstWhere(
      (mood) => mood.mood == LocalMood.softLanding,
    );

    expect(morning.tracks.map((track) => track.id), contains('artist-a-1'));
    expect(
      nightDrive.tracks.map((track) => track.id),
      contains('related-genre'),
    );
    expect(softLanding.tracks.map((track) => track.id), contains('unrelated'));
    expect(
      LocalDiscovery.moodMixes([
        const ImportedTrack(
          id: 'untagged',
          path: '/music/untagged.mp3',
          title: 'No mood signals',
        ),
      ]),
      isEmpty,
    );
  });

  test('genre and mood picks learn from favorites and play counts', () {
    final genres = LocalDiscovery.genreMixes(
      tracks,
      favoriteTrackIds: const {'related-genre'},
      playCounts: const {'artist-a-1': 2, 'related-genre': 12},
    );
    final moods = LocalDiscovery.moodMixes(
      tracks,
      favoriteTrackIds: const {'artist-a-1'},
      playCounts: const {'artist-a-2': 20},
    );

    expect(genres.first.genre.toLowerCase(), 'electronic');
    expect(genres.first.tracks.first.id, 'related-genre');
    expect(
      moods
          .firstWhere((mood) => mood.mood == LocalMood.morningGlow)
          .tracks
          .first
          .id,
      'artist-a-2',
    );
  });
}
