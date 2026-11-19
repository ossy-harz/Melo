import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:melo_player/features/library/imported_track.dart';
import 'package:melo_player/features/library/library_platform_data_source.dart';
import 'package:melo_player/features/library/data/library_repository.dart';
import 'package:melo_player/features/library/data/melo_database.dart';
import 'package:melo_player/features/library/music_playlist.dart';
import 'package:melo_player/features/library/song_metadata_enricher.dart';
import 'package:melo_player/features/mix/personal_mix.dart';
import 'package:melo_player/features/mix/local_discovery.dart';

export 'package:melo_player/features/library/library_platform_data_source.dart'
    show
        DeviceAudio,
        LibraryPlatformDataSource,
        MusicFolder,
        MusicPermissionDeniedException,
        MethodChannelLibraryPlatformDataSource;

class BulkTrackRemovalResult {
  const BulkTrackRemovalResult({
    required this.removed,
    required this.failures,
    this.cancelled = false,
  });

  final List<ImportedTrack> removed;
  final Map<ImportedTrack, Object> failures;
  final bool cancelled;
}

class MusicLibrary extends ChangeNotifier {
  MusicLibrary._({
    required this._musicDirectory,
    required this._preferences,
    required this._repository,
    required this._pickAudio,
    required this._scanDeviceAudio,
    required this._pickMusicFolder,
    required this._scanMusicFolder,
    required this._releaseMusicFolder,
    required this._deleteDeviceAudio,
    required this._deleteDeviceAudioBatch,
    required this._metadataReader,
    required this._isAndroid,
  });

  @visibleForTesting
  factory MusicLibrary.forTesting({
    required Directory musicDirectory,
    required SharedPreferences preferences,
    required Future<List<PickedAudio>> Function() pickAudio,
    Future<List<DeviceAudio>> Function()? scanDeviceAudio,
    Future<List<DeviceAudio>> Function({DateTime? modifiedSince})?
    scanDeviceAudioSince,
    Future<MusicFolder?> Function()? pickMusicFolder,
    Future<List<DeviceAudio>> Function(String uri)? scanMusicFolder,
    Future<void> Function(String uri)? releaseMusicFolder,
    Future<bool> Function(String uri)? deleteDeviceAudio,
    Future<bool> Function(List<String> uris)? deleteDeviceAudioBatch,
    Future<Map<Object?, Object?>?> Function(String path, String fallbackTitle)?
    readImportedMetadata,
    bool Function()? isAndroid,
    LibraryRepository? repository,
  }) => MusicLibrary._(
    musicDirectory: musicDirectory,
    preferences: preferences,
    repository: repository,
    pickAudio: pickAudio,
    scanDeviceAudio:
        scanDeviceAudioSince ??
        ({DateTime? modifiedSince}) =>
            scanDeviceAudio?.call() ?? _emptyDeviceScan(),
    pickMusicFolder: pickMusicFolder ?? _emptyFolderPicker,
    scanMusicFolder: scanMusicFolder ?? _emptyFolderScan,
    releaseMusicFolder: releaseMusicFolder ?? _emptyFolderRelease,
    deleteDeviceAudio: deleteDeviceAudio ?? _unsupportedTrackDeletion,
    deleteDeviceAudioBatch:
        deleteDeviceAudioBatch ??
        ((uris) async {
          final delete = deleteDeviceAudio ?? _unsupportedTrackDeletion;
          for (final uri in uris) {
            if (!await delete(uri)) return false;
          }
          return true;
        }),
    metadataReader: readImportedMetadata ?? _emptyMetadataReader,
    isAndroid: isAndroid ?? (() => Platform.isAndroid),
  );

  static const _tracksKey = 'tone_library_tracks_v1';
  static const _favoritesKey = 'tone_library_favorites_v1';
  static const _playlistsKey = 'tone_library_playlists_v1';
  static const _foldersKey = 'tone_library_folders_v1';
  static const _queueKey = 'tone_playback_queue_v1';
  static const _currentTrackKey = 'tone_playback_current_v1';
  static const _positionKey = 'tone_playback_position_ms_v1';
  static const _mixExclusionsKey = 'tone_mix_exclusions_v1';
  static const supportedExtensions = [
    'mp3',
    'm4a',
    'aac',
    'flac',
    'wav',
    'ogg',
    'opus',
    'webm',
  ];

  final Directory _musicDirectory;
  Directory get musicDirectory => _musicDirectory;
  final SharedPreferences _preferences;
  final LibraryRepository? _repository;
  LibraryRepository get analysisRepository =>
      _repository ??
      (throw StateError(
        'Persistent music analysis requires a database-backed library.',
      ));
  final Future<List<PickedAudio>> Function() _pickAudio;
  final Future<List<DeviceAudio>> Function({DateTime? modifiedSince})
  _scanDeviceAudio;
  final Future<MusicFolder?> Function() _pickMusicFolder;
  final Future<List<DeviceAudio>> Function(String uri) _scanMusicFolder;
  final Future<void> Function(String uri) _releaseMusicFolder;
  final Future<bool> Function(String uri) _deleteDeviceAudio;
  final Future<bool> Function(List<String> uris) _deleteDeviceAudioBatch;
  final Future<Map<Object?, Object?>?> Function(
    String path,
    String fallbackTitle,
  )
  _metadataReader;
  final bool Function() _isAndroid;
  final ValueNotifier<int> _playbackHistoryRevision = ValueNotifier(0);
  List<ImportedTrack> _tracks = const [];
  List<MusicPlaylist> _playlists = const [];
  List<MusicFolder> _musicFolders = const [];
  String? _currentTrackId;
  Set<String> _favoriteTrackIds = {};
  Set<String> _mixExcludedTrackIds = {};
  Map<String, int> _trackIndexById = const {};
  List<String> _queuedTrackOrder = const [];
  final Map<String, int> _artistRadioRotations = {};
  final List<MediaItem> _recentSessionItems = [];
  final Map<String, int> _artistPlayCounts = {};
  String? _lastRecordedMediaId;
  bool _isImporting = false;
  int _lastImportSkippedDuplicates = 0;
  int _importSequence = 0;

  List<ImportedTrack> get tracks => UnmodifiableListView(_tracks);
  List<MediaItem> get recentSessionItems =>
      List.unmodifiable(_recentSessionItems);
  Set<String> get excludedTrackIds => Set.unmodifiable(_mixExcludedTrackIds);

  /// Ranked artists derived from recent session plays, persistent listening
  /// history, and favorited tracks.
  List<String> get topAffinityArtists {
    final scores = <String, int>{};
    final canonicalNames = <String, String>{};

    void addScore(String? rawArtist, int delta) {
      final clean = (rawArtist ?? '').trim();
      final lower = clean.toLowerCase();
      if (clean.isEmpty || lower == 'unknown artist') return;
      canonicalNames.putIfAbsent(lower, () => clean);
      scores[lower] = (scores[lower] ?? 0) + delta;
    }

    for (final item in _recentSessionItems.take(15)) {
      addScore(item.artist, 3);
    }
    for (final entry in _artistPlayCounts.entries) {
      addScore(entry.key, entry.value);
    }
    for (final track in _tracks) {
      if (_favoriteTrackIds.contains(track.id)) {
        addScore(track.artist, 2);
      }
    }

    final ranked = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ranked
        .map((e) => canonicalNames[e.key] ?? e.key)
        .toList(growable: false);
  }

  Set<String> get recentCanonicalSongKeys {
    final keys = <String>{};
    for (final item in _recentSessionItems.take(20)) {
      final cleanTitle =
          SongMetadataEnricher.cleanTitle(
            item.title,
            rawArtist: item.artist,
          ).trim().toLowerCase();
      final cleanArtist = (item.artist ?? '').trim().toLowerCase();
      if (cleanTitle.isNotEmpty) {
        keys.add('$cleanTitle|$cleanArtist');
      }
    }
    return keys;
  }
  ValueListenable<int> get playbackHistoryRevision => _playbackHistoryRevision;
  List<MusicPlaylist> get playlists => UnmodifiableListView(_playlists);
  List<MusicFolder> get musicFolders => UnmodifiableListView(_musicFolders);
  List<ImportedTrack> get favoriteTracks => _tracks
      .where((track) => _favoriteTrackIds.contains(track.id))
      .toList(growable: false);
  List<PlaylistSuggestion> get playlistSuggestions =>
      LocalDiscovery.suggestions(_tracks, favoriteTrackIds: _favoriteTrackIds);
  bool get isImporting => _isImporting;
  int get lastImportSkippedDuplicates => _lastImportSkippedDuplicates;
  bool get isEmpty => _tracks.isEmpty;
  bool get hasMixExclusions => _mixExcludedTrackIds.isNotEmpty;
  int get mixExclusionCount => _mixExcludedTrackIds.length;
  int get tracksWithDuration => _tracks
      .where((track) => track.durationMs != null && track.durationMs! > 0)
      .length;
  int get tracksWithoutDuration => _tracks
      .where((track) => track.durationMs == null || track.durationMs! <= 0)
      .length;

