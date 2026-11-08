import 'package:melo_player/features/library/imported_track.dart';

abstract final class DuplicateTrackSelection {
  static Set<String> smartRemovalIds(
    Iterable<List<ImportedTrack>> duplicateGroups, {
    required Set<String> favoriteTrackIds,
    Map<String, int> playCounts = const {},
  }) {
    final selected = <String>{};
    for (final group in duplicateGroups) {
      if (group.length < 2) continue;
      final ranked = [...group]
        ..sort((first, second) {
          final score = _keepScore(
            second,
            favoriteTrackIds,
            playCounts,
          ).compareTo(_keepScore(first, favoriteTrackIds, playCounts));
          return score != 0 ? score : first.id.compareTo(second.id);
        });
      selected.addAll(ranked.skip(1).map((track) => track.id));
    }
    return Set.unmodifiable(selected);
  }

  static int _keepScore(
    ImportedTrack track,
    Set<String> favoriteTrackIds,
    Map<String, int> playCounts,
  ) {
    var score = track.isAvailable ? 10000 : 0;
    if (favoriteTrackIds.contains(track.id)) score += 1000;
    score += (playCounts[track.id] ?? 0) * 10;
    if (track.album.trim().isNotEmpty &&
        track.album.toLowerCase() != 'unknown album') {
      score += 2;
    }
    if (track.genre?.trim().isNotEmpty == true) score++;
    if (track.year != null) score++;
    if (track.trackNumber != null) score++;
    if (track.artworkUri?.trim().isNotEmpty == true) score++;
    if (track.durationMs != null) score++;
    return score;
  }
}
