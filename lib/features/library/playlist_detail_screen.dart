import 'package:audio_service/audio_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:melo_player/app/melo_theme.dart';
import 'package:melo_player/features/library/imported_track.dart';
import 'package:melo_player/features/library/music_library.dart';
import 'package:melo_player/features/library/music_playlist.dart';
import 'package:melo_player/features/library/song_details_sheet.dart';
import 'package:melo_player/features/player/mini_player.dart';

/// Apple Music-inspired dedicated playlist screen with hero artwork,
/// editorial themes, side-by-side Play & Shuffle pills, and clean track list.
class PlaylistDetailScreen extends StatefulWidget {
  const PlaylistDetailScreen({
    required this.playlist,
    required this.library,
    required this.audioHandler,
    super.key,
  });

  final MusicPlaylist playlist;
  final MusicLibrary library;
  final AudioHandler? audioHandler;

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  late final ScrollController _scrollController;
  bool _showCollapsedTitle = false;
  bool _isReordering = false;
  String _searchFilter = '';

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final show = _scrollController.hasClients && _scrollController.offset > 190;
    if (show != _showCollapsedTitle) {
      setState(() => _showCollapsedTitle = show);
    }
  }

  MusicPlaylist get _currentPlaylist {
    return widget.library.playlists.firstWhere(
      (p) => p.id == widget.playlist.id,
      orElse: () => widget.playlist,
    );
  }

  List<ImportedTrack> get _tracks {
    return widget.library.tracksForPlaylist(_currentPlaylist.id);
  }

  List<ImportedTrack> get _filteredTracks {
    final all = _tracks;
    final q = _searchFilter.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((t) {
      return t.title.toLowerCase().contains(q) ||
          t.artist.toLowerCase().contains(q) ||
          t.album.toLowerCase().contains(q);
    }).toList(growable: false);
  }

  String _formatTotalDuration(List<ImportedTrack> tracks) {
    var totalMs = 0;
    for (final t in tracks) {
      totalMs += t.durationMs ?? 0;
    }
    final duration = Duration(milliseconds: totalMs);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '$hours hr ${minutes > 0 ? '$minutes min' : ''}';
    }
    return '$minutes min';
  }

  Future<void> _playPlaylist({String? startTrackId, bool shuffle = false}) async {
    final handler = widget.audioHandler;
    if (handler == null) return;
    final tracks = _tracks.where((t) => t.isAvailable).toList();
    if (tracks.isEmpty) {
      _showMessage('Add songs to this playlist before playing.');
      return;
    }

    try {
      if (shuffle) {
        final shuffled = [...tracks]..shuffle();
        await widget.library.playMix(handler, shuffled);
      } else {
        await widget.library.playPlaylist(
          handler,
          _currentPlaylist.id,
          startTrackId: startTrackId,
        );
      }
    } catch (e) {
      _showMessage('Could not play playlist: $e');
    }
  }

  Future<void> _queueTrack(ImportedTrack track) async {
    final handler = widget.audioHandler;
    if (handler == null) return;
    try {
      await handler.addQueueItem(track.toMediaItem());
      _showMessage('Added "${track.title}" to queue.');
    } catch (e) {
      _showMessage('Could not queue song: $e');
    }
  }

  Future<void> _removeTrack(ImportedTrack track) async {
    try {
      await widget.library.removeTrackFromPlaylist(_currentPlaylist.id, track.id);
      _showMessage('Removed "${track.title}" from playlist.');
    } catch (e) {
      _showMessage('Could not remove song: $e');
    }
  }

  Future<void> _addSongsDialog() async {
    final library = widget.library;
    final playlist = _currentPlaylist;
    final allTracks = library.tracks;

    if (allTracks.isEmpty) {
      _showMessage('Scan your device first to find songs.');
      return;
    }

    final chosen = <String>{};
    var query = '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final existingIds = playlist.trackIds.toSet();
            final filtered = allTracks.where((t) {
              final q = query.trim().toLowerCase();
              if (q.isEmpty) return true;
              return t.title.toLowerCase().contains(q) ||
                  t.artist.toLowerCase().contains(q);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.82,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Add Songs',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        if (chosen.isNotEmpty)
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: MeloColors.cherry,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            onPressed: () async {
                              Navigator.pop(context);
                              await library.addTracksToPlaylist(playlist.id, chosen);
                              _showMessage('Added ${chosen.length} songs.');
                            },
                            child: Text('Add (${chosen.length})'),
                          )
                        else
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search songs or artists...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.06),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onChanged: (val) => setSheetState(() => query = val),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final track = filtered[index];
                        final alreadyInPlaylist = existingIds.contains(track.id);
                        final isSelected = chosen.contains(track.id);

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 2,
                          ),
                          leading: AlbumArtwork(
                            size: 42,
                            title: track.title,
                            artworkUri: track.artworkUri != null
                                ? Uri.tryParse(track.artworkUri!)
                                : null,
                            sourceUri: Uri.tryParse(track.path),
                            borderRadius: 6,
                          ),
                          title: Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: alreadyInPlaylist
                                  ? Colors.white.withValues(alpha: 0.38)
                                  : Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            alreadyInPlaylist
                                ? 'Already in playlist'
                                : displayArtistName(track.artist),
                            maxLines: 1,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                          ),
                          trailing: alreadyInPlaylist
                              ? const Icon(Icons.check_circle_rounded,
                                  color: Colors.white24, size: 22)
                              : Checkbox(
                                  value: isSelected,
                                  activeColor: MeloColors.cherry,
                                  shape: const CircleBorder(),
                                  onChanged: (checked) {
                                    setSheetState(() {
                                      if (checked == true) {
                                        chosen.add(track.id);
                                      } else {
                                        chosen.remove(track.id);
                                      }
                                    });
                                  },
                                ),
                          onTap: alreadyInPlaylist
                              ? null
                              : () {
                                  setSheetState(() {
                                    if (isSelected) {
                                      chosen.remove(track.id);
                                    } else {
                                      chosen.add(track.id);
                                    }
                                  });
                                },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _changeCoverThemeDialog() async {
    const themeNames = [
      'Velvet Sunset (Melo Cherry)',
      'Midnight Groove (Electric Sky)',
      'Solar Flare (Radiant Amber)',
      'Emerald Wave (Aqua Mint)',
      'Cosmic Neon (Hot Magenta)',
      'Rose Gold (Warm Blush)',
      'Titanium Slate (Charcoal)',
    ];

    const themeColors = [
      Color(0xFFFF2A4F),
      Color(0xFF06B6D4),
      Color(0xFFF59E0B),
      Color(0xFF10B981),
      Color(0xFFF43F5E),
      Color(0xFFFB7185),
      Color(0xFF94A3B8),
    ];

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Customize Playlist Artwork',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose a curated Melo editorial gradient style or pick a photo from your device.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 18),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.white.withValues(alpha: 0.08),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                  ),
                  child: const Icon(Icons.photo_library_rounded, size: 22),
                ),
                title: const Text('Pick Photo from Device',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Set custom album artwork for this playlist',
                    style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    final files = await FilePicker.pickFiles(
                      type: FileType.image,
                      dialogTitle: 'Select Playlist Cover Artwork',
                    );
                    if (files.isNotEmpty && files.first.path != null) {
                      final path = files.first.path!;
                      await widget.library.updatePlaylistCover(
                        _currentPlaylist.id,
                        customArtworkUri: path,
                      );
                      setState(() {});
                      _showMessage('Updated playlist cover.');
                    }
                  } catch (e) {
                    _showMessage('Could not pick image: $e');
                  }
                },
              ),
              const Divider(height: 24),
              Text(
                'Melo Editorial Themes',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 110,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: themeNames.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final color = themeColors[index];
                    return GestureDetector(
                      onTap: () async {
                        Navigator.pop(context);
                        await widget.library.updatePlaylistCover(
                          _currentPlaylist.id,
                          coverStyle: index.toString(),
                          customArtworkUri: null,
                        );
                        setState(() {});
                        _showMessage('Applied ${themeNames[index]}.');
                      },
                      child: Column(
                        children: [
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: LinearGradient(
                                colors: [color, color.withValues(alpha: 0.4), Colors.black],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(Icons.music_note_rounded,
                                  color: Colors.white, size: 24),
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: 72,
                            child: Text(
                              themeNames[index].split(' ').first,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _renamePlaylistDialog() async {
    final playlist = _currentPlaylist;
    final controller = TextEditingController(text: playlist.name);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 48,
          decoration: const InputDecoration(hintText: 'Playlist name'),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != playlist.name) {
      try {
        await widget.library.renamePlaylist(playlist.id, newName);
        setState(() {});
        _showMessage('Renamed playlist to "$newName".');
      } catch (e) {
        _showMessage('Could not rename: $e');
      }
    }
  }

  Future<void> _deletePlaylistDialog() async {
    final playlist = _currentPlaylist;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${playlist.name}"?'),
        content: const Text(
          'This will remove the playlist from Tone. The actual song files on your device will remain untouched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await widget.library.deletePlaylist(playlist.id);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        _showMessage('Could not delete playlist: $e');
      }
    }
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final playlist = _currentPlaylist;
    final tracks = _tracks;
    final filtered = _filteredTracks;
    final themeIndex = playlist.coverStyle != null
        ? int.tryParse(playlist.coverStyle!)
        : null;
    final themeColors = const [
      Color(0xFFFF2A4F),
      Color(0xFF06B6D4),
      Color(0xFFF59E0B),
      Color(0xFF10B981),
      Color(0xFFF43F5E),
      Color(0xFFFB7185),
      Color(0xFF94A3B8),
    ];
    final headerTint = themeIndex != null &&
            themeIndex >= 0 &&
            themeIndex < themeColors.length
        ? themeColors[themeIndex]
        : const Color(0xFF4A6B82);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Apple Music Top Bar
              SliverAppBar(
                pinned: true,
                backgroundColor: _showCollapsedTitle
                    ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.94)
                    : Colors.transparent,
                surfaceTintColor: Colors.transparent,
                leading: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          size: 18, color: Colors.white),
                    ),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Back',
                  ),
                ),
                title: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _showCollapsedTitle ? 1.0 : 0.0,
                  child: Text(
                    playlist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                ),
                actions: [
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                      child: const Icon(Icons.share_rounded,
                          size: 18, color: Colors.white),
                    ),
                    tooltip: 'Share',
                    onPressed: () =>
                        _showMessage('Sharing "${playlist.name}"'),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Playlist Options',
                    icon: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                      child: const Icon(Icons.more_horiz_rounded,
                          size: 18, color: Colors.white),
                    ),
                    onSelected: (val) {
                      if (val == 'add') _addSongsDialog();
                      if (val == 'cover') _changeCoverThemeDialog();
                      if (val == 'reorder') {
                        setState(() => _isReordering = !_isReordering);
                      }
                      if (val == 'rename') _renamePlaylistDialog();
                      if (val == 'delete') _deletePlaylistDialog();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'add',
                        child: Row(
                          children: [
                            Icon(Icons.add_rounded, size: 20),
                            SizedBox(width: 10),
                            Text('Add Songs'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'cover',
                        child: Row(
                          children: [
                            Icon(Icons.palette_rounded, size: 20),
                            SizedBox(width: 10),
                            Text('Change Artwork / Theme'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'reorder',
                        child: Row(
                          children: [
                            Icon(
                              _isReordering
                                  ? Icons.check_rounded
                                  : Icons.reorder_rounded,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Text(_isReordering
                                ? 'Done Reordering'
                                : 'Reorder Songs'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'rename',
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded, size: 20),
                            SizedBox(width: 10),
                            Text('Rename Playlist'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded,
                                color: Colors.redAccent, size: 20),
                            SizedBox(width: 10),
                            Text('Delete Playlist',
                                style: TextStyle(color: Colors.redAccent)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                ],
              ),

              // Spotify & Apple Inspired Ambient Gradient Hero Header (Reference Screenshots 1 & 2)
              SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        headerTint.withValues(alpha: 0.55),
                        headerTint.withValues(alpha: 0.15),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.65, 1.0],
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Centered Big Hero Artwork (Spotify Reference Image 1)
                      Center(
                        child: Container(
                          width: 216,
                          height: 216,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: headerTint.withValues(alpha: 0.45),
                                blurRadius: 28,
                                offset: const Offset(0, 14),
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.6),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: PlaylistArtwork(
                              playlistName: playlist.name,
                              tracks: tracks,
                              library: widget.library,
                              size: 216,
                              borderRadius: 16,
                              customArtworkUri: playlist.customArtworkUri,
                              themeIndex: themeIndex,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Centered Apple Music Playlist Title
                      Center(
                        child: Text(
                          playlist.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.6,
                            color: Colors.white,
                            height: 1.15,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Centered Artists Subtitle
                      Center(
                        child: Builder(
                          builder: (context) {
                            final topArtists = tracks
                                .map((t) => displayArtistName(t.artist))
                                .where((a) => a != 'Unknown artist' && a.isNotEmpty)
                                .toSet()
                                .take(3)
                                .toList();
                            final artistSubtitle = topArtists.isNotEmpty
                                ? 'With ${topArtists.join(', ')}${tracks.length > 3 ? ' and more' : ''}'
                                : '${playlist.name} collection';
                            return Text(
                              artistSubtitle,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.72),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Centered Badge & Metadata
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: MeloColors.cherry.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(MeloRadii.pill),
                              border: Border.all(
                                color: MeloColors.cherry.withValues(alpha: 0.4),
                                width: 0.8,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.stars_rounded, size: 12, color: MeloColors.cherry),
                                SizedBox(width: 4),
                                Text(
                                  'Melo Curated',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${tracks.length} ${tracks.length == 1 ? 'song' : 'songs'}${tracks.isNotEmpty ? ' · ${_formatTotalDuration(tracks)}' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Apple Music Centered Action Row (Screenshot 1)
                      // Centered: [ 🔀 Circular Shuffle ]  [ ▶ White Stadium Play Pill ]  [ + Circular Add ]
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.14),
                            ),
                            child: IconButton(
                              tooltip: 'Shuffle',
                              icon: const Icon(
                                Icons.shuffle_rounded,
                                size: 22,
                                color: Colors.white,
                              ),
                              onPressed: tracks.isEmpty
                                  ? null
                                  : () => _playPlaylist(shuffle: true),
                            ),
                          ),
                          const SizedBox(width: 20),
                          SizedBox(
                            height: 50,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                                shape: const StadiumBorder(),
                                elevation: 0,
                              ),
                              onPressed: tracks.isEmpty ? null : () => _playPlaylist(),
                              icon: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.black,
                                size: 28,
                              ),
                              label: const Text(
                                'Play',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.14),
                            ),
                            child: IconButton(
                              tooltip: 'Add songs',
                              icon: const Icon(
                                Icons.add_rounded,
                                size: 26,
                                color: Colors.white,
                              ),
                              onPressed: _addSongsDialog,
                            ),
                          ),
                        ],
                      ),
                      if (tracks.length >= 6 && !_isReordering) ...[
                        const SizedBox(height: 18),
                        TextField(
                          decoration: InputDecoration(
                            hintText: 'Filter in playlist...',
                            prefixIcon:
                                const Icon(Icons.search_rounded, size: 18),
                            isDense: true,
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.08),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (v) => setState(() => _searchFilter = v),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Empty Playlist State
              if (tracks.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                          child: const Icon(Icons.queue_music_rounded,
                              size: 32, color: Colors.white38),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No Songs in Playlist',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Add your favorite tracks from your device library to start listening.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: MeloColors.cherry,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _addSongsDialog,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add Songs'),
                        ),
                      ],
                    ),
                  ),
                )

              // Reorderable Track List (when editing order)
              else if (_isReordering)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  sliver: SliverReorderableList(
                    itemCount: tracks.length,
                    onReorderItem: (oldIndex, newIndex) async {
                      try {
                        await widget.library.reorderPlaylistTrack(
                          playlist.id,
                          oldIndex,
                          newIndex,
                        );
                        setState(() {});
                      } catch (e) {
                        _showMessage('Could not reorder: $e');
                      }
                    },
                    itemBuilder: (context, index) {
                      final track = tracks[index];
                      return Material(
                        key: ValueKey(track.id),
                        color: Colors.transparent,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          leading: AlbumArtwork(
                            size: 42,
                            title: track.title,
                            artworkUri: track.artworkUri != null
                                ? Uri.tryParse(track.artworkUri!)
                                : null,
                            sourceUri: Uri.tryParse(track.path),
                            borderRadius: 6,
                          ),
                          title: Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            displayArtistName(track.artist),
                            maxLines: 1,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                          ),
                          trailing: ReorderableDragStartListener(
                            index: index,
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.drag_handle_rounded, color: Colors.white54),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                )

              // Apple Music Track List
              else
                StreamBuilder<MediaItem?>(
                  stream: widget.audioHandler?.mediaItem,
                  initialData: widget.audioHandler?.mediaItem.value,
                  builder: (context, mediaSnapshot) {
                    final currentItem = mediaSnapshot.data;
                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final track = filtered[index];
                            final isLossless =
                                track.path.toLowerCase().endsWith('.flac') ||
                                    track.path.toLowerCase().endsWith('.wav');
                            final isPlaying = currentItem != null &&
                                (currentItem.id == track.path ||
                                    currentItem.id == track.id ||
                                    (currentItem.title.trim().toLowerCase() ==
                                            track.title.trim().toLowerCase() &&
                                        currentItem.artist?.trim().toLowerCase() ==
                                            track.artist.trim().toLowerCase()));

                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => _playPlaylist(startTrackId: track.id),
                                onLongPress: () => SongDetailsSheet.show(
                                  context,
                                  track: track,
                                  audioHandler: widget.audioHandler,
                                  library: widget.library,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 7,
                                  ),
                                  child: Row(
                                    children: [
                                      // Apple Music Track Artwork Thumbnail with playing overlay
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: SizedBox(
                                          width: 48,
                                          height: 48,
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              AlbumArtwork(
                                                size: 48,
                                                title: track.title,
                                                artworkUri: track.artworkUri != null
                                                    ? Uri.tryParse(track.artworkUri!)
                                                    : null,
                                                sourceUri: Uri.tryParse(track.path),
                                                borderRadius: 8,
                                              ),
                                              if (isPlaying)
                                                Container(
                                                  color: Colors.black.withValues(alpha: 0.55),
                                                  child: const Center(
                                                    child: Icon(
                                                      Icons.graphic_eq_rounded,
                                                      color: MeloColors.cherry,
                                                      size: 22,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),

                                      // Title & Subtitle
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              track.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 15.5,
                                                fontWeight: isPlaying
                                                    ? FontWeight.w800
                                                    : FontWeight.w600,
                                                color: isPlaying
                                                    ? MeloColors.cherrySoft
                                                    : Colors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Row(
                                              children: [
                                                if (isPlaying) ...[
                                                  const Icon(
                                                    Icons.volume_up_rounded,
                                                    size: 14,
                                                    color: MeloColors.cherrySoft,
                                                  ),
                                                  const SizedBox(width: 4),
                                                ],
                                                if (isLossless) ...[
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                      horizontal: 4.5,
                                                      vertical: 1.5,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(4),
                                                      color: Colors.white
                                                          .withValues(alpha: 0.12),
                                                    ),
                                                    child: const Text(
                                                      'LOSSLESS',
                                                      style: TextStyle(
                                                        fontSize: 8.5,
                                                        fontWeight: FontWeight.w800,
                                                        letterSpacing: 0.3,
                                                        color: Colors.white70,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                ],
                                            if (track.isAvailable) ...[
                                              const Icon(
                                                Icons.check_circle_rounded,
                                                size: 13.5,
                                                color: Color(0xFF1ED760),
                                              ),
                                              const SizedBox(width: 5),
                                            ],
                                            Expanded(
                                              child: Text(
                                                displayArtistName(track.artist),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.white
                                                      .withValues(alpha: 0.55),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Trailing 3-dots popup menu (vertical dots per Apple Music)
                                  PopupMenuButton<String>(
                                    icon: const Icon(
                                      Icons.more_vert_rounded,
                                      color: Colors.white54,
                                      size: 20,
                                    ),
                                    tooltip: 'Track Options',
                                    onSelected: (val) {
                                      if (val == 'play') {
                                        _playPlaylist(startTrackId: track.id);
                                      }
                                      if (val == 'queue') _queueTrack(track);
                                      if (val == 'details') {
                                        SongDetailsSheet.show(
                                          context,
                                          track: track,
                                          audioHandler: widget.audioHandler,
                                          library: widget.library,
                                        );
                                      }
                                      if (val == 'remove') _removeTrack(track);
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'details',
                                        child: Row(
                                          children: [
                                            Icon(Icons.info_outline_rounded,
                                                size: 18),
                                            SizedBox(width: 10),
                                            Text('Song Details & Artwork'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'play',
                                        child: Row(
                                          children: [
                                            Icon(Icons.play_arrow_rounded,
                                                size: 19),
                                            SizedBox(width: 10),
                                            Text('Play Track'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'queue',
                                        child: Row(
                                          children: [
                                            Icon(Icons.queue_music_rounded,
                                                size: 18),
                                            SizedBox(width: 10),
                                            Text('Play Next / Add to Queue'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'remove',
                                        child: Row(
                                          children: [
                                            Icon(
                                                Icons
                                                    .remove_circle_outline_rounded,
                                                color: Colors.redAccent,
                                                size: 18),
                                            SizedBox(width: 10),
                                            Text('Remove from Playlist',
                                                style: TextStyle(
                                                    color: Colors.redAccent)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: filtered.length,
                    ),
                  ),
                );
              },
            ),
            ],
          ),
        ],
      ),
    );
  }
}
