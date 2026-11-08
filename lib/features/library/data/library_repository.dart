import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tone_player/features/library/data/tone_database.dart';
import 'package:tone_player/features/library/imported_track.dart';
import 'package:tone_player/features/library/library_platform_data_source.dart';
import 'package:tone_player/features/library/music_playlist.dart';

class LibrarySnapshot {
  const LibrarySnapshot({
    required this.tracks,
    required this.playlists,
    required this.folders,
    required this.favoriteTrackIds,
    required this.excludedTrackIds,
    required this.queueTrackIds,
    required this.currentTrackId,
    required this.positionMs,
  });

  final List<ImportedTrack> tracks;
  final List<MusicPlaylist> playlists;
  final List<MusicFolder> folders;
  final Set<String> favoriteTrackIds;
  final Set<String> excludedTrackIds;
  final List<String> queueTrackIds;
  final String? currentTrackId;
  final int positionMs;
}

class PlaybackHistoryEntry {
  const PlaybackHistoryEntry({
    required this.trackId,
    required this.title,
    required this.artist,
    required this.album,
    required this.playedAt,
    required this.listenedMs,
    required this.completed,
  });

  final String trackId;
  final String title;
  final String artist;
  final String album;
  final DateTime playedAt;
  final int listenedMs;
  final bool completed;
}

class MostPlayedTrack {
  const MostPlayedTrack({required this.track, required this.playCount});

  final ImportedTrack track;
  final int playCount;
}

class StoredTrackAnalysis {
  const StoredTrackAnalysis({
    required this.trackId,
    required this.analysisJson,
    required this.analyzedAt,
    this.bpm,
    this.musicalKey,
    this.energy,
  });

  final String trackId;
  final String analysisJson;
  final DateTime analyzedAt;
  final double? bpm;
  final String? musicalKey;
  final double? energy;
}

class LibraryDatabaseCorruptionException implements Exception {
  const LibraryDatabaseCorruptionException();

  @override
  String toString() => 'The local music database failed its integrity check.';
}

abstract interface class LibraryRepository {
  Future<LibrarySnapshot> load();
  Future<List<ImportedTrack>> searchTracks(String query);
  Future<List<List<ImportedTrack>>> possibleDuplicateGroups();
  Future<void> saveTracks(List<ImportedTrack> tracks);
  Future<void> saveDeviceScan({
    required List<ImportedTrack> changedTracks,
    required Set<String> unavailableTrackIds,
  });
  Future<void> savePlaylists(List<MusicPlaylist> playlists);
  Future<void> saveFolders(List<MusicFolder> folders);
  Future<void> saveFavorites(Set<String> trackIds);
  Future<void> saveExclusions(Set<String> trackIds);
  Future<void> saveQueue(
    List<String> trackIds, {
    required String? currentTrackId,
    required int positionMs,
  });
  Future<void> saveCurrentTrack(String? trackId);
  Future<void> savePlaybackPosition(int positionMs);
  Future<List<ImportedTrack>> recentlyPlayed({int limit = 20});
  Future<List<MostPlayedTrack>> mostPlayedTracks({int limit = 20});
  Future<List<PlaybackHistoryEntry>> listeningHistory({int limit = 100});
  Future<StoredTrackAnalysis?> trackAnalysisFor(String trackId);
  Future<Map<String, StoredTrackAnalysis>> trackAnalysesFor(
    Set<String> trackIds,
  );
  Future<void> saveTrackAnalysis(StoredTrackAnalysis analysis);
  Future<DateTime?> lastFullDeviceScanAt();
  Future<void> recordFullDeviceScan(DateTime completedAt);
  Future<void> close();
}

