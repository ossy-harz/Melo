import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:melo_player/app/melo_glass.dart';
import 'package:melo_player/app/melo_theme.dart';
import 'package:melo_player/features/library/music_library.dart';
import 'package:melo_player/features/library/music_playlist.dart';
import 'package:melo_player/features/sources/external_feed_service.dart';
import 'package:melo_player/features/spotify/spotify_service.dart';
import 'package:melo_player/features/youtube/youtube_audio_service.dart';
import 'package:melo_player/features/youtube/youtube_auth_service.dart';

class SpotifyImportSheet extends StatefulWidget {
  const SpotifyImportSheet({
    this.library,
    this.audioHandler,
    this.initialUrl,
    this.initialTab = 0,
    super.key,
  });

  final MusicLibrary? library;
  final AudioHandler? audioHandler;
  final String? initialUrl;
  final int initialTab;

  static Future<void> show(
    BuildContext context, {
    MusicLibrary? library,
    AudioHandler? audioHandler,
    String? initialUrl,
    int initialTab = 0,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SpotifyImportSheet(
        library: library,
        audioHandler: audioHandler,
        initialUrl: initialUrl,
        initialTab: initialTab,
      ),
    );
  }

  @override
  State<SpotifyImportSheet> createState() => _SpotifyImportSheetState();
}

class _SpotifyImportSheetState extends State<SpotifyImportSheet> {
  final TextEditingController _urlController = TextEditingController();
  late int _selectedTab;
  bool _isLoading = false;
  String? _errorMessage;
  SpotifyPlaylistData? _loadedPlaylist;
  bool _isImporting = false;
  bool _isDownloadingPlaylist = false;
  String? _downloadProgressMessage;
  String? _downloadingTrackId;

  final Set<String> _importingIds = {};
  final Set<String> _importedIds = {};
  bool _isRefreshingTab = false;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab.clamp(0, 2);
    SpotifyService.instance.authState.addListener(_onAuthStateChanged);
    YoutubeAuthService.instance.authState.addListener(_onAuthStateChanged);

