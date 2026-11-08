import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:melo_player/app/melo_glass.dart';
import 'package:melo_player/app/melo_theme.dart';
import 'package:melo_player/features/library/music_library.dart';
import 'package:melo_player/features/spotify/spotify_service.dart';
import 'package:melo_player/features/youtube/youtube_audio_service.dart';

class SpotifyImportSheet extends StatefulWidget {
  const SpotifyImportSheet({
    this.library,
    this.audioHandler,
    super.key,
  });

  final MusicLibrary? library;
  final AudioHandler? audioHandler;

  static Future<void> show(
    BuildContext context, {
    MusicLibrary? library,
    AudioHandler? audioHandler,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SpotifyImportSheet(
        library: library,
        audioHandler: audioHandler,
      ),
    );
  }

  @override
  State<SpotifyImportSheet> createState() => _SpotifyImportSheetState();
}

class _SpotifyImportSheetState extends State<SpotifyImportSheet> {
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  SpotifyPlaylistData? _loadedPlaylist;
  bool _isImporting = false;
  bool _isDownloadingPlaylist = false;
  String? _downloadProgressMessage;
  String? _downloadingTrackId;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _fetchPlaylist(String input) async {
    final clean = input.trim();
    if (clean.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _loadedPlaylist = null;
    });

    try {
      final data = await SpotifyService.instance.fetchPlaylist(clean);
      if (!mounted) return;
      setState(() {
        _loadedPlaylist = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load playlist: $e';
      });
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isNotEmpty) {
      _urlController.text = text;
      _fetchPlaylist(text);
    }
  }

  Future<void> _importToLibrary() async {
    final playlist = _loadedPlaylist;
    final musicLibrary = widget.library;
    if (playlist == null || musicLibrary == null) return;

    setState(() => _isImporting = true);
    try {
      final tonePlaylist = await SpotifyService.instance.importPlaylistToTone(
        playlist: playlist,
        library: musicLibrary,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported "${tonePlaylist.name}" (${playlist.tracks.length} tracks) to your Library!',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isImporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import failed: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _playAllTracks() async {
    final playlist = _loadedPlaylist;
    final handler = widget.audioHandler;
    final musicLibrary = widget.library;
    if (playlist == null || handler == null) return;

    try {
      final mediaItems = playlist.tracks.map((t) {
        final localMatch = musicLibrary?.findMatchingLocalTrack(
          providerTrackId: t.id,
          title: t.title,
          artist: t.artist,
        );
        if (localMatch != null) {
          return localMatch.toMediaItem();
        }
        return t.toImportedTrack().toMediaItem();
      }).toList();
      await handler.updateQueue(mediaItems);
      await handler.skipToQueueItem(0);
      await handler.play();

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Streaming "${playlist.title}"'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not play tracks: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _playSingleTrack(SpotifyTrack track) async {
    final handler = widget.audioHandler;
    final musicLibrary = widget.library;
    if (handler == null) return;

    try {
      final localMatch = musicLibrary?.findMatchingLocalTrack(
        providerTrackId: track.id,
        title: track.title,
        artist: track.artist,
      );
      if (localMatch != null) {
        await handler.playMediaItem(localMatch.toMediaItem());
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Playing "${track.title}" from your device'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }

      final imported = track.toImportedTrack();
      await handler.playMediaItem(imported.toMediaItem());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Streaming "${track.title}" — tap Download to save offline'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not stream track: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _downloadSingleTrack(SpotifyTrack track) async {
    final musicLibrary = widget.library;
    if (musicLibrary == null) return;

    if (musicLibrary.isTrackDownloaded(
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
      final query = '${track.title} ${track.artist}';
      final results = await YoutubeAudioService.instance.search(query);
      if (results.isEmpty) {
        throw StateError('No matching track found on audio streaming network');
      }

      await YoutubeAudioService.instance.downloadTrack(
        track: results.first,
        library: musicLibrary,
        onProgress: (_) {},
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved "${track.title}" for offline playback!'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
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

  Future<void> _downloadEntirePlaylistOffline() async {
    final playlist = _loadedPlaylist;
    final musicLibrary = widget.library;
    if (playlist == null || musicLibrary == null) return;

    setState(() {
      _isDownloadingPlaylist = true;
      _downloadProgressMessage = 'Initializing offline download...';
    });

    try {
      final tonePlaylist = await SpotifyService.instance.importPlaylistToTone(
        playlist: playlist,
        library: musicLibrary,
      );

      var downloadedCount = 0;
      var alreadyInLibraryCount = 0;
      for (var i = 0; i < playlist.tracks.length; i++) {
        if (!mounted || !_isDownloadingPlaylist) break;
        final track = playlist.tracks[i];

        if (musicLibrary.isTrackDownloaded(
          providerTrackId: track.id,
          title: track.title,
          artist: track.artist,
        )) {
          alreadyInLibraryCount++;
          continue;
        }

        setState(() {
          _downloadProgressMessage =
              'Downloading ${i + 1}/${playlist.tracks.length}: ${track.title}';
        });

        final query = '${track.title} ${track.artist}';
        final results = await YoutubeAudioService.instance.search(query);
        if (results.isNotEmpty) {
          try {
            await YoutubeAudioService.instance.downloadTrack(
              track: results.first,
              library: musicLibrary,
              onProgress: (_) {},
            );
            downloadedCount++;
          } catch (e) {
            debugPrint('Failed to download track ${track.title}: $e');
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _isDownloadingPlaylist = false;
        _downloadProgressMessage = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Downloaded $downloadedCount new tracks ($alreadyInLibraryCount already in library) into "${tonePlaylist.name}"!',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDownloadingPlaylist = false;
        _downloadProgressMessage = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Playlist download error: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final mediaQuery = MediaQuery.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: mediaQuery.size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 38,
            height: 4.5,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1DB954).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.music_note_rounded,
                    color: Color(0xFF1DB954),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cloud Playlist Import',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Paste any shared playlist, album, or track link',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Paste from clipboard',
                  onPressed: _pasteFromClipboard,
                  icon: const Icon(Icons.paste_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _urlController,
                        onSubmitted: _fetchPlaylist,
                        decoration: InputDecoration(
                          hintText: 'https://open.spotify.com/playlist/...',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: colors.onSurfaceVariant,
                          ),
                          prefixIcon: const Icon(Icons.link_rounded),
                          suffixIcon: _urlController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded),
                                  onPressed: () {
                                    _urlController.clear();
                                    setState(() {
                                      _loadedPlaylist = null;
                                      _errorMessage = null;
                                    });
                                  },
                                )
                              : null,
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(MeloRadii.md),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: _isLoading
                          ? null
                          : () => _fetchPlaylist(_urlController.text),
                      child: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Load'),
                    ),
                  ],
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(MeloRadii.sm),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                    ),
                  ),
                ],
                if (_loadedPlaylist == null && !_isLoading) ...[
                  const SizedBox(height: 24),
                  Text(
                    'FEATURED PLAYLISTS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 146,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: SpotifyService.featuredPlaylists.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final featured = SpotifyService.featuredPlaylists[index];
                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            _urlController.text =
                                'https://open.spotify.com/playlist/${featured.id}';
                            _fetchPlaylist(featured.id);
                          },
                          child: SizedBox(
                            width: 104,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    featured.artworkUrl,
                                    width: 104,
                                    height: 84,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        Container(
                                      width: 104,
                                      height: 84,
                                      color: Colors.white12,
                                      child: const Icon(Icons.album_rounded),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  featured.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  featured.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                if (_loadedPlaylist != null) ...[
                  const SizedBox(height: 20),
                  MeloGlass(
                    borderRadius: MeloRadii.lg,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: _loadedPlaylist!.artworkUrl != null
                                    ? Image.network(
                                        _loadedPlaylist!.artworkUrl!,
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) =>
                                            Container(
                                          width: 80,
                                          height: 80,
                                          color: Colors.white12,
                                          child: const Icon(Icons.album_rounded),
                                        ),
                                      )
                                    : Container(
                                        width: 80,
                                        height: 80,
                                        color: Colors.white12,
                                        child: const Icon(Icons.album_rounded),
                                      ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _loadedPlaylist!.title,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    if (_loadedPlaylist!.description.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        _loadedPlaylist!.description,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colors.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 6),
                                    Text(
                                      '${_loadedPlaylist!.tracks.length} tracks · ${_loadedPlaylist!.totalDurationString}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: MeloColors.cherry,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (_downloadProgressMessage != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _downloadProgressMessage!,
                                      style: const TextStyle(fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => setState(() => _isDownloadingPlaylist = false),
                                    child: const Text('Cancel', style: TextStyle(fontSize: 11)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _isImporting ? null : _importToLibrary,
                                  icon: _isImporting
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.playlist_add_rounded, size: 18),
                                  label: Text(
                                    _isImporting
                                        ? 'Importing…'
                                        : 'Save to Playlists',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.tonalIcon(
                                onPressed: _playAllTracks,
                                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                                label: const Text('Play'),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filledTonal(
                                tooltip: 'Download all tracks offline',
                                onPressed: _isDownloadingPlaylist
                                    ? null
                                    : _downloadEntirePlaylistOffline,
                                icon: const Icon(Icons.download_rounded, size: 18),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'TRACKS (${_loadedPlaylist!.tracks.length})',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < _loadedPlaylist!.tracks.length; i++) ...[
                    Builder(
                      builder: (context) {
                        final track = _loadedPlaylist!.tracks[i];
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
                          leading: Container(
                            width: 28,
                            alignment: Alignment.center,
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          title: Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                track.durationString,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (isDownloaded)
                                const Tooltip(
                                  message: 'Already downloaded in library',
                                  child: Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                                )
                              else if (isDownloading)
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              else
                                IconButton(
                                  tooltip: 'Download offline',
                                  icon: const Icon(Icons.download_rounded, size: 18),
                                  onPressed: () => _downloadSingleTrack(track),
                                ),
                            ],
                          ),
                          onTap: () => _playSingleTrack(track),
                        );
                      },
                    ),
                    const Divider(height: 1, thickness: 0.5),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
