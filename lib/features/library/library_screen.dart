import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:tone_player/features/library/imported_track.dart';
import 'package:tone_player/features/library/music_library.dart';
import 'package:tone_player/features/library/music_playlist.dart';
import 'package:tone_player/features/player/mini_player.dart';

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
  static const _filters = [
    'Songs',
    'Albums',
    'Artists',
    'Favorites',
    'Playlists',
  ];
  String _selectedFilter = _filters.first;
  _LibraryGroup? _selectedGroup;
  String? _selectedPlaylistId;

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
    } on Object catch (error) {
      if (!mounted) return;
      _showMessage('Could not scan device music: $error');
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
      if (!mounted || count == 0) return;
      _showMessage(
        count == 1 ? 'Added 1 song to your library.' : 'Added $count songs.',
      );
    } on Object catch (error) {
      if (!mounted) return;
      _showMessage('Could not add music: $error');
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
        title: const Text('Remove this song from Tone?'),
        content: Text(
          track.isDeviceMedia
              ? 'The song will be removed from Tone, but the original file will stay on your device.'
              : 'Tone will delete its imported copy. Your original file will not be changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
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
      await library.removeTrack(track);
    } on Object catch (error) {
      if (!mounted) return;
      _showMessage('Could not remove this song: $error');
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
        final visibleTracks = _selectedFilter == 'Favorites'
            ? library?.favoriteTracks ?? const <ImportedTrack>[]
            : tracks;
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
                        Text(
                          'Your library',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.8,
                              ),
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
                          FilledButton.icon(
                            onPressed: _createPlaylist,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Create playlist'),
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
                                    });
                                  }
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (showEmpty)
                          _EmptyLibrary(isAvailable: library != null)
                        else if (_selectedFilter == 'Playlists' &&
                            selectedPlaylist == null &&
                            playlists.isEmpty)
                          const _NotAvailableFilter(filter: 'Playlists')
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
                trackCount: (playlist) =>
                    library.tracksForPlaylist(playlist.id).length,
                onSelect: (playlist) =>
                    setState(() => _selectedPlaylistId = playlist.id),
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
                  tracks: selectedTracks,
                  currentTrackId:
                      mediaSnapshot.data?.extras?['libraryId'] as String?,
                  onPlay: (track) =>
                      _playAlbum(selectedTracks, startTrackId: track.id),
                  onRemove: _removeTrack,
                  onToggleFavorite: _toggleFavorite,
                  isFavorite: (track) => library.isFavorite(track.id),
                ),
              )
            else if (!showEmpty && canBrowseTracks)
              _TrackList(
                tracks: _selectedGroup != null ? selectedTracks : visibleTracks,
                onPlay: _playTrack,
                onRemove: _removeTrack,
                onToggleFavorite: _toggleFavorite,
                isFavorite: (track) => library.isFavorite(track.id),
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
            : Material(color: Colors.white, child: page);
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
                      color: const Color(0xFF89919A),
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    group.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFF171A20),
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    displayArtistName(artwork.artist),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: const Color(0xFF737C86)),
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
                  backgroundColor: const Color(0xFF171A20),
                  foregroundColor: Colors.white,
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
                  foregroundColor: const Color(0xFF171A20),
                  backgroundColor: const Color(0xFFF2F3F4),
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

class _AlbumTrackList extends StatelessWidget {
  const _AlbumTrackList({
    required this.tracks,
    required this.currentTrackId,
    required this.onPlay,
    required this.onRemove,
    required this.onToggleFavorite,
    required this.isFavorite,
  });

  final List<ImportedTrack> tracks;
  final String? currentTrackId;
  final ValueChanged<ImportedTrack> onPlay;
  final ValueChanged<ImportedTrack> onRemove;
  final ValueChanged<ImportedTrack> onToggleFavorite;
  final bool Function(ImportedTrack) isFavorite;

  @override
  Widget build(BuildContext context) => SliverPadding(
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
                    ? const Icon(
                        Icons.equalizer_rounded,
                        color: Color(0xFF171A20),
                        size: 20,
                      )
                    : Text(
                        number.toString().padLeft(2, '0'),
                        style: const TextStyle(
                          color: Color(0xFF171A20),
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
              style: const TextStyle(
                color: Color(0xFF171A20),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              '${displayArtistName(track.artist)} · ${_formatAlbumDuration(track.durationMs)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF747D87), fontSize: 11),
            ),
            onTap: () => onPlay(track),
            trailing: PopupMenuButton<String>(
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
                        ? 'Remove from Tone'
                        : 'Remove imported copy',
                  ),
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
            'Scan your device to find your music in one go. Tone plays those originals in place, without copying them.',
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
    required this.onRemove,
    required this.onToggleFavorite,
    required this.isFavorite,
  });

  final List<ImportedTrack> tracks;
  final ValueChanged<ImportedTrack> onPlay;
  final ValueChanged<ImportedTrack> onRemove;
  final ValueChanged<ImportedTrack> onToggleFavorite;
  final bool Function(ImportedTrack) isFavorite;

  @override
  Widget build(BuildContext context) => SliverPadding(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
    sliver: SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final track = tracks[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 2),
            leading: AlbumArtwork(
              size: 52,
              title: track.title,
              artworkUri: track.artworkUri == null
                  ? null
                  : Uri.tryParse(track.artworkUri!),
              sourceUri: Uri.tryParse(track.path),
              borderRadius: 12,
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
            trailing: PopupMenuButton<String>(
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
                        ? 'Remove from Tone'
                        : 'Remove imported copy',
                  ),
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
            return Material(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
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
    required this.trackCount,
    required this.onSelect,
    required this.onPlay,
    required this.onRename,
    required this.onDelete,
  });

  final List<MusicPlaylist> playlists;
  final int Function(MusicPlaylist) trackCount;
  final ValueChanged<MusicPlaylist> onSelect;
  final ValueChanged<MusicPlaylist> onPlay;
  final ValueChanged<MusicPlaylist> onRename;
  final ValueChanged<MusicPlaylist> onDelete;

  @override
  Widget build(BuildContext context) => SliverPadding(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
    sliver: SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final playlist = playlists[index];
          final count = trackCount(playlist);
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 2),
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              child: Icon(
                Icons.queue_music_rounded,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
            title: Text(
              playlist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text('$count ${count == 1 ? 'song' : 'songs'}'),
            onTap: () => onSelect(playlist),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Play ${playlist.name}',
                  onPressed: count == 0 ? null : () => onPlay(playlist),
                  icon: const Icon(Icons.play_arrow_rounded),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Playlist options',
                  onSelected: (value) {
                    if (value == 'rename') onRename(playlist);
                    if (value == 'delete') onDelete(playlist);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'rename', child: Text('Rename')),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete playlist'),
                    ),
                  ],
                ),
              ],
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
    required this.onRemove,
    required this.onReorder,
  });

  final List<ImportedTrack> tracks;
  final ValueChanged<ImportedTrack> onPlay;
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
          trailing: IconButton(
            tooltip: 'Remove from playlist',
            onPressed: () => onRemove(track),
            icon: const Icon(Icons.remove_circle_outline_rounded),
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
