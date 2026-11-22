import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:melo_player/features/library/imported_track.dart';

class SoundCloudTrack {
  const SoundCloudTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.durationMs,
    required this.permalinkUrl,
    this.artworkUrl,
    this.genre,
    this.streamUrl,
    this.playbackCount,
    this.likesCount,
  });

  final String id;
  final String title;
  final String artist;
  final int durationMs;
  final String permalinkUrl;
  final String? artworkUrl;
  final String? genre;
  final String? streamUrl;
  final int? playbackCount;
  final int? likesCount;

  ImportedTrack toImportedTrack() {
    return ImportedTrack(
      id: 'soundcloud:$id',
      path: streamUrl ?? permalinkUrl,
      title: title,
      artist: artist,
      album: genre != null && genre!.isNotEmpty ? '$genre Single' : 'SoundCloud',
      durationMs: durationMs,
      artworkUri: artworkUrl,
      genre: genre,
      sourceProvider: 'SoundCloud',
      providerTrackId: id,
      isAvailable: true,
    );
  }
}

class SoundCloudAudioService {
  SoundCloudAudioService._();
  static final SoundCloudAudioService instance = SoundCloudAudioService._();

  static const String _defaultClientId = 'a3e059563d7fd3372b49b37f00a00bcf';
  static const String _backupClientId = 'iZIs9mchVcX5lhVR1OiZAkGCUguLsBXK';
  String _activeClientId = _defaultClientId;

  final http.Client _client = http.Client();
  final Map<String, String> _resolvedStreamCache = {};

  /// Searches SoundCloud for public tracks matching [query].
  Future<List<SoundCloudTrack>> search(String query, {int limit = 20}) async {
    final clean = query.trim();
    if (clean.isEmpty) return const [];

    try {
      final uri = Uri.parse('https://api-v2.soundcloud.com/search/tracks').replace(
        queryParameters: {
          'q': clean,
          'client_id': _activeClientId,
          'limit': '$limit',
          'linked_partitioning': '1',
        },
      );

      var response = await _client.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 401 && _activeClientId != _backupClientId) {
        _activeClientId = _backupClientId;
        final retryUri = uri.replace(queryParameters: {
          ...uri.queryParameters,
          'client_id': _backupClientId,
        });
        response = await _client.get(retryUri).timeout(const Duration(seconds: 8));
      }

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final collection = json['collection'] as List?;
        if (collection != null) {
          return _parseTracks(collection);
        }
      }
    } catch (e) {
      debugPrint('SoundCloud search error: $e');
    }
    return const [];
  }

  /// Fetches the SoundCloud Trending / Hot & New charts.
  Future<List<SoundCloudTrack>> fetchTrendingCharts({
    String genre = 'soundcloud:genres:all-music',
    int limit = 50,
  }) async {
    try {
      final uri = Uri.parse('https://api-v2.soundcloud.com/charts').replace(
        queryParameters: {
          'kind': 'top',
          'genre': genre,
          'client_id': _activeClientId,
          'limit': '$limit',
        },
      );

      var response = await _client.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 401 && _activeClientId != _backupClientId) {
        _activeClientId = _backupClientId;
        final retryUri = uri.replace(queryParameters: {
          ...uri.queryParameters,
          'client_id': _backupClientId,
        });
        response = await _client.get(retryUri).timeout(const Duration(seconds: 8));
      }

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final collection = json['collection'] as List?;
        if (collection != null) {
          final tracksList = <dynamic>[];
          for (final item in collection) {
            if (item is Map && item['track'] != null) {
              tracksList.add(item['track']);
            }
          }
          return _parseTracks(tracksList);
        }
      }
    } catch (e) {
      debugPrint('SoundCloud trending charts error: $e');
    }
    return const [];
  }

  /// Resolves the direct, playable progressive audio stream URL for a track.
  Future<String?> resolveStreamUrl(Map<String, dynamic> trackJson) async {
    final trackId = trackJson['id']?.toString() ?? '';
    if (trackId.isNotEmpty && _resolvedStreamCache.containsKey(trackId)) {
      return _resolvedStreamCache[trackId];
    }

    try {
      final media = trackJson['media'] as Map?;
      final transcodings = media?['transcodings'] as List?;
      if (transcodings == null || transcodings.isEmpty) return null;

      // Prefer progressive mp3 audio for fast direct playback and downloads
      Map? progressive;
      Map? hls;
      for (final t in transcodings) {
        if (t is! Map) continue;
        final format = t['format'] as Map?;
        final protocol = format?['protocol'] as String?;
        if (protocol == 'progressive') {
          progressive = t;
          break;
        } else if (protocol == 'hls') {
          hls ??= t;
        }
      }

      final chosen = progressive ?? hls;
      final targetUrl = chosen?['url'] as String?;
      if (targetUrl == null) return null;

      final signUri = Uri.parse(targetUrl).replace(
        queryParameters: {'client_id': _activeClientId},
      );

      final signRes = await _client.get(signUri).timeout(const Duration(seconds: 6));
      if (signRes.statusCode == 200) {
        final signJson = jsonDecode(signRes.body) as Map<String, dynamic>;
        final directStream = signJson['url'] as String?;
        if (directStream != null && directStream.isNotEmpty) {
          if (trackId.isNotEmpty) {
            _resolvedStreamCache[trackId] = directStream;
          }
          return directStream;
        }
      }
    } catch (e) {
      debugPrint('SoundCloud stream resolution error: $e');
    }
    return null;
  }

  List<SoundCloudTrack> _parseTracks(List rawList) {
    final result = <SoundCloudTrack>[];
    for (final item in rawList) {
      if (item is! Map) continue;
      final id = item['id']?.toString() ?? '';
      final title = (item['title'] as String?)?.trim() ?? '';
      final user = item['user'] as Map?;
      final artist = (user?['username'] as String?)?.trim() ?? 'SoundCloud Artist';
      final durationMs = (item['duration'] as num?)?.toInt() ?? 180000;
      final permalink = (item['permalink_url'] as String?) ?? '';
      final genre = item['genre'] as String?;

      String? art = item['artwork_url'] as String?;
      if (art != null && art.isNotEmpty) {
        art = art.replaceAll('-large.', '-t500x500.');
      } else {
        final avatar = user?['avatar_url'] as String?;
        if (avatar != null && avatar.isNotEmpty) {
          art = avatar.replaceAll('-large.', '-t500x500.');
        }
      }

      if (id.isNotEmpty && title.isNotEmpty) {
        result.add(
          SoundCloudTrack(
            id: id,
            title: title,
            artist: artist,
            durationMs: durationMs,
            permalinkUrl: permalink,
            artworkUrl: art,
            genre: genre,
            playbackCount: (item['playback_count'] as num?)?.toInt(),
            likesCount: (item['likes_count'] as num?)?.toInt(),
          ),
        );
      }
    }
    return result;
  }
}
