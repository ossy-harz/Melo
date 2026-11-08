import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:melo_player/features/library/imported_track.dart';
import 'package:melo_player/features/library/music_library.dart';
import 'package:melo_player/features/library/song_metadata_enricher.dart';
import 'package:melo_player/features/player/lyrics_repository.dart';
import 'package:melo_player/features/sources/lossless_audio_service.dart';
import 'package:melo_player/features/youtube/youtube_auth_service.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yte;

enum YoutubeAudioQuality {
  highest,
  standard,
  dataSaver,
}

class YoutubeTrack {
  const YoutubeTrack({
    required this.id,
    required this.title,
    required this.author,
    required this.duration,
    this.album,
    this.thumbnailUrl,
    this.viewCount,
  });

  final String id;
  final String title;
  final String author;
  final Duration duration;
  final String? album;
  final String? thumbnailUrl;
  final String? viewCount;

  String get durationString {
    final minutes = duration.inMinutes;
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String get durationFormatted => durationString;

  String get displaySubtitle {
    final cleanAlbum = album?.trim();
    if (cleanAlbum != null &&
        cleanAlbum.isNotEmpty &&
        cleanAlbum != 'YouTube Music' &&
        cleanAlbum.toLowerCase() != title.toLowerCase()) {
      return '$author · $cleanAlbum';
    }
    return author;
  }

  ImportedTrack toImportedTrack({String? streamUrl}) => ImportedTrack(
    id: 'youtube:$id',
    path: streamUrl ?? 'youtube:$id',
    title: title,
    artist: author,
    album: (album != null && album!.trim().isNotEmpty)
        ? album!.trim()
        : 'YouTube Music',
    durationMs: duration.inMilliseconds,
    artworkUri: thumbnailUrl,
    sourceProvider: 'YouTube',
    providerTrackId: id,
    isAvailable: true,
  );

  MediaItem toMediaItem({String? streamUrl}) => MediaItem(
    id: streamUrl ?? 'youtube:$id',
    title: title,
    artist: author,
    album: (album != null && album!.trim().isNotEmpty)
        ? album!.trim()
        : 'YouTube Music',
    duration: duration > Duration.zero ? duration : null,
    artUri: thumbnailUrl == null ? null : Uri.tryParse(thumbnailUrl!),
    extras: {
      'source': 'youtube',
      'isLiveStream': true,
      'providerTrackId': id,
      'videoId': id,
      'streamUrl': ?streamUrl,
    },
  );
}

class YoutubeStreamDetails {
  const YoutubeStreamDetails({
    required this.url,
    required this.mimeType,
    required this.bitrate,
    this.sampleRate = 44100,
    this.channelCount = 2,
    this.codec = 'AAC',
    this.contentLength,
    this.headers = const {
      'User-Agent': _visionOsUserAgent,
      'Accept': '*/*',
      'Accept-Encoding': 'identity',
    },
  });

