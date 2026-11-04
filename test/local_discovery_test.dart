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

  test('daily library rotation is stable for the day and changes by date', () {
    const records = ['one', 'two', 'three', 'four'];
    final firstDay = LocalDiscovery.dailyRotation(
      records,
      date: DateTime(2026, 11, 1, 8),
    );
    final sameDay = LocalDiscovery.dailyRotation(
      records,
      date: DateTime(2026, 11, 1, 22),
    );
    final nextDay = LocalDiscovery.dailyRotation(
      records,
      date: DateTime(2026, 11, 2),
    );

    expect(sameDay, firstDay);
    expect(nextDay, isNot(firstDay));
    expect(nextDay.toSet(), records.toSet());
  });

  test('artist radio starts with the artist and uses actual local signals', () {
    final station = LocalDiscovery.artistRadio(tracks, 'artist a');

    expect(station.take(2).map((track) => track.id), [
      'artist-a-1',
      'artist-a-2',
    ]);
    expect(station.map((track) => track.id), contains('related-genre'));
    expect(station.map((track) => track.id), contains('related-tempo'));
    expect(station.map((track) => track.id), isNot(contains('unrelated')));
    expect(LocalDiscovery.artistRadio(tracks, 'not in library'), isEmpty);
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
}
