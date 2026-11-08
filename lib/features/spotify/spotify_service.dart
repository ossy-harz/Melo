import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotify/spotify.dart' as sp;
import 'package:melo_player/features/library/imported_track.dart';
import 'package:melo_player/features/library/music_library.dart';
import 'package:melo_player/features/library/music_playlist.dart';

class SpotifyTrack {
  const SpotifyTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationMs,
    this.artworkUrl,
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final int durationMs;
  final String? artworkUrl;

  String get durationString {
    final dur = Duration(milliseconds: durationMs);
    final minutes = dur.inMinutes;
    final seconds = (dur.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  ImportedTrack toImportedTrack() => ImportedTrack(
    id: 'spotify:$id',
    path: 'spotify:$id',
    title: title,
    artist: artist,
    album: album,
    durationMs: durationMs,
    artworkUri: artworkUrl,
    sourceProvider: 'Spotify',
    providerTrackId: id,
    isAvailable: true,
  );
}

class SpotifyPlaylistData {
  const SpotifyPlaylistData({
    required this.id,
    required this.title,
    required this.description,
    required this.tracks,
    this.artworkUrl,
    this.owner,
  });

  final String id;
  final String title;
  final String description;
  final List<SpotifyTrack> tracks;
  final String? artworkUrl;
  final String? owner;

  int get totalDurationMs =>
      tracks.fold(0, (sum, track) => sum + track.durationMs);

  String get totalDurationString {
    final duration = Duration(milliseconds: totalDurationMs);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }
}

class FeaturedSpotifyPlaylist {
  const FeaturedSpotifyPlaylist({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.artworkUrl,
  });

  final String id;
  final String title;
  final String subtitle;
  final String artworkUrl;
}

class SpotifyService {
  SpotifyService._();
  static final SpotifyService instance = SpotifyService._();

  bool get isConfigured => true;

  static const String _clientIdPrefKey = 'tone_spotify_client_id';
  static const String _clientSecretPrefKey = 'tone_spotify_client_secret';

  static const List<FeaturedSpotifyPlaylist> featuredPlaylists = [
    FeaturedSpotifyPlaylist(
      id: '37i9dQZF1DXcBWIGoYBM5M',
      title: "Today's Top Hits",
      subtitle: 'The hottest tracks right now',
      artworkUrl:
          'https://i.scdn.co/image/ab67706f00000002e06fabee7abffa117bed662f',
    ),
    FeaturedSpotifyPlaylist(
      id: '37i9dQZF1DX4WYpdgoIcn6',
      title: 'Chill Hits',
      subtitle: 'Kick back to the best new and recent chill hits',
      artworkUrl:
          'https://i.scdn.co/image/ab67706f00000002ca5aee3428d4f24705fb8a50',
    ),
    FeaturedSpotifyPlaylist(
      id: '37i9dQZF1DWZeKCadgRdKQ',
      title: 'Deep Focus',
      subtitle: 'Keep calm and focus with ambient study music',
      artworkUrl:
          'https://i.scdn.co/image/ab67706f00000002fe24d7084be472288cd6ee6c',
    ),
    FeaturedSpotifyPlaylist(
      id: '37i9dQZF1DXdLEN7aqioXM',
      title: 'Lo-Fi Beats',
      subtitle: 'Beats to relax, study, and vibe to',
      artworkUrl:
          'https://i.scdn.co/image/ab67706f0000000254473de875effa1660d2b775',
    ),
    FeaturedSpotifyPlaylist(
      id: '37i9dQZF1DWXRqgorJj26U',
      title: 'Rock Classics',
      subtitle: 'Rock legends & epic anthems',
      artworkUrl:
          'https://i.scdn.co/image/ab67706f00000002476b77271e1fbe536340f1a6',
    ),
  ];

  Future<String?> getSavedClientId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_clientIdPrefKey);
  }

