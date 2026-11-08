import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tone_player/app/tone_theme.dart';
import 'package:tone_player/features/library/music_playlist_import.dart';
import 'package:tone_player/features/library/duplicate_track_selection.dart';
import 'package:tone_player/features/library/imported_track.dart';
import 'package:tone_player/features/library/music_library.dart';
import 'package:tone_player/features/library/music_playlist.dart';
import 'package:tone_player/features/library/playlist_detail_screen.dart';
import 'package:tone_player/features/library/library_track_filters.dart';
import 'package:tone_player/features/player/mini_player.dart';
import 'package:tone_player/features/sources/universal_link_sheet.dart';
import 'package:tone_player/features/spotify/spotify_import_sheet.dart';
import 'package:tone_player/features/youtube/youtube_search_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    required this.onUnavailable,
    this.onSearch,
    this.library,
    this.audioHandler,
    super.key,
  });

  final ValueChanged<String> onUnavailable;
  final VoidCallback? onSearch;
  final MusicLibrary? library;
  final AudioHandler? audioHandler;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final TextEditingController _trackQueryController = TextEditingController();
  static const _filters = [
    'Songs',
    'Albums',
    'Artists',
    'Favorites',
    'Duplicates',
    'Playlists',
  ];
  String _selectedFilter = _filters.first;
  String _trackQuery = '';
  LibraryTrackSort _trackSort = LibraryTrackSort.libraryOrder;
  _LibraryGroup? _selectedGroup;
  String? _selectedPlaylistId;
  List<List<ImportedTrack>> _duplicateGroups = const [];
  Set<String> _selectedDuplicateIds = {};
  bool _isLoadingDuplicates = false;
  Object? _duplicateError;

  @override
  void dispose() {
    _trackQueryController.dispose();
    super.dispose();
  }

  Future<void> _loadDuplicates() async {
    final library = widget.library;
    if (library == null) return;
    setState(() {
      _isLoadingDuplicates = true;
      _duplicateError = null;
    });
    try {
      final groups = await library.possibleDuplicateGroups();
      if (!mounted) return;
      setState(() {
        _duplicateGroups = groups;
        final duplicateIds = groups
            .expand((group) => group)
            .map((track) => track.id)
            .toSet();
        _selectedDuplicateIds = _selectedDuplicateIds
            .where(duplicateIds.contains)
            .toSet();
        _isLoadingDuplicates = false;
      });
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'tone library',
          context: ErrorDescription('while checking for duplicate tracks'),
        ),
      );
      if (!mounted) return;
      setState(() {
        _duplicateError = error;
        _isLoadingDuplicates = false;
      });
    }
  }

  Future<void> _smartSelectDuplicates() async {
    final library = widget.library;
    if (library == null || _duplicateGroups.isEmpty) return;
    try {
      final playCounts = {
        for (final item in await library.mostPlayedTracks(
          limit: library.tracks.length,
        ))
          item.track.id: item.playCount,
      };
      final selected = DuplicateTrackSelection.smartRemovalIds(
        _duplicateGroups,
        favoriteTrackIds: {
          for (final track in library.favoriteTracks) track.id,
        },
        playCounts: playCounts,
      );
      if (mounted) setState(() => _selectedDuplicateIds = selected);
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'tone library',
          context: ErrorDescription('while selecting duplicate copies'),
        ),
      );
      if (mounted) _showMessage('Could not smart-select duplicates: $error');
    }
  }

  Future<void> _removeSelectedDuplicates() async {
    final library = widget.library;
    if (library == null || _selectedDuplicateIds.isEmpty) return;
    final selected = _duplicateGroups
        .expand((group) => group)
        .where((track) => _selectedDuplicateIds.contains(track.id))
        .toList(growable: false);
    if (selected.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove selected duplicates?'),
        content: Text(
          'Melo selected ${selected.length} lower-priority copies. '
          'Favorites, frequently played songs, and better-tagged copies were '
          'prioritized to keep. This deletes the selected song files.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Review'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete selected'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final removalResult = await library.removeTracks(selected);
    for (final entry in removalResult.failures.entries) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: entry.value,
          stack: StackTrace.current,
          library: 'tone library',
          context: ErrorDescription('while deleting ${entry.key.title}'),
        ),
      );
    }
    if (removalResult.cancelled) {
      if (mounted) {
        _showMessage(
          'Deletion was canceled; the selected songs are still in your library.',
        );
      }
      return;
    }

    final removed = removalResult.removed;
    final failures = removalResult.failures.keys
        .map((track) => track.title)
        .toList(growable: true);
    try {
      await _removeDeletedTracksFromQueue(removed);
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'tone library',
          context: ErrorDescription('while updating the queue after cleanup'),
        ),
      );
      failures.add('playback queue');
    }
    if (!mounted) return;
    setState(() {
      _selectedDuplicateIds.removeAll(removed.map((track) => track.id));
    });
    await _loadDuplicates();
    if (!mounted) return;
    _showMessage(
      failures.isEmpty
          ? 'Deleted ${removed.length} duplicate '
                '${removed.length == 1 ? 'copy' : 'copies'}.'
          : 'Deleted ${removed.length}; ${failures.length} could not be '
                'removed. Review the remaining copies.',
    );
  }

  Future<void> _removeDeletedTracksFromQueue(
    List<ImportedTrack> removed,
  ) async {
    final handler = widget.audioHandler;
    if (handler == null || removed.isEmpty) return;
    final removedPaths = removed.map((track) => track.path).toSet();
    final queue = handler.queue.value;
    final nextQueue = queue
        .where((item) => !removedPaths.contains(item.id))
        .toList(growable: false);
    if (nextQueue.length == queue.length) return;

    final currentId = handler.mediaItem.value?.id;
    final currentWasRemoved =
        currentId != null && removedPaths.contains(currentId);
    final previousIndex = handler.playbackState.value.queueIndex ?? 0;
    final wasPlaying = handler.playbackState.value.playing;
    await handler.updateQueue(nextQueue);
    if (!currentWasRemoved) return;
    if (nextQueue.isEmpty) {
      await handler.stop();
      return;
    }
    await handler.skipToQueueItem(previousIndex.clamp(0, nextQueue.length - 1));
    if (wasPlaying) await handler.play();
  }

  Future<void> _scanDevice() async {
    final library = widget.library;
    if (library == null) {
      widget.onUnavailable('Device music scan');
      return;
    }

    try {
      final count = await library.scanDeviceMusic();
      if (!mounted) return;
      _showMessage(
        count == 0
            ? 'No supported music files were found on this device.'
            : 'Found $count songs on your device.',
      );
    } on MusicPermissionDeniedException catch (error) {
      if (!mounted) return;
      await _showScanPermissionHelp(error.permanentlyDenied);
    } on Object catch (error) {
      if (!mounted) return;
      _showMessage('Could not scan device music: $error');
    }
  }

  /// Device scanning depends on a system permission Tone cannot grant itself,
  /// so when it is missing we explain why and offer the settings screen
  /// instead of surfacing a raw error.
  Future<void> _showScanPermissionHelp(bool permanentlyDenied) async {
    final openSettings = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Allow music access'),
        content: Text(
          permanentlyDenied
              ? 'Melo scans music already on this device. Music access is '
                    'turned off, so allow it for Melo in your system settings.'
              : 'Melo needs access to your device music before it can scan '
                    'your songs.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Open settings'),
          ),
        ],
      ),
    );
    if (openSettings == true) {
      await openAppSettings();
    }
  }

  Future<void> _addSongs() async {
    final library = widget.library;
    if (library == null) {
      widget.onUnavailable('Music import');
      return;
    }

    try {
      final count = await library.pickAndImport();
      final skipped = library.lastImportSkippedDuplicates;
      if (!mounted || (count == 0 && skipped == 0)) return;
      final addedMessage = count == 1 ? 'Added 1 song' : 'Added $count songs';
      final skippedMessage = skipped == 1
          ? 'skipped 1 exact duplicate'
          : 'skipped $skipped exact duplicates';
      _showMessage(
        count == 0
            ? 'All selected songs were already in your library.'
            : skipped == 0
            ? '$addedMessage to your library.'
            : '$addedMessage; $skippedMessage.',
      );
      if (_selectedFilter == 'Duplicates') await _loadDuplicates();
    } on Object catch (error) {
      if (!mounted) return;
      _showMessage('Could not add music: $error');
    }
  }

  Future<void> _importPlaylist() async {
    final library = widget.library;
    if (library == null) {
      widget.onUnavailable('Playlist import');
      return;
    }

    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['m3u', 'm3u8'],
        dialogTitle: 'Choose a playlist to import',
      );
      if (files.isEmpty) return;
      final file = files.first;
      final contents = await utf8.decoder.bind(file.readAsByteStream()).join();
      final entries = MusicPlaylistImport.parseM3uEntries(contents);
      if (entries.isEmpty) {
        if (mounted) _showMessage('This playlist has no song entries.');
        return;
      }
      var tracks = MusicPlaylistImport.resolvePlaylistEntries(
        entries,
        library.tracks,
      );
      if (tracks.isEmpty) {
        if (!mounted) return;
        final scanNow = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('No matching songs yet'),
            content: const Text(
              'Melo checked playlist paths, original filenames, and available '
              'song metadata. Scan device music once in case these downloads '
              'have not been added to the library yet.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Scan device music'),
              ),
            ],
          ),
        );
        if (scanNow != true) return;
        await library.scanDeviceMusic();
        if (!mounted) return;
        tracks = MusicPlaylistImport.resolvePlaylistEntries(
          entries,
          library.tracks,
        );
        if (tracks.isEmpty) {
          _showMessage(
            'No available songs matched this playlist after scanning. Check '
            'that the files are in a scanned folder and try again.',
          );
          return;
        }
      }

      final defaultName = file.name.replaceFirst(
        RegExp(r'\.m3u8?$', caseSensitive: false),
        '',
      );
      final name = await _playlistNameDialog(
        title: 'Name imported playlist',
        initialName: defaultName,
      );
      if (!mounted || name == null) return;
      final missingCount = entries.length - tracks.length;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import playlist?'),
          content: Text(
            '${tracks.length} songs match your library.'
            '${missingCount > 0 ? ' $missingCount entries are unmatched, unavailable, or repeated and will be skipped.' : ''}'
            ' Songs will not be copied.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Import'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      final playlist = await library.createPlaylist(name);
      try {
        await library.addTracksToPlaylist(
          playlist.id,
          tracks.map((track) => track.id),
        );
      } on Object {
        await library.deletePlaylist(playlist.id);
        rethrow;
      }
      if (!mounted) return;
      setState(() {
        _selectedFilter = 'Playlists';
        _selectedPlaylistId = playlist.id;
      });
      _showMessage('Imported ${playlist.name} with ${tracks.length} songs.');
    } on MusicPermissionDeniedException catch (error) {
      if (!mounted) return;
      await _showScanPermissionHelp(error.permanentlyDenied);
    } on Object catch (error) {
      if (!mounted) return;
      _showMessage('Could not import playlist: $error');
    }
  }

  Future<void> _queueTrack(ImportedTrack track) async {
    final library = widget.library;
    final handler = widget.audioHandler;
    if (library == null || handler == null) {
      widget.onUnavailable('Queue music');
      return;
    }
    if (!track.isAvailable) {
      _showMessage('This song is unavailable and cannot be queued.');
      return;
    }
    final alreadyQueued = handler.queue.value.any(
      (item) => item.extras?['libraryId'] == track.id || item.id == track.path,
    );
    if (alreadyQueued) {
      _showMessage('${track.title} is already in the queue.');
      return;
    }
    try {
      await handler.addQueueItem(track.toMediaItem());
      if (mounted) _showMessage('Added ${track.title} to the queue.');
    } on Object catch (error) {
      if (!mounted) return;
      _showMessage('Could not add this song to the queue: $error');
    }
  }

  Future<void> _addMusicFolder() async {
    final library = widget.library;
    if (library == null) {
      widget.onUnavailable('Folder music access');
      return;
    }

    try {
      final count = await library.addMusicFolder();
      if (!mounted || count == 0) return;
      _showMessage(
        count == 1
            ? 'Added 1 song from the selected folder.'
            : 'Added $count songs from the selected folder.',
      );
    } on Object catch (error) {
      if (!mounted) return;
      _showMessage('Could not add that music folder: $error');
    }
  }

  Future<void> _removeMusicFolder(MusicFolder folder) async {
    final library = widget.library;
    if (library == null) return;
    try {
      await library.removeMusicFolder(folder);
      if (!mounted) return;
      _showMessage('Removed ${folder.name} from Tone.');
    } on Object catch (error) {
      if (!mounted) return;
      _showMessage('Could not remove ${folder.name}: $error');
    }
  }

  Future<void> _playTrack(ImportedTrack track) async {
    final library = widget.library;
    final handler = widget.audioHandler;
    if (library == null || handler == null) return;
    try {
      final index = library.indexOfTrack(track.id);
      if (index < 0) throw StateError('This song is no longer in the library.');
      await library.playTrack(handler, index);
    } on Object catch (error) {
      if (!mounted) return;
      _showMessage('Could not play this song: $error');
    }
  }

  Future<void> _playAlbum(
    List<ImportedTrack> tracks, {
    String? startTrackId,
    bool shuffle = false,
  }) async {
    final library = widget.library;
    final handler = widget.audioHandler;
    if (library == null || handler == null) {
      widget.onUnavailable('Album playback');
      return;
    }
    try {
      final orderedTracks = [...tracks]
        ..sort((first, second) {
          final firstNumber = first.trackNumber;
          final secondNumber = second.trackNumber;
          if (firstNumber != null && secondNumber != null) {
            return firstNumber.compareTo(secondNumber);
          }
          if (firstNumber != null) return -1;
          if (secondNumber != null) return 1;
          return first.title.toLowerCase().compareTo(
            second.title.toLowerCase(),
          );
        });
      if (shuffle) {
        orderedTracks.shuffle();
      } else if (startTrackId != null) {
        final startIndex = orderedTracks.indexWhere(
          (track) => track.id == startTrackId,
        );
        if (startIndex >= 0) {
          final rotated = [
            ...orderedTracks.skip(startIndex),
            ...orderedTracks.take(startIndex),
          ];
          orderedTracks
            ..clear()
            ..addAll(rotated);
        }
      }
      await library.playMix(handler, orderedTracks);
    } on Object catch (error) {
      if (!mounted) return;
      _showMessage('Could not play this album: $error');
    }
  }

  Future<void> _addAlbumToPlaylist(List<ImportedTrack> tracks) async {
    final library = widget.library;
    if (library == null) {
      widget.onUnavailable('Add album to playlist');
      return;
    }
    try {
      final playlists = library.playlists;
      String? playlistId;
      if (playlists.isEmpty) {
        final name = await _playlistNameDialog(
          title: 'Create a playlist for this album',
        );
        if (name == null) return;
        playlistId = (await library.createPlaylist(name)).id;
      } else {
        playlistId = await showDialog<String>(
          context: context,
          builder: (context) => SimpleDialog(
            title: const Text('Add album to playlist'),
            children: [
              for (final playlist in playlists)
                SimpleDialogOption(
                  onPressed: () => Navigator.of(context).pop(playlist.id),
                  child: Text(playlist.name),
                ),
            ],
          ),
        );
        if (playlistId == null) return;
      }
      await library.addTracksToPlaylist(
        playlistId,
        tracks.map((track) => track.id),
      );
      if (mounted) _showMessage('Album added to your playlist.');
    } on Object catch (error) {
      if (!mounted) return;
      _showMessage('Could not add this album to a playlist: $error');
    }
  }

  Future<void> _playAlbumArtistRadio(String artist) async {
    final library = widget.library;
    final handler = widget.audioHandler;
    if (library == null || handler == null) return;
    try {
      await library.playArtistRadio(handler, artist);
      if (mounted) _showMessage('Playing $artist radio from your library.');
    } on Object catch (error) {
      if (!mounted) return;
      _showMessage('Could not start $artist radio: $error');
    }
  }

  void _showAlbumDetails(_LibraryGroup group, List<ImportedTrack> tracks) {
    int? year;
    for (final track in tracks) {
      if (track.year != null) {
        year = track.year;
        break;
      }
    }
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(group.title),
        content: Text(
          'Artist: ${displayArtistName(group.artworkTrack.artist)}\n'
          'Songs: ${tracks.length}\n'
          'Release year: ${year ?? 'Not tagged'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeTrack(ImportedTrack track) async {
    final library = widget.library;
    if (library == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this song file?'),
        content: Text(
          track.isDeviceMedia
              ? 'This permanently deletes “${track.title}” from your device. Android may ask you to confirm the deletion again.'
              : 'This permanently deletes Tone’s imported copy of “${track.title}”. The original file you selected will not be changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete file'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final deleted = await library.removeTrack(track);
      if (!deleted) {
        if (mounted) {
          _showMessage(
            'Deletion was canceled; the song is still in your library.',
          );
        }
        return;
      }

      final handler = widget.audioHandler;
      if (handler != null) {
        final queue = handler.queue.value;
        if (queue.any((item) => item.id == track.path)) {
          final currentId = handler.mediaItem.value?.id;
          final wasPlaying = handler.playbackState.value.playing;
          final nextQueue = queue
              .where((item) => item.id != track.path)
              .toList(growable: false);
          final currentIndex = nextQueue.indexWhere(
            (item) => item.id == currentId,
          );
          await handler.updateQueue(nextQueue);
          if (nextQueue.isNotEmpty) {
            await handler.skipToQueueItem(currentIndex < 0 ? 0 : currentIndex);
            if (wasPlaying) await handler.play();
          } else {
            await handler.stop();
          }
        }
      }
      if (_selectedFilter == 'Duplicates') await _loadDuplicates();
      if (mounted) _showMessage('Deleted ${track.title}.');
    } on Object catch (error) {
      if (!mounted) return;
      _showMessage('Could not delete this song: $error');
    }
  }

  Future<void> _toggleFavorite(ImportedTrack track) async {
    final library = widget.library;
    if (library == null) return;
    try {
      final isFavorite = await library.toggleFavorite(track.id);
      if (!mounted) return;
      _showMessage(
        isFavorite
            ? 'Added ${track.title} to favorites.'
            : 'Removed ${track.title} from favorites.',
      );
    } on Object catch (error) {
      if (!mounted) return;
      _showMessage('Could not update favorite: $error');
    }
  }

  Future<void> _createPlaylist() async {
    final library = widget.library;
    if (library == null) return;
    final name = await _playlistNameDialog(title: 'New playlist');
    if (name == null) return;
    try {
      final playlist = await library.createPlaylist(name);
      if (!mounted) return;
      setState(() => _selectedPlaylistId = playlist.id);
      _showMessage('Created ${playlist.name}.');
    } on Object catch (error) {
      if (!mounted) return;
      _showMessage('Could not create playlist: $error');
    }
  }

  Future<void> _renamePlaylist(MusicPlaylist playlist) async {
    final library = widget.library;
    if (library == null) return;
    final name = await _playlistNameDialog(
      title: 'Rename playlist',
      initialName: playlist.name,
    );
    if (name == null) return;
    try {
      await library.renamePlaylist(playlist.id, name);
    } on Object catch (error) {
      if (!mounted) return;
      _showMessage('Could not rename playlist: $error');
    }
  }

  Future<String?> _playlistNameDialog({
    required String title,
    String initialName = '',
  }) => showDialog<String>(
    context: context,
    builder: (context) =>
        _PlaylistNameDialog(title: title, initialName: initialName),
  );

  Future<void> _deletePlaylist(MusicPlaylist playlist) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete playlist?'),
        content: Text(
          'Delete "${playlist.name}"? Your songs will stay in Tone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep playlist'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.library?.deletePlaylist(playlist.id);
      if (mounted && _selectedPlaylistId == playlist.id) {
        setState(() => _selectedPlaylistId = null);
      }
    } on Object catch (error) {
      if (!mounted) return;
      _showMessage('Could not delete playlist: $error');
    }
  }

  Future<void> _addSongsToPlaylist(MusicPlaylist playlist) async {
    final library = widget.library;
    if (library == null) return;
    final selected = await showDialog<Set<String>>(
      context: context,
      builder: (context) {
        final chosen = <String>{};
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text('Add songs to ${playlist.name}'),
            content: SizedBox(
              width: 420,
              height: 420,
              child: library.tracks.isEmpty
                  ? const Center(child: Text('Scan your device to find songs.'))
                  : ListView.builder(
                      itemCount: library.tracks.length,
                      itemBuilder: (context, index) {
                        final track = library.tracks[index];
                        final alreadyAdded = playlist.trackIds.contains(
                          track.id,
                        );
                        return CheckboxListTile(
                          value: alreadyAdded || chosen.contains(track.id),
                          onChanged: alreadyAdded
                              ? null
                              : (selected) => setDialogState(() {
                                  if (selected == true) {
                                    chosen.add(track.id);
                                  } else {
                                    chosen.remove(track.id);
                                  }
                                }),
                          title: Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(displayArtistName(track.artist)),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(chosen),
                child: const Text('Add selected'),
              ),
            ],
          ),
        );
      },
    );
    if (selected == null || selected.isEmpty) return;
    try {
      await library.addTracksToPlaylist(playlist.id, selected);
    } on Object catch (error) {
      if (!mounted) return;
      _showMessage('Could not add songs: $error');
    }
  }

  Future<void> _playPlaylist(MusicPlaylist playlist, {String? trackId}) async {
    final library = widget.library;
    final handler = widget.audioHandler;
    if (library == null || handler == null) {
      widget.onUnavailable('Playlist playback');
      return;
    }
    try {
      await library.playPlaylist(handler, playlist.id, startTrackId: trackId);
    } on Object catch (error) {
      if (!mounted) return;
      _showMessage('Could not play playlist: $error');
    }
  }

  Future<void> _removePlaylistTrack(
    MusicPlaylist playlist,
    ImportedTrack track,
  ) async {
    try {
      await widget.library?.removeTrackFromPlaylist(playlist.id, track.id);
    } on Object catch (error) {
      if (!mounted) return;
      _showMessage('Could not remove song from playlist: $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  bool _matchesTrackFilters(ImportedTrack track) {
    final query = _trackQuery.trim().toLowerCase();
    final matchesQuery =
        query.isEmpty ||
        track.title.toLowerCase().contains(query) ||
        track.artist.toLowerCase().contains(query) ||
        track.album.toLowerCase().contains(query);
    return matchesQuery;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final library = widget.library;
    return AnimatedBuilder(
      animation: library ?? _NoopListenable.instance,
      builder: (context, _) {
        final tracks = library?.tracks ?? const <ImportedTrack>[];
        final playlists = library?.playlists ?? const <MusicPlaylist>[];
        MusicPlaylist? foundPlaylist;
        if (_selectedPlaylistId != null) {
          for (final playlist in playlists) {
            if (playlist.id == _selectedPlaylistId) {
              foundPlaylist = playlist;
              break;
            }
          }
        }
        final selectedPlaylist = foundPlaylist;
        final sourceTracks = selectedPlaylist != null
            ? library?.tracksForPlaylist(selectedPlaylist.id) ??
                  const <ImportedTrack>[]
            : _selectedFilter == 'Favorites'
            ? library?.favoriteTracks ?? const <ImportedTrack>[]
            : _selectedFilter == 'Duplicates'
            ? _duplicateGroups.expand((group) => group).toList(growable: false)
            : tracks;
        final visibleTracks = const LibraryTrackFilters().apply(
          sourceTracks.where(_matchesTrackFilters),
          _trackSort,
        );
        final showEmpty =
            library == null ||
            (tracks.isEmpty && _selectedFilter != 'Playlists');
        final selectedTracks = _selectedGroup == null
            ? <ImportedTrack>[]
            : tracks
                  .where((track) => _matchesGroup(track, _selectedGroup!))
                  .toList();
        if (_selectedFilter == 'Albums') {
          selectedTracks.sort((first, second) {
            final firstNumber = first.trackNumber;
            final secondNumber = second.trackNumber;
            if (firstNumber != null && secondNumber != null) {
              return firstNumber.compareTo(secondNumber);
            }
            if (firstNumber != null) return -1;
            if (secondNumber != null) return 1;
            return first.title.toLowerCase().compareTo(
              second.title.toLowerCase(),
            );
          });
        }
        final visibleSelectedTracks = const LibraryTrackFilters().apply(
          selectedTracks.where(_matchesTrackFilters),
          _trackSort,
        );
        final selectedAlbum = _selectedFilter == 'Albums'
            ? _selectedGroup
            : null;
        final albumHeader = selectedAlbum == null
            ? null
            : Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                child: _AlbumDetailHeader(
                  group: selectedAlbum,
                  tracks: selectedTracks,
                  onBack: () => setState(() => _selectedGroup = null),
                  onSearch: widget.onSearch,
                  onPlay: () => _playAlbum(selectedTracks),
                  onShuffle: () => _playAlbum(selectedTracks, shuffle: true),
                  onAddToPlaylist: () => _addAlbumToPlaylist(selectedTracks),
                  onArtistRadio: () =>
                      _playAlbumArtistRadio(selectedAlbum.artworkTrack.artist),
                  onShowDetails: () =>
                      _showAlbumDetails(selectedAlbum, selectedTracks),
                ),
              );
        final canBrowseTracks =
            _selectedFilter == 'Songs' ||
            _selectedFilter == 'Favorites' ||
            _selectedFilter == 'Duplicates' ||
            _selectedGroup != null ||
            selectedPlaylist != null;
        final page = CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child:
                  albumHeader ??
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Your library',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.8,
                                    ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'YouTube Music',
                              icon: const Icon(
                                Icons.play_circle_fill_rounded,
                                color: Colors.red,
                              ),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => YoutubeSearchScreen(
                                    audioHandler: widget.audioHandler,
                                    library: widget.library,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Import Online Playlist',
                              icon: const Icon(
                                Icons.playlist_add_rounded,
                                color: ToneColors.cherry,
                              ),
                              onPressed: () => SpotifyImportSheet.show(
                                context,
                                library: widget.library,
                                audioHandler: widget.audioHandler,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Download Lossless FLAC & Links',
                              icon: const Icon(
                                Icons.link_rounded,
                                color: ToneColors.cherry,
                              ),
                              onPressed: () => UniversalLinkSheet.show(
                                context,
                                library: widget.library,
                                audioHandler: widget.audioHandler,
                              ),
                            ),
                            if (widget.onSearch != null)
                              IconButton(
                                tooltip: 'Search',
                                onPressed: widget.onSearch,
                                icon: const Icon(Icons.search_rounded),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Everything you love, together.',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                        const SizedBox(height: 22),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            FilledButton.icon(
                              onPressed: library?.isImporting == true
                                  ? null
                                  : _scanDevice,
                              icon: library?.isImporting == true
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.library_music_outlined),
                              label: Text(
                                library?.isImporting == true
                                    ? 'Scanning…'
                                    : 'Scan device',
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: library?.isImporting == true
                                  ? null
                                  : _addSongs,
                              icon: const Icon(Icons.file_open_outlined),
                              label: const Text('Import files'),
                            ),
                            OutlinedButton.icon(
                              onPressed: library?.isImporting == true
                                  ? null
                                  : _addMusicFolder,
                              icon: const Icon(
                                Icons.create_new_folder_outlined,
                              ),
                              label: const Text('Add folder'),
                            ),
                          ],
                        ),
                        if (library?.musicFolders.isNotEmpty == true) ...[
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              for (final folder in library!.musicFolders)
                                InputChip(
                                  avatar: const Icon(
                                    Icons.folder_outlined,
                                    size: 18,
                                  ),
                                  label: Text(folder.name),
                                  onDeleted: library.isImporting
                                      ? null
                                      : () => _removeMusicFolder(folder),
                                ),
                            ],
                          ),
                        ],
                        if (_selectedFilter == 'Playlists' &&
                            selectedPlaylist == null) ...[
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              FilledButton.icon(
                                onPressed: _createPlaylist,
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Create playlist'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => SpotifyImportSheet.show(
                                  context,
                                  library: widget.library,
                                  audioHandler: widget.audioHandler,
                                ),
                                icon: const Icon(
                                  Icons.playlist_add_rounded,
                                  color: ToneColors.cherry,
                                ),
                                label: const Text('Import link'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => UniversalLinkSheet.show(
                                  context,
                                  library: widget.library,
                                  audioHandler: widget.audioHandler,
                                ),
                                icon: const Icon(
                                  Icons.link_rounded,
                                  color: ToneColors.cherry,
                                ),
                                label: const Text('Rip FLAC / Links'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _importPlaylist,
                                icon: const Icon(Icons.file_upload_outlined),
                                label: const Text('Import file'),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 22),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final label in _filters)
                              ChoiceChip(
                                label: Text(label),
                                selected: _selectedFilter == label,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _selectedFilter = label;
                                      _selectedGroup = null;
                                      _selectedPlaylistId = null;
                                      _trackQuery = '';
                                      _trackQueryController.clear();
                                    });
                                    if (label == 'Duplicates') {
                                      _loadDuplicates();
                                    }
                                  }
                                },
                              ),
                          ],
                        ),
                        if (canBrowseTracks) ...[
                          const SizedBox(height: 16),
                          Row(
                            key: const ValueKey('library-search-sort-row'),
                            children: [
                              Expanded(
                                child: TextField(
                                  key: const ValueKey('library-track-filter'),
                                  controller: _trackQueryController,
                                  decoration: InputDecoration(
                                    hintText: 'Search songs, artists, albums',
                                    prefixIcon: const Icon(
                                      Icons.search_rounded,
                                    ),
                                    suffixIcon: _trackQuery.isEmpty
                                        ? null
                                        : IconButton(
                                            tooltip: 'Clear search',
                                            onPressed: () {
                                              _trackQueryController.clear();
                                              setState(() => _trackQuery = '');
                                            },
                                            icon: const Icon(
                                              Icons.clear_rounded,
                                            ),
                                          ),
                                    isDense: true,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onChanged: (value) =>
                                      setState(() => _trackQuery = value),
                                ),
                              ),
                              PopupMenuButton<LibraryTrackSort>(
                                key: const ValueKey('library-track-sort'),
                                tooltip: 'Sort: ${_trackSort.label}',
                                onSelected: (sort) =>
                                    setState(() => _trackSort = sort),
                                itemBuilder: (context) => [
                                  for (final sort in LibraryTrackSort.values)
                                    PopupMenuItem(
                                      value: sort,
                                      child: _LibraryMenuChoice(
                                        label: sort.label,
                                        selected: sort == _trackSort,
                                      ),
                                    ),
                                ],
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.swap_vert_rounded),
                                      const SizedBox(width: 4),
                                      Text(
                                        _trackSort.label,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium,
                                      ),
                                      const Icon(Icons.expand_more_rounded),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 20),
                        if (_selectedFilter == 'Duplicates' &&
                            _duplicateError != null)
                          Text(
                            'Could not check for duplicates: $_duplicateError',
                          )
                        else if (_selectedFilter == 'Duplicates' &&
                            _isLoadingDuplicates)
                          const Center(child: CircularProgressIndicator())
                        else if (_selectedFilter == 'Duplicates' &&
                            _duplicateGroups.isEmpty &&
                            !showEmpty)
                          const Text(
                            'No likely duplicates found. Melo keeps every source until you choose to remove one.',
                          )
                        else if (_selectedFilter == 'Duplicates' && !showEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Smart select keeps the available, favorited, '
                                'frequently played, or better-tagged copy. '
                                'Review your selection before deleting files.',
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _isLoadingDuplicates
                                        ? null
                                        : _smartSelectDuplicates,
                                    icon: const Icon(
                                      Icons.auto_awesome_rounded,
                                    ),
                                    label: const Text('Smart select'),
                                  ),
                                  if (_selectedDuplicateIds.isNotEmpty)
                                    FilledButton.icon(
                                      onPressed: _removeSelectedDuplicates,
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                      ),
                                      label: Text(
                                        'Delete ${_selectedDuplicateIds.length} selected',
                                      ),
                                    ),
                                  if (_selectedDuplicateIds.isNotEmpty)
                                    TextButton(
                                      onPressed: () => setState(
                                        () => _selectedDuplicateIds.clear(),
                                      ),
                                      child: const Text('Clear'),
                                    ),
                                ],
                              ),
                            ],
                          )
                        else if (showEmpty)
                          _EmptyLibrary(isAvailable: library != null)
                        else if (_selectedFilter == 'Playlists' &&
                            selectedPlaylist == null &&
                            playlists.isEmpty)
                          const _NotAvailableFilter(filter: 'Playlists')
                        else if (canBrowseTracks &&
                            selectedPlaylist == null &&
                            _selectedGroup == null &&
                            visibleTracks.isEmpty &&
                            !showEmpty)
                          const Text('No songs match these filters.')
                        else if (_selectedFilter == 'Favorites' &&
                            visibleTracks.isEmpty)
                          const _NotAvailableFilter(filter: 'Favorites')
                        else if (selectedPlaylist != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    tooltip: 'Back to playlists',
                                    onPressed: () => setState(
                                      () => _selectedPlaylistId = null,
                                    ),
                                    icon: const Icon(Icons.arrow_back_rounded),
                                  ),
                                  PlaylistArtwork(
                                    playlistName: selectedPlaylist.name,
                                    tracks: library.tracksForPlaylist(
                                      selectedPlaylist.id,
                                    ),
                                    library: library,
                                    size: 46,
                                    borderRadius: 12,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      selectedPlaylist.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    tooltip: 'Playlist options',
                                    onSelected: (value) {
                                      if (value == 'rename') {
                                        _renamePlaylist(selectedPlaylist);
                                      } else if (value == 'delete') {
                                        _deletePlaylist(selectedPlaylist);
                                      }
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(
                                        value: 'rename',
                                        child: Text('Rename'),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Delete playlist'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 10,
                                children: [
                                  FilledButton.icon(
                                    onPressed: selectedPlaylist.trackIds.isEmpty
                                        ? null
                                        : () => _playPlaylist(selectedPlaylist),
                                    icon: const Icon(Icons.play_arrow_rounded),
                                    label: const Text('Play'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        _addSongsToPlaylist(selectedPlaylist),
                                    icon: const Icon(
                                      Icons.playlist_add_rounded,
                                    ),
                                    label: const Text('Add songs'),
                                  ),
                                ],
                              ),
                              if (selectedPlaylist.trackIds.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.only(top: 18),
                                  child: Text(
                                    'This playlist is ready for its first song.',
                                  ),
                                ),
                            ],
                          )
                        else if (_selectedGroup != null &&
                            _selectedFilter != 'Albums')
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: IconButton(
                              tooltip:
                                  'Back to ${_selectedFilter.toLowerCase()}',
                              onPressed: () =>
                                  setState(() => _selectedGroup = null),
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                            title: Text(
                              _selectedGroup!.title,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            subtitle: Text(_selectedGroup!.subtitle),
                          ),
                      ],
                    ),
                  ),
            ),
            if (!showEmpty &&
                _selectedFilter == 'Playlists' &&
                selectedPlaylist == null)
              _PlaylistList(
                playlists: playlists,
                library: library,
                tracksFor: (playlist) => library.tracksForPlaylist(playlist.id),
                trackCount: (playlist) =>
                    library.tracksForPlaylist(playlist.id).length,
                onSelect: (playlist) {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PlaylistDetailScreen(
                        playlist: playlist,
                        library: library,
                        audioHandler: widget.audioHandler,
                      ),
                    ),
                  );
                },
                onPlay: _playPlaylist,
                onRename: _renamePlaylist,
                onDelete: _deletePlaylist,
              )
            else if (!showEmpty &&
                _selectedFilter == 'Playlists' &&
                selectedPlaylist != null)
              _PlaylistTrackList(
                tracks: library.tracksForPlaylist(selectedPlaylist.id),
                onPlay: (track) =>
                    _playPlaylist(selectedPlaylist, trackId: track.id),
                onQueue: _queueTrack,
                onRemove: (track) =>
                    _removePlaylistTrack(selectedPlaylist, track),
                onReorder: (oldIndex, newIndex) async {
                  try {
                    await library.reorderPlaylistTrack(
                      selectedPlaylist.id,
                      oldIndex,
                      newIndex,
                    );
                  } on Object catch (error) {
                    if (mounted) {
                      _showMessage('Could not reorder playlist: $error');
                    }
                  }
                },
              )
            else if (!showEmpty &&
                _selectedGroup != null &&
                _selectedFilter == 'Albums')
              StreamBuilder<MediaItem?>(
                stream: widget.audioHandler?.mediaItem,
                builder: (context, mediaSnapshot) => _AlbumTrackList(
                  tracks: visibleSelectedTracks,
                  currentTrackId:
                      mediaSnapshot.data?.extras?['libraryId'] as String?,
                  onPlay: (track) =>
                      _playAlbum(selectedTracks, startTrackId: track.id),
                  onQueue: _queueTrack,
                  onRemove: _removeTrack,
                  onToggleFavorite: _toggleFavorite,
                  isFavorite: (track) => library.isFavorite(track.id),
                ),
              )
            else if (!showEmpty && canBrowseTracks)
              _TrackList(
                tracks: _selectedGroup != null
                    ? visibleSelectedTracks
                    : visibleTracks,
                onPlay: _playTrack,
                onQueue: _queueTrack,
                onRemove: _removeTrack,
                onToggleFavorite: _toggleFavorite,
                isFavorite: (track) => library.isFavorite(track.id),
                selectedIds: _selectedFilter == 'Duplicates'
                    ? _selectedDuplicateIds
                    : null,
                onToggleSelection: _selectedFilter == 'Duplicates'
                    ? (track) => setState(() {
                        if (!_selectedDuplicateIds.add(track.id)) {
                          _selectedDuplicateIds.remove(track.id);
                        }
                      })
                    : null,
              )
            else if (!showEmpty && _selectedFilter != 'Playlists')
              _GroupList(
                groups: _buildGroups(tracks),
                onSelect: (group) => setState(() => _selectedGroup = group),
              ),
          ],
        );
        return selectedAlbum == null
            ? page
            : Material(color: colors.surface, child: page);
      },
    );
  }

  List<_LibraryGroup> _buildGroups(List<ImportedTrack> tracks) {
    final grouped = <String, List<ImportedTrack>>{};
    for (final track in tracks) {
      final key = _selectedFilter == 'Albums'
          ? '${track.album}\u001f${track.artist}'
          : track.artist;
      grouped.putIfAbsent(key, () => []).add(track);
    }
    return grouped.entries.map((entry) {
      final groupTracks = entry.value;
      final first = groupTracks.first;
      return _LibraryGroup(
        key: entry.key,
        title: _selectedFilter == 'Albums'
            ? first.album
            : displayArtistName(first.artist),
        subtitle: _selectedFilter == 'Albums'
            ? '${displayArtistName(first.artist)} · ${groupTracks.length} songs'
            : '${groupTracks.length} songs',
        artworkTrack: first,
      );
    }).toList()..sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
  }

  bool _matchesGroup(ImportedTrack track, _LibraryGroup group) =>
      _selectedFilter == 'Albums'
      ? '${track.album}\u001f${track.artist}' == group.key
      : track.artist == group.key;
}