  bool isFavorite(String trackId) => _favoriteTrackIds.contains(trackId);

  bool isFavoriteMediaItem(MediaItem item) {
    if (_favoriteTrackIds.contains(item.id)) return true;
    final libId = item.extras?['libraryId'] as String?;
    if (libId != null && _favoriteTrackIds.contains(libId)) return true;
    final providerId = _providerTrackIdForMediaItem(item);
    final localMatch = findMatchingLocalTrack(
      providerTrackId: providerId,
      title: item.title,
      artist: item.artist,
      path: item.extras?['localPath'] as String? ?? item.id,
    );
    if (localMatch != null && _favoriteTrackIds.contains(localMatch.id)) {
      return true;
    }
    if (providerId != null && providerId.isNotEmpty) {
      for (final track in _tracks) {
        if (track.providerTrackId == providerId &&
            _favoriteTrackIds.contains(track.id)) {
          return true;
        }
      }
    }
    return false;
  }

  String? _providerTrackIdForMediaItem(MediaItem item) {
    final extraId = item.extras?['providerTrackId'] as String?;
    if (extraId != null && extraId.isNotEmpty) return extraId;
    if (item.id.startsWith('spotify:')) return item.id.substring(8);
    if (item.id.startsWith('youtube:')) return item.id.substring(8);
    return null;
  }
  bool isExcludedFromMixes(String trackId) =>
      _mixExcludedTrackIds.contains(trackId);

  List<ImportedTrack> tracksForPlaylist(String playlistId) {
    final playlist = _playlistById(playlistId);
    return playlist.trackIds
        .map((id) => _trackIndexById[id])
        .whereType<int>()
        .map((index) => _tracks[index])
        .toList(growable: false);
  }

  List<ImportedTrack> artistRadioTracks(
    String artist, {
    Map<String, int> playCounts = const {},
    int rotation = 0,
  }) => LocalDiscovery.artistRadio(
    _tracks,
    artist,
    favoriteTrackIds: _favoriteTrackIds,
    playCounts: playCounts,
    rotation: rotation,
  );

  Future<void> playArtistRadio(AudioHandler handler, String artist) async {
    final key = artist.trim().toLowerCase();
    final rotation = _artistRadioRotations[key] ?? 0;
    _artistRadioRotations[key] = rotation + 1;
    final playCounts = {
      for (final item in await mostPlayedTracks(limit: _tracks.length))
        item.track.id: item.playCount,
    };
    final station = artistRadioTracks(
      artist,
      playCounts: playCounts,
      rotation: rotation,
    ).where((track) => track.isAvailable).toList(growable: false);
    if (station.isEmpty) {
      throw StateError('There are no playable songs for $artist radio.');
    }
    await playMix(handler, station);
  }

  List<ImportedTrack> searchTracks(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return tracks;
    return _tracks
        .where(
          (track) =>
              track.title.toLowerCase().contains(normalizedQuery) ||
              track.artist.toLowerCase().contains(normalizedQuery) ||
              track.album.toLowerCase().contains(normalizedQuery),
        )
        .toList(growable: false);
  }

  static bool _isStreamPath(String path) =>
      path.startsWith('youtube:') ||
      path.startsWith('spotify:') ||
      path.startsWith('http://') ||
      path.startsWith('https://');

  static bool _isLocalOnDeviceTrack(ImportedTrack track) {
    if (!track.isAvailable) return false;
    if (_isStreamPath(track.path)) return false;
    if (track.isDeviceMedia) return true;
    return File(track.path).existsSync();
  }

