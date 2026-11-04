import 'dart:math';

import 'package:tone_player/features/library/imported_track.dart';

class MixPick {
  const MixPick({required this.track, required this.reason});

  final ImportedTrack track;
  final String reason;
}

class PersonalMixGenerator {
  const PersonalMixGenerator._();

  static const maxTracks = 50;

  static List<MixPick> generate({
    required Iterable<ImportedTrack> tracks,
    required Set<String> favoriteTrackIds,
    required Set<String> excludedTrackIds,
    required Duration targetDuration,
    required double discovery,
    int? randomSeed,
  }) {
    final familiar = <ImportedTrack>[];
    final other = <ImportedTrack>[];
    for (final track in tracks) {
      if (excludedTrackIds.contains(track.id) ||
          track.durationMs == null ||
          track.durationMs! <= 0) {
        continue;
      }
      (favoriteTrackIds.contains(track.id) ? familiar : other).add(track);
    }

    final random = Random(randomSeed);
    familiar.shuffle(random);
    other.shuffle(random);
    final familiarity = discovery.clamp(0.0, 1.0);
    final candidates = <ImportedTrack>[];
    while (familiar.isNotEmpty || other.isNotEmpty) {
      final preferOther = random.nextDouble() < familiarity;
      final preferred = preferOther ? other : familiar;
      final fallback = preferOther ? familiar : other;
      candidates.add(
        (preferred.isNotEmpty ? preferred : fallback).removeLast(),
      );
    }

    final picks = <MixPick>[];
    var duration = Duration.zero;
    ImportedTrack? previous;
    while (candidates.isNotEmpty && picks.length < maxTracks) {
      final fitting = candidates
          .where(
            (track) =>
                duration + Duration(milliseconds: track.durationMs!) <=
                targetDuration,
          )
          .toList(growable: false);
      if (fitting.isEmpty) break;

      ImportedTrack? flowing;
      if (previous != null) {
        for (final candidate in fitting) {
          if (_isGoodTransition(previous, candidate)) {
            flowing = candidate;
            break;
          }
        }
      }
      final track = flowing ?? fitting.first;
      candidates.remove(track);
      final trackDuration = Duration(milliseconds: track.durationMs!);
      final transition = previous == null
          ? null
          : _transitionReason(previous, track);
      picks.add(
        MixPick(
          track: track,
          reason:
              transition ??
              (favoriteTrackIds.contains(track.id)
                  ? 'A favorite you saved'
                  : 'A different track from your library'),
        ),
      );
      duration += trackDuration;
      previous = track;
    }
    return List.unmodifiable(picks);
  }

  static bool _isGoodTransition(ImportedTrack previous, ImportedTrack next) =>
      _transitionReason(previous, next) != null;

  static String? _transitionReason(ImportedTrack previous, ImportedTrack next) {
    final sameGenre =
        previous.genre != null &&
        next.genre != null &&
        previous.genre!.trim().isNotEmpty &&
        previous.genre!.trim().toLowerCase() ==
            next.genre!.trim().toLowerCase();
    final tempoMatch = _tempoMatches(previous.bpm, next.bpm);
    if (sameGenre && tempoMatch) return 'DJ flow · matching genre and tempo';
    if (sameGenre) return 'DJ flow · same genre';
    if (tempoMatch) return 'DJ flow · compatible tempo';
    return null;
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