class _AlbumDetailHeader extends StatelessWidget {
  const _AlbumDetailHeader({
    required this.group,
    required this.tracks,
    required this.onBack,
    required this.onSearch,
    required this.onPlay,
    required this.onShuffle,
    required this.onAddToPlaylist,
    required this.onArtistRadio,
    required this.onShowDetails,
  });

  final _LibraryGroup group;
  final List<ImportedTrack> tracks;
  final VoidCallback onBack;
  final VoidCallback? onSearch;
  final VoidCallback onPlay;
  final VoidCallback onShuffle;
  final VoidCallback onAddToPlaylist;
  final VoidCallback onArtistRadio;
  final VoidCallback onShowDetails;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final artwork = group.artworkTrack;
    int? year;
    for (final track in tracks) {
      if (track.year != null) {
        year = track.year;
        break;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Back to albums',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const Spacer(),
            if (onSearch != null)
              IconButton(
                tooltip: 'Search music',
                onPressed: onSearch,
                icon: const Icon(Icons.search_rounded),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AlbumArtwork(
              size: 96,
              title: artwork.title,
              artworkUri: artwork.artworkUri == null
                  ? null
                  : Uri.tryParse(artwork.artworkUri!),
              sourceUri: Uri.tryParse(artwork.path),
              borderRadius: 16,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Album · ${tracks.length} songs · ${year ?? 'Year not tagged'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    group.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    displayArtistName(artwork.artist),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Add album to playlist',
                        visualDensity: VisualDensity.compact,
                        onPressed: onAddToPlaylist,
                        icon: const Icon(Icons.playlist_add_rounded),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Album options',
                        onSelected: (value) {
                          if (value == 'radio') onArtistRadio();
                          if (value == 'details') onShowDetails();
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'radio',
                            child: Text('Start artist radio'),
                          ),
                          PopupMenuItem(
                            value: 'details',
                            child: Text('Album details'),
                          ),
                        ],
                        icon: const Icon(Icons.more_horiz_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: tracks.isEmpty ? null : onPlay,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  minimumSize: const Size(48, 46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.play_circle_outline_rounded, size: 19),
                label: const Text('Play'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: tracks.isEmpty ? null : onShuffle,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.onSurface,
                  backgroundColor: colors.surfaceContainerHigh,
                  side: BorderSide.none,
                  minimumSize: const Size(48, 46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.shuffle_rounded, size: 18),
                label: const Text('Shuffle'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LibraryMenuChoice extends StatelessWidget {
  const _LibraryMenuChoice({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label)),
      if (selected) const Icon(Icons.check_rounded, size: 18),
    ],
  );
}

class _LibraryTrackFilterSheet extends StatefulWidget {
  const _LibraryTrackFilterSheet({required this.initial});

  final LibraryTrackFilters initial;

  @override
  State<_LibraryTrackFilterSheet> createState() =>
      _LibraryTrackFilterSheetState();
}

class _LibraryTrackFilterSheetState extends State<_LibraryTrackFilterSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _minimumSizeController;
  late final TextEditingController _maximumSizeController;
  late final TextEditingController _minimumDurationController;
  late final TextEditingController _maximumDurationController;
  DateTimeRange? _modifiedRange;

  @override
  void initState() {
    super.initState();
    _minimumSizeController = TextEditingController(
      text: _formatThreshold(widget.initial.minimumSizeBytes, 1024 * 1024),
    );
    _maximumSizeController = TextEditingController(
      text: _formatThreshold(widget.initial.maximumSizeBytes, 1024 * 1024),
    );
    _minimumDurationController = TextEditingController(
      text: _formatThreshold(widget.initial.minimumDurationMs, 60 * 1000),
    );
    _maximumDurationController = TextEditingController(
      text: _formatThreshold(widget.initial.maximumDurationMs, 60 * 1000),
    );
    if (widget.initial.modifiedFrom != null ||
        widget.initial.modifiedThrough != null) {
      final start =
          widget.initial.modifiedFrom ?? widget.initial.modifiedThrough!;
      final end = widget.initial.modifiedThrough ?? start;
      _modifiedRange = DateTimeRange(start: start, end: end);
    }
  }

  @override
  void dispose() {
    _minimumSizeController.dispose();
    _maximumSizeController.dispose();
    _minimumDurationController.dispose();
    _maximumDurationController.dispose();
    super.dispose();
  }

  Future<void> _pickModifiedRange() async {
    final today = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1970),
      lastDate: DateTime(today.year + 1, 12, 31),
      initialDateRange: _modifiedRange,
      helpText: 'Choose modified dates',
    );
    if (selected != null && mounted) {
      setState(() => _modifiedRange = selected);
    }
  }

  String? _validatePair(
    String? value,
    TextEditingController minimum,
    TextEditingController maximum,
    String unit,
  ) {
    final text = value?.trim() ?? '';
    final parsed = text.isEmpty ? null : double.tryParse(text);
    if (text.isNotEmpty && (parsed == null || !parsed.isFinite || parsed < 0)) {
      return 'Enter a valid $unit value';
    }
    final minimumValue = double.tryParse(minimum.text.trim());
    final maximumValue = double.tryParse(maximum.text.trim());
    if (minimumValue != null &&
        maximumValue != null &&
        minimumValue > maximumValue) {
      return 'Minimum must not exceed maximum';
    }
    return null;
  }

  int? _threshold(TextEditingController controller, int multiplier) {
    final value = double.tryParse(controller.text.trim());
    return value == null ? null : (value * multiplier).round();
  }

  void _apply() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      LibraryTrackFilters(
        modifiedFrom: _modifiedRange?.start,
        modifiedThrough: _modifiedRange?.end,
        minimumSizeBytes: _threshold(_minimumSizeController, 1024 * 1024),
        maximumSizeBytes: _threshold(_maximumSizeController, 1024 * 1024),
        minimumDurationMs: _threshold(_minimumDurationController, 60 * 1000),
        maximumDurationMs: _threshold(_maximumDurationController, 60 * 1000),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'More filters',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Text(
                'Date modified',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _modifiedRange == null
                          ? 'Any date'
                          : '${_formatFilterDate(_modifiedRange!.start)} – ${_formatFilterDate(_modifiedRange!.end)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: _pickModifiedRange,
                    child: Text(_modifiedRange == null ? 'Choose' : 'Change'),
                  ),
                  if (_modifiedRange != null)
                    IconButton(
                      tooltip: 'Clear date range',
                      onPressed: () => setState(() => _modifiedRange = null),
                      icon: const Icon(Icons.close_rounded),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'File size (MB)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('minimum-file-size'),
                      controller: _minimumSizeController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Minimum',
                        suffixText: 'MB',
                      ),
                      validator: (value) => _validatePair(
                        value,
                        _minimumSizeController,
                        _maximumSizeController,
                        'size',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('maximum-file-size'),
                      controller: _maximumSizeController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Maximum',
                        suffixText: 'MB',
                      ),
                      validator: (value) => _validatePair(
                        value,
                        _minimumSizeController,
                        _maximumSizeController,
                        'size',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Duration (minutes)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('minimum-track-duration'),
                      controller: _minimumDurationController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Minimum',
                        suffixText: 'min',
                      ),
                      validator: (value) => _validatePair(
                        value,
                        _minimumDurationController,
                        _maximumDurationController,
                        'duration',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('maximum-track-duration'),
                      controller: _maximumDurationController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Maximum',
                        suffixText: 'min',
                      ),
                      validator: (value) => _validatePair(
                        value,
                        _minimumDurationController,
                        _maximumDurationController,
                        'duration',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pop(const LibraryTrackFilters()),
                    child: const Text('Reset'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _apply,
                    child: const Text('Apply filters'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

String? _formatThreshold(int? value, int divisor) {
  if (value == null) return null;
  return (value / divisor)
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'\.?0+$'), '');
}

String _formatFilterDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class _AlbumTrackList extends StatelessWidget {
  const _AlbumTrackList({
    required this.tracks,
    required this.currentTrackId,
    required this.onPlay,
    required this.onQueue,
    required this.onRemove,
    required this.onToggleFavorite,
    required this.isFavorite,
  });

  final List<ImportedTrack> tracks;
  final String? currentTrackId;
  final ValueChanged<ImportedTrack> onPlay;
  final ValueChanged<ImportedTrack> onQueue;
  final ValueChanged<ImportedTrack> onRemove;
  final ValueChanged<ImportedTrack> onToggleFavorite;
  final bool Function(ImportedTrack) isFavorite;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final track = tracks[index];
            final isPlaying = track.id == currentTrackId;
            final number = track.trackNumber ?? index + 1;
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 0),
              minLeadingWidth: 28,
              leading: SizedBox(
                width: 28,
                child: Center(
                  child: isPlaying
                      ? Icon(
                          Icons.equalizer_rounded,
                          color: colors.primary,
                          size: 20,
                        )
                      : Text(
                          number.toString().padLeft(2, '0'),
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
              ),
              title: Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                '${displayArtistName(track.artist)} · ${_formatAlbumDuration(track.durationMs)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
              ),
              onTap: () => onPlay(track),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Add to queue',
                    onPressed: () => onQueue(track),
                    icon: const Icon(Icons.queue_music_rounded),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Song options',
                    onSelected: (value) {
                      if (value == 'favorite') onToggleFavorite(track);
                      if (value == 'remove') onRemove(track);
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'favorite',
                        child: Text(
                          isFavorite(track)
                              ? 'Remove from favorites'
                              : 'Add to favorites',
                        ),
                      ),
                      PopupMenuItem(
                        value: 'remove',
                        child: Text(
                          track.isDeviceMedia
                              ? 'Delete original file'
                              : 'Delete imported copy',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
          childCount: tracks.length,
          addAutomaticKeepAlives: false,
        ),
      ),
    );
  }
}

String _formatAlbumDuration(int? durationMs) {
  if (durationMs == null || durationMs <= 0) return '--:--';
  final totalSeconds = durationMs ~/ 1000;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.isAvailable});

  final bool isAvailable;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 38),
      child: Column(
        children: [
          Icon(
            Icons.queue_music_rounded,
            size: 54,
            color: colors.primary.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 18),
          Text(
            'Your library starts with you.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Scan your device to find your music in one go. Melo plays those originals in place, without copying them.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          if (!isAvailable) ...[
            const SizedBox(height: 18),
            Text(
              'Music import is available in the installed app.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrackList extends StatelessWidget {
  const _TrackList({
    required this.tracks,
    required this.onPlay,
    required this.onQueue,
    required this.onRemove,
    required this.onToggleFavorite,
    required this.isFavorite,
    this.selectedIds,
    this.onToggleSelection,
  });

  final List<ImportedTrack> tracks;
  final ValueChanged<ImportedTrack> onPlay;
  final ValueChanged<ImportedTrack> onQueue;
  final ValueChanged<ImportedTrack> onRemove;
  final ValueChanged<ImportedTrack> onToggleFavorite;
  final bool Function(ImportedTrack) isFavorite;
  final Set<String>? selectedIds;
  final ValueChanged<ImportedTrack>? onToggleSelection;

  @override
  Widget build(BuildContext context) => SliverPadding(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
    sliver: SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final track = tracks[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 2),
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onToggleSelection != null)
                  SizedBox(
                    width: 40,
                    child: Checkbox(
                      value: selectedIds?.contains(track.id) ?? false,
                      onChanged: (_) => onToggleSelection!(track),
                    ),
                  ),
                AlbumArtwork(
                  size: 52,
                  title: track.title,
                  artworkUri: track.artworkUri == null
                      ? null
                      : Uri.tryParse(track.artworkUri!),
                  sourceUri: Uri.tryParse(track.path),
                  borderRadius: 12,
                ),
              ],
            ),
            title: Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              track.album == 'Unknown album'
                  ? displayArtistName(track.artist)
                  : '${displayArtistName(track.artist)} · ${track.album}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => onPlay(track),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onToggleSelection == null)
                  IconButton(
                    tooltip: 'Add to queue',
                    onPressed: () => onQueue(track),
                    icon: const Icon(Icons.queue_music_rounded),
                  ),
                PopupMenuButton<String>(
                  tooltip: 'Song options',
                  onSelected: (value) {
                    if (value == 'favorite') onToggleFavorite(track);
                    if (value == 'remove') onRemove(track);
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'favorite',
                      child: Text(
                        isFavorite(track)
                            ? 'Remove from favorites'
                            : 'Add to favorites',
                      ),
                    ),
                    PopupMenuItem(
                      value: 'remove',
                      child: Text(
                        track.isDeviceMedia
                            ? 'Delete original file'
                            : 'Delete imported copy',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        childCount: tracks.length,
        addAutomaticKeepAlives: false,
      ),
    ),
  );
}

class _LibraryGroup {
  const _LibraryGroup({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.artworkTrack,
  });

  final String key;
  final String title;
  final String subtitle;
  final ImportedTrack artworkTrack;
}

class _GroupList extends StatelessWidget {
  const _GroupList({required this.groups, required this.onSelect});

  final List<_LibraryGroup> groups;
  final ValueChanged<_LibraryGroup> onSelect;

  @override
  Widget build(BuildContext context) {
    final columns = MediaQuery.sizeOf(context).width >= 640 ? 3 : 2;
    final colors = Theme.of(context).colorScheme;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 14,
          childAspectRatio: 0.78,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final group = groups[index];
            final artwork = group.artworkTrack;
            final radius = BorderRadius.circular(ToneRadii.lg);
            return Material(
              color: Colors.transparent,
              borderRadius: radius,
              clipBehavior: Clip.antiAlias,
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colors.surfaceContainerHigh,
                      colors.surfaceContainerLow,
                    ],
                  ),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.1),
                  ),
                ),
                child: InkWell(
                  onTap: () => onSelect(group),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) => AlbumArtwork(
                              size: constraints.maxWidth,
                              title: artwork.title,
                              artworkUri: artwork.artworkUri == null
                                  ? null
                                  : Uri.tryParse(artwork.artworkUri!),
                              sourceUri: Uri.tryParse(artwork.path),
                              borderRadius: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          group.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          group.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
          childCount: groups.length,
          addAutomaticKeepAlives: false,
        ),
      ),
    );
  }
}

