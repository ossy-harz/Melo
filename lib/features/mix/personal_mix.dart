import 'dart:math';

import 'package:melo_player/features/library/imported_track.dart';

class MixPick {
  const MixPick({required this.track, required this.reason});

  final ImportedTrack track;
  final String reason;
}

/// Builds an ordered personal mix from local library metadata.
///
/// Candidates are scored for adjacency, energy, variety, and listener
/// preferences using tags already on the device.
abstract final class PersonalMixGenerator {
  static const maxTracks = 50;

  /// How strongly each signal influences the next pick.
  static const _energyWeight = 3.2;
  static const _compatibilityWeight = 2.4;
  static const _freshnessWeight = 1.4;
  static const _preferenceWeight = 2.6;

  /// A small seeded shuffle so two mixes of the same library differ, while
  /// never outweighing a genuinely better fit.
  static const _jitterWeight = 0.45;

  /// Where the energy arc starts, peaks, and settles.
  static const _openEnergy = 0.32;
  static const _peakEnergy = 0.95;
  static const _closingEnergy = 0.42;
  static const _peakAt = 0.66;

  /// A tempo span Tone can treat as "calm" through "driving" when a tagged
  /// BPM is the only energy signal available.
  static const _calmBpm = 78.0;
  static const _drivingBpm = 150.0;

  /// How far energy has to move before the reason mentions it.
  static const _energyShift = 0.12;

  static const _unknownAffinity = 0.5;

  static List<MixPick> generate({
    required Iterable<ImportedTrack> tracks,
    required Set<String> favoriteTrackIds,
    required Set<String> excludedTrackIds,
    required Duration targetDuration,
    required double discovery,
    int? randomSeed,
  }) {
    if (targetDuration <= Duration.zero) return const <MixPick>[];

    final remaining = <ImportedTrack>[];
    for (final track in tracks) {
      final durationMs = track.durationMs;
      if (excludedTrackIds.contains(track.id)) continue;
      if (!track.isAvailable) continue;
      if (durationMs == null || durationMs <= 0) continue;
      remaining.add(track);
    }
    if (remaining.isEmpty) return const <MixPick>[];

    final random = Random(randomSeed);
    final energies = <String, double>{
      for (final track in remaining) track.id: _energy(track),
    };

    // Share of the mix that should come from favorites. The slider leans the
    // balance rather than gating it, so the mix still works when a library has
    // almost no favorites.
    final familiarShare = (1 - discovery).clamp(0.0, 1.0);
    final targetMs = targetDuration.inMilliseconds;

    final picks = <MixPick>[];
    final artistUse = <String, int>{};
    final albumUse = <String, int>{};
    var elapsed = Duration.zero;
    ImportedTrack? previous;

    while (remaining.isNotEmpty && picks.length < maxTracks) {
      final position = (elapsed.inMilliseconds / targetMs).clamp(0.0, 1.0);
      final targetEnergy = _arcEnergy(position);
      final familiarSoFar = picks
          .where((pick) => favoriteTrackIds.contains(pick.track.id))
          .length;
      final preference = (familiarShare * (picks.length + 1) - familiarSoFar)
          .clamp(-1.0, 1.0);

      ImportedTrack? best;
      var bestScore = double.negativeInfinity;
      for (final candidate in remaining) {
        final durationMs = candidate.durationMs!;
        if (elapsed.inMilliseconds + durationMs > targetMs) continue;
        final score = _score(
          candidate: candidate,
          energy: energies[candidate.id]!,
          targetEnergy: targetEnergy,
          previous: previous,
          isFavorite: favoriteTrackIds.contains(candidate.id),
          preference: preference,
          artistUse: artistUse,
          albumUse: albumUse,
          random: random,
        );
        if (score > bestScore) {
          bestScore = score;
          best = candidate;
        }
      }
      if (best == null) break;

      picks.add(
        MixPick(
          track: best,
          reason: _reason(
            previous: previous,
            next: best,
            isFavorite: favoriteTrackIds.contains(best.id),
            energies: energies,
          ),
        ),
      );

      final artist = _artistKey(best);
      if (artist != null) artistUse[artist] = (artistUse[artist] ?? 0) + 1;
      final album = _albumKey(best);
      if (album != null) albumUse[album] = (albumUse[album] ?? 0) + 1;
      remaining.remove(best);
      elapsed += Duration(milliseconds: best.durationMs!);
      previous = best;
    }
    return List.unmodifiable(picks);
  }

