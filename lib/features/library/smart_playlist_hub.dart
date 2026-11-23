import 'package:flutter/material.dart';
import 'package:melo_player/features/library/imported_track.dart';
import 'package:melo_player/features/library/music_library.dart';

enum SmartPlaylistType {
  heavyRotation(
    title: 'Heavy Rotation',
    subtitle: 'Your most-played tracks',
    icon: Icons.repeat_on_rounded,
    color: Color(0xFFE52D27),
  ),
  forgottenGems(
    title: 'Forgotten Gems',
    subtitle: 'Loved tracks waiting to be re-discovered',
    icon: Icons.diamond_rounded,
    color: Color(0xFF673AB7),
  ),
  recentlyAdded(
    title: 'Recently Added',
    subtitle: 'Newest additions to your collection',
    icon: Icons.new_releases_rounded,
    color: Color(0xFF009688),
  ),
  audiophileHiRes(
    title: 'Lossless & Studio',
    subtitle: 'FLAC, ALAC, WAV & hi-res audio files',
    icon: Icons.high_quality_rounded,
    color: Color(0xFFFF9800),
  ),
  neverPlayed(
    title: 'Never Played',
    subtitle: 'Unopened gems in your library',
    icon: Icons.explore_rounded,
    color: Color(0xFF2196F3),
  );

  const SmartPlaylistType({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
}

class SmartPlaylistHub {
  SmartPlaylistHub._();

  static Future<List<ImportedTrack>> resolveTracks({
    required SmartPlaylistType type,
    required MusicLibrary library,
  }) async {
    final all = library.tracks.where((t) => t.isAvailable).toList();
    switch (type) {
      case SmartPlaylistType.recentlyAdded:
        // Reverse order of added tracks
        return all.reversed.take(40).toList();

      case SmartPlaylistType.audiophileHiRes:
        return all.where((t) {
          final path = t.path.toLowerCase();
          final src = (t.sourceName ?? '').toLowerCase();
          final isFlacOrWavOrAiff = path.endsWith('.flac') ||
              path.endsWith('.wav') ||
              path.endsWith('.aiff') ||
              path.endsWith('.dsd') ||
              path.endsWith('.dff');
          // Common ALAC files use .m4a container with ALAC codec tag
          final isAlac = path.endsWith('.alac') ||
              (path.endsWith('.m4a') && (src.contains('alac') || src.contains('lossless')));
          final isExplicitLossless = src.contains('24bit') ||
              src.contains('24-bit') ||
              src.contains('96khz') ||
              src.contains('192khz') ||
              src.contains('lossless') ||
              src.contains('flac');
          return isFlacOrWavOrAiff || isAlac || isExplicitLossless;
        }).take(40).toList();

      case SmartPlaylistType.neverPlayed:
        final history = await library.listeningHistory(limit: 500);
        final playedIds = history.map((e) => e.trackId).toSet();
        return all.where((t) => !playedIds.contains(t.id)).take(40).toList();

      case SmartPlaylistType.heavyRotation:
        final mostPlayed = await library.mostPlayedTracks(limit: 40);
        if (mostPlayed.isEmpty) return const <ImportedTrack>[];
        final trackMap = {for (final t in all) t.id: t};
        final result = <ImportedTrack>[];
        for (final item in mostPlayed) {
          final t = trackMap[item.track.id] ?? item.track;
          result.add(t);
        }
        return result;

      case SmartPlaylistType.forgottenGems:
        final history = await library.listeningHistory(limit: 500);
        if (history.isEmpty && library.favoriteTracks.isEmpty) {
          return const <ImportedTrack>[];
        }
        final recentPlayed = history.take(25).map((e) => e.trackId).toSet();
        final historicalPlayed = history.skip(25).map((e) => e.trackId).toSet();
        final favIds = library.favoriteTracks.map((t) => t.id).toSet();
        final gems = all.where((t) {
          final wasEnjoyed = historicalPlayed.contains(t.id) || favIds.contains(t.id);
          return wasEnjoyed && !recentPlayed.contains(t.id);
        }).toList();
        return gems.take(30).toList();
    }
  }
}
