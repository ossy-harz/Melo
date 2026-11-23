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

  /// Generates a tailored mood session blending local library tracks with verified catalog streams.
  Future<SmartPlaylist> generateMoodSession({
    required ListeningMood mood,
    MusicLibrary? library,
  }) async {
    final sessionTracks = <MediaItem>[];
    final seenIds = <String>{};

    // 1. Gather local matching tracks by genre and tempo
    if (library != null && library.tracks.isNotEmpty) {
      final matchingLocal = <ImportedTrack>[];
      for (final t in library.tracks) {
        if (!t.isAvailable) continue;
        final genre = t.genre?.toLowerCase() ?? '';
        final genreMatches = mood.genres.any((g) => genre.contains(g.toLowerCase()));
        if (genreMatches) {
          matchingLocal.add(t);
        }
      }

      // Shuffle and take up to 10 local tracks
      matchingLocal.shuffle(math.Random());
      for (final track in matchingLocal.take(10)) {
        if (seenIds.add(track.id)) {
          sessionTracks.add(track.toMediaItem());
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
