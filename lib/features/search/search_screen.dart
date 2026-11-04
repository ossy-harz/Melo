import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:tone_player/features/downloads/jamendo_screen.dart';
import 'package:tone_player/features/library/imported_track.dart';
import 'package:tone_player/features/library/music_library.dart';
import 'package:tone_player/features/player/mini_player.dart';

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

  void _onQueryChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 180), () {
      if (mounted) setState(() {});
    });
  }

  Future<void> _playTrack(int index) async {
    final library = widget.library;
    final handler = widget.audioHandler;
    if (library == null || handler == null) return;
    final track = library.searchTracks(_controller.text)[index];
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

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.library ?? _NoopListenable.instance,
      builder: (context, _) => CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            sliver: SliverList.list(
              children: [
                Text(
                  'Find your next favorite.',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.search,
                  onChanged: _onQueryChanged,
                  decoration: InputDecoration(
                    hintText: 'Songs, albums, artists',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchDebounce?.cancel();
                        _controller.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.download_for_offline_outlined),
                    title: const Text('Licensed downloads'),
                    subtitle: const Text(
                      'Browse artist-approved music from Jamendo',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => JamendoScreen(library: widget.library),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                if (_controller.text.trim().isNotEmpty)
                  _SearchResults(
                    library: widget.library,
                    query: _controller.text,
                    onPlay: _playTrack,
                  )
                else ...[
                  Text(
                    'Search your music',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.library?.isEmpty == false
                        ? 'Search stays on this device. Choose a song to start listening.'
                        : 'Scan your device from Your library to find your music here.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.library,
    required this.query,
    required this.onPlay,
  });

  final MusicLibrary? library;
  final String query;
  final ValueChanged<int> onPlay;

  @override
  Widget build(BuildContext context) {
    final results = library?.searchTracks(query) ?? const [];
    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Text(
          'No matching songs found.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${results.length} ${results.length == 1 ? 'result' : 'results'}',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        for (
          var index = 0;
          index < (results.length > 100 ? 100 : results.length);
          index++
        )
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: AlbumArtwork(
              size: 48,
              title: results[index].title,
              artworkUri: results[index].artworkUri == null
                  ? null
                  : Uri.tryParse(results[index].artworkUri!),
              sourceUri: Uri.tryParse(results[index].path),
              borderRadius: 10,
            ),
            title: Text(
              results[index].title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              results[index].album == 'Unknown album'
                  ? displayArtistName(results[index].artist)
                  : '${displayArtistName(results[index].artist)} · ${results[index].album}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.play_arrow_rounded),
            onTap: () => onPlay(index),
          ),
        if (results.length > 100)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Showing the first 100 results. Refine your search to see more.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

class _NoopListenable implements Listenable {
  const _NoopListenable._();

  static const instance = _NoopListenable._();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}