    if (widget.initialUrl != null && widget.initialUrl!.trim().isNotEmpty) {
      _urlController.text = widget.initialUrl!.trim();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fetchPlaylist(widget.initialUrl!.trim());
      });
    } else {
      // Warm up user playlists for YouTube if connected
      if (YoutubeAuthService.instance.isLoggedIn &&
          YoutubeAuthService.instance.userPlaylists.isEmpty) {
        unawaited(YoutubeAuthService.instance.getUserPlaylists());
      }
    }
  }

  @override
  void dispose() {
    SpotifyService.instance.authState.removeListener(_onAuthStateChanged);
    YoutubeAuthService.instance.authState.removeListener(_onAuthStateChanged);
    _urlController.dispose();
    super.dispose();
  }

  void _onAuthStateChanged() {
    if (mounted) setState(() {});
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
      SpotifyPlaylistData? data;

      if (clean == 'LM') {
        final liked = await YoutubeAuthService.instance.getLikedMusic();
        data = SpotifyPlaylistData(
          id: 'LM',
          title: 'YouTube Liked Music',
          description: 'Your liked songs on YouTube Music',
          artworkUrl: liked.isNotEmpty ? liked.first.thumbnailUrl : null,
          owner: YoutubeAuthService.instance.accountName ?? 'YouTube Music',
          tracks: liked
              .map((t) => SpotifyTrack(
                    id: 'youtube:${t.id}',
                    title: t.title,
                    artist: t.author,
                    album: t.album ?? '',
                    durationMs: t.duration.inMilliseconds,
                    artworkUrl: t.thumbnailUrl,
                  ))
              .toList(),
        );
      } else if (clean == 'liked') {
        final liked = SpotifyService.instance.likedTracks.isNotEmpty
            ? SpotifyService.instance.likedTracks
            : SpotifyService.instance.personalFeedTracks;
        data = SpotifyPlaylistData(
          id: 'liked',
          title: 'Spotify Liked Songs',
          description: 'Your liked tracks on Spotify',
          artworkUrl: liked.isNotEmpty ? liked.first.artworkUrl : null,
          owner: SpotifyService.instance.displayName ?? 'Spotify',
          tracks: liked,
        );
      } else if (clean.startsWith('PL') ||
          clean.startsWith('RD') ||
          clean.contains('youtube.com') ||
          clean.contains('youtu.be')) {
        final ytData = await YoutubeAudioService.instance.fetchPlaylist(clean);
        if (ytData == null || ytData.tracks.isEmpty) {
          throw StateError('Could not load YouTube playlist or playlist is private.');
        }
        data = SpotifyPlaylistData(
          id: ytData.id,
          title: ytData.title,
          description: 'Curated by ${ytData.author}',
          artworkUrl: ytData.thumbnailUrl,
          owner: ytData.author,
          tracks: ytData.tracks
              .map((t) => SpotifyTrack(
                    id: 'youtube:${t.id}',
                    title: t.title,
                    artist: t.author,
                    album: t.album ?? '',
                    durationMs: t.duration.inMilliseconds,
                    artworkUrl: t.thumbnailUrl,
                  ))
              .toList(),
        );
      } else {
        // Universal resolver (Spotify, Apple Music, Deezer, SoundCloud)
        final resolved =
            await ExternalFeedService.instance.resolveExternalUrl(clean);
        data = SpotifyPlaylistData(
          id: resolved.id,
          title: resolved.title,
          description: resolved.description ??
              '${resolved.provider} · ${resolved.curator}',
          artworkUrl: resolved.artworkUrl,
          owner: resolved.curator,
          tracks: resolved.tracks
              .map((t) => SpotifyTrack(
                    id: t.providerTrackId ?? t.id,
                    title: t.title,
                    artist: t.artist,
                    album: t.album,
                    durationMs: t.durationMs ?? 180000,
                    artworkUrl: t.artworkUri,
                  ))
              .toList(),
        );
      }

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

  Future<void> _importQuickPlaylist(
    String playlistId, {
    required bool isSpotify,
    String? title,
  }) async {
    final musicLibrary = widget.library;
    if (musicLibrary == null || _importingIds.contains(playlistId)) return;

    setState(() => _importingIds.add(playlistId));
    try {
      if (isSpotify) {
        if (playlistId == 'liked') {
          final tracks = SpotifyService.instance.likedTracks.isNotEmpty
              ? SpotifyService.instance.likedTracks
              : SpotifyService.instance.personalFeedTracks;
          final playlist = SpotifyPlaylistData(
            id: 'liked',
            title: 'Spotify Liked Songs',
            description: 'Synced from your Spotify account',
            tracks: tracks,
            artworkUrl: tracks.isNotEmpty ? tracks.first.artworkUrl : null,
          );
          await SpotifyService.instance.importPlaylistToTone(
            playlist: playlist,
            library: musicLibrary,
            mergeExisting: true,
          );
        } else {
          final data = await SpotifyService.instance.fetchPlaylist(playlistId);
          await SpotifyService.instance.importPlaylistToTone(
            playlist: data,
            library: musicLibrary,
            mergeExisting: true,
          );
        }
      } else {
        if (playlistId == 'LM') {
          final liked = await YoutubeAuthService.instance.getLikedMusic();
          final imported = liked.map((t) => t.toImportedTrack()).toList();
          await musicLibrary.importExternalTracks(imported);
          const pName = 'YouTube Liked Songs';
          final existing = musicLibrary.playlists
              .where((p) => p.name == pName)
              .firstOrNull;
          if (existing != null) {
            await musicLibrary.addTracksToPlaylist(
              existing.id,
              imported.map((t) => t.id).toList(),
            );
          } else {
            final p = await musicLibrary.createPlaylist(pName);
            await musicLibrary.addTracksToPlaylist(
              p.id,
              imported.map((t) => t.id).toList(),
            );
          }
        } else {
          final data =
              await YoutubeAudioService.instance.fetchPlaylist(playlistId);
          if (data != null && data.tracks.isNotEmpty) {
            await YoutubeAudioService.instance.importPlaylistToTone(
              playlist: data,
              library: musicLibrary,
              mergeExisting: true,
            );
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _importedIds.add(playlistId);
        _importingIds.remove(playlistId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported "${title ?? 'Playlist'}" to your Library!',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _importingIds.remove(playlistId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import error: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _importToLibrary() async {
    final playlist = _loadedPlaylist;
    final musicLibrary = widget.library;
    if (playlist == null || musicLibrary == null) return;

    setState(() => _isImporting = true);
    try {
      MusicPlaylist tonePlaylist;
      if (playlist.id.startsWith('youtube:') || playlist.id == 'LM') {
        final ytTracks = playlist.tracks.map((t) => YoutubeTrack(
          id: t.id.replaceAll('youtube:', ''),
          title: t.title,
          author: t.artist,
          album: t.album,
          duration: Duration(milliseconds: t.durationMs),
          thumbnailUrl: t.artworkUrl ?? '',
        )).toList();
        final ytData = YoutubePlaylistData(
          id: playlist.id,
          title: playlist.title,
          author: playlist.owner ?? 'YouTube Music',
          tracks: ytTracks,
          thumbnailUrl: playlist.artworkUrl,
        );
        tonePlaylist = await YoutubeAudioService.instance.importPlaylistToTone(
          playlist: ytData,
          library: musicLibrary,
          mergeExisting: true,
        );
      } else {
        tonePlaylist = await SpotifyService.instance.importPlaylistToTone(
          playlist: playlist,
          library: musicLibrary,
          mergeExisting: true,
        );
      }

      if (!mounted) return;
      setState(() {
        _isImporting = false;
        _importedIds.add(playlist.id);
      });
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
          content: Text('"${track.title}" is already downloaded in your library.'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _downloadingTrackId = track.id);
    try {
      final query = '${track.title} ${track.artist}';
      final results = await YoutubeAudioService.instance.search(query);
      if (results.isEmpty) {
        throw StateError('No audio stream source found for this track.');
      }
      await YoutubeAudioService.instance.downloadTrack(
        track: results.first,
        library: musicLibrary,
        onProgress: (_) {},
      );

      if (!mounted) return;
      setState(() => _downloadingTrackId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloaded "${track.title}" to library!'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _downloadingTrackId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
        maxHeight: mediaQuery.size.height * 0.90,
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
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Row(
              children: [
                if (_loadedPlaylist != null)
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: 'Back to playlists',
                    onPressed: () {
                      setState(() {
                        _loadedPlaylist = null;
                        _errorMessage = null;
                      });
                    },
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: MeloColors.cherry.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.cloud_download_rounded,
                      color: MeloColors.cherry,
                      size: 22,
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _loadedPlaylist != null
                            ? _loadedPlaylist!.title
                            : 'Cloud & Online Playlists',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        _loadedPlaylist != null
                            ? '${_loadedPlaylist!.tracks.length} tracks · Tap Import to save'
                            : 'Pick and sync from your Spotify, YouTube, or direct links',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_loadedPlaylist == null && _selectedTab == 2)
                  IconButton(
                    tooltip: 'Paste link',
                    onPressed: _pasteFromClipboard,
                    icon: const Icon(Icons.paste_rounded),
                  ),
              ],
            ),
          ),

          // SEGMENTED TAB SELECTOR (when not previewing a loaded playlist)
          if (_loadedPlaylist == null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(MeloRadii.lg),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    _buildSegmentTab(
                      index: 0,
                      label: 'Spotify',
                      icon: Icons.graphic_eq_rounded,
                      activeColor: const Color(0xFF1DB954),
                    ),
                    _buildSegmentTab(
                      index: 1,
                      label: 'YouTube',
                      icon: Icons.play_circle_fill_rounded,
                      activeColor: Colors.redAccent,
                    ),
                    _buildSegmentTab(
                      index: 2,
                      label: 'Direct Link',
                      icon: Icons.link_rounded,
                      activeColor: MeloColors.cherry,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          const Divider(height: 1),

          Expanded(
            child: _loadedPlaylist != null
                ? _buildPlaylistDetailView()
                : switch (_selectedTab) {
                    0 => _buildSpotifyTab(),
                    1 => _buildYouTubeTab(),
                    2 => _buildDirectLinkTab(),
                    _ => _buildSpotifyTab(),
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentTab({
    required int index,
    required String label,
    required IconData icon,
    required Color activeColor,
  }) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTab = index;
            _errorMessage = null;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withValues(alpha: 0.22)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(MeloRadii.md),
            border: isSelected
                ? Border.all(color: activeColor.withValues(alpha: 0.4), width: 1)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? activeColor : Colors.white60,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.white60,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpotifyTab() {
    final spotify = SpotifyService.instance;
    final colors = Theme.of(context).colorScheme;

    if (!spotify.isLoggedIn) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          MeloGlass(
            borderRadius: MeloRadii.lg,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.graphic_eq_rounded,
                    size: 40,
                    color: Color(0xFF1DB954),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Connect Your Spotify Account',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Browse, pick, and 1-tap import all your personal Spotify playlists, liked tracks, and personalized mixes directly into Melo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: colors.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () async {
                      final ok = await spotify.launchInAppLogin();
                      if (ok && mounted) {
                        await spotify.refreshPersonalFeed(library: widget.library);
                        setState(() {});
                      }
                    },
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('Sign In to Spotify (1-Tap)'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1DB954),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildFeaturedPlaylistsCarousel(),
        ],
      );
    }

    final playlists = spotify.userPlaylists;
    final likedCount = spotify.likedTracks.isNotEmpty
        ? spotify.likedTracks.length
        : spotify.personalFeedTracks.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        // Account header
        Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF1DB954).withValues(alpha: 0.2),
              backgroundImage: spotify.avatarUrl != null
                  ? NetworkImage(spotify.avatarUrl!)
                  : null,
              child: spotify.avatarUrl == null
                  ? const Icon(Icons.person_rounded, size: 20, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    spotify.displayName ?? 'Spotify User',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  Text(
                    '${playlists.length} playlists · $likedCount liked tracks',
                    style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: _isRefreshingTab
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 20),
              tooltip: 'Refresh Spotify playlists',
              onPressed: _isRefreshingTab
                  ? null
                  : () async {
                      setState(() => _isRefreshingTab = true);
                      await spotify.refreshPersonalFeed(library: widget.library);
                      if (mounted) setState(() => _isRefreshingTab = false);
                    },
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Liked Songs Primary Card
        _buildCloudPlaylistTile(
          id: 'liked',
          title: 'Spotify Liked Songs',
          subtitle: '$likedCount saved tracks · Curated by you',
          thumbnailUrl: spotify.likedTracks.isNotEmpty
              ? spotify.likedTracks.first.artworkUrl
              : 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=600&q=80',
          isSpotify: true,
          isHeartCard: true,
        ),

        const SizedBox(height: 16),
        Text(
          'YOUR SPOTIFY PLAYLISTS (${playlists.length})',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),

        if (playlists.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'No custom playlists found in this Spotify account. Tap Refresh above to rescan or paste any playlist URL.',
              style: TextStyle(fontSize: 12, color: Colors.white60),
            ),
          )
        else
          for (final p in playlists) ...[
            _buildCloudPlaylistTile(
              id: p.id,
              title: p.title,
              subtitle: p.subtitle,
              thumbnailUrl: p.artworkUrl.isNotEmpty ? p.artworkUrl : null,
              isSpotify: true,
            ),
            const SizedBox(height: 10),
          ],

        const SizedBox(height: 24),
        _buildFeaturedPlaylistsCarousel(),
      ],
    );
  }

  Widget _buildYouTubeTab() {
    final auth = YoutubeAuthService.instance;
    final colors = Theme.of(context).colorScheme;

    if (!auth.isLoggedIn) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          MeloGlass(
            borderRadius: MeloRadii.lg,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.play_circle_fill_rounded,
                    size: 40,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Connect Your YouTube Account',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Browse, pick, and 1-tap import all your YouTube Music library playlists, liked songs, and personalized mixes directly into Melo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: colors.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () async {
                      final ok = await auth.launchInAppLogin();
                      if (ok && mounted) {
                        await auth.getUserPlaylists(forceRefresh: true);
                        setState(() {});
                      }
                    },
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('Sign In with Google (1-Tap)'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildFeaturedPlaylistsCarousel(),
        ],
      );
    }

    final ytPlaylists = auth.userPlaylists;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
              backgroundImage: auth.avatarUrl != null
                  ? NetworkImage(auth.avatarUrl!)
                  : null,
              child: auth.avatarUrl == null
                  ? const Icon(Icons.person_rounded, size: 20, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    auth.accountName ?? 'YouTube Music User',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  Text(
                    '${ytPlaylists.length} playlists & mixes',
                    style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: _isRefreshingTab
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 20),
              tooltip: 'Refresh YouTube playlists',
              onPressed: _isRefreshingTab
                  ? null
                  : () async {
                      setState(() => _isRefreshingTab = true);
                      await auth.getUserPlaylists(forceRefresh: true);
                      if (mounted) setState(() => _isRefreshingTab = false);
                    },
            ),
          ],
        ),
        const SizedBox(height: 16),

        Text(
          'YOUR YOUTUBE PLAYLISTS (${ytPlaylists.length})',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),

        if (ytPlaylists.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'No playlists found in your YouTube library yet. Tap Refresh above to query your account or paste a link.',
              style: TextStyle(fontSize: 12, color: Colors.white60),
            ),
          )
        else
          for (final p in ytPlaylists) ...[
            _buildCloudPlaylistTile(
              id: p.id,
              title: p.title,
              subtitle: p.subtitle ?? '${p.trackCount} tracks',
              thumbnailUrl: p.thumbnailUrl,
              isSpotify: false,
              isHeartCard: p.id == 'LM',
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  Widget _buildDirectLinkTab() {
    final colors = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _urlController,
                onSubmitted: _fetchPlaylist,
                decoration: InputDecoration(
                  hintText: 'Spotify, YouTube, Apple Music, or Deezer link...',
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
              onPressed: _isLoading ? null : () => _fetchPlaylist(_urlController.text),
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
        const SizedBox(height: 24),
        _buildFeaturedPlaylistsCarousel(),
      ],
    );
  }

  Widget _buildCloudPlaylistTile({
    required String id,
    required String title,
    required String? subtitle,
    required String? thumbnailUrl,
    required bool isSpotify,
    bool isHeartCard = false,
  }) {
    final isImporting = _importingIds.contains(id);
    final isImported = _importedIds.contains(id);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        _urlController.text = id;
        _fetchPlaylist(id);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isHeartCard
                ? (isSpotify
                    ? const Color(0xFF1DB954).withValues(alpha: 0.3)
                    : Colors.redAccent.withValues(alpha: 0.3))
                : Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: isHeartCard
                  ? Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isSpotify
                              ? [const Color(0xFF1DB954), const Color(0xFF0F6E31)]
                              : [Colors.redAccent, Colors.red.shade900],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    )
                  : (thumbnailUrl != null && thumbnailUrl.isNotEmpty
                      ? Image.network(
                          thumbnailUrl,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 52,
                            height: 52,
                            color: Colors.white12,
                            child: const Icon(Icons.music_note_rounded),
                          ),
                        )
                      : Container(
                          width: 52,
                          height: 52,
                          color: Colors.white12,
                          child: const Icon(Icons.music_note_rounded),
                        )),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle ?? (isSpotify ? 'Spotify' : 'YouTube Music'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isImported)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: MeloColors.cherry.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_rounded, color: MeloColors.cherry, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Imported',
                      style: TextStyle(
                        fontSize: 11,
                        color: MeloColors.cherry,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              )
            else
              FilledButton.tonal(
                onPressed: isImporting
                    ? null
                    : () => _importQuickPlaylist(
                          id,
                          isSpotify: isSpotify,
                          title: title,
                        ),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: isImporting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Import',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedPlaylistsCarousel() {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                          errorBuilder: (_, _, _) => Container(
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
    );
  }

  Widget _buildPlaylistDetailView() {
    final colors = Theme.of(context).colorScheme;
    final playlist = _loadedPlaylist!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
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
                      child: playlist.artworkUrl != null
                          ? Image.network(
                              playlist.artworkUrl!,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
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
                            playlist.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (playlist.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              playlist.description,
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
                            '${playlist.tracks.length} tracks · ${playlist.totalDurationString}',
                            style: const TextStyle(
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                          onPressed: () =>
                              setState(() => _isDownloadingPlaylist = false),
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
                          _isImporting ? 'Importing…' : 'Save to Library',
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
          'TRACKS (${playlist.tracks.length})',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < playlist.tracks.length; i++) ...[
          Builder(
            builder: (context) {
              final track = playlist.tracks[i];
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
                        child: Icon(Icons.check_circle_rounded,
                            color: MeloColors.cherry, size: 20),
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
    );
  }
}
