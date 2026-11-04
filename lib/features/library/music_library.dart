import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tone_player/features/library/imported_track.dart';
import 'package:tone_player/features/library/music_playlist.dart';
import 'package:tone_player/features/mix/personal_mix.dart';
import 'package:tone_player/features/mix/local_discovery.dart';

class MusicLibrary extends ChangeNotifier {
  static const _platform = MethodChannel('app.tone.tone_player/library');

  MusicLibrary._({
    required this._musicDirectory,
    required this._preferences,
    required this._pickAudio,
    required this._scanDeviceAudio,
    required this._pickMusicFolder,
    required this._scanMusicFolder,
    required this._releaseMusicFolder,
    required this._metadataReader,
    required this._isAndroid,
  });

  @visibleForTesting
  factory MusicLibrary.forTesting({
    required Directory musicDirectory,
    required SharedPreferences preferences,
    required Future<List<PickedAudio>> Function() pickAudio,
    Future<List<DeviceAudio>> Function()? scanDeviceAudio,
    Future<MusicFolder?> Function()? pickMusicFolder,
    Future<List<DeviceAudio>> Function(String uri)? scanMusicFolder,
    Future<void> Function(String uri)? releaseMusicFolder,
    Future<Map<Object?, Object?>?> Function(String path, String fallbackTitle)?
    readImportedMetadata,
    bool Function()? isAndroid,
  }) => MusicLibrary._(
    musicDirectory: musicDirectory,
    preferences: preferences,
    pickAudio: pickAudio,
    scanDeviceAudio: scanDeviceAudio ?? _emptyDeviceScan,
    pickMusicFolder: pickMusicFolder ?? _emptyFolderPicker,
    scanMusicFolder: scanMusicFolder ?? _emptyFolderScan,
    releaseMusicFolder: releaseMusicFolder ?? _emptyFolderRelease,
    metadataReader: readImportedMetadata ?? _readImportedMetadata,
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
  ];

  final Directory _musicDirectory;
  final SharedPreferences _preferences;
  final Future<List<PickedAudio>> Function() _pickAudio;
  final Future<List<DeviceAudio>> Function() _scanDeviceAudio;
  final Future<MusicFolder?> Function() _pickMusicFolder;
  final Future<List<DeviceAudio>> Function(String uri) _scanMusicFolder;
  final Future<void> Function(String uri) _releaseMusicFolder;
  final Future<Map<Object?, Object?>?> Function(
    String path,
    String fallbackTitle,
  )
  _metadataReader;
  final bool Function() _isAndroid;
  List<ImportedTrack> _tracks = const [];
  List<MusicPlaylist> _playlists = const [];
  List<MusicFolder> _musicFolders = const [];
  Set<String> _favoriteTrackIds = {};
  Set<String> _mixExcludedTrackIds = {};
  Map<String, int> _trackIndexById = const {};
  Map<String, int> _queueIndexes = const {};
  List<String> _queuedTrackOrder = const [];
  bool _isImporting = false;
  int _importSequence = 0;

  List<ImportedTrack> get tracks => UnmodifiableListView(_tracks);
  List<MusicPlaylist> get playlists => UnmodifiableListView(_playlists);
  List<MusicFolder> get musicFolders => UnmodifiableListView(_musicFolders);
  List<ImportedTrack> get favoriteTracks => _tracks
      .where((track) => _favoriteTrackIds.contains(track.id))
      .toList(growable: false);
  List<ImportedTrack> get discoveryTracks => _tracks;
  List<PlaylistSuggestion> get playlistSuggestions =>
      LocalDiscovery.suggestions(_tracks, favoriteTrackIds: _favoriteTrackIds);
  bool get isImporting => _isImporting;
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

  List<ImportedTrack> artistRadioTracks(String artist) =>
      LocalDiscovery.artistRadio(_tracks, artist);

  Future<void> playArtistRadio(AudioHandler handler, String artist) async {
    final station = artistRadioTracks(artist);
    if (station.isEmpty) {
      throw StateError('There are no playable songs for $artist radio.');
    }
    await playMix(handler, station);
  }

