import 'dart:math' as math;
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:melo_player/features/library/imported_track.dart';
import 'package:melo_player/features/library/music_library.dart';
import 'package:melo_player/features/mix/smart_playlist_service.dart';
import 'package:melo_player/features/youtube/youtube_audio_service.dart';

enum ListeningMood {
  chill(
    title: 'Chill',
    subtitle: 'Mellow grooves & acoustic calm',
    icon: Icons.spa_rounded,
    minBpm: 60,
    maxBpm: 98,
    genres: ['R&B & Soul', 'Lo-Fi', 'Acoustic', 'Chill', 'Ambient'],
    searchFallback: 'Chill acoustic relaxing songs official audio',
  ),
  focus(
    title: 'Focus',
    subtitle: 'Instrumental flow & study rhythms',
    icon: Icons.psychology_rounded,
    minBpm: 75,
    maxBpm: 115,
    genres: ['Electronic & Dance', 'Lo-Fi', 'Instrumental', 'Ambient'],
    searchFallback: 'Deep focus study beats instrumental official audio',
  ),
  workout(
    title: 'Workout',
    subtitle: 'High-energy driving tempo',
    icon: Icons.fitness_center_rounded,
    minBpm: 125,
    maxBpm: 158,
    genres: ['Hip-Hop & Rap', 'Afrobeats', 'Electronic & Dance', 'Rock'],
    searchFallback: 'High energy workout motivation songs official audio',
  ),
  party(
    title: 'Party',
    subtitle: 'Club anthems & dancefloor bangers',
    icon: Icons.celebration_rounded,
    minBpm: 118,
    maxBpm: 135,
    genres: ['Dancehall', 'Afrobeats', 'Amapiano', 'Electronic & Dance'],
    searchFallback: 'Party dance hits club mix official audio',
  ),
  driving(
    title: 'Driving',
    subtitle: 'Open road melodies & momentum',
    icon: Icons.directions_car_rounded,
    minBpm: 95,
    maxBpm: 128,
    genres: ['Rock', 'Pop', 'Hip-Hop & Rap', 'Kenyan & Bongo'],
    searchFallback: 'Road trip driving songs energetic official audio',
  ),
  lateNight(
    title: 'Late Night',
    subtitle: 'Nocturnal soul & moody vibes',
    icon: Icons.bedtime_rounded,
    minBpm: 60,
    maxBpm: 95,
    genres: ['R&B & Soul', 'Lo-Fi', 'Dancehall'],
    searchFallback: 'Late night slow jams R&B soulful official audio',
  );

