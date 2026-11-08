import 'package:melo_player/features/library/imported_track.dart';

enum DiscoveryPickType { artistRadio, moodMix, playlist }

class PlaylistSuggestion {
  const PlaylistSuggestion({
    required this.name,
    required this.description,
    required this.tracks,
    this.type = DiscoveryPickType.playlist,
  });

  final String name;
  final String description;
  final List<ImportedTrack> tracks;
  final DiscoveryPickType type;
}

enum LocalMood { morningGlow, nightDrive, softLanding, fullVolume }

class LocalMoodMix {
  const LocalMoodMix({
    required this.mood,
    required this.name,
    required this.description,
    required this.tracks,
  });

  final LocalMood mood;
  final String name;
  final String description;
  final List<ImportedTrack> tracks;
}

class LocalGenreMix {
  const LocalGenreMix({required this.genre, required this.tracks});

  final String genre;
  final List<ImportedTrack> tracks;
}

abstract final class LocalDiscovery {
  static const _maxStationTracks = 40;
  static const _maxPlaylistTracks = 40;
  static const _maxSuggestions = 3;

  static List<ImportedTrack> artistRadio(
    Iterable<ImportedTrack> library,
    String artist, {
    Set<String> favoriteTrackIds = const {},
    Map<String, int> playCounts = const {},
    int rotation = 0,
  }) {
    final normalizedArtist = artist.trim().toLowerCase();
    if (normalizedArtist.isEmpty) return const [];
    final tracks = library.where((track) => track.isAvailable).toList();
    final artistTracks = tracks
        .where(
          (track) =>
              displayArtistName(track.artist).trim().toLowerCase() ==
              normalizedArtist,
        )
        .toList(growable: false);
    if (artistTracks.isEmpty) return const [];

    final genres = artistTracks
        .map((track) => track.genre?.trim().toLowerCase())
        .whereType<String>()
        .where((genre) => genre.isNotEmpty)
        .toSet();
    final tempos = artistTracks.map((track) => track.bpm).whereType<double>();
    final anchorTempo = tempos.isEmpty
        ? null
        : tempos.reduce((sum, bpm) => sum + bpm) / tempos.length;
    final offset =
        (rotation % artistTracks.length + artistTracks.length) %
        artistTracks.length;
    final firstTrack = artistTracks[offset];
    final candidatesByArtist =
        <String, List<({ImportedTrack track, double score})>>{};
    for (final track in tracks) {
      if (track.id == firstTrack.id) continue;
      final trackArtist = displayArtistName(track.artist).trim().toLowerCase();
      final genre = track.genre?.trim().toLowerCase();
      final genreMatch = genre == null ? 0.0 : _genreSimilarity(genre, genres);
      final tempoMatch = _tempoSimilarity(anchorTempo, track.bpm);
      final sameArtist = trackArtist == normalizedArtist;
      var score = sameArtist ? 0.5 : genreMatch * 3.0 + tempoMatch * 2.0;
      if (favoriteTrackIds.contains(track.id)) score += 0.75;
      score += (playCounts[track.id] ?? 0).clamp(0, 20) * 0.03;
      if (score == 0) continue;
      candidatesByArtist.putIfAbsent(trackArtist, () => []).add((
        track: track,
        score: score,
      ));
    }

    final hasRelatedArtist = candidatesByArtist.keys.any(
      (key) => key != normalizedArtist,
    );
    if (!hasRelatedArtist) {
      for (final track in tracks) {
        final trackArtist = displayArtistName(track.artist)
            .trim()
            .toLowerCase();
        if (track.id == firstTrack.id || trackArtist == normalizedArtist) {
          continue;
        }
        candidatesByArtist.putIfAbsent(trackArtist, () => []).add((
          track: track,
          score: 0.6,
        ));
      }
    }

    final artistGroups = candidatesByArtist.entries.toList()
      ..sort((first, second) {
        final firstScore = first.value
            .map((candidate) => candidate.score)
            .reduce((a, b) => a > b ? a : b);
        final secondScore = second.value
            .map((candidate) => candidate.score)
            .reduce((a, b) => a > b ? a : b);
        final scoreComparison = secondScore.compareTo(firstScore);
        return scoreComparison != 0
            ? scoreComparison
            : first.key.compareTo(second.key);
      });
    if (artistGroups.isNotEmpty) {
      final groupOffset =
          (rotation % artistGroups.length + artistGroups.length) %
          artistGroups.length;
      final rotatedGroups = [
        ...artistGroups.skip(groupOffset),
        ...artistGroups.take(groupOffset),
      ];
      artistGroups
        ..clear()
        ..addAll(rotatedGroups);
    }
    for (final group in artistGroups) {
      group.value.sort((first, second) {
        final scoreComparison = second.score.compareTo(first.score);
        return scoreComparison != 0
            ? scoreComparison
            : first.track.title.compareTo(second.track.title);
      });
    }

    final station = <ImportedTrack>[firstTrack];
    for (var round = 0; station.length < _maxStationTracks; round++) {
      var foundTrack = false;
      for (final group in artistGroups) {
        if (round >= group.value.length) continue;
        station.add(group.value[round].track);
        foundTrack = true;
        if (station.length == _maxStationTracks) break;
      }
      if (!foundTrack) break;
    }
    return List.unmodifiable(station);
  }

