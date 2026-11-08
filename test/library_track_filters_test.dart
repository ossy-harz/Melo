import 'package:flutter_test/flutter_test.dart';
import 'package:tone_player/features/library/imported_track.dart';
import 'package:tone_player/features/library/library_track_filters.dart';

void main() {
  final tracks = [
    ImportedTrack(
      id: 'small',
      path: '/music/small.mp3',
      title: 'Alpha',
      dateModifiedAt: DateTime(2026, 1, 2, 9),
      fileSizeBytes: 2 * 1024 * 1024,
      durationMs: 120000,
    ),
    ImportedTrack(
      id: 'large',
      path: '/music/large.mp3',
      title: 'Charlie',
      dateModifiedAt: DateTime(2026, 1, 3, 10),
      fileSizeBytes: 10 * 1024 * 1024,
      durationMs: 300000,
    ),
    const ImportedTrack(
      id: 'unknown',
      path: '/music/unknown.mp3',
      title: 'Bravo',
    ),
  ];

  test(
    'filters by inclusive modified date, file size, and duration ranges',
    () {
      final filters = LibraryTrackFilters(
        modifiedFrom: DateTime(2026, 1, 2),
        modifiedThrough: DateTime(2026, 1, 3),
        minimumSizeBytes: 2 * 1024 * 1024,
        maximumSizeBytes: 10 * 1024 * 1024,
        minimumDurationMs: 120000,
        maximumDurationMs: 300000,
      );

      expect(filters.isActive, isTrue);
      expect(
        filters
            .apply(tracks, LibraryTrackSort.libraryOrder)
            .map((track) => track.id),
        ['small', 'large'],
      );
    },
  );

  test('sorts by metadata while keeping unknown values after known values', () {
    expect(
      const LibraryTrackFilters()
          .apply(tracks, LibraryTrackSort.largestFile)
          .map((track) => track.id),
      ['large', 'small', 'unknown'],
    );
    expect(
      const LibraryTrackFilters()
          .apply(tracks, LibraryTrackSort.title)
          .map((track) => track.id),
      ['small', 'unknown', 'large'],
    );
  });
}
