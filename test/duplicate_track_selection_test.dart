import 'package:flutter_test/flutter_test.dart';
import 'package:melo_player/features/library/duplicate_track_selection.dart';
import 'package:melo_player/features/library/imported_track.dart';

void main() {
  test('keeps the most valuable available copy and selects the rest', () {
    const groups = [
      [
        ImportedTrack(
          id: 'plain-copy',
          path: '/music/plain.mp3',
          title: 'Blue Hour',
          artist: 'Tone Test',
        ),
        ImportedTrack(
          id: 'favorite-copy',
          path: '/music/favorite.mp3',
          title: 'Blue Hour',
          artist: 'Tone Test',
          album: 'Afterlight',
          genre: 'Electronic',
          year: 2025,
          durationMs: 180000,
          isAvailable: true,
        ),
        ImportedTrack(
          id: 'missing-copy',
          path: '/missing/song.mp3',
          title: 'Blue Hour',
          artist: 'Tone Test',
          isAvailable: false,
        ),
      ],
    ];

    final selected = DuplicateTrackSelection.smartRemovalIds(
      groups,
      favoriteTrackIds: const {'favorite-copy'},
      playCounts: const {'plain-copy': 100},
    );

    expect(selected, {'plain-copy', 'missing-copy'});
  });

  test('does not select a track unless its group has another copy', () {
    const groups = [
      [
        ImportedTrack(
          id: 'only-copy',
          path: '/music/only.mp3',
          title: 'Only song',
        ),
      ],
      <ImportedTrack>[],
    ];

    expect(
      DuplicateTrackSelection.smartRemovalIds(
        groups,
        favoriteTrackIds: const {},
      ),
      isEmpty,
    );
  });
}
