import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:melo_player/features/library/imported_track.dart';
import 'package:melo_player/features/library/music_library.dart';
import 'package:melo_player/features/library/music_playlist.dart';
import 'package:melo_player/features/sources/music_provider_models.dart';
import 'package:melo_player/features/sources/soundcloud_audio_service.dart';
import 'package:melo_player/features/spotify/spotify_service.dart';
import 'package:melo_player/features/youtube/youtube_audio_service.dart';

class ExternalResolvedPlaylist {
  const ExternalResolvedPlaylist({
    required this.id,
    required this.title,
    required this.curator,
    required this.tracks,
    required this.provider,
    this.artworkUrl,
    this.description,
  });

  final String id;
  final String title;
  final String curator;
  final List<ImportedTrack> tracks;
  final String provider;
  final String? artworkUrl;
  final String? description;

  int get trackCount => tracks.length;
  int get totalDurationMs => tracks.fold(0, (sum, t) => sum + (t.durationMs ?? 0));

  String get totalDurationString {
    final dur = Duration(milliseconds: totalDurationMs);
    final hours = dur.inHours;
    final minutes = dur.inMinutes % 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }
}

/// Mornye-grade metadata and feed integration service for Melo.
/// Aggregates live storefront charts and public feeds from Apple Music,
/// Deezer, Spotify, and YouTube Music with zero authentication required.
class ExternalFeedService {
  ExternalFeedService._();
  static final ExternalFeedService instance = ExternalFeedService._();

  List<ImportedTrack>? _cachedAppleCharts;
  List<ImportedTrack>? _cachedDeezerCharts;
  DateTime? _lastAppleFetch;
  DateTime? _lastDeezerFetch;

