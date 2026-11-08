import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:melo_player/features/youtube/youtube_audio_service.dart';

class YoutubeAuthService {
  YoutubeAuthService._();
  static final YoutubeAuthService instance = YoutubeAuthService._();

  static const String _cookiePrefKey = 'tone_yt_auth_cookie';
  static const String _namePrefKey = 'tone_yt_account_name';
  static const String _avatarPrefKey = 'tone_yt_account_avatar';
  static const String _genresPrefKey = 'tone_yt_favorite_genres';

  String? _cookie;
  String? _accountName;
  String? _avatarUrl;
  List<String> _favoriteGenres = [
    'Hip-Hop',
    'Electronic',
    'R&B',
    'Rock',
    'Pop',
    'Indie',
  ];

  bool get isLoggedIn => _cookie != null && _cookie!.isNotEmpty;
  String? get accountName => _accountName;
  String? get avatarUrl => _avatarUrl;
  String? get rawCookie => _cookie;
  List<String> get favoriteGenres => List.unmodifiable(_favoriteGenres);

  final ValueNotifier<bool> authState = ValueNotifier<bool>(false);

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _cookie = prefs.getString(_cookiePrefKey);
    _accountName = prefs.getString(_namePrefKey);
    _avatarUrl = prefs.getString(_avatarPrefKey);
    final savedGenres = prefs.getStringList(_genresPrefKey);
    if (savedGenres != null && savedGenres.isNotEmpty) {
      _favoriteGenres = savedGenres;
    }
    authState.value = isLoggedIn;
  }

  /// Generates the standard Innertube SHA1 Authorization header from SAPISID cookie.
  String? _generateSapisidHash(String cookie, String origin) {
    final match = RegExp(r'(?:SAPISID|__Secure-3PAPISID)=([^;]+)').firstMatch(cookie);
    if (match == null) return null;
    final sapisid = match.group(1)?.trim();
    if (sapisid == null || sapisid.isEmpty) return null;

    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final payload = '$timestamp $sapisid $origin';
    final hash = sha1.convert(utf8.encode(payload)).toString();
    return 'SAPISIDHASH ${timestamp}_$hash';
  }

  Map<String, String> getAuthHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    };

    if (_cookie != null && _cookie!.isNotEmpty) {
      headers['Cookie'] = _cookie!;
      const origin = 'https://music.youtube.com';
      headers['X-Origin'] = origin;
      final auth = _generateSapisidHash(_cookie!, origin);
      if (auth != null) {
        headers['Authorization'] = auth;
      }
    }

    return headers;
  }

  static const MethodChannel _channel = MethodChannel('app.melo.melo_player/library');

  /// Launches in-app Google / YouTube Music sign-in sheet, captures cookies on authentication.
  Future<bool> launchInAppLogin() async {
    try {
      final cookies = await _channel.invokeMethod<String>('openYtMusicLogin');
      if (cookies != null && cookies.isNotEmpty) {
        return await loginWithCookie(cookies);
      }
      return false;
    } catch (e) {
      debugPrint('Error in launchInAppLogin: $e');
      return false;
    }
  }

  /// Connect a YouTube account by providing session cookies from music.youtube.com or youtube.com.
  Future<bool> loginWithCookie(String cookieString) async {
    final cleanCookie = cookieString.trim();
    if (cleanCookie.isEmpty) return false;

    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Cookie': cleanCookie,
        'X-Origin': 'https://music.youtube.com',
      };

      final auth = _generateSapisidHash(cleanCookie, 'https://music.youtube.com');
      if (auth != null) headers['Authorization'] = auth;

      final uri = Uri.parse('https://music.youtube.com/youtubei/v1/browse');
      final payload = {
        'context': {
          'client': {
            'clientName': 'WEB_REMIX',
            'clientVersion': '1.20231201.01.00',
            'hl': 'en',
            'gl': 'US',
          },
        },
        'browseId': 'FEmusic_home',
      };

      final response = await http
          .post(uri, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('YouTube login check returned ${response.statusCode}');
        // If HTTP fails or session invalid, return false
        return false;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      String extractedName = 'YouTube Music User';
      String? extractedAvatar;

      // Extract account avatar and name from topbar if available
      final topbar = json['topbar']?['musicTopBarRenderer'];
      final userImage = topbar?['userAvatar']?['thumbnails'] as List?;
      if (userImage != null && userImage.isNotEmpty) {
        extractedAvatar = userImage.last['url'] as String?;
      }

      _cookie = cleanCookie;
      _accountName = extractedName;
      _avatarUrl = extractedAvatar;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cookiePrefKey, cleanCookie);
      await prefs.setString(_namePrefKey, extractedName);
      if (extractedAvatar != null) {
        await prefs.setString(_avatarPrefKey, extractedAvatar);
      }

      authState.value = true;
      return true;
    } catch (e) {
      debugPrint('YouTube cookie login error: $e');
      return false;
    }
  }

  /// Sign out and clear stored YouTube session cookies.
  Future<void> logout() async {
    _cookie = null;
    _accountName = null;
    _avatarUrl = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cookiePrefKey);
    await prefs.remove(_namePrefKey);
    await prefs.remove(_avatarPrefKey);
    authState.value = false;
  }

  /// Connects using a public YouTube channel or handle without requiring passwords or cookies.
  Future<bool> loginWithChannelHandle(String handle) async {
    final clean = handle.trim().replaceFirst('@', '');
    if (clean.isEmpty) return false;

    try {
      final query = '@$clean';
      final tracks = await YoutubeAudioService.instance.search(query);
      _accountName = '@$clean';
      _avatarUrl = tracks.isNotEmpty ? tracks.first.thumbnailUrl : null;
      _cookie = 'HANDLE_AUTH_$clean';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cookiePrefKey, _cookie!);
      await prefs.setString(_namePrefKey, _accountName!);
      if (_avatarUrl != null) {
        await prefs.setString(_avatarPrefKey, _avatarUrl!);
      }

      authState.value = true;
      return true;
    } catch (e) {
      debugPrint('Error syncing channel handle: $e');
      return false;
    }
  }

  /// Updates user favorite vibe/genre tags to shape personalized taste recommendations.
  Future<void> setFavoriteGenres(List<String> genres) async {
    _favoriteGenres = List.unmodifiable(genres);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_genresPrefKey, genres);
  }

  /// Fetches personalized taste tracks:
  /// - If logged in: fetches from YouTube Music's 'FEmusic_home' (Listen Again, Mixed for You).
  /// - If not logged in: generates smart mixes based on selected favorite genres.
  Future<List<YoutubeTrack>> getPersonalTasteTracks() async {
    if (isLoggedIn) {
      try {
        final uri = Uri.parse('https://music.youtube.com/youtubei/v1/browse');
        final payload = {
          'context': {
            'client': {
              'clientName': 'WEB_REMIX',
              'clientVersion': '1.20231201.01.00',
              'hl': 'en',
              'gl': 'US',
            },
          },
          'browseId': 'FEmusic_home',
        };

        final response = await http
            .post(uri, headers: getAuthHeaders(), body: jsonEncode(payload))
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          final parsed = _parseTracksFromBrowse(json);
          if (parsed.isNotEmpty) return parsed;
        }
      } catch (e) {
        debugPrint('Error fetching personalized YouTube home: $e');
      }
    }

    // Fallback or guest taste: query curated tracks from user's favorite vibes
    final genreQuery = _favoriteGenres.take(3).join(' ');
    return YoutubeAudioService.instance.search('$genreQuery Mix');
  }

  /// Fetches the user's Liked Music from YouTube Music ('LM').
  Future<List<YoutubeTrack>> getLikedMusic({int limit = 50}) async {
    if (!isLoggedIn) return const [];

    try {
      final uri = Uri.parse('https://music.youtube.com/youtubei/v1/browse');
      final payload = {
        'context': {
          'client': {
            'clientName': 'WEB_REMIX',
            'clientVersion': '1.20231201.01.00',
            'hl': 'en',
            'gl': 'US',
          },
        },
        'browseId': 'LM',
      };

      final response = await http
          .post(uri, headers: getAuthHeaders(), body: jsonEncode(payload))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final tracks = _parseTracksFromBrowse(json);
        return tracks.take(limit).toList();
      }
    } catch (e) {
      debugPrint('Error fetching Liked Music from YouTube: $e');
    }
    return const [];
  }

  List<YoutubeTrack> _parseTracksFromBrowse(Map<String, dynamic> json) {
    final results = <YoutubeTrack>[];
    try {
      final contents = json['contents']?['singleColumnBrowseResultsRenderer']
          ?['tabs']?[0]?['tabRenderer']?['content']
          ?['sectionListRenderer']?['contents'] as List?;

      if (contents == null) return const [];

      for (final section in contents) {
        final shelf = section['musicCarouselShelfRenderer'] ??
            section['musicShelfRenderer'];
        if (shelf == null) continue;

        final items = shelf['contents'] as List?;
        if (items == null) continue;

        for (final item in items) {
          final renderer = item['musicResponsiveListItemRenderer'] ??
              item['musicTwoRowItemRenderer'];
          if (renderer == null) continue;

          String? videoId;
          final navEndpoint = renderer['navigationEndpoint'] ??
              renderer['overlay']?['musicItemThumbnailOverlayRenderer']
                  ?['content']?['musicPlayButtonRenderer']
                  ?['playNavigationEndpoint'];
          videoId = navEndpoint?['watchEndpoint']?['videoId'] as String?;

          String title = 'Unknown Title';
          String author = 'YouTube Music';

          if (renderer['flexColumns'] != null) {
            final colList = renderer['flexColumns'] as List;
            if (colList.isNotEmpty) {
              final titleRuns = colList[0]?['musicResponsiveListItemFlexColumnRenderer']
                  ?['text']?['runs'] as List?;
              if (titleRuns != null && titleRuns.isNotEmpty) {
                title = titleRuns.map((r) => r['text'] ?? '').join();
                final nav = titleRuns[0]?['navigationEndpoint']?['watchEndpoint'];
                videoId ??= nav?['videoId'] as String?;
              }
            }
            if (colList.length > 1) {
              final authorRuns = colList[1]
                  ?['musicResponsiveListItemFlexColumnRenderer']?['text']
                  ?['runs'] as List?;
              if (authorRuns != null && authorRuns.isNotEmpty) {
                author = authorRuns.map((r) => r['text'] ?? '').join();
              }
            }
          } else if (renderer['title'] != null) {
            final runs = renderer['title']?['runs'] as List?;
            if (runs != null && runs.isNotEmpty) {
              title = runs.map((r) => r['text'] ?? '').join();
            }
            final subRuns = renderer['subtitle']?['runs'] as List?;
            if (subRuns != null && subRuns.isNotEmpty) {
              author = subRuns.map((r) => r['text'] ?? '').join();
            }
          }

          if (videoId == null || videoId.isEmpty) continue;

          final thumbnails = renderer['thumbnail']?['musicThumbnailRenderer']
              ?['thumbnail']?['thumbnails'] as List?;
          final thumbUrl = thumbnails?.isNotEmpty == true
              ? thumbnails!.last['url'] as String?
              : 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';

          results.add(
            YoutubeTrack(
              id: videoId,
              title: title,
              author: author,
              duration: const Duration(minutes: 3, seconds: 30),
              thumbnailUrl: thumbUrl,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error parsing tracks from YouTube browse JSON: $e');
    }
    return results;
  }
}