  Future<String?> getSavedClientSecret() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_clientSecretPrefKey);
  }

  Future<void> saveCredentials({String? clientId, String? clientSecret}) async {
    final prefs = await SharedPreferences.getInstance();
    if (clientId != null && clientId.trim().isNotEmpty) {
      await prefs.setString(_clientIdPrefKey, clientId.trim());
    } else {
      await prefs.remove(_clientIdPrefKey);
    }
    if (clientSecret != null && clientSecret.trim().isNotEmpty) {
      await prefs.setString(_clientSecretPrefKey, clientSecret.trim());
    } else {
      await prefs.remove(_clientSecretPrefKey);
    }
  }

  String? extractPlaylistId(String input) {
    final clean = input.trim();
    if (clean.startsWith('spotify:playlist:')) {
      return clean.replaceFirst('spotify:playlist:', '').split('?').first;
    }
    final urlMatch = RegExp(r'open\.spotify\.com/playlist/([a-zA-Z0-9]+)').firstMatch(clean);
    if (urlMatch != null) {
      return urlMatch.group(1);
    }
    // Check if input is a raw 22-character alphanumeric Spotify ID
    if (RegExp(r'^[a-zA-Z0-9]{22}$').hasMatch(clean)) {
      return clean;
    }
    return null;
  }

  /// Fetches a public Spotify playlist without requiring credentials, using
  /// Spotify's public embed page data. Falls back to official Web API if credentials exist.
  Future<SpotifyPlaylistData> fetchPlaylist(String urlOrId) async {
    final playlistId = extractPlaylistId(urlOrId);
    if (playlistId == null) {
      throw const FormatException('Invalid Spotify playlist URL or ID.');
    }

    // Try custom Web API credentials if user saved them
    final clientId = await getSavedClientId();
    final clientSecret = await getSavedClientSecret();
    if (clientId != null && clientSecret != null) {
      try {
        return await _fetchViaWebApi(playlistId, clientId, clientSecret);
      } catch (e) {
        debugPrint('Spotify Web API failed; falling back to embed parsing: $e');
      }
    }

    // Fast & resilient public embed parsing (no credentials needed)
    return _fetchViaEmbed(playlistId);
  }

  Future<SpotifyPlaylistData> _fetchViaEmbed(String playlistId) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..badCertificateCallback = ((cert, host, port) => true);

    try {
      final request = await client.getUrl(
        Uri.parse('https://open.spotify.com/embed/playlist/$playlistId'),
      );
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      );
      final response = await request.close().timeout(const Duration(seconds: 15));

      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Spotify returned HTTP ${response.statusCode}');
      }

      final body = await response.transform(utf8.decoder).join();
      final nextDataMatch = RegExp(
        r'<script id="__NEXT_DATA__"[^>]*>([^<]+)</script>',
      ).firstMatch(body);

      if (nextDataMatch == null) {
        throw const FormatException('Could not parse Spotify playlist data.');
      }

      final jsonData = jsonDecode(nextDataMatch.group(1)!) as Map<String, dynamic>;
      final entity =
          jsonData['props']?['pageProps']?['state']?['data']?['entity']
              as Map<String, dynamic>?;

      if (entity == null) {
        throw const FormatException('Spotify playlist entity not found.');
      }

      final name = entity['name'] as String? ?? 'Spotify Playlist';
      final subtitle = entity['subtitle'] as String? ?? '';
      final trackList = (entity['trackList'] as List?) ?? const [];

      String? artworkUrl;
      final visual = entity['visual'] as Map<String, dynamic>?;
      final images = visual?['avatar']?['sources'] as List? ??
          visual?['header']?['sources'] as List?;
      if (images != null && images.isNotEmpty) {
        artworkUrl = images.first['url'] as String?;
      }

      final tracks = <SpotifyTrack>[];
      for (final raw in trackList) {
        if (raw is! Map<String, dynamic>) continue;
        final trackUri = raw['uri'] as String? ?? '';
        final trackId = trackUri.replaceFirst('spotify:track:', '');
        final title = raw['title'] as String? ?? 'Untitled';
        final artist = raw['subtitle'] as String? ?? 'Unknown Artist';
        final duration = raw['duration'] as int? ?? 180000;

        tracks.add(
          SpotifyTrack(
            id: trackId,
            title: title,
            artist: artist,
            album: name,
            durationMs: duration,
            artworkUrl: artworkUrl,
          ),
        );
      }

      return SpotifyPlaylistData(
        id: playlistId,
        title: name,
        description: subtitle,
        artworkUrl: artworkUrl,
        tracks: tracks,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<SpotifyPlaylistData> _fetchViaWebApi(
    String playlistId,
    String clientId,
    String clientSecret,
  ) async {
    final credentials = sp.SpotifyApiCredentials(clientId, clientSecret);
    final api = sp.SpotifyApi(credentials);

    final playlist = await api.playlists.get(playlistId);
    final pageTracks = await api.playlists.getPlaylistTracks(playlistId).all();

    final tracks = <SpotifyTrack>[];
    for (final playlistTrack in pageTracks) {
      final track = playlistTrack.track;
      if (track == null || track.name == null) continue;
      final artistName =
          track.artists?.map((a) => a.name ?? '').where((n) => n.isNotEmpty).join(', ') ??
          'Unknown Artist';
      final albumName = track.album?.name ?? playlist.name ?? 'Spotify';
      final art = track.album?.images?.isNotEmpty == true
          ? track.album!.images!.first.url
          : playlist.images?.isNotEmpty == true
              ? playlist.images!.first.url
              : null;

      tracks.add(
        SpotifyTrack(
          id: track.id ?? track.uri ?? '',
          title: track.name!,
          artist: artistName,
          album: albumName,
          durationMs: track.durationMs ?? 180000,
          artworkUrl: art,
        ),
      );
    }

    return SpotifyPlaylistData(
      id: playlistId,
      title: playlist.name ?? 'Spotify Playlist',
      description: playlist.description ?? '',
      artworkUrl: playlist.images?.isNotEmpty == true ? playlist.images!.first.url : null,
      owner: playlist.owner?.displayName,
      tracks: tracks,
    );
  }

  /// Imports a Spotify playlist into Tone's local playlist system so it appears
  /// in the user's Library and Playlists tab.
  Future<MusicPlaylist> importPlaylistToTone({
    required SpotifyPlaylistData playlist,
    required MusicLibrary library,
  }) async {
    // 1. Create or get existing playlist in Tone
    var targetName = playlist.title;
    MusicPlaylist tonePlaylist;
    try {
      tonePlaylist = await library.createPlaylist(targetName);
    } catch (_) {
      // If name already exists, append timestamp
      targetName = '${playlist.title} (${DateTime.now().minute}m)';
      tonePlaylist = await library.createPlaylist(targetName);
    }

    // 2. Convert Spotify tracks to imported tracks and register in library
    final importedTracks = playlist.tracks.map((t) => t.toImportedTrack()).toList();
    await library.importExternalTracks(importedTracks);

    // 3. Add to playlist
    await library.addTracksToPlaylist(
      tonePlaylist.id,
      importedTracks.map((t) => t.id),
    );

    return tonePlaylist;
  }
}