  static Future<MusicFolder?> _pickMusicFolderFromDevice() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError(
        'Folder access is currently available on Android.',
      );
    }
    final result = await _platform.invokeMapMethod<String, Object?>(
      'pickMusicFolder',
    );
    if (result == null) return null;
    return MusicFolder(
      uri: result['uri']! as String,
      name: result['name']! as String,
    );
  }

  static Future<List<DeviceAudio>> _scanFolderFromDevice(String uri) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError(
        'Folder access is currently available on Android.',
      );
    }
    final result = await _platform.invokeListMethod<Map<Object?, Object?>>(
      'scanMusicFolder',
      {'uri': uri},
    );
    if (result == null) {
      throw StateError('Android did not return the selected folder contents.');
    }
    return result.map(DeviceAudio.fromPlatformMap).toList(growable: false);
  }

  static Future<void> _releaseFolderOnDevice(String uri) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    await _platform.invokeMethod<void>('releaseMusicFolder', {'uri': uri});
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

  int indexOfTrack(String id) => _trackIndexById[id] ?? -1;

  static Future<MusicLibrary> open() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory(p.join(support.path, 'music'));
    await directory.create(recursive: true);
    final preferences = await SharedPreferences.getInstance();
    final library = MusicLibrary._(
      musicDirectory: directory,
      preferences: preferences,
      pickAudio: _pickFromDevice,
      scanDeviceAudio: _scanFromDevice,
      pickMusicFolder: _pickMusicFolderFromDevice,
      scanMusicFolder: _scanFolderFromDevice,
      releaseMusicFolder: _releaseFolderOnDevice,
      metadataReader: _readImportedMetadata,
      isAndroid: () => Platform.isAndroid,
    );
    await library.load();
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
    _favoriteTrackIds = (_preferences.getStringList(_favoritesKey) ?? const [])
        .toSet();
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
    final stored = _preferences.getString(_tracksKey);
    if (stored == null) return;

    final decoded = ImportedTrack.decodeList(stored);
    final available = <ImportedTrack>[];
    for (final track in decoded) {
      if (track.isDeviceMedia || await File(track.path).exists()) {
        available.add(track);
      }
    }
    _setTracks(available);
    if (available.length != decoded.length) {
      await _saveTracks(available);
    }
  }

  Future<void> refreshImportedMetadata() async {
    if (!_isAndroid()) return;
    final candidates = _tracks
        .where((track) => !track.isDeviceMedia && !track.metadataReviewed)
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
      await _preferences.setString(
        _foldersKey,
        jsonEncode(updatedFolders.map((item) => item.toJson()).toList()),
      );
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
    await _preferences.setString(
      _foldersKey,
      jsonEncode(updatedFolders.map((item) => item.toJson()).toList()),
    );
    await _saveTracks(updatedTracks);
    await _savePlaylists(updatedPlaylists);
    await _preferences.setStringList(_favoritesKey, updatedFavorites.toList());
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
    await _preferences.setStringList(_favoritesKey, updated.toList());
    _favoriteTrackIds = updated;
    notifyListeners();
    return isFavorite;
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
    _queueIndexes = {
      for (var index = 0; index < _queuedTrackOrder.length; index++)
        _queuedTrackOrder[index]: index,
    };
    final selectedTrack = orderedTracks.first;
    await handler.play();
    await _preferences.setString(_queueKey, jsonEncode(_queuedTrackOrder));
    await _preferences.setString(_currentTrackKey, selectedTrack.id);
    await _preferences.setInt(_positionKey, 0);
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
    await _preferences.setStringList(_mixExclusionsKey, updated.toList());
    _mixExcludedTrackIds = updated;
    notifyListeners();
  }

  Future<void> resetMixExclusions() async {
    await _preferences.remove(_mixExclusionsKey);
    _mixExcludedTrackIds = {};
    notifyListeners();
  }

  Future<void> clearPersonalPreferences() async {
    await _preferences.remove(_favoritesKey);
    await _preferences.remove(_mixExclusionsKey);
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
          return _tracks[index];
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
    _queueIndexes = {
      for (var index = 0; index < _queuedTrackOrder.length; index++)
        _queuedTrackOrder[index]: index,
    };
    await handler.play();
    await _preferences.setString(_queueKey, jsonEncode(_queuedTrackOrder));
    await _preferences.setString(_currentTrackKey, orderedTracks.first.id);
    await _preferences.setInt(_positionKey, 0);
  }

  Future<int> pickAndImport() async {
    if (_isImporting) return 0;
    _setImporting(true);
    try {
      final files = await _pickAudio();
      final added = <ImportedTrack>[];
      try {
        for (final file in files) {
          final extension = p.extension(file.name).toLowerCase();
          if (!supportedExtensions.contains(extension.replaceFirst('.', ''))) {
            continue;
          }
          added.add(await _copyPickedFile(file));
        }
      } on Object {
        await _deleteCopies(added);
        rethrow;
      }

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
          track.providerTrackId == normalizedTrackId) {
        return track;
      }
    }
    if (_isImporting) {
      throw StateError('Wait for the current library import to finish.');
    }

    _setImporting(true);
    ImportedTrack? copiedTrack;
    try {
      copiedTrack = await _copyPickedFile(
        PickedAudio(name: fileName, bytes: bytes),
      );
      final imported = copiedTrack.withMetadata(
        title: title,
        artist: artist,
        album: album,
        durationMs: durationMs,
        artworkUri: artworkUri,
        year: year,
        sourceProvider: normalizedProvider,
        providerTrackId: normalizedTrackId,
        licenseUrl: licenseUrl,
        metadataReviewed: true,
      );
      final updated = [..._tracks, imported];
      try {
        await _saveTracks(updated);
      } on Object {
        await _deleteCopies([copiedTrack]);
        rethrow;
      }
      _setTracks(updated);
      _invalidatePlaybackQueue();
      notifyListeners();
      return imported;
    } finally {
      _setImporting(false);
    }
  }

  Future<int> scanDeviceMusic() async {
    if (_isImporting) return 0;
    _setImporting(true);
    try {
      final discovered = [...await _scanDeviceAudio()];
      for (final folder in _musicFolders) {
        discovered.addAll(await _scanMusicFolder(folder.uri));
      }
      final deviceTracks = _tracksFromDeviceAudio(discovered);
      final importedTracks = _tracks
          .where((track) => !track.isDeviceMedia)
          .toList(growable: false);
      final updated = [...importedTracks, ...deviceTracks];
      await _saveTracks(updated);
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
      dialogTitle: 'Choose music to add to Tone',
    );
    return files
        .map(
          (file) =>
              PickedAudio(name: file.name, bytes: file.readAsByteStream()),
        )
        .toList(growable: false);
  }

  static Future<List<DeviceAudio>> _scanFromDevice() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError(
        'Device music scanning is currently available on Android.',
      );
    }
    final sdkVersion = await _platform.invokeMethod<int>('androidSdkVersion');
    final permission = sdkVersion != null && sdkVersion >= 33
        ? Permission.audio
        : Permission.storage;
    final status = await permission.request();
    if (!status.isGranted) {
      throw StateError(
        'Tone needs music access permission to scan your device.',
      );
    }
    const pageSize = 250;
    final audio = <DeviceAudio>[];
    var offset = 0;
    while (true) {
      final page = await _platform.invokeListMethod<Map<Object?, Object?>>(
        'scanAudio',
        {'offset': offset, 'limit': pageSize},
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

  static Future<List<DeviceAudio>> _emptyDeviceScan() async => const [];
  static Future<MusicFolder?> _emptyFolderPicker() async => null;
  static Future<List<DeviceAudio>> _emptyFolderScan(String _) async => const [];
  static Future<void> _emptyFolderRelease(String _) async {}

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
      final track = ImportedTrack.fromCopiedFile(
        id: id,
        path: destination.path,
        originalName: picked.name,
      );
      Map<Object?, Object?>? metadata;
      try {
        metadata = await _metadataReader(destination.path, track.title);
      } on PlatformException catch (error, stackTrace) {
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

  static Future<Map<Object?, Object?>?> _readImportedMetadata(
    String path,
    String fallbackTitle,
  ) async {
    if (!Platform.isAndroid) return null;
    return _platform.invokeMapMethod<Object?, Object?>(
      'readLocalAudioMetadata',
      {'path': path, 'fallbackTitle': fallbackTitle},
    );
  }

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
    final currentQueue = handler.queue.value;
    final queuedIndex = _queueIndexes[selectedTrack.id];
    if (_queuedTrackOrder.length == _tracks.length && queuedIndex != null) {
      if (currentQueue.length != _queuedTrackOrder.length ||
          currentQueue[queuedIndex].extras?['libraryId'] != selectedTrack.id) {
        throw StateError('The current playback queue is out of sync.');
      }
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
      _queueIndexes = {
        for (var index = 0; index < _queuedTrackOrder.length; index++)
          _queuedTrackOrder[index]: index,
      };
    }
    await handler.play();
    await _preferences.setString(_queueKey, jsonEncode(_queuedTrackOrder));
    await _preferences.setString(_currentTrackKey, selectedTrack.id);
    await _preferences.setInt(_positionKey, 0);
  }

  Future<void> restoreQueue(AudioHandler handler) async {
    final encodedQueue = _preferences.getString(_queueKey);
    if (encodedQueue == null || _tracks.isEmpty) return;

    final storedIds = (jsonDecode(encodedQueue) as List).cast<String>();
    final byId = {for (final track in _tracks) track.id: track};
    final restored = storedIds.map((id) => byId[id]).whereType<ImportedTrack>();
    final queue = restored.toList(growable: false);
    if (queue.isEmpty) return;

    final currentId = _preferences.getString(_currentTrackKey);
    final restoredIndex = queue.indexWhere((track) => track.id == currentId);
    await handler.updateQueue(
      queue.map((track) => track.toMediaItem()).toList(growable: false),
    );
    _queuedTrackOrder = queue.map((track) => track.id).toList(growable: false);
    _queueIndexes = {
      for (var index = 0; index < queue.length; index++) queue[index].id: index,
    };
    await handler.skipToQueueItem(restoredIndex < 0 ? 0 : restoredIndex);
    final position = _preferences.getInt(_positionKey) ?? 0;
    if (position > 0) {
      await handler.seek(Duration(milliseconds: position));
    }
  }

  Future<void> saveCurrentTrack(String? mediaId) async {
    if (mediaId == null) {
      await _preferences.remove(_currentTrackKey);
      await _preferences.remove(_positionKey);
      return;
    }
    final track = _tracks.where((item) => item.path == mediaId);
    if (track.isEmpty) return;
    if (_preferences.getString(_currentTrackKey) == track.first.id) return;
    await _preferences.setString(_currentTrackKey, track.first.id);
    await _preferences.setInt(_positionKey, 0);
  }

  Future<void> savePlaybackPosition(Duration position) =>
      _preferences.setInt(_positionKey, position.inMilliseconds);

  Future<void> removeTrack(ImportedTrack track) async {
    if (!_tracks.any((item) => item.id == track.id)) return;
    final updated = _tracks.where((item) => item.id != track.id).toList();
    await _saveTracks(updated);
    final updatedPlaylists = _playlists
        .map(
          (playlist) => _copyPlaylist(
            playlist,
            trackIds: playlist.trackIds
                .where((id) => id != track.id)
                .toList(growable: false),
          ),
        )
        .toList(growable: false);
    if (_playlists.any((playlist) => playlist.trackIds.contains(track.id))) {
      await _savePlaylists(updatedPlaylists);
      _playlists = updatedPlaylists;
    }
    _setTracks(updated);
    _invalidatePlaybackQueue();
    if (_favoriteTrackIds.remove(track.id)) {
      await _preferences.setStringList(
        _favoritesKey,
        _favoriteTrackIds.toList(),
      );
    }
    if (!track.isDeviceMedia) {
      final file = File(track.path);
      if (await file.exists()) {
        await file.delete();
      }
    }
    notifyListeners();
  }

  Future<void> _saveTracks(List<ImportedTrack> tracks) async {
    final json = tracks.map((track) => track.toJson()).toList(growable: false);
    await _preferences.setString(_tracksKey, jsonEncode(json));
  }

  Future<void> _savePlaylists(List<MusicPlaylist> playlists) =>
      _preferences.setString(
        _playlistsKey,
        jsonEncode(playlists.map((playlist) => playlist.toJson()).toList()),
      );

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
  );

  void _setImporting(bool value) {
    _isImporting = value;
    notifyListeners();
  }

  void _invalidatePlaybackQueue() {
    _queueIndexes = const {};
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