  static List<PlaylistSuggestion> suggestions(
    Iterable<ImportedTrack> library, {
    required Set<String> favoriteTrackIds,
  }) {
    final tracks = library.toList(growable: false);
    final suggestions = <PlaylistSuggestion>[];
    final favoriteArtists = <String, List<ImportedTrack>>{};
    for (final track in tracks) {
      if (!favoriteTrackIds.contains(track.id)) continue;
      final artist = displayArtistName(track.artist);
      if (artist.isEmpty || artist == 'On-device audio') continue;
      favoriteArtists.putIfAbsent(artist, () => []).add(track);
    }

    MapEntry<String, List<ImportedTrack>>? favoriteArtist;
    for (final entry in favoriteArtists.entries) {
      if (entry.value.length >= 2) {
        favoriteArtist = entry;
        break;
      }
    }
    if (favoriteArtist != null) {
      suggestions.add(
        PlaylistSuggestion(
          name: '${favoriteArtist.key} on repeat',
          description: 'Your favorites, plus more from your library',
          tracks: artistRadio(
            tracks,
            favoriteArtist.key,
            favoriteTrackIds: favoriteTrackIds,
          ),
        ),
      );
    }

    final genres = <String, List<ImportedTrack>>{};
    for (final track in tracks) {
      final genre = track.genre?.trim();
      if (genre == null || genre.isEmpty) continue;
      genres.putIfAbsent(genre.toLowerCase(), () => []).add(track);
    }
    final genreEntries = genres.entries.toList()
      ..sort(
        (first, second) => second.value.length.compareTo(first.value.length),
      );
    for (final entry in genreEntries) {
      if (suggestions.length >= _maxSuggestions) break;
      if (entry.value.length < 3) continue;
      final label = entry.value.first.genre!.trim();
      if (suggestions.any(
        (suggestion) =>
            suggestion.name.toLowerCase() == '$label flow'.toLowerCase(),
      )) {
        continue;
      }
      suggestions.add(
        PlaylistSuggestion(
          name: '$label flow',
          description: '${entry.value.length} songs with this sound',
          tracks: List.unmodifiable(entry.value.take(_maxPlaylistTracks)),
        ),
      );
    }

    if (suggestions.length < _maxSuggestions) {
      final favorites = tracks
          .where((track) => favoriteTrackIds.contains(track.id))
          .toList(growable: false);
      if (favorites.length >= 3) {
        suggestions.add(
          PlaylistSuggestion(
            name: 'Your red thread',
            description: 'A playlist made from songs you love',
            tracks: List.unmodifiable(favorites.take(_maxPlaylistTracks)),
          ),
        );
      }
    }
    return List.unmodifiable(suggestions.take(_maxSuggestions));
  }

