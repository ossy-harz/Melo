import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ArtworkCache {
  ArtworkCache({required this._directory, this.maxBytes = 128 * 1024 * 1024});

  static Future<ArtworkCache>? _shared;

  static Future<ArtworkCache> get shared => _shared ??= _openShared();

  @visibleForTesting
  static void setSharedForTesting(ArtworkCache? cache) {
    _shared = cache == null ? null : Future.value(cache);
  }

  static Future<ArtworkCache> _openShared() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory(p.join(support.path, 'artwork-cache'));
    await directory.create(recursive: true);
    return ArtworkCache(directory: directory);
  }

  final Directory _directory;
  final int maxBytes;
  final Map<String, Future<Uint8List?>> _pending = {};

  Future<Uint8List?> getOrFetch(
    String key,
    Future<Uint8List?> Function() fetch,
  ) => _pending
      .putIfAbsent(key, () async {
        final file = _fileFor(key);
        try {
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            if (bytes.isNotEmpty) {
              await file.setLastModified(DateTime.now());
              return Uint8List.fromList(bytes);
            }
            await file.delete();
          }
        } on FileSystemException catch (error, stackTrace) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stackTrace,
              library: 'tone artwork cache',
              context: ErrorDescription('while reading cached artwork'),
            ),
          );
        }

        final bytes = await fetch();
        if (bytes == null || bytes.isEmpty) return null;
        try {
          await _directory.create(recursive: true);
          final temporary = File(
            '${file.path}.${DateTime.now().microsecondsSinceEpoch}.partial',
          );
          try {
            await temporary.writeAsBytes(bytes, flush: true);
            await temporary.rename(file.path);
          } finally {
            if (await temporary.exists()) await temporary.delete();
          }
          await _prune();
        } on FileSystemException catch (error, stackTrace) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stackTrace,
              library: 'tone artwork cache',
              context: ErrorDescription('while storing extracted artwork'),
            ),
          );
        }
        return bytes;
      })
      .whenComplete(() => _pending.remove(key));

  Future<void> clear() async {
    if (await _directory.exists()) {
      await for (final entity in _directory.list()) {
        if (entity is File) await entity.delete();
      }
    }
  }

  File _fileFor(String key) =>
      File(p.join(_directory.path, '${sha256.convert(key.codeUnits)}.art'));

  Future<void> _prune() async {
    final files = <({File file, int length, DateTime modified})>[];
    var totalBytes = 0;
    await for (final entity in _directory.list()) {
      if (entity is! File || !entity.path.endsWith('.art')) continue;
      final stat = await entity.stat();
      files.add((file: entity, length: stat.size, modified: stat.modified));
      totalBytes += stat.size;
    }
    if (totalBytes <= maxBytes) return;
    files.sort((first, second) => first.modified.compareTo(second.modified));
    for (final entry in files) {
      if (totalBytes <= maxBytes) break;
      await entry.file.delete();
      totalBytes -= entry.length;
    }
  }
}
