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
    final albumTitle = item.album?.trim().isNotEmpty == true
        ? item.album!.trim()
        : 'Single';
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
                      audioHandler.skipToNext();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Skipped and marked disliked'),
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

              // Group 1: Quality & Playlist
              _MoreOptionTile(
                icon: Icons.auto_awesome_rounded,
                title: 'Upgrade quality',
                onTap: () {
                  Navigator.of(context).pop();
                  onUpgradeQuality();
                },
              ),
              _MoreOptionTile(
                icon: Icons.videocam_outlined,
                title: 'Convert to video',
                onTap: () {
                  Navigator.of(context).pop();
                  final q = '${item.title} $artistTitle';
                  AppUpdateService.openExternalUrl(
                    'https://www.youtube.com/results?search_query=${Uri.encodeComponent(q)}',
                  );
                },
              ),
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
                icon: Icons.playlist_play_rounded,
                title: 'Play next',
                onTap: () {
                  Navigator.of(context).pop();
                  audioHandler.addQueueItem(item);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Playing "${item.title}" next in queue'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              _MoreOptionTile(
                icon: Icons.queue_music_rounded,
                title: 'Up next',
                subtitle: 'Open queue',
                onTap: () {
                  Navigator.of(context).pop();
                  onOpenQueue?.call();
                },
              ),
              _MoreOptionTile(
                icon: Icons.playlist_add_rounded,
                title: 'Add to queue',
                onTap: () {
                  Navigator.of(context).pop();
                  audioHandler.addQueueItem(item);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Added "${item.title}" to queue'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
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
                icon: Icons.album_outlined,
                title: 'Open album',
                subtitle: albumTitle,
                onTap: () {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Album: $albumTitle'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
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
                onTap: () {
                  Navigator.of(context).pop();
                  SleepTimerService.showSleepTimerDialog(context, audioHandler);
                },
              ),
              _MoreOptionTile(
                icon: Icons.graphic_eq_rounded,
                title: 'Automix overview',
                onTap: () {
                  Navigator.of(context).pop();
                  onOpenSongInfo();
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
              _MoreOptionTile(
                icon: Icons.bug_report_outlined,
                title: 'Copy log',
                onTap: () {
                  Navigator.of(context).pop();
                  final log = StringBuffer()
                    ..writeln('Tone Track Diagnostics:')
                    ..writeln('Title: ${item.title}')
                    ..writeln('Artist: ${item.artist}')
                    ..writeln('Album: ${item.album}')
                    ..writeln('Duration: ${item.duration?.inSeconds}s')
                    ..writeln('ID: ${item.id}')
                    ..writeln('Queue Length: ${audioHandler.queue.value.length}')
                    ..writeln('State: ${audioHandler.playbackState.value.processingState}');
                  Clipboard.setData(ClipboardData(text: log.toString()));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Diagnostic log copied to clipboard'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
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
          color: Color(0xFF1E151A),
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
            const SizedBox(height: 12),
            if (playlists.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('No playlists created yet. Create one in Library.'),
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
                      leading: const Icon(Icons.playlist_play_rounded, color: MeloColors.cherry),
                      title: Text(pl.name, style: const TextStyle(color: Colors.white)),
                      subtitle: Text('${pl.trackIds.length} tracks', style: const TextStyle(color: Colors.white60)),
                      onTap: () async {
                        Navigator.of(sheetContext).pop();
                        await library.addTracksToPlaylist(pl.id, [item.id]);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Added "${item.title}" to ${pl.name}'),
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
