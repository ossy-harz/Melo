import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Supported external music & metadata service providers.
enum MusicProviderType {
  all('all', 'All Curated', Color(0xFFFA243C), Icons.auto_awesome_rounded),
  appleMusic('apple_music', 'Apple Music', Color(0xFFFC3C44), Icons.apple_rounded),
  spotify('spotify', 'Spotify Web', Color(0xFF1DB954), Icons.graphic_eq_rounded),
  youtubeMusic('youtube_music', 'YouTube Music', Color(0xFFFF0000), Icons.play_circle_fill_rounded),
  deezer('deezer', 'Deezer', Color(0xFFA238FF), Icons.album_rounded),
  soundcloud('soundcloud', 'SoundCloud', Color(0xFFFF5500), Icons.cloud_queue_rounded),
  tidal('tidal', 'TIDAL', Color(0xFF00E5FF), Icons.waves_rounded),
  amazonMusic('amazon_music', 'Amazon Music', Color(0xFF00A8E1), Icons.music_note_rounded);

  const MusicProviderType(this.id, this.displayName, this.brandColor, this.icon);

  final String id;
  final String displayName;
  final Color brandColor;
  final IconData icon;

  bool get canStream => this != all;
  bool get canDownload =>
      this == youtubeMusic || this == soundcloud || this == deezer;
  bool get hasLyrics =>
      this == spotify || this == appleMusic || this == deezer || this == youtubeMusic;
  bool get hasHomeFeed =>
      this == all ||
      this == appleMusic ||
      this == spotify ||
      this == youtubeMusic ||
      this == deezer ||
      this == soundcloud;

  static MusicProviderType fromId(String id) {
    return MusicProviderType.values.firstWhere(
      (p) => p.id == id || p.name == id,
      orElse: () => MusicProviderType.all,
    );
  }
}

/// Unified, cross-provider song metadata model matching Mornye's TrackMetadata.
class UnifiedTrackMetadata {
  const UnifiedTrackMetadata({
    required this.title,
    required this.artist,
    required this.album,
    required this.provider,
    this.albumArtist,
    this.durationMs,
    this.artworkUrl,
    this.releaseDate,
    this.isrc,
    this.genres = const [],
    this.composers = const [],
    this.producers = const [],
    this.recordLabel,
    this.trackNumber,
    this.totalTracks,
    this.discNumber,
    this.totalDiscs,
    this.explicit,
    this.audioTraits = const [],
    this.providerTrackId,
    this.streamUrl,
    this.downloadUrl,
    this.audioCodec,
    this.bitrateKbps,
    this.syncedLyrics,
    this.plainLyrics,
  });

  final String title;
  final String artist;
  final String album;
  final MusicProviderType provider;
  final String? albumArtist;
  final int? durationMs;
  final String? artworkUrl;
  final String? releaseDate;
  final String? isrc;
  final List<String> genres;
  final List<String> composers;
  final List<String> producers;
  final String? recordLabel;
  final int? trackNumber;
  final int? totalTracks;
  final int? discNumber;
  final int? totalDiscs;
  final bool? explicit;
  final List<String> audioTraits;
  final String? providerTrackId;
  final String? streamUrl;
  final String? downloadUrl;
  final String? audioCodec;
  final int? bitrateKbps;
  final String? syncedLyrics;
  final String? plainLyrics;