  const ListeningMood({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.minBpm,
    required this.maxBpm,
    required this.genres,
    required this.searchFallback,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final double minBpm;
  final double maxBpm;
  final List<String> genres;
  final String searchFallback;
}

class MoodSessionService {
  MoodSessionService._();
  static final MoodSessionService instance = MoodSessionService._();

  /// Checks if a track's BPM matches the mood or its harmonic half/double-time groove.
  static bool isBpmCompatible(double bpm, ListeningMood mood) {
    if (bpm <= 0) return true;
    if (bpm >= mood.minBpm && bpm <= mood.maxBpm) return true;
    // For energetic workout and party sessions, require actual fast tempo (not slow ballads)
    if (mood == ListeningMood.workout || mood == ListeningMood.party) {
      return false;
    }
    // For mellow chill/focus/late-night, allow harmonic double-time (e.g. 160 bpm groove felt at 80 bpm)
    final halfTime = bpm / 2;
    if (halfTime >= mood.minBpm && halfTime <= mood.maxBpm) return true;
    return false;
  }

  /// Calculates a suitability energy score for a track matching the specified mood.
  /// Returns -1 if the track is disqualified due to tempo or tone incompatibility.
  static double scoreTrackForMood({
    required ImportedTrack track,
    required ListeningMood mood,
    Set<String> recentTrackIds = const {},
  }) {
    if (recentTrackIds.contains(track.id)) return -1;

    final genre = track.genre?.toLowerCase() ?? '';
    final title = track.title.toLowerCase();
    final genreMatches = mood.genres.any((g) => genre.contains(g.toLowerCase()));

    // Strict BPM boundary verification when tempo is tagged
    if (track.bpm != null && track.bpm! > 0) {
      if (!isBpmCompatible(track.bpm!, mood)) {
        return -1; // Disqualified by tempo
      }
    } else {
      // Fallback heuristics when BPM is untagged:
      if (mood == ListeningMood.workout || mood == ListeningMood.party) {
        if (title.contains('slow') ||
            title.contains('acoustic') ||
            title.contains('lullaby') ||
            title.contains('ambient') ||
            title.contains('relaxing')) {
          return -1; // Disqualify calm songs from energetic sessions
        }
      }
      if (mood == ListeningMood.chill || mood == ListeningMood.lateNight) {
        if (title.contains('workout') ||
            title.contains('club mix') ||
            title.contains('rave') ||
            title.contains('party edit')) {
          return -1;
        }
      }
    }

    if (!genreMatches && (track.bpm == null || track.bpm! <= 0)) {
      return -1;
    }

    var score = 10.0;
    if (genreMatches) score += 35.0;
    if (track.bpm != null && track.bpm! >= mood.minBpm && track.bpm! <= mood.maxBpm) {
      score += 45.0;
      final mid = (mood.minBpm + mood.maxBpm) / 2;
      final dist = (track.bpm! - mid).abs();
      score += math.max(0.0, 10.0 - (dist / 3));
    }

    return score;
  }

  /// Generates a tailored mood session blending local library tracks with verified catalog streams.
  Future<SmartPlaylist> generateMoodSession({
    required ListeningMood mood,
    MusicLibrary? library,
  }) async {
    final sessionTracks = <MediaItem>[];
    final seenIds = <String>{};

    // 1. Gather local matching tracks by BPM tempo range and genre suitability
    if (library != null && library.tracks.isNotEmpty) {
      final history = await library.listeningHistory(limit: 15);
      final recentIds = history.map((e) => e.trackId).toSet();
      final scoredLocal = <(ImportedTrack, double)>[];

      for (final t in library.tracks) {
        if (!t.isAvailable) continue;
        final score = scoreTrackForMood(
          track: t,
          mood: mood,
          recentTrackIds: recentIds,
        );
        if (score > 0) {
          scoredLocal.add((t, score));
        }
      }

      // Sort descending by suitability score
      scoredLocal.sort((a, b) => b.$2.compareTo(a.$2));

      for (final item in scoredLocal.take(12)) {
        if (seenIds.add(item.$1.id)) {
          sessionTracks.add(item.$1.toMediaItem());
        }
      }
    }

    // 2. Supplement with high-quality streaming catalog tracks for continuous flow
    try {
      final ytHits = await YoutubeAudioService.instance.search(
        mood.searchFallback,
        filterMixtapes: true,
      );

      for (final hit in ytHits.take(15)) {
        final id = 'youtube:${hit.id}';
        if (seenIds.add(id)) {
          sessionTracks.add(
            MediaItem(
              id: id,
              title: hit.title,
              artist: hit.author,
              album: '${mood.title} Session',
              duration: hit.duration,
              artUri: hit.thumbnailUrl != null ? Uri.tryParse(hit.thumbnailUrl!) : null,
              extras: {
                'source': 'youtube',
                'downloadProvider': 'YouTube',
                'genre': mood.genres.first,
              },
            ),
          );
        }
      }
    } catch (_) {}

    return SmartPlaylist(
      id: 'mood:${mood.name}',
      title: '${mood.title} Vibe',
      subtitle: mood.subtitle,
      tracks: sessionTracks,
      isContinuous: true,
      seedGenre: mood.genres.first,
    );
  }
}