  final String url;
  final String mimeType;
  final int bitrate;
  final int sampleRate;
  final int channelCount;
  final String codec;
  final int? contentLength;
  final Map<String, String> headers;
}

const String _visionOsUserAgent =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15';
const String _iosUserAgent =
    'com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)';
const String _androidSdklessUserAgent =
    'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip';
const String _vrUserAgent =
    'com.google.android.apps.youtube.vr.oculus/1.62.27 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip';

class _CachedStream {
  const _CachedStream(this.details, this.expiresAt);
  final YoutubeStreamDetails details;
  final DateTime expiresAt;
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class YoutubeAudioService {
  YoutubeAudioService._();
  static final YoutubeAudioService instance = YoutubeAudioService._();

  final Map<String, _CachedStream> _streamCache = {};
  final Map<String, Future<YoutubeStreamDetails>> _inFlightResolutions = {};
  String? _cachedVisitorData;
  DateTime? _visitorDataExpiresAt;
  yte.YoutubeExplode? _ytClient;

  yte.YoutubeExplode get _client => _ytClient ??= yte.YoutubeExplode();

  /// Fetches and caches a clean unencoded session visitorData token from
  /// www.youtube.com/sw.js_data so Innertube VISIONOS/IOS player requests
  /// resolve official YouTube Music tracks in ~600ms with HTTP 200/206.
  Future<String?> _getVisitorData() async {
    if (_cachedVisitorData != null &&
        _visitorDataExpiresAt != null &&
        DateTime.now().isBefore(_visitorDataExpiresAt!)) {
      return _cachedVisitorData;
    }
    try {
      final res = await http
          .get(
            Uri.parse('https://www.youtube.com/sw.js_data'),
            headers: const {
              'User-Agent': _iosUserAgent,
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        var body = res.body;
        if (body.startsWith(")]}'")) {
          body = body.substring(4);
        }
        final data = jsonDecode(body) as List<dynamic>;
        final value = data[0][2][0][0][13] as String?;
        if (value != null && value.isNotEmpty) {
          _cachedVisitorData = value;
          _visitorDataExpiresAt = DateTime.now().add(const Duration(hours: 1));
          return _cachedVisitorData;
        }
      }
    } catch (e) {
      debugPrint('Could not fetch YouTube visitorData: $e');
    }
    return _cachedVisitorData;
  }

  /// Pre-warms stream URLs for top tracks in the background so playback starts instantly.
  Future<void> prefetchStreams(Iterable<String> videoIds) async {
    for (final id in videoIds.take(3)) {
      if (id.isEmpty) continue;
      final cached = _streamCache[id];
      if (cached != null && !cached.isExpired) continue;
      if (_inFlightResolutions.containsKey(id)) continue;
      unawaited(
        getStreamDetails(id).catchError((Object _) {
          return const YoutubeStreamDetails(
            url: '',
            mimeType: 'audio/mp4',
            bitrate: 128000,
          );
        }),
      );
    }
  }

  /// Upgrades low-res thumbnails to crisp 800x800 square cover art or maxresdefault.
  static String cleanThumbnailUrl(String? url, {String? videoId}) {
    if (url != null && url.isNotEmpty) {
      if (url.contains('googleusercontent.com') || url.contains('ggpht.com')) {
        return url.replaceAll(RegExp(r'=w\d+-h\d+.*'), '=w800-h800-l90-rj');
      }
      if (url.contains('i.ytimg.com')) {
        return url
            .replaceAll('hqdefault.jpg', 'maxresdefault.jpg')
            .replaceAll('mqdefault.jpg', 'maxresdefault.jpg')
            .replaceAll('default.jpg', 'maxresdefault.jpg');
      }
      return url;
    }
    if (videoId != null && videoId.isNotEmpty) {
      return 'https://i.ytimg.com/vi/$videoId/maxresdefault.jpg';
    }
    return '';
  }

  /// Detects whether a title or duration corresponds to a long nonstop compilation,
  /// full album rip, DJ mix, or multi-hour set rather than a single song.
  static bool isMixtapeOrNonstop(String title, Duration duration) {
    // If duration is longer than 11 minutes (660 seconds), it's a mix or album.
    if (duration.inSeconds > 660) return true;
    // If duration is shorter than 40 seconds, it's a teaser or snippet.
    if (duration.inSeconds > 0 && duration.inSeconds < 40) return true;

    final lower = title.toLowerCase();
    const blacklist = [
      'nonstop',
      'non-stop',
      'non stop',
      'mixtape',
      'mix tape',
      'dj mix',
      'dj set',
      'club mix',
      'party mix',
      'live set',
      'full set',
      'continuous mix',
      'full album',
      'complete album',
      'megamix',
      'mega mix',
      'audio jukebox',
      'jukebox',
      'compilation',
      'all songs',
      'best songs of',
      'top songs of',
      'greatest hits full',
      'hour mix',
      '1 hour',
      '2 hour',
      '3 hour',
      '10 hour',
      'mashup mix',
      'extended mix set',
    ];
    for (final word in blacklist) {
      if (lower.contains(word)) return true;
    }
    return false;
  }

  /// Searches YouTube Music (official studio songs with album metadata & square artwork)
  /// and YouTube in parallel, returning fast, deduplicated results.
  Future<List<YoutubeTrack>> search(
    String query, {
    bool filterMixtapes = true,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return const [];
    unawaited(_getVisitorData());

    // When filterMixtapes is requested, strictly filter long sets and nonstop compilations.
    final shouldFilter = filterMixtapes;

    try {
      final resultsPair = await Future.wait([
        _searchYoutubeMusicSongs(cleanQuery),
        _searchYoutubeWeb(cleanQuery),
      ]);

      final ytmSongs = resultsPair[0];
      final webVideos = resultsPair[1];

      final combined = <YoutubeTrack>[];
      final seenIds = <String>{};

      for (final track in ytmSongs) {
        if (shouldFilter && isMixtapeOrNonstop(track.title, track.duration)) {
          continue;
        }
        if (track.duration.inSeconds > 0 && track.duration.inSeconds < 30) {
          continue;
        }
        if (seenIds.add(track.id)) {
          combined.add(track);
        }
      }
      for (final track in webVideos) {
        if (shouldFilter && isMixtapeOrNonstop(track.title, track.duration)) {
          continue;
        }
        if (track.duration.inSeconds > 0 && track.duration.inSeconds < 30) {
          continue;
        }
        if (seenIds.add(track.id)) {
          combined.add(track);
        }
      }

      if (combined.isNotEmpty) {
        unawaited(prefetchStreams(combined.take(3).map((t) => t.id)));
      }
      return combined;
    } catch (e) {
      debugPrint('YouTube search error: $e');
      return const [];
    }
  }

  /// Searches specifically for real, long-form DJ mixes and continuous live DJ sets
  /// (e.g., Boiler Room, Afrobeats & Amapiano DJ mixes, Hip-Hop club sets, House sets).
  Future<List<YoutubeTrack>> searchDjMixes(String query) async {
    final clean = query.trim().isEmpty
        ? 'DJ Mix Live Set Nonstop'
        : query.trim();
    final searchQuery = clean.toLowerCase().contains('mix') ||
            clean.toLowerCase().contains('set') ||
            clean.toLowerCase().contains('boiler room')
        ? clean
        : '$clean DJ Mix Nonstop Set';
    try {
      final webResults = await _searchYoutubeWeb(searchQuery);
      final djSets = webResults
          .where((t) => t.duration.inMinutes >= 8)
          .toList(growable: false);
      final finalResults = djSets.isNotEmpty
          ? djSets
          : webResults
              .where((t) => t.duration.inSeconds >= 180)
              .toList(growable: false);
      if (finalResults.isNotEmpty) {
        unawaited(prefetchStreams(finalResults.take(2).map((t) => t.id)));
      }
      return finalResults;
    } catch (e) {
      debugPrint('DJ mix search error: $e');
      return const [];
    }
  }

  Future<List<YoutubeTrack>> _searchYoutubeMusicSongs(String query) async {
    try {
      final uri = Uri.parse(
        'https://music.youtube.com/youtubei/v1/search?prettyPrint=false',
      );
      final payload = {
        'context': {
          'client': {
            'clientName': 'WEB_REMIX',
            'clientVersion': '1.20241111.01.00',
            'hl': 'en',
            'gl': 'US',
          },
        },
        'query': query,
        // Filter specifically for official Songs shelf
        'params': 'EgWKAQIIAWoKEAkQBRAKEAMQBA%3D%3D',
      };

      final response = await http
          .post(
            uri,
            headers: {
              ...YoutubeAuthService.instance.getAuthHeaders(),
              'Origin': 'https://music.youtube.com',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) return const [];

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final tabs =
          json['contents']?['tabbedSearchResultsRenderer']?['tabs'] as List?;
      if (tabs == null || tabs.isEmpty) return const [];

      final results = <YoutubeTrack>[];
      for (final tab in tabs) {
        final sectionContents =
            tab['tabRenderer']?['content']?['sectionListRenderer']?['contents']
                as List?;
        if (sectionContents == null) continue;

        for (final section in sectionContents) {
          final shelfItems =
              section['musicShelfRenderer']?['contents'] as List?;
          if (shelfItems == null) continue;

          for (final item in shelfItems) {
            final renderer =
                item['musicResponsiveListItemRenderer'] as Map<String, dynamic>?;
            if (renderer == null) continue;

            final videoId =
                renderer['playlistItemData']?['videoId'] as String?;
            if (videoId == null || videoId.isEmpty) continue;

            final flexColumns = renderer['flexColumns'] as List?;
            if (flexColumns == null || flexColumns.isEmpty) continue;

            final col0Runs = flexColumns[0]
                    ['musicResponsiveListItemFlexColumnRenderer']?['text']
                ?['runs'] as List?;
            final title =
                col0Runs?.map((r) => r['text'] ?? '').join().trim() ?? '';
            if (title.isEmpty) continue;

            var author = 'YouTube Music';
            String? album;
            var duration = Duration.zero;

            if (flexColumns.length > 1) {
              final col1Runs = flexColumns[1]
                      ['musicResponsiveListItemFlexColumnRenderer']?['text']
                  ?['runs'] as List?;
              if (col1Runs != null) {
                final tokens = col1Runs
                    .map((r) => (r['text'] as String? ?? '').trim())
                    .where((t) => t.isNotEmpty && t != '•' && t != '·')
                    .toList();

                if (tokens.isNotEmpty &&
                    RegExp(r'^\d+:\d+(?::\d+)?$').hasMatch(tokens.last)) {
                  duration = _parseDuration(tokens.removeLast());
                }
                if (tokens.isNotEmpty &&
                    (tokens.first == 'Song' ||
                        tokens.first == 'Video' ||
                        tokens.first == 'Single')) {
                  tokens.removeAt(0);
                }
                if (tokens.isNotEmpty) {
                  author = tokens.first;
                }
                if (tokens.length >= 2) {
                  final candidateAlbum = tokens[1];
                  if (!candidateAlbum.contains('views') &&
                      !candidateAlbum.contains('plays')) {
                    album = candidateAlbum;
                  }
                }
              }
            }

            final thumbs = renderer['thumbnail']?['musicThumbnailRenderer']
                ?['thumbnail']?['thumbnails'] as List?;
            String? thumbUrl;
            if (thumbs != null && thumbs.isNotEmpty) {
              final rawUrl = thumbs.last['url'] as String?;
              if (rawUrl != null) {
                thumbUrl = cleanThumbnailUrl(rawUrl, videoId: videoId);
              }
            }
            thumbUrl ??= cleanThumbnailUrl(null, videoId: videoId);

            results.add(
              YoutubeTrack(
                id: videoId,
                title: title,
                author: author,
                album: album,
                duration: duration,
                thumbnailUrl: thumbUrl,
              ),
            );
          }
        }
      }
      return results;
    } catch (e) {
      debugPrint('YouTube Music song search fallback: $e');
      return const [];
    }
  }

  Future<List<YoutubeTrack>> _searchYoutubeWeb(String query) async {
    try {
      final uri = Uri.parse(
        'https://www.youtube.com/youtubei/v1/search?prettyPrint=false',
      );
      final payload = {
        'context': {
          'client': {
            'clientName': 'WEB',
            'clientVersion': '2.20241111.01.00',
            'hl': 'en',
            'gl': 'US',
          },
        },
        'query': query,
      };

      final response = await http
          .post(
            uri,
            headers: YoutubeAuthService.instance.getAuthHeaders(),
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 7));

      if (response.statusCode != 200) return const [];

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final sections = json['contents']?['twoColumnSearchResultsRenderer']
          ?['primaryContents']?['sectionListRenderer']?['contents'] as List?;

      final results = <YoutubeTrack>[];
      if (sections != null) {
        for (final section in sections) {
          final itemSection =
              section['itemSectionRenderer']?['contents'] as List?;
          if (itemSection == null) continue;

          for (final item in itemSection) {
            final renderer = item['videoRenderer'];
            if (renderer == null) continue;

            final videoId = renderer['videoId'] as String?;
            if (videoId == null) continue;

            final titleRuns = renderer['title']?['runs'] as List?;
            final title =
                titleRuns?.map((r) => r['text'] ?? '').join() ?? 'Unknown title';

            final authorRuns = renderer['ownerText']?['runs'] as List?;
            var author =
                authorRuns?.map((r) => r['text'] ?? '').join() ?? 'YouTube';
            author = author.replaceFirst(RegExp(r'\s*-\s*Topic$'), '').trim();

            final lengthText =
                renderer['lengthText']?['simpleText'] as String? ?? '0:00';
            final duration = _parseDuration(lengthText);

            final thumbnails = renderer['thumbnail']?['thumbnails'] as List?;
            final rawThumb = thumbnails?.isNotEmpty == true
                ? thumbnails!.last['url'] as String?
                : null;
            final thumbUrl = cleanThumbnailUrl(rawThumb, videoId: videoId);

            final viewText =
                renderer['shortViewCountText']?['simpleText'] as String?;

            results.add(
              YoutubeTrack(
                id: videoId,
                title: title,
                author: author,
                duration: duration,
                thumbnailUrl: thumbUrl,
                viewCount: viewText,
              ),
            );
          }
        }
      }
      return results;
    } catch (e) {
      debugPrint('YouTube web search error: $e');
      return const [];
    }
  }

  static const String _qualityPrefKey = 'tone_youtube_audio_quality';

  Future<YoutubeAudioQuality> getPreferredQuality() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_qualityPrefKey);
    return switch (value) {
      'highest' => YoutubeAudioQuality.highest,
      'dataSaver' => YoutubeAudioQuality.dataSaver,
      _ => YoutubeAudioQuality.standard,
    };
  }

  Future<void> setPreferredQuality(YoutubeAudioQuality quality) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_qualityPrefKey, quality.name);
  }

