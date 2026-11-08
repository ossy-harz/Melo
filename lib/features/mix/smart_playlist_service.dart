import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:melo_player/features/library/imported_track.dart';
import 'package:melo_player/features/library/music_library.dart';
import 'package:melo_player/features/library/music_playlist.dart';
import 'package:melo_player/features/mix/local_discovery.dart';
import 'package:melo_player/features/youtube/youtube_audio_service.dart';
import 'package:melo_player/features/youtube/youtube_auth_service.dart';

enum SmartVibe {
  dailyFlow,
  highEnergy,
  deepFocus,
  lateNightChill,
}

class SmartPlaylist {
  const SmartPlaylist({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.tracks,
    required this.isContinuous,
    this.artworkUri,
    this.seedArtist,
    this.seedGenre,
  });

  final String id;
  final String title;
  final String subtitle;
  final List<MediaItem> tracks;
  final bool isContinuous;
  final String? artworkUri;
  final String? seedArtist;
  final String? seedGenre;
}

class SmartPlaylistService {
  SmartPlaylistService._();
  static final SmartPlaylistService instance = SmartPlaylistService._();

  bool _continuousAutoplay = true;
  bool get isContinuousAutoplayEnabled => _continuousAutoplay;

  Future<void> setContinuousAutoplayEnabled(bool enabled) async {
    _continuousAutoplay = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tone_continuous_autoplay', enabled);
  }

  /// Generates an infinite smart radio playlist starting from a specific seed track.
  Future<SmartPlaylist> generateTrackRadio({
    required MediaItem seedTrack,
    MusicLibrary? library,
  }) async {
    final title = '${seedTrack.title} Radio';
    final artist = seedTrack.artist ?? 'Artist';
    final subtitle = 'Continuous stream based on $artist';
    final queueTracks = <MediaItem>[seedTrack];
    final seenIds = <String>{seedTrack.id};

    // 1. Add matching local tracks from the same artist/genre if available
    if (library != null) {
      final localTracks = library.tracks;
      final matchingLocal = localTracks.where((t) {
        if (!t.isAvailable) return false;
        final isArtistMatch = t.artist.trim().toLowerCase() == artist.trim().toLowerCase();
        final isGenreMatch = seedTrack.genre != null &&
            t.genre != null &&
            t.genre!.toLowerCase() == seedTrack.genre!.toLowerCase();
        return isArtistMatch || isGenreMatch;
      }).toList();

      for (final track in matchingLocal) {
        final mediaItem = track.toMediaItem();
        if (!seenIds.contains(mediaItem.id)) {
          seenIds.add(mediaItem.id);
          queueTracks.add(mediaItem);
        }
        if (queueTracks.length >= 6) break;
      }
    }

    // 2. Fetch streaming recommendations from YouTube/Invidious
    final videoId = seedTrack.extras?['providerTrackId'] as String? ??
        (seedTrack.id.startsWith('youtube:') ? seedTrack.id.substring(8) : 'dQw4w9WgXcQ');

    try {
      final related = await YoutubeAudioService.instance.getRelatedTracks(
        videoId,
        artist: artist,
        title: seedTrack.title,
      );

      for (final ytTrack in related) {
        final mediaItem = ytTrack.toMediaItem();
        if (!seenIds.contains(mediaItem.id)) {
          seenIds.add(mediaItem.id);
          queueTracks.add(mediaItem);
        }
      }
    } catch (e) {
      debugPrint('Error generating track radio recommendations: $e');
    }

    return SmartPlaylist(
      id: 'radio:${seedTrack.id}',
      title: title,
      subtitle: subtitle,
      tracks: queueTracks,
      isContinuous: true,
      artworkUri: seedTrack.artUri?.toString(),
      seedArtist: artist,
    );
  }

  /// Generates an artist radio with top tracks and similar artist continuous streaming.
  Future<SmartPlaylist> generateArtistRadio({
    required String artist,
    MusicLibrary? library,
    String? artworkUri,
  }) async {
    final cleanArtist = artist.trim();
    final queueTracks = <MediaItem>[];
    final seenIds = <String>{};

    // 1. Local tracks by this artist
    if (library != null) {
      final localArtistTracks = LocalDiscovery.artistRadio(
        library.tracks,
        cleanArtist,
        favoriteTrackIds: library.favoriteTracks.map((t) => t.id).toSet(),
      );
      for (final t in localArtistTracks) {
        final item = t.toMediaItem();
        if (!seenIds.contains(item.id)) {
          seenIds.add(item.id);
          queueTracks.add(item);
        }
      }
    }

    // 2. Streamed tracks for this artist
    try {
      final ytResults = await YoutubeAudioService.instance.search('$cleanArtist best songs');
      for (final t in ytResults) {
        final item = t.toMediaItem();
        if (!seenIds.contains(item.id)) {
          seenIds.add(item.id);
          queueTracks.add(item);
        }
        if (queueTracks.length >= 25) break;
      }
    } catch (e) {
      debugPrint('Error fetching artist radio online tracks: $e');
    }

    return SmartPlaylist(
      id: 'artist_radio:$cleanArtist',
      title: '$cleanArtist Radio',
      subtitle: 'Endless artist mix & similar sounds',
      tracks: queueTracks,
      isContinuous: true,
      artworkUri: artworkUri ?? (queueTracks.isNotEmpty ? queueTracks.first.artUri?.toString() : null),
      seedArtist: cleanArtist,
    );
  }

