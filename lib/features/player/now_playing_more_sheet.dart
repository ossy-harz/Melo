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
                    icon: isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
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
                  Navigator.of(context).pop();
                  _showAddToPlaylist(context);
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

  Future<String> _ensureRegisteredTrackId(MusicLibrary library) async {
    final existingId = item.extras?['libraryId'] as String?;
    if (existingId != null &&
        library.tracks.any((t) => t.id == existingId)) {
      return existingId;
    }
    final localMatch = library.findMatchingLocalTrack(
      providerTrackId: item.extras?['providerTrackId'] as String?,
      title: item.title,
      artist: item.artist,
      path: item.id,
    );
    if (localMatch != null) return localMatch.id;

    final isSpotify =
        item.id.startsWith('spotify:') ||
        item.extras?['downloadProvider'] == 'Spotify' ||
        item.extras?['source'] == 'spotify';
    final pId =
        item.extras?['providerTrackId'] as String? ??
        (item.id.startsWith('spotify:')
            ? item.id.substring(8)
            : item.id.startsWith('youtube:')
            ? item.id.substring(8)
            : null);
    final remoteTrack = ImportedTrack(
      id: item.id,
      path: item.id,
      title: item.title,
      artist: item.artist ?? 'Unknown artist',
      album: item.album ?? 'Streaming',
      durationMs: item.duration?.inMilliseconds,
      artworkUri: item.artUri?.toString(),
      sourceProvider: isSpotify ? 'Spotify' : 'youtube',
      providerTrackId: pId,
      isAvailable: true,
      isDeviceMedia: false,
    );
    final registered = await library.registerOrFindRemoteTracks([remoteTrack]);
    return registered.isNotEmpty ? registered.first.id : item.id;
  }

  Future<void> _createPlaylistWithTrack(
    BuildContext rootContext,
    BuildContext sheetContext,
    MusicLibrary library,
  ) async {
    final name = await showDialog<String>(
      context: sheetContext,
      builder: (_) => const _NewPlaylistDialog(),
    );
    if (name == null || name.isEmpty) return;

    final trackId = await _ensureRegisteredTrackId(library);
    final created = await library.createPlaylist(name);
    if (item.artUri != null) {
      await library.updatePlaylistCover(
        created.id,
        customArtworkUri: item.artUri.toString(),
      );
    }
    await library.addTracksToPlaylist(created.id, [trackId]);
    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
    if (rootContext.mounted) {
      ScaffoldMessenger.of(rootContext).showSnackBar(
        SnackBar(
          content: Text('Added "${item.title}" to "${created.name}"'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showAddToPlaylist(BuildContext context) {
    final library = musicLibrary;
    if (library == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Library unavailable in preview')),
      );
      return;
    }
    final playlists = library.playlists;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF141416),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Add to Playlist',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              leading: const CircleAvatar(
                backgroundColor: MeloColors.cherry,
                foregroundColor: Colors.white,
                radius: 18,
                child: Icon(Icons.add_rounded, size: 20),
              ),
              title: const Text(
                'New Playlist',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onTap: () => unawaited(
                _createPlaylistWithTrack(context, sheetContext, library),
              ),
            ),
            if (playlists.isNotEmpty) const SizedBox(height: 6),
            if (playlists.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'No playlists yet — create one above.',
                    style: TextStyle(color: Colors.white60),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    final pl = playlists[index];
                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: const Icon(
                        Icons.playlist_play_rounded,
                        color: MeloColors.cherry,
                      ),
                      title: Text(
                        pl.name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        '${pl.trackIds.length} tracks',
                        style: const TextStyle(color: Colors.white60),
                      ),
                      onTap: () async {
                        final trackId = await _ensureRegisteredTrackId(library);
                        await library.addTracksToPlaylist(pl.id, [trackId]);
                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Added "${item.title}" to ${pl.name}',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
          ],
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
                style: const TextStyle(
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