  /// Fast Innertube stream resolver (~600ms) using VISIONOS, IOS, and ANDROID_SDKLESS with visitorData.
  Future<YoutubeStreamDetails?> _resolveInnertubeStream(
    String videoId,
    YoutubeAudioQuality quality,
  ) async {
    final visitorData = await _getVisitorData();

    // 1. VISIONOS client (returns 200 OK on ExoPlayer No-Range GET and 206 on full track without 1MB cutoff)
    final visionDetails = await _queryInnertubePlayer(
      videoId: videoId,
      quality: quality,
      endpoint: 'https://www.youtube.com/youtubei/v1/player?prettyPrint=false',
      userAgent: _visionOsUserAgent,
      visitorData: visitorData,
      extraHeaders: const {
        'X-YouTube-Client-Name': '101',
        'X-YouTube-Client-Version': '0.1',
      },
      clientPayload: {
        'clientName': 'VISIONOS',
        'clientVersion': '0.1',
        'deviceMake': 'Apple',
        'deviceModel': 'RealityDevice14,1',
        'osName': 'visionOS',
        'osVersion': '1.3.21O771',
        'userAgent': _visionOsUserAgent,
        'hl': 'en',
        'gl': 'US',
        'visitorData': ?visitorData,
      },
    );
    if (visionDetails != null &&
        await _probeStreamUrl(visionDetails.url, headers: visionDetails.headers)) {
      return visionDetails;
    }

    // 2. IOS client with visitorData
    final iosDetails = await _queryInnertubePlayer(
      videoId: videoId,
      quality: quality,
      endpoint: 'https://www.youtube.com/youtubei/v1/player?prettyPrint=false',
      userAgent: _iosUserAgent,
      visitorData: visitorData,
      clientPayload: {
        'clientName': 'IOS',
        'clientVersion': '20.10.4',
        'deviceMake': 'Apple',
        'deviceModel': 'iPhone16,2',
        'userAgent': _iosUserAgent,
        'osName': 'IOS',
        'osVersion': '18.3.2.22D82',
        'hl': 'en',
        'gl': 'US',
        'visitorData': ?visitorData,
      },
    );
    if (iosDetails != null &&
        await _probeStreamUrl(iosDetails.url, headers: iosDetails.headers)) {
      return iosDetails;
    }

    // 3. ANDROID_SDKLESS client
    final sdklessDetails = await _queryInnertubePlayer(
      videoId: videoId,
      quality: quality,
      endpoint: 'https://www.youtube.com/youtubei/v1/player?prettyPrint=false',
      userAgent: _androidSdklessUserAgent,
      visitorData: visitorData,
      clientPayload: {
        'clientName': 'ANDROID',
        'clientVersion': '20.10.38',
        'userAgent': _androidSdklessUserAgent,
        'osName': 'Android',
        'osVersion': '11',
        'hl': 'en',
        'gl': 'US',
        'visitorData': ?visitorData,
      },
    );
    if (sdklessDetails != null &&
        await _probeStreamUrl(
          sdklessDetails.url,
          headers: sdklessDetails.headers,
        )) {
      return sdklessDetails;
    }

    // 4. ANDROID_VR client
    final vrDetails = await _queryInnertubePlayer(
      videoId: videoId,
      quality: quality,
      endpoint: 'https://www.youtube.com/youtubei/v1/player?prettyPrint=false',
      userAgent: _vrUserAgent,
      visitorData: visitorData,
      clientPayload: {
        'clientName': 'ANDROID_VR',
        'clientVersion': '1.62.27',
        'deviceMake': 'Oculus',
        'deviceModel': 'Quest 3',
        'androidSdkVersion': 32,
        'userAgent': _vrUserAgent,
        'osName': 'Android',
        'osVersion': '12L',
        'hl': 'en',
        'gl': 'US',
        'visitorData': ?visitorData,
      },
    );
    if (vrDetails != null &&
        await _probeStreamUrl(vrDetails.url, headers: vrDetails.headers)) {
      return vrDetails;
    }

    // 5. Authenticated WEB_REMIX if user logged in
    if (YoutubeAuthService.instance.isLoggedIn) {
      final remixDetails = await _queryInnertubePlayer(
        videoId: videoId,
        quality: quality,
        endpoint:
            'https://music.youtube.com/youtubei/v1/player?prettyPrint=false',
        userAgent:
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        visitorData: visitorData,
        includeAuthHeaders: true,
        clientPayload: {
          'clientName': 'WEB_REMIX',
          'clientVersion': '1.20241111.01.00',
          'hl': 'en',
          'gl': 'US',
        },
      );
      if (remixDetails != null &&
          await _probeStreamUrl(remixDetails.url, headers: remixDetails.headers)) {
        return remixDetails;
      }
    }

    return null;
  }