  /// Generates dynamic Smart Vibe Mixes.
  Future<SmartPlaylist> generateVibeMix({
    required SmartVibe vibe,
    MusicLibrary? library,
  }) async {
    final queueTracks = <MediaItem>[];
    final seenIds = <String>{};

    String title;
    String subtitle;
    String searchQuery;

    switch (vibe) {
      case SmartVibe.dailyFlow:
        title = 'My Daily Flow';
        subtitle = 'Your favorites blended with smart discoveries';
        searchQuery = 'popular hits music mix';
        break;
      case SmartVibe.highEnergy:
        title = 'High Energy Workout';
        subtitle = 'Driving rhythms & high tempo beats';
        searchQuery = 'high energy workout motivational music';
        break;
      case SmartVibe.deepFocus:
        title = 'Deep Focus & Study';
        subtitle = 'Calm instrumental & lofi beats';
        searchQuery = 'lofi hip hop radio beats to relax study to';
        break;
      case SmartVibe.lateNightChill:
        title = 'Late Night Chill';
        subtitle = 'Mellow acoustic & atmospheric vibes';
        searchQuery = 'chill acoustic late night music';
        break;
    }

    // 1. Gather personalized and local favorites
    if (vibe == SmartVibe.dailyFlow) {
      try {
        final tasteTracks = await YoutubeAuthService.instance.getPersonalTasteTracks();
        for (final t in tasteTracks) {
          final item = t.toMediaItem();
          if (!seenIds.contains(item.id)) {
            seenIds.add(item.id);
            queueTracks.add(item);
          }
        }
      } catch (_) {}

      if (library != null && library.tracks.isNotEmpty) {
        final favorites = library.tracks.where((t) => library.isFavorite(t.id)).toList();
        favorites.shuffle();
        for (final t in favorites.take(10)) {
          final item = t.toMediaItem();
          if (!seenIds.contains(item.id)) {
            seenIds.add(item.id);
            queueTracks.add(item);
          }
        }
      }
    }

    // 2. Fetch curated vibe tracks online
    try {
      final results = await YoutubeAudioService.instance.search(searchQuery);
      for (final t in results) {
        final item = t.toMediaItem();
        if (!seenIds.contains(item.id)) {
          seenIds.add(item.id);
          queueTracks.add(item);
        }
        if (queueTracks.length >= 25) break;
      }
    } catch (e) {
      debugPrint('Error fetching vibe mix tracks: $e');
    }

    return SmartPlaylist(
      id: 'vibe:${vibe.name}',
      title: title,
      subtitle: subtitle,
      tracks: queueTracks,
      isContinuous: true,
      artworkUri: queueTracks.isNotEmpty ? queueTracks.first.artUri?.toString() : null,
    );
  }

  /// Plays a smart playlist on Tone's audio handler with continuous queue active.
  Future<void> playSmartPlaylist({
    required AudioHandler audioHandler,
    required SmartPlaylist playlist,
  }) async {
    if (playlist.tracks.isEmpty) return;

    // Enable continuous autoplay so the radio never stops
    try {
      await audioHandler.customAction('autoplay.set', {'enabled': true});
    } catch (_) {}

    // Replace current queue and start playing
    await audioHandler.updateQueue(playlist.tracks);
    await audioHandler.playMediaItem(playlist.tracks.first);
  }

  /// Saves the current Smart Playlist into Tone's local playlists.
  Future<MusicPlaylist?> saveToLibrary({
    required SmartPlaylist playlist,
    required MusicLibrary library,
  }) async {
    if (playlist.tracks.isEmpty) return null;

    final created = await library.createPlaylist(playlist.title);
    final importedTracks = playlist.tracks.map((item) {
      final rawId = item.extras?['providerTrackId'] as String? ?? item.id;
      return ImportedTrack(
        id: item.id,
        path: item.id,
        title: item.title,
        artist: item.artist ?? 'Tone Artist',
        album: item.album ?? playlist.title,
        durationMs: item.duration?.inMilliseconds ?? 180000,
        artworkUri: item.artUri?.toString(),
        sourceProvider: item.id.startsWith('youtube:') ? 'YouTube' : 'SmartRadio',
        providerTrackId: rawId,
        isAvailable: true,
      );
    }).toList();

    await library.importExternalTracks(importedTracks);
    await library.addTracksToPlaylist(
      created.id,
      importedTracks.map((t) => t.id),
    );

    return created;
  }
}
