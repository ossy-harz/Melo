import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tone_player/features/library/data/artwork_cache.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('tone-artwork-cache-');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('persists extracted artwork and serves it without refetching', () async {
    final firstCache = ArtworkCache(directory: directory);
    var fetches = 0;
    final first = await firstCache.getOrFetch('content://album/1', () async {
      fetches++;
      return Uint8List.fromList([1, 2, 3]);
    });

    final restoredCache = ArtworkCache(directory: directory);
    final restored = await restoredCache.getOrFetch(
      'content://album/1',
      () async {
        fetches++;
        return Uint8List.fromList([4, 5, 6]);
      },
    );

    expect(first, [1, 2, 3]);
    expect(restored, [1, 2, 3]);
    expect(fetches, 1);
  });

  test(
    'prunes least-recently-used artwork after exceeding the configured cap',
    () async {
      final cache = ArtworkCache(directory: directory, maxBytes: 4);
      await cache.getOrFetch(
        'first',
        () async => Uint8List.fromList([1, 2, 3]),
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await cache.getOrFetch(
        'second',
        () async => Uint8List.fromList([4, 5, 6]),
      );

      expect(await Directory(directory.path).list().length, 1);
      var fetches = 0;
      final restored = await cache.getOrFetch('second', () async {
        fetches++;
        return Uint8List.fromList([4, 5, 6]);
      });
      expect(restored, [4, 5, 6]);
      expect(fetches, 0);
    },
  );

  test(
    'returns null for unavailable artwork without creating cache entries',
    () async {
      final cache = ArtworkCache(directory: directory);
      expect(await cache.getOrFetch('missing', () async => null), isNull);
      expect(await directory.list().toList(), isEmpty);
    },
  );
}