  Future<YoutubeStreamDetails?> _queryInnertubePlayer({
    required String videoId,
    required YoutubeAudioQuality quality,
    required String endpoint,
    required String userAgent,
    required Map<String, dynamic> clientPayload,
    String? visitorData,
    Map<String, String>? extraHeaders,
    bool includeAuthHeaders = false,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse(endpoint),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': userAgent,
              'X-Goog-Visitor-Id': ?visitorData,
              ...?extraHeaders,
              if (includeAuthHeaders)
                ...YoutubeAuthService.instance.getAuthHeaders(),
            },
            body: jsonEncode({
              'context': {'client': clientPayload},
              'videoId': videoId,
              'contentCheckOk': true,
              'racyCheckOk': true,
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final streamingData = data['streamingData'] as Map<String, dynamic>?;
      if (streamingData == null) return null;

      final adaptiveFormats = (streamingData['adaptiveFormats'] as List?)
          ?.cast<Map<String, dynamic>>()
          .where((f) => (f['mimeType'] as String? ?? '').startsWith('audio/'))
          .where((f) => f['url'] != null)
          .toList();

      if (adaptiveFormats == null || adaptiveFormats.isEmpty) return null;

      Map<String, dynamic> selected;
      switch (quality) {
        case YoutubeAudioQuality.highest:
          adaptiveFormats.sort(
            (a, b) =>
                _safeBitrate(b['bitrate']).compareTo(_safeBitrate(a['bitrate'])),
          );
          selected = adaptiveFormats.first;
        case YoutubeAudioQuality.dataSaver:
          adaptiveFormats.sort(
            (a, b) =>
                _safeBitrate(a['bitrate']).compareTo(_safeBitrate(b['bitrate'])),
          );
          selected = adaptiveFormats.first;
        case YoutubeAudioQuality.standard:
          final mp4Formats = adaptiveFormats
              .where((f) => (f['mimeType'] as String? ?? '').contains('mp4'))
              .toList();
          if (mp4Formats.isNotEmpty) {
            mp4Formats.sort(
              (a, b) => _safeBitrate(b['bitrate'])
                  .compareTo(_safeBitrate(a['bitrate'])),
            );
            selected = mp4Formats.first;
          } else {
            adaptiveFormats.sort(
              (a, b) => _safeBitrate(b['bitrate'])
                  .compareTo(_safeBitrate(a['bitrate'])),
            );
            selected = adaptiveFormats.first;
          }
      }

      final url = selected['url'] as String;
      final mimeType = selected['mimeType'] as String? ?? 'audio/mp4';
      final isMp4 = mimeType.contains('mp4');
      final bitrate = _safeBitrate(selected['bitrate'], 128000);
      final contentLength = int.tryParse(selected['contentLength']?.toString() ?? '');
      final sampleRate =
          int.tryParse(selected['audioSampleRate'] as String? ?? '') ??
              (isMp4 ? 44100 : 48000);

      return YoutubeStreamDetails(
        url: url,
        mimeType: isMp4 ? 'audio/mp4' : 'audio/webm',
        bitrate: bitrate,
        sampleRate: sampleRate,
        channelCount: 2,
        codec: isMp4 ? 'AAC' : 'Opus',
        contentLength: contentLength,
        headers: {
          'User-Agent': userAgent,
          'Accept': '*/*',
          'Accept-Encoding': 'identity',
        },
      );
    } catch (e) {
      debugPrint('Innertube ($userAgent) stream resolution error: $e');
      return null;
    }
  }

  static const List<String> _invidiousMirrors = [
    'https://yt.chocolatemoo53.com',
    'https://inv.nadeko.net',
    'https://invidious.nerdvpn.de',
    'https://invidious.tiekoetter.com',
    'https://invidious.privacyredirect.com',
  ];

  static int _safeBitrate(dynamic val, [int fallback = 0]) {
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? fallback;
    return fallback;
  }

  /// Resolves direct audio stream via public high-availability Invidious mirror pool.
  Future<YoutubeStreamDetails?> _resolveInvidiousStream(
    String videoId,
    YoutubeAudioQuality quality,
  ) async {
    for (final base in _invidiousMirrors) {
      try {
        final res = await http
            .get(
              Uri.parse('$base/api/v1/videos/$videoId?local=true'),
              headers: const {'Accept': 'application/json'},
            )
            .timeout(const Duration(seconds: 4));
        if (res.statusCode != 200) continue;
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final adaptive = (data['adaptiveFormats'] as List?)
            ?.cast<Map<String, dynamic>>()
            .where((f) => (f['type'] as String? ?? '').startsWith('audio/'))
            .where((f) => f['url'] != null)
            .toList();
        if (adaptive == null || adaptive.isEmpty) continue;

        adaptive.sort((a, b) {
          final bitA = _safeBitrate(a['bitrate'], 0);
          final bitB = _safeBitrate(b['bitrate'], 0);
          return bitB.compareTo(bitA);
        });

        final chosen = switch (quality) {
          YoutubeAudioQuality.highest => adaptive.first,
          YoutubeAudioQuality.dataSaver => adaptive.last,
          YoutubeAudioQuality.standard => adaptive.firstWhere(
              (f) => (f['type'] as String? ?? '').contains('mp4'),
              orElse: () => adaptive.first,
            ),
        };

        var url = chosen['url'] as String;
        if (url.startsWith('/')) {
          url = '$base$url';
        }
        final type = chosen['type'] as String? ?? 'audio/mp4';
        final isMp4 = type.contains('mp4');
        final bitrate = _safeBitrate(chosen['bitrate'], 128000);

        return YoutubeStreamDetails(
          url: url,
          mimeType: isMp4 ? 'audio/mp4' : 'audio/webm',
          bitrate: bitrate,
          sampleRate: isMp4 ? 44100 : 48000,
          channelCount: 2,
          codec: isMp4 ? 'AAC' : 'Opus',
        );
      } catch (e) {
        debugPrint('Invidious mirror ($base) resolution error: $e');
        continue;
      }
    }
    return null;
  }

  /// Automatically searches for an un-gated audio/topic upload of the song when official video is bot-guarded.
  Future<YoutubeStreamDetails?> _resolveMatchingAudioStream(
    String videoId,
    YoutubeAudioQuality quality,
  ) async {
    try {
      final oembed = await http
          .get(
            Uri.parse(
              'https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=$videoId&format=json',
            ),
          )
          .timeout(const Duration(seconds: 3));
      if (oembed.statusCode != 200) return null;
      final info = jsonDecode(oembed.body) as Map<String, dynamic>;
      final title = info['title'] as String?;
      final author = info['author_name'] as String?;
      if (title == null || title.isEmpty) return null;

      final cleanTitle = title
          .replaceAll(
            RegExp(
              r'\((?:Official\s*)?(?:Music\s*)?Video.*?\)',
              caseSensitive: false,
            ),
            '',
          )
          .replaceAll(RegExp(r'\[.*?\]'), '')
          .trim();
      final query = author != null && !cleanTitle.contains(author)
          ? '$cleanTitle $author Audio'
          : '$cleanTitle Audio';

      final searchResults = await _searchYoutubeWeb(query);
      for (final alt in searchResults.take(3)) {
        if (alt.id == videoId) continue;
        final direct = await _resolveInnertubeStream(alt.id, quality);
        if (direct != null) return direct;
      }
    } catch (e) {
      debugPrint('Matching audio stream fallback error: $e');
    }
    return null;
  }

  /// Extracts detailed stream info (playable URL, codec, bitrate, signed headers) for a YouTube video.
  Future<YoutubeStreamDetails> getStreamDetails(
    String videoId, {
    YoutubeAudioQuality? quality,
  }) async {
    final cached = _streamCache[videoId];
    if (cached != null && !cached.isExpired) {
      return cached.details;
    }

    final existingInFlight = _inFlightResolutions[videoId];
    if (existingInFlight != null) {
      return existingInFlight;
    }

    final future = _resolveStreamDetailsInternal(videoId, quality: quality);
    _inFlightResolutions[videoId] = future;
    try {
      return await future;
    } finally {
      _inFlightResolutions.remove(videoId);
    }
  }

  Future<YoutubeStreamDetails> _resolveStreamDetailsInternal(
    String videoId, {
    YoutubeAudioQuality? quality,
  }) async {
    final preferredQuality = quality ?? await getPreferredQuality();

    // 1. Fast Innertube VISIONOS / IOS / ANDROID_SDKLESS resolution (~600ms)
    final innertubeDetails =
        await _resolveInnertubeStream(videoId, preferredQuality);
    if (innertubeDetails != null) {
      _streamCache[videoId] = _CachedStream(
        innertubeDetails,
        DateTime.now().add(const Duration(hours: 4)),
      );
      return innertubeDetails;
    }

    // 2. Client-deciphered stream via youtube_explode_dart (signed for device IP)
    try {
      final manifest = await _client.videos.streamsClient.getManifest(videoId);
      final audioStreams = manifest.audioOnly.toList();
      if (audioStreams.isNotEmpty) {
        yte.AudioOnlyStreamInfo streamInfo;
        switch (preferredQuality) {
          case YoutubeAudioQuality.highest:
            final mp4Streams =
                audioStreams.where((s) => s.container.name == 'mp4').toList();
            streamInfo = mp4Streams.isNotEmpty
                ? mp4Streams.withHighestBitrate()
                : audioStreams.withHighestBitrate();
          case YoutubeAudioQuality.dataSaver:
            streamInfo = audioStreams.reduce(
              (curr, next) =>
                  curr.bitrate.bitsPerSecond < next.bitrate.bitsPerSecond
                      ? curr
                      : next,
            );
          case YoutubeAudioQuality.standard:
            final mp4Streams =
                audioStreams.where((s) => s.container.name == 'mp4').toList();
            streamInfo = mp4Streams.isNotEmpty
                ? mp4Streams.withHighestBitrate()
                : audioStreams.withHighestBitrate();
        }

        final streamUrl = streamInfo.url.toString();
        final isMp4 = streamInfo.container.name == 'mp4';
        final details = YoutubeStreamDetails(
          url: streamUrl,
          mimeType: isMp4 ? 'audio/mp4' : 'audio/webm',
          bitrate: streamInfo.bitrate.bitsPerSecond,
          sampleRate: isMp4 ? 44100 : 48000,
          channelCount: 2,
          codec: isMp4 ? 'AAC' : 'Opus',
          contentLength: streamInfo.size.totalBytes,
          headers: const {
            'User-Agent': _androidSdklessUserAgent,
            'Accept': '*/*',
            'Accept-Encoding': 'identity',
          },
        );
        if (await _probeStreamUrl(details.url, headers: details.headers)) {
          _streamCache[videoId] = _CachedStream(
            details,
            DateTime.now().add(const Duration(hours: 4)),
          );
          return details;
        }
      }
    } catch (e) {
      debugPrint('YouTube client manifest resolution failed: $e');
    }

    // 3. High-availability Invidious proxy stream
    final invidiousDetails =
        await _resolveInvidiousStream(videoId, preferredQuality);
    if (invidiousDetails != null &&
        await _probeStreamUrl(
          invidiousDetails.url,
          headers: invidiousDetails.headers,
        )) {
      _streamCache[videoId] = _CachedStream(
        invidiousDetails,
        DateTime.now().add(const Duration(hours: 4)),
      );
      return invidiousDetails;
    }

    // 4. Matching audio / topic track fallback
    final matchingDetails =
        await _resolveMatchingAudioStream(videoId, preferredQuality);
    if (matchingDetails != null) {
      _streamCache[videoId] = _CachedStream(
        matchingDetails,
        DateTime.now().add(const Duration(hours: 4)),
      );
      return matchingDetails;
    }

    throw StateError(
      'Unable to resolve playable audio stream for YouTube video $videoId.',
    );
  }

  /// Verifies whether an audio stream URL can actually be streamed via HTTP Range requests,
  /// closing the probe connection immediately so the stream token is never held open.
  Future<bool> _probeStreamUrl(
    String url, {
    Map<String, String>? headers,
  }) async {
    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(url));
      req.headers.addAll({
        'Range': 'bytes=0-1024',
        ...?headers,
      });
      final res = await client
          .send(req)
          .timeout(const Duration(seconds: 3));
      return res.statusCode == 200 || res.statusCode == 206;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }

