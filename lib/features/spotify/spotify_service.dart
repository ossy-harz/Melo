import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotify/spotify.dart' as sp;
import 'package:melo_player/features/library/imported_track.dart';
import 'package:melo_player/features/library/music_library.dart';
import 'package:melo_player/features/library/music_playlist.dart';
import 'package:melo_player/features/youtube/youtube_audio_service.dart';

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

  ImportedTrack toImportedTrack({String? genre}) => ImportedTrack(
    id: 'spotify:$id',
    path: 'spotify:$id',
    title: title,
    artist: artist,
    album: album,
    durationMs: durationMs,
    artworkUri: artworkUrl,
    sourceProvider: 'Spotify',
    providerTrackId: id,
    genre: genre,
    isAvailable: true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'album': album,
    'durationMs': durationMs,
    if (artworkUrl != null) 'artworkUrl': artworkUrl,
  };

  factory SpotifyTrack.fromJson(Map<String, dynamic> json) => SpotifyTrack(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? 'Untitled',
    artist: json['artist'] as String? ?? 'Unknown Artist',
    album: json['album'] as String? ?? 'Spotify',
    durationMs: (json['durationMs'] as num?)?.toInt() ?? 180000,
    artworkUrl: json['artworkUrl'] as String?,
  );
}

class SpotifyPlaylistSummary {
  const SpotifyPlaylistSummary({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.artworkUrl,
    this.trackCount = 0,
  });

  final String id;
  final String title;
  final String subtitle;
  final String artworkUrl;
  final int trackCount;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'artworkUrl': artworkUrl,
    'trackCount': trackCount,
  };

  factory SpotifyPlaylistSummary.fromJson(Map<String, dynamic> json) =>
      SpotifyPlaylistSummary(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? 'Spotify Playlist',
        subtitle: json['subtitle'] as String? ?? 'Your Spotify Playlist',
        artworkUrl: json['artworkUrl'] as String? ?? '',
        trackCount: (json['trackCount'] as num?)?.toInt() ?? 0,
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
    this.category = 'Featured',
  });

  final String id;
  final String title;
  final String subtitle;
  final String artworkUrl;
  final String category;
}

class SpotifyService {
  SpotifyService._();
  static final SpotifyService instance = SpotifyService._();

  bool get isConfigured => true;

  static const String _clientIdPrefKey = 'tone_spotify_client_id';
  static const String _clientSecretPrefKey = 'tone_spotify_client_secret';
  static const String _accessTokenPrefKey = 'tone_spotify_access_token';
  static const String _refreshTokenPrefKey = 'tone_spotify_refresh_token';
  static const String _cookiePrefKey = 'tone_spotify_auth_cookie';
  static const String _userIdPrefKey = 'tone_spotify_user_id';
  static const String _displayNamePrefKey = 'tone_spotify_display_name';
  static const String _avatarUrlPrefKey = 'tone_spotify_avatar_url';
  static const String _userPlaylistsJsonPrefKey = 'tone_spotify_user_playlists';
  static const String _personalTracksJsonPrefKey =
      'tone_spotify_personal_tracks';
  static const String _likedTracksJsonPrefKey = 'tone_spotify_liked_tracks';
  static const String _recentlyPlayedJsonPrefKey =
      'tone_spotify_recent_tracks';
  static const String _topArtistsPrefKey = 'tone_spotify_top_artists';
  static const MethodChannel _channel = MethodChannel(
    'app.melo.melo_player/library',
  );
  static const String _pkceRedirectUri = 'melo://spotify-callback';

  final Map<String, SpotifyPlaylistData> _playlistCache = {};
  List<SpotifyTrack>? _cachedFeedTracks;

  String? _accessToken;
  String? _refreshToken;
  String? _cookie;
  String? _userId;
  String? _displayName;
  String? _avatarUrl;
  List<SpotifyPlaylistSummary> _userPlaylists = const [];
  List<SpotifyTrack> _personalFeedTracks = const [];
  List<SpotifyTrack> _likedTracks = const [];
  List<SpotifyTrack> _recentlyPlayedTracks = const [];
  List<String> _topArtists = const [];
  Future<void>? _activeRefresh;

  final ValueNotifier<bool> authState = ValueNotifier<bool>(false);
  final ValueNotifier<int> feedRevision = ValueNotifier<int>(0);

  bool get isLoggedIn =>
      (_accessToken?.isNotEmpty ?? false) ||
      (_cookie?.isNotEmpty ?? false) ||
      (_userId?.isNotEmpty ?? false);
  String? get displayName => _displayName;
  String? get avatarUrl => _avatarUrl;
  String? get userId => _userId;
  List<SpotifyPlaylistSummary> get userPlaylists =>
      List.unmodifiable(_userPlaylists);
  List<SpotifyTrack> get personalFeedTracks =>
      List.unmodifiable(_personalFeedTracks);
  List<SpotifyTrack> get likedTracks => List.unmodifiable(_likedTracks);
  List<SpotifyTrack> get recentlyPlayedTracks =>
      List.unmodifiable(_recentlyPlayedTracks);
  List<String> get topArtists => List.unmodifiable(_topArtists);

