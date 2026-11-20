import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:melo_player/app/melo_theme.dart';
import 'package:melo_player/features/library/imported_track.dart';
import 'package:melo_player/features/library/music_library.dart';
import 'package:melo_player/features/library/song_details_sheet.dart';
import 'package:melo_player/features/library/song_metadata_enricher.dart';
import 'package:melo_player/features/mix/smart_playlist_service.dart';
import 'package:melo_player/features/player/animated_equalizer_indicator.dart';
import 'package:melo_player/features/player/melo_audio_handler.dart';
import 'package:melo_player/features/player/mini_player.dart';
import 'package:melo_player/features/sources/lossless_audio_service.dart';
import 'package:melo_player/features/spotify/spotify_service.dart';
import 'package:melo_player/features/youtube/youtube_audio_service.dart';

/// Global background playlist download coordinator so playlist downloads keep
/// running even after the user navigates away from the playlist screen.
class PlaylistDownloadManager extends ChangeNotifier {
  PlaylistDownloadManager._();

  static final PlaylistDownloadManager instance = PlaylistDownloadManager._();

  final Set<String> _activePlaylists = {};
  final Map<String, double> _trackProgress = {};
  String? _activeBannerText;

  String? get activeBannerText => _activeBannerText;

  static bool isSpotifyTrackId(String id) => id.startsWith('spotify:');

  static String rawTrackId(String id) {
    if (id.startsWith('spotify:')) return id.substring(8);
    if (id.startsWith('youtube:')) return id.substring(8);
    return id;
  }

  static Future<YoutubeTrack?> resolveDownloadableYoutubeTrack(
    YoutubeTrack track, {
    String? fallbackAlbum,
    String? fallbackArt,
  }) async {
    if (!isSpotifyTrackId(track.id)) return track;
    final results = await YoutubeAudioService.instance.search(
      '${track.title} ${track.author}',
    );
    if (results.isEmpty) return null;
    final first = results.first;
    return YoutubeTrack(
      id: first.id,
      title: track.title,
      author: track.author,
      duration: track.duration > Duration.zero ? track.duration : first.duration,
      album: track.album ?? fallbackAlbum,
      thumbnailUrl: fallbackArt ?? track.thumbnailUrl ?? first.thumbnailUrl,
    );
  }

  bool isPlaylistDownloading(String playlistTitle) =>
      _activePlaylists.contains(playlistTitle.trim().toLowerCase());

  double? progressForTrack(String trackId, String rawId) =>
      _trackProgress[trackId] ??
      _trackProgress[rawId] ??
      _trackProgress['youtube:$rawId'] ??
      _trackProgress['spotify:$rawId'];

  Future<void> ensurePlaylistSaved({
    required String playlistTitle,
    String? coverUrl,
    required List<YoutubeTrack> tracks,
    required MusicLibrary library,
    Map<String, String> enrichedArtworks = const {},
  }) async {
    if (tracks.isEmpty) return;

    var playlist = library.playlists
        .where((p) => p.name.toLowerCase() == playlistTitle.toLowerCase())
        .firstOrNull;
    if (playlist == null) {
      playlist = await library.createPlaylist(playlistTitle);
      final coverArt = coverUrl ??
          tracks
              .map((t) => enrichedArtworks[t.id] ?? t.thumbnailUrl)
              .whereType<String>()
              .firstOrNull;
      if (coverArt != null && coverArt.isNotEmpty) {
        await library.updatePlaylistCover(
          playlist.id,
          customArtworkUri: coverArt,
        );
      }
    }

    final remoteTracks = tracks
        .map((t) {
          final enrichedArt = enrichedArtworks[t.id] ?? t.thumbnailUrl;
          final rawId = rawTrackId(t.id);
          if (isSpotifyTrackId(t.id)) {
            return SpotifyTrack(
              id: rawId,
              title: t.title,
              artist: t.author,
              album: (t.album != null && t.album!.trim().isNotEmpty)
                  ? t.album!.trim()
                  : playlistTitle,
              durationMs: t.duration.inMilliseconds,
              artworkUrl: enrichedArt,
            ).toImportedTrack();
          }
          return YoutubeTrack(
            id: rawId,
            title: t.title,
            author: t.author,
            duration: t.duration,
            album: t.album ?? playlistTitle,
            thumbnailUrl: enrichedArt,
            viewCount: t.viewCount,
          ).toImportedTrack();
        })
        .toList(growable: false);
    final registeredTracks = await library.registerOrFindRemoteTracks(
      remoteTracks,
    );
    await library.addTracksToPlaylist(
      playlist.id,
      registeredTracks.map((t) => t.id),
    );
  }

  Future<int> downloadSingleTrack({
    required YoutubeTrack track,
    required MusicLibrary library,
    LosslessAudioQuality? qualityOverride,
    String? fallbackAlbum,
    String? fallbackArt,
  }) async {
    if (_trackProgress.containsKey(track.id)) return 0;
    _trackProgress[track.id] = 0.04;
    notifyListeners();
    try {
      final downloadable = await resolveDownloadableYoutubeTrack(
        track,
        fallbackAlbum: fallbackAlbum,
        fallbackArt: fallbackArt,
      );
      if (downloadable == null) {
        throw StateError('No downloadable stream found for "${track.title}"');
      }
      await YoutubeAudioService.instance.downloadTrack(
        track: downloadable,
        library: library,
        qualityOverride: qualityOverride,
        onProgress: (p) {
          _trackProgress[track.id] = p;
          notifyListeners();
        },
      );
      return 1;
    } finally {
      _trackProgress.remove(track.id);
      notifyListeners();
    }
  }

  Future<int> downloadPlaylist({
    required String playlistTitle,
    String? coverUrl,
    required List<YoutubeTrack> tracks,
    required MusicLibrary library,
    LosslessAudioQuality? qualityOverride,
    Map<String, String> enrichedArtworks = const {},
    bool ensureSavedInLibrary = true,
  }) async {
    final key = playlistTitle.trim().toLowerCase();
    if (_activePlaylists.contains(key) || tracks.isEmpty) return 0;

    final unDownloaded = tracks.where((t) {
      return !library.isTrackDownloaded(
        providerTrackId: rawTrackId(t.id),
        title: t.title,
        artist: t.author,
      );
    }).toList(growable: false);
    if (unDownloaded.isEmpty) return 0;

    _activePlaylists.add(key);
    _activeBannerText =
        'Downloading "$playlistTitle" (0/${unDownloaded.length})…';
    notifyListeners();

    var savedCount = 0;
    try {
      if (ensureSavedInLibrary) {
        try {
          await ensurePlaylistSaved(
            playlistTitle: playlistTitle,
            coverUrl: coverUrl,
            tracks: tracks,
            library: library,
            enrichedArtworks: enrichedArtworks,
          );
        } catch (_) {}
      }

      for (var i = 0; i < unDownloaded.length; i++) {
        final track = unDownloaded[i];
        _activeBannerText =
            'Downloading "$playlistTitle" (${i + 1}/${unDownloaded.length}): ${track.title}';
        _trackProgress[track.id] = 0.05;
        notifyListeners();
        try {
          final downloadable = await resolveDownloadableYoutubeTrack(
            track,
            fallbackAlbum: playlistTitle,
            fallbackArt: enrichedArtworks[track.id],
          );
          if (downloadable != null) {
            await YoutubeAudioService.instance.downloadTrack(
              track: downloadable,
              library: library,
              qualityOverride: qualityOverride,
              onProgress: (p) {
                _trackProgress[track.id] = p;
                notifyListeners();
              },
            );
            savedCount++;
          }
        } catch (_) {
        } finally {
          _trackProgress.remove(track.id);
          notifyListeners();
        }
      }
    } finally {
      _activePlaylists.remove(key);
      if (_activePlaylists.isEmpty) {
        _activeBannerText = null;
      }
      notifyListeners();
    }
    return savedCount;
  }
}

