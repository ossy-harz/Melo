import 'package:tone_player/features/library/imported_track.dart';

class PlaylistSuggestion {
  const PlaylistSuggestion({
    required this.name,
    required this.description,
    required this.tracks,
  });

  final String name;
  final String description;
  final List<ImportedTrack> tracks;
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

abstract final class LocalDiscovery {
  static const _maxStationTracks = 40;
  static const _maxPlaylistTracks = 40;
  static const _maxSuggestions = 3;

  static List<T> dailyRotation<T>(Iterable<T> items, {required DateTime date}) {
    final values = items.toList(growable: false);
    if (values.length < 2) return List.unmodifiable(values);
    final dateOnly = DateTime(date.year, date.month, date.day);
    final epoch = DateTime(2020);
    final elapsedDays = dateOnly.difference(epoch).inDays;
    final offset =
        (elapsedDays % values.length + values.length) % values.length;
    return List.unmodifiable([...values.skip(offset), ...values.take(offset)]);
  }

  static List<ImportedTrack> artistRadio(
    Iterable<ImportedTrack> library,
    String artist,
  ) {
    final normalizedArtist = artist.trim().toLowerCase();
    if (normalizedArtist.isEmpty) return const [];
    final tracks = library.toList(growable: false);
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
    final artistTrackIds = artistTracks.map((track) => track.id).toSet();
    final related = tracks.where((track) {
      if (artistTrackIds.contains(track.id)) return false;
      final genre = track.genre?.trim().toLowerCase();
      return (genre != null && genres.contains(genre)) ||
          _tempoMatches(anchorTempo, track.bpm);
    });
    return List.unmodifiable(
      [...artistTracks, ...related].take(_maxStationTracks),
    );
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
          tracks: artistRadio(tracks, favoriteArtist.key),
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

  static List<LocalMoodMix> moodMixes(Iterable<ImportedTrack> library) {
    final tracks = library.toList(growable: false);
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
                  final score = (genreMatch ? 2 : 0) + (tempoMatch ? 1 : 0);
                  return (track: track, score: score);
                })
                .where((match) => match.score > 0)
                .toList()
              ..sort((first, second) => second.score.compareTo(first.score));
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

  static bool _tempoMatches(double? first, double? second) {
    if (first == null || second == null || first <= 0 || second <= 0) {
      return false;
    }
    final ratio = first > second ? first / second : second / first;
    return (ratio - 1).abs() <= 0.08 ||
        (ratio - 2).abs() <= 0.16 ||
        (ratio - 1.5).abs() <= 0.12;
  }
}