class _PlaylistList extends StatelessWidget {
  const _PlaylistList({
    required this.playlists,
    required this.library,
    required this.tracksFor,
    required this.trackCount,
    required this.onSelect,
    required this.onPlay,
    required this.onRename,
    required this.onDelete,
  });

  final List<MusicPlaylist> playlists;
  final MusicLibrary? library;
  final List<ImportedTrack> Function(MusicPlaylist) tracksFor;
  final int Function(MusicPlaylist) trackCount;
  final ValueChanged<MusicPlaylist> onSelect;
  final ValueChanged<MusicPlaylist> onPlay;
  final ValueChanged<MusicPlaylist> onRename;
  final ValueChanged<MusicPlaylist> onDelete;

  @override
  Widget build(BuildContext context) => SliverPadding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
    sliver: SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 20,
        crossAxisSpacing: 16,
        childAspectRatio: 0.74,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final playlist = playlists[index];
          final playlistTracks = tracksFor(playlist);
          final count = trackCount(playlist);
          final themeIndex = playlist.coverStyle != null ? int.tryParse(playlist.coverStyle!) : null;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onSelect(playlist),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Apple Music Square Artwork
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        PlaylistArtwork(
                          playlistName: playlist.name,
                          tracks: playlistTracks,
                          library: library,
                          size: 180,
                          borderRadius: 14,
                          customArtworkUri: playlist.customArtworkUri,
                          themeIndex: themeIndex,
                        ),
                        if (count > 0)
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: Material(
                              color: ToneColors.cherry,
                              shape: const CircleBorder(),
                              elevation: 4,
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => onPlay(playlist),
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Title & Count
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          playlist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.more_vert_rounded, size: 18, color: Colors.white54),
                        tooltip: 'Playlist options',
                        onSelected: (value) {
                          if (value == 'rename') onRename(playlist);
                          if (value == 'delete') onDelete(playlist);
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'rename', child: Text('Rename')),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete playlist', style: TextStyle(color: Colors.redAccent)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Text(
                    '$count ${count == 1 ? 'song' : 'songs'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.55),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        childCount: playlists.length,
        addAutomaticKeepAlives: false,
      ),
    ),
  );
}