  String get durationString {
    if (durationMs == null || durationMs! <= 0) return '--:--';
    final dur = Duration(milliseconds: durationMs!);
    final m = dur.inMinutes;
    final s = dur.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get qualityBadge {
    if (audioTraits.contains('lossless')) {
      return 'HI-RES LOSSLESS · 24-BIT';
    }
    if (audioCodec != null && bitrateKbps != null) {
      return '${audioCodec!.toUpperCase()} · $bitrateKbps KBPS';
    }
    if (bitrateKbps != null && bitrateKbps! >= 320) {
      return 'HI-RES · 320 KBPS';
    }
    return '${provider.displayName.toUpperCase()} · VERIFIED';
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'artist': artist,
    'album': album,
    'provider': provider.id,
    if (albumArtist != null) 'album_artist': albumArtist,
    if (durationMs != null) 'duration_ms': durationMs,
    if (artworkUrl != null) 'artwork_url': artworkUrl,
    if (releaseDate != null) 'release_date': releaseDate,
    if (isrc != null) 'isrc': isrc,
    if (genres.isNotEmpty) 'genres': genres,
    if (composers.isNotEmpty) 'composers': composers,
    if (producers.isNotEmpty) 'producers': producers,
    if (recordLabel != null) 'record_label': recordLabel,
    if (trackNumber != null) 'track_number': trackNumber,
    if (totalTracks != null) 'total_tracks': totalTracks,
    if (discNumber != null) 'disc_number': discNumber,
    if (totalDiscs != null) 'total_discs': totalDiscs,
    if (explicit != null) 'explicit': explicit,
    if (audioTraits.isNotEmpty) 'audio_traits': audioTraits,
    if (providerTrackId != null) 'provider_track_id': providerTrackId,
    if (streamUrl != null) 'stream_url': streamUrl,
    if (downloadUrl != null) 'download_url': downloadUrl,
    if (audioCodec != null) 'audio_codec': audioCodec,
    if (bitrateKbps != null) 'bitrate_kbps': bitrateKbps,
    if (syncedLyrics != null) 'synced_lyrics': syncedLyrics,
    if (plainLyrics != null) 'plain_lyrics': plainLyrics,
  };

  factory UnifiedTrackMetadata.fromJson(Map<String, dynamic> json) => UnifiedTrackMetadata(
    title: json['title'] as String? ?? '',
    artist: json['artist'] as String? ?? '',
    album: json['album'] as String? ?? '',
    provider: MusicProviderType.fromId(json['provider'] as String? ?? 'all'),
    albumArtist: json['album_artist'] as String?,
    durationMs: json['duration_ms'] as int?,
    artworkUrl: json['artwork_url'] as String?,
    releaseDate: json['release_date'] as String?,
    isrc: json['isrc'] as String?,
    genres: (json['genres'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    composers: (json['composers'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    producers: (json['producers'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    recordLabel: json['record_label'] as String?,
    trackNumber: json['track_number'] as int?,
    totalTracks: json['total_tracks'] as int?,
    discNumber: json['disc_number'] as int?,
    totalDiscs: json['total_discs'] as int?,
    explicit: json['explicit'] as bool?,
    audioTraits: (json['audio_traits'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    providerTrackId: json['provider_track_id'] as String?,
    streamUrl: json['stream_url'] as String?,
    downloadUrl: json['download_url'] as String?,
    audioCodec: json['audio_codec'] as String?,
    bitrateKbps: json['bitrate_kbps'] as int?,
    syncedLyrics: json['synced_lyrics'] as String?,
    plainLyrics: json['plain_lyrics'] as String?,
  );
}

/// Global settings controller for Home Feed & Discovery Provider.
///
/// Keeps user preference in persistent storage and provides a reactive
/// [ValueNotifier] that adapts the Home Screen editorial shelves, top picks,
/// and quick picks to the selected provider without cluttering the main UI.
class HomeFeedProviderSettings {
  HomeFeedProviderSettings._();
  static final HomeFeedProviderSettings instance = HomeFeedProviderSettings._();

  static const String _prefKey = 'tone_home_feed_provider';

  final ValueNotifier<MusicProviderType> activeProvider =
      ValueNotifier<MusicProviderType>(MusicProviderType.all);

  bool _initialized = false;

  /// Loads the persisted provider selection from SharedPreferences.
  Future<void> init([SharedPreferences? injectedPrefs]) async {
    if (_initialized && injectedPrefs == null) return;
    try {
      final prefs = injectedPrefs ?? await SharedPreferences.getInstance();
      final savedId = prefs.getString(_prefKey);
      if (savedId != null && savedId.isNotEmpty) {
        activeProvider.value = MusicProviderType.fromId(savedId);
      }
    } catch (_) {}
    _initialized = true;
  }

  /// Sets and persists the selected discovery provider.
  Future<void> setProvider(
    MusicProviderType provider, [
    SharedPreferences? injectedPrefs,
  ]) async {
    if (activeProvider.value == provider) return;
    activeProvider.value = provider;
    try {
      final prefs = injectedPrefs ?? await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, provider.id);
    } catch (_) {}
  }

  /// Resets back to default 'all' (useful in tests or clear data).
  void resetForTesting() {
    activeProvider.value = MusicProviderType.all;
    _initialized = false;
  }
}

/// Mornye-grade Explore Item representing a single track, album, playlist, artist, or station.
class ExploreItem {
  const ExploreItem({
    required this.id,
    required this.uri,
    required this.type,
    required this.name,
    required this.artists,
    this.description,
    this.coverUrl,
    this.featuredCoverUrl,
    this.heading,
    this.explicit,
    this.providerId,
    this.albumId,
    this.albumName,
    this.releaseDate,
    this.durationMs = 0,
  });

  final String id;
  final String uri;
  final String type; // 'track', 'album', 'playlist', 'artist', 'station'
  final String name;
  final String artists;
  final String? description;
  final String? coverUrl;
  final String? featuredCoverUrl;
  final String? heading;
  final bool? explicit;
  final String? providerId;
  final String? albumId;
  final String? albumName;
  final String? releaseDate;
  final int durationMs;

  factory ExploreItem.fromJson(Map<String, dynamic> json) {
    return ExploreItem(
      id: json['id'] as String? ?? '',
      uri: json['uri'] as String? ?? '',
      type: json['type'] as String? ?? 'track',
      name: json['name'] as String? ?? '',
      artists: json['artists'] as String? ?? '',
      description: json['description'] as String?,
      coverUrl: json['cover_url'] as String?,
      featuredCoverUrl: json['featured_cover_url'] as String?,
      heading: json['heading'] as String?,
      explicit: json['explicit'] as bool?,
      providerId: json['provider_id'] as String?,
      albumId: json['album_id'] as String?,
      albumName: json['album_name'] as String?,
      releaseDate: json['release_date']?.toString(),
      durationMs: json['duration_ms'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'uri': uri,
    'type': type,
    'name': name,
    'artists': artists,
    if (description != null) 'description': description,
    if (coverUrl != null) 'cover_url': coverUrl,
    if (featuredCoverUrl != null) 'featured_cover_url': featuredCoverUrl,
    if (heading != null) 'heading': heading,
    if (explicit != null) 'explicit': explicit,
    if (providerId != null) 'provider_id': providerId,
    if (albumId != null) 'album_id': albumId,
    if (albumName != null) 'album_name': albumName,
    if (releaseDate != null) 'release_date': releaseDate,
    'duration_ms': durationMs,
  };
}

/// Mornye-grade Explore Section supporting 'featured', 'quick-picks', and 'shelf' layouts.
class ExploreSection {
  const ExploreSection({
    required this.uri,
    required this.title,
    this.layout = 'shelf',
    required this.items,
  });

  final String uri;
  final String title;
  final String layout; // 'featured' | 'quick-picks' | 'shelf'
  final List<ExploreItem> items;

  bool get isFeatured => layout == 'featured';
  bool get isQuickPicks => layout == 'quick-picks';
  bool get isShelf => !isFeatured && !isQuickPicks;

  factory ExploreSection.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return ExploreSection(
      uri: json['uri'] as String? ?? '',
      title: json['title'] as String? ?? '',
      layout: json['layout'] as String? ?? 'shelf',
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map((i) => ExploreItem.fromJson(i))
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => {
    'uri': uri,
    'title': title,
    'layout': layout,
    'items': items.map((i) => i.toJson()).toList(growable: false),
  };
}

/// Persistent cache store for Explore Sections mirroring Mornye's ExploreCacheStore.
class ExploreFeedCacheStore {
  ExploreFeedCacheStore._();
  static final ExploreFeedCacheStore instance = ExploreFeedCacheStore._();

  static const String _cacheKey = 'tone_explore_feed_cache';
  static const String _cacheTsKey = 'tone_explore_feed_ts';

  Future<({String? payload, int? timestampMs})> read([SharedPreferences? injectedPrefs]) async {
    try {
      final prefs = injectedPrefs ?? await SharedPreferences.getInstance();
      final payload = prefs.getString(_cacheKey);
      final ts = prefs.getInt(_cacheTsKey);
      return (payload: payload, timestampMs: ts);
    } catch (_) {
      return (payload: null, timestampMs: null);
    }
  }

  Future<void> write(String payload, [SharedPreferences? injectedPrefs]) async {
    try {
      final prefs = injectedPrefs ?? await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, payload);
      await prefs.setInt(_cacheTsKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  Future<void> clear([SharedPreferences? injectedPrefs]) async {
    try {
      final prefs = injectedPrefs ?? await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheTsKey);
    } catch (_) {}
  }
}