  static double _score({
    required ImportedTrack candidate,
    required double energy,
    required double targetEnergy,
    required ImportedTrack? previous,
    required bool isFavorite,
    required double preference,
    required Map<String, int> artistUse,
    required Map<String, int> albumUse,
    required Random random,
  }) {
    // 1. How well the song sits against the shape of the mix.
    final energyFit = 1 - (energy - targetEnergy).abs().clamp(0.0, 1.0);

    // 2. How well its tags fit the previous pick.
    final compatibility = previous == null
        ? _unknownAffinity
        : _mixCompatibilityScore(previous, candidate);

    // 3. Artist and album separation, so a mix never becomes one album played
    //    in its own order. This nudges the choice, it never blocks a song.
    final freshness = _freshness(candidate, previous, artistUse, albumUse);

    // 4. How far the mix is from the favorites/other balance asked for.
    final balance = isFavorite ? preference : -preference;

    return _energyWeight * energyFit +
        _compatibilityWeight * compatibility +
        _freshnessWeight * freshness +
        _preferenceWeight * balance +
        _jitterWeight * random.nextDouble();
  }

  /// The shape of the mix: open gently, lift to a peak two-thirds of the way
  /// through, then come back down so the set lands instead of just stopping.
  static double _arcEnergy(double position) {
    if (position <= _peakAt) {
      return _openEnergy + (_peakEnergy - _openEnergy) * (position / _peakAt);
    }
    final fall = (position - _peakAt) / (1 - _peakAt);
    return _peakEnergy + (_closingEnergy - _peakEnergy) * fall;
  }

  /// A best guess at how energetic a track is, built only from tags. A tagged
  /// tempo is the stronger signal and a known genre refines it; when neither
  /// exists the track sits in the middle so it is neither chased nor avoided.
  static double _energy(ImportedTrack track) {
    final fromGenre = _genreEnergy(track.genre);
    final bpm = track.bpm;
    final fromTempo = bpm == null || !bpm.isFinite || bpm <= 0
        ? null
        : ((bpm - _calmBpm) / (_drivingBpm - _calmBpm)).clamp(0.0, 1.0);
    if (fromTempo != null && fromGenre != null) {
      return 0.7 * fromTempo + 0.3 * fromGenre;
    }
    return fromTempo ?? fromGenre ?? _unknownAffinity;
  }

  static bool _hasEnergyTags(ImportedTrack track) {
    final bpm = track.bpm;
    return (bpm != null && bpm.isFinite && bpm > 0) ||
        _normalizeGenre(track.genre) != null;
  }

  /// Prefer neighboring picks with compatible tagged tempos.
  static double _tempoAffinity(double? first, double? second) {
    if (first == null || second == null || first <= 0 || second <= 0) {
      return _unknownAffinity;
    }
    final ratio = first > second ? first / second : second / first;
    if (ratio <= 1.06) return 1;
    if (ratio <= 1.12) return 0.7;
    if ((ratio - 1.5).abs() <= 0.12) return 0.55;
    if ((ratio - 2).abs() <= 0.16) return 0.6;
    return 0.05;
  }

  static double _genreAffinity(String? first, String? second) {
    final a = _normalizeGenre(first);
    final b = _normalizeGenre(second);
    if (a == null || b == null) return _unknownAffinity;
    if (a == b) return 1;
    final familyA = _genreFamily(a);
    if (familyA != null && familyA == _genreFamily(b)) return 0.7;
    return 0.1;
  }

  static double _mixCompatibilityScore(
    ImportedTrack previous,
    ImportedTrack next,
  ) {
    final tempo = _tempoAffinity(previous.bpm, next.bpm);
    final genre = _genreAffinity(previous.genre, next.genre);
    return (tempo * 0.6 + genre * 0.4).clamp(0.0, 1.0);
  }

  static double _freshness(
    ImportedTrack candidate,
    ImportedTrack? previous,
    Map<String, int> artistUse,
    Map<String, int> albumUse,
  ) {
    var score = 1.0;
    final artist = _artistKey(candidate);
    final album = _albumKey(candidate);
    if (previous != null) {
      if (artist != null && artist == _artistKey(previous)) score -= 0.55;
      if (album != null && album == _albumKey(previous)) score -= 0.35;
    }
    final repeats = artist == null ? 0 : artistUse[artist] ?? 0;
    if (repeats >= 2) score -= 0.25;
    if (repeats >= 3) score -= 0.25;
    if (album != null && (albumUse[album] ?? 0) >= 1) score -= 0.2;
    return score.clamp(0.0, 1.0);
  }

