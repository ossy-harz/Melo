import 'package:tone_player/features/library/imported_track.dart';

enum LibraryTrackSort {
  libraryOrder,
  title,
  recentlyModified,
  oldestModified,
  largestFile,
  smallestFile,
  longestDuration,
  shortestDuration,
}

extension LibraryTrackSortLabel on LibraryTrackSort {
  String get label => switch (this) {
    LibraryTrackSort.libraryOrder => 'Library order',
    LibraryTrackSort.title => 'Title (A–Z)',
    LibraryTrackSort.recentlyModified => 'Recently modified',
    LibraryTrackSort.oldestModified => 'Oldest modified',
    LibraryTrackSort.largestFile => 'Largest file',
    LibraryTrackSort.smallestFile => 'Smallest file',
    LibraryTrackSort.longestDuration => 'Longest duration',
    LibraryTrackSort.shortestDuration => 'Shortest duration',
  };
}

class LibraryTrackFilters {
  const LibraryTrackFilters({
    this.modifiedFrom,
    this.modifiedThrough,
    this.minimumSizeBytes,
    this.maximumSizeBytes,
    this.minimumDurationMs,
    this.maximumDurationMs,
  });

  final DateTime? modifiedFrom;
  final DateTime? modifiedThrough;
  final int? minimumSizeBytes;
  final int? maximumSizeBytes;
  final int? minimumDurationMs;
  final int? maximumDurationMs;

  bool get isActive =>
      modifiedFrom != null ||
      modifiedThrough != null ||
      minimumSizeBytes != null ||
      maximumSizeBytes != null ||
      minimumDurationMs != null ||
      maximumDurationMs != null;

  bool matches(ImportedTrack track) {
    final modifiedAt = track.dateModifiedAt;
    if (modifiedFrom != null &&
        (modifiedAt == null ||
            _calendarDay(modifiedAt).isBefore(_calendarDay(modifiedFrom!)))) {
      return false;
    }
    if (modifiedThrough != null &&
        (modifiedAt == null ||
            _calendarDay(modifiedAt).isAfter(_calendarDay(modifiedThrough!)))) {
      return false;
    }
    if (!_within(track.fileSizeBytes, minimumSizeBytes, maximumSizeBytes)) {
      return false;
    }
    return _within(track.durationMs, minimumDurationMs, maximumDurationMs);
  }

  List<ImportedTrack> apply(
    Iterable<ImportedTrack> tracks,
    LibraryTrackSort sort,
  ) {
    final result = tracks.where(matches).toList(growable: false);
    if (sort == LibraryTrackSort.libraryOrder) return result;
    final indexed = [
      for (var index = 0; index < result.length; index++)
        (index: index, track: result[index]),
    ];
    indexed.sort((first, second) {
      final comparison = switch (sort) {
        LibraryTrackSort.libraryOrder => 0,
        LibraryTrackSort.title => first.track.title.toLowerCase().compareTo(
          second.track.title.toLowerCase(),
        ),
        LibraryTrackSort.recentlyModified => _compareNullable(
          first.track.dateModifiedAt,
          second.track.dateModifiedAt,
          descending: true,
        ),
        LibraryTrackSort.oldestModified => _compareNullable(
          first.track.dateModifiedAt,
          second.track.dateModifiedAt,
        ),
        LibraryTrackSort.largestFile => _compareNullable(
          first.track.fileSizeBytes,
          second.track.fileSizeBytes,
          descending: true,
        ),
        LibraryTrackSort.smallestFile => _compareNullable(
          first.track.fileSizeBytes,
          second.track.fileSizeBytes,
        ),
        LibraryTrackSort.longestDuration => _compareNullable(
          first.track.durationMs,
          second.track.durationMs,
          descending: true,
        ),
        LibraryTrackSort.shortestDuration => _compareNullable(
          first.track.durationMs,
          second.track.durationMs,
        ),
      };
      return comparison == 0 ? first.index.compareTo(second.index) : comparison;
    });
    return indexed.map((entry) => entry.track).toList(growable: false);
  }

  static DateTime _calendarDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static bool _within(int? value, int? minimum, int? maximum) {
    if (minimum == null && maximum == null) return true;
    if (value == null) return false;
    return (minimum == null || value >= minimum) &&
        (maximum == null || value <= maximum);
  }

  static int _compareNullable<T extends Comparable<T>>(
    T? first,
    T? second, {
    bool descending = false,
  }) {
    if (first == null) return second == null ? 0 : 1;
    if (second == null) return -1;
    final comparison = first.compareTo(second);
    return descending ? -comparison : comparison;
  }
}
