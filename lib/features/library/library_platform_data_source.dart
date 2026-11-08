import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

abstract interface class LibraryPlatformDataSource {
  Future<List<DeviceAudio>> scanDeviceAudio({DateTime? modifiedSince});
  Future<MusicFolder?> pickMusicFolder();
  Future<List<DeviceAudio>> scanMusicFolder(String uri);
  Future<void> releaseMusicFolder(String uri);
  Future<bool> deleteDeviceAudio(String uri);
  Future<bool> deleteDeviceAudioBatch(List<String> uris);
  Future<Map<Object?, Object?>?> readImportedMetadata(
    String path,
    String fallbackTitle,
  );
}

class MethodChannelLibraryPlatformDataSource
    implements LibraryPlatformDataSource {
  const MethodChannelLibraryPlatformDataSource({
    this._channel = const MethodChannel('app.melo.melo_player/library'),
  });

  final MethodChannel _channel;

  @override
  Future<List<DeviceAudio>> scanDeviceAudio({DateTime? modifiedSince}) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError(
        'Device music scanning is currently available on Android.',
      );
    }
    final sdkVersion = await _channel.invokeMethod<int>('androidSdkVersion');
    final permission = sdkVersion != null && sdkVersion >= 33
        ? Permission.audio
        : Permission.storage;
    final status = await permission.request();
    if (!status.isGranted) {
      throw MusicPermissionDeniedException(
        permanentlyDenied: status.isPermanentlyDenied,
      );
    }
    const pageSize = 250;
    final audio = <DeviceAudio>[];
    var offset = 0;
    while (true) {
      final page = await _channel.invokeListMethod<Map<Object?, Object?>>(
        'scanAudio',
        {
          'offset': offset,
          'limit': pageSize,
          if (modifiedSince != null)
            'modifiedAfterSeconds':
                modifiedSince.millisecondsSinceEpoch ~/ 1000,
        },
      );
      if (page == null) {
        throw StateError('Android did not return a page of scanned music.');
      }
      audio.addAll(page.map(DeviceAudio.fromPlatformMap));
      if (page.length < pageSize) break;
      offset += pageSize;
      await Future<void>.delayed(Duration.zero);
    }
    return audio;
  }

  @override
  Future<MusicFolder?> pickMusicFolder() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError(
        'Folder access is currently available on Android.',
      );
    }
    final result = await _channel.invokeMapMethod<String, Object?>(
      'pickMusicFolder',
    );
    if (result == null) return null;
    final uri = result['uri'];
    final name = result['name'];
    if (uri is! String || name is! String) {
      throw const FormatException(
        'Android returned an invalid selected music folder.',
      );
    }
    return MusicFolder(uri: uri, name: name);
  }

  @override
  Future<List<DeviceAudio>> scanMusicFolder(String uri) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError(
        'Folder access is currently available on Android.',
      );
    }
    final result = await _channel.invokeListMethod<Map<Object?, Object?>>(
      'scanMusicFolder',
      {'uri': uri},
    );
    if (result == null) {
      throw StateError('Android did not return the selected folder contents.');
    }
    return result.map(DeviceAudio.fromPlatformMap).toList(growable: false);
  }

  @override
  Future<void> releaseMusicFolder(String uri) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    await _channel.invokeMethod<void>('releaseMusicFolder', {'uri': uri});
  }

  @override
  Future<bool> deleteDeviceAudio(String uri) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError(
        'Deleting device music is currently available on Android.',
      );
    }
    final deleted = await _channel.invokeMethod<bool>('deleteDeviceAudio', {
      'uri': uri,
    });
    if (deleted == null) {
      throw StateError('Android did not report whether the song was deleted.');
    }
    return deleted;
  }

  @override
  Future<bool> deleteDeviceAudioBatch(List<String> uris) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError(
        'Deleting device music is currently available on Android.',
      );
    }
    if (uris.isEmpty) return true;
    final sdkVersion = await _channel.invokeMethod<int>('androidSdkVersion');
    if (sdkVersion == null) {
      throw StateError('Android did not report its SDK version.');
    }
    if (sdkVersion < 30 || uris.length == 1) {
      for (final uri in uris) {
        if (!await deleteDeviceAudio(uri)) return false;
      }
      return true;
    }
    final deleted = await _channel.invokeMethod<bool>(
      'deleteDeviceAudioBatch',
      {'uris': uris},
    );
    if (deleted == null) {
      throw StateError(
        'Android did not report whether the selected songs were deleted.',
      );
    }
    return deleted;
  }

  @override
  Future<Map<Object?, Object?>?> readImportedMetadata(
    String path,
    String fallbackTitle,
  ) async {
    if (defaultTargetPlatform != TargetPlatform.android) return null;
    return _channel.invokeMapMethod<Object?, Object?>(
      'readLocalAudioMetadata',
      {'path': path, 'fallbackTitle': fallbackTitle},
    );
  }
}

class MusicPermissionDeniedException implements Exception {
  const MusicPermissionDeniedException({this.permanentlyDenied = false});

  final bool permanentlyDenied;

  @override
  String toString() => 'Music access permission was not granted.';
}

class DeviceAudio {
  const DeviceAudio({
    required this.uri,
    required this.name,
    required this.title,
    required this.artist,
    this.album = 'Unknown album',
    this.durationMs,
    this.artworkUri,
    this.year,
    this.trackNumber,
    this.genre,
    this.bpm,
    this.sourceFolderUri,
    this.lyricsUri,
    this.dateModifiedSeconds,
    this.sizeBytes,
  });

  final String uri;
  final String name;
  final String title;
  final String artist;
  final String album;
  final int? durationMs;
  final String? artworkUri;
  final int? year;
  final int? trackNumber;
  final String? genre;
  final double? bpm;
  final String? sourceFolderUri;
  final String? lyricsUri;
  final int? dateModifiedSeconds;
  final int? sizeBytes;

  factory DeviceAudio.fromPlatformMap(Map<Object?, Object?> item) =>
      DeviceAudio(
        uri: item['uri']! as String,
        name: item['name']! as String,
        title: item['title']! as String,
        artist: item['artist']! as String,
        album: item['album'] as String? ?? 'Unknown album',
        durationMs: (item['durationMs'] as num?)?.toInt(),
        artworkUri: item['artworkUri'] as String?,
        year: (item['year'] as num?)?.toInt(),
        trackNumber: (item['trackNumber'] as num?)?.toInt(),
        genre: item['genre'] as String?,
        bpm: (item['bpm'] as num?)?.toDouble(),
        dateModifiedSeconds: (item['dateModifiedSeconds'] as num?)?.toInt(),
        sizeBytes: (item['sizeBytes'] as num?)?.toInt(),
        sourceFolderUri: item['sourceFolderUri'] as String?,
        lyricsUri: item['lyricsUri'] as String?,
      );
}

class MusicFolder {
  const MusicFolder({required this.uri, required this.name});

  final String uri;
  final String name;

  Map<String, String> toJson() => {'uri': uri, 'name': name};

  factory MusicFolder.fromJson(Map<String, Object?> json) =>
      MusicFolder(uri: json['uri']! as String, name: json['name']! as String);

  static List<MusicFolder> decodeList(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! List) {
      throw const FormatException('Stored music folders are not a list.');
    }
    return decoded
        .map((item) {
          if (item is! Map) {
            throw const FormatException(
              'Stored music folder is not an object.',
            );
          }
          return MusicFolder.fromJson(Map<String, Object?>.from(item));
        })
        .toList(growable: false);
  }
}