class _PlaylistTrackList extends StatelessWidget {
  const _PlaylistTrackList({
    required this.tracks,
    required this.onPlay,
    required this.onQueue,
    required this.onRemove,
    required this.onReorder,
  });

  final List<ImportedTrack> tracks;
  final ValueChanged<ImportedTrack> onPlay;
  final ValueChanged<ImportedTrack> onQueue;
  final ValueChanged<ImportedTrack> onRemove;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) => SliverPadding(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
    sliver: SliverReorderableList(
      itemCount: tracks.length,
      onReorderItem: onReorder,
      itemBuilder: (context, index) {
        final track = tracks[index];
        return ListTile(
          key: ValueKey(track.id),
          contentPadding: EdgeInsets.zero,
          leading: ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_handle_rounded),
          ),
          title: Text(
            track.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${displayArtistName(track.artist)} · ${track.album}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => onPlay(track),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Add to queue',
                onPressed: () => onQueue(track),
                icon: const Icon(Icons.queue_music_rounded),
              ),
              IconButton(
                tooltip: 'Remove from playlist',
                onPressed: () => onRemove(track),
                icon: const Icon(Icons.remove_circle_outline_rounded),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _NotAvailableFilter extends StatelessWidget {
  const _NotAvailableFilter({required this.filter});

  final String filter;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 54),
    child: Text(
      filter == 'Favorites'
          ? 'Your favorite songs will appear here.'
          : '$filter will appear here as your library grows.',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyLarge,
    ),
  );
}

class _NoopListenable implements Listenable {
  const _NoopListenable._();

  static const instance = _NoopListenable._();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

class _PlaylistNameDialog extends StatefulWidget {
  const _PlaylistNameDialog({required this.title, required this.initialName});

  final String title;
  final String initialName;

  @override
  State<_PlaylistNameDialog> createState() => _PlaylistNameDialogState();
}

class _PlaylistNameDialogState extends State<_PlaylistNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLength: 48,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(hintText: 'Playlist name'),
      onSubmitted: (value) => Navigator.of(context).pop(value),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(_controller.text),
        child: const Text('Save'),
      ),
    ],
  );
}