class DriftLibraryRepository extends DatabaseAccessor<ToneDatabase>
    implements LibraryRepository {
  DriftLibraryRepository({
    required this.database,
    required this._legacyPreferences,
  }) : super(database);

  static const _migrationKey = 'migration.shared_preferences.v1';
  static const _tracksKey = 'tone_library_tracks_v1';
  static const _favoritesKey = 'tone_library_favorites_v1';
  static const _playlistsKey = 'tone_library_playlists_v1';
  static const _foldersKey = 'tone_library_folders_v1';
  static const _queueKey = 'tone_playback_queue_v1';
  static const _currentTrackKey = 'tone_playback_current_v1';
  static const _positionKey = 'tone_playback_position_ms_v1';
  static const _mixExclusionsKey = 'tone_mix_exclusions_v1';

  final ToneDatabase database;
  final SharedPreferences _legacyPreferences;

  Future<void> initialize() async {
    final result = await database.customSelect('PRAGMA quick_check').get();
    if (result.length != 1 || result.single.data.values.single != 'ok') {
      throw const LibraryDatabaseCorruptionException();
    }
    await _migrateLegacyPreferences();
  }

  @override
  Future<LibrarySnapshot> load() async {
    final trackRows = await (database.select(
      database.libraryTracks,
    )..orderBy([(track) => OrderingTerm.asc(track.position)])).get();
    final playlistRows = await (database.select(
      database.playlists,
    )..orderBy([(playlist) => OrderingTerm.asc(playlist.position)])).get();
    final playlistTrackRows = await database
        .select(database.playlistTracks)
        .get();
    final folderRows = await (database.select(
      database.libraryFolders,
    )..orderBy([(folder) => OrderingTerm.asc(folder.position)])).get();
    final favoriteRows = await database.select(database.favorites).get();
    final excludedRows = await database.select(database.excludedTracks).get();
    final queueRows = await (database.select(
      database.playbackQueueEntries,
    )..orderBy([(entry) => OrderingTerm.asc(entry.position)])).get();
    final state = await database
        .select(database.playbackState)
        .getSingleOrNull();
    final trackIdsByPlaylist = <String, List<String>>{};
    for (final row in playlistTrackRows) {
      trackIdsByPlaylist.putIfAbsent(row.playlistId, () => []).add(row.trackId);
    }

    return LibrarySnapshot(
      tracks: trackRows.map(_toImportedTrack).toList(growable: false),
      playlists: playlistRows
          .map(
            (row) => MusicPlaylist(
              id: row.id,
              name: row.name,
              trackIds: List.unmodifiable(
                trackIdsByPlaylist[row.id] ?? const [],
              ),
              createdAt: row.createdAt,
            ),
          )
          .toList(growable: false),
      folders: folderRows
          .map((row) => MusicFolder(uri: row.uri, name: row.name))
          .toList(growable: false),
      favoriteTrackIds: favoriteRows.map((row) => row.trackId).toSet(),
      excludedTrackIds: excludedRows.map((row) => row.trackId).toSet(),
      queueTrackIds: queueRows
          .map((row) => row.trackId)
          .toList(growable: false),
      currentTrackId: state?.currentTrackId,
      positionMs: state?.positionMs ?? 0,
    );
  }

  @override
  Future<List<ImportedTrack>> searchTracks(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      final rows = await (database.select(
        database.libraryTracks,
      )..orderBy([(track) => OrderingTerm.asc(track.position)])).get();
      return rows.map(_toImportedTrack).toList(growable: false);
    }

    final expression = normalizedQuery
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .map((term) => '"${term.replaceAll('"', '""')}"*')
        .join(' AND ');
    final rows = await database
        .customSelect(
          'SELECT library_tracks.* FROM library_tracks '
          'JOIN library_track_search '
          'ON library_track_search.track_id = library_tracks.id '
          'WHERE library_track_search MATCH ? '
          'ORDER BY bm25(library_track_search)',
          variables: [Variable.withString(expression)],
          readsFrom: {database.libraryTracks},
        )
        .get();
    return rows
        .map((row) => _toImportedTrack(database.libraryTracks.map(row.data)))
        .toList(growable: false);
  }

  @override
  Future<List<List<ImportedTrack>>> possibleDuplicateGroups() async {
    final rows = await database.select(database.libraryTracks).get();
    final byMetadata = <String, List<ImportedTrack>>{};
    for (final row in rows) {
      final track = _toImportedTrack(row);
      final key = '${_normalize(track.title)}\u001f${_normalize(track.artist)}';
      byMetadata.putIfAbsent(key, () => []).add(track);
    }

    final groups = <List<ImportedTrack>>[];
    for (final candidates in byMetadata.values) {
      if (candidates.length < 2) continue;
      final sorted = [...candidates]
        ..sort(
          (first, second) =>
              (first.durationMs ?? -1).compareTo(second.durationMs ?? -1),
        );
      final remaining = <ImportedTrack>{...sorted};
      while (remaining.isNotEmpty) {
        final seed = remaining.first;
        remaining.remove(seed);
        final group = <ImportedTrack>[seed];
        final duration = seed.durationMs;
        if (duration != null && duration > 0) {
          final matches = remaining
              .where(
                (track) =>
                    track.durationMs != null &&
                    (track.durationMs! - duration).abs() <= 3000,
              )
              .toList(growable: false);
          group.addAll(matches);
          remaining.removeAll(matches);
        } else {
          final undurationed = remaining
              .where((track) => track.durationMs == null)
              .toList(growable: false);
          group.addAll(undurationed);
          remaining.removeAll(undurationed);
        }
        if (group.length > 1) groups.add(List.unmodifiable(group));
      }
    }
    groups.sort(
      (first, second) => first.first.title.compareTo(second.first.title),
    );
    return List.unmodifiable(groups);
  }

  @override
  Future<void> saveTracks(List<ImportedTrack> tracks) => database.transaction(
    () async {
      final artistRows = <String, ArtistsCompanion>{};
      final albumRows = <String, AlbumsCompanion>{};
      final trackRows = <LibraryTracksCompanion>[];
      final now = DateTime.now();

      for (var index = 0; index < tracks.length; index++) {
        final track = tracks[index];
        final artistName = track.artist.trim().isEmpty
            ? 'Unknown artist'
            : track.artist.trim();
        final albumName = track.album.trim().isEmpty
            ? 'Unknown album'
            : track.album.trim();
        final artistId = _artistId(artistName);
        final albumId = _albumId(artistId, albumName);
        artistRows[artistId] = ArtistsCompanion.insert(
          id: artistId,
          name: artistName,
          normalizedName: _normalize(artistName),
        );
        albumRows[albumId] = AlbumsCompanion.insert(
          id: albumId,
          title: albumName,
          artistId: artistId,
          year: Value(track.year),
          artworkUri: Value(track.artworkUri),
        );
        trackRows.add(
          LibraryTracksCompanion.insert(
            id: track.id,
            path: track.path,
            sourceName: Value(track.sourceName),
            title: track.title,
            artist: track.artist,
            album: track.album,
            artistId: artistId,
            albumId: albumId,
            durationMs: Value(track.durationMs),
            artworkUri: Value(track.artworkUri),
            year: Value(track.year),
            trackNumber: Value(track.trackNumber),
            genre: Value(track.genre),
            bpm: Value(track.bpm),
            isDeviceMedia: Value(track.isDeviceMedia),
            sourceFolderUri: Value(track.sourceFolderUri),
            lyricsUri: Value(track.lyricsUri),
            sourceProvider: Value(track.sourceProvider),
            providerTrackId: Value(track.providerTrackId),
            licenseUrl: Value(track.licenseUrl),
            metadataReviewed: Value(track.metadataReviewed),
            isAvailable: Value(track.isAvailable),
            position: index,
            lastSeenAt: Value(
              track.isDeviceMedia && track.isAvailable ? now : null,
            ),
            fileSizeBytes: Value(track.fileSizeBytes),
            fileModifiedAt: Value(track.dateModifiedAt),
          ),
        );
      }

      await batch((batch) {
        batch.insertAllOnConflictUpdate(
          database.artists,
          artistRows.values.toList(growable: false),
        );
        batch.insertAllOnConflictUpdate(
          database.albums,
          albumRows.values.toList(growable: false),
        );
        batch.insertAllOnConflictUpdate(database.libraryTracks, trackRows);
      });

      final retainedIds = tracks.map((track) => track.id).toSet();
      final existingRows = await database.select(database.libraryTracks).get();
      final removedIds = existingRows
          .map((row) => row.id)
          .where((id) => !retainedIds.contains(id))
          .toList(growable: false);
      for (var offset = 0; offset < removedIds.length; offset += 400) {
        final end = (offset + 400).clamp(0, removedIds.length);
        final chunk = removedIds.sublist(offset, end);
        await (database.delete(
          database.libraryTracks,
        )..where((row) => row.id.isIn(chunk))).go();
      }
    },
  );

  @override
  Future<void> saveDeviceScan({
    required List<ImportedTrack> changedTracks,
    required Set<String> unavailableTrackIds,
  }) => database.transaction(() async {
    final existing = await database.select(database.libraryTracks).get();
    final positions = {for (final row in existing) row.id: row.position};
    var nextPosition =
        existing.fold<int>(
          -1,
          (maximum, row) => row.position > maximum ? row.position : maximum,
        ) +
        1;
    final artistRows = <String, ArtistsCompanion>{};
    final albumRows = <String, AlbumsCompanion>{};
    final trackRows = <LibraryTracksCompanion>[];
    final now = DateTime.now();
    for (final track in changedTracks) {
      final artistName = track.artist.trim().isEmpty
          ? 'Unknown artist'
          : track.artist.trim();
      final albumName = track.album.trim().isEmpty
          ? 'Unknown album'
          : track.album.trim();
      final artistId = _artistId(artistName);
      final albumId = _albumId(artistId, albumName);
      artistRows[artistId] = ArtistsCompanion.insert(
        id: artistId,
        name: artistName,
        normalizedName: _normalize(artistName),
      );
      albumRows[albumId] = AlbumsCompanion.insert(
        id: albumId,
        title: albumName,
        artistId: artistId,
        year: Value(track.year),
        artworkUri: Value(track.artworkUri),
      );
      final position = positions[track.id] ?? nextPosition++;
      trackRows.add(
        LibraryTracksCompanion.insert(
          id: track.id,
          path: track.path,
          sourceName: Value(track.sourceName),
          title: track.title,
          artist: track.artist,
          album: track.album,
          artistId: artistId,
          albumId: albumId,
          durationMs: Value(track.durationMs),
          artworkUri: Value(track.artworkUri),
          year: Value(track.year),
          trackNumber: Value(track.trackNumber),
          genre: Value(track.genre),
          bpm: Value(track.bpm),
          isDeviceMedia: const Value(true),
          sourceFolderUri: Value(track.sourceFolderUri),
          lyricsUri: Value(track.lyricsUri),
          sourceProvider: Value(track.sourceProvider),
          providerTrackId: Value(track.providerTrackId),
          licenseUrl: Value(track.licenseUrl),
          metadataReviewed: Value(track.metadataReviewed),
          isAvailable: Value(track.isAvailable),
          position: position,
          lastSeenAt: Value(track.isAvailable ? now : null),
          fileSizeBytes: Value(track.fileSizeBytes),
          fileModifiedAt: Value(track.dateModifiedAt),
        ),
      );
    }

    await batch((batch) {
      if (artistRows.isNotEmpty) {
        batch.insertAllOnConflictUpdate(
          database.artists,
          artistRows.values.toList(growable: false),
        );
      }
      if (albumRows.isNotEmpty) {
        batch.insertAllOnConflictUpdate(
          database.albums,
          albumRows.values.toList(growable: false),
        );
      }
      if (trackRows.isNotEmpty) {
        batch.insertAllOnConflictUpdate(database.libraryTracks, trackRows);
      }
      for (final id in unavailableTrackIds) {
        batch.update(
          database.libraryTracks,
          const LibraryTracksCompanion(isAvailable: Value(false)),
          where: (track) => track.id.equals(id),
        );
      }
    });
  });

  @override
  Future<void> savePlaylists(List<MusicPlaylist> playlists) =>
      database.transaction(() async {
        final validTrackRows = await database
            .select(database.libraryTracks)
            .get();
        final validTrackIds = validTrackRows.map((row) => row.id).toSet();
        await database.delete(database.playlistTracks).go();
        await database.delete(database.playlists).go();
        final playlistRows = <PlaylistsCompanion>[];
        final memberships = <PlaylistTracksCompanion>[];
        for (var index = 0; index < playlists.length; index++) {
          final playlist = playlists[index];
          playlistRows.add(
            PlaylistsCompanion.insert(
              id: playlist.id,
              name: playlist.name,
              createdAt: playlist.createdAt,
              position: index,
            ),
          );
          var position = 0;
          for (final trackId in playlist.trackIds) {
            if (!validTrackIds.contains(trackId)) continue;
            memberships.add(
              PlaylistTracksCompanion.insert(
                playlistId: playlist.id,
                trackId: trackId,
                position: position++,
              ),
            );
          }
        }
        await batch((batch) {
          if (playlistRows.isNotEmpty) {
            batch.insertAllOnConflictUpdate(database.playlists, playlistRows);
          }
          if (memberships.isNotEmpty) {
            batch.insertAll(database.playlistTracks, memberships);
          }
        });
      });

  @override
  Future<void> saveFolders(List<MusicFolder> folders) =>
      database.transaction(() async {
        await database.delete(database.libraryFolders).go();
        if (folders.isEmpty) return;
        final now = DateTime.now();
        await batch((batch) {
          batch.insertAll(database.libraryFolders, [
            for (var index = 0; index < folders.length; index++)
              LibraryFoldersCompanion.insert(
                uri: folders[index].uri,
                name: folders[index].name,
                grantedAt: now,
                position: index,
              ),
          ]);
        });
      });

  @override
  Future<void> saveFavorites(Set<String> trackIds) =>
      _replaceTrackSet(trackIds, excluded: false);

  @override
  Future<void> saveExclusions(Set<String> trackIds) =>
      _replaceTrackSet(trackIds, excluded: true);

  Future<void> _replaceTrackSet(
    Set<String> trackIds, {
    required bool excluded,
  }) async {
    await database.transaction(() async {
      if (excluded) {
        await database.delete(database.excludedTracks).go();
      } else {
        await database.delete(database.favorites).go();
      }
      final valid = await database.select(database.libraryTracks).get();
      final validIds = valid.map((row) => row.id).toSet();
      final retained = trackIds
          .where(validIds.contains)
          .toList(growable: false);
      if (retained.isEmpty) return;
      final now = DateTime.now();
      await batch((batch) {
        if (excluded) {
          batch.insertAll(
            database.excludedTracks,
            retained.map(
              (id) =>
                  ExcludedTracksCompanion.insert(trackId: id, excludedAt: now),
            ),
          );
        } else {
          batch.insertAll(
            database.favorites,
            retained.map(
              (id) => FavoritesCompanion.insert(trackId: id, addedAt: now),
            ),
          );
        }
      });
    });
  }

  @override
  Future<void> saveQueue(
    List<String> trackIds, {
    required String? currentTrackId,
    required int positionMs,
  }) => database.transaction(() async {
    await database.delete(database.playbackQueueEntries).go();
    await batch((batch) {
      if (trackIds.isNotEmpty) {
        batch.insertAll(database.playbackQueueEntries, [
          for (var index = 0; index < trackIds.length; index++)
            PlaybackQueueEntriesCompanion.insert(
              position: Value(index),
              trackId: trackIds[index],
            ),
        ]);
      }
    });
    await into(database.playbackState).insertOnConflictUpdate(
      PlaybackStateCompanion.insert(
        id: const Value(0),
        currentTrackId: Value(currentTrackId),
        positionMs: Value(positionMs),
      ),
    );
  });

  @override
  Future<void> saveCurrentTrack(String? trackId) async {
    await database.transaction(() async {
      final current = await database
          .select(database.playbackState)
          .getSingleOrNull();
      await into(database.playbackState).insertOnConflictUpdate(
        PlaybackStateCompanion.insert(
          id: const Value(0),
          currentTrackId: Value(trackId),
          positionMs: Value(
            trackId == current?.currentTrackId ? current?.positionMs ?? 0 : 0,
          ),
        ),
      );
      if (trackId == null || trackId == current?.currentTrackId) return;
      final row = await (database.select(
        database.libraryTracks,
      )..where((track) => track.id.equals(trackId))).getSingleOrNull();
      if (row == null) return;
      await into(database.playbackHistory).insert(
        PlaybackHistoryCompanion.insert(
          trackId: row.id,
          title: row.title,
          artist: row.artist,
          album: row.album,
          playedAt: DateTime.now(),
        ),
      );
    });
  }

  @override
  Future<void> savePlaybackPosition(int positionMs) async {
    final state = await database
        .select(database.playbackState)
        .getSingleOrNull();
    await into(database.playbackState).insertOnConflictUpdate(
      PlaybackStateCompanion.insert(
        id: const Value(0),
        currentTrackId: Value(state?.currentTrackId),
        positionMs: Value(positionMs < 0 ? 0 : positionMs),
      ),
    );
  }

  @override
  Future<List<ImportedTrack>> recentlyPlayed({int limit = 20}) async {
    if (limit <= 0) return const [];
    final result = await database
        .customSelect(
          'SELECT track_id FROM playback_history '
          'GROUP BY track_id ORDER BY MAX(played_at) DESC LIMIT ?',
          variables: [Variable.withInt(limit)],
        )
        .get();
    final tracks = await database.select(database.libraryTracks).get();
    final byId = {for (final row in tracks) row.id: _toImportedTrack(row)};
    return result
        .map((row) => byId[row.read<String>('track_id')])
        .whereType<ImportedTrack>()
        .toList(growable: false);
  }

  @override
  Future<List<MostPlayedTrack>> mostPlayedTracks({int limit = 20}) async {
    if (limit <= 0) return const [];
    final result = await database
        .customSelect(
          'SELECT track_id, COUNT(*) AS play_count FROM playback_history '
          'GROUP BY track_id '
          'ORDER BY play_count DESC, MAX(played_at) DESC LIMIT ?',
          variables: [Variable.withInt(limit)],
          readsFrom: {database.playbackHistory},
        )
        .get();
    if (result.isEmpty) return const [];
    final ids = result.map((row) => row.read<String>('track_id')).toSet();
    final tracks = await (database.select(
      database.libraryTracks,
    )..where((track) => track.id.isIn(ids))).get();
    final tracksById = {
      for (final row in tracks) row.id: _toImportedTrack(row),
    };
    return result
        .map((row) {
          final track = tracksById[row.read<String>('track_id')];
          return track == null
              ? null
              : MostPlayedTrack(
                  track: track,
                  playCount: row.read<int>('play_count'),
                );
        })
        .whereType<MostPlayedTrack>()
        .toList(growable: false);
  }

  @override
  Future<List<PlaybackHistoryEntry>> listeningHistory({int limit = 100}) async {
    if (limit <= 0) return const [];
    final rows =
        await (database.select(database.playbackHistory)
              ..orderBy([(entry) => OrderingTerm.desc(entry.playedAt)])
              ..limit(limit))
            .get();
    return rows
        .map(
          (row) => PlaybackHistoryEntry(
            trackId: row.trackId,
            title: row.title,
            artist: row.artist,
            album: row.album,
            playedAt: row.playedAt,
            listenedMs: row.listenedMs,
            completed: row.completed,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<StoredTrackAnalysis?> trackAnalysisFor(String trackId) async {
    final row = await (database.select(
      database.trackAnalysis,
    )..where((analysis) => analysis.trackId.equals(trackId))).getSingleOrNull();
    if (row == null) return null;
    return _storedTrackAnalysis(row);
  }

  @override
  Future<Map<String, StoredTrackAnalysis>> trackAnalysesFor(
    Set<String> trackIds,
  ) async {
    if (trackIds.isEmpty) return const {};
    final rows = await (database.select(
      database.trackAnalysis,
    )..where((analysis) => analysis.trackId.isIn(trackIds))).get();
    return {for (final row in rows) row.trackId: _storedTrackAnalysis(row)};
  }

  @override
  Future<void> saveTrackAnalysis(StoredTrackAnalysis analysis) async {
    final decoded = jsonDecode(analysis.analysisJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Track analysis must be a JSON object.');
    }
    if (analysis.bpm != null &&
        (!analysis.bpm!.isFinite || analysis.bpm! <= 0)) {
      throw const FormatException('Track analysis BPM must be positive.');
    }
    if (analysis.energy != null &&
        (!analysis.energy!.isFinite ||
            analysis.energy! < 0 ||
            analysis.energy! > 1)) {
      throw const FormatException(
        'Track analysis energy must be between 0 and 1.',
      );
    }
    await into(database.trackAnalysis).insertOnConflictUpdate(
      TrackAnalysisCompanion.insert(
        trackId: analysis.trackId,
        bpm: Value(analysis.bpm),
        musicalKey: Value(analysis.musicalKey),
        energy: Value(analysis.energy),
        analysisJson: Value(analysis.analysisJson),
        analyzedAt: analysis.analyzedAt,
      ),
    );
  }

  StoredTrackAnalysis _storedTrackAnalysis(TrackAnalysi row) {
    final analysisJson = row.analysisJson;
    if (analysisJson == null) {
      throw const FormatException(
        'Stored track analysis is missing its payload.',
      );
    }
    return StoredTrackAnalysis(
      trackId: row.trackId,
      analysisJson: analysisJson,
      analyzedAt: row.analyzedAt,
      bpm: row.bpm,
      musicalKey: row.musicalKey,
      energy: row.energy,
    );
  }

  @override
  Future<DateTime?> lastFullDeviceScanAt() async {
    final row =
        await (database.select(database.userPreferences)..where(
              (preference) => preference.key.equals('library.full_scan_at'),
            ))
            .getSingleOrNull();
    if (row == null) return null;
    final decoded = jsonDecode(row.valueJson);
    if (decoded is! String) {
      throw const FormatException('Stored library scan timestamp is invalid.');
    }
    return DateTime.parse(decoded);
  }

  @override
  Future<void> recordFullDeviceScan(DateTime completedAt) async {
    await into(database.userPreferences).insertOnConflictUpdate(
      UserPreferencesCompanion.insert(
        key: 'library.full_scan_at',
        valueJson: jsonEncode(completedAt.toIso8601String()),
        updatedAt: completedAt,
      ),
    );
  }

  @override
  Future<void> close() => database.close();

  Future<void> _migrateLegacyPreferences() async {
    final marker = await (database.select(
      database.userPreferences,
    )..where((row) => row.key.equals(_migrationKey))).getSingleOrNull();
    if (marker != null) return;

    final trackJson = _legacyPreferences.getString(_tracksKey);
    final tracks = trackJson == null
        ? const <ImportedTrack>[]
        : ImportedTrack.decodeList(trackJson);
    final playlistJson = _legacyPreferences.getString(_playlistsKey);
    final playlists = playlistJson == null
        ? const <MusicPlaylist>[]
        : MusicPlaylist.decodeList(playlistJson);
    final folderJson = _legacyPreferences.getString(_foldersKey);
    final folders = folderJson == null
        ? const <MusicFolder>[]
        : MusicFolder.decodeList(folderJson);
    final queueIds = _decodeStringList(_legacyPreferences.getString(_queueKey));
    final favorites =
        (_legacyPreferences.getStringList(_favoritesKey) ?? const []).toSet();
    final exclusions =
        (_legacyPreferences.getStringList(_mixExclusionsKey) ?? const [])
            .toSet();
    final currentTrackId = _legacyPreferences.getString(_currentTrackKey);
    final positionMs = _legacyPreferences.getInt(_positionKey) ?? 0;

    await database.transaction(() async {
      await _writeTracks(tracks);
      await _writePlaylists(playlists, tracks.map((track) => track.id).toSet());
      await _writeFolders(folders);
      await _writeTrackSet(favorites, excluded: false);
      await _writeTrackSet(exclusions, excluded: true);
      await _writeQueue(
        queueIds,
        currentTrackId: currentTrackId,
        positionMs: positionMs,
      );
      final migratedTracks = await database
          .select(database.libraryTracks)
          .get();
      if (migratedTracks.length != tracks.length) {
        throw StateError(
          'Legacy music library migration did not preserve all track records.',
        );
      }
      await into(database.userPreferences).insert(
        UserPreferencesCompanion.insert(
          key: _migrationKey,
          valueJson: jsonEncode({
            'completedAt': DateTime.now().toIso8601String(),
          }),
          updatedAt: DateTime.now(),
        ),
      );
    });
  }

  Future<void> _writeTracks(List<ImportedTrack> tracks) async {
    if (tracks.isEmpty) return;
    final artistRows = <String, ArtistsCompanion>{};
    final albumRows = <String, AlbumsCompanion>{};
    final trackRows = <LibraryTracksCompanion>[];
    final now = DateTime.now();
    for (var index = 0; index < tracks.length; index++) {
      final track = tracks[index];
      final artistName = track.artist.trim().isEmpty
          ? 'Unknown artist'
          : track.artist.trim();
      final albumName = track.album.trim().isEmpty
          ? 'Unknown album'
          : track.album.trim();
      final artistId = _artistId(artistName);
      final albumId = _albumId(artistId, albumName);
      artistRows[artistId] = ArtistsCompanion.insert(
        id: artistId,
        name: artistName,
        normalizedName: _normalize(artistName),
      );
      albumRows[albumId] = AlbumsCompanion.insert(
        id: albumId,
        title: albumName,
        artistId: artistId,
        year: Value(track.year),
        artworkUri: Value(track.artworkUri),
      );
      trackRows.add(
        LibraryTracksCompanion.insert(
          id: track.id,
          path: track.path,
          sourceName: Value(track.sourceName),
          title: track.title,
          artist: track.artist,
          album: track.album,
          artistId: artistId,
          albumId: albumId,
          durationMs: Value(track.durationMs),
          artworkUri: Value(track.artworkUri),
          year: Value(track.year),
          trackNumber: Value(track.trackNumber),
          genre: Value(track.genre),
          bpm: Value(track.bpm),
          isDeviceMedia: Value(track.isDeviceMedia),
          sourceFolderUri: Value(track.sourceFolderUri),
          lyricsUri: Value(track.lyricsUri),
          sourceProvider: Value(track.sourceProvider),
          providerTrackId: Value(track.providerTrackId),
          licenseUrl: Value(track.licenseUrl),
          metadataReviewed: Value(track.metadataReviewed),
          isAvailable: Value(track.isAvailable),
          position: index,
          lastSeenAt: Value(
            track.isDeviceMedia && track.isAvailable ? now : null,
          ),
          fileSizeBytes: Value(track.fileSizeBytes),
          fileModifiedAt: Value(track.dateModifiedAt),
        ),
      );
    }
    await batch((batch) {
      batch.insertAllOnConflictUpdate(
        database.artists,
        artistRows.values.toList(growable: false),
      );
      batch.insertAllOnConflictUpdate(
        database.albums,
        albumRows.values.toList(growable: false),
      );
      batch.insertAllOnConflictUpdate(database.libraryTracks, trackRows);
    });
  }

  Future<void> _writePlaylists(
    List<MusicPlaylist> playlists,
    Set<String> validTrackIds,
  ) async {
    if (playlists.isEmpty) return;
    final playlistRows = <PlaylistsCompanion>[];
    final memberships = <PlaylistTracksCompanion>[];
    for (var index = 0; index < playlists.length; index++) {
      final playlist = playlists[index];
      playlistRows.add(
        PlaylistsCompanion.insert(
          id: playlist.id,
          name: playlist.name,
          createdAt: playlist.createdAt,
          position: index,
        ),
      );
      var position = 0;
      for (final trackId in playlist.trackIds) {
        if (!validTrackIds.contains(trackId)) continue;
        memberships.add(
          PlaylistTracksCompanion.insert(
            playlistId: playlist.id,
            trackId: trackId,
            position: position++,
          ),
        );
      }
    }
    await batch((batch) {
      batch.insertAllOnConflictUpdate(database.playlists, playlistRows);
      if (memberships.isNotEmpty) {
        batch.insertAll(database.playlistTracks, memberships);
      }
    });
  }

  Future<void> _writeFolders(List<MusicFolder> folders) async {
    if (folders.isEmpty) return;
    final now = DateTime.now();
    await batch((batch) {
      batch.insertAll(database.libraryFolders, [
        for (var index = 0; index < folders.length; index++)
          LibraryFoldersCompanion.insert(
            uri: folders[index].uri,
            name: folders[index].name,
            grantedAt: now,
            position: index,
          ),
      ]);
    });
  }

  Future<void> _writeTrackSet(
    Set<String> trackIds, {
    required bool excluded,
  }) async {
    if (trackIds.isEmpty) return;
    final rows = await database.select(database.libraryTracks).get();
    final validIds = rows.map((row) => row.id).toSet();
    final retained = trackIds.where(validIds.contains).toList(growable: false);
    if (retained.isEmpty) return;
    final now = DateTime.now();
    await batch((batch) {
      if (excluded) {
        batch.insertAll(
          database.excludedTracks,
          retained.map(
            (id) =>
                ExcludedTracksCompanion.insert(trackId: id, excludedAt: now),
          ),
        );
      } else {
        batch.insertAll(
          database.favorites,
          retained.map(
            (id) => FavoritesCompanion.insert(trackId: id, addedAt: now),
          ),
        );
      }
    });
  }

  Future<void> _writeQueue(
    List<String> trackIds, {
    required String? currentTrackId,
    required int positionMs,
  }) async {
    if (trackIds.isNotEmpty) {
      await batch((batch) {
        batch.insertAll(database.playbackQueueEntries, [
          for (var index = 0; index < trackIds.length; index++)
            PlaybackQueueEntriesCompanion.insert(
              position: Value(index),
              trackId: trackIds[index],
            ),
        ]);
      });
    }
    await into(database.playbackState).insertOnConflictUpdate(
      PlaybackStateCompanion.insert(
        id: const Value(0),
        currentTrackId: Value(currentTrackId),
        positionMs: Value(positionMs < 0 ? 0 : positionMs),
      ),
    );
  }

  static List<String> _decodeStringList(String? value) {
    if (value == null) return const [];
    final decoded = jsonDecode(value);
    if (decoded is! List || decoded.any((item) => item is! String)) {
      throw const FormatException('Stored playback queue is invalid.');
    }
    return decoded.cast<String>();
  }

  static ImportedTrack _toImportedTrack(LibraryTrack row) => ImportedTrack(
    id: row.id,
    path: row.path,
    sourceName: row.sourceName,
    title: row.title,
    artist: row.artist,
    album: row.album,
    durationMs: row.durationMs,
    artworkUri: row.artworkUri,
    year: row.year,
    trackNumber: row.trackNumber,
    genre: row.genre,
    bpm: row.bpm,
    isDeviceMedia: row.isDeviceMedia,
    sourceFolderUri: row.sourceFolderUri,
    lyricsUri: row.lyricsUri,
    sourceProvider: row.sourceProvider,
    providerTrackId: row.providerTrackId,
    licenseUrl: row.licenseUrl,
    metadataReviewed: row.metadataReviewed,
    isAvailable: row.isAvailable,
    dateModifiedAt: row.fileModifiedAt,
    fileSizeBytes: row.fileSizeBytes,
  );

  static String _normalize(String value) => value.trim().toLowerCase();

  static String _artistId(String artist) => 'artist:${_normalize(artist)}';

  static String _albumId(String artistId, String album) =>
      'album:$artistId\u001f${_normalize(album)}';
}
