import 'package:flutter/material.dart';

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

/// Unified, cross-provider song metadata model.
class UnifiedTrackMetadata {
  const UnifiedTrackMetadata({
    required this.title,
    required this.artist,
    required this.album,
    required this.provider,
    this.durationMs,
    this.artworkUrl,
    this.releaseDate,
    this.isrc,
    this.genres = const [],
    this.composers = const [],
    this.producers = const [],
    this.recordLabel,
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
  final int? durationMs;
  final String? artworkUrl;
  final String? releaseDate;
  final String? isrc;
  final List<String> genres;
  final List<String> composers;
  final List<String> producers;
  final String? recordLabel;
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
    if (audioCodec != null && bitrateKbps != null) {
      return '${audioCodec!.toUpperCase()} · $bitrateKbps KBPS';
    }
    if (bitrateKbps != null && bitrateKbps! >= 320) {
      return 'HI-RES · 320 KBPS';
    }
    return '${provider.displayName.toUpperCase()} · VERIFIED';
  }
}