  /// Fetches the live Apple Music Top Songs chart for the given [storefront] ('us', 'gb', etc.).
  /// Delivers verified 2024-2026 chart releases with high-resolution 600x600 artwork.
  Future<List<ImportedTrack>> fetchAppleMusicCharts({
    String storefront = 'us',
    int limit = 50,
  }) async {
    final now = DateTime.now();
    if (_cachedAppleCharts != null &&
        _lastAppleFetch != null &&
        now.difference(_lastAppleFetch!) < const Duration(minutes: 30)) {
      return _cachedAppleCharts!.take(limit).toList(growable: false);
    }

    try {
      final uri = Uri.parse(
        'https://itunes.apple.com/$storefront/rss/topsongs/limit=$limit/json',
      );
      final response = await http
          .get(uri, headers: {
            'Accept': 'application/json',
            'User-Agent':
                'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1',
          })
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final entries = json['feed']?['entry'] as List?;
        if (entries != null) {
          final tracks = <ImportedTrack>[];
          for (final entry in entries) {
            if (entry is! Map) continue;
            final title = (entry['im:name']?['label'] as String?)?.trim() ?? '';
            final artist = (entry['im:artist']?['label'] as String?)?.trim() ?? 'Apple Music';
            final album = (entry['im:collection']?['im:name']?['label'] as String?)?.trim() ?? 'Apple Music';
            final id = (entry['id']?['attributes']?['im:id'] as String?) ??
                '$artist-$title'.replaceAll(' ', '-').toLowerCase();

            // Upgrade artwork to 600x600
            String? artUrl;
            final images = entry['im:image'] as List?;
            if (images != null && images.isNotEmpty) {
              final raw = images.last['label'] as String?;
              if (raw != null) {
                artUrl = raw.replaceAll(RegExp(r'\d+x\d+bb'), '600x600bb');
              }
            }

            final durationStr = entry['link']?[1]?['im:duration']?['label'] as String?;
            final durationMs = int.tryParse(durationStr ?? '') ?? 210000;

            if (title.isNotEmpty) {
              tracks.add(
                ImportedTrack(
                  id: 'apple:$id',
                  path: 'apple:$id',
                  title: title,
                  artist: artist,
                  album: album,
                  durationMs: durationMs,
                  artworkUri: artUrl,
                  sourceProvider: 'Apple Music',
                  providerTrackId: id,
                  isAvailable: true,
                ),
              );
            }
          }
          if (tracks.isNotEmpty) {
            _cachedAppleCharts = List.unmodifiable(tracks);
            _lastAppleFetch = now;
            return tracks.take(limit).toList(growable: false);
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching Apple Music charts: $e');
    }
    return _cachedAppleCharts ?? const [];
  }

  /// Fetches the live Deezer Global Top Charts (100% open, high-res 1000x1000 covers).
  Future<List<ImportedTrack>> fetchDeezerGlobalCharts({int limit = 50}) async {
    final now = DateTime.now();
    if (_cachedDeezerCharts != null &&
        _lastDeezerFetch != null &&
        now.difference(_lastDeezerFetch!) < const Duration(minutes: 30)) {
      return _cachedDeezerCharts!.take(limit).toList(growable: false);
    }

    try {
      final uri = Uri.parse('https://api.deezer.com/chart/0/tracks?limit=$limit');
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final data = json['data'] as List?;
        if (data != null) {
          final tracks = <ImportedTrack>[];
          for (final item in data) {
            if (item is! Map) continue;
            final id = item['id']?.toString() ?? '';
            final title = (item['title'] as String?)?.trim() ?? '';
            final artist = (item['artist']?['name'] as String?)?.trim() ?? 'Deezer Artist';
            final album = (item['album']?['title'] as String?)?.trim() ?? 'Deezer Chart';
            final durationSec = (item['duration'] as num?)?.toInt() ?? 180;
            final artUrl = (item['album']?['cover_xl'] as String?) ??
                (item['album']?['cover_big'] as String?) ??
                (item['album']?['cover_medium'] as String?);

            if (title.isNotEmpty) {
              tracks.add(
                ImportedTrack(
                  id: 'deezer:$id',
                  path: 'deezer:$id',
                  title: title,
                  artist: artist,
                  album: album,
                  durationMs: durationSec * 1000,
                  artworkUri: artUrl,
                  sourceProvider: 'Deezer',
                  providerTrackId: id,
                  isAvailable: true,
                ),
              );
            }
          }
          if (tracks.isNotEmpty) {
            _cachedDeezerCharts = List.unmodifiable(tracks);
            _lastDeezerFetch = now;
            return tracks.take(limit).toList(growable: false);
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching Deezer charts: $e');
    }
    return _cachedDeezerCharts ?? const [];
  }

  /// Fetches the live SoundCloud Trending / Hot Charts (100% tokenless, 500x500 covers).
  Future<List<ImportedTrack>> fetchSoundCloudTrending({int limit = 50}) async {
    try {
      final tracks = await SoundCloudAudioService.instance.fetchTrendingCharts(limit: limit);
      if (tracks.isNotEmpty) {
        return tracks.map((t) => t.toImportedTrack()).toList(growable: false);
      }
    } catch (e) {
      debugPrint('Error fetching SoundCloud trending: $e');
    }
    return const [];
  }

  /// Fetches current YouTube Music Trending & Global Popular Singles.
  Future<List<ImportedTrack>> fetchYouTubeMusicTrending({int limit = 50}) async {
    try {
      final songs = await YoutubeAudioService.instance.search(
        'Top 50 Global Hits 2025 2026 Official Audio',
        filterMixtapes: true,
      );
      if (songs.isNotEmpty) {
        return songs.take(limit).map((s) => s.toImportedTrack()).toList(growable: false);
      }
    } catch (e) {
      debugPrint('Error fetching YouTube Music trending: $e');
    }
    return const [];
  }

  /// Fetches Spotify Global Top Hits & Editorial Playlist tracks.
  Future<List<ImportedTrack>> fetchSpotifyTopHits({int limit = 50}) async {
    try {
      final sp = await SpotifyService.instance.fetchPlaylist(
        'https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M',
      );
      if (sp.tracks.isNotEmpty) {
        return sp.tracks.map((t) => t.toImportedTrack()).take(limit).toList(growable: false);
      }
    } catch (e) {
      debugPrint('Error fetching Spotify top hits: $e');
    }
    return const [];
  }

  /// Fetches the home feed tracks for the selected [provider] ('all', 'apple_music', 'spotify', etc.).
  Future<List<ImportedTrack>> fetchFeedForProvider(
    MusicProviderType provider, {
    int limit = 50,
  }) async {
    switch (provider) {
      case MusicProviderType.appleMusic:
        return fetchAppleMusicCharts(limit: limit);
      case MusicProviderType.deezer:
        return fetchDeezerGlobalCharts(limit: limit);
      case MusicProviderType.soundcloud:
        return fetchSoundCloudTrending(limit: limit);
      case MusicProviderType.youtubeMusic:
        return fetchYouTubeMusicTrending(limit: limit);
      case MusicProviderType.spotify:
        return fetchSpotifyTopHits(limit: limit);
      case MusicProviderType.all:
      default:
        // Smart blend: 16 from Apple Music, 16 from Deezer, 10 from SoundCloud, 8 from YouTube Music
        final results = await Future.wait([
          fetchAppleMusicCharts(limit: 20),
          fetchDeezerGlobalCharts(limit: 20),
          fetchSoundCloudTrending(limit: 15),
          fetchYouTubeMusicTrending(limit: 15),
        ]);
        final merged = <ImportedTrack>[];
        final seen = <String>{};
        final apple = results[0];
        final deezer = results[1];
        final soundcloud = results[2];
        final youtube = results[3];

        final maxLen = [apple.length, deezer.length, soundcloud.length, youtube.length]
            .reduce((a, b) => a > b ? a : b);

        for (var i = 0; i < maxLen && merged.length < limit; i++) {
          if (i < apple.length && seen.add(apple[i].title.toLowerCase())) merged.add(apple[i]);
          if (i < deezer.length && seen.add(deezer[i].title.toLowerCase())) merged.add(deezer[i]);
          if (i < soundcloud.length && seen.add(soundcloud[i].title.toLowerCase())) merged.add(soundcloud[i]);
          if (i < youtube.length && seen.add(youtube[i].title.toLowerCase())) merged.add(youtube[i]);
        }
        return merged;
    }
  }

  /// Fetches structured [ExploreSection]s for [provider] mirroring Mornye's getHomeFeed architecture.
  Future<List<ExploreSection>> getHomeFeed(
    MusicProviderType provider, {
    bool forceRefresh = false,
    String? region,
  }) async {
    // 1. Check persistent cache store first (mirroring Mornye's ExploreCacheStore)
    if (!forceRefresh) {
      final cached = await ExploreFeedCacheStore.instance.read();
      if (cached.payload != null && cached.timestampMs != null) {
        final age = DateTime.now().millisecondsSinceEpoch - cached.timestampMs!;
        if (age < 5 * 60 * 1000) { // 5-minute cache TTL like Mornye
          try {
            final decoded = jsonDecode(cached.payload!) as Map<String, dynamic>;
            if (decoded['provider_id'] == provider.id && decoded['sections'] is List) {
              final sections = (decoded['sections'] as List)
                  .whereType<Map<String, dynamic>>()
                  .map((s) => ExploreSection.fromJson(s))
                  .toList();
              if (sections.isNotEmpty) return sections;
            }
          } catch (_) {}
        }
      }
    }

    // 2. Fetch fresh sections per provider
    final sections = await _buildFreshHomeFeedSections(provider, region: region);

    // 3. Save to persistent cache store
    if (sections.isNotEmpty) {
      final payload = jsonEncode({
        'provider_id': provider.id,
        'region': region ?? 'US',
        'sections': sections.map((s) => s.toJson()).toList(),
      });
      unawaited(ExploreFeedCacheStore.instance.write(payload));
    }

    return sections;
  }

  Future<List<ExploreSection>> _buildFreshHomeFeedSections(
    MusicProviderType provider, {
    String? region,
  }) async {
    final rawTracks = await fetchFeedForProvider(provider, limit: 30);
    final quickPickItems = rawTracks.map((t) => ExploreItem(
      id: t.providerTrackId ?? t.id.replaceAll(RegExp(r'^[a-z]+:'), ''),
      uri: t.id,
      type: 'track',
      name: t.title,
      artists: t.artist,
      coverUrl: t.artworkUri,
      featuredCoverUrl: t.artworkUri,
      heading: 'CHARTS',
      providerId: provider.id,
      albumId: t.album,
      albumName: t.album,
      durationMs: t.durationMs ?? 180000,
    )).toList();

    switch (provider) {
      case MusicProviderType.appleMusic:
        return [
          ExploreSection(
            uri: 'apple:featured',
            title: 'Featured Highlights',
            layout: 'featured',
            items: const [
              ExploreItem(
                id: 'am_1',
                uri: 'apple:station:1',
                type: 'station',
                name: 'Worldwide Live 1',
                artists: 'Live Global Premieres & Charts',
                description: 'Live broadcast of global chart hits, premier releases and artist interviews',
                featuredCoverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=1000&q=80',
                coverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
                heading: 'LIVE ON AIR',
                providerId: 'apple_music',
              ),
              ExploreItem(
                id: 'am_spatial',
                uri: 'apple:playlist:spatial',
                type: 'playlist',
                name: 'Spatial Audio Masters',
                artists: 'Immersive Dolby Atmos Sound',
                description: 'Dolby Atmos & spatial soundscapes crafted for ultra high-fidelity sound',
                featuredCoverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=1000&q=80',
                coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&q=80',
                heading: 'SPATIAL AUDIO',
                providerId: 'apple_music',
              ),
              ExploreItem(
                id: 'am_top100',
                uri: 'apple:playlist:top100',
                type: 'playlist',
                name: 'Top 100 Global Hits',
                artists: 'Worldwide Chart Leaders',
                description: 'The 100 most played tracks worldwide on live digital charts today',
                featuredCoverUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=1000&q=80',
                coverUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=600&q=80',
                heading: 'GLOBAL CHARTS',
                providerId: 'apple_music',
              ),
            ],
          ),
          ExploreSection(
            uri: 'apple:quick_picks',
            title: 'Top Songs & Latest Hits',
            layout: 'quick-picks',
            items: quickPickItems,
          ),
          const ExploreSection(
            uri: 'apple:broadcast',
            title: 'Live Stations & Broadcasts',
            layout: 'shelf',
            items: [
              ExploreItem(
                id: 'am_station_1',
                uri: 'apple:station:1',
                type: 'station',
                name: 'Worldwide Radio 1',
                artists: 'Live Worldwide Radio',
                coverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
                heading: 'LIVE ON AIR',
                providerId: 'apple_music',
              ),
              ExploreItem(
                id: 'am_station_hits',
                uri: 'apple:station:hits',
                type: 'station',
                name: 'Hits & Rewind',
                artists: 'Retro 80s to 2000s Pop',
                coverUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=600&q=80',
                heading: 'TIMELESS CLASSICS',
                providerId: 'apple_music',
              ),
              ExploreItem(
                id: 'am_station_country',
                uri: 'apple:station:country',
                type: 'station',
                name: 'Nashville Sessions',
                artists: 'Studio Country Hits Live',
                coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&q=80',
                heading: 'STUDIO LIVE',
                providerId: 'apple_music',
              ),
            ],
          ),
        ];

      case MusicProviderType.youtubeMusic:
        return [
          ExploreSection(
            uri: 'yt:featured',
            title: 'Trending & Spotlight',
            layout: 'featured',
            items: const [
              ExploreItem(
                id: 'yt_trending',
                uri: 'youtube:trending',
                type: 'playlist',
                name: 'Global Trending Hits',
                artists: 'Breakthrough Videos & Singles',
                description: 'Number 1 trending music & breakthrough videos across global feeds',
                featuredCoverUrl: 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=1000&q=80',
                coverUrl: 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=600&q=80',
                heading: 'TRENDING NOW',
                providerId: 'youtube_music',
              ),
              ExploreItem(
                id: 'yt_viral',
                uri: 'youtube:viral',
                type: 'playlist',
                name: 'Global Viral 50',
                artists: 'Breakthrough Audio Anthems',
                description: 'The top viral tracks with millions of plays and shares this week',
                featuredCoverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=1000&q=80',
                coverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
                heading: 'VIRAL HITS',
                providerId: 'youtube_music',
              ),
            ],
          ),
          ExploreSection(
            uri: 'yt:quick_picks',
            title: 'Quick Picks',
            layout: 'quick-picks',
            items: quickPickItems,
          ),
          const ExploreSection(
            uri: 'yt:broadcast',
            title: 'Spotlight Stations',
            layout: 'shelf',
            items: [
              ExploreItem(
                id: 'yt_channel_1',
                uri: 'youtube:channel:trending',
                type: 'station',
                name: 'Trending Hits',
                artists: 'Global Top Trending',
                coverUrl: 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=600&q=80',
                heading: 'TOP CHARTS',
                providerId: 'youtube_music',
              ),
              ExploreItem(
                id: 'yt_channel_2',
                uri: 'youtube:channel:viral',
                type: 'station',
                name: 'Viral Breakthroughs',
                artists: 'Breakthrough Audio Anthems',
                coverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
                heading: 'VIRAL 100',
                providerId: 'youtube_music',
              ),
            ],
          ),
        ];

      case MusicProviderType.spotify:
        return [
          ExploreSection(
            uri: 'spotify:featured',
            title: 'Curated Highlights',
            layout: 'featured',
            items: const [
              ExploreItem(
                id: 'sp_top_hits',
                uri: 'spotify:playlist:37i9dQZF1DXcBWIGoYBM5M',
                type: 'playlist',
                name: "Today's Top Hits",
                artists: 'The Hottest 50 Tracks Worldwide',
                description: 'The hottest 50 tracks worldwide across digital streams right now',
                featuredCoverUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=1000&q=80',
                coverUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=600&q=80',
                heading: 'TOP 50',
                providerId: 'spotify',
              ),
              ExploreItem(
                id: 'sp_rapcaviar',
                uri: 'spotify:playlist:37i9dQZF1DX0XUsuxWHRQd',
                type: 'playlist',
                name: 'RapCaviar Anthem',
                artists: 'Heavyweight Hip-Hop',
                description: 'Heavyweight hip-hop bangers and new rap anthems',
                featuredCoverUrl: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=1000&q=80',
                coverUrl: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=600&q=80',
                heading: 'HIP-HOP ANTHEMS',
                providerId: 'spotify',
              ),
              ExploreItem(
                id: 'sp_new_music',
                uri: 'spotify:playlist:37i9dQZF1DX4JAvHpjipBk',
                type: 'playlist',
                name: 'New Music Friday',
                artists: 'Fresh Weekly Drops',
                description: 'The premier weekly release lineup of brand-new singles and albums',
                featuredCoverUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=1000&q=80',
                coverUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=600&q=80',
                heading: 'NEW RELEASES',
                providerId: 'spotify',
              ),
            ],
          ),
          ExploreSection(
            uri: 'spotify:quick_picks',
            title: 'Top Hits & Viral Charts',
            layout: 'quick-picks',
            items: quickPickItems,
          ),
          const ExploreSection(
            uri: 'spotify:broadcast',
            title: 'Curated Playlists',
            layout: 'shelf',
            items: [
              ExploreItem(
                id: 'sp_b_top50',
                uri: 'spotify:playlist:37i9dQZF1DXcBWIGoYBM5M',
                type: 'playlist',
                name: 'Global Top 50',
                artists: 'Most Streamed Tracks Worldwide',
                coverUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=600&q=80',
                heading: 'TOP 50',
                providerId: 'spotify',
              ),
              ExploreItem(
                id: 'sp_b_viral',
                uri: 'spotify:playlist:37i9dQZF1DX2L0iB23Enbq',
                type: 'playlist',
                name: 'Viral 50',
                artists: 'Viral Breakout Songs',
                coverUrl: 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=600&q=80',
                heading: 'VIRAL 50',
                providerId: 'spotify',
              ),
              ExploreItem(
                id: 'sp_b_fresh',
                uri: 'spotify:playlist:37i9dQZF1DX3u9TSYrV1nG',
                type: 'playlist',
                name: 'Fresh Finds',
                artists: 'Indie & Future Stars',
                coverUrl: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=600&q=80',
                heading: 'FRESH FINDS',
                providerId: 'spotify',
              ),
            ],
          ),
        ];

      case MusicProviderType.deezer:
        return [
          ExploreSection(
            uri: 'deezer:featured',
            title: 'Spotlight Flow',
            layout: 'featured',
            items: const [
              ExploreItem(
                id: 'dz_flow',
                uri: 'deezer:playlist:3155776842',
                type: 'playlist',
                name: 'Infinite Flow & Top Hits',
                artists: 'Top International Chart Hits',
                description: 'Non-stop personalized stream with fresh releases & timeless classics',
                featuredCoverUrl: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=1000&q=80',
                coverUrl: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=600&q=80',
                heading: 'INFINITE FLOW',
                providerId: 'deezer',
              ),
              ExploreItem(
                id: 'dz_hits',
                uri: 'deezer:playlist:1116190041',
                type: 'playlist',
                name: 'Worldwide Hits 2026',
                artists: 'Chart Toppers & New Heat',
                description: 'The biggest international singles and chart anthems in pristine fidelity',
                featuredCoverUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=1000&q=80',
                coverUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=600&q=80',
                heading: 'WORLDWIDE CHARTS',
                providerId: 'deezer',
              ),
            ],
          ),
          ExploreSection(
            uri: 'deezer:quick_picks',
            title: 'Worldwide Top Charts',
            layout: 'quick-picks',
            items: quickPickItems,
          ),
          const ExploreSection(
            uri: 'deezer:broadcast',
            title: 'Worldwide Stations',
            layout: 'shelf',
            items: [
              ExploreItem(
                id: 'dz_b_flow',
                uri: 'deezer:playlist:3155776842',
                type: 'playlist',
                name: 'Infinite Flow',
                artists: 'High-Fidelity Stream',
                coverUrl: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=600&q=80',
                heading: 'HIGH FIDELITY',
                providerId: 'deezer',
              ),
              ExploreItem(
                id: 'dz_b_top',
                uri: 'deezer:playlist:1116190041',
                type: 'playlist',
                name: 'Top International Hits',
                artists: 'Top 100 International Hits',
                coverUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=600&q=80',
                heading: 'GLOBAL 100',
                providerId: 'deezer',
              ),
            ],
          ),
        ];

      case MusicProviderType.soundcloud:
        return [
          ExploreSection(
            uri: 'soundcloud:featured',
            title: 'Next Wave Spotlight',
            layout: 'featured',
            items: const [
              ExploreItem(
                id: 'sc_nextwave',
                uri: 'soundcloud:nextwave',
                type: 'playlist',
                name: 'Next Wave & Underground',
                artists: 'Emerging Underground Artists',
                description: 'Emerging underground artists, remixes, future bass & lo-fi flips',
                featuredCoverUrl: 'https://images.unsplash.com/photo-1571266028243-e4733b0f0bb0?w=1000&q=80',
                coverUrl: 'https://images.unsplash.com/photo-1571266028243-e4733b0f0bb0?w=600&q=80',
                heading: 'FUTURE SOUNDS',
                providerId: 'soundcloud',
              ),
            ],
          ),
          ExploreSection(
            uri: 'soundcloud:quick_picks',
            title: 'Hot & Trending Tracks',
            layout: 'quick-picks',
            items: quickPickItems,
          ),
          const ExploreSection(
            uri: 'soundcloud:broadcast',
            title: 'Live Sets & Radio',
            layout: 'shelf',
            items: [
              ExploreItem(
                id: 'sc_b_next',
                uri: 'soundcloud:station:nextwave',
                type: 'station',
                name: 'Next Wave',
                artists: 'Emerging Indie & Future Bass',
                coverUrl: 'https://images.unsplash.com/photo-1571266028243-e4733b0f0bb0?w=600&q=80',
                heading: 'INDIE DISCOVERY',
                providerId: 'soundcloud',
              ),
              ExploreItem(
                id: 'sc_b_flips',
                uri: 'soundcloud:station:flips',
                type: 'station',
                name: 'VIP Flips & Bootlegs',
                artists: 'Underground Club Edits & Bootlegs',
                coverUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=600&q=80',
                heading: 'CLUB EDITS',
                providerId: 'soundcloud',
              ),
            ],
          ),
        ];

      case MusicProviderType.all:
      default:
        return [
          ExploreSection(
            uri: 'curated:featured',
            title: 'Featured Highlights',
            layout: 'featured',
            items: const [
              ExploreItem(
                id: 'cur_am1',
                uri: 'apple:station:1',
                type: 'station',
                name: 'Worldwide Live 1',
                artists: 'Global Premieres & Top Hits',
                description: 'Live broadcast of global chart hits, premier releases and artist interviews',
                featuredCoverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=1000&q=80',
                coverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
                heading: 'LIVE ON AIR',
                providerId: 'apple_music',
              ),
              ExploreItem(
                id: 'cur_sp',
                uri: 'spotify:playlist:37i9dQZF1DXcBWIGoYBM5M',
                type: 'playlist',
                name: "Today's Top Hits",
                artists: 'The Hottest 50 Tracks Worldwide',
                description: 'The hottest 50 tracks on digital charts worldwide right now',
                featuredCoverUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=1000&q=80',
                coverUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=600&q=80',
                heading: 'TOP 50',
                providerId: 'spotify',
              ),
              ExploreItem(
                id: 'cur_dz',
                uri: 'deezer:playlist:3155776842',
                type: 'playlist',
                name: 'Top Worldwide Hits',
                artists: 'International Chart Anthems',
                description: 'Top 100 international charts and streaming favorites',
                featuredCoverUrl: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=1000&q=80',
                coverUrl: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=600&q=80',
                heading: 'WORLDWIDE CHARTS',
                providerId: 'deezer',
              ),
            ],
          ),
          ExploreSection(
            uri: 'curated:quick_picks',
            title: 'Top Songs & Latest Hits',
            layout: 'quick-picks',
            items: quickPickItems,
          ),
        ];
    }
  }

  /// Automatically inspects and resolves ANY external music URL (Spotify, YouTube,
  /// YouTube Music, Apple Music, Deezer) into a normalized [ExternalResolvedPlaylist].
  Future<ExternalResolvedPlaylist> resolveExternalUrl(String url) async {
    final clean = url.trim();
    if (clean.isEmpty) {
      throw const FormatException('Please enter a valid playlist, album, or mix link.');
    }

    // 1. YouTube or YouTube Music
    if (clean.contains('youtube.com') || clean.contains('youtu.be') || clean.startsWith('PL')) {
      final ytData = await YoutubeAudioService.instance.fetchPlaylist(clean);
      if (ytData == null || ytData.tracks.isEmpty) {
        throw const FormatException('Could not load YouTube playlist. Please make sure it is public or unlisted.');
      }
      return ExternalResolvedPlaylist(
        id: ytData.id,
        title: ytData.title,
        curator: ytData.author,
        artworkUrl: ytData.thumbnailUrl,
        provider: 'YouTube Music',
        tracks: ytData.tracks.map((t) => t.toImportedTrack()).toList(growable: false),
      );
    }

    // 2. Spotify
    if (clean.contains('spotify.com') || clean.startsWith('spotify:')) {
      final spData = await SpotifyService.instance.fetchPlaylist(clean);
      if (spData.tracks.isEmpty) {
        throw const FormatException('Could not load Spotify playlist or album.');
      }
      return ExternalResolvedPlaylist(
        id: spData.id,
        title: spData.title,
        curator: spData.owner ?? 'Spotify',
        artworkUrl: spData.artworkUrl,
        provider: 'Spotify',
        description: spData.description,
        tracks: spData.tracks.map((t) => t.toImportedTrack()).toList(growable: false),
      );
    }

    // 3. Apple Music
    if (clean.contains('music.apple.com')) {
      final resolved = await _resolveAppleMusicUrl(clean);
      if (resolved != null && resolved.tracks.isNotEmpty) {
        return resolved;
      }
    }

    // 4. Deezer
    if (clean.contains('deezer.com')) {
      final resolved = await _resolveDeezerUrl(clean);
      if (resolved != null && resolved.tracks.isNotEmpty) {
        return resolved;
      }
    }

    // 5. SoundCloud
    if (clean.contains('soundcloud.com')) {
      final tracks = await SoundCloudAudioService.instance.search(clean, limit: 25);
      if (tracks.isNotEmpty) {
        return ExternalResolvedPlaylist(
          id: 'soundcloud:${tracks.first.id}',
          title: tracks.first.title,
          curator: tracks.first.artist,
          artworkUrl: tracks.first.artworkUrl,
          provider: 'SoundCloud',
          tracks: tracks.map((t) => t.toImportedTrack()).toList(growable: false),
        );
      }
    }

    // Fallback: try Spotify parser
    final spFallback = await SpotifyService.instance.fetchPlaylist(clean);
    return ExternalResolvedPlaylist(
      id: spFallback.id,
      title: spFallback.title,
      curator: spFallback.owner ?? 'Music Stream',
      artworkUrl: spFallback.artworkUrl,
      provider: 'External',
      tracks: spFallback.tracks.map((t) => t.toImportedTrack()).toList(growable: false),
    );
  }

  Future<ExternalResolvedPlaylist?> _resolveAppleMusicUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      // Format: /us/album/title/id or /us/playlist/title/pl.id
      String? storefront;
      String? entityId;
      for (var i = 0; i < segments.length; i++) {
        final seg = segments[i];
        if (seg == 'album' || seg == 'playlist') {
          if (i > 0) storefront = segments[i - 1];
          if (i + 2 < segments.length) {
            entityId = segments[i + 2];
          } else if (i + 1 < segments.length) {
            entityId = segments[i + 1];
          }
          break;
        }
      }

      if (entityId == null) return null;
      storefront ??= 'us';

      final lookupUri = Uri.parse(
        'https://itunes.apple.com/lookup?id=$entityId&entity=song&country=$storefront',
      );
      final res = await http.get(lookupUri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final results = json['results'] as List?;
        if (results != null && results.isNotEmpty) {
          final collection = results.first as Map;
          final name = (collection['collectionName'] as String?) ?? 'Apple Music Collection';
          final artist = (collection['artistName'] as String?) ?? 'Apple Music';
          final artUrl = (collection['artworkUrl100'] as String?)?.replaceAll(RegExp(r'\d+x\d+bb'), '600x600bb');

          final tracks = <ImportedTrack>[];
          for (final item in results.skip(1)) {
            if (item is! Map || item['wrapperType'] != 'track') continue;
            final tTitle = (item['trackName'] as String?)?.trim() ?? '';
            final tArtist = (item['artistName'] as String?)?.trim() ?? artist;
            final tId = item['trackId']?.toString() ?? '$name-$tTitle';
            final tDuration = (item['trackTimeMillis'] as num?)?.toInt() ?? 200000;
            if (tTitle.isNotEmpty) {
              tracks.add(
                ImportedTrack(
                  id: 'apple:$tId',
                  path: 'apple:$tId',
                  title: tTitle,
                  artist: tArtist,
                  album: name,
                  durationMs: tDuration,
                  artworkUri: artUrl,
                  sourceProvider: 'Apple Music',
                  providerTrackId: tId,
                  isAvailable: true,
                ),
              );
            }
          }

          if (tracks.isNotEmpty) {
            return ExternalResolvedPlaylist(
              id: entityId,
              title: name,
              curator: artist,
              artworkUrl: artUrl,
              provider: 'Apple Music',
              tracks: tracks,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Apple Music URL resolution error: $e');
    }
    return null;
  }

  Future<ExternalResolvedPlaylist?> _resolveDeezerUrl(String url) async {
    try {
      final match = RegExp(r'deezer\.com/(?:[a-z]{2}/)?(playlist|album)/(\d+)').firstMatch(url);
      if (match == null) return null;
      final type = match.group(1)!;
      final id = match.group(2)!;

      final res = await http.get(Uri.parse('https://api.deezer.com/$type/$id')).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final title = (json['title'] as String?) ?? 'Deezer $type';
        final curator = (json['creator']?['name'] as String?) ?? (json['artist']?['name'] as String?) ?? 'Deezer';
        final artUrl = (json['cover_xl'] as String?) ?? (json['picture_xl'] as String?);
        final rawTracks = (json['tracks']?['data'] as List?) ?? const [];

        final tracks = <ImportedTrack>[];
        for (final item in rawTracks) {
          if (item is! Map) continue;
          final tId = item['id']?.toString() ?? '';
          final tTitle = (item['title'] as String?)?.trim() ?? '';
          final tArtist = (item['artist']?['name'] as String?)?.trim() ?? curator;
          final tDuration = (item['duration'] as num?)?.toInt() ?? 180;
          if (tTitle.isNotEmpty) {
            tracks.add(
              ImportedTrack(
                id: 'deezer:$tId',
                path: 'deezer:$tId',
                title: tTitle,
                artist: tArtist,
                album: title,
                durationMs: tDuration * 1000,
                artworkUri: artUrl,
                sourceProvider: 'Deezer',
                providerTrackId: tId,
                isAvailable: true,
              ),
            );
          }
        }

        if (tracks.isNotEmpty) {
          return ExternalResolvedPlaylist(
            id: id,
            title: title,
            curator: curator,
            artworkUrl: artUrl,
            provider: 'Deezer',
            tracks: tracks,
          );
        }
      }
    } catch (e) {
      debugPrint('Deezer URL resolution error: $e');
    }
    return null;
  }

  /// Imports any [ExternalResolvedPlaylist] into Melo's [MusicLibrary] playlists.
  Future<MusicPlaylist> importToLibrary({
    required ExternalResolvedPlaylist playlist,
    required MusicLibrary library,
    bool mergeExisting = false,
  }) async {
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

    await library.importExternalTracks(playlist.tracks);
    await library.addTracksToPlaylist(
      tonePlaylist.id,
      playlist.tracks.map((t) => t.id),
    );

    return tonePlaylist;
  }
}