  static String _normalizeSongText(String value) => value
      .toLowerCase()
      .replaceAll(
        RegExp(
          r'[\(\[](?:official\s*(?:music\s*)?(?:video|audio|lyric\s*video|visualizer)|lyrics?|audio|hd|hq|4k|remastered.*?)[\)\]]',
          caseSensitive: false,
        ),
        '',
      )
      .replaceFirst(RegExp(r'\s*-\s*topic$', caseSensitive: false), '')
      .replaceAll(RegExp(r'[^\w\s]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Locates an existing track in the local device library by provider ID, path, or title/artist.
  ImportedTrack? findMatchingLocalTrack({
    String? providerTrackId,
    String? title,
    String? artist,
    String? path,
  }) {
    if (path != null && path.isNotEmpty) {
      for (final track in _tracks) {
        if (track.path == path && _isLocalOnDeviceTrack(track)) return track;
      }
    }

    if (providerTrackId != null && providerTrackId.isNotEmpty) {
      for (final track in _tracks) {
        if (track.providerTrackId == providerTrackId &&
            _isLocalOnDeviceTrack(track)) {
          return track;
        }
      }
    }

    if (title != null && title.trim().isNotEmpty) {
      final cleanTitle = _normalizeSongText(title);
      final cleanArtist = _normalizeSongText(artist ?? '');
      if (cleanTitle.isEmpty) return null;
      String stripArtistPrefix(String t, String a) {
        if (a.isNotEmpty && t.startsWith('$a ')) {
          return t.substring(a.length + 1).trim();
        }
        return t;
      }
      final normQueryTitle = stripArtistPrefix(cleanTitle, cleanArtist);
      for (final track in _tracks) {
        if (!_isLocalOnDeviceTrack(track)) continue;
        final trackTitle = _normalizeSongText(track.title);
        final trackArtist = _normalizeSongText(track.artist);
        if (trackTitle.isEmpty) continue;

        final normTrackTitle = stripArtistPrefix(trackTitle, trackArtist);
        final titleMatch = trackTitle == cleanTitle ||
            (normTrackTitle.isNotEmpty &&
                normQueryTitle.isNotEmpty &&
                normTrackTitle == normQueryTitle);

        if (titleMatch) {
          if (cleanArtist.isEmpty ||
              trackArtist.isEmpty ||
              cleanArtist == 'unknown artist' ||
              trackArtist == 'unknown artist' ||
              cleanArtist == 'ondevice audio' ||
              trackArtist == 'ondevice audio') {
            return track;
          }
          if (trackArtist == cleanArtist ||
              trackArtist.contains(cleanArtist) ||
              cleanArtist.contains(trackArtist)) {
            return track;
          }
        }
      }
    }
    return null;
  }

  /// Checks whether a track is already stored on the device (MediaStore or downloaded file).
  bool isTrackDownloaded({
    String? providerTrackId,
    String? title,
    String? artist,
    String? path,
  }) {
    final match = findMatchingLocalTrack(
      providerTrackId: providerTrackId,
      title: title,
      artist: artist,
      path: path,
    );
    return match != null;
  }

  Future<List<ImportedTrack>> searchTracksIndexed(String query) =>
      _repository?.searchTracks(query) ?? Future.value(searchTracks(query));

  Future<List<List<ImportedTrack>>> possibleDuplicateGroups() =>
      _repository?.possibleDuplicateGroups() ??
      Future.value(const <List<ImportedTrack>>[]);

  int indexOfTrack(String id) => _trackIndexById[id] ?? -1;
  ImportedTrack? trackForId(String id) => _trackById(id);

  static Future<MusicLibrary> open({
    LibraryPlatformDataSource? platformDataSource,
  }) async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory(p.join(support.path, 'music'));
    await directory.create(recursive: true);
    final preferences = await SharedPreferences.getInstance();
    final databaseFile = File(p.join(support.path, 'tone_library.sqlite'));
    final database = MeloDatabase.open(databaseFile);
    var repository = DriftLibraryRepository(
      database: database,
      legacyPreferences: preferences,
    );
    try {
      await repository.initialize();
    } on LibraryDatabaseCorruptionException catch (error, stackTrace) {
      await repository.close();
      final quarantined = File(
        '${databaseFile.path}.corrupt-${DateTime.now().microsecondsSinceEpoch}',
      );
      await databaseFile.rename(quarantined.path);
      repository = DriftLibraryRepository(
        database: MeloDatabase.open(databaseFile),
        legacyPreferences: preferences,
      );
      await repository.initialize();
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'tone library',
          context: ErrorDescription(
            'while recovering the corrupt database; the original was preserved at ${quarantined.path}',
          ),
        ),
      );
    } on Object {
      await repository.close();
      rethrow;
    }
    final dataSource =
        platformDataSource ?? const MethodChannelLibraryPlatformDataSource();
    final library = MusicLibrary._(
      musicDirectory: directory,
      preferences: preferences,
      repository: repository,
      pickAudio: _pickFromDevice,
      scanDeviceAudio: dataSource.scanDeviceAudio,
      pickMusicFolder: dataSource.pickMusicFolder,
      scanMusicFolder: dataSource.scanMusicFolder,
      releaseMusicFolder: dataSource.releaseMusicFolder,
      deleteDeviceAudio: dataSource.deleteDeviceAudio,
      deleteDeviceAudioBatch: dataSource.deleteDeviceAudioBatch,
      metadataReader: dataSource.readImportedMetadata,
      isAndroid: () => Platform.isAndroid,
    );
    await library.load();
    unawaited(
      library._hydrateTasteMemory().catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'tone library',
            context: ErrorDescription('while hydrating listening taste memory'),
          ),
        );
      }),
    );
    unawaited(
      library.refreshImportedMetadata().catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'tone library',
            context: ErrorDescription('while refreshing saved audio metadata'),
          ),
        );
      }),
    );
    return library;
  }

  Future<void> load() async {
    List<ImportedTrack> decoded;
    if (_repository case final repository?) {
      final snapshot = await repository.load();
      _favoriteTrackIds = snapshot.favoriteTrackIds;
      _mixExcludedTrackIds = snapshot.excludedTrackIds;
      _playlists = snapshot.playlists;
      _musicFolders = snapshot.folders;
      _queuedTrackOrder = snapshot.queueTrackIds;
      _currentTrackId = snapshot.currentTrackId;
      decoded = snapshot.tracks;
    } else {
      _favoriteTrackIds =
          (_preferences.getStringList(_favoritesKey) ?? const []).toSet();
      _mixExcludedTrackIds =
          (_preferences.getStringList(_mixExclusionsKey) ?? const []).toSet();
      final storedPlaylists = _preferences.getString(_playlistsKey);
      if (storedPlaylists != null) {
        _playlists = MusicPlaylist.decodeList(storedPlaylists);
      }
      final storedFolders = _preferences.getString(_foldersKey);
      if (storedFolders != null) {
        _musicFolders = MusicFolder.decodeList(storedFolders);
      }
      _currentTrackId = _preferences.getString(_currentTrackKey);
      final stored = _preferences.getString(_tracksKey);
      decoded = stored == null ? const [] : ImportedTrack.decodeList(stored);
    }

    if (_isAndroid()) {
      var streamRestored = false;
      final filtered = decoded
          .where(
            (track) =>
                _isStreamPath(track.path) || !_isNonSongAudioTrack(track),
          )
          .map((track) {
            if (_isStreamPath(track.path) && !track.isAvailable) {
              streamRestored = true;
              return track.withMetadata(isAvailable: true);
            }
            return track;
          })
          .toList(growable: false);
      _setTracks(filtered);
      if (streamRestored) {
        unawaited(_saveTracks(filtered));
      }
      unawaited(_verifyTrackFilesAsync(filtered));
      return;
    }

    final loadedTracks = <ImportedTrack>[];
    var trackMetadataChanged = false;
    for (final track in decoded) {
      if (_isStreamPath(track.path)) {
        if (!track.isAvailable) {
          trackMetadataChanged = true;
          loadedTracks.add(track.withMetadata(isAvailable: true));
        } else {
          loadedTracks.add(track);
        }
        continue;
      }
      final file = track.isDeviceMedia ? null : File(track.path);
      final available = file == null || await file.exists();
      final modifiedAt =
          track.dateModifiedAt ??
          (available ? await file?.lastModified() : null);
      final fileSizeBytes =
          track.fileSizeBytes ?? (available ? await file?.length() : null);
      if (track.isAvailable != available ||
          track.dateModifiedAt != modifiedAt ||
          track.fileSizeBytes != fileSizeBytes) {
        trackMetadataChanged = true;
      }
      loadedTracks.add(
        track.withMetadata(
          isAvailable: available,
          dateModifiedAt: modifiedAt,
          fileSizeBytes: fileSizeBytes,
        ),
      );
    }
    _setTracks(loadedTracks);
    if (trackMetadataChanged) {
      await _saveTracks(loadedTracks);
    }
  }

  static bool _isNonSongAudioTrack(ImportedTrack track) {
    final durationMs = track.durationMs;
    if (durationMs != null && durationMs > 0 && durationMs < 30000) {
      return true;
    }
    final lowerName =
        (track.sourceName ?? p.basename(track.path)).trim().toLowerCase();
    final lowerTitle = track.title.trim().toLowerCase();
    for (final candidate in [lowerName, lowerTitle]) {
      if (candidate.startsWith('ptt-') ||
          candidate.startsWith('aud-') ||
          candidate.startsWith('call_recording') ||
          candidate.startsWith('voice_') ||
          candidate.contains('whatsapp voice') ||
          candidate.contains('whatsapp audio')) {
        return true;
      }
    }
    return false;
  }

  Future<void> _verifyTrackFilesAsync(List<ImportedTrack> initialTracks) async {
    var changed = false;
    final verifiedById = <String, ImportedTrack>{};
    for (final track in initialTracks) {
      if (track.isDeviceMedia) continue;
      if (_isStreamPath(track.path)) {
        if (!track.isAvailable) {
          changed = true;
          verifiedById[track.id] = track.withMetadata(isAvailable: true);
        }
        continue;
      }
      final file = File(track.path);
      final available = await file.exists();
      final modifiedAt =
          track.dateModifiedAt ?? (available ? await file.lastModified() : null);
      final fileSizeBytes =
          track.fileSizeBytes ?? (available ? await file.length() : null);
      if (track.isAvailable != available ||
          track.dateModifiedAt != modifiedAt ||
          track.fileSizeBytes != fileSizeBytes) {
        changed = true;
        verifiedById[track.id] = track.withMetadata(
          isAvailable: available,
          dateModifiedAt: modifiedAt,
          fileSizeBytes: fileSizeBytes,
        );
      }
    }
    if (!changed) return;
    final updated = _tracks
        .map((t) => verifiedById[t.id] ?? t)
        .toList(growable: false);
    _setTracks(updated);
    await _saveTracks(updated);
    notifyListeners();
  }

  Future<void> refreshImportedMetadata() async {
    if (!_isAndroid()) return;
    final candidates = _tracks
        .where(
          (track) =>
              !track.isDeviceMedia &&
              !track.metadataReviewed &&
              !_isStreamPath(track.path),
        )
        .toList(growable: false);
    if (candidates.isEmpty) return;

    final enriched = <String, ImportedTrack>{};
    for (final track in candidates) {
      try {
        final metadata = await _metadataReader(track.path, track.title);
        enriched[track.id] = metadata == null
            ? track.withMetadata(metadataReviewed: true)
            : track.withMetadata(
                title: metadata['title'] as String?,
                artist: metadata['artist'] as String?,
                album: metadata['album'] as String?,
                durationMs: (metadata['durationMs'] as num?)?.toInt(),
                artworkUri: metadata['artworkUri'] as String?,
                year: (metadata['year'] as num?)?.toInt(),
                trackNumber: (metadata['trackNumber'] as num?)?.toInt(),
                genre: metadata['genre'] as String?,
                bpm: (metadata['bpm'] as num?)?.toDouble(),
                metadataReviewed: true,
              );
      } on PlatformException catch (error, stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'tone library',
            context: ErrorDescription('while refreshing saved audio metadata'),
          ),
        );
        enriched[track.id] = track.withMetadata(metadataReviewed: true);
      }
    }

    if (enriched.isEmpty) return;
    final updated = _tracks
        .map((track) => enriched[track.id] ?? track)
        .toList(growable: false);
    await _saveTracks(updated);
    _setTracks(updated);
    notifyListeners();
  }

  Future<int> addMusicFolder() async {
    if (_isImporting) return 0;
    _setImporting(true);
    try {
      final folder = await _pickMusicFolder();
      if (folder == null) return 0;
      if (_musicFolders.any((saved) => saved.uri == folder.uri)) return 0;

      final discovered = await _scanMusicFolder(folder.uri);
      final tracks = _tracks
          .where((track) => track.sourceFolderUri != folder.uri)
          .toList(growable: false);
      final folderTracks = _tracksFromDeviceAudio(discovered);
      final updatedFolders = [..._musicFolders, folder];
      await _saveFolders(updatedFolders);
      await _saveTracks([...tracks, ...folderTracks]);
      _musicFolders = updatedFolders;
      _setTracks([...tracks, ...folderTracks]);
      _invalidatePlaybackQueue();
      notifyListeners();
      return folderTracks.length;
    } finally {
      _setImporting(false);
    }
  }

  Future<void> removeMusicFolder(MusicFolder folder) async {
    final removedTrackIds = _tracks
        .where((track) => track.sourceFolderUri == folder.uri)
        .map((track) => track.id)
        .toSet();
    await _releaseMusicFolder(folder.uri);
    final updatedFolders = _musicFolders
        .where((saved) => saved.uri != folder.uri)
        .toList(growable: false);
    final updatedTracks = _tracks
        .where((track) => track.sourceFolderUri != folder.uri)
        .toList(growable: false);
    final updatedPlaylists = _playlists
        .map(
          (playlist) => _copyPlaylist(
            playlist,
            trackIds: playlist.trackIds
                .where((id) => !removedTrackIds.contains(id))
                .toList(growable: false),
          ),
        )
        .toList(growable: false);
    final updatedFavorites = Set<String>.from(_favoriteTrackIds)
      ..removeAll(removedTrackIds);
    await _saveFolders(updatedFolders);
    await _saveTracks(updatedTracks);
    await _savePlaylists(updatedPlaylists);
    await _saveFavorites(updatedFavorites);
    _musicFolders = updatedFolders;
    _playlists = updatedPlaylists;
    _favoriteTrackIds = updatedFavorites;
    _setTracks(updatedTracks);
    _invalidatePlaybackQueue();
    notifyListeners();
  }

  static List<ImportedTrack> _tracksFromDeviceAudio(
    Iterable<DeviceAudio> audio,
  ) => audio
      .where(
        (item) => supportedExtensions.contains(
          p.extension(item.name).toLowerCase().replaceFirst('.', ''),
        ),
      )
      .map(
        (item) => ImportedTrack.fromDeviceMedia(
          uri: item.uri,
          sourceName: item.name,
          title: item.title,
          artist: item.artist,
          album: item.album,
          durationMs: item.durationMs,
          artworkUri: item.artworkUri,
          year: item.year,
          trackNumber: item.trackNumber,
          genre: item.genre,
          bpm: item.bpm,
          sourceFolderUri: item.sourceFolderUri,
          lyricsUri: item.lyricsUri,
          dateModifiedAt: item.dateModifiedSeconds == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(
                  item.dateModifiedSeconds! * 1000,
                ),
          fileSizeBytes: item.sizeBytes,
        ),
      )
      .toList(growable: false);

  Future<bool> toggleFavorite(String trackId) async {
    if (!_trackIndexById.containsKey(trackId)) {
      throw StateError('This song is no longer in the library.');
    }
    final updated = Set<String>.from(_favoriteTrackIds);
    final isFavorite = !updated.remove(trackId);
    if (isFavorite) updated.add(trackId);
    await _saveFavorites(updated);
    _favoriteTrackIds = updated;
    notifyListeners();
    return isFavorite;
  }

  Future<String> ensureMediaItemRegistered(MediaItem item) async {
    final existingId = item.extras?['libraryId'] as String?;
    if (existingId != null && _trackIndexById.containsKey(existingId)) {
      return existingId;
    }
    if (_trackIndexById.containsKey(item.id)) return item.id;
    final providerId = _providerTrackIdForMediaItem(item);
    final localMatch = findMatchingLocalTrack(
      providerTrackId: providerId,
      title: item.title,
      artist: item.artist,
      path: item.extras?['localPath'] as String? ?? item.id,
    );
    if (localMatch != null) return localMatch.id;
    for (final track in _tracks) {
      if (track.path == item.id ||
          (providerId != null &&
              providerId.isNotEmpty &&
              track.providerTrackId == providerId)) {
        return track.id;
      }
    }

    final isSpotify =
        item.id.startsWith('spotify:') ||
        item.extras?['downloadProvider'] == 'Spotify' ||
        item.extras?['source'] == 'spotify';
    final isDevice =
        item.id.startsWith('/') ||
        item.id.startsWith('file:') ||
        item.id.startsWith('content:');
    final remoteTrack = ImportedTrack(
      id: item.id,
      path: item.id,
      title: item.title,
      artist: item.artist ?? 'Unknown artist',
      album: item.album ?? 'Streaming',
      durationMs: item.duration?.inMilliseconds,
      artworkUri: item.artUri?.toString(),
      sourceProvider: isDevice
          ? null
          : isSpotify
          ? 'Spotify'
          : 'youtube',
      providerTrackId: providerId,
      isAvailable: true,
      isDeviceMedia: isDevice,
    );
    final registered = await registerOrFindRemoteTracks([remoteTrack]);
    return registered.isNotEmpty ? registered.first.id : item.id;
  }

  Future<bool> toggleFavoriteMediaItem(MediaItem item) async {
    final trackId = await ensureMediaItemRegistered(item);
    return toggleFavorite(trackId);
  }

  Future<MusicPlaylist> createPlaylist(String name) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Playlist name cannot be empty.');
    }
    if (_playlists.any(
      (playlist) => playlist.name.toLowerCase() == normalizedName.toLowerCase(),
    )) {
      throw StateError('A playlist with that name already exists.');
    }
    final playlist = MusicPlaylist(
      id: 'playlist_${DateTime.now().microsecondsSinceEpoch}',
      name: normalizedName,
      trackIds: const [],
      createdAt: DateTime.now(),
    );
    final updated = [..._playlists, playlist];
    await _savePlaylists(updated);
    _playlists = updated;
    notifyListeners();
    return playlist;
  }

  Future<void> renamePlaylist(String playlistId, String name) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Playlist name cannot be empty.');
    }
    if (_playlists.any(
      (playlist) =>
          playlist.id != playlistId &&
          playlist.name.toLowerCase() == normalizedName.toLowerCase(),
    )) {
      throw StateError('A playlist with that name already exists.');
    }
    final updated = _playlists
        .map(
          (playlist) => playlist.id == playlistId
              ? _copyPlaylist(playlist, name: normalizedName)
              : playlist,
        )
        .toList(growable: false);
    if (updated.every((playlist) => playlist.id != playlistId)) {
      throw StateError('This playlist no longer exists.');
    }
    await _savePlaylists(updated);
    _playlists = updated;
    notifyListeners();
  }

  Future<void> deletePlaylist(String playlistId) async {
    final updated = _playlists
        .where((playlist) => playlist.id != playlistId)
        .toList(growable: false);
    if (updated.length == _playlists.length) {
      throw StateError('This playlist no longer exists.');
    }
    await _savePlaylists(updated);
    _playlists = updated;
    notifyListeners();
  }

  Future<void> updatePlaylistCover(
    String playlistId, {
    String? coverStyle,
    String? customArtworkUri,
  }) async {
    final index = _playlists.indexWhere((playlist) => playlist.id == playlistId);
    if (index < 0) {
      throw StateError('This playlist no longer exists.');
    }
    final updated = List<MusicPlaylist>.from(_playlists);
    updated[index] = updated[index].copyWith(
      coverStyle: coverStyle,
      customArtworkUri: customArtworkUri,
    );
    await _savePlaylists(updated);
    _playlists = List.unmodifiable(updated);
    notifyListeners();
  }

  /// Registers online/streaming tracks into the library so they can be saved into
  /// playlists, queued, streamed, and downloaded to device on demand.
  Future<List<ImportedTrack>> registerOrFindRemoteTracks(
    List<ImportedTrack> remoteTracks,
  ) async {
    final existingTracksMap = {for (final t in _tracks) t.id: t};
    final toAdd = <ImportedTrack>[];
    final restoredUnavailable = <String, ImportedTrack>{};
    final seenNewIds = <String>{};
    final result = <ImportedTrack>[];

    for (final remote in remoteTracks) {
      final local = findMatchingLocalTrack(
        providerTrackId: remote.providerTrackId,
        title: remote.title,
        artist: remote.artist,
      );
      if (local != null) {
        result.add(local);
      } else if (existingTracksMap.containsKey(remote.id)) {
        var existing = existingTracksMap[remote.id]!;
        if (_isStreamPath(existing.path) && !existing.isAvailable) {
          existing = existing.withMetadata(isAvailable: true);
          restoredUnavailable[existing.id] = existing;
        }
        result.add(existing);
      } else {
        if (seenNewIds.add(remote.id)) {
          toAdd.add(remote);
        }
        result.add(remote);
      }
    }

    if (toAdd.isNotEmpty || restoredUnavailable.isNotEmpty) {
      final updated = [
        for (final t in _tracks) restoredUnavailable[t.id] ?? t,
        ...toAdd,
      ];
      await _saveTracks(updated);
      _tracks = List.unmodifiable(updated);
      _trackIndexById = {
        for (var i = 0; i < updated.length; i++) updated[i].id: i,
      };
      notifyListeners();
    }

    return result;
  }

  Future<void> addTracksToPlaylist(
    String playlistId,
    Iterable<String> trackIds,
  ) async {
    final playlist = _playlistById(playlistId);
    final updatedIds = [...playlist.trackIds];
    for (final trackId in trackIds) {
      if (!_trackIndexById.containsKey(trackId)) {
        throw StateError('A selected song is no longer in the library.');
      }
      if (!updatedIds.contains(trackId)) updatedIds.add(trackId);
    }
    await _updatePlaylist(playlistId, (current) {
      return _copyPlaylist(current, trackIds: updatedIds);
    });
  }

  Future<void> removeTrackFromPlaylist(
    String playlistId,
    String trackId,
  ) async {
    await _updatePlaylist(playlistId, (playlist) {
      return _copyPlaylist(
        playlist,
        trackIds: playlist.trackIds.where((id) => id != trackId).toList(),
      );
    });
  }

  Future<void> reorderPlaylistTrack(
    String playlistId,
    int oldIndex,
    int newIndex,
  ) async {
    await _updatePlaylist(playlistId, (playlist) {
      final trackIds = [...playlist.trackIds];
      if (oldIndex < 0 || oldIndex >= trackIds.length) {
        throw RangeError.index(oldIndex, trackIds, 'oldIndex');
      }
      if (newIndex < 0 || newIndex > trackIds.length) {
        throw RangeError.index(newIndex, trackIds, 'newIndex');
      }
      final trackId = trackIds.removeAt(oldIndex);
      trackIds.insert(newIndex, trackId);
      return _copyPlaylist(playlist, trackIds: trackIds);
    });
  }

  Future<void> playPlaylist(
    AudioHandler handler,
    String playlistId, {
    String? startTrackId,
  }) async {
    final tracks = tracksForPlaylist(playlistId);
    if (tracks.isEmpty) {
      throw StateError('Add songs to this playlist before playing it.');
    }
    if (tracks.any((track) => !track.isAvailable)) {
      throw StateError(
        'This playlist contains unavailable songs. Rescan your library and review the missing tracks.',
      );
    }
    final requestedIndex = startTrackId == null
        ? 0
        : tracks.indexWhere((track) => track.id == startTrackId);
    if (requestedIndex < 0) {
      throw StateError('The selected song is no longer in this playlist.');
    }
    final orderedTracks = [
      ...tracks.skip(requestedIndex),
      ...tracks.take(requestedIndex),
    ];
    await handler.updateQueue(
      orderedTracks.map((track) => track.toMediaItem()).toList(growable: false),
    );
    _queuedTrackOrder = orderedTracks
        .map((track) => track.id)
        .toList(growable: false);
    final selectedTrack = orderedTracks.first;
    await handler.play();
    await _saveQueueState(currentTrackId: selectedTrack.id, positionMs: 0);
  }

  List<MixPick> generatePersonalMix({
    required Duration targetDuration,
    required double discovery,
    int? randomSeed,
  }) => PersonalMixGenerator.generate(
    tracks: _tracks,
    favoriteTrackIds: _favoriteTrackIds,
    excludedTrackIds: _mixExcludedTrackIds,
    targetDuration: targetDuration,
    discovery: discovery,
    randomSeed: randomSeed,
  );

  ImportedTrack? _trackById(String trackId) {
    final index = _trackIndexById[trackId];
    return index == null ? null : _tracks[index];
  }

  Future<void> setMixExcluded(String trackId, bool excluded) async {
    if (!_trackIndexById.containsKey(trackId)) {
      throw StateError('This song is no longer in the library.');
    }
    final updated = Set<String>.from(_mixExcludedTrackIds);
    if (excluded) {
      updated.add(trackId);
    } else {
      updated.remove(trackId);
    }
    await _saveExclusions(updated);
    _mixExcludedTrackIds = updated;
    notifyListeners();
  }

  Future<void> resetMixExclusions() async {
    await _saveExclusions({});
    _mixExcludedTrackIds = {};
    notifyListeners();
  }

  Future<void> clearPersonalPreferences() async {
    await _saveFavorites({});
    await _saveExclusions({});
    _favoriteTrackIds = {};
    _mixExcludedTrackIds = {};
    notifyListeners();
  }

  Future<void> playMix(
    AudioHandler handler,
    Iterable<ImportedTrack> picks,
  ) async {
    final orderedTracks = picks
        .map((pick) {
          final index = _trackIndexById[pick.id];
          if (index == null) {
            throw StateError(
              'A selected mix song is no longer in the library.',
            );
          }
          final track = _tracks[index];
          if (!track.isAvailable) {
            throw StateError(
              'A selected mix song is currently unavailable. Rescan your music library and try again.',
            );
          }
          return track;
        })
        .toList(growable: false);
    if (orderedTracks.isEmpty) {
      throw StateError('Add playable songs to your library to make a mix.');
    }
    final ids = orderedTracks.map((track) => track.id).toSet();
    if (ids.length != orderedTracks.length) {
      throw ArgumentError('A mix cannot contain the same song more than once.');
    }
    await handler.updateQueue(
      orderedTracks.map((track) => track.toMediaItem()).toList(growable: false),
    );
    _queuedTrackOrder = orderedTracks
        .map((track) => track.id)
        .toList(growable: false);
    await handler.play();
    await _saveQueueState(
      currentTrackId: orderedTracks.first.id,
      positionMs: 0,
    );
  }

  Future<int> pickAndImport() async {
    if (_isImporting) return 0;
    _lastImportSkippedDuplicates = 0;
    _setImporting(true);
    try {
      final files = await _pickAudio();
      final added = <ImportedTrack>[];
      var skippedDuplicates = 0;
      try {
        for (final file in files) {
          final extension = p.extension(file.name).toLowerCase();
          if (!supportedExtensions.contains(extension.replaceFirst('.', ''))) {
            continue;
          }
          final copied = await _copyPickedFile(file);
          try {
            if (await _isExactDuplicateImport(copied, [..._tracks, ...added])) {
              await _deleteCopies([copied]);
              skippedDuplicates++;
            } else {
              added.add(copied);
            }
          } on Object {
            await _deleteCopies([copied]);
            rethrow;
          }
        }
      } on Object {
        await _deleteCopies(added);
        rethrow;
      }

      _lastImportSkippedDuplicates = skippedDuplicates;
      if (added.isEmpty) return 0;
      final updated = [..._tracks, ...added];
      try {
        await _saveTracks(updated);
      } on Object {
        await _deleteCopies(added);
        rethrow;
      }
      _setTracks(updated);
      _invalidatePlaybackQueue();
      notifyListeners();
      return added.length;
    } finally {
      _setImporting(false);
    }
  }

  Future<ImportedTrack> importLicensedDownload({
    required String provider,
    required String providerTrackId,
    required String fileName,
    required Stream<List<int>> bytes,
    required String title,
    required String artist,
    required String album,
    required int? durationMs,
    required String? artworkUri,
    required int? year,
    required String? licenseUrl,
    String? genre,
    int? trackNumber,
    bool convertToFlac = false,
  }) async {
    final normalizedProvider = provider.trim();
    final normalizedTrackId = providerTrackId.trim();
    if (normalizedProvider.isEmpty || normalizedTrackId.isEmpty) {
      throw ArgumentError('Download provider and track ID are required.');
    }
    if (!supportedExtensions.contains(
      p.extension(fileName).toLowerCase().replaceFirst('.', ''),
    )) {
      throw ArgumentError.value(
        fileName,
        'fileName',
        'The downloaded file must use a supported audio format.',
      );
    }
    for (final track in _tracks) {
      if (track.sourceProvider == normalizedProvider &&
          track.providerTrackId == normalizedTrackId &&
          !_isStreamPath(track.path)) {
        return track;
      }
    }
    if (_isImporting) {
      throw StateError('Wait for the current library import to finish.');
    }

    _setImporting(true);
    try {
      var copiedTrack = await _copyPickedFile(
        PickedAudio(name: fileName, bytes: bytes),
      );
      var exportFileName = fileName;
      if (_isAndroid()) {
        if (convertToFlac && !copiedTrack.path.toLowerCase().endsWith('.flac')) {
          try {
            final flacPath = '${p.withoutExtension(copiedTrack.path)}.flac';
            final flacFileName = '${p.withoutExtension(fileName)}.flac';
            String? localArtworkPath;
            if (artworkUri != null && artworkUri.startsWith('file:')) {
              localArtworkPath = Uri.parse(artworkUri).toFilePath();
            }
            await const MethodChannel('app.melo.melo_player/library')
                .invokeMethod<Map<Object?, Object?>>(
              'convertToLosslessFlac',
              <String, Object?>{
                'sourcePath': copiedTrack.path,
                'destPath': flacPath,
                'title': title,
                'artist': artist,
                'album': album,
                'year': year,
                'genre': genre,
                'trackNumber': trackNumber,
                'artworkPath': localArtworkPath,
              },
            );
            final flacFile = File(flacPath);
            if (await flacFile.exists() && await flacFile.length() > 0) {
              final oldFile = File(copiedTrack.path);
              if (await oldFile.exists()) {
                await oldFile.delete();
              }
              copiedTrack = ImportedTrack.fromCopiedFile(
                id: copiedTrack.id,
                path: flacFile.path,
                originalName: flacFileName,
              ).withMetadata(
                fileSizeBytes: await flacFile.length(),
                dateModifiedAt: await flacFile.lastModified(),
              );
              exportFileName = flacFileName;
            }
          } catch (error) {
            debugPrint('FLAC conversion fallback to original stream container: $error');
          }
        }
        try {
          await const MethodChannel('app.melo.melo_player/library')
              .invokeMethod<Map<Object?, Object?>>(
            'saveToDeviceMusic',
            <String, Object?>{
              'sourcePath': copiedTrack.path,
              'fileName': exportFileName,
              'title': title,
              'artist': artist,
              'album': album,
              'durationMs': durationMs,
            },
          );
        } catch (error) {
          debugPrint('Could not export download to MediaStore Music/Tone: $error');
        }
      }
      final imported = copiedTrack.withMetadata(
        title: title,
        artist: artist,
        album: album,
        durationMs: durationMs,
        artworkUri: artworkUri,
        year: year,
        genre: genre,
        trackNumber: trackNumber,
        sourceProvider: normalizedProvider,
        providerTrackId: normalizedTrackId,
        licenseUrl: licenseUrl,
        metadataReviewed: true,
      );
      // Remove temporary stream references for this track and remap playlists/favorites
      // to the newly downloaded local file ID before cascade-deleting the stream row.
      final removedStreamIds = <String>{};
      final filteredExisting = <ImportedTrack>[];
      for (final t in _tracks) {
        final matchesStream = _isStreamPath(t.path) &&
            (t.providerTrackId == normalizedTrackId ||
                (_normalizeSongText(t.title) == _normalizeSongText(title) &&
                    _normalizeSongText(t.artist) == _normalizeSongText(artist)));
        if (matchesStream) {
          removedStreamIds.add(t.id);
        } else {
          filteredExisting.add(t);
        }
      }
      final updated = [...filteredExisting, imported];
      try {
        await _saveTracks(updated);
      } on Object {
        await _deleteCopies([copiedTrack]);
        rethrow;
      }
      _setTracks(updated);
      if (removedStreamIds.isNotEmpty) {
        var playlistsChanged = false;
        final remappedPlaylists = _playlists.map((playlist) {
          if (!playlist.trackIds.any(removedStreamIds.contains)) {
            return playlist;
          }
          playlistsChanged = true;
          final nextIds = <String>[];
          final seen = <String>{};
          for (final id in playlist.trackIds) {
            final mappedId = removedStreamIds.contains(id) ? imported.id : id;
            if (seen.add(mappedId)) nextIds.add(mappedId);
          }
          return _copyPlaylist(playlist, trackIds: nextIds);
        }).toList(growable: false);
        if (playlistsChanged) {
          await _savePlaylists(remappedPlaylists);
          _playlists = remappedPlaylists;
        }
        if (_favoriteTrackIds.any(removedStreamIds.contains)) {
          final nextFavs = {
            for (final id in _favoriteTrackIds)
              removedStreamIds.contains(id) ? imported.id : id,
          };
          await _saveFavorites(nextFavs);
          _favoriteTrackIds = nextFavs;
        }
      }
      _invalidatePlaybackQueue();
      notifyListeners();
      return imported;
    } finally {
      _setImporting(false);
    }
  }

  Future<ImportedTrack?> updateTrackEnrichedMetadata(
    String trackId, {
    String? title,
    String? artist,
    String? album,
    int? year,
    String? genre,
    int? trackNumber,
    String? artworkUri,
  }) async {
    final index = _trackIndexById[trackId];
    if (index == null || index < 0 || index >= _tracks.length) return null;
    final current = _tracks[index];
    final updatedTrack = current.withMetadata(
      title: title,
      artist: artist,
      album: album,
      year: year,
      genre: genre,
      trackNumber: trackNumber,
      artworkUri: artworkUri,
      metadataReviewed: true,
    );
    final updated = [..._tracks];
    updated[index] = updatedTrack;
    await _saveTracks(updated);
    _setTracks(updated);
    notifyListeners();
    return updatedTrack;
  }

  Future<List<ImportedTrack>> importExternalTracks(
    Iterable<ImportedTrack> externalTracks,
  ) async {
    final existingIds = _tracks.map((t) => t.id).toSet();
    final newTracks = <ImportedTrack>[];
    for (final track in externalTracks) {
      if (!existingIds.contains(track.id)) {
        newTracks.add(track);
        existingIds.add(track.id);
      }
    }
    if (newTracks.isEmpty) return const [];
    final updated = [..._tracks, ...newTracks];
    await _saveTracks(updated);
    _setTracks(updated);
    _invalidatePlaybackQueue();
    notifyListeners();
    return newTracks;
  }

  Future<int> scanDeviceMusic() async {
    if (_isImporting) return 0;
    _setImporting(true);
    try {
      final now = DateTime.now();
      final lastFullScan = await _repository?.lastFullDeviceScanAt();
      final needsFullScan =
          lastFullScan == null ||
          now.difference(lastFullScan) >= const Duration(hours: 24) ||
          _repository == null;
      final discovered = [
        ...await _scanDeviceAudio(
          modifiedSince: needsFullScan ? null : lastFullScan,
        ),
      ];
      for (final folder in _musicFolders) {
        discovered.addAll(await _scanMusicFolder(folder.uri));
      }
      final importedTracks = _tracks
          .where((track) => !track.isDeviceMedia)
          .toList(growable: false);
      final downloadedSignatures = <String>{
        for (final track in importedTracks)
          if (track.sourceProvider != null)
            '${track.title.trim().toLowerCase()}|${track.artist.trim().toLowerCase()}',
      };
      final deviceTracks = _tracksFromDeviceAudio(discovered)
          .where(
            (track) =>
                (!_isAndroid() || !_isNonSongAudioTrack(track)) &&
                !downloadedSignatures.contains(
                  '${track.title.trim().toLowerCase()}|${track.artist.trim().toLowerCase()}',
                ),
          )
          .toList(growable: false);
      final discoveredById = {
        for (final track in deviceTracks) track.id: track,
      };
      final previousDeviceTracks = _tracks.where(
        (track) =>
            track.isDeviceMedia &&
            (!_isAndroid() || !_isNonSongAudioTrack(track)),
      );
      final retainedDeviceTracks = <ImportedTrack>[];
      final unavailableTrackIds = <String>{};
      for (final previous in previousDeviceTracks) {
        final update = discoveredById.remove(previous.id);
        if (update != null) {
          retainedDeviceTracks.add(update);
        } else if (needsFullScan) {
          retainedDeviceTracks.add(previous.withMetadata(isAvailable: false));
          unavailableTrackIds.add(previous.id);
        } else {
          retainedDeviceTracks.add(previous);
        }
      }
      final updated = [
        ...importedTracks,
        ...retainedDeviceTracks,
        ...discoveredById.values,
      ];
      if (_repository case final repository?) {
        await repository.saveDeviceScan(
          changedTracks: deviceTracks,
          unavailableTrackIds: unavailableTrackIds,
        );
      } else {
        await _saveTracks(updated);
      }
      if (needsFullScan) await _repository?.recordFullDeviceScan(now);
      _setTracks(updated);
      _invalidatePlaybackQueue();
      notifyListeners();
      return deviceTracks.length;
    } finally {
      _setImporting(false);
    }
  }

  static Future<List<PickedAudio>> _pickFromDevice() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: supportedExtensions,
      dialogTitle: 'Choose music to add to Melo',
    );
    return files
        .map(
          (file) =>
              PickedAudio(name: file.name, bytes: file.readAsByteStream()),
        )
        .toList(growable: false);
  }

  static Future<List<DeviceAudio>> _emptyDeviceScan() async => const [];
  static Future<MusicFolder?> _emptyFolderPicker() async => null;
  static Future<List<DeviceAudio>> _emptyFolderScan(String _) async => const [];
  static Future<void> _emptyFolderRelease(String _) async {}
  static Future<bool> _unsupportedTrackDeletion(String _) =>
      Future.error(UnsupportedError('Track-file deletion is not configured.'));

  Future<ImportedTrack> _copyPickedFile(PickedAudio picked) async {
    final extension = p.extension(picked.name).toLowerCase();
    var id = '${DateTime.now().microsecondsSinceEpoch}_${_importSequence++}';
    while (await File(p.join(_musicDirectory.path, '$id$extension')).exists()) {
      id = '${DateTime.now().microsecondsSinceEpoch}_${_importSequence++}';
    }

    final fileName = '$id$extension';
    final partial = File(p.join(_musicDirectory.path, '$fileName.partial'));
    final destination = File(p.join(_musicDirectory.path, fileName));
    final sink = partial.openWrite();
    var sinkClosed = false;
    try {
      await sink.addStream(picked.bytes);
      await sink.flush();
      await sink.close();
      sinkClosed = true;
      if (await partial.length() == 0) {
        throw FileSystemException('The selected audio file is empty.');
      }
      await partial.rename(destination.path);
      final track =
          ImportedTrack.fromCopiedFile(
            id: id,
            path: destination.path,
            originalName: picked.name,
          ).withMetadata(
            fileSizeBytes: await destination.length(),
            dateModifiedAt: await destination.lastModified(),
          );
      Map<Object?, Object?>? metadata;
      try {
        metadata = await _metadataReader(destination.path, track.title);
      } catch (error, stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'tone library',
            context: ErrorDescription('while reading imported audio metadata'),
          ),
        );
        return track.withMetadata(metadataReviewed: true);
      }
      if (metadata == null) return track;
      return track.withMetadata(
        title: metadata['title'] as String?,
        artist: metadata['artist'] as String?,
        album: metadata['album'] as String?,
        durationMs: (metadata['durationMs'] as num?)?.toInt(),
        artworkUri: metadata['artworkUri'] as String?,
        year: (metadata['year'] as num?)?.toInt(),
        trackNumber: (metadata['trackNumber'] as num?)?.toInt(),
        genre: metadata['genre'] as String?,
        bpm: (metadata['bpm'] as num?)?.toDouble(),
        metadataReviewed: true,
      );
    } on Object {
      if (!sinkClosed) {
        try {
          await sink.close();
        } on FileSystemException {
          // addStream closes the sink itself when the input stream fails.
        }
      }
      if (await partial.exists()) {
        await partial.delete();
      }
      if (await destination.exists()) {
        await destination.delete();
      }
      rethrow;
    }
  }

  Future<bool> _isExactDuplicateImport(
    ImportedTrack candidate,
    Iterable<ImportedTrack> existingTracks,
  ) async {
    final candidateFile = File(candidate.path);
    final candidateLength =
        candidate.fileSizeBytes ?? await candidateFile.length();
    final candidateDigest = await _fileDigest(candidateFile);
    for (final existing in existingTracks) {
      if (existing.isDeviceMedia || _isStreamPath(existing.path)) continue;
      if (existing.fileSizeBytes != null &&
          existing.fileSizeBytes != candidateLength) {
        continue;
      }
      final existingFile = File(existing.path);
      if (!await existingFile.exists() ||
          await existingFile.length() != candidateLength) {
        continue;
      }
      if (await _fileDigest(existingFile) == candidateDigest) return true;
    }
    return false;
  }

  Future<String> _fileDigest(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();

  static Future<Map<Object?, Object?>?> _emptyMetadataReader(
    String _,
    String _,
  ) async => null;

  Future<void> _deleteCopies(Iterable<ImportedTrack> tracks) async {
    for (final track in tracks) {
      final file = File(track.path);
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> playTrack(AudioHandler handler, int index) async {
    if (index < 0 || index >= _tracks.length) {
      throw RangeError.index(index, _tracks, 'index');
    }
    final selectedTrack = _tracks[index];
    if (!selectedTrack.isAvailable) {
      final file = File(selectedTrack.path);
      if (selectedTrack.isDeviceMedia || file.existsSync()) {
        final recovered = selectedTrack.withMetadata(isAvailable: true);
        final nextTracks = [..._tracks];
        nextTracks[index] = recovered;
        _setTracks(nextTracks);
        unawaited(_saveTracks(nextTracks));
      } else {
        throw StateError(
          'This song is currently unavailable. Rescan your music library and try again.',
        );
      }
    }
    final currentQueue = handler.queue.value;
    final queuedIndex = currentQueue.indexWhere(
      (item) => _trackIdForMediaItem(item) == selectedTrack.id,
    );
    final queueMatchesStoredOrder =
        currentQueue.length == _queuedTrackOrder.length &&
        currentQueue.asMap().entries.every(
          (entry) =>
              _trackIdForMediaItem(entry.value) == _queuedTrackOrder[entry.key],
        );
    if (_queuedTrackOrder.length == _tracks.length &&
        queueMatchesStoredOrder &&
        queuedIndex >= 0) {
      await handler.skipToQueueItem(queuedIndex);
    } else {
      final orderedTracks = [..._tracks.skip(index), ..._tracks.take(index)];
      await handler.updateQueue(
        orderedTracks
            .map((track) => track.toMediaItem())
            .toList(growable: false),
      );
      _queuedTrackOrder = orderedTracks
          .map((track) => track.id)
          .toList(growable: false);
    }
    await handler.play();
    await _saveQueueState(currentTrackId: selectedTrack.id, positionMs: 0);
  }

  String? _trackIdForMediaItem(MediaItem item) {
    final libraryId = item.extras?['libraryId'];
    if (libraryId is String && _trackIndexById.containsKey(libraryId)) {
      return libraryId;
    }
    for (final track in _tracks) {
      if (track.path == item.id) return track.id;
    }
    return null;
  }

  Future<void> restoreQueue(AudioHandler handler) async {
    final snapshot = _repository == null ? null : await _repository.load();
    final storedIds =
        snapshot?.queueTrackIds ??
        (() {
          final encodedQueue = _preferences.getString(_queueKey);
          if (encodedQueue == null) return const <String>[];
          final decoded = jsonDecode(encodedQueue);
          if (decoded is! List || decoded.any((item) => item is! String)) {
            throw const FormatException('Stored playback queue is invalid.');
          }
          return decoded.cast<String>();
        })();
    if (storedIds.isEmpty || _tracks.isEmpty) return;

    final byId = {for (final track in _tracks) track.id: track};
    final restored = storedIds
        .map((id) => byId[id])
        .whereType<ImportedTrack>()
        .where((track) => track.isAvailable);
    final queue = restored.toList(growable: false);
    if (queue.isEmpty) return;

    final currentId =
        snapshot?.currentTrackId ?? _preferences.getString(_currentTrackKey);
    final restoredIndex = queue.indexWhere((track) => track.id == currentId);
    await handler.updateQueue(
      queue.map((track) => track.toMediaItem()).toList(growable: false),
    );
    _queuedTrackOrder = queue.map((track) => track.id).toList(growable: false);
    await handler.skipToQueueItem(restoredIndex < 0 ? 0 : restoredIndex);
    final position =
        snapshot?.positionMs ?? _preferences.getInt(_positionKey) ?? 0;
    if (position > 0) {
      await handler.seek(Duration(milliseconds: position));
    }
  }

  Future<void> persistPlaybackQueue({
    required List<MediaItem> items,
    required String? currentMediaId,
    required int positionMs,
  }) async {
    final tracksById = {for (final track in _tracks) track.id: track};
    final tracksByPath = {for (final track in _tracks) track.path: track};
    final idsByMediaId = <String, String>{};
    final trackIds = <String>[];
    for (final item in items) {
      final libraryId = item.extras?['libraryId'];
      final track =
          (libraryId is String ? tracksById[libraryId] : null) ??
          tracksByPath[item.id];
      if (track == null) {
        _queuedTrackOrder = const [];
        await _saveQueueState(currentTrackId: null, positionMs: 0);
        return;
      }
      trackIds.add(track.id);
      idsByMediaId[item.id] = track.id;
    }

    _queuedTrackOrder = List.unmodifiable(trackIds);
    await _saveQueueState(
      currentTrackId:
          idsByMediaId[currentMediaId] ??
          (trackIds.isEmpty ? null : trackIds.first),
      positionMs: positionMs < 0 ? 0 : positionMs,
    );
  }

  Future<void> _hydrateTasteMemory() async {
    if (_repository == null) return;
    final history = await listeningHistory(limit: 50);
    if (history.isEmpty) return;
    final seededIds = _recentSessionItems.map((e) => e.id).toSet();
    for (final entry in history) {
      final cleanArtist = entry.artist.trim();
      final lower = cleanArtist.toLowerCase();
      if (cleanArtist.isNotEmpty && lower != 'unknown artist') {
        _artistPlayCounts[cleanArtist] =
            (_artistPlayCounts[cleanArtist] ?? 0) + 1;
      }
      if (_recentSessionItems.length < 40 &&
          !seededIds.contains(entry.trackId)) {
        seededIds.add(entry.trackId);
        _recentSessionItems.add(
          MediaItem(
            id: entry.trackId,
            title: entry.title,
            artist: entry.artist,
            album: entry.album,
          ),
        );
      }
    }
  }

  /// Records both local and streamed playback into session taste memory and
  /// persistent listening history.
  Future<void> recordPlayedMediaItem(MediaItem? item) async {
    if (item == null) {
      await saveCurrentTrack(null);
      return;
    }
    final cleanArtist = (item.artist ?? '').trim();
    _recentSessionItems.removeWhere((existing) => existing.id == item.id);
    _recentSessionItems.insert(0, item);
    if (_recentSessionItems.length > 40) {
      _recentSessionItems.removeRange(40, _recentSessionItems.length);
    }
    if (cleanArtist.isNotEmpty &&
        cleanArtist.toLowerCase() != 'unknown artist') {
      _artistPlayCounts[cleanArtist] =
          (_artistPlayCounts[cleanArtist] ?? 0) + 1;
    }

    final localId = _trackIdForMediaItem(item);
    if (localId != null) {
      final localIdx = _trackIndexById[localId];
      final localPath = localIdx != null ? _tracks[localIdx].path : item.id;
      _lastRecordedMediaId = item.id;
      await saveCurrentTrack(localPath);
      return;
    }

    if (_lastRecordedMediaId != item.id) {
      _lastRecordedMediaId = item.id;
      await _repository?.recordStreamPlayback(
        trackId: item.id,
        title: item.title,
        artist: cleanArtist.isEmpty ? 'Unknown Artist' : cleanArtist,
        album: item.album ?? '',
      );
      _playbackHistoryRevision.value++;
    }
  }

  Future<void> saveCurrentTrack(String? mediaId) async {
    String? trackId;
    if (mediaId != null) {
      final matches = _tracks.where((item) => item.path == mediaId);
      if (matches.isEmpty) return;
      trackId = matches.first.id;
    }
    if (_currentTrackId == trackId) return;
    if (_repository case final repository?) {
      await repository.saveCurrentTrack(trackId);
    } else if (trackId == null) {
      await _preferences.remove(_currentTrackKey);
      await _preferences.remove(_positionKey);
    } else {
      await _preferences.setString(_currentTrackKey, trackId);
      await _preferences.setInt(_positionKey, 0);
    }
    _currentTrackId = trackId;
    _playbackHistoryRevision.value++;
  }

  Future<void> savePlaybackPosition(Duration position) =>
      _repository?.savePlaybackPosition(position.inMilliseconds) ??
      _preferences.setInt(_positionKey, position.inMilliseconds);

  Future<List<ImportedTrack>> recentlyPlayed({int limit = 20}) async {
    if (_repository == null) return const [];
    return _repository.recentlyPlayed(limit: limit);
  }

  Future<List<MostPlayedTrack>> mostPlayedTracks({int limit = 20}) async {
    if (_repository == null) return const [];
    return _repository.mostPlayedTracks(limit: limit);
  }

  Future<List<PlaybackHistoryEntry>> listeningHistory({int limit = 100}) async {
    if (_repository == null) return const [];
    return _repository.listeningHistory(limit: limit);
  }

  Future<bool> removeTrack(ImportedTrack track) async {
    if (!_tracks.any((item) => item.id == track.id)) return true;
    if (track.isDeviceMedia) {
      if (!await _deleteDeviceAudio(track.path)) return false;
    } else {
      final musicDirectory = p.normalize(p.absolute(_musicDirectory.path));
      final trackPath = p.normalize(p.absolute(track.path));
      if (!p.isWithin(musicDirectory, trackPath)) {
        throw StateError('Melo can only delete files stored in its library.');
      }
      final file = File(track.path);
      if (await file.exists()) await file.delete();
    }

    await _removeTracksFromLibrary({track.id});
    return true;
  }

  Future<BulkTrackRemovalResult> removeTracks(
    Iterable<ImportedTrack> tracks,
  ) async {
    final selectedById = {for (final track in tracks) track.id: track};
    final selected = selectedById.values
        .where((track) => _tracks.any((item) => item.id == track.id))
        .toList(growable: false);
    final mediaStoreTracks = selected
        .where(
          (track) =>
              track.isDeviceMedia &&
              Uri.tryParse(track.path)?.authority == 'media',
        )
        .toList(growable: false);
    final removed = <ImportedTrack>[];
    final failures = <ImportedTrack, Object>{};

    if (mediaStoreTracks.isNotEmpty) {
      try {
        final approved = await _deleteDeviceAudioBatch(
          mediaStoreTracks.map((track) => track.path).toList(growable: false),
        );
        if (!approved) {
          return const BulkTrackRemovalResult(
            removed: [],
            failures: {},
            cancelled: true,
          );
        }
        await _removeTracksFromLibrary({
          for (final track in mediaStoreTracks) track.id,
        });
        removed.addAll(mediaStoreTracks);
      } on Object catch (error) {
        for (final track in mediaStoreTracks) {
          failures[track] = error;
        }
      }
    }

    for (final track in selected) {
      if (mediaStoreTracks.any((mediaTrack) => mediaTrack.id == track.id)) {
        continue;
      }
      try {
        if (await removeTrack(track)) {
          removed.add(track);
        } else {
          failures[track] = StateError('Deletion was not approved.');
        }
      } on Object catch (error) {
        failures[track] = error;
      }
    }

    return BulkTrackRemovalResult(
      removed: List.unmodifiable(removed),
      failures: Map.unmodifiable(failures),
    );
  }

  Future<void> _removeTracksFromLibrary(Set<String> trackIds) async {
    if (trackIds.isEmpty) return;
    final existingIds = trackIds
        .where((id) => _tracks.any((track) => track.id == id))
        .toSet();
    if (existingIds.isEmpty) return;
    final updated = _tracks
        .where((item) => !existingIds.contains(item.id))
        .toList(growable: false);
    await _saveTracks(updated);
    final hasPlaylistReferences = _playlists.any(
      (playlist) => playlist.trackIds.any(existingIds.contains),
    );
    if (hasPlaylistReferences) {
      final updatedPlaylists = _playlists
          .map(
            (playlist) => _copyPlaylist(
              playlist,
              trackIds: playlist.trackIds
                  .where((id) => !existingIds.contains(id))
                  .toList(growable: false),
            ),
          )
          .toList(growable: false);
      await _savePlaylists(updatedPlaylists);
      _playlists = updatedPlaylists;
    }
    _setTracks(updated);
    _invalidatePlaybackQueue();
    final removedFavorite = _favoriteTrackIds.any(existingIds.contains);
    _favoriteTrackIds.removeAll(existingIds);
    if (removedFavorite) {
      await _saveFavorites(_favoriteTrackIds);
    }
    notifyListeners();
  }

  Future<void> _saveTracks(List<ImportedTrack> tracks) async {
    if (_repository case final repository?) {
      await repository.saveTracks(tracks);
      return;
    }
    final json = tracks.map((track) => track.toJson()).toList(growable: false);
    await _preferences.setString(_tracksKey, jsonEncode(json));
  }

  Future<void> _savePlaylists(List<MusicPlaylist> playlists) {
    if (_repository case final repository?) {
      return repository.savePlaylists(playlists);
    }
    return _preferences.setString(
      _playlistsKey,
      jsonEncode(playlists.map((playlist) => playlist.toJson()).toList()),
    );
  }

  Future<void> _saveFolders(List<MusicFolder> folders) {
    if (_repository case final repository?) {
      return repository.saveFolders(folders);
    }
    return _preferences.setString(
      _foldersKey,
      jsonEncode(folders.map((folder) => folder.toJson()).toList()),
    );
  }

  Future<void> _saveFavorites(Set<String> trackIds) {
    if (_repository case final repository?) {
      return repository.saveFavorites(trackIds);
    }
    return trackIds.isEmpty
        ? _preferences.remove(_favoritesKey)
        : _preferences.setStringList(_favoritesKey, trackIds.toList());
  }

  Future<void> _saveExclusions(Set<String> trackIds) {
    if (_repository case final repository?) {
      return repository.saveExclusions(trackIds);
    }
    return trackIds.isEmpty
        ? _preferences.remove(_mixExclusionsKey)
        : _preferences.setStringList(_mixExclusionsKey, trackIds.toList());
  }

  Future<void> _saveQueueState({
    required String? currentTrackId,
    required int positionMs,
  }) {
    if (_repository case final repository?) {
      return repository.saveQueue(
        _queuedTrackOrder,
        currentTrackId: currentTrackId,
        positionMs: positionMs,
      );
    }
    return Future.wait([
      _preferences.setString(_queueKey, jsonEncode(_queuedTrackOrder)),
      if (currentTrackId == null)
        _preferences.remove(_currentTrackKey)
      else
        _preferences.setString(_currentTrackKey, currentTrackId),
      _preferences.setInt(_positionKey, positionMs),
    ]).then((_) {});
  }

  Future<void> close() async {
    await _repository?.close();
    _playbackHistoryRevision.dispose();
    dispose();
  }

  MusicPlaylist _playlistById(String playlistId) {
    for (final playlist in _playlists) {
      if (playlist.id == playlistId) return playlist;
    }
    throw StateError('This playlist no longer exists.');
  }

  Future<void> _updatePlaylist(
    String playlistId,
    MusicPlaylist Function(MusicPlaylist) update,
  ) async {
    var found = false;
    final updated = _playlists
        .map((playlist) {
          if (playlist.id != playlistId) return playlist;
          found = true;
          return update(playlist);
        })
        .toList(growable: false);
    if (!found) throw StateError('This playlist no longer exists.');
    await _savePlaylists(updated);
    _playlists = updated;
    notifyListeners();
  }

  MusicPlaylist _copyPlaylist(
    MusicPlaylist playlist, {
    String? name,
    List<String>? trackIds,
  }) => MusicPlaylist(
    id: playlist.id,
    name: name ?? playlist.name,
    trackIds: List.unmodifiable(trackIds ?? playlist.trackIds),
    createdAt: playlist.createdAt,
    coverStyle: playlist.coverStyle,
    customArtworkUri: playlist.customArtworkUri,
  );

  void _setImporting(bool value) {
    _isImporting = value;
    notifyListeners();
  }

  void _invalidatePlaybackQueue() {
    _queuedTrackOrder = const [];
  }

  void _setTracks(List<ImportedTrack> tracks) {
    _tracks = tracks;
    _trackIndexById = {
      for (var index = 0; index < tracks.length; index++)
        tracks[index].id: index,
    };
  }
}

class PickedAudio {
  const PickedAudio({required this.name, required this.bytes});

  final String name;
  final Stream<List<int>> bytes;
}
