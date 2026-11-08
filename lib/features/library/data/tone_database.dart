import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

part 'tone_database.g.dart';

class Artists extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get normalizedName => text().unique()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Albums extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get artistId => text().references(Artists, #id)();
  IntColumn get year => integer().nullable()();
  TextColumn get artworkUri => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(name: 'tracks_title_idx', columns: {#title})
@TableIndex(name: 'tracks_artist_idx', columns: {#artist})
@TableIndex(name: 'tracks_album_idx', columns: {#album})
@TableIndex(name: 'tracks_availability_idx', columns: {#isAvailable})
@TableIndex(name: 'tracks_artist_album_idx', columns: {#artistId, #albumId})
@TableIndex(name: 'tracks_order_idx', columns: {#position})
class LibraryTracks extends Table {
  TextColumn get id => text()();
  TextColumn get path => text()();
  TextColumn get sourceName => text().nullable()();
  TextColumn get title => text()();
  TextColumn get artist => text()();
  TextColumn get album => text()();
  TextColumn get artistId => text().references(Artists, #id)();
  TextColumn get albumId => text().references(Albums, #id)();
  IntColumn get durationMs => integer().nullable()();
  TextColumn get artworkUri => text().nullable()();
  IntColumn get year => integer().nullable()();
  IntColumn get trackNumber => integer().nullable()();
  TextColumn get genre => text().nullable()();
  RealColumn get bpm => real().nullable()();
  BoolColumn get isDeviceMedia =>
      boolean().withDefault(const Constant(false))();
  TextColumn get sourceFolderUri => text().nullable()();
  TextColumn get lyricsUri => text().nullable()();
  TextColumn get sourceProvider => text().nullable()();
  TextColumn get providerTrackId => text().nullable()();
  TextColumn get licenseUrl => text().nullable()();
  BoolColumn get metadataReviewed =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get isAvailable => boolean().withDefault(const Constant(true))();
  IntColumn get position => integer()();
  DateTimeColumn get lastSeenAt => dateTime().nullable()();
  IntColumn get fileSizeBytes => integer().nullable()();
  DateTimeColumn get fileModifiedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class LibraryFolders extends Table {
  TextColumn get uri => text()();
  TextColumn get name => text()();
  DateTimeColumn get grantedAt => dateTime()();
  IntColumn get position => integer()();

  @override
  Set<Column<Object>> get primaryKey => {uri};
}

@TableIndex(name: 'playlists_name_idx', columns: {#name})
@TableIndex(name: 'playlists_order_idx', columns: {#position})
class Playlists extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get position => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(
  name: 'playlist_tracks_order_idx',
  columns: {#playlistId, #position},
  unique: true,
)
class PlaylistTracks extends Table {
  TextColumn get playlistId =>
      text().references(Playlists, #id, onDelete: KeyAction.cascade)();
  TextColumn get trackId =>
      text().references(LibraryTracks, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();

  @override
  Set<Column<Object>> get primaryKey => {playlistId, trackId};
}

class Favorites extends Table {
  TextColumn get trackId =>
      text().references(LibraryTracks, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {trackId};
}

class ExcludedTracks extends Table {
  TextColumn get trackId =>
      text().references(LibraryTracks, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get excludedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {trackId};
}

@TableIndex(
  name: 'playback_queue_order_idx',
  columns: {#position},
  unique: true,
)
class PlaybackQueueEntries extends Table {
  IntColumn get position => integer()();
  TextColumn get trackId => text()();

  @override
  Set<Column<Object>> get primaryKey => {position};
}

class PlaybackState extends Table {
  IntColumn get id => integer().withDefault(const Constant(0))();
  TextColumn get currentTrackId => text().nullable()();
  IntColumn get positionMs => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(name: 'playback_history_time_idx', columns: {#playedAt})
@TableIndex(name: 'playback_history_track_idx', columns: {#trackId, #playedAt})
class PlaybackHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get trackId => text()();
  TextColumn get title => text()();
  TextColumn get artist => text()();
  TextColumn get album => text()();
  DateTimeColumn get playedAt => dateTime()();
  IntColumn get listenedMs => integer().withDefault(const Constant(0))();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
}

class TrackAnalysis extends Table {
  TextColumn get trackId =>
      text().references(LibraryTracks, #id, onDelete: KeyAction.cascade)();
  RealColumn get bpm => real().nullable()();
  TextColumn get musicalKey => text().nullable()();
  RealColumn get energy => real().nullable()();
  TextColumn get analysisJson => text().nullable()();
  DateTimeColumn get analyzedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {trackId};
}

class ArtworkCache extends Table {
  TextColumn get sourceUri => text()();
  TextColumn get cachedPath => text()();
  IntColumn get byteLength => integer().nullable()();
  DateTimeColumn get cachedAt => dateTime()();
  DateTimeColumn get lastAccessedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {sourceUri};
}

class Downloads extends Table {
  TextColumn get trackId =>
      text().references(LibraryTracks, #id, onDelete: KeyAction.cascade)();
  TextColumn get provider => text()();
  TextColumn get providerTrackId => text()();
  TextColumn get licenseUrl => text().nullable()();
  DateTimeColumn get downloadedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {trackId};
}

class DjSessions extends Table {
  TextColumn get id => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  TextColumn get settingsJson => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class DjSessionEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sessionId =>
      text().references(DjSessions, #id, onDelete: KeyAction.cascade)();
  TextColumn get eventType => text()();
  TextColumn get trackId => text().nullable()();
  TextColumn get payloadJson => text().nullable()();
  DateTimeColumn get occurredAt => dateTime()();
}

class UserPreferences extends Table {
  TextColumn get key => text()();
  TextColumn get valueJson => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

class AudioProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get settingsJson => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    Artists,
    Albums,
    LibraryTracks,
    LibraryFolders,
    Playlists,
    PlaylistTracks,
    Favorites,
    ExcludedTracks,
    PlaybackQueueEntries,
    PlaybackState,
    PlaybackHistory,
    TrackAnalysis,
    ArtworkCache,
    Downloads,
    DjSessions,
    DjSessionEvents,
    UserPreferences,
    AudioProfiles,
  ],
)
class ToneDatabase extends _$ToneDatabase {
  ToneDatabase(super.executor);

  factory ToneDatabase.open(File file) =>
      ToneDatabase(NativeDatabase.createInBackground(file));

  factory ToneDatabase.inMemory() => ToneDatabase(NativeDatabase.memory());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _createSearchIndex();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) await _createSearchIndex();
      if (from < 3) {
        await migrator.addColumn(libraryTracks, libraryTracks.sourceName);
      }
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA journal_mode = WAL');
    },
  );

  Future<void> _createSearchIndex() async {
    await customStatement(
      'CREATE VIRTUAL TABLE library_track_search USING '
      'fts5(track_id UNINDEXED, title, artist, album, '
      'tokenize = "unicode61 remove_diacritics 2")',
    );
    await customStatement('''
      CREATE TRIGGER library_track_search_insert
      AFTER INSERT ON library_tracks BEGIN
        INSERT INTO library_track_search(track_id, title, artist, album)
        VALUES (new.id, new.title, new.artist, new.album);
      END
    ''');
    await customStatement('''
      CREATE TRIGGER library_track_search_update
      AFTER UPDATE OF title, artist, album ON library_tracks BEGIN
        DELETE FROM library_track_search WHERE track_id = old.id;
        INSERT INTO library_track_search(track_id, title, artist, album)
        VALUES (new.id, new.title, new.artist, new.album);
      END
    ''');
    await customStatement('''
      CREATE TRIGGER library_track_search_delete
      AFTER DELETE ON library_tracks BEGIN
        DELETE FROM library_track_search WHERE track_id = old.id;
      END
    ''');
  }
}