  static List<PlaylistSuggestion> recommendations(
    Iterable<ImportedTrack> library, {
    required Set<String> favoriteTrackIds,
    int rotation = 0,
    int limit = 3,
  }) {
    if (limit <= 0) return const [];
    final tracks = library.where((track) => track.isAvailable).toList();
    if (tracks.isEmpty) return const [];
    final candidates = <({PlaylistSuggestion pick, double score})>[];

    final artists = <String, List<ImportedTrack>>{};
    final favoriteCounts = <String, int>{};
    for (final track in tracks) {
      final artist = displayArtistName(track.artist).trim();
      if (artist.isEmpty || artist.toLowerCase() == 'on-device audio') {
        continue;
      }
      final key = artist.toLowerCase();
      artists.putIfAbsent(key, () => []).add(track);
      if (favoriteTrackIds.contains(track.id)) {
        favoriteCounts.update(key, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    final rankedArtists = artists.entries.toList()
      ..sort((first, second) {
        final firstScore =
            first.value.length * 1.4 + (favoriteCounts[first.key] ?? 0) * 2.5;
        final secondScore =
            second.value.length * 1.4 + (favoriteCounts[second.key] ?? 0) * 2.5;
        final scoreComparison = secondScore.compareTo(firstScore);
        return scoreComparison != 0
            ? scoreComparison
            : first.key.compareTo(second.key);
      });
    for (final entry in rankedArtists.take(16)) {
      final artistTracks = entry.value;
      final artist = displayArtistName(artistTracks.first.artist).trim();
      final station = artistRadio(
        tracks,
        artist,
        favoriteTrackIds: favoriteTrackIds,
      ).where((track) => track.isAvailable).toList(growable: false);
      if (station.length < 2) continue;
      final favorites = favoriteCounts[entry.key] ?? 0;
      candidates.add((
        pick: PlaylistSuggestion(
          name: '$artist Radio',
          description: 'Local picks matched by genre, tempo and favorites',
          tracks: List.unmodifiable(station.take(_maxStationTracks)),
          type: DiscoveryPickType.artistRadio,
        ),
        score: 2 + artistTracks.length * 1.4 + favorites * 2.5,
      ));
    }

    for (final suggestion in suggestions(
      tracks,
      favoriteTrackIds: favoriteTrackIds,
    )) {
      final favorites = suggestion.tracks
          .where((track) => favoriteTrackIds.contains(track.id))
          .length;
      candidates.add((
        pick: suggestion,
        score: 1.5 + suggestion.tracks.length * 0.55 + favorites * 1.6,
      ));
    }

    for (final mood in moodMixes(tracks)) {
      final favorites = mood.tracks
          .where((track) => favoriteTrackIds.contains(track.id))
          .length;
      candidates.add((
        pick: PlaylistSuggestion(
          name: mood.name,
          description: mood.description,
          tracks: mood.tracks,
          type: DiscoveryPickType.moodMix,
        ),
        score: 1 + mood.tracks.length * 0.45 + favorites * 1.8,
      ));
    }

    final ranked = <({PlaylistSuggestion pick, double score})>[];
    final seenNames = <String>{};
    for (final candidate in candidates) {
      final normalizedName = candidate.pick.name.toLowerCase();
      if (candidate.pick.tracks.isEmpty || !seenNames.add(normalizedName)) {
        continue;
      }
      ranked.add(candidate);
    }
    ranked.sort((first, second) {
      final score = second.score.compareTo(first.score);
      return score != 0 ? score : first.pick.name.compareTo(second.pick.name);
    });
    if (ranked.isEmpty) return const [];
    final pageCount = (ranked.length / limit).ceil();
    final start = (rotation.abs() % pageCount) * limit;
    final ordered = [...ranked.skip(start), ...ranked.take(start)];
    final diverse = <PlaylistSuggestion>[];
    final types = <DiscoveryPickType>{};
    for (final candidate in ordered) {
      if (diverse.length >= limit || types.contains(candidate.pick.type)) {
        continue;
      }
      if (_overlapsTooMuch(candidate.pick, diverse)) continue;
      types.add(candidate.pick.type);
      diverse.add(candidate.pick);
    }
    for (final candidate in ordered) {
      if (diverse.length >= limit) break;
      if (diverse.contains(candidate.pick) ||
          _overlapsTooMuch(candidate.pick, diverse)) {
        continue;
      }
      diverse.add(candidate.pick);
    }
    return List.unmodifiable(diverse);
  }

  static bool _overlapsTooMuch(
    PlaylistSuggestion candidate,
    List<PlaylistSuggestion> selected,
  ) {
    final candidateIds = candidate.tracks.map((track) => track.id).toSet();
    if (candidateIds.isEmpty) return true;
    for (final pick in selected) {
      final selectedIds = pick.tracks.map((track) => track.id).toSet();
      final intersection = candidateIds.intersection(selectedIds).length;
      final union = candidateIds.union(selectedIds).length;
      if (union > 0 && intersection / union >= 0.72) return true;
    }
    return false;
  }

  static List<LocalGenreMix> genreMixes(
    Iterable<ImportedTrack> library, {
    Set<String> favoriteTrackIds = const {},
    Map<String, int> playCounts = const {},
    int limit = 3,
  }) {
    final grouped = <String, List<ImportedTrack>>{};
    for (final track in library) {
      if (!track.isAvailable) continue;
      final genre = track.genre?.trim();
      if (genre == null || genre.isEmpty) continue;
      grouped.putIfAbsent(genre.toLowerCase(), () => []).add(track);
    }

    final groups =
        grouped.values.map((tracks) {
          final weightedScore = tracks.fold<double>(
            0,
            (score, track) =>
                score + _listeningScore(track, favoriteTrackIds, playCounts),
          );
          final rankedTracks = [...tracks]
            ..sort((first, second) {
              final score = _listeningScore(
                second,
                favoriteTrackIds,
                playCounts,
              ).compareTo(_listeningScore(first, favoriteTrackIds, playCounts));
              return score != 0 ? score : first.title.compareTo(second.title);
            });
          return (
            score: weightedScore,
            mix: LocalGenreMix(
              genre: tracks.first.genre!.trim(),
              tracks: List.unmodifiable(rankedTracks.take(_maxPlaylistTracks)),
            ),
          );
        }).toList()..sort((first, second) {
          final score = second.score.compareTo(first.score);
          return score != 0
              ? score
              : first.mix.genre.compareTo(second.mix.genre);
        });
    return List.unmodifiable(groups.take(limit).map((group) => group.mix));
  }

  static List<LocalMoodMix> moodMixes(
    Iterable<ImportedTrack> library, {
    Set<String> favoriteTrackIds = const {},
    Map<String, int> playCounts = const {},
  }) {
    final tracks = library.where((track) => track.isAvailable).toList();
    final moods =
        <
          ({
            LocalMood mood,
            String name,
            String description,
            Set<String> genres,
            double minBpm,
            double maxBpm,
          })
        >[
          (
            mood: LocalMood.morningGlow,
            name: 'Morning glow',
            description: 'Warm, easy-start tracks',
            genres: {'pop', 'soul', 'disco', 'r&b', 'afrobeats'},
            minBpm: 88,
            maxBpm: 132,
          ),
          (
            mood: LocalMood.nightDrive,
            name: 'Night drive',
            description: 'A steady road-ready flow',
            genres: {'electronic', 'synth', 'alternative', 'hip-hop', 'house'},
            minBpm: 72,
            maxBpm: 126,
          ),
          (
            mood: LocalMood.softLanding,
            name: 'Soft landing',
            description: 'Gentler tempos from your tags',
            genres: {
              'ambient',
              'acoustic',
              'classical',
              'jazz',
              'folk',
              'soul',
            },
            minBpm: 0,
            maxBpm: 96,
          ),
          (
            mood: LocalMood.fullVolume,
            name: 'Full volume',
            description: 'Up-tempo energy from your library',
            genres: {'dance', 'electronic', 'rock', 'pop', 'afrobeats'},
            minBpm: 112,
            maxBpm: 300,
          ),
        ];

    return List.unmodifiable(
      moods.map((mood) {
        final matches =
            tracks
                .map((track) {
                  final genre = track.genre?.trim().toLowerCase() ?? '';
                  final genreMatch = mood.genres.any(genre.contains);
                  final bpm = track.bpm;
                  final tempoMatch =
                      bpm != null && bpm >= mood.minBpm && bpm <= mood.maxBpm;
                  final signalScore =
                      (genreMatch ? 2.0 : 0.0) + (tempoMatch ? 1.0 : 0.0);
                  final score = signalScore > 0
                      ? signalScore +
                            _listeningScore(track, favoriteTrackIds, playCounts)
                      : 0.0;
                  return (track: track, score: score);
                })
                .where((match) => match.score > 0)
                .toList()
              ..sort((first, second) {
                final score = second.score.compareTo(first.score);
                return score != 0
                    ? score
                    : first.track.title.compareTo(second.track.title);
              });
        if (matches.isEmpty) return null;
        return LocalMoodMix(
          mood: mood.mood,
          name: mood.name,
          description: mood.description,
          tracks: List.unmodifiable(
            matches.take(_maxPlaylistTracks).map((match) => match.track),
          ),
        );
      }).whereType<LocalMoodMix>(),
    );
  }

  static double _listeningScore(
    ImportedTrack track,
    Set<String> favoriteTrackIds,
    Map<String, int> playCounts,
  ) =>
      (favoriteTrackIds.contains(track.id) ? 2.0 : 0.0) +
      (playCounts[track.id] ?? 0).clamp(0, 20).toDouble() * 0.15;

  static bool _tempoMatches(double? first, double? second) {
    if (first == null || second == null || first <= 0 || second <= 0) {
      return false;
    }
    final ratio = first > second ? first / second : second / first;
    return (ratio - 1).abs() <= 0.08 ||
        (ratio - 2).abs() <= 0.16 ||
        (ratio - 1.5).abs() <= 0.12;
  }

  static double _tempoSimilarity(double? first, double? second) {
    if (first == null || second == null || first <= 0 || second <= 0) {
      return 0;
    }
    if (_tempoMatches(first, second)) return 1;
    final ratio = first > second ? first / second : second / first;
    if (ratio <= 1.18) return 0.55;
    if (ratio <= 1.35) return 0.25;
    return 0;
  }

  static double _genreSimilarity(String candidate, Set<String> seedGenres) {
    var best = 0.0;
    for (final seed in seedGenres) {
      if (candidate == seed) return 1;
      final candidateFamily = _genreFamily(candidate);
      if (candidateFamily != null && candidateFamily == _genreFamily(seed)) {
        best = best < 0.72 ? 0.72 : best;
        continue;
      }
      if (candidate.contains(seed) || seed.contains(candidate)) {
        best = best < 0.65 ? 0.65 : best;
        continue;
      }
      final candidateWords = candidate
          .split(RegExp(r'[^a-z0-9]+'))
          .where((word) => word.length > 2)
          .toSet();
      final seedWords = seed
          .split(RegExp(r'[^a-z0-9]+'))
          .where((word) => word.length > 2)
          .toSet();
      if (candidateWords.intersection(seedWords).isNotEmpty) {
        best = best < 0.5 ? 0.5 : best;
      }
    }
    return best;
  }

  static String? _genreFamily(String genre) {
    const families = <String, Set<String>>{
      'electronic': {
        'electronic',
        'dance',
        'house',
        'techno',
        'edm',
        'synth',
        'trance',
      },
      'urban': {'hip hop', 'hip-hop', 'rap', 'r&b', 'rnb', 'afrobeats'},
      'rock': {'rock', 'metal', 'punk', 'alternative', 'indie'},
      'acoustic': {'folk', 'acoustic', 'country', 'singer songwriter'},
    };
    for (final family in families.entries) {
      if (family.value.any(genre.contains)) return family.key;
    }
    return null;
  }
}
