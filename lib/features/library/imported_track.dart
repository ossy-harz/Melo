import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:path/path.dart' as p;

class ImportedTrack {
  const ImportedTrack({
    required this.id,
    required this.path,
    required this.title,
    this.artist = 'Unknown artist',
    this.album = 'Unknown album',
    this.durationMs,
    this.artworkUri,
    this.year,
    this.trackNumber,
    this.genre,
    this.bpm,
    this.isDeviceMedia = false,
    this.sourceFolderUri,
    this.lyricsUri,
    this.sourceProvider,
    this.providerTrackId,
    this.licenseUrl,
    this.metadataReviewed = false,
  });

  final String id;
  final String path;
  final String title;
  final String artist;
  final String album;
  final int? durationMs;
  final String? artworkUri;
  final int? year;
  final int? trackNumber;
  final String? genre;
  final double? bpm;
  final bool isDeviceMedia;
  final String? sourceFolderUri;
  final String? lyricsUri;
  final String? sourceProvider;
  final String? providerTrackId;
  final String? licenseUrl;
  final bool metadataReviewed;

  String get displayArtist {
    final normalized = artist.trim();
    return normalized.isEmpty || normalized.toLowerCase() == 'unknown artist'
        ? 'On-device audio'
        : normalized;
  }

  MediaItem toMediaItem() => MediaItem(
    id: path,
    title: title,
    artist: displayArtistName(artist),
    album: album,
    duration: durationMs == null ? null : Duration(milliseconds: durationMs!),
    artUri: artworkUri == null ? null : Uri.tryParse(artworkUri!),
    extras: {
      'libraryId': id,
      'source': isDeviceMedia ? 'device' : 'local',
      if (sourceProvider != null) 'downloadProvider': sourceProvider,
      if (providerTrackId != null) 'providerTrackId': providerTrackId,
      if (licenseUrl != null) 'licenseUrl': licenseUrl,
      if (year != null) 'year': year,
      if (trackNumber != null) 'trackNumber': trackNumber,
      if (genre != null) 'genre': genre,
      if (bpm != null) 'bpm': bpm,
      if (lyricsUri != null) 'lyricsUri': lyricsUri,
    },
  );

  ImportedTrack withMetadata({
    String? title,
    String? artist,
    String? album,
    int? durationMs,
    String? artworkUri,
    int? year,
    int? trackNumber,
    String? genre,
    double? bpm,
    bool? metadataReviewed,
    String? sourceProvider,
    String? providerTrackId,
    String? licenseUrl,
  }) => ImportedTrack(
    id: id,
    path: path,
    title: title ?? this.title,
    artist: artist ?? this.artist,
    album: album ?? this.album,
    durationMs: durationMs ?? this.durationMs,
    artworkUri: artworkUri ?? this.artworkUri,
    year: year ?? this.year,
    trackNumber: trackNumber ?? this.trackNumber,
    genre: genre ?? this.genre,
    bpm: bpm ?? this.bpm,
    isDeviceMedia: isDeviceMedia,
    sourceFolderUri: sourceFolderUri,
    lyricsUri: lyricsUri,
    sourceProvider: sourceProvider ?? this.sourceProvider,
    providerTrackId: providerTrackId ?? this.providerTrackId,
    licenseUrl: licenseUrl ?? this.licenseUrl,
    metadataReviewed: metadataReviewed ?? this.metadataReviewed,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'path': path,
    'title': title,
    'artist': artist,
    'album': album,
    'durationMs': durationMs,
    'artworkUri': artworkUri,
    'year': year,
    'trackNumber': trackNumber,
    'genre': genre,
    'bpm': bpm,
    'isDeviceMedia': isDeviceMedia,
    'sourceFolderUri': sourceFolderUri,
    'lyricsUri': lyricsUri,
    'sourceProvider': sourceProvider,
    'providerTrackId': providerTrackId,
    'licenseUrl': licenseUrl,
    'metadataReviewed': metadataReviewed,
  };

  factory ImportedTrack.fromJson(Map<String, Object?> json) => ImportedTrack(
    id: json['id']! as String,
    path: json['path']! as String,
    title: json['title']! as String,
    artist: json['artist'] as String? ?? 'Unknown artist',
    album: json['album'] as String? ?? 'Unknown album',
    durationMs: (json['durationMs'] as num?)?.toInt(),
    artworkUri: json['artworkUri'] as String?,
    year: (json['year'] as num?)?.toInt(),
    trackNumber: (json['trackNumber'] as num?)?.toInt(),
    genre: json['genre'] as String?,
    bpm: (json['bpm'] as num?)?.toDouble(),
    isDeviceMedia: json['isDeviceMedia'] as bool? ?? false,
    sourceFolderUri: json['sourceFolderUri'] as String?,
    lyricsUri: json['lyricsUri'] as String?,
    sourceProvider: json['sourceProvider'] as String?,
    providerTrackId: json['providerTrackId'] as String?,
    licenseUrl: json['licenseUrl'] as String?,
    metadataReviewed: json['metadataReviewed'] as bool? ?? false,
  );

  factory ImportedTrack.fromCopiedFile({
    required String id,
    required String path,
    required String originalName,
  }) => ImportedTrack(
    id: id,
    path: path,
    title: p.basenameWithoutExtension(originalName),
  );

  factory ImportedTrack.fromDeviceMedia({
    required String uri,
    required String title,
    required String artist,
    String album = 'Unknown album',
    int? durationMs,
    String? artworkUri,
    int? year,
    int? trackNumber,
    String? genre,
    double? bpm,
    String? sourceFolderUri,
    String? lyricsUri,
  }) => ImportedTrack(
    id: uri,
    path: uri,
    title: title,
    artist: artist,
    album: album,
    durationMs: durationMs,
    artworkUri: artworkUri,
    year: year,
    trackNumber: trackNumber,
    genre: genre,
    bpm: bpm,
    isDeviceMedia: true,
    sourceFolderUri: sourceFolderUri,
    lyricsUri: lyricsUri,
  );

  static List<ImportedTrack> decodeList(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! List) {
      throw const FormatException('Stored music library is not a list.');
    }
    return decoded
        .map((item) {
          if (item is! Map) {
            throw const FormatException('Stored track is not an object.');
          }
          return ImportedTrack.fromJson(Map<String, Object?>.from(item));
        })
        .toList(growable: false);
  }
}

String displayArtistName(
  String? artist, {
  String? fallback = 'On-device audio',
}) {
  final normalized = artist?.trim();
  if (normalized == null ||
      normalized.isEmpty ||
      normalized.toLowerCase() == 'unknown artist') {
    return fallback ?? '';
  }
  return normalized;
}
