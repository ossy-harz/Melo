import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:melo_player/app/melo_theme.dart';
import 'package:melo_player/features/library/music_playlist_import.dart';
import 'package:melo_player/features/library/duplicate_track_selection.dart';
import 'package:melo_player/features/library/imported_track.dart';
import 'package:melo_player/features/library/music_library.dart';
import 'package:melo_player/features/library/music_playlist.dart';
import 'package:melo_player/features/library/playlist_detail_screen.dart';
import 'package:melo_player/features/library/library_track_filters.dart';
import 'package:melo_player/features/player/mini_player.dart';
import 'package:melo_player/features/sources/universal_link_sheet.dart';
import 'package:melo_player/features/spotify/spotify_import_sheet.dart';

part 'library_views.dart';

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
                        if (library == null || library.tracks.isEmpty) ...[
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
                          const SizedBox(height: 18),
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
                        ] else ...[
                          // Clean Apple Music / Spotify Style Header (No clutter, pull-to-refresh active)
                          Row(
                            children: [
                              Text(
                                'Library',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -1.0,
                                    ),
                              ),
                              const Spacer(),
                              IconButton(
                                tooltip: 'Create playlist',
                                icon: const Icon(Icons.add_rounded, size: 26),
                                onPressed: _createPlaylist,
                              ),
                              if (widget.onSearch != null)
                                IconButton(
                                  tooltip: 'Search',
                                  onPressed: widget.onSearch,
                                  icon: const Icon(Icons.search_rounded),
                                ),
                              PopupMenuButton<String>(
                                tooltip: 'More options',
                                icon: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                  child: const Icon(Icons.more_horiz_rounded, size: 20),
                                ),
                                onSelected: (val) {
                                  if (val == 'scan') _scanDevice();
                                  if (val == 'folder') _addMusicFolder();
                                  if (val == 'import_files') _addSongs();
                                  if (val == 'import_m3u') _importPlaylist();
                                  if (val == 'import_link') {
                                    SpotifyImportSheet.show(
                                      context,
                                      library: widget.library,
                                      audioHandler: widget.audioHandler,
                                    );
                                  }
                                  if (val == 'rip') {
                                    UniversalLinkSheet.show(
                                      context,
                                      library: widget.library,
                                      audioHandler: widget.audioHandler,
                                    );
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'scan',
                                    child: Row(
                                      children: [
                                        Icon(Icons.refresh_rounded, size: 20),
                                        SizedBox(width: 10),
                                        Text('Scan Device Library'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'folder',
                                    child: Row(
                                      children: [
                                        Icon(Icons.create_new_folder_outlined, size: 20),
                                        SizedBox(width: 10),
                                        Text('Add Music Folder'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'import_files',
                                    child: Row(
                                      children: [
                                        Icon(Icons.file_open_outlined, size: 20),
                                        SizedBox(width: 10),
                                        Text('Import Audio Files'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'import_m3u',
                                    child: Row(
                                      children: [
                                        Icon(Icons.queue_music_rounded, size: 20),
                                        SizedBox(width: 10),
                                        Text('Import M3U Playlist'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'import_link',
                                    child: Row(
                                      children: [
                                        Icon(Icons.playlist_add_rounded, size: 20),
                                        SizedBox(width: 10),
                                        Text('Import Online Playlist'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'rip',
                                    child: Row(
                                      children: [
                                        Icon(Icons.link_rounded, size: 20),
                                        SizedBox(width: 10),
                                        Text('Download Lossless FLAC / Links'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (library.isImporting) ...[
                            const SizedBox(height: 8),
                            const LinearProgressIndicator(color: MeloColors.cherry),
                          ],
                        ],
                        if (library?.musicFolders.isNotEmpty == true) ...[
                          const SizedBox(height: 12),
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
                        const SizedBox(height: 16),
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
                        if (_selectedFilter == 'Playlists' &&
                            selectedPlaylist == null) ...[
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: _createPlaylist,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Create playlist'),
                          ),
                        ],
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
        final refreshablePage = RefreshIndicator(
          color: MeloColors.cherry,
          backgroundColor: colors.surfaceContainerHigh,
          onRefresh: () async {
            if (widget.library != null) {
              await widget.library!.scanDeviceMusic();
            }
          },
          child: page,
        );
        return selectedAlbum == null
            ? refreshablePage
            : Material(color: colors.surface, child: refreshablePage);
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

