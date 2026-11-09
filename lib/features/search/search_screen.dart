import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:melo_player/app/melo_theme.dart';
import 'package:melo_player/features/library/imported_track.dart';
import 'package:melo_player/features/library/music_library.dart';
import 'package:melo_player/features/player/mini_player.dart';
import 'package:melo_player/features/sources/lossless_audio_service.dart';
import 'package:melo_player/features/spotify/spotify_import_sheet.dart';
import 'package:melo_player/features/youtube/youtube_audio_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({this.library, this.audioHandler, super.key});

  final MusicLibrary? library;
  final AudioHandler? audioHandler;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _searchDebounce;
  List<ImportedTrack> _searchResults = const [];
  List<YoutubeTrack> _onlineResults = const [];
  Object? _searchError;
  bool _isSearchLoading = false;
  bool _isOnlineLoading = false;
  int _searchRequest = 0;
  String? _playingOnlineId;
  final Map<String, double> _downloadProgress = {};
  int _selectedCategoryIndex = 0;

  @override
  void initState() {
    super.initState();
    widget.library?.addListener(_onLibraryChanged);
  }

  @override
  void didUpdateWidget(covariant SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.library == widget.library) return;
    oldWidget.library?.removeListener(_onLibraryChanged);
    widget.library?.addListener(_onLibraryChanged);
    _refreshSearchResults(_controller.text);
  }

  void _onQueryChanged(String query) {
    _searchDebounce?.cancel();
    final hasText = query.trim().isNotEmpty;
    setState(() {
      _isSearchLoading = hasText;
      _isOnlineLoading = hasText;
      _searchResults = const [];
      if (!hasText) _onlineResults = const [];
      _searchError = null;
    });
    _searchDebounce = Timer(const Duration(milliseconds: 220), () {
      _refreshSearchResults(query);
    });
  }

  void _onLibraryChanged() {
    if (!mounted) return;
    if (_controller.text.trim().isNotEmpty) {
      _refreshSearchResults(_controller.text, localOnly: true);
    } else {
      setState(() {});
    }
  }

  Future<void> _refreshSearchResults(
    String query, {
    bool localOnly = false,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      if (!mounted) return;
      setState(() {
        _searchResults = const [];
        _onlineResults = const [];
        _searchError = null;
        _isSearchLoading = false;
        _isOnlineLoading = false;
      });
      return;
    }

    final request = ++_searchRequest;
    try {
      final results =
          await widget.library?.searchTracksIndexed(cleanQuery) ??
          const <ImportedTrack>[];
      if (!mounted || request != _searchRequest) return;
      setState(() {
        _searchResults = results;
        _searchError = null;
        _isSearchLoading = false;
      });
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'tone search',
          context: ErrorDescription('while searching the music library'),
        ),
      );
      if (!mounted || request != _searchRequest) return;
      setState(() {
        _searchResults = const [];
        _searchError = error;
        _isSearchLoading = false;
      });
    }

    if (localOnly) return;

    try {
      final online = await YoutubeAudioService.instance.search(cleanQuery);
      if (!mounted || request != _searchRequest) return;
      setState(() {
        _onlineResults = online;
        _isOnlineLoading = false;
      });
    } on Object {
      if (!mounted || request != _searchRequest) return;
      setState(() {
        _onlineResults = const [];
        _isOnlineLoading = false;
      });
    }
  }

  Future<void> _playTrack(int index) async {
    final library = widget.library;
    final handler = widget.audioHandler;
    if (library == null || handler == null) return;
    if (index < 0 || index >= _searchResults.length) return;
    final track = _searchResults[index];
    final libraryIndex = library.indexOfTrack(track.id);
    if (libraryIndex < 0) return;
    try {
      await library.playTrack(handler, libraryIndex);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not play this song: $error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<void> _playOnlineTrack(YoutubeTrack track) async {
    final handler = widget.audioHandler;
    if (handler == null) return;
    setState(() => _playingOnlineId = track.id);
    try {
      final localMatch = widget.library?.findMatchingLocalTrack(
        providerTrackId: track.id,
        title: track.title,
        artist: track.author,
      );
      if (localMatch != null) {
        await handler.playMediaItem(localMatch.toMediaItem());
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Playing "${track.title}" from your device'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        return;
      }

      final item = track.toMediaItem();
      await handler.playMediaItem(item);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Streaming "${track.title}" â tap Download anytime to save to device'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not play "${track.title}": $error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) {
        setState(() => _playingOnlineId = null);
      }
    }
  }

  Future<void> _downloadOnlineTrack(YoutubeTrack track) async {
    final library = widget.library;
    if (library == null) return;
    if (_downloadProgress.containsKey(track.id)) return;
    if (library.isTrackDownloaded(
      providerTrackId: track.id,
      title: track.title,
      artist: track.author,
    )) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('"${track.title}" is already on your device.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }

    final chosenQuality = await LosslessAudioService.instance.selectDownloadQuality(
      context,
      title: track.title,
      artist: track.author,
    );
    if (chosenQuality == null || !mounted) return;

    setState(() => _downloadProgress[track.id] = 0.01);
    try {
      await YoutubeAudioService.instance.downloadTrack(
        track: track,
        library: library,
        qualityOverride: chosenQuality,
        onProgress: (p) {
          if (mounted) {
            setState(() => _downloadProgress[track.id] = p.clamp(0.01, 1.0));
          }
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Saved "${track.title}" (${chosenQuality.shortLabel} + Artwork & Lyrics) to Music/Tone',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not download "${track.title}": $error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) {
        setState(() => _downloadProgress.remove(track.id));
      }
    }
  }

  Future<void> _playAll({required bool shuffle}) async {
    final library = widget.library;
    final handler = widget.audioHandler;
    if (library == null || handler == null) return;
    final results = [..._searchResults];
    if (results.isEmpty) return;
    if (shuffle) results.shuffle();
    try {
      await library.playMix(handler, results);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not start this queue: $error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    widget.library?.removeListener(_onLibraryChanged);
    _controller.dispose();
    super.dispose();
  }

  bool get _isUrlQuery {
    final query = _controller.text.trim().toLowerCase();
    return query.startsWith('http://') ||
        query.startsWith('https://') ||
        query.contains('spotify.com') ||
        query.contains('youtube.com') ||
        query.contains('youtu.be');
  }

  Widget _buildUrlActionCard(BuildContext context) {
    final query = _controller.text.trim();
    final isSpotify = query.toLowerCase().contains('spotify');
    final isYt = query.toLowerCase().contains('youtu');
    final platform = isSpotify ? 'Spotify' : (isYt ? 'YouTube' : 'Web');
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1ED760).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1ED760).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.link_rounded, color: Color(0xFF1ED760), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$platform Link Detected',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Import and stream all tracks from this link directly in Melo:',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1ED760),
                foregroundColor: Colors.black,
              ),
              icon: const Icon(Icons.playlist_add_check_rounded, size: 18),
              label: const Text(
                'Import & Stream Playlist',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              onPressed: () => SpotifyImportSheet.show(
                context,
                library: widget.library,
                audioHandler: widget.audioHandler,
                initialUrl: query,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _controller.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
            sliver: SliverList.list(
              children: [
                StreamBuilder<MediaItem?>(
                  stream: widget.audioHandler?.mediaItem,
                  initialData: widget.audioHandler?.mediaItem.value,
                  builder: (context, snapshot) {
                    final item = snapshot.data;
                    if (item == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: MeloColors.cherry.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: MeloColors.cherry.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.graphic_eq_rounded,
                              size: 18,
                              color: MeloColors.cherry,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'NOW PLAYING: ',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: MeloColors.cherrySoft,
                                letterSpacing: 0.8,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '${item.title} · ${item.artist ?? "Melo Player"}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: _onQueryChanged,
                  onSubmitted: (q) => _refreshSearchResults(q),
                  decoration: InputDecoration(
                    hintText: 'Search songs, artists, or paste playlist link...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _controller.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _searchDebounce?.cancel();
                              _controller.clear();
                              _onQueryChanged('');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
                if (_isUrlQuery)
                  _buildUrlActionCard(context),
                if (hasQuery) ...[
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          label: const Text('All Results'),
                          selected: _selectedCategoryIndex == 0,
                          onSelected: (_) => setState(() => _selectedCategoryIndex = 0),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          avatar: const Icon(Icons.check_circle_rounded, size: 16, color: MeloColors.cherrySoft),
                          label: Text('On Device (${_searchResults.length})'),
                          selected: _selectedCategoryIndex == 1,
                          onSelected: (_) => setState(() => _selectedCategoryIndex = 1),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          avatar: const Icon(Icons.stream_rounded, size: 16),
                          label: Text('Lossless Streams (${_onlineResults.length})'),
                          selected: _selectedCategoryIndex == 2,
                          onSelected: (_) => setState(() => _selectedCategoryIndex = 2),
                        ),
                      ],
                    ),
                  ),
                ],
                if (!hasQuery && !_isUrlQuery) ...[
                  const SizedBox(height: 28),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.travel_explore_rounded,
                          size: 48,
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Search library, stream online, or paste any playlist link',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (hasQuery) ...[
            // Top Result Card (Apple / Spotify hero result)
            if (_selectedCategoryIndex == 0 &&
                !_isSearchLoading &&
                (_searchResults.isNotEmpty || _onlineResults.isNotEmpty)) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                sliver: SliverToBoxAdapter(
                  child: Builder(
                    builder: (context) {
                      if (_searchResults.isNotEmpty) {
                        final topLocal = _searchResults.first;
                        return _TopResultCard(
                          title: topLocal.title,
                          subtitle: '${topLocal.artist} · ${topLocal.album}',
                          artUri: topLocal.artworkUri == null
                              ? null
                              : Uri.tryParse(topLocal.artworkUri!),
                          sourceUri: Uri.tryParse(topLocal.path),
                          isOnDevice: true,
                          onPlay: () => _playTrack(0),
                        );
                      } else {
                        final topOnline = _onlineResults.first;
                        return _TopResultCard(
                          title: topOnline.title,
                          subtitle: '${topOnline.author} · ${topOnline.displaySubtitle}',
                          artUri: topOnline.thumbnailUrl == null
                              ? null
                              : Uri.tryParse(topOnline.thumbnailUrl!),
                          isOnDevice: false,
                          onPlay: () => _playOnlineTrack(topOnline),
                        );
                      }
                    },
                  ),
                ),
              ),
            ],

            // On Device Results
            if ((_selectedCategoryIndex == 0 || _selectedCategoryIndex == 1) &&
                (_searchResults.isNotEmpty || _searchError != null)) ...[
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverToBoxAdapter(
                  child: _SearchResults(
                    results: _searchResults,
                    isLoading: _isSearchLoading,
                    error: _searchError,
                    onPlayAll: () => _playAll(shuffle: false),
                    onShuffle: () => _playAll(shuffle: true),
                  ),
                ),
              ),
              if (!_isSearchLoading &&
                  _searchError == null &&
                  _searchResults.isNotEmpty)
                StreamBuilder<MediaItem?>(
                  stream: widget.audioHandler?.mediaItem,
                  initialData: widget.audioHandler?.mediaItem.value,
                  builder: (context, mediaSnap) {
                    final current = mediaSnap.data;
                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final track = _searchResults[index];
                            final isPlaying = current != null &&
                                (current.id == track.path ||
                                    current.id == track.id ||
                                    (current.title.trim().toLowerCase() ==
                                            track.title.trim().toLowerCase() &&
                                        current.artist?.trim().toLowerCase() ==
                                            track.artist.trim().toLowerCase()));
                            return _SearchResultTile(
                              track: track,
                              isPlaying: isPlaying,
                              onTap: () => _playTrack(index),
                            );
                          },
                          childCount: _searchResults.length > 100
                              ? 100
                              : _searchResults.length,
                        ),
                      ),
                    );
                  },
                ),
            ],

            // Streaming / Lossless Catalog Results
            if ((_selectedCategoryIndex == 0 || _selectedCategoryIndex == 2) &&
                (_isOnlineLoading || _onlineResults.isNotEmpty)) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Text(
                        'Lossless Streams & Catalog',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (_isOnlineLoading)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),
              ),
              if (_onlineResults.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 96),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final track = _onlineResults[index];
                        final isDownloaded =
                            widget.library?.isTrackDownloaded(
                              providerTrackId: track.id,
                              title: track.title,
                              artist: track.author,
                            ) ??
                            false;
                        return _OnlineSearchResultTile(
                          track: track,
                          isPlaying: _playingOnlineId == track.id,
                          isDownloaded: isDownloaded,
                          downloadProgress: _downloadProgress[track.id],
                          onTap: () => _playOnlineTrack(track),
                          onDownload: widget.library == null
                              ? null
                              : () => _downloadOnlineTrack(track),
                        );
                      },
                      childCount: _onlineResults.length,
                    ),
                  ),
                ),
            ],

            if (!_isSearchLoading &&
                !_isOnlineLoading &&
                _searchError == null &&
                _searchResults.isEmpty &&
                _onlineResults.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverToBoxAdapter(
                  child: _SearchResults(
                    results: const [],
                    isLoading: false,
                    error: null,
                    onPlayAll: () {},
                    onShuffle: () {},
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.results,
    required this.isLoading,
    required this.error,
    required this.onPlayAll,
    required this.onShuffle,
  });

  final List<ImportedTrack> results;
  final bool isLoading;
  final Object? error;
  final VoidCallback onPlayAll;
  final VoidCallback onShuffle;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 28),
        child: Text('Could not search your library: $error'),
      );
    }
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 28),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (results.isEmpty) {
      final colors = Theme.of(context).colorScheme;
      return Padding(
        padding: const EdgeInsets.only(top: 28),
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 44,
              color: colors.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 12),
            Text(
              'No matching songs found.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try a different title, artist, or album.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'On this device (${results.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            TextButton.icon(
              onPressed: onShuffle,
              icon: const Icon(Icons.shuffle_rounded, size: 18),
              label: const Text('Shuffle'),
            ),
            FilledButton.tonalIcon(
              onPressed: onPlayAll,
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('Play all'),
            ),
          ],
        ),
      ],
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({
    required this.track,
    required this.onTap,
    this.isPlaying = false,
  });

  final ImportedTrack track;
  final VoidCallback onTap;
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final subtitle = track.album == 'Unknown album'
        ? displayArtistName(track.artist)
        : '${displayArtistName(track.artist)} · ${track.album}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(MeloRadii.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MeloRadii.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    AlbumArtwork(
                      size: 50,
                      title: track.title,
                      artworkUri: track.artworkUri == null
                          ? null
                          : Uri.tryParse(track.artworkUri!),
                      sourceUri: Uri.tryParse(track.path),
                      borderRadius: 12,
                    ),
                    if (isPlaying)
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.equalizer_rounded,
                            color: MeloColors.cherry,
                            size: 24,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isPlaying ? MeloColors.cherrySoft : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Track options',
                  icon: const Icon(Icons.more_vert_rounded, size: 20),
                  onPressed: () => TrackDetailsSheet.show(
                    context,
                    track.toMediaItem(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnlineSearchResultTile extends StatelessWidget {
  const _OnlineSearchResultTile({
    required this.track,
    required this.isPlaying,
    required this.isDownloaded,
    required this.downloadProgress,
    required this.onTap,
    required this.onDownload,
  });

  final YoutubeTrack track;
  final bool isPlaying;
  final bool isDownloaded;
  final double? downloadProgress;
  final VoidCallback onTap;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final metaLine = track.duration > Duration.zero
        ? '${track.displaySubtitle} · ${track.durationString}'
        : track.displaySubtitle;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(MeloRadii.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MeloRadii.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
            child: Row(
              children: [
                AlbumArtwork(
                  size: 50,
                  title: track.title,
                  artworkUri: track.thumbnailUrl == null
                      ? null
                      : Uri.tryParse(track.thumbnailUrl!),
                  borderRadius: 12,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        metaLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isPlaying)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (downloadProgress != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        value: downloadProgress! > 0.05
                            ? downloadProgress
                            : null,
                        strokeWidth: 2.2,
                      ),
                    ),
                  )
                else if (isDownloaded)
                  Tooltip(
                    message: 'Saved on device',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(
                        Icons.download_done_rounded,
                        size: 20,
                        color: colors.primary,
                      ),
                    ),
                  )
                else if (onDownload != null)
                  IconButton(
                    tooltip: 'Save to device',
                    onPressed: onDownload,
                    icon: Icon(
                      Icons.download_for_offline_outlined,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _TopResultCard extends StatelessWidget {
  const _TopResultCard({
    required this.title,
    required this.subtitle,
    this.artUri,
    this.sourceUri,
    required this.isOnDevice,
    required this.onPlay,
  });

  final String title;
  final String subtitle;
  final Uri? artUri;
  final Uri? sourceUri;
  final bool isOnDevice;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'TOP RESULT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: MeloColors.cherry,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isOnDevice
                      ? MeloColors.cherry.withValues(alpha: 0.15)
                      : colors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isOnDevice ? 'ON DEVICE' : 'STREAMING',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isOnDevice ? MeloColors.cherry : colors.primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 58,
                  height: 58,
                  child: AlbumArtwork(
                    size: 58,
                    title: title,
                    artworkUri: artUri,
                    sourceUri: sourceUri,
                    borderRadius: 12,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: MeloColors.cherry,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(12),
                ),
                onPressed: onPlay,
                icon: const Icon(Icons.play_arrow_rounded, size: 26),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
