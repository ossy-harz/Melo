import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:melo_player/features/library/data/library_repository.dart';
import 'package:melo_player/features/library/data/melo_database.dart';
import 'package:melo_player/features/library/imported_track.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('upgrades a version 2 library without losing tracks', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final directory = await Directory.systemTemp.createTemp(
      'tone-library-migration-',
    );
    final file = File('${directory.path}\\tone.db');
    final originalDatabase = MeloDatabase.open(file);
    final originalRepository = DriftLibraryRepository(
      database: originalDatabase,
      legacyPreferences: preferences,
    );
    try {
      await originalRepository.initialize();
      await originalRepository.saveTracks([
        const ImportedTrack(
          id: 'mornye-track',
          path: 'content://media/external/audio/media/9',
          sourceName: 'Download_09.flac',
          title: 'The Ninth Song',
          artist: 'Tone Test',
          isDeviceMedia: true,
        ),
      ]);
      await originalDatabase.customStatement(
        'ALTER TABLE library_tracks DROP COLUMN source_name',
      );
      await originalDatabase.customStatement('PRAGMA user_version = 2');
    } finally {
      await originalRepository.close();
    }

    final upgradedRepository = DriftLibraryRepository(
      database: MeloDatabase.open(file),
      legacyPreferences: preferences,
    );
    try {
      await upgradedRepository.initialize();
      final tracks = (await upgradedRepository.load()).tracks;
      expect(tracks.single.title, 'The Ninth Song');
      expect(tracks.single.sourceName, isNull);
    } finally {
      await upgradedRepository.close();
      await directory.delete(recursive: true);
    }
  });
}
