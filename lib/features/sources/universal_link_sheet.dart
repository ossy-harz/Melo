import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:melo_player/app/melo_theme.dart';
import 'package:melo_player/features/library/music_library.dart';
import 'package:melo_player/features/sources/lossless_audio_service.dart';

class UniversalLinkSheet extends StatefulWidget {
  const UniversalLinkSheet({
    super.key,
    required this.library,
    this.audioHandler,
  });

  final MusicLibrary? library;
  final AudioHandler? audioHandler;

  static void show(BuildContext context, {MusicLibrary? library, AudioHandler? audioHandler}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UniversalLinkSheet(
        library: library,
        audioHandler: audioHandler,
      ),
    );
  }

  @override
  State<UniversalLinkSheet> createState() => _UniversalLinkSheetState();
}

class _UniversalLinkSheetState extends State<UniversalLinkSheet> {
  final _urlController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  UniversalPlaylistResult? _loadedResult;
  LosslessAudioQuality _selectedQuality = LosslessAudioQuality.flacHiRes;

  String? _downloadingTrackId;
  bool _isDownloadingAll = false;
  String? _batchProgressMessage;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _resolveLink() async {
    final input = _urlController.text.trim();
    if (input.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _loadedResult = null;
    });

    try {
      final res = await LosslessAudioService.instance.resolveMusicLink(input);
      if (!mounted) return;
      setState(() {
        _loadedResult = res;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '').replaceFirst('FormatException: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadSingle(UniversalMusicTrack track) async {
    final lib = widget.library;
    if (lib == null) return;

    if (lib.isTrackDownloaded(
      providerTrackId: track.id,
      title: track.title,
      artist: track.artist,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${track.title}" is already in your local library.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _downloadingTrackId = track.id);

    try {
      await LosslessAudioService.instance.downloadTrackInQuality(
        track: track,
        library: lib,
        quality: _selectedQuality,
        onProgress: (_) {},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloaded "${track.title}" (${_selectedQuality.name.toUpperCase()}) offline!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _downloadingTrackId = null);
    }
  }

  Future<void> _downloadAll() async {
    final res = _loadedResult;
    final lib = widget.library;
    if (res == null || lib == null) return;

    setState(() {
      _isDownloadingAll = true;
      _batchProgressMessage = 'Starting download...';
    });

    try {
      await LosslessAudioService.instance.downloadFullPlaylist(
        playlist: res,
        library: lib,
        quality: _selectedQuality,
        onProgress: (current, total, title) {
          if (mounted) {
            setState(() {
              _batchProgressMessage = '[$current/$total] $title';
            });
          }
        },
        onComplete: (downloaded, skipped) {
          if (!mounted) return;
          setState(() {
            _isDownloadingAll = false;
            _batchProgressMessage = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Complete! Downloaded $downloaded new tracks ($skipped already in library).',
              ),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDownloadingAll = false;
        _batchProgressMessage = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download error: $e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  void _playTrack(UniversalMusicTrack track) {
    final handler = widget.audioHandler;
    if (handler == null) return;

    final mediaItem = MediaItem(
      id: 'youtube:${track.id}',
      title: track.title,
      artist: track.artist,
      album: track.album,
      duration: Duration(milliseconds: track.durationMs),
      artUri: track.artworkUrl != null ? Uri.parse(track.artworkUrl!) : null,
      extras: {
        'providerTrackId': track.id,
        'downloadProvider': track.provider,
        'source': 'youtube',
      },
    );

    handler.playMediaItem(mediaItem);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final mediaQuery = MediaQuery.of(context);

    return Container(
      constraints: BoxConstraints(maxHeight: mediaQuery.size.height * 0.88),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colors.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                const Icon(Icons.link_rounded, color: MeloColors.cherry),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Import & Download Music Links',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      hintText: 'Paste Spotify, YouTube, or Deezer link...',
                      hintStyle: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 13),
                      prefixIcon: const Icon(Icons.music_note_rounded, size: 18),
                      filled: true,
                      fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                    onSubmitted: (_) => _resolveLink(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _isLoading ? null : _resolveLink,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Rip'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text('Quality: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                SegmentedButton<LosslessAudioQuality>(
                  segments: const [
                    ButtonSegment(value: LosslessAudioQuality.flacHiRes, label: Text('FLAC (Lossless)', style: TextStyle(fontSize: 11))),
                    ButtonSegment(value: LosslessAudioQuality.highOpus, label: Text('320k Opus', style: TextStyle(fontSize: 11))),
                    ButtonSegment(value: LosslessAudioQuality.standard, label: Text('160k AAC', style: TextStyle(fontSize: 11))),
                  ],
                  selected: {_selectedQuality},
                  onSelectionChanged: (set) => setState(() => _selectedQuality = set.first),
                ),
              ],
            ),
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ),
          if (_isDownloadingAll && _batchProgressMessage != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MeloColors.cherry.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: MeloColors.cherry)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(_batchProgressMessage!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          const Divider(height: 16),
          Expanded(
            child: _loadedResult == null
                ? Center(
                    child: Text(
                      'Paste any music link above to parse & download lossless audio.',
                      style: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.7), fontSize: 13),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    children: [
                      Row(
                        children: [
                          if (_loadedResult!.artworkUrl != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                _loadedResult!.artworkUrl!,
                                width: 54,
                                height: 54,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Icon(Icons.album_rounded, size: 54),
                              ),
                            ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _loadedResult!.name,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${_loadedResult!.author} · ${_loadedResult!.tracks.length} tracks',
                                  style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: _isDownloadingAll ? null : _downloadAll,
                            icon: const Icon(Icons.download_rounded, size: 16),
                            label: const Text('Download All'),
                            style: FilledButton.styleFrom(
                              backgroundColor: MeloColors.cherry,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      for (var i = 0; i < _loadedResult!.tracks.length; i++) ...[
                        Builder(
                          builder: (context) {
                            final track = _loadedResult!.tracks[i];
                            final isDownloading = _downloadingTrackId == track.id;
                            final isDownloaded = widget.library?.isTrackDownloaded(
                                  providerTrackId: track.id,
                                  title: track.title,
                                  artist: track.artist,
                                ) ??
                                false;

                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Text(
                                '${i + 1}',
                                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                              ),
                              title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (track.durationMs > 0)
                                    Text(track.durationFormatted, style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11)),
                                  const SizedBox(width: 8),
                                  if (isDownloaded)
                                    const Tooltip(
                                      message: 'Already in local library',
                                      child: Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
                                    )
                                  else if (isDownloading)
                                    const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                  else
                                    IconButton(
                                      icon: const Icon(Icons.download_rounded, size: 18),
                                      onPressed: () => _downloadSingle(track),
                                    ),
                                ],
                              ),
                              onTap: () => _playTrack(track),
                            );
                          },
                        ),
                        const Divider(height: 1),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