  static const List<FeaturedSpotifyPlaylist> featuredPlaylists = [
    FeaturedSpotifyPlaylist(
      id: '37i9dQZF1DXcBWIGoYBM5M',
      title: "Today's Top Hits",
      subtitle: 'The hottest tracks right now',
      artworkUrl:
          'https://i.scdn.co/image/ab67706f00000002e06fabee7abffa117bed662f',
      category: 'Charts',
    ),
    FeaturedSpotifyPlaylist(
      id: '37i9dQZEVXbMDoHDwVN2tF',
      title: 'Top 50 - Global',
      subtitle: 'Most played tracks worldwide right now',
      artworkUrl:
          'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
      category: 'Charts',
    ),
    FeaturedSpotifyPlaylist(
      id: '37i9dQZF1DWYkaDif7Ztbp',
      title: 'African Heat',
      subtitle: 'Afrobeats, Amapiano & global African heat',
      artworkUrl:
          'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=600&q=80',
      category: 'Afro & Global',
    ),
    FeaturedSpotifyPlaylist(
      id: '37i9dQZF1DX0XUsuxWHRQd',
      title: 'RapCaviar',
      subtitle: 'Heavyweight bars & hip-hop leaders',
      artworkUrl:
          'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=600&q=80',
      category: 'Hip-Hop',
    ),
    FeaturedSpotifyPlaylist(
      id: '37i9dQZF1DX4WYpdgoIcn6',
      title: 'Chill Hits',
      subtitle: 'Kick back to the best new and recent chill hits',
      artworkUrl:
          'https://i.scdn.co/image/ab67706f00000002ca5aee3428d4f24705fb8a50',
      category: 'Chill',
    ),
    FeaturedSpotifyPlaylist(
      id: '37i9dQZF1DWZeKCadgRdKQ',
      title: 'Deep Focus',
      subtitle: 'Keep calm and focus with ambient study music',
      artworkUrl:
          'https://i.scdn.co/image/ab67706f00000002fe24d7084be472288cd6ee6c',
      category: 'Focus',
    ),
    FeaturedSpotifyPlaylist(
      id: '37i9dQZF1DXdLEN7aqioXM',
      title: 'Lo-Fi Beats',
      subtitle: 'Beats to relax, study, and vibe to',
      artworkUrl:
          'https://i.scdn.co/image/ab67706f0000000254473de875effa1660d2b775',
      category: 'Focus',
    ),
    FeaturedSpotifyPlaylist(
      id: '37i9dQZF1DWXRqgorJj26U',
      title: 'Rock Classics',
      subtitle: 'Rock legends & epic anthems',
      artworkUrl:
          'https://i.scdn.co/image/ab67706f00000002476b77271e1fbe536340f1a6',
      category: 'Rock',
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

  /// Loads saved Spotify account credentials, session state, and cached personal
  /// feed from local storage, and triggers a background feed refresh if signed in.
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_accessTokenPrefKey);
    _refreshToken = prefs.getString(_refreshTokenPrefKey);
    _cookie = prefs.getString(_cookiePrefKey);
    _userId = prefs.getString(_userIdPrefKey);
    _displayName = prefs.getString(_displayNamePrefKey);
    _avatarUrl = prefs.getString(_avatarUrlPrefKey);
    _topArtists = prefs.getStringList(_topArtistsPrefKey) ?? const [];

    _userPlaylists = _decodePlaylistsJson(
      prefs.getString(_userPlaylistsJsonPrefKey),
    );
    _personalFeedTracks = _decodeTracksJson(
      prefs.getString(_personalTracksJsonPrefKey),
    );
    _likedTracks = _decodeTracksJson(prefs.getString(_likedTracksJsonPrefKey));
    _recentlyPlayedTracks = _decodeTracksJson(
      prefs.getString(_recentlyPlayedJsonPrefKey),
    );

    authState.value = isLoggedIn;
    feedRevision.value++;
    if (isLoggedIn && !Platform.environment.containsKey('FLUTTER_TEST')) {
      unawaited(refreshPersonalFeed());
    }
  }