/// Shared bottom dock displaying active background playlist downloads and
/// the persistent [MiniPlayer] bar across playlist screens and [AppShell].
class PlaylistMiniPlayerDock extends StatelessWidget {
  const PlaylistMiniPlayerDock({
    required this.audioHandler,
    this.musicLibrary,
    this.padding = const EdgeInsets.fromLTRB(12, 0, 12, 8),
    this.onNavigate,
    super.key,
  });

  final AudioHandler? audioHandler;
  final MusicLibrary? musicLibrary;
  final EdgeInsetsGeometry padding;
  final ValueChanged<int>? onNavigate;

  @override
  Widget build(BuildContext context) {
    final handler = audioHandler;
    return AnimatedBuilder(
      animation: PlaylistDownloadManager.instance,
      builder: (context, _) {
        final bannerText = PlaylistDownloadManager.instance.activeBannerText;
        return StreamBuilder<MediaItem?>(
          stream: handler?.mediaItem,
          initialData: handler?.mediaItem.value,
          builder: (context, mediaSnapshot) {
            final hasItem = mediaSnapshot.data != null && handler != null;
            if (bannerText == null && !hasItem) {
              return const SizedBox.shrink();
            }
            return SafeArea(
              top: false,
              child: Padding(
                padding: padding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (bannerText != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141416),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: MeloColors.cherry.withValues(alpha: 0.45),
                            width: 0.9,
                          ),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: MeloColors.cherry,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                bannerText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (hasItem)
                      MiniPlayer(
                        audioHandler: handler,
                        onOpen: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            fullscreenDialog: true,
                            builder: (_) => NowPlayingScreen(
                              audioHandler: handler,
                              musicLibrary: musicLibrary,
                              onNavigate: onNavigate,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class CuratedPlaylistPreset {
  const CuratedPlaylistPreset({
    required this.title,
    required this.curatorSubtitle,
    required this.badge,
    required this.searchQuery,
    required this.gradient,
    required this.icon,
    this.coverUrl,
    this.vibe,
    this.genre = 'All',
    this.isArtistRadio = false,
    this.artistAvatars = const [],
    this.artistName,
    this.spotifyPlaylistId,
    this.initialSpotifyTracks,
    this.initialMediaItems,
    this.allowLongEpisodes = false,
  });

  final String title;
  final String curatorSubtitle;
  final String badge;
  final String searchQuery;
  final List<Color> gradient;
  final IconData icon;
  final String? coverUrl;
  final SmartVibe? vibe;
  final String genre;
  final bool isArtistRadio;
  final List<String> artistAvatars;
  final String? artistName;
  final String? spotifyPlaylistId;
  final List<SpotifyTrack>? initialSpotifyTracks;
  final List<MediaItem>? initialMediaItems;
  final bool allowLongEpisodes;
}

/// Builds a canonical [CuratedPlaylistPreset] for a [SmartVibe] station so
/// Home shelves and background preloading share identical cache keys.
CuratedPlaylistPreset smartVibeStationPreset(SmartVibe vibe) {
  final (title, subtitle, badge, gradient, icon) = switch (vibe) {
    SmartVibe.dailyFlow => (
      'Personal Station',
      'Continuous dynamic stream tailored to your favorites',
      'PERSONAL STATION',
      const [Color(0xFFFA243C), Color(0xFF7A0C1E), Color(0xFF0A0A0C)],
      Icons.graphic_eq_rounded,
    ),
    SmartVibe.highEnergy => (
      'Discovery Station',
      'Endless exploration & fresh music discoveries',
      'DISCOVERY',
      const [Color(0xFF3B0812), Color(0xFFFA243C), Color(0xFF080808)],
      Icons.radar_rounded,
    ),
    SmartVibe.deepFocus => (
      'Deep Focus & Study',
      'Calm instrumental grooves and ambient lofi beats',
      'INSTRUMENTAL',
      const [Color(0xFF1C1C1E), Color(0xFF3A0A14), Color(0xFF000000)],
      Icons.headphones_rounded,
    ),
    SmartVibe.lateNightChill => (
      'Late Night Chill',
      'Mellow acoustic & atmospheric midnight soul',
      'LATE NIGHT',
      const [Color(0xFF4A0915), Color(0xFF140307), Color(0xFF000000)],
      Icons.nightlight_round,
    ),
  };

  return CuratedPlaylistPreset(
    title: title,
    curatorSubtitle: subtitle,
    badge: badge,
    searchQuery: '',
    gradient: gradient,
    icon: icon,
    vibe: vibe,
  );
}

/// Full-screen playlist and radio view matching the hero overlapping artwork,
/// metadata summary, single-row action bar (preview art, Save, Download, Share,
/// Shuffle, and Play FAB), and transparent track list design.
class CuratedPlaylistScreen extends StatefulWidget {
  const CuratedPlaylistScreen({
    required this.preset,
    required this.audioHandler,
    required this.library,
    super.key,
  });

  final CuratedPlaylistPreset preset;
  final AudioHandler? audioHandler;
  final MusicLibrary? library;

  static List<YoutubeTrack>? cachedTracksFor(CuratedPlaylistPreset preset) =>
      _CuratedPlaylistScreenState._cache[_CuratedPlaylistScreenState._cacheKeyFor(
        preset,
      )];

  static Future<List<YoutubeTrack>> preloadPreset(
    CuratedPlaylistPreset preset, {
    MusicLibrary? library,
  }) => _CuratedPlaylistScreenState._preloadPreset(preset, library: library);

  static Future<void> preloadPresets(
    Iterable<CuratedPlaylistPreset> presets, {
    MusicLibrary? library,
    int maxConcurrent = 2,
  }) => _CuratedPlaylistScreenState._preloadPresets(
    presets,
    library: library,
    maxConcurrent: maxConcurrent,
  );

  @override
  State<CuratedPlaylistScreen> createState() => _CuratedPlaylistScreenState();
}

class _CuratedPlaylistScreenState extends State<CuratedPlaylistScreen> {
  static final Map<String, List<YoutubeTrack>> _cache = {};
  static final Map<String, String> _coverCache = {};
  static final Map<String, Future<List<YoutubeTrack>>> _inFlightPreloads = {};

  static String _cacheKeyFor(CuratedPlaylistPreset preset) =>
      '${preset.spotifyPlaylistId ?? ""}|${preset.title}|${preset.searchQuery}';

  List<YoutubeTrack> _tracks = const [];
  bool _loading = true;
  String? _errorMessage;
  String? _resolvedArtistCoverUrl;
  final Map<String, String> _enrichedTrackArtworks = {};
  bool get _isDownloadingAll =>
      PlaylistDownloadManager.instance.isPlaylistDownloading(widget.preset.title);
  bool _shuffleEnabled = false;
  bool _showSearchBar = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchFilter = '';

  @override
  void initState() {
    super.initState();
    widget.library?.addListener(_onLibraryChanged);
    PlaylistDownloadManager.instance.addListener(_onLibraryChanged);
    final cached = _cache[_cacheKey];
    if (cached != null && cached.isNotEmpty) {
      _tracks = cached;
      _resolvedArtistCoverUrl = _coverCache[_cacheKey];
      _loading = false;
    }
    unawaited(_loadTracks());
  }

  @override
  void didUpdateWidget(covariant CuratedPlaylistScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.library != widget.library) {
      oldWidget.library?.removeListener(_onLibraryChanged);
      widget.library?.addListener(_onLibraryChanged);
    }
  }

  @override
  void dispose() {
    widget.library?.removeListener(_onLibraryChanged);
    PlaylistDownloadManager.instance.removeListener(_onLibraryChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onLibraryChanged() {
    if (mounted) setState(() {});
  }

  String get _cacheKey => _cacheKeyFor(widget.preset);

  List<YoutubeTrack> get _filteredTracks {
    if (_searchFilter.isEmpty) return _tracks;
    return _tracks
        .where((t) {
          return t.title.toLowerCase().contains(_searchFilter) ||
              t.author.toLowerCase().contains(_searchFilter);
        })
        .toList(growable: false);
  }

  static bool _isSpotifyTrackId(String id) =>
      PlaylistDownloadManager.isSpotifyTrackId(id);

  static String _rawTrackId(String id) =>
      PlaylistDownloadManager.rawTrackId(id);

  static YoutubeTrack _fromSpotifyTrackStatic(SpotifyTrack t) => YoutubeTrack(
    id: 'spotify:${t.id}',
    title: t.title,
    author: t.artist,
    duration: Duration(milliseconds: t.durationMs),
    thumbnailUrl: t.artworkUrl,
    album: t.album,
  );

  YoutubeTrack _fromSpotifyTrack(SpotifyTrack t) => _fromSpotifyTrackStatic(t);

  static YoutubeTrack _importedTrackToYoutubeTrack(ImportedTrack track) {
    var rawId = track.providerTrackId ?? track.id;
    if (rawId.startsWith('youtube:')) rawId = rawId.substring(8);
    if (rawId.startsWith('spotify:')) rawId = rawId.substring(8);
    final isSpotify = (track.sourceProvider?.toLowerCase() == 'spotify') ||
        track.path.startsWith('spotify:');
    final id = isSpotify ? 'spotify:$rawId' : 'youtube:$rawId';

    return YoutubeTrack(
      id: id,
      title: track.title,
      author: track.artist,
      duration: Duration(milliseconds: track.durationMs ?? 0),
      album: track.album,
      thumbnailUrl: track.artworkUri,
    );
  }

  ImportedTrack _trackToImportedTrack(YoutubeTrack t) {
    final enrichedArt = _enrichedTrackArtworks[t.id] ?? t.thumbnailUrl;
    final rawId = _rawTrackId(t.id);
    if (_isSpotifyTrackId(t.id)) {
      return SpotifyTrack(
        id: rawId,
        title: t.title,
        artist: t.author,
        album: (t.album != null && t.album!.trim().isNotEmpty)
            ? t.album!.trim()
            : widget.preset.title,
        durationMs: t.duration.inMilliseconds,
        artworkUrl: enrichedArt,
      ).toImportedTrack();
    }
    return YoutubeTrack(
      id: rawId,
      title: t.title,
      author: t.author,
      duration: t.duration,
      album: t.album ?? widget.preset.title,
      thumbnailUrl: enrichedArt,
      viewCount: t.viewCount,
    ).toImportedTrack();
  }

  MediaItem _trackToMediaItem(YoutubeTrack t) {
    final enrichedArt = _enrichedTrackArtworks[t.id] ?? t.thumbnailUrl;
    final rawId = _rawTrackId(t.id);
    if (_isSpotifyTrackId(t.id)) {
      return SpotifyTrack(
        id: rawId,
        title: t.title,
        artist: t.author,
        album: (t.album != null && t.album!.trim().isNotEmpty)
            ? t.album!.trim()
            : widget.preset.title,
        durationMs: t.duration.inMilliseconds,
        artworkUrl: enrichedArt,
      ).toImportedTrack().toMediaItem();
    }
    return YoutubeTrack(
      id: rawId,
      title: t.title,
      author: t.author,
      duration: t.duration,
      album: t.album,
      thumbnailUrl: enrichedArt,
      viewCount: t.viewCount,
    ).toMediaItem();
  }

  void _syncSavedPlaylistIfNeeded(List<YoutubeTrack> tracks) {
    final library = widget.library;
    if (library == null || tracks.isEmpty) return;
    final existing = library.playlists
        .where((p) => p.name.toLowerCase() == widget.preset.title.toLowerCase())
        .firstOrNull;
    if (existing != null && existing.trackIds.length < tracks.length) {
      unawaited(_ensurePlaylistSavedSilently(tracksOverride: tracks));
    }
  }

  static List<YoutubeTrack> _filterYoutubeTracksForPreset(
    List<YoutubeTrack> results,
    CuratedPlaylistPreset preset,
  ) {
    final maxSeconds = preset.allowLongEpisodes ? 14400 : 660;
    return results
        .where((t) {
          if (t.duration.inSeconds > maxSeconds) return false;
          if (t.duration.inSeconds > 0 && t.duration.inSeconds < 40) {
            return false;
          }
          if (!preset.allowLongEpisodes &&
              YoutubeAudioService.isMixtapeOrNonstop(t.title, t.duration)) {
            return false;
          }
          return true;
        })
        .take(25)
        .toList(growable: false);
  }

  static List<YoutubeTrack> _mapMediaItemsStatic(
    List<MediaItem> items, {
    required String fallbackArtist,
  }) {
    return items
        .map((m) {
          final isSpotify =
              m.id.startsWith('spotify:') ||
              m.extras?['downloadProvider'] == 'Spotify' ||
              m.extras?['source'] == 'spotify';
          final pId =
              m.extras?['providerTrackId'] as String? ?? _rawTrackId(m.id);
          return YoutubeTrack(
            id: isSpotify ? 'spotify:$pId' : pId,
            title: m.title,
            author: m.artist ?? fallbackArtist,
            duration: m.duration ?? const Duration(minutes: 3, seconds: 20),
            thumbnailUrl: m.artUri?.toString(),
            album: m.album,
          );
        })
        .toList(growable: false);
  }

  static Future<List<YoutubeTrack>> _resolvePresetTracks(
    CuratedPlaylistPreset preset, {
    MusicLibrary? library,
    void Function(String coverUrl)? onCoverResolved,
  }) async {
    final key = _cacheKeyFor(preset);
    var valid = const <YoutubeTrack>[];
    final spotifyId = preset.spotifyPlaylistId?.trim();
    final artistSeed =
        preset.artistName ??
        (preset.isArtistRadio
            ? preset.title
                  .replaceAll(RegExp(r'\s+Radio$', caseSensitive: false), '')
                  .trim()
            : null);

    if (spotifyId != null && spotifyId.isNotEmpty) {
      if (spotifyId == 'liked') {
        final spotifyTracks = SpotifyService.instance.likedTracks.isNotEmpty
            ? SpotifyService.instance.likedTracks
            : SpotifyService.instance.personalFeedTracks;
        valid = spotifyTracks
            .map(_fromSpotifyTrackStatic)
            .toList(growable: false);
      } else {
        try {
          final data = await SpotifyService.instance.fetchPlaylist(spotifyId);
          if (data.artworkUrl != null && data.artworkUrl!.isNotEmpty) {
            _coverCache[key] = data.artworkUrl!;
            onCoverResolved?.call(data.artworkUrl!);
          }
          valid = data.tracks
              .map(_fromSpotifyTrackStatic)
              .toList(growable: false);
        } catch (e) {
          debugPrint('Spotify playlist fetch failed ($spotifyId): $e');
        }
      }
      if (valid.isEmpty) {
        final fallbackQuery = preset.searchQuery.isNotEmpty
            ? preset.searchQuery
            : '${preset.title} official audio';
        final results = await YoutubeAudioService.instance.search(
          fallbackQuery,
          filterMixtapes: true,
        );
        valid = _filterYoutubeTracksForPreset(results, preset);
      }
    } else if (artistSeed != null && artistSeed.isNotEmpty) {
      if (preset.coverUrl == null || preset.coverUrl!.isEmpty) {
        unawaited(
          SongMetadataEnricher.instance.fetchArtistImageUrl(artistSeed).then((
            url,
          ) {
            if (url != null && url.isNotEmpty) {
              _coverCache[key] = url;
              onCoverResolved?.call(url);
            }
          }),
        );
      }
      final radio = await SmartPlaylistService.instance.generateArtistRadio(
        artist: artistSeed,
        library: library,
        artworkUri: preset.coverUrl,
      );
      valid = _mapMediaItemsStatic(radio.tracks, fallbackArtist: artistSeed);
    } else if (preset.vibe != null) {
      final smart = await SmartPlaylistService.instance.generateVibeMix(
        vibe: preset.vibe!,
        library: library,
      );
      valid = _mapMediaItemsStatic(smart.tracks, fallbackArtist: 'Melo');
    } else if (preset.searchQuery.trim().isNotEmpty) {
      final results = await YoutubeAudioService.instance.search(
        preset.searchQuery,
        filterMixtapes: !preset.allowLongEpisodes,
      );
      valid = _filterYoutubeTracksForPreset(results, preset);
    }

    if (valid.isNotEmpty) {
      _cache[key] = valid;
      preloadArtworkUrls([
        _coverCache[key],
        preset.coverUrl,
        ...valid.take(8).map((t) => t.thumbnailUrl),
      ]);
    }
    return valid;
  }

  static Future<List<YoutubeTrack>> _preloadPreset(
    CuratedPlaylistPreset preset, {
    MusicLibrary? library,
  }) async {
    if (preset.initialMediaItems != null &&
        preset.initialMediaItems!.isNotEmpty) {
      return _mapMediaItemsStatic(
        preset.initialMediaItems!,
        fallbackArtist: preset.artistName ?? 'Melo',
      );
    }
    if (preset.initialSpotifyTracks != null &&
        preset.initialSpotifyTracks!.isNotEmpty) {
      return preset.initialSpotifyTracks!
          .map(_fromSpotifyTrackStatic)
          .toList(growable: false);
    }
    final key = _cacheKeyFor(preset);
    final cached = _cache[key];
    if (cached != null && cached.isNotEmpty) return cached;
    final inFlight = _inFlightPreloads[key];
    if (inFlight != null) return inFlight;

    final future = _resolvePresetTracks(preset, library: library)
        .catchError((_) => const <YoutubeTrack>[])
        .whenComplete(() => _inFlightPreloads.remove(key));
    _inFlightPreloads[key] = future;
    return future;
  }

  static Future<void> _preloadPresets(
    Iterable<CuratedPlaylistPreset> presets, {
    MusicLibrary? library,
    int maxConcurrent = 2,
  }) async {
    final queue = presets.toList(growable: false);
    if (queue.isEmpty) return;
    final stride = maxConcurrent.clamp(1, 4);
    for (var i = 0; i < queue.length; i += stride) {
      final batch = queue.skip(i).take(stride);
      await Future.wait(
        batch.map((preset) => _preloadPreset(preset, library: library)),
      );
    }
  }

  Future<void> _loadTracks() async {
    final initialItems = widget.preset.initialMediaItems;
    if (initialItems != null && initialItems.isNotEmpty) {
      final mapped = _mapMediaItemsStatic(
        initialItems,
        fallbackArtist: widget.preset.artistName ?? 'Melo',
      );
      if (mounted) {
        setState(() {
          _tracks = mapped;
          _loading = false;
          _errorMessage = null;
        });
      }
      _syncSavedPlaylistIfNeeded(mapped);
      unawaited(_enrichTrackArtworks(mapped));
      if (mapped.length < 4 &&
          !Platform.environment.containsKey('FLUTTER_TEST') &&
          widget.preset.searchQuery.trim().isNotEmpty) {
        unawaited(_appendRelatedTracksInBackground(mapped));
      }
      return;
    }

    final initialSpotify = widget.preset.initialSpotifyTracks;
    if (initialSpotify != null && initialSpotify.isNotEmpty) {
      final mapped = initialSpotify
          .map(_fromSpotifyTrack)
          .toList(growable: false);
      if (mounted) {
        setState(() {
          _tracks = mapped;
          _loading = false;
          _errorMessage = null;
        });
      }
      _syncSavedPlaylistIfNeeded(mapped);
      unawaited(_enrichTrackArtworks(mapped));
      return;
    }

    final cached = _cache[_cacheKey];
    if (cached != null && cached.isNotEmpty) {
      if (mounted) {
        setState(() {
          _tracks = cached;
          _resolvedArtistCoverUrl ??= _coverCache[_cacheKey];
          _loading = false;
        });
      }
      _syncSavedPlaylistIfNeeded(cached);
      unawaited(_enrichTrackArtworks(cached));
      return;
    }

    try {
      final inFlight = _inFlightPreloads[_cacheKey];
      final valid = inFlight != null
          ? await inFlight
          : await _resolvePresetTracks(
              widget.preset,
              library: widget.library,
              onCoverResolved: (url) {
                if (mounted && url.isNotEmpty) {
                  setState(() => _resolvedArtistCoverUrl = url);
                }
              },
            );

      if (valid.isEmpty) {
        final savedPlaylist = widget.library?.playlists
            .where(
              (p) =>
                  p.name.trim().toLowerCase() ==
                  widget.preset.title.trim().toLowerCase(),
            )
            .firstOrNull;
        if (savedPlaylist != null && widget.library != null) {
          final savedTracks =
              widget.library!.tracksForPlaylist(savedPlaylist.id);
          if (savedTracks.isNotEmpty) {
            final mapped =
                savedTracks.map(_importedTrackToYoutubeTrack).toList(growable: false);
            if (mounted) {
              setState(() {
                _tracks = mapped;
                _loading = false;
                _errorMessage = null;
              });
            }
            _cache[_cacheKey] = mapped;
            return;
          }
        }
      }

      if (mounted) {
        setState(() {
          _tracks = valid;
          _resolvedArtistCoverUrl ??= _coverCache[_cacheKey];
          _loading = false;
          _errorMessage = valid.isEmpty
              ? 'No tracks found for this playlist.'
              : null;
        });
      }
      if (valid.isNotEmpty) {
        _syncSavedPlaylistIfNeeded(valid);
        unawaited(_enrichTrackArtworks(valid));
      }
    } catch (e) {
      final savedPlaylist = widget.library?.playlists
          .where(
            (p) =>
                p.name.trim().toLowerCase() ==
                widget.preset.title.trim().toLowerCase(),
          )
          .firstOrNull;
      if (savedPlaylist != null && widget.library != null) {
        final savedTracks =
            widget.library!.tracksForPlaylist(savedPlaylist.id);
        if (savedTracks.isNotEmpty) {
          final mapped =
              savedTracks.map(_importedTrackToYoutubeTrack).toList(growable: false);
          if (mounted) {
            setState(() {
              _tracks = mapped;
              _loading = false;
              _errorMessage = null;
            });
          }
          _cache[_cacheKey] = mapped;
          return;
        }
      }

      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = 'Could not load playlist tracks: $e';
        });
      }
    }
  }

  Future<void> _appendRelatedTracksInBackground(
    List<YoutubeTrack> seedTracks,
  ) async {
    try {
      final results = await YoutubeAudioService.instance.search(
        widget.preset.searchQuery,
        filterMixtapes: !widget.preset.allowLongEpisodes,
      );
      final filtered = _filterValidYoutubeTracks(results);
      if (!mounted || filtered.isEmpty) return;

      final existingKeys = seedTracks
          .map((t) => '${_rawTrackId(t.id)}|${t.title.trim().toLowerCase()}')
          .toSet();
      final merged = [...seedTracks];
      for (final track in filtered) {
        final key =
            '${_rawTrackId(track.id)}|${track.title.trim().toLowerCase()}';
        if (existingKeys.add(key)) {
          merged.add(track);
        }
      }
      if (merged.length == seedTracks.length) return;
      setState(() => _tracks = merged);
      _syncSavedPlaylistIfNeeded(merged);
      unawaited(_enrichTrackArtworks(merged));
    } catch (_) {}
  }

  List<YoutubeTrack> _filterValidYoutubeTracks(List<YoutubeTrack> results) =>
      _filterYoutubeTracksForPreset(results, widget.preset);

  Future<void> _enrichTrackArtworks(List<YoutubeTrack> tracks) async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    final sharedPlaylistArt = widget.preset.coverUrl ?? _resolvedArtistCoverUrl;
    preloadArtworkUrls([
      sharedPlaylistArt,
      ...tracks.take(10).map((t) => t.thumbnailUrl),
    ]);

    final cachedUpdates = <String, String>{};
    final toFetch = <YoutubeTrack>[];
    for (final t in tracks) {
      final cached = SongMetadataEnricher.instance.cachedTrackArtworkUrl(
        t.title,
        t.author,
      );
      if (cached != null && cached.isNotEmpty) {
        if (_enrichedTrackArtworks[t.id] != cached) {
          cachedUpdates[t.id] = cached;
        }
        continue;
      }
      final needsOwnArt =
          t.thumbnailUrl == null ||
          t.thumbnailUrl!.isEmpty ||
          t.thumbnailUrl == sharedPlaylistArt;
      if (needsOwnArt && toFetch.length < 15) {
        toFetch.add(t);
      }
    }

    if (cachedUpdates.isNotEmpty && mounted) {
      setState(() => _enrichedTrackArtworks.addAll(cachedUpdates));
      preloadArtworkUrls(cachedUpdates.values);
    }

    for (var i = 0; i < toFetch.length; i += 5) {
      if (!mounted) return;
      final chunk = toFetch.skip(i).take(5);
      final batchUpdates = <String, String>{};
      await Future.wait(
        chunk.map((t) async {
          final url = await SongMetadataEnricher.instance.fetchTrackArtworkUrl(
            t.title,
            t.author,
          );
          if (url != null && url.isNotEmpty) {
            batchUpdates[t.id] = url;
          }
        }),
      );
      if (!mounted) return;
      if (batchUpdates.isNotEmpty) {
        preloadArtworkUrls(batchUpdates.values);
        setState(() => _enrichedTrackArtworks.addAll(batchUpdates));
      }
    }
  }

  String get _totalDurationText {
    var totalSec = 0;
    for (final t in _tracks) {
      totalSec += t.duration.inSeconds;
    }
    final duration = Duration(seconds: totalSec);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}min';
    }
    return '${minutes}min';
  }

  String get _artistsSummaryText {
    if (_tracks.isEmpty) return widget.preset.curatorSubtitle;
    final uniqueArtists = <String>[];
    final seen = <String>{};
    for (final track in _tracks) {
      final clean = track.author.split(',').first.trim();
      final lower = clean.toLowerCase();
      if (clean.isEmpty ||
          lower == 'unknown artist' ||
          lower == 'melo' ||
          lower == 'melo artist') {
        continue;
      }
      if (seen.add(lower)) {
        uniqueArtists.add(clean);
      }
    }
    if (uniqueArtists.isEmpty) return widget.preset.curatorSubtitle;
    final lead = uniqueArtists.take(3).join(', ');
    return uniqueArtists.length > 3 ? 'With $lead and more' : 'With $lead';
  }

  Future<void> _playPlaylist({
    required bool shuffle,
    int startIndex = 0,
    List<YoutubeTrack>? sourceTracks,
  }) async {
    final handler = widget.audioHandler;
    final baseTracks = sourceTracks ?? _filteredTracks;
    if (handler == null || baseTracks.isEmpty) return;

    try {
      final ordered = [...baseTracks];
      var targetIndex = startIndex.clamp(0, ordered.length - 1);
      if (shuffle && sourceTracks == null) {
        ordered.shuffle();
        targetIndex = 0;
      }

      final items = ordered
          .map((t) {
            final local = widget.library?.findMatchingLocalTrack(
              providerTrackId: _rawTrackId(t.id),
              title: t.title,
              artist: t.author,
            );
            final base = local != null
                ? local.toMediaItem()
                : _trackToMediaItem(t);
            return base.copyWith(
              extras: {
                ...?base.extras,
                'playlistTitle': widget.preset.title,
                'playlistBadge': widget.preset.badge,
              },
            );
          })
          .toList(growable: false);

      await handler.setShuffleMode(
        shuffle ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none,
      );
      if (handler is MeloAudioHandler) {
        await handler.replaceQueue(
          items,
          initialIndex: targetIndex,
          playWhenReady: true,
        );
      } else {
        if (!shuffle && targetIndex > 0) {
          final rotated = [
            ...items.skip(targetIndex),
            ...items.take(targetIndex),
          ];
          await handler.updateQueue(rotated);
        } else {
          await handler.updateQueue(items);
        }
        await handler.skipToQueueItem(0);
        await handler.play();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Playing "${widget.preset.title}"'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not play playlist: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<void> _downloadSingleTrack(YoutubeTrack track) async {
    final library = widget.library;
    final rawId = _rawTrackId(track.id);
    if (library == null ||
        PlaylistDownloadManager.instance.progressForTrack(track.id, rawId) !=
            null) {
      return;
    }

    final chosenQuality = await LosslessAudioService.instance
        .selectDownloadQuality(
          context,
          title: track.title,
          artist: track.author,
        );
    if (chosenQuality == null || !mounted) return;

    try {
      await PlaylistDownloadManager.instance.downloadSingleTrack(
        track: track,
        library: library,
        qualityOverride: chosenQuality,
        fallbackAlbum: widget.preset.title,
        fallbackArt: _enrichedTrackArtworks[track.id],
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Saved "${track.title}" (${chosenQuality.shortLabel}) to Melo Library',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not download "${track.title}": $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<void> _ensurePlaylistSavedSilently({
    List<YoutubeTrack>? tracksOverride,
  }) async {
    final library = widget.library;
    final sourceTracks = tracksOverride ?? _tracks;
    if (library == null || sourceTracks.isEmpty) return;

    await PlaylistDownloadManager.instance.ensurePlaylistSaved(
      playlistTitle: widget.preset.title,
      coverUrl: widget.preset.coverUrl ?? _resolvedArtistCoverUrl,
      tracks: sourceTracks,
      library: library,
      enrichedArtworks: _enrichedTrackArtworks,
    );
  }

  Future<void> _downloadAllTracks() async {
    final library = widget.library;
    if (library == null || _tracks.isEmpty || _isDownloadingAll) return;

    final unDownloaded = _tracks.where((t) {
      return !library.isTrackDownloaded(
        providerTrackId: _rawTrackId(t.id),
        title: t.title,
        artist: t.author,
      );
    }).toList();

    if (unDownloaded.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('All songs in this playlist are already downloaded.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Downloading ${unDownloaded.length} songs from "${widget.preset.title}" in background…',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );

    final tracksSnapshot = List<YoutubeTrack>.unmodifiable(_tracks);
    final artSnapshot = Map<String, String>.unmodifiable(_enrichedTrackArtworks);
    final future = PlaylistDownloadManager.instance.downloadPlaylist(
      playlistTitle: widget.preset.title,
      coverUrl: widget.preset.coverUrl ?? _resolvedArtistCoverUrl,
      tracks: tracksSnapshot,
      library: library,
      enrichedArtworks: artSnapshot,
    );
    unawaited(
      future.then((savedCount) {
        if (!mounted || savedCount <= 0) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                'Downloaded $savedCount songs from "${widget.preset.title}"',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }),
    );
  }

  Future<void> _savePlaylistToPhone() async {
    final library = widget.library;
    if (library == null || _tracks.isEmpty) return;

    final existing = library.playlists
        .where((p) => p.name.toLowerCase() == widget.preset.title.toLowerCase())
        .firstOrNull;
    if (existing != null) {
      await _ensurePlaylistSavedSilently();
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '"${widget.preset.title}" synced to your Melo Library',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }

    try {
      await _ensurePlaylistSavedSilently();
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Saved "${widget.preset.title}" (${_tracks.length} songs) to Library',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not save playlist: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<void> _toggleSaveSingleTrack(YoutubeTrack track) async {
    final library = widget.library;
    if (library == null) return;
    try {
      final imported = _trackToImportedTrack(track);
      final registered = await library.registerOrFindRemoteTracks([imported]);
      if (registered.isEmpty) return;
      final isNowFavorite = await library.toggleFavorite(registered.first.id);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              isNowFavorite
                  ? 'Saved "${track.title}" to your songs'
                  : 'Removed "${track.title}" from saved songs',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not update song: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  void _showTrackDetails(YoutubeTrack track) {
    SongDetailsSheet.show(
      context,
      mediaItem: _trackToMediaItem(track),
      audioHandler: widget.audioHandler,
      library: widget.library,
    );
  }

  void _sharePlaylist() {
    final trackLines = _tracks
        .take(5)
        .map((t) => '${t.title} — ${t.author}')
        .join('\n');
    final summary = trackLines.isEmpty
        ? '${widget.preset.title} on Melo'
        : '${widget.preset.title} (${_tracks.length} tracks) on Melo\n$trackLines';
    Clipboard.setData(ClipboardData(text: summary));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Copied "${widget.preset.title}" to clipboard'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _showPlaylistOptionsSheet(BuildContext context) {
    final isSaved =
        widget.library?.playlists.any(
          (p) => p.name.toLowerCase() == widget.preset.title.toLowerCase(),
        ) ??
        false;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF141416),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              ListTile(
                leading: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                ),
                title: const Text(
                  'Play playlist',
                  style: TextStyle(color: Colors.white),
                ),
                enabled: _tracks.isNotEmpty,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_playPlaylist(shuffle: false));
                },
              ),
              ListTile(
                leading: const Icon(Icons.shuffle_rounded, color: Colors.white),
                title: const Text(
                  'Shuffle playlist',
                  style: TextStyle(color: Colors.white),
                ),
                enabled: _tracks.isNotEmpty,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  setState(() => _shuffleEnabled = true);
                  unawaited(_playPlaylist(shuffle: true));
                },
              ),
              ListTile(
                leading: Icon(
                  isSaved
                      ? Icons.check_circle_rounded
                      : Icons.add_circle_outline_rounded,
                  color: isSaved ? MeloColors.cherry : Colors.white,
                ),
                title: Text(
                  isSaved ? 'Saved to Library' : 'Save to Library',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_savePlaylistToPhone());
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.arrow_circle_down_outlined,
                  color: Colors.white,
                ),
                title: const Text(
                  'Download all tracks offline',
                  style: TextStyle(color: Colors.white),
                ),
                enabled: _tracks.isNotEmpty && !_isDownloadingAll,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_downloadAllTracks());
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined, color: Colors.white),
                title: const Text(
                  'Share playlist',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _sharePlaylist();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _distinctArtworkUrls() {
    final seen = <String>{};
    final urls = <String>[];
    void addUrl(String? raw) {
      final clean = raw?.trim();
      if (clean == null || clean.isEmpty) return;
      if (seen.add(clean)) urls.add(clean);
    }

    addUrl(_resolvedArtistCoverUrl);
    addUrl(widget.preset.coverUrl);
    for (final avatar in widget.preset.artistAvatars) {
      addUrl(avatar);
    }
    for (final t in _tracks) {
      addUrl(_enrichedTrackArtworks[t.id] ?? t.thumbnailUrl);
      if (urls.length >= 4) break;
    }
    return urls;
  }

  Widget _buildHeroArtwork(
    List<String> distinctCovers,
    List<Color> primaryGradient,
  ) {
    final useTripleCircles =
        distinctCovers.length >= 3 ||
        widget.preset.isArtistRadio ||
        widget.preset.vibe != null;

    if (useTripleCircles) {
      final centerUrl = distinctCovers.isNotEmpty ? distinctCovers[0] : null;
      final leftUrl = distinctCovers.length > 1 ? distinctCovers[1] : centerUrl;
      final rightUrl = distinctCovers.length > 2
          ? distinctCovers[2]
          : leftUrl;

      Widget circleArtwork(String? url, double size, {bool border = false}) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: border
                ? Border.all(color: Colors.black, width: 3.5)
                : Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                    width: 1,
                  ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: border ? 0.65 : 0.4),
                blurRadius: border ? 24 : 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipOval(
            child: url != null && url.isNotEmpty
                ? CachedNetworkArtwork(
                    url: url,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    errorWidget: _fallbackGradientArtwork(
                      primaryGradient,
                      iconSize: size * 0.38,
                    ),
                  )
                : _fallbackGradientArtwork(
                    primaryGradient,
                    iconSize: size * 0.38,
                  ),
          ),
        );
      }

      return SizedBox(
        width: 316,
        height: 196,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 6,
              top: 32,
              child: circleArtwork(leftUrl, 132),
            ),
            Positioned(
              right: 6,
              top: 32,
              child: circleArtwork(rightUrl, 132),
            ),
            circleArtwork(centerUrl, 192, border: true),
          ],
        ),
      );
    }

    final heroCoverUrl = distinctCovers.firstOrNull;
    return Container(
      width: 196,
      height: 196,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryGradient.first.withValues(alpha: 0.45),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.7),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: heroCoverUrl != null && heroCoverUrl.isNotEmpty
            ? CachedNetworkArtwork(
                url: heroCoverUrl,
                width: 196,
                height: 196,
                fit: BoxFit.cover,
                errorWidget: _fallbackGradientArtwork(
                  primaryGradient,
                  iconSize: 76,
                ),
              )
            : _fallbackGradientArtwork(primaryGradient, iconSize: 76),
      ),
    );
  }

  Widget _fallbackGradientArtwork(
    List<Color> colors, {
    double iconSize = 64,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Center(
        child: Icon(
          widget.preset.icon,
          size: iconSize,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }

  Widget _buildTrackThumbnail(YoutubeTrack track, bool isPlaying) {
    final artUrl = _enrichedTrackArtworks[track.id] ?? track.thumbnailUrl;
    final isSpotify = _isSpotifyTrackId(track.id);
    Widget fallbackBox() => Container(
      color: const Color(0xFF1C1C1E),
      child: const Icon(
        Icons.music_note_rounded,
        color: Colors.white38,
        size: 20,
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 48,
        height: 48,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (artUrl != null && artUrl.isNotEmpty)
              CachedNetworkArtwork(
                url: artUrl,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorWidget: !isSpotify
                    ? CachedNetworkArtwork(
                        url: 'https://i.ytimg.com/vi/${track.id}/hqdefault.jpg',
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorWidget: fallbackBox(),
                      )
                    : fallbackBox(),
              )
            else if (!isSpotify)
              CachedNetworkArtwork(
                url: 'https://i.ytimg.com/vi/${track.id}/hqdefault.jpg',
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorWidget: fallbackBox(),
              )
            else
              fallbackBox(),
            if (isPlaying)
              Container(
                color: Colors.black.withValues(alpha: 0.58),
                child: const Center(
                  child: AnimatedEqualizerIndicator(
                    color: MeloColors.cherry,
                    size: 20,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryGradient = widget.preset.gradient;
    final headerColor = primaryGradient.first;
    final library = widget.library;
    final isPlaylistSaved =
        library?.playlists.any(
          (p) => p.name.toLowerCase() == widget.preset.title.toLowerCase(),
        ) ??
        false;
    final distinctCovers = _distinctArtworkUrls();
    final miniPreviewArt = distinctCovers.firstOrNull;

    return Scaffold(
      backgroundColor: Colors.black,
      bottomNavigationBar: PlaylistMiniPlayerDock(
        audioHandler: widget.audioHandler,
        musicLibrary: widget.library,
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 448 + MediaQuery.paddingOf(context).top,
            pinned: true,
            stretch: true,
            backgroundColor: Colors.black,
            surfaceTintColor: Colors.transparent,
            leading: Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Center(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.42),
                  ),
                  child: IconButton(
                    tooltip: 'Back',
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 17,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
            actions: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.42),
                ),
                child: IconButton(
                  tooltip: 'Find in playlist',
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    _showSearchBar ? Icons.close_rounded : Icons.search_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                  onPressed: () {
                    setState(() {
                      _showSearchBar = !_showSearchBar;
                      if (!_showSearchBar) {
                        _searchController.clear();
                        _searchFilter = '';
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.42),
                ),
                child: IconButton(
                  tooltip: 'Playlist options',
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () => _showPlaylistOptionsSheet(context),
                ),
              ),
              const SizedBox(width: 12),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          headerColor.withValues(alpha: 0.72),
                          MeloColors.cherryDeep.withValues(alpha: 0.34),
                          Colors.black,
                        ],
                        stops: const [0.0, 0.62, 1.0],
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 44, 18, 12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: _buildHeroArtwork(
                              distinctCovers,
                              primaryGradient,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.preset.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.7,
                              height: 1.08,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _artistsSummaryText,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.72),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: const BoxDecoration(
                                  color: MeloColors.cherry,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.graphic_eq_rounded,
                                  size: 13,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Made for you',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _tracks.isEmpty
                                ? widget.preset.badge
                                : '$_totalDurationText · ${_tracks.length} songs',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.58),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Screenshot-Matched Single-Row Action Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // Mini vertical rounded preview thumbnail
                      Container(
                        width: 34,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.34),
                            width: 1.2,
                          ),
                          color: const Color(0xFF1C1C1E),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child:
                            miniPreviewArt != null && miniPreviewArt.isNotEmpty
                            ? CachedNetworkArtwork(
                                url: miniPreviewArt,
                                width: 34,
                                height: 44,
                                fit: BoxFit.cover,
                                errorWidget: Icon(
                                  widget.preset.icon,
                                  color: Colors.white70,
                                  size: 16,
                                ),
                              )
                            : Icon(
                                widget.preset.icon,
                                color: Colors.white70,
                                size: 16,
                              ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        tooltip: isPlaylistSaved
                            ? 'Saved to Library'
                            : 'Save to Library',
                        onPressed: _tracks.isEmpty ? null : _savePlaylistToPhone,
                        icon: Icon(
                          isPlaylistSaved
                              ? Icons.check_circle_rounded
                              : Icons.add_circle_outline_rounded,
                          color: isPlaylistSaved
                              ? MeloColors.cherry
                              : Colors.white70,
                          size: 28,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Download Playlist',
                        onPressed: _tracks.isEmpty || _isDownloadingAll
                            ? null
                            : _downloadAllTracks,
                        icon: _isDownloadingAll
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: MeloColors.cherry,
                                ),
                              )
                            : const Icon(
                                Icons.arrow_circle_down_outlined,
                                color: Colors.white70,
                                size: 28,
                              ),
                      ),
                      IconButton(
                        tooltip: 'Share',
                        onPressed: _sharePlaylist,
                        icon: const Icon(
                          Icons.share_outlined,
                          color: Colors.white70,
                          size: 24,
                        ),
                      ),
                      const Spacer(),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Shuffle playlist',
                            onPressed: _tracks.isEmpty
                                ? null
                                : () {
                                    setState(
                                      () => _shuffleEnabled = !_shuffleEnabled,
                                    );
                                    if (_shuffleEnabled) {
                                      unawaited(_playPlaylist(shuffle: true));
                                    }
                                  },
                            icon: Icon(
                              Icons.shuffle_rounded,
                              color: _shuffleEnabled
                                  ? MeloColors.cherry
                                  : Colors.white70,
                              size: 26,
                            ),
                          ),
                          if (_shuffleEnabled)
                            Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                color: MeloColors.cherry,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Semantics(
                        button: true,
                        label: 'Play playlist',
                        child: Material(
                          color: _tracks.isEmpty
                              ? MeloColors.cherry.withValues(alpha: 0.45)
                              : MeloColors.cherry,
                          shape: const CircleBorder(),
                          elevation: 4,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _tracks.isEmpty
                                ? null
                                : () => _playPlaylist(shuffle: _shuffleEnabled),
                            child: const SizedBox(
                              width: 56,
                              height: 56,
                              child: Icon(
                                Icons.play_arrow_rounded,
                                size: 34,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_showSearchBar) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      autofocus: true,
                      onChanged: (val) => setState(
                        () => _searchFilter = val.trim().toLowerCase(),
                      ),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Find in ${widget.preset.title}',
                        hintStyle: const TextStyle(
                          color: Colors.white38,
                          fontSize: 13.5,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Colors.white38,
                          size: 20,
                        ),
                        suffixIcon: _searchFilter.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear_rounded,
                                  color: Colors.white54,
                                  size: 18,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchFilter = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFF141416),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: MeloColors.cherry),
                    SizedBox(height: 16),
                    Text(
                      'Loading tracks...',
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),

          if (!_loading && _errorMessage != null && _tracks.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.wifi_off_rounded,
                        size: 48,
                        color: Colors.white38,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: MeloColors.cherry,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          setState(() => _loading = true);
                          unawaited(_loadTracks());
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (!_loading && _tracks.isNotEmpty && _filteredTracks.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.search_off_rounded,
                        size: 44,
                        color: Colors.white38,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No songs matching "$_searchFilter"',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchFilter = '');
                        },
                        child: const Text('Clear search'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (!_loading && _filteredTracks.isNotEmpty)
            StreamBuilder<MediaItem?>(
              stream: widget.audioHandler?.mediaItem,
              initialData: widget.audioHandler?.mediaItem.value,
              builder: (context, mediaSnapshot) {
                final currentItem = mediaSnapshot.data;
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 2, 12, 120),
                  sliver: SliverList.builder(
                    itemCount: _filteredTracks.length,
                    itemBuilder: (context, index) {
                      final track = _filteredTracks[index];
                      final rawId = _rawTrackId(track.id);
                      final isDownloaded =
                          library?.isTrackDownloaded(
                            providerTrackId: rawId,
                            title: track.title,
                            artist: track.author,
                          ) ??
                          false;
                      final localMatch = library?.findMatchingLocalTrack(
                        providerTrackId: rawId,
                        title: track.title,
                        artist: track.author,
                      );
                      final isSavedTrack =
                          isDownloaded ||
                          (localMatch != null &&
                              ((library?.isFavorite(localMatch.id) ?? false) ||
                                  (library?.playlists.any(
                                        (p) =>
                                            p.name.toLowerCase() ==
                                                widget.preset.title
                                                    .toLowerCase() &&
                                            p.trackIds.contains(localMatch.id),
                                      ) ??
                                      false)));
                      final progress = PlaylistDownloadManager.instance
                          .progressForTrack(track.id, rawId);
                      final isPlaying =
                          currentItem != null &&
                          (currentItem.id == track.id ||
                              currentItem.extras?['providerTrackId'] == rawId ||
                              (currentItem.title.trim().toLowerCase() ==
                                      track.title.trim().toLowerCase() &&
                                  currentItem.artist?.trim().toLowerCase() ==
                                      track.author.trim().toLowerCase()));

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _playPlaylist(
                            shuffle: false,
                            startIndex: index,
                            sourceTracks: _filteredTracks,
                          ),
                          onLongPress: () => _showTrackDetails(track),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                _buildTrackThumbnail(track, isPlaying),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        track.title,
                                        style: TextStyle(
                                          color: isPlaying
                                              ? MeloColors.cherry
                                              : Colors.white,
                                          fontSize: 15.5,
                                          fontWeight: isPlaying
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                          letterSpacing: -0.2,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        track.author,
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.62,
                                          ),
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                if (progress != null)
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        value: progress > 0 ? progress : null,
                                        strokeWidth: 2.2,
                                        color: MeloColors.cherry,
                                      ),
                                    ),
                                  )
                                else if (isSavedTrack)
                                  IconButton(
                                    tooltip: 'Saved',
                                    onPressed: () =>
                                        _toggleSaveSingleTrack(track),
                                    icon: const Icon(
                                      Icons.check_circle_rounded,
                                      color: MeloColors.cherry,
                                      size: 21,
                                    ),
                                  ),
                                PopupMenuButton<String>(
                                  icon: Icon(
                                    Icons.more_vert_rounded,
                                    color: Colors.white.withValues(alpha: 0.55),
                                    size: 20,
                                  ),
                                  color: const Color(0xFF141416),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  onSelected: (value) async {
                                    switch (value) {
                                      case 'play':
                                        await _playPlaylist(
                                          shuffle: false,
                                          startIndex: index,
                                          sourceTracks: _filteredTracks,
                                        );
                                        break;
                                      case 'save':
                                        await _toggleSaveSingleTrack(track);
                                        break;
                                      case 'play_next':
                                        final item = _trackToMediaItem(track);
                                        final handler = widget.audioHandler;
                                        if (handler is MeloAudioHandler) {
                                          await handler.insertQueueItemNext(item);
                                        } else {
                                          await handler?.addQueueItem(item);
                                        }
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context)
                                          ..hideCurrentSnackBar()
                                          ..showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Playing "${track.title}" next',
                                              ),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                            ),
                                          );
                                        break;
                                      case 'queue':
                                        final item = _trackToMediaItem(track);
                                        await widget.audioHandler?.addQueueItem(
                                          item,
                                        );
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context)
                                          ..hideCurrentSnackBar()
                                          ..showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Added "${track.title}" to Up Next',
                                              ),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                            ),
                                          );
                                        break;
                                      case 'download':
                                        await _downloadSingleTrack(track);
                                        break;
                                      case 'details':
                                        _showTrackDetails(track);
                                        break;
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    const PopupMenuItem(
                                      value: 'details',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.info_outline_rounded,
                                            size: 20,
                                          ),
                                          SizedBox(width: 12),
                                          Text('Song details & artwork'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'play',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.play_arrow_rounded,
                                            size: 20,
                                          ),
                                          SizedBox(width: 12),
                                          Text('Play track'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'save',
                                      child: Row(
                                        children: [
                                          Icon(
                                            isSavedTrack
                                                ? Icons.check_circle_rounded
                                                : Icons
                                                      .add_circle_outline_rounded,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            isSavedTrack
                                                ? 'Remove from saved songs'
                                                : 'Save song to library',
                                          ),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'play_next',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.playlist_play_rounded,
                                            size: 20,
                                          ),
                                          SizedBox(width: 12),
                                          Text('Play next'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'queue',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.queue_music_rounded,
                                            size: 20,
                                          ),
                                          SizedBox(width: 12),
                                          Text('Add to Up Next'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'download',
                                      child: Row(
                                        children: [
                                          Icon(
                                            isDownloaded
                                                ? Icons
                                                      .file_download_done_rounded
                                                : Icons.download_rounded,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            isDownloaded
                                                ? 'Redownload track'
                                                : 'Download track',
                                          ),
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
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
