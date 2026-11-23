import 'dart:async';
import 'dart:math' as math;
import 'package:melo_player/features/library/imported_track.dart';
import 'package:melo_player/features/library/music_library.dart';

class ArtistPlayStat {
  const ArtistPlayStat({
    required this.artist,
    required this.playCount,
    required this.percentage,
  });

  final String artist;
  final int playCount;
  final double percentage;
}

enum ListeningVibe {
  morning('Morning Sun', 'Acoustic & Uplifting'),
  afternoon('Daytime Flow', 'Focus & Rhythmic'),
  evening('Sunset Groove', 'Chill & Soulful'),
  nightOwl('Night Owl', 'Late Night Nocturne');

  const ListeningVibe(this.title, this.subtitle);
  final String title;
  final String subtitle;
}

class MeloInsightsReport {
  const MeloInsightsReport({
    required this.totalPlays,
    required this.totalListeningMinutes,
    required this.topArtists,
    required this.topTracks,
    required this.forgottenGems,
    required this.topGenres,
    required this.dominantVibe,
  });

  final int totalPlays;
  final int totalListeningMinutes;
  final List<ArtistPlayStat> topArtists;
  final List<ImportedTrack> topTracks;
  final List<ImportedTrack> forgottenGems;
  final List<String> topGenres;
  final ListeningVibe dominantVibe;
}

class MeloInsightsService {
  MeloInsightsService._();
  static final MeloInsightsService instance = MeloInsightsService._();

  Future<MeloInsightsReport> generateReport({MusicLibrary? library}) async {
    if (library == null) {
      return const MeloInsightsReport(
        totalPlays: 0,
        totalListeningMinutes: 0,
        topArtists: [],
        topTracks: [],
        forgottenGems: [],
        topGenres: [],
        dominantVibe: ListeningVibe.afternoon,
      );
    }
    final totalDbCount = await library.totalPlaybackCount();
    // Retrieve up to 1000 history entries for detailed breakdown
    final history = await library.listeningHistory(limit: 1000);
    final mostPlayed = await library.mostPlayedTracks(limit: 30);
    final allTracks = library.tracks;

    if (history.isEmpty && mostPlayed.isEmpty && allTracks.isEmpty) {
      return const MeloInsightsReport(
        totalPlays: 0,
        totalListeningMinutes: 0,
        topArtists: [],
        topTracks: [],
        forgottenGems: [],
        topGenres: [],
        dominantVibe: ListeningVibe.afternoon,
      );
    }

    final totalPlays = math.max(totalDbCount, history.length);

    // Calculate listening minutes using actual listenedMs where recorded,
    // or capped completed playback to prevent 30s listens counting as 5m
    var totalSeconds = 0;
    final trackById = {for (final t in allTracks) t.id: t};

    for (final entry in history) {
      if (entry.listenedMs > 0) {
        totalSeconds += (entry.listenedMs / 1000).round();
      } else if (entry.completed) {
        final t = trackById[entry.trackId];
        if (t?.durationMs != null && t!.durationMs! > 0) {
          totalSeconds += (t.durationMs! / 1000).round();
        } else {
          totalSeconds += 180; // 3 min standard
        }
      } else {
        // Partial listen without exact duration recorded: conservative 45s estimate
        totalSeconds += 45;
      }
    }
    final totalMinutes = (totalSeconds / 60).round();

    // Top Artists
    final artistCounts = <String, int>{};
    for (final entry in history) {
      final a = entry.artist.trim();
      if (a.isNotEmpty && a.toLowerCase() != 'unknown artist') {
        artistCounts[a] = (artistCounts[a] ?? 0) + 1;
      }
    }
    final sortedArtists = artistCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topArtists = sortedArtists.take(5).map((e) {
      final pct = totalPlays > 0 ? (e.value / totalPlays) : 0.0;
      return ArtistPlayStat(
        artist: e.key,
        playCount: e.value,
        percentage: pct,
      );
    }).toList();

    // Top Tracks (mapped to actual ImportedTrack)
    final topTracks = <ImportedTrack>[];
    for (final mp in mostPlayed) {
      final track = trackById[mp.track.id] ?? mp.track;
      topTracks.add(track);
    }

    // Forgotten Gems: tracks actually played in the past (>7 days ago) or favorited,
    // but not played in the most recent 25 sessions. Never injects never-played songs.
    final recentPlayedIds = history.take(25).map((e) => e.trackId).toSet();
    final now = DateTime.now();
    final forgottenGems = <ImportedTrack>[];

    for (final entry in history.reversed) {
      if (!recentPlayedIds.contains(entry.trackId)) {
        final age = now.difference(entry.playedAt).inDays;
        if (age >= 7) {
          final t = trackById[entry.trackId];
          if (t != null && !forgottenGems.any((existing) => existing.id == t.id)) {
            forgottenGems.add(t);
            if (forgottenGems.length >= 20) break;
          }
        }
      }
    }

    // Top Genres
    final genreCounts = <String, int>{};
    for (final t in allTracks) {
      final g = t.genre?.trim();
      if (g != null && g.isNotEmpty && g.toLowerCase() != 'unknown genre') {
        genreCounts[g] = (genreCounts[g] ?? 0) + 1;
      }
    }
    final topGenres = (genreCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(4)
        .map((e) => e.key)
        .toList();

    // Dominant Time-of-day Vibe
    final hourCounts = <int, int>{};
    for (final entry in history) {
      final h = entry.playedAt.hour;
      hourCounts[h] = (hourCounts[h] ?? 0) + 1;
    }
    var morning = 0; // 5 - 11
    var afternoon = 0; // 12 - 16
    var evening = 0; // 17 - 21
    var night = 0; // 22 - 4

    for (final e in hourCounts.entries) {
      final h = e.key;
      if (h >= 5 && h < 12) {
        morning += e.value;
      } else if (h >= 12 && h < 17) {
        afternoon += e.value;
      } else if (h >= 17 && h < 22) {
        evening += e.value;
      } else {
        night += e.value;
      }
    }

    var dominantVibe = ListeningVibe.evening;
    var maxVal = evening;
    if (morning > maxVal) {
      maxVal = morning;
      dominantVibe = ListeningVibe.morning;
    }
    if (afternoon > maxVal) {
      maxVal = afternoon;
      dominantVibe = ListeningVibe.afternoon;
    }
    if (night > maxVal) {
      dominantVibe = ListeningVibe.nightOwl;
    }

    return MeloInsightsReport(
      totalPlays: totalPlays,
      totalListeningMinutes: totalMinutes,
      topArtists: topArtists,
      topTracks: topTracks,
      forgottenGems: forgottenGems,
      topGenres: topGenres,
      dominantVibe: dominantVibe,
    );
  }
}