  List<SpotifyPlaylistSummary> _decodePlaylistsJson(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return list
          .whereType<Map>()
          .map(
            (m) => SpotifyPlaylistSummary.fromJson(
              Map<String, dynamic>.from(m),
            ),
          )
          .where((p) => p.id.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  List<SpotifyTrack> _decodeTracksJson(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return list
          .whereType<Map>()
          .map((m) => SpotifyTrack.fromJson(Map<String, dynamic>.from(m)))
          .where((t) => t.title.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _persistSession() async {
    final prefs = await SharedPreferences.getInstance();
    Future<void> setOrRemove(String key, String? value) async {
      if (value != null && value.isNotEmpty) {
        await prefs.setString(key, value);
      } else {
        await prefs.remove(key);
      }
    }

    await setOrRemove(_accessTokenPrefKey, _accessToken);
    await setOrRemove(_refreshTokenPrefKey, _refreshToken);
    await setOrRemove(_cookiePrefKey, _cookie);
    await setOrRemove(_userIdPrefKey, _userId);
    await setOrRemove(_displayNamePrefKey, _displayName);
    await setOrRemove(_avatarUrlPrefKey, _avatarUrl);
    await prefs.setStringList(_topArtistsPrefKey, _topArtists);
    await prefs.setString(
      _userPlaylistsJsonPrefKey,
      jsonEncode(_userPlaylists.map((p) => p.toJson()).toList()),
    );
    await prefs.setString(
      _personalTracksJsonPrefKey,
      jsonEncode(_personalFeedTracks.map((t) => t.toJson()).toList()),
    );
    await prefs.setString(
      _likedTracksJsonPrefKey,
      jsonEncode(_likedTracks.map((t) => t.toJson()).toList()),
    );
    await prefs.setString(
      _recentlyPlayedJsonPrefKey,
      jsonEncode(_recentlyPlayedTracks.map((t) => t.toJson()).toList()),
    );
  }

  static String _generateCodeVerifier() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final rand = math.Random.secure();
    return List.generate(64, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  static String _generateCodeChallenge(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier));
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  /// Launches an in-app Spotify login WebView (OAuth 2.0 PKCE when a Client ID
  /// is configured, or web-session sign-in capturing Spotify session cookies).
  Future<bool> launchInAppLogin() async {
    try {
      final clientId = (await getSavedClientId())?.trim();
      if (clientId != null && clientId.isNotEmpty) {
        final verifier = _generateCodeVerifier();
        final challenge = _generateCodeChallenge(verifier);
        final authUri = Uri.https('accounts.spotify.com', '/authorize', {
          'client_id': clientId,
          'response_type': 'code',
          'redirect_uri': _pkceRedirectUri,
          'scope':
              'user-read-private user-read-recently-played user-top-read user-library-read playlist-read-private playlist-read-collaborative',
          'code_challenge_method': 'S256',
          'code_challenge': challenge,
          'show_dialog': 'true',
        });

        final rawResult = await _channel.invokeMethod<dynamic>(
          'openSpotifyLogin',
          {
            'authUrl': authUri.toString(),
            'redirectPrefix': _pkceRedirectUri,
          },
        );
        if (rawResult is Map) {
          final redirectUrl = rawResult['redirectUrl'] as String?;
          final cookies = rawResult['cookies'] as String?;
          if (redirectUrl != null) {
            final uri = Uri.tryParse(redirectUrl);
            final code = uri?.queryParameters['code'];
            if (code != null && code.isNotEmpty) {
              final exchanged = await _exchangePkceCode(
                code: code,
                verifier: verifier,
                clientId: clientId,
              );
              if (exchanged) {
                if (cookies != null && cookies.isNotEmpty) _cookie = cookies;
                await refreshPersonalFeed();
                return isLoggedIn;
              }
            }
          }
          if (cookies != null && cookies.contains('sp_dc=')) {
            return await connectWithTokenOrCookie(cookies);
          }
        }
        return false;
      }

      final rawResult = await _channel.invokeMethod<dynamic>('openSpotifyLogin');
      if (rawResult is! Map) return false;
      final cookies = (rawResult['cookies'] as String?)?.trim() ?? '';
      final pageToken = (rawResult['accessToken'] as String?)?.trim() ?? '';
      if (pageToken.isNotEmpty) {
        _accessToken = pageToken;
      }
      if (cookies.isNotEmpty) {
        _cookie = cookies;
      }
      if (_accessToken == null && _cookie == null) return false;

      if (_accessToken == null && _cookie != null) {
        await _exchangeCookieForToken();
      }
      await refreshPersonalFeed();
      if (!isLoggedIn && _cookie != null && _cookie!.contains('sp_dc=')) {
        _displayName ??= 'Spotify Account';
        await _persistSession();
        authState.value = isLoggedIn;
        feedRevision.value++;
      }
      return isLoggedIn;
    } catch (e) {
      debugPrint('Error in Spotify launchInAppLogin: $e');
      return false;
    }
  }

  Future<bool> _exchangePkceCode({
    required String code,
    required String verifier,
    required String clientId,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('https://accounts.spotify.com/api/token'),
            headers: const {
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: {
              'grant_type': 'authorization_code',
              'code': code,
              'redirect_uri': _pkceRedirectUri,
              'client_id': clientId,
              'code_verifier': verifier,
            },
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return false;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final token = data['access_token'] as String?;
      final refresh = data['refresh_token'] as String?;
      if (token == null || token.isEmpty) return false;
      _accessToken = token;
      if (refresh != null && refresh.isNotEmpty) _refreshToken = refresh;
      return true;
    } catch (e) {
      debugPrint('Spotify PKCE code exchange error: $e');
      return false;
    }
  }

  Future<bool> _refreshWithRefreshToken() async {
    final refresh = _refreshToken;
    final clientId = (await getSavedClientId())?.trim();
    if (refresh == null ||
        refresh.isEmpty ||
        clientId == null ||
        clientId.isEmpty) {
      return false;
    }
    try {
      final res = await http
          .post(
            Uri.parse('https://accounts.spotify.com/api/token'),
            headers: const {
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: {
              'grant_type': 'refresh_token',
              'refresh_token': refresh,
              'client_id': clientId,
            },
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return false;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final token = data['access_token'] as String?;
      final nextRefresh = data['refresh_token'] as String?;
      if (token == null || token.isEmpty) return false;
      _accessToken = token;
      if (nextRefresh != null && nextRefresh.isNotEmpty) {
        _refreshToken = nextRefresh;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _exchangeCookieForToken() async {
    final cookie = _cookie;
    if (cookie == null || cookie.isEmpty) return false;
    const ua =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';
    try {
      final res = await http
          .get(
            Uri.parse(
              'https://open.spotify.com/get_access_token?reason=transport&productType=web_player',
            ),
            headers: {
              'Cookie': cookie,
              'User-Agent': ua,
              'Accept': 'application/json',
              'App-Platform': 'WebPlayer',
            },
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final token = data['accessToken'] as String?;
        if (token != null && token.isNotEmpty) {
          _accessToken = token;
          return true;
        }
      }
    } catch (_) {}

    // Fallback: extract embedded web player session token from open.spotify.com HTML
    try {
      final pageRes = await http
          .get(
            Uri.parse('https://open.spotify.com/'),
            headers: {
              'Cookie': cookie,
              'User-Agent': ua,
              'Accept': 'text/html,application/xhtml+xml',
            },
          )
          .timeout(const Duration(seconds: 10));
      if (pageRes.statusCode == 200) {
        final match = RegExp(
          r'<script id="session"[^>]*>([^<]+)</script>',
        ).firstMatch(pageRes.body);
        if (match != null) {
          final json = jsonDecode(match.group(1)!) as Map<String, dynamic>;
          final token = json['accessToken'] as String?;
          if (token != null && token.isNotEmpty) {
            _accessToken = token;
            return true;
          }
        }
      }
    } catch (_) {}
    return false;
  }

  /// Connects using a Spotify Bearer access token, session cookie (`sp_dc=...`),
  /// a Spotify user profile URL/username (`https://open.spotify.com/user/...`),
  /// or a Spotify playlist link directly.
  Future<bool> connectWithTokenOrCookie(String input) async {
    var clean = input.trim();
    if (clean.isEmpty) return false;

    // Strip trailing query parameters or fragments
    final qIdx = clean.indexOf('?');
    if (qIdx != -1) clean = clean.substring(0, qIdx).trim();
    final hIdx = clean.indexOf('#');
    if (hIdx != -1) clean = clean.substring(0, hIdx).trim();

    // Check if the input is a Spotify playlist or album URL/ID directly
    final playlistParsed = parseSpotifyUrlOrId(clean);
    if (playlistParsed != null &&
        (playlistParsed.$2 == 'playlist' || playlistParsed.$2 == 'album')) {
      try {
        final data = await fetchPlaylist(playlistParsed.$1);
        if (data.tracks.isNotEmpty) {
          _userPlaylists = [
            SpotifyPlaylistSummary(
              id: data.id,
              title: data.title,
              subtitle: '${data.tracks.length} tracks',
              artworkUrl: data.artworkUrl ?? '',
              trackCount: data.tracks.length,
            ),
            ..._userPlaylists.where((p) => p.id != data.id),
          ];
          _personalFeedTracks = data.tracks;
          _displayName ??= data.title;
          _userId ??= playlistParsed.$1;
          await _persistSession();
          authState.value = true;
          feedRevision.value++;
          return true;
        }
      } catch (e) {
        debugPrint('Direct playlist connection failed: $e');
      }
    }

    final prevToken = _accessToken;
    final prevCookie = _cookie;
    final prevUserId = _userId;

    if (clean.toLowerCase().startsWith('bearer ')) {
      _accessToken = clean.substring(7).trim();
      _cookie = null;
    } else if (clean.contains('sp_dc=')) {
      _cookie = clean;
      _accessToken = null;
      await _exchangeCookieForToken();
    } else if (clean.startsWith('BQ') && !clean.contains(' ')) {
      _accessToken = clean;
      _cookie = null;
    } else {
      final userMatch = RegExp(
        r'(?:open\.spotify\.com/(?:intl-[a-zA-Z]{2,5}/)?user/|spotify:user:)([a-zA-Z0-9._-]+)',
        caseSensitive: false,
      ).firstMatch(clean);
      final extractedUser =
          userMatch?.group(1) ??
          (!clean.contains(' ') && !clean.contains('/') ? clean : null);
      if (extractedUser == null || extractedUser.isEmpty) {
        return false;
      }
      _userId = extractedUser;
      _displayName ??= extractedUser;
      _accessToken = null;
      _cookie = null;
    }

    await refreshPersonalFeed();

    final hasData =
        (_displayName != null && _displayName!.isNotEmpty) ||
        _userPlaylists.isNotEmpty ||
        _personalFeedTracks.isNotEmpty ||
        (_accessToken != null && _accessToken!.isNotEmpty);
    if (!hasData) {
      _accessToken = prevToken;
      _cookie = prevCookie;
      _userId = prevUserId;
      authState.value = isLoggedIn;
      return false;
    }

    authState.value = isLoggedIn;
    feedRevision.value++;
    return true;
  }

  /// Signs out and clears all cached Spotify session tokens and personal feed items.
  Future<void> logout() async {
    _accessToken = null;
    _refreshToken = null;
    _cookie = null;
    _userId = null;
    _displayName = null;
    _avatarUrl = null;
    _userPlaylists = const [];
    _personalFeedTracks = const [];
    _likedTracks = const [];
    _recentlyPlayedTracks = const [];
    _topArtists = const [];

    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      _accessTokenPrefKey,
      _refreshTokenPrefKey,
      _cookiePrefKey,
      _userIdPrefKey,
      _displayNamePrefKey,
      _avatarUrlPrefKey,
      _userPlaylistsJsonPrefKey,
      _personalTracksJsonPrefKey,
      _likedTracksJsonPrefKey,
      _recentlyPlayedJsonPrefKey,
      _topArtistsPrefKey,
    ]) {
      await prefs.remove(key);
    }
    authState.value = false;
    feedRevision.value++;
  }

  Future<Map<String, dynamic>?> _spotifyApiGet(
    String path,
    String token,
  ) async {
    try {
      final res = await http
          .get(
            Uri.parse('https://api.spotify.com$path'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  SpotifyTrack? _parseApiTrack(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final name = map['name'] as String?;
    if (name == null || name.trim().isEmpty) return null;
    final id = (map['id'] as String?) ?? (map['uri'] as String?) ?? name;
    final artistsList = map['artists'] as List?;
    final artist =
        artistsList
            ?.whereType<Map>()
            .map((a) => a['name'] as String? ?? '')
            .where((n) => n.isNotEmpty)
            .join(', ') ??
        'Unknown Artist';
    final albumMap = map['album'] as Map?;
    final album = (albumMap?['name'] as String?) ?? 'Spotify';
    final images = albumMap?['images'] as List?;
    String? artworkUrl;
    if (images != null && images.isNotEmpty) {
      final first = images.first;
      if (first is Map) {
        artworkUrl = first['url'] as String?;
      }
    }
    final durationMs = (map['duration_ms'] as num?)?.toInt() ?? 180000;
    return SpotifyTrack(
      id: id,
      title: name,
      artist: artist.isEmpty ? 'Unknown Artist' : artist,
      album: album,
      durationMs: durationMs,
      artworkUrl: artworkUrl,
    );
  }

  SpotifyPlaylistSummary? _parseApiPlaylistSummary(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final id = map['id'] as String?;
    final name = map['name'] as String?;
    if (id == null || id.isEmpty || name == null || name.isEmpty) return null;
    final owner = (map['owner'] as Map?)?['display_name'] as String?;
    final total = ((map['tracks'] as Map?)?['total'] as num?)?.toInt() ?? 0;
    final images = map['images'] as List?;
    var artworkUrl = '';
    if (images != null && images.isNotEmpty) {
      final first = images.first;
      if (first is Map) {
        artworkUrl = (first['url'] as String?) ?? '';
      }
    }
    return SpotifyPlaylistSummary(
      id: id,
      title: name,
      subtitle: owner != null && owner.isNotEmpty
          ? '$owner · $total tracks'
          : '$total tracks',
      artworkUrl: artworkUrl,
      trackCount: total,
    );
  }

  /// Refreshes the signed-in user's Spotify profile, playlists, recently played,
  /// top tracks, top artists, and liked songs, and optionally primes [library].
  Future<void> refreshPersonalFeed({MusicLibrary? library}) {
    final existing = _activeRefresh;
    if (existing != null) return existing;
    final op = _performRefreshPersonalFeed(library: library);
    _activeRefresh = op;
    return op.whenComplete(() => _activeRefresh = null);
  }

  Future<void> _performRefreshPersonalFeed({MusicLibrary? library}) async {
    if (!isLoggedIn) return;
    try {
      String? activeToken = _accessToken;
      Map<String, dynamic>? me = activeToken != null && activeToken.isNotEmpty
          ? await _spotifyApiGet('/v1/me', activeToken)
          : null;

      if (me == null && _refreshToken != null && _refreshToken!.isNotEmpty) {
        if (await _refreshWithRefreshToken() && _accessToken != null) {
          activeToken = _accessToken;
          me = await _spotifyApiGet('/v1/me', activeToken!);
        }
      }
      if (me == null && _cookie != null && _cookie!.isNotEmpty) {
        if (await _exchangeCookieForToken() && _accessToken != null) {
          activeToken = _accessToken;
          me = await _spotifyApiGet('/v1/me', activeToken!);
        }
      }

      if (me != null && activeToken != null) {
        _userId = (me['id'] as String?) ?? _userId;
        _displayName =
            (me['display_name'] as String?) ?? _userId ?? 'Spotify User';
        final profileImages = me['images'] as List?;
        if (profileImages != null && profileImages.isNotEmpty) {
          _avatarUrl = (profileImages.first as Map?)?['url'] as String?;
        }

        final responses = await Future.wait([
          _spotifyApiGet('/v1/me/playlists?limit=30', activeToken),
          _spotifyApiGet(
            '/v1/me/player/recently-played?limit=25',
            activeToken,
          ),
          _spotifyApiGet(
            '/v1/me/top/tracks?limit=25&time_range=short_term',
            activeToken,
          ),
          _spotifyApiGet(
            '/v1/me/top/artists?limit=15&time_range=short_term',
            activeToken,
          ),
          _spotifyApiGet('/v1/me/tracks?limit=50', activeToken),
        ]);

        final playlistsJson = responses[0];
        if (playlistsJson != null) {
          final parsed = ((playlistsJson['items'] as List?) ?? const [])
              .map(_parseApiPlaylistSummary)
              .whereType<SpotifyPlaylistSummary>()
              .toList(growable: false);
          if (parsed.isNotEmpty) _userPlaylists = parsed;
        }

        final recentJson = responses[1];
        if (recentJson != null) {
          final parsed = ((recentJson['items'] as List?) ?? const [])
              .map(
                (item) => _parseApiTrack(item is Map ? item['track'] : null),
              )
              .whereType<SpotifyTrack>()
              .toList(growable: false);
          if (parsed.isNotEmpty) _recentlyPlayedTracks = parsed;
        }

        var topTracks = const <SpotifyTrack>[];
        final topTracksJson = responses[2];
        if (topTracksJson != null) {
          topTracks = ((topTracksJson['items'] as List?) ?? const [])
              .map(_parseApiTrack)
              .whereType<SpotifyTrack>()
              .toList(growable: false);
        }

        final topArtistsJson = responses[3];
        if (topArtistsJson != null) {
          final parsedArtists =
              ((topArtistsJson['items'] as List?) ?? const [])
                  .whereType<Map>()
                  .map((a) => (a['name'] as String? ?? '').trim())
                  .where((name) => name.isNotEmpty)
                  .toList(growable: false);
          if (parsedArtists.isNotEmpty) _topArtists = parsedArtists;
        }

        final likedJson = responses[4];
        if (likedJson != null) {
          final parsed = ((likedJson['items'] as List?) ?? const [])
              .map(
                (item) => _parseApiTrack(item is Map ? item['track'] : null),
              )
              .whereType<SpotifyTrack>()
              .toList(growable: false);
          if (parsed.isNotEmpty) _likedTracks = parsed;
        }

        final merged = <SpotifyTrack>[];
        final seenTrackIds = <String>{};
        void addAllUnique(Iterable<SpotifyTrack> source) {
          for (final t in source) {
            final key = '${t.title.toLowerCase()}|${t.artist.toLowerCase()}';
            if (seenTrackIds.add(key)) merged.add(t);
          }
        }

        addAllUnique(_recentlyPlayedTracks);
        addAllUnique(topTracks);
        addAllUnique(_likedTracks);

        if (merged.length < 10 && _userPlaylists.isNotEmpty) {
          for (final summary in _userPlaylists.take(3)) {
            try {
              final data = await fetchPlaylist(summary.id);
              addAllUnique(data.tracks);
            } catch (_) {}
          }
        }
        if (merged.isNotEmpty) _personalFeedTracks = merged;
      } else if (_userId != null && _userId!.isNotEmpty) {
        await _refreshPublicUserFeed(_userId!);
      }

      if (library != null && _personalFeedTracks.isNotEmpty) {
        for (final track in _personalFeedTracks.take(15).toList().reversed) {
          await library.recordPlayedMediaItem(
            track.toImportedTrack().toMediaItem(),
          );
        }
      }

      await _persistSession();
      authState.value = isLoggedIn;
      feedRevision.value++;
    } catch (e) {
      debugPrint('Error refreshing personal Spotify feed: $e');
    }
  }

  Future<void> _refreshPublicUserFeed(String userId) async {
    final publicPlaylistIds = <String>[];
    final clientId = (await getSavedClientId())?.trim();
    final clientSecret = (await getSavedClientSecret())?.trim();
    if (clientId != null &&
        clientId.isNotEmpty &&
        clientSecret != null &&
        clientSecret.isNotEmpty) {
      try {
        final credentials = sp.SpotifyApiCredentials(clientId, clientSecret);
        final api = sp.SpotifyApi(credentials);
        final pages = await api.playlists.getUsersPlaylists(userId).all();
        final summaries = <SpotifyPlaylistSummary>[];
        for (final p in pages) {
          final id = p.id;
          final name = p.name;
          if (id == null || name == null) continue;
          publicPlaylistIds.add(id);
          summaries.add(
            SpotifyPlaylistSummary(
              id: id,
              title: name,
              subtitle: p.owner?.displayName ?? userId,
              artworkUrl: p.images?.isNotEmpty == true
                  ? (p.images!.first.url ?? '')
                  : '',
            ),
          );
        }
        if (summaries.isNotEmpty) _userPlaylists = summaries;
      } catch (_) {}
    }

    if (publicPlaylistIds.isEmpty) {
      try {
        final res = await http
            .get(
              Uri.parse('https://open.spotify.com/user/$userId'),
              headers: const {
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
              },
            )
            .timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          final seen = <String>{};
          for (final m in RegExp(
            r'(?:spotify:playlist:|/(?:intl-[a-zA-Z]{2,5}/)?playlist/)([a-zA-Z0-9_-]{16,40})',
            caseSensitive: false,
          ).allMatches(res.body)) {
            final id = m.group(1);
            if (id != null && seen.add(id)) {
              publicPlaylistIds.add(id);
            }
          }
          final titleMatch = RegExp(
            r'<meta property="og:title" content="([^"]+)"',
          ).firstMatch(res.body);
          if (titleMatch != null && titleMatch.group(1)!.trim().isNotEmpty) {
            _displayName = titleMatch
                .group(1)!
                .replaceAll(RegExp(r'\s*\|\s*Spotify$'), '')
                .trim();
          }
          final imgMatch = RegExp(
            r'<meta property="og:image" content="([^"]+)"',
          ).firstMatch(res.body);
          if (imgMatch != null && imgMatch.group(1)!.trim().isNotEmpty) {
            _avatarUrl = imgMatch.group(1)!.trim();
          }
        }
      } catch (_) {}
    }

    if (publicPlaylistIds.isNotEmpty) {
      final summaries = <SpotifyPlaylistSummary>[];
      final feedTracks = <SpotifyTrack>[];
      final seenTracks = <String>{};
      for (final id in publicPlaylistIds.take(8)) {
        try {
          final data = await fetchPlaylist(id);
          summaries.add(
            SpotifyPlaylistSummary(
              id: data.id,
              title: data.title,
              subtitle: '${data.tracks.length} tracks',
              artworkUrl: data.artworkUrl ?? '',
              trackCount: data.tracks.length,
            ),
          );
          if (feedTracks.length < 30) {
            for (final t in data.tracks) {
              final key = '${t.title.toLowerCase()}|${t.artist.toLowerCase()}';
              if (seenTracks.add(key)) feedTracks.add(t);
            }
          }
        } catch (_) {}
      }
      if (summaries.isNotEmpty && _userPlaylists.isEmpty) {
        _userPlaylists = summaries;
      }
      if (feedTracks.isNotEmpty) {
        _personalFeedTracks = feedTracks;
      }
    }
  }

  /// Syncs the user's Spotify liked songs and personal playlists into
  /// [library], returning the total number of tracks synced.
  Future<int> syncAccountToLibrary(MusicLibrary library) async {
    try {
      await refreshPersonalFeed(library: library);
    } catch (e) {
      debugPrint('Spotify feed refresh during sync warning: $e');
    }
    var syncedCount = 0;

    final primaryTracks = _likedTracks.isNotEmpty
        ? _likedTracks
        : _personalFeedTracks;
    if (primaryTracks.isNotEmpty) {
      try {
        final likedPlaylist = SpotifyPlaylistData(
          id: 'liked',
          title: 'Spotify Liked Songs',
          description: 'Synced from your Spotify account',
          tracks: primaryTracks,
          artworkUrl: primaryTracks.first.artworkUrl,
        );
        await importPlaylistToTone(
          playlist: likedPlaylist,
          library: library,
          mergeExisting: true,
        );
        syncedCount += primaryTracks.length;
      } catch (e) {
        debugPrint('Failed syncing Spotify liked songs: $e');
      }
    }

    for (final summary in _userPlaylists.take(10)) {
      try {
        final data = await fetchPlaylist(summary.id);
        if (data.tracks.isEmpty) continue;
        await importPlaylistToTone(
          playlist: data,
          library: library,
          mergeExisting: true,
        );
        syncedCount += data.tracks.length;
      } catch (e) {
        debugPrint('Failed syncing Spotify playlist ${summary.title}: $e');
      }
    }
    return syncedCount;
  }

  /// Parses a Spotify URL or raw ID into its unique identifier and entity type ('playlist', 'album', 'track').
  static (String id, String type)? parseSpotifyUrlOrId(String input) {
    var clean = input.trim();
    if (clean.isEmpty) return null;

    // Strip trailing query parameters (?si=...) or fragments (#...)
    final qIdx = clean.indexOf('?');
    if (qIdx != -1) clean = clean.substring(0, qIdx).trim();
    final hIdx = clean.indexOf('#');
    if (hIdx != -1) clean = clean.substring(0, hIdx).trim();

    // 1. Spotify URI formats:
    // spotify:playlist:xxx, spotify:album:xxx, spotify:track:xxx, spotify:user:xxx:playlist:yyy
    final uriMatch = RegExp(
      r'spotify:(?:user:[^:]+:)?(playlist|album|track):([a-zA-Z0-9_-]+)',
      caseSensitive: false,
    ).firstMatch(clean);
    if (uriMatch != null) {
      return (uriMatch.group(2)!, uriMatch.group(1)!.toLowerCase());
    }

    // 2. Spotify Web URLs:
    // https://open.spotify.com/intl-xx/(playlist|album|track)/xxx
    // https://open.spotify.com/(playlist|album|track)/xxx
    // https://open.spotify.com/user/xxx/playlist/yyy
    final urlMatch = RegExp(
      r'open\.spotify\.com/(?:intl-[a-zA-Z]{2,5}/)?(?:user/[^/]+/)?(playlist|album|track)/([a-zA-Z0-9_-]+)',
      caseSensitive: false,
    ).firstMatch(clean);
    if (urlMatch != null) {
      return (urlMatch.group(2)!, urlMatch.group(1)!.toLowerCase());
    }

    // 3. Raw Spotify Base62 ID (20 to 24 characters)
    if (RegExp(r'^[a-zA-Z0-9]{20,24}$').hasMatch(clean)) {
      return (clean, 'playlist');
    }

    return null;
  }

  String? extractPlaylistId(String input) {
    final parsed = parseSpotifyUrlOrId(input);
    return parsed?.$1;
  }

  /// Fetches a public Spotify playlist or album without requiring developer credentials,
  /// using Spotify oEmbed and public embed page data with Deezer/iTunes resilience.
  Future<SpotifyPlaylistData> fetchPlaylist(String urlOrId) async {
    final parsed = parseSpotifyUrlOrId(urlOrId);
    if (parsed == null) {
      throw const FormatException('Invalid Spotify URL or ID. Please check the link.');
    }
    final entityId = parsed.$1;
    final entityType = parsed.$2;

    final cached = _playlistCache[entityId];
    if (cached != null && cached.tracks.isNotEmpty) {
      return cached;
    }

    SpotifyPlaylistData data;
    // 1. If user is logged in with active token, fetch directly from Web API.
    // This allows importing personal, private, and collaborative user playlists cleanly.
    if ((_accessToken == null || _accessToken!.isEmpty) && _cookie != null && _cookie!.isNotEmpty) {
      try {
        await _exchangeCookieForToken();
      } catch (_) {}
    }
    if (_accessToken != null && _accessToken!.isNotEmpty) {
      try {
        final apiData = await _fetchViaAccessToken(entityId, entityType: entityType);
        if (apiData != null && apiData.tracks.isNotEmpty) {
          _playlistCache[entityId] = apiData;
          return apiData;
        }
      } catch (e) {
        debugPrint('Spotify access token fetch error: $e');
      }
    }

    // 2. Try custom Web API credentials if user saved them
    final clientId = await getSavedClientId();
    final clientSecret = await getSavedClientSecret();
    if (clientId != null && clientSecret != null) {
      try {
        data = await _fetchViaWebApi(entityId, clientId, clientSecret);
        _playlistCache[entityId] = data;
        return data;
      } catch (e) {
        debugPrint('Spotify Web API failed; falling back to embed parsing: $e');
      }
    }

    // 3. Fast, tokenless & resilient public embed parsing
    data = await _fetchViaEmbed(entityId, entityType: entityType);
    _playlistCache[entityId] = data;
    return data;
  }

  Future<SpotifyPlaylistData?> _fetchViaAccessToken(
    String entityId, {
    String entityType = 'playlist',
  }) async {
    final token = _accessToken;
    if (token == null || token.isEmpty) return null;
    final path = entityType == 'album'
        ? '/v1/albums/$entityId'
        : '/v1/playlists/$entityId';
    var json = await _spotifyApiGet(path, token);
    if (json == null) {
      if (_refreshToken != null && _refreshToken!.isNotEmpty) {
        if (await _refreshWithRefreshToken() && _accessToken != null) {
          json = await _spotifyApiGet(path, _accessToken!);
        }
      } else if (_cookie != null && _cookie!.isNotEmpty) {
        if (await _exchangeCookieForToken() && _accessToken != null) {
          json = await _spotifyApiGet(path, _accessToken!);
        }
      }
    }
    if (json == null) return null;

    final title = (json['name'] as String?) ?? 'Spotify Playlist';
    final description = (json['description'] as String?) ?? '';
    final owner = (json['owner'] as Map?)?['display_name'] as String?;
    final images = json['images'] as List?;
    String? artworkUrl;
    if (images != null && images.isNotEmpty) {
      final first = images.first;
      if (first is Map) {
        artworkUrl = first['url'] as String?;
      }
    }

    final rawTracks = json['tracks'];
    final items = rawTracks is Map ? (rawTracks['items'] as List?) : (rawTracks as List?);
    final tracks = <SpotifyTrack>[];
    if (items != null) {
      for (final item in items) {
        if (item is! Map) continue;
        final trackMap = entityType == 'album' ? item : (item['track'] as Map?);
        final t = _parseApiTrack(trackMap);
        if (t != null) {
          tracks.add(
            artworkUrl != null && (t.artworkUrl == null || t.artworkUrl!.isEmpty)
                ? SpotifyTrack(
                    id: t.id,
                    title: t.title,
                    artist: t.artist,
                    album: t.album.isEmpty ? title : t.album,
                    durationMs: t.durationMs,
                    artworkUrl: artworkUrl,
                  )
                : t,
          );
        }
      }
    }

    if (tracks.isNotEmpty) {
      return SpotifyPlaylistData(
        id: entityId,
        title: title,
        description: description,
        artworkUrl: artworkUrl,
        owner: owner,
        tracks: tracks,
      );
    }
    return null;
  }

  /// Fetches live tracks from Spotify's featured charts playlist feed for Home discovery.
  Future<List<SpotifyTrack>> fetchFeedTracks({int limit = 12}) async {
    final cached = _cachedFeedTracks;
    if (cached != null && cached.isNotEmpty) {
      return cached.take(limit).toList(growable: false);
    }
    for (final playlist in featuredPlaylists.take(2)) {
      try {
        final data = await fetchPlaylist(playlist.id);
        if (data.tracks.isNotEmpty) {
          _cachedFeedTracks = List<SpotifyTrack>.unmodifiable(data.tracks);
          return data.tracks.take(limit).toList(growable: false);
        }
      } catch (_) {}
    }
    return const [];
  }

  Future<SpotifyPlaylistData> _fetchViaEmbed(
    String entityId, {
    String entityType = 'playlist',
  }) async {
    // 1. Fetch Spotify oEmbed for authoritative title, thumbnail, and author
    String oembedTitle = 'Spotify Playlist';
    String? oembedThumbnail;
    try {
      final oembedUri = Uri.parse(
        'https://open.spotify.com/oembed?url=https://open.spotify.com/$entityType/$entityId',
      );
      final oembedRes = await http.get(oembedUri).timeout(const Duration(seconds: 8));
      if (oembedRes.statusCode == 200) {
        final oData = jsonDecode(oembedRes.body) as Map<String, dynamic>;
        oembedTitle = (oData['title'] as String?)?.trim() ?? oembedTitle;
        oembedThumbnail = (oData['thumbnail_url'] as String?)?.trim();
      }
    } catch (_) {}

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);

    try {
      final request = await client.getUrl(
        Uri.parse('https://open.spotify.com/embed/$entityType/$entityId'),
      );
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      );
      request.headers.set(
        HttpHeaders.acceptHeader,
        'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      );
      request.headers.set(
        HttpHeaders.acceptLanguageHeader,
        'en-US,en;q=0.9',
      );
      final response = await request.close().timeout(const Duration(seconds: 15));

      if (response.statusCode != HttpStatus.ok) {
        return await _fallbackTracksSearch(
          entityId,
          oembedTitle,
          oembedThumbnail,
          entityType: entityType,
        );
      }

      final body = await response.transform(utf8.decoder).join();
      String? rawJson;
      final scriptMatch = RegExp(
        r'<script id="(?:__NEXT_DATA__|initial-state|embed-state)"[^>]*>([^<]+)</script>',
      ).firstMatch(body);
      if (scriptMatch != null) {
        rawJson = scriptMatch.group(1);
      } else {
        final anyJsonScript = RegExp(
          r'<script type="application/json"[^>]*>([^<]+)</script>',
        ).allMatches(body);
        for (final m in anyJsonScript) {
          final content = m.group(1)!;
          if (content.contains('trackList') || content.contains('tracks') || content.contains('entity')) {
            rawJson = content;
            break;
          }
        }
      }

      if (rawJson == null) {
        return await _fallbackTracksSearch(
          entityId,
          oembedTitle,
          oembedThumbnail,
          entityType: entityType,
        );
      }

      final jsonData = jsonDecode(rawJson) as Map<String, dynamic>;
      final entity =
          (jsonData['props']?['pageProps']?['state']?['data']?['entity'] ??
           jsonData['entity'] ??
           jsonData['data']?['entity'])
              as Map<String, dynamic>?;

      if (entity == null) {
        return await _fallbackTracksSearch(
          entityId,
          oembedTitle,
          oembedThumbnail,
          entityType: entityType,
        );
      }

      final name = (entity['name'] as String?) ??
          (entity['title'] as String?) ??
          oembedTitle;
      final subtitle = (entity['subtitle'] as String?) ??
          (entity['description'] as String?) ??
          '';
      final trackList = ((entity['trackList'] ?? entity['tracks']) as List?) ?? const [];

      String? artworkUrl = oembedThumbnail;
      final visualIdentity = entity['visualIdentity'] as Map<String, dynamic>?;
      final images = visualIdentity?['image'] as List?;
      if (images != null && images.isNotEmpty) {
        final last = images.last;
        if (last is Map && last['url'] != null) {
          artworkUrl = last['url'] as String?;
        }
      }
      if (artworkUrl == null) {
        final visual = entity['visual'] as Map<String, dynamic>?;
        final avatarSources = visual?['avatar']?['sources'] as List? ??
            visual?['header']?['sources'] as List?;
        if (avatarSources != null && avatarSources.isNotEmpty) {
          artworkUrl = avatarSources.first['url'] as String?;
        }
      }

      final tracks = <SpotifyTrack>[];
      for (final raw in trackList) {
        if (raw is! Map<String, dynamic>) continue;
        final trackUri = raw['uri'] as String? ?? '';
        final trackId = trackUri.replaceFirst('spotify:track:', '');
        final title = raw['title'] as String? ?? raw['name'] as String? ?? 'Untitled';
        final artist = raw['subtitle'] as String? ??
            raw['artist'] as String? ??
            'Unknown Artist';
        final duration = (raw['duration'] as num?)?.toInt() ??
            (raw['duration_ms'] as num?)?.toInt() ??
            180000;

        tracks.add(
          SpotifyTrack(
            id: trackId.isNotEmpty ? trackId : '$name-$title',
            title: title,
            artist: artist,
            album: name,
            durationMs: duration,
            artworkUrl: artworkUrl,
          ),
        );
      }

      if (tracks.isEmpty) {
        return await _fallbackTracksSearch(
          entityId,
          name,
          artworkUrl,
          entityType: entityType,
        );
      }

      return SpotifyPlaylistData(
        id: entityId,
        title: name,
        description: subtitle,
        artworkUrl: artworkUrl,
        tracks: tracks,
      );
    } catch (e) {
      return await _fallbackTracksSearch(
        entityId,
        oembedTitle,
        oembedThumbnail,
        entityType: entityType,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<SpotifyPlaylistData> _fallbackTracksSearch(
    String entityId,
    String title,
    String? artworkUrl, {
    String entityType = 'playlist',
  }) async {
    final query = title != 'Spotify Playlist' ? title : entityId;
    final tracks = <SpotifyTrack>[];
    try {
      final res = await http
          .get(
            Uri.parse(
              'https://api.deezer.com/search?q=${Uri.encodeComponent(query)}&limit=30',
            ),
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final data = json['data'] as List?;
        if (data != null) {
          for (final item in data) {
            if (item is! Map) continue;
            final tTitle = (item['title'] as String?)?.trim() ?? '';
            final artistMap = item['artist'] as Map?;
            final tArtist = (artistMap?['name'] as String?)?.trim() ?? 'Unknown Artist';
            final albumMap = item['album'] as Map?;
            final tAlbum = (albumMap?['title'] as String?)?.trim() ?? title;
            final art = (albumMap?['cover_medium'] as String?) ?? artworkUrl;
            final dur = ((item['duration'] as num?)?.toInt() ?? 180) * 1000;
            if (tTitle.isNotEmpty) {
              tracks.add(
                SpotifyTrack(
                  id: 'sp_fallback_${item['id'] ?? tTitle}',
                  title: tTitle,
                  artist: tArtist,
                  album: tAlbum,
                  durationMs: dur,
                  artworkUrl: art,
                ),
              );
            }
          }
        }
      }
    } catch (_) {}

    // Resilient fallback 2: YouTube Audio Service search
    if (tracks.isEmpty) {
      try {
        final ytQuery = query.toLowerCase().contains('playlist')
            ? query
            : '$query songs playlist official audio';
        final ytHits = await YoutubeAudioService.instance.search(
          ytQuery,
          filterMixtapes: true,
        );
        for (final y in ytHits.take(30)) {
          if (y.duration.inSeconds >= 45 && y.duration.inSeconds <= 720) {
            tracks.add(
              SpotifyTrack(
                id: 'youtube:${y.id}',
                title: y.title,
                artist: y.author,
                album: title,
                durationMs: y.duration.inMilliseconds,
                artworkUrl: y.thumbnailUrl ?? artworkUrl,
              ),
            );
          }
        }
      } catch (_) {}
    }

    if (tracks.isNotEmpty) {
      return SpotifyPlaylistData(
        id: entityId,
        title: title,
        description: 'Synced playlist tracks',
        artworkUrl: artworkUrl,
        tracks: tracks,
      );
    }

    throw const FormatException('Could not parse Spotify playlist data.');
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
    bool mergeExisting = false,
  }) async {
    // 1. Create or reuse existing playlist in Tone
    var targetName = playlist.title;
    MusicPlaylist? tonePlaylist;
    if (mergeExisting) {
      tonePlaylist = library.playlists
          .where((p) => p.name.toLowerCase() == targetName.toLowerCase())
          .firstOrNull;
    }
    var suffix = 2;
    while (tonePlaylist == null) {
      try {
        tonePlaylist = await library.createPlaylist(targetName);
      } catch (_) {
        targetName = '${playlist.title} ($suffix)';
        suffix++;
      }
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
