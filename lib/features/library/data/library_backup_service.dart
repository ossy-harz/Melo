import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:melo_player/features/library/imported_track.dart';
import 'package:melo_player/features/library/music_playlist.dart';

class LibraryBackupData {
  const LibraryBackupData({
    required this.version,
    required this.timestamp,
    required this.playlists,
    required this.tracks,
    required this.favoriteTrackIds,
    this.excludedTrackIds = const {},
  });

  final int version;
  final DateTime timestamp;
  final List<MusicPlaylist> playlists;
  final List<ImportedTrack> tracks;
  final Set<String> favoriteTrackIds;
  final Set<String> excludedTrackIds;

  Map<String, Object?> toJson() => {
    'version': version,
    'timestamp': timestamp.toIso8601String(),
    'playlists': playlists.map((p) => p.toJson()).toList(),
    'tracks': tracks.map((t) => t.toJson()).toList(),
    'favoriteTrackIds': favoriteTrackIds.toList(),
    'excludedTrackIds': excludedTrackIds.toList(),
  };

  factory LibraryBackupData.fromJson(Map<String, Object?> json) {
    final playlistsJson = json['playlists'];
    final tracksJson = json['tracks'];
    final favsJson = json['favoriteTrackIds'];
    final exclJson = json['excludedTrackIds'];

    final playlists = <MusicPlaylist>[];
    if (playlistsJson is List) {
      for (final item in playlistsJson) {
        if (item is Map) {
          try {
            playlists.add(MusicPlaylist.fromJson(Map<String, Object?>.from(item)));
          } catch (_) {}
        }
      }
    }

    final tracks = <ImportedTrack>[];
    if (tracksJson is List) {
      for (final item in tracksJson) {
        if (item is Map) {
          try {
            tracks.add(ImportedTrack.fromJson(Map<String, Object?>.from(item)));
          } catch (_) {}
        }
      }
    }

    final favoriteTrackIds = <String>{};
    if (favsJson is List) {
      for (final id in favsJson) {
        if (id is String) favoriteTrackIds.add(id);
      }
    }

    final excludedTrackIds = <String>{};
    if (exclJson is List) {
      for (final id in exclJson) {
        if (id is String) excludedTrackIds.add(id);
      }
    }

    return LibraryBackupData(
      version: (json['version'] as num?)?.toInt() ?? 1,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      playlists: List.unmodifiable(playlists),
      tracks: List.unmodifiable(tracks),
      favoriteTrackIds: Set.unmodifiable(favoriteTrackIds),
      excludedTrackIds: Set.unmodifiable(excludedTrackIds),
    );
  }
}

class LibraryBackupService {
  static const int currentVersion = 1;
  static const String backupFileName = 'melo_library_backup.json';

  static List<String> get potentialBackupDirectories => const [
    '/storage/emulated/0/Music/Tone/Backups',
    '/storage/emulated/0/Music/Tone',
    '/storage/emulated/0/Music',
    '/storage/emulated/0/Download/Melo',
    '/storage/emulated/0/Download',
    '/sdcard/Music/Tone/Backups',
    '/sdcard/Download/Melo',
  ];

  /// Automatically exports backup to external persistent storage surviving uninstallation.
  static Future<File?> autoBackup({
    required List<MusicPlaylist> playlists,
    required List<ImportedTrack> tracks,
    required Set<String> favoriteTrackIds,
    Set<String> excludedTrackIds = const {},
  }) async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return null;
    }
    if (playlists.isEmpty && favoriteTrackIds.isEmpty) return null;

    final data = LibraryBackupData(
      version: currentVersion,
      timestamp: DateTime.now(),
      playlists: playlists,
      tracks: tracks,
      favoriteTrackIds: favoriteTrackIds,
      excludedTrackIds: excludedTrackIds,
    );

    final jsonString = jsonEncode(data.toJson());
    File? lastSaved;

    // 1. Try public external storage locations that survive app uninstallation
    for (final dirPath in potentialBackupDirectories) {
      try {
        final dir = Directory(dirPath);
        if (!dir.existsSync()) {
          try {
            dir.createSync(recursive: true);
          } catch (_) {}
        }
        if (dir.existsSync()) {
          final file = File(p.join(dir.path, backupFileName));
          await file.writeAsString(jsonString, flush: true);
          lastSaved = file;
          debugPrint('Library backup successfully auto-saved to: ${file.path}');
        }
      } catch (e) {
        // Continue to other locations
      }
    }

    // 2. Also save to app support directory
    try {
      final support = await getApplicationSupportDirectory();
      final backupDir = Directory(p.join(support.path, 'backups'));
      if (!backupDir.existsSync()) {
        await backupDir.create(recursive: true);
      }
      final file = File(p.join(backupDir.path, backupFileName));
      await file.writeAsString(jsonString, flush: true);
      lastSaved ??= file;
    } catch (_) {}

    return lastSaved;
  }

  /// Checks external storage locations for an existing backup file.
  static Future<File?> findLatestExternalBackup() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return null;
    }
    for (final dirPath in potentialBackupDirectories) {
      try {
        final file = File(p.join(dirPath, backupFileName));
        if (await file.exists()) {
          return file;
        }
      } catch (_) {}
    }

    try {
      final support = await getApplicationSupportDirectory();
      final file = File(p.join(support.path, 'backups', backupFileName));
      if (await file.exists()) {
        return file;
      }
    } catch (_) {}

    return null;
  }

  /// Restores library from a given backup file.
  static Future<LibraryBackupData?> readBackup(File file) async {
    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, Object?>;
      return LibraryBackupData.fromJson(json);
    } catch (e) {
      debugPrint('Failed to read backup from ${file.path}: $e');
      return null;
    }
  }

  /// Manually picks and imports a backup file chosen by the user.
  static Future<LibraryBackupData?> pickAndImportBackup() async {
    try {
      final selected = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        dialogTitle: 'Select Melo Library Backup File',
      );
      if (selected.isEmpty) return null;
      final path = selected.first.path;
      if (path == null) return null;
      return await readBackup(File(path));
    } catch (e) {
      debugPrint('Failed to pick backup file: $e');
      return null;
    }
  }
}