  void clearStreamCache(String videoId) {
    _streamCache.remove(videoId);
  }

  /// Attempts to resolve an alternative working stream when an active playback stream errors out.
  Future<YoutubeStreamDetails?> getFallbackStream(String videoId) async {
    clearStreamCache(videoId);
    final fresh = await _resolveInnertubeStream(
      videoId,
      YoutubeAudioQuality.standard,
    );
    if (fresh != null) {
      _streamCache[videoId] = _CachedStream(
        fresh,
        DateTime.now().add(const Duration(hours: 4)),
      );
      return fresh;
    }

    final match = await _resolveMatchingAudioStream(
      videoId,
      YoutubeAudioQuality.standard,
    );
    if (match != null) {
      _streamCache[videoId] = _CachedStream(
        match,
        DateTime.now().add(const Duration(hours: 4)),
      );
      return match;
    }
    return null;
  }

  /// Extracts the direct playable audio stream URL for a YouTube video.
  Future<String> getAudioStreamUrl(String videoId) async {
    final details = await getStreamDetails(videoId);
    return details.url;
  }

  /// Streams full audio bytes using 512 KB closed Range chunks so Googlevideo
  /// serves at unthrottled speed (~2.5s per track) without HTTP 403.
  Stream<List<int>> streamAudioBytes(
    YoutubeStreamDetails details, {
    ValueChanged<double>? onProgress,
  }) async* {
    final client = http.Client();
    try {
      final totalLen = details.contentLength ?? 0;
      if (totalLen > 0) {
        var downloaded = 0;
        const chunkSize = 524288; // 512 KB
        while (downloaded < totalLen) {
          final end = math.min(downloaded + chunkSize - 1, totalLen - 1);
          final req = http.Request('GET', Uri.parse(details.url));
          req.headers.addAll(details.headers);
          req.headers['Range'] = 'bytes=$downloaded-$end';
          final res = await client
              .send(req)
              .timeout(const Duration(seconds: 15));
          if (res.statusCode != 200 && res.statusCode != 206) {
            throw StateError(
              'Audio download failed at byte $downloaded (HTTP ${res.statusCode})',
            );
          }
          await for (final chunk in res.stream) {
            downloaded += chunk.length;
            onProgress?.call((downloaded / totalLen).clamp(0.01, 1.0));
            yield chunk;
          }
        }
        return;
      }

      // Fallback when contentLength is not advertised up-front
      final req = http.Request('GET', Uri.parse(details.url));
      req.headers.addAll(details.headers);
      final res = await client.send(req).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200 && res.statusCode != 206) {
        throw StateError('Audio download failed (HTTP ${res.statusCode})');
      }
      final streamTotal = res.contentLength ?? 0;
      var received = 0;
      await for (final chunk in res.stream) {
        received += chunk.length;
        if (streamTotal > 0) {
          onProgress?.call((received / streamTotal).clamp(0.01, 1.0));
        }
        yield chunk;
      }
    } finally {
      client.close();
    }
  }

  /// Fetches continuous related / radio recommendations for a given YouTube track or artist.
  Future<List<YoutubeTrack>> getRelatedTracks(
    String videoId, {
    String? artist,
    String? title,
  }) async {
    final related = <YoutubeTrack>[];
    final seenIds = <String>{videoId};

    // 1. Search similar tracks via YouTube Music songs API for fast, clean studio tracks
    final query = (artist != null &&
            artist.isNotEmpty &&
            title != null &&
            title.isNotEmpty)
        ? '$artist $title'
        : (artist != null && artist.isNotEmpty)
            ? '$artist top songs'
            : '${title ?? ''} music';

    try {
      final searchResults = await search(query);
      for (final t in searchResults) {
        if (!seenIds.contains(t.id)) {
          seenIds.add(t.id);
          related.add(t);
        }
        if (related.length >= 10) break;
      }
      if (related.isNotEmpty) return related;
    } catch (e) {
      debugPrint('Related search failed: $e');
    }

    return related;
  }

  /// Downloads a YouTube track directly to the user's device (Music/Tone) and Tone's library,
  /// complete with studio metadata, 1000x1000 cover artwork, and synchronized .lrc lyrics.
  Future<ImportedTrack> downloadTrack({
    required YoutubeTrack track,
    required MusicLibrary library,
    required ValueChanged<double> onProgress,
    LosslessAudioQuality? qualityOverride,
  }) async {
    // 0. Coordinate with device library to avoid duplicate downloads
    final existing = library.findMatchingLocalTrack(
      providerTrackId: track.id,
      title: track.title,
      artist: track.author,
    );
    if (existing != null) {
      debugPrint(
        'Track "${track.title}" is already on device: ${existing.path}',
      );
      onProgress(1.0);
      return existing;
    }

    final targetQuality =
        qualityOverride ?? await LosslessAudioService.instance.getPreferredQuality();
    final streamQuality = targetQuality == LosslessAudioQuality.standard
        ? YoutubeAudioQuality.standard
        : YoutubeAudioQuality.highest;

    // 1. Resolve master stream AND full studio metadata + high-res artwork + synced lyrics in parallel
    final streamFuture = getStreamDetails(
      track.id,
      quality: streamQuality,
    );
    final metadataFuture = SongMetadataEnricher.instance.fetchFullMetadata(
      title: track.title,
      artist: track.author,
      album: track.album,
      durationMs: track.duration.inMilliseconds,
      fallbackArtworkUrl: track.thumbnailUrl,
      artworkDirectory: library.musicDirectory,
      trackIdForCache: track.id,
    );

    final details = await streamFuture;
    final enriched = await metadataFuture;

    final ext = details.codec == 'AAC' ? 'm4a' : 'webm';
    final safeArtist = enriched.artist
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .trim();
    final safeTitle = enriched.title
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .trim();
    final fileName = safeArtist.isNotEmpty &&
            !safeTitle.toLowerCase().startsWith(safeArtist.toLowerCase())
        ? '$safeArtist - $safeTitle.$ext'
        : '$safeTitle.$ext';

    // 2. Stream audio via fast 512 KB Range chunks and convert to Lossless FLAC (.flac) when chosen
    final byteStream = streamAudioBytes(details, onProgress: onProgress);

    final imported = await library.importLicensedDownload(
      provider: 'YouTube',
      providerTrackId: track.id,
      fileName: fileName,
      bytes: byteStream,
      title: enriched.title,
      artist: enriched.artist,
      album: enriched.album,
      durationMs: enriched.durationMs ?? track.duration.inMilliseconds,
      artworkUri: enriched.localArtworkUri ?? enriched.artworkUrl ?? track.thumbnailUrl,
      year: enriched.year ?? DateTime.now().year,
      genre: enriched.genre,
      trackNumber: enriched.trackNumber,
      licenseUrl: 'https://music.youtube.com/watch?v=${track.id}',
      convertToFlac: targetQuality == LosslessAudioQuality.flacHiRes,
    );

    // 3. Persist synchronized offline lyrics (.lrc) on disk and in LyricsRepository cache
    final lrcContent = enriched.lyricsContent;
    if (lrcContent != null && lrcContent.trim().isNotEmpty) {
      try {
        final dotIndex = imported.path.lastIndexOf('.');
        final lrcPath = dotIndex > 0
            ? '${imported.path.substring(0, dotIndex)}.lrc'
            : '${imported.path}.lrc';
        await File(lrcPath).writeAsString(lrcContent, flush: true);
        await LyricsRepository.cacheLyricsForId(imported.id, lrcContent);
        await LyricsRepository.cacheLyricsForId(imported.path, lrcContent);
        await LyricsRepository.cacheLyricsForId('youtube:${track.id}', lrcContent);
        await LyricsRepository.cacheLyricsForSong(
          title: enriched.title,
          artist: enriched.artist,
          rawLrc: lrcContent,
        );
      } catch (e) {
        debugPrint('Could not save offline lyrics file: $e');
      }
    }

    onProgress(1.0);
    return imported;
  }

  static Duration _parseDuration(String text) {
    final parts =
        text.split(':').map((e) => int.tryParse(e.trim()) ?? 0).toList();
    if (parts.length == 3) {
      return Duration(hours: parts[0], minutes: parts[1], seconds: parts[2]);
    } else if (parts.length == 2) {
      return Duration(minutes: parts[0], seconds: parts[1]);
    }
    return Duration.zero;
  }
}