  /// The plain-language reason shown under each song.
  static String _reason({
    required ImportedTrack? previous,
    required ImportedTrack next,
    required bool isFavorite,
    required Map<String, double> energies,
  }) {
    if (previous != null) {
      final compatibility = _compatibilityReason(previous, next);
      if (compatibility != null) return compatibility;
      if (_hasEnergyTags(previous) && _hasEnergyTags(next)) {
        final shift = energies[next.id]! - energies[previous.id]!;
        if (shift >= _energyShift) return 'Lifts the energy';
        if (shift <= -_energyShift) return 'Eases the energy down';
      }
    }
    return isFavorite
        ? 'A favorite you saved'
        : 'A different track from your library';
  }

  static String? _compatibilityReason(
    ImportedTrack previous,
    ImportedTrack next,
  ) {
    final sameGenre = _sameGenre(previous.genre, next.genre);
    final tempoMatch = _tempoMatches(previous.bpm, next.bpm);
    if (sameGenre && tempoMatch) return 'Similar genre and tempo';
    if (sameGenre) return 'Same genre';
    if (tempoMatch) return 'Compatible tempo';
    return null;
  }

  static bool _sameGenre(String? first, String? second) {
    final a = _normalizeGenre(first);
    return a != null && a == _normalizeGenre(second);
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

  static String? _normalizeGenre(String? genre) {
    final value = genre?.trim().toLowerCase();
    return value == null || value.isEmpty ? null : value;
  }

  /// A performer's name, or `null` for the "Unknown artist" placeholder so
  /// unrelated untagged tracks are never treated as one act.
  static String? _artistKey(ImportedTrack track) {
    final name = displayArtistName(track.artist, fallback: '').trim();
    return name.isEmpty ? null : name.toLowerCase();
  }

  static String? _albumKey(ImportedTrack track) {
    final value = track.album.trim().toLowerCase();
    return value.isEmpty || value == 'unknown album' ? null : value;
  }

  /// Genre keywords mapped to a rough energy, longest key first so "k-pop"
  /// never reads as plain "pop".
  static const _genreEnergyTable = <String, double>{
    'ambient': 0.12,
    'classical': 0.22,
    'folk': 0.28,
    'acoustic': 0.3,
    'jazz': 0.38,
    'blues': 0.4,
    'soul': 0.45,
    'r&b': 0.52,
    'rnb': 0.52,
    'hip hop': 0.62,
    'hip-hop': 0.62,
    'reggae': 0.55,
    'country': 0.45,
    'gospel': 0.5,
    'indie': 0.55,
    'pop': 0.6,
    'synth': 0.6,
    'rap': 0.62,
    'afrobeats': 0.66,
    'afrobeat': 0.66,
    'funk': 0.68,
    'disco': 0.7,
    'trap': 0.7,
    'house': 0.72,
    'latin': 0.72,
    'rock': 0.76,
    'electronic': 0.78,
    'techno': 0.82,
    'dance': 0.82,
    'punk': 0.85,
    'edm': 0.88,
    'metal': 0.95,
  };

  static double? _genreEnergy(String? genre) {
    final value = _normalizeGenre(genre);
    if (value == null) return null;
    String? matched;
    double? energy;
    for (final entry in _genreEnergyTable.entries) {
      if (!value.contains(entry.key)) continue;
      if (matched == null || entry.key.length > matched.length) {
        matched = entry.key;
        energy = entry.value;
      }
    }
    return energy;
  }

  /// Genres with related listening characteristics.
  static const _genreFamilies = <String, String>{
    'house': 'electronic',
    'techno': 'electronic',
    'trance': 'electronic',
    'electro': 'electronic',
    'edm': 'electronic',
    'dance': 'electronic',
    'dubstep': 'electronic',
    'synth': 'electronic',
    'electronic': 'electronic',
    'hip hop': 'urban',
    'hip-hop': 'urban',
    'rap': 'urban',
    'trap': 'urban',
    'r&b': 'urban',
    'rnb': 'urban',
    'afrobeats': 'urban',
    'afrobeat': 'urban',
    'soul': 'urban',
    'funk': 'urban',
    'rock': 'rock',
    'alternative': 'rock',
    'indie': 'rock',
    'metal': 'rock',
    'punk': 'rock',
    'folk': 'roots',
    'country': 'roots',
    'blues': 'roots',
    'gospel': 'roots',
    'reggae': 'roots',
    'latin': 'roots',
    'ambient': 'calm',
    'classical': 'calm',
    'acoustic': 'calm',
    'jazz': 'calm',
    'lo-fi': 'calm',
    'lofi': 'calm',
  };

  static String? _genreFamily(String genre) {
    String? matched;
    String? family;
    for (final entry in _genreFamilies.entries) {
      if (!genre.contains(entry.key)) continue;
      if (matched == null || entry.key.length > matched.length) {
        matched = entry.key;
        family = entry.value;
      }
    }
    return family;
  }
}
