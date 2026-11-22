part of 'mini_player.dart';

class NowPlayingMoreSheet extends StatelessWidget {
  const NowPlayingMoreSheet({
    required this.item,
    required this.audioHandler,
    this.musicLibrary,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onOpenSongInfo,
    required this.onStartRadio,
    required this.onOpenArtist,
    required this.onUpgradeQuality,
    required this.onSaveToDevice,
    required this.onOpenLyrics,
    this.onFindLyricsOnline,
    this.onOpenQueue,
    this.lyricsOffsetMs = 0,
    this.onLyricsOffsetChanged,
    super.key,
  });

  final MediaItem item;
  final AudioHandler audioHandler;
  final MusicLibrary? musicLibrary;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onOpenSongInfo;
  final VoidCallback onStartRadio;
  final VoidCallback onOpenArtist;
  final VoidCallback onUpgradeQuality;
  final VoidCallback onSaveToDevice;
  final VoidCallback onOpenLyrics;
  final VoidCallback? onFindLyricsOnline;
  final VoidCallback? onOpenQueue;
  final int lyricsOffsetMs;
  final ValueChanged<int>? onLyricsOffsetChanged;

  @override
  Widget build(BuildContext context) {
    final artistTitle = displayArtistName(item.artist);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xE61F1A24),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top drag handle
              Center(
                child: Container(
                  width: 38,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Top 3 Quick-Action Buttons (Like, Dislike, Share)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _TopActionButton(
                    icon: isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    iconColor: isFavorite ? MeloColors.cherry : Colors.white,
                    label: isFavorite ? 'Liked' : 'Like',
                    onTap: () {
                      Navigator.of(context).pop();
                      onToggleFavorite();
                    },
                  ),
                  _TopActionButton(
                    icon: Icons.heart_broken_outlined,
                    label: 'Dislike',
                    onTap: () {
                      Navigator.of(context).pop();
                      final library = musicLibrary;
                      if (library != null) {
                        final libraryId = item.extras?['libraryId'] as String? ??
                            library
                                .findMatchingLocalTrack(
                                  title: item.title,
                                  artist: item.artist,
                                  path: item.id,
                                )
                                ?.id;
                        if (libraryId != null) {
                          unawaited(library.setMixExcluded(libraryId, true));
                        }
                      }
                      audioHandler.skipToNext();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Skipped and excluded from mixes'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  _TopActionButton(
                    icon: Icons.ios_share_rounded,
                    label: 'Share',
                    onTap: () {
                      Navigator.of(context).pop();
                      final text = '${item.title} - $artistTitle on Melo';
                      Clipboard.setData(ClipboardData(text: text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Copied "$text" to clipboard'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _sheetDivider(),

              // Group 1: Playlist
              _MoreOptionTile(
                icon: Icons.playlist_add_rounded,
                title: 'Add to playlist',
                onTap: () {
                  final hostContext = Navigator.of(context).context;
                  Navigator.of(context).pop();
                  showManagePlaylistsSheet(
                    hostContext,
                    item: item,
                    musicLibrary: musicLibrary,
                  );
                },
              ),
              _sheetDivider(),

              // Group 2: Playback & Queue
              _MoreOptionTile(
                icon: Icons.sensors_rounded,
                title: 'Start radio',
                subtitle: 'Start artist radio',
                onTap: () {
                  Navigator.of(context).pop();
                  onStartRadio();
                },
              ),

              _MoreOptionTile(
                icon: Icons.lyrics_rounded,
                title: 'Read lyrics',
                onTap: () {
                  Navigator.of(context).pop();
                  onOpenLyrics();
                },
              ),
              if (onFindLyricsOnline != null)
                _MoreOptionTile(
                  icon: Icons.search_rounded,
                  title: 'Find lyrics online',
                  onTap: () {
                    Navigator.of(context).pop();
                    onFindLyricsOnline!();
                  },
                ),
              _MoreOptionTile(
                icon: Icons.arrow_circle_down_outlined,
                title: 'Download',
                onTap: () {
                  Navigator.of(context).pop();
                  onSaveToDevice();
                },
              ),
              _MoreOptionTile(
                icon: Icons.delete_outline_rounded,
                title: 'Remove from cache',
                onTap: () {
                  Navigator.of(context).pop();
                  _artworkCache.remove(item.artUri);
                  _resolvedArtworkBytes.remove(item.artUri);
                  final sourceUri = Uri.tryParse(item.id);
                  if (sourceUri != null) {
                    _artworkCache.remove(sourceUri);
                    _resolvedArtworkBytes.remove(sourceUri);
                  }
                  _paletteCache.remove(item.artUri);
                  _audioQualityCache.remove(item.id);
                  _audioTagsCache.remove(item.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Cleared local cache for this song'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              _sheetDivider(),

              // Group 3: Navigation & Metadata
              _MoreOptionTile(
                icon: Icons.mic_none_rounded,
                title: 'Open artist',
                subtitle: artistTitle,
                onTap: () {
                  Navigator.of(context).pop();
                  onOpenArtist();
                },
              ),
              _MoreOptionTile(
                icon: Icons.info_outline_rounded,
                title: 'Song Info',
                subtitle: 'Track details',
                onTap: () {
                  Navigator.of(context).pop();
                  onOpenSongInfo();
                },
              ),
              _sheetDivider(),

              // Group 4: Tools
              _MoreOptionTile(
                icon: Icons.bedtime_outlined,
                title: 'Sleep timer',
                subtitle: SleepTimerService.instance.isActive
                    ? '${SleepTimerService.instance.compactRemainingLabel} remaining'
                    : 'Auto-pause with gentle fade-out',
                onTap: () {
                  final hostContext = Navigator.of(context).context;
                  Navigator.of(context).pop();
                  unawaited(
                    SleepTimerService.showSleepTimerDialog(
                      hostContext,
                      audioHandler,
                    ),
                  );
                },
              ),
              _MoreOptionTile(
                icon: Icons.tune_rounded,
                title: 'Lyrics offset',
                onTap: () {
                  Navigator.of(context).pop();
                  _showLyricsOffsetDialog(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLyricsOffsetDialog(BuildContext context) {
    var offset = lyricsOffsetMs;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E151A),
          title: const Text('Lyrics Sync Offset', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${offset > 0 ? '+' : ''}${offset}ms',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: MeloColors.cherry,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    onPressed: () {
                      setDialogState(() => offset -= 250);
                      onLyricsOffsetChanged?.call(offset);
                    },
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  const SizedBox(width: 16),
                  IconButton.filledTonal(
                    onPressed: () {
                      setDialogState(() => offset = 0);
                      onLyricsOffsetChanged?.call(0);
                    },
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                  const SizedBox(width: 16),
                  IconButton.filledTonal(
                    onPressed: () {
                      setDialogState(() => offset += 250);
                      onLyricsOffsetChanged?.call(offset);
                    },
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetDivider() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Divider(
          color: Colors.white.withValues(alpha: 0.08),
          height: 1,
          thickness: 1,
        ),
      );
}

class _TopActionButton extends StatelessWidget {
  const _TopActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
              child: Icon(icon, color: iconColor ?? Colors.white, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreOptionTile extends StatelessWidget {
  const _MoreOptionTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Stateful dialog so [_controller] outlives the route pop and IME animations.
class _NewPlaylistDialog extends StatefulWidget {
  const _NewPlaylistDialog();

  @override
  State<_NewPlaylistDialog> createState() => _NewPlaylistDialogState();
}

class _NewPlaylistDialogState extends State<_NewPlaylistDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      backgroundColor: const Color(0xFF141416),
      title: const Text(
        'New Playlist',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        style: const TextStyle(color: Colors.white),
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText: 'Playlist name',
          hintStyle: const TextStyle(color: Colors.white38),
          filled: true,
          fillColor: Colors.black,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            FocusScope.of(context).unfocus();
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: MeloColors.cherry,
            foregroundColor: Colors.white,
          ),
          onPressed: _submit,
          child: const Text('Create'),
        ),
      ],
    );
  }
}

void showManagePlaylistsSheet(
  BuildContext context, {
  required MediaItem item,
  required MusicLibrary? musicLibrary,
}) {
  if (musicLibrary == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Library unavailable in preview'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _ManagePlaylistsSheet(
      rootContext: context,
      item: item,
      library: musicLibrary,
    ),
  );
}

class _ManagePlaylistsSheet extends StatefulWidget {
  const _ManagePlaylistsSheet({
    required this.rootContext,
    required this.item,
    required this.library,
  });

  final BuildContext rootContext;
  final MediaItem item;
  final MusicLibrary library;

  @override
  State<_ManagePlaylistsSheet> createState() => _ManagePlaylistsSheetState();
}

class _ManagePlaylistsSheetState extends State<_ManagePlaylistsSheet> {
  String? _busyPlaylistId;
  bool _togglingLiked = false;

  String? _matchedPlaylistTrackId(MusicPlaylist playlist) {
    final idsToCheck = <String>{
      widget.item.id,
      if (widget.item.extras?['libraryId'] is String)
        widget.item.extras!['libraryId'] as String,
      if (widget.item.extras?['localPath'] is String)
        widget.item.extras!['localPath'] as String,
    };
    final localMatch = widget.library.findMatchingLocalTrack(
      providerTrackId: widget.item.extras?['providerTrackId'] as String?,
      title: widget.item.title,
      artist: widget.item.artist,
      path: widget.item.id,
    );
    if (localMatch != null) idsToCheck.add(localMatch.id);
    for (final candidate in idsToCheck) {
      if (playlist.trackIds.contains(candidate)) return candidate;
    }
    return null;
  }

  Future<void> _toggleLiked() async {
    if (_togglingLiked) return;
    setState(() => _togglingLiked = true);
    try {
      await widget.library.toggleFavoriteMediaItem(widget.item);
      unawaited(HapticFeedback.selectionClick());
    } finally {
      if (mounted) setState(() => _togglingLiked = false);
    }
  }

  Future<void> _togglePlaylist(MusicPlaylist playlist) async {
    if (_busyPlaylistId != null) return;
    setState(() => _busyPlaylistId = playlist.id);
    try {
      final existingTrackId = _matchedPlaylistTrackId(playlist);
      if (existingTrackId != null) {
        await widget.library.removeTrackFromPlaylist(
          playlist.id,
          existingTrackId,
        );
      } else {
        final trackId = await widget.library.ensureMediaItemRegistered(
          widget.item,
        );
        await widget.library.addTracksToPlaylist(playlist.id, [trackId]);
      }
      unawaited(HapticFeedback.selectionClick());
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not update playlist: $error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busyPlaylistId = null);
    }
  }

  Future<void> _createPlaylistWithTrack() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _NewPlaylistDialog(),
    );
    if (name == null || name.isEmpty || !mounted) return;
    try {
      final trackId = await widget.library.ensureMediaItemRegistered(
        widget.item,
      );
      final created = await widget.library.createPlaylist(name);
      if (widget.item.artUri != null) {
        await widget.library.updatePlaylistCover(
          created.id,
          customArtworkUri: widget.item.artUri.toString(),
        );
      }
      await widget.library.addTracksToPlaylist(created.id, [trackId]);
      unawaited(HapticFeedback.mediumImpact());
      if (widget.rootContext.mounted) {
        ScaffoldMessenger.of(widget.rootContext).showSnackBar(
          SnackBar(
            content: Text('Created "${created.name}" with "${widget.item.title}"'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not create playlist: $error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: const Color(0xF2171217),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: widget.library,
          builder: (context, _) {
            final isLiked = widget.library.isFavoriteMediaItem(widget.item);
            final playlists = widget.library.playlists;
            return Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      AlbumArtwork(
                        size: 44,
                        title: widget.item.title,
                        artworkUri: widget.item.artUri,
                        sourceUri: Uri.tryParse(widget.item.id),
                        borderRadius: 10,
                        iconSize: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              displayArtistName(widget.item.artist),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.12),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Material(
                    color: isLiked
                        ? MeloColors.cherry.withValues(alpha: 0.18)
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: _toggleLiked,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                gradient: LinearGradient(
                                  colors: [
                                    MeloColors.cherry,
                                    MeloColors.cherryDeep,
                                  ],
                                ),
                              ),
                              child: Icon(
                                isLiked
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Liked Songs',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    '${widget.library.favoriteTracks.length} saved songs',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.6,
                                      ),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              isLiked
                                  ? Icons.check_circle_rounded
                                  : Icons.add_circle_outline_rounded,
                              color: isLiked
                                  ? MeloColors.cherrySoft
                                  : Colors.white54,
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Material(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: _createPlaylistWithTrack,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: MeloColors.cherry.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: MeloColors.cherry.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                              child: Icon(
                                Icons.add_rounded,
                                color: MeloColors.cherrySoft,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'New Playlist',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (playlists.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          'No custom playlists yet — tap New Playlist above.',
                          style: TextStyle(color: Colors.white60, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: playlists.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final pl = playlists[index];
                          final inPlaylist =
                              _matchedPlaylistTrackId(pl) != null;
                          final isBusy = _busyPlaylistId == pl.id;
                          return Material(
                            color: inPlaylist
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(14),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => _togglePlaylist(pl),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    AlbumArtwork(
                                      size: 38,
                                      title: pl.name,
                                      artworkUri: pl.customArtworkUri != null
                                          ? Uri.tryParse(pl.customArtworkUri!)
                                          : null,
                                      borderRadius: 10,
                                      iconSize: 18,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            pl.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            '${pl.trackIds.length} tracks',
                                            style: TextStyle(
                                              color: Colors.white.withValues(
                                                alpha: 0.56,
                                              ),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isBusy)
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: MeloColors.cherry,
                                        ),
                                      )
                                    else
                                      Icon(
                                        inPlaylist
                                            ? Icons.check_circle_rounded
                                            : Icons.add_circle_outline_rounded,
                                        color: inPlaylist
                                            ? MeloColors.cherrySoft
                                            : Colors.white54,
                                        size: 22,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
