part of 'mini_player.dart';

/// The artwork-derived palette for [item], or `null` when it has no artwork or
/// the artwork is effectively monochrome. Shares the artwork cache so the
/// image is only ever fetched once per track.
Future<TonePalette?> _paletteForItem(MediaItem item) {
  final artworkUri = item.artUri;
  final sourceUri = Uri.tryParse(item.id);
  if (artworkUri == null && sourceUri == null) {
    return Future<TonePalette?>.value();
  }
  final key = artworkUri ?? sourceUri!;
  return _paletteCache.putIfAbsent(key, () async {
    final bytes = await _loadArtwork(artworkUri, sourceUri);
    final palette = await tonePaletteFromBytes(bytes);
    if (_paletteCache.length > 64) {
      _paletteCache.remove(_paletteCache.keys.first);
    }
    return palette;
  });
}

/// The palette to actually paint with: artwork colour when available, otherwise
/// a tasteful deterministic colour derived from the title.
TonePalette _paletteFor(MediaItem item, TonePalette? artworkPalette) =>
    artworkPalette ?? TonePalette.fromSeed(item.title.hashCode);

/// Public entry point so hero surfaces elsewhere (Home, Library) can pick up
/// the same artwork-derived colour as the Now Playing screen.
Future<TonePalette?> tonePaletteForItem(MediaItem item) =>
    _paletteForItem(item);

class _ArtworkBackdrop extends StatelessWidget {
  const _ArtworkBackdrop({required this.palette});

  final TonePalette palette;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: ToneMotion.slow,
      curve: ToneMotion.emphasized,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.deep, ToneColors.playerBackdrop, ToneColors.amoled],
          stops: const [0, 0.52, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedContainer(
            duration: ToneMotion.slow,
            curve: ToneMotion.emphasized,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.74),
                radius: 1.08,
                colors: [
                  palette.accent.withValues(alpha: 0.44),
                  palette.accent.withValues(alpha: 0),
                ],
              ),
            ),
          ),
          AnimatedContainer(
            duration: ToneMotion.slow,
            curve: ToneMotion.emphasized,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.8, 1.1),
                radius: 0.95,
                colors: [
                  palette.muted.withValues(alpha: 0.5),
                  palette.muted.withValues(alpha: 0),
                ],
              ),
            ),
          ),
          const ToneGrain(),
        ],
      ),
    );
  }
}

class _PlayerScrim extends StatelessWidget {
  const _PlayerScrim();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x8C000000),
          Color(0x3D000000),
          Color(0xAB000000),
          Color(0xFF000000),
        ],
        stops: [0, 0.34, 0.74, 1],
      ),
    ),
  );
}

class AlbumArtwork extends StatelessWidget {
  const AlbumArtwork({
    required this.size,
    required this.title,
    this.iconSize = 25,
    this.artworkUri,
    this.sourceUri,
    this.borderRadius,
    super.key,
  });

  final double size;
  final String title;
  final double iconSize;
  final Uri? artworkUri;
  final Uri? sourceUri;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final palette = TonePalette.fromSeed(title.hashCode);
    final radius = BorderRadius.circular(borderRadius ?? size * 0.09);
    final artwork = artworkUri != null || sourceUri != null
        ? _loadArtwork(artworkUri, sourceUri)
        : null;
    return Semantics(
      label: 'Artwork for $title',
      image: true,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            colors: [palette.muted, palette.deep, ToneColors.cherryDeep],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: size >= 80
              ? [
                  BoxShadow(
                    color: palette.accent.withValues(alpha: 0.22),
                    blurRadius: size * 0.22,
                    spreadRadius: -size * 0.06,
                    offset: Offset(0, size * 0.1),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.34),
                    blurRadius: size * 0.16,
                    offset: Offset(0, size * 0.09),
                  ),
                ]
              : null,
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        clipBehavior: Clip.antiAlias,
        child: artwork == null
            ? _fallback(palette)
            : FutureBuilder<Uint8List?>(
                future: artwork,
                builder: (context, snapshot) {
                  final bytes = snapshot.data;
                  if (bytes == null || bytes.isEmpty) return _fallback(palette);
                  final decodeSize =
                      (size * MediaQuery.devicePixelRatioOf(context))
                          .ceil()
                          .clamp(64, 1024);
                  return Image.memory(
                    bytes,
                    fit: BoxFit.cover,
                    cacheWidth: decodeSize,
                    cacheHeight: decodeSize,
                    errorBuilder: (_, _, _) => _fallback(palette),
                  );
                },
              ),
      ),
    );
  }

  /// The no-artwork treatment: a deterministic gradient with the track's
  /// monogram and a whisper of grain, so a missing cover still looks
  /// deliberate rather than broken.
  Widget _fallback(TonePalette palette) {
    if (size < 56) {
      return Icon(
        Icons.graphic_eq_rounded,
        color: Colors.white.withValues(alpha: 0.92),
        size: iconSize.clamp(0, size * 0.5),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.3, -0.4),
              radius: 1.1,
              colors: [
                palette.accent.withValues(alpha: 0.55),
                Colors.transparent,
              ],
            ),
          ),
        ),
        const ToneGrain(opacity: 0.07, density: 0.0006),
        Center(
          child: Text(
            _monogram(title),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.94),
              fontSize: size * 0.4,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              height: 1,
            ),
          ),
        ),
        Positioned(
          right: size * 0.1,
          bottom: size * 0.1,
          child: Icon(
            Icons.graphic_eq_rounded,
            color: Colors.white.withValues(alpha: 0.5),
            size: size * 0.15,
          ),
        ),
      ],
    );
  }
}

String _monogram(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '♪';
  return String.fromCharCode(trimmed.runes.first).toUpperCase();
}

Future<Uint8List?> _loadArtwork(Uri? artworkUri, Uri? sourceUri) {
  final cacheKey = artworkUri ?? sourceUri!;
  return _artworkCache.putIfAbsent(cacheKey, () async {
    try {
      // 1. Direct local image file (e.g. file:///.../_art.jpg)
      for (final candidate in [artworkUri, sourceUri]) {
        if (candidate == null) continue;
        final lowerPath = candidate.path.toLowerCase();
        final isImageFile =
            lowerPath.endsWith('.jpg') ||
            lowerPath.endsWith('.jpeg') ||
            lowerPath.endsWith('.png') ||
            lowerPath.endsWith('.webp');
        if (isImageFile &&
            (candidate.scheme == 'file' || candidate.scheme.isEmpty)) {
          try {
            final file = candidate.scheme == 'file'
                ? File.fromUri(candidate)
                : File(candidate.path);
            if (await file.exists()) {
              final bytes = await file.readAsBytes();
              if (bytes.isNotEmpty) {
                if (_artworkCache.length > 96) {
                  _artworkCache.remove(_artworkCache.keys.first);
                }
                return bytes;
              }
            }
          } catch (_) {}
        }
      }

      // 2. Remote HTTP/HTTPS artwork
      if (artworkUri != null &&
          (artworkUri.scheme == 'http' || artworkUri.scheme == 'https')) {
        try {
          final res = await http
              .get(artworkUri)
              .timeout(const Duration(seconds: 8));
          if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
            if (_artworkCache.length > 96) {
              _artworkCache.remove(_artworkCache.keys.first);
            }
            return res.bodyBytes;
          }
        } catch (_) {}
      }

      // 3. Platform channel (MediaStore albumart, content://, or embedded audio tags)
      Future<Uint8List?> fetch() {
        return _artworkChannel.invokeMethod<Uint8List>('getArtwork', {
          'uri': artworkUri?.toString(),
          'sourceUri': sourceUri?.toString(),
        });
      }

      final bytes = !kIsWeb && Platform.isAndroid
          ? await (await ArtworkCache.shared).getOrFetch(
              cacheKey.toString(),
              fetch,
            )
          : await fetch();
      if (bytes == null || bytes.isEmpty) {
        _artworkCache.remove(cacheKey);
        return null;
      }
      if (_artworkCache.length > 96) {
        _artworkCache.remove(_artworkCache.keys.first);
      }
      return bytes;
    } on Object {
      _artworkCache.remove(cacheKey);
      return null;
    }
  });
}

/// Renders rich playlist cover artwork:
/// - A 2x2 album cover mosaic when the playlist contains 4+ distinct track covers
/// - Single track cover when 1-3 covers exist
/// - Automatic background cover lookup from iTunes/Deezer on Android if tracks lack artwork
class PlaylistArtwork extends StatefulWidget {
  const PlaylistArtwork({
    required this.playlistName,
    required this.tracks,
    required this.size,
    this.library,
    this.borderRadius,
    super.key,
  });

  final String playlistName;
  final List<ImportedTrack> tracks;
  final double size;
  final MusicLibrary? library;
  final double? borderRadius;

  @override
  State<PlaylistArtwork> createState() => _PlaylistArtworkState();
}

class _PlaylistArtworkState extends State<PlaylistArtwork> {
  static final Map<String, String?> _resolvedPlaylistCoverCache = {};
  String? _fallbackCoverUrl;
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    _maybeResolveMissingCover();
  }

  @override
  void didUpdateWidget(covariant PlaylistArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playlistName != widget.playlistName ||
        oldWidget.tracks.length != widget.tracks.length) {
      _maybeResolveMissingCover();
    }
  }

  void _maybeResolveMissingCover() {
    if (widget.tracks.isEmpty) return;
    final hasAnyArtwork = widget.tracks.any(
      (t) => t.artworkUri != null && t.artworkUri!.trim().isNotEmpty,
    );
    if (hasAnyArtwork) return;

    final first = widget.tracks.first;
    final cacheKey = '${first.title.toLowerCase()}|${first.artist.toLowerCase()}';
    if (_resolvedPlaylistCoverCache.containsKey(cacheKey)) {
      _fallbackCoverUrl = _resolvedPlaylistCoverCache[cacheKey];
      return;
    }
    if (_resolving || kIsWeb || !Platform.isAndroid) return;
    _resolving = true;
    unawaited(() async {
      try {
        final enriched = await SongMetadataEnricher.instance.fetchFullMetadata(
          title: first.title,
          artist: first.artist,
          album: first.album,
          durationMs: first.durationMs,
          artworkDirectory: widget.library?.musicDirectory,
          trackIdForCache: first.id,
        );
        final resolvedUri = enriched.localArtworkUri ?? enriched.artworkUrl;
        _resolvedPlaylistCoverCache[cacheKey] = resolvedUri;
        if (resolvedUri != null && widget.library != null) {
          await widget.library!.updateTrackEnrichedMetadata(
            first.id,
            artworkUri: resolvedUri,
          );
        }
        if (mounted && resolvedUri != null) {
          setState(() => _fallbackCoverUrl = resolvedUri);
        }
      } catch (_) {
      } finally {
        _resolving = false;
      }
    }());
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? (widget.size * 0.24).clamp(10.0, 28.0);
    final distinctTrackCovers = <ImportedTrack>[];
    final seenCoverKeys = <String>{};

    for (final track in widget.tracks) {
      final key = track.artworkUri?.trim().isNotEmpty == true
          ? track.artworkUri!
          : track.path;
      if (seenCoverKeys.add(key)) {
        distinctTrackCovers.add(track);
      }
      if (distinctTrackCovers.length >= 4) break;
    }

    if (distinctTrackCovers.length >= 4) {
      final tileSize = widget.size / 2;
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Column(
            children: [
              Row(
                children: [
                  _tile(distinctTrackCovers[0], tileSize),
                  _tile(distinctTrackCovers[1], tileSize),
                ],
              ),
              Row(
                children: [
                  _tile(distinctTrackCovers[2], tileSize),
                  _tile(distinctTrackCovers[3], tileSize),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final lead = distinctTrackCovers.firstOrNull ?? widget.tracks.firstOrNull;
    final artStr = lead?.artworkUri ?? _fallbackCoverUrl;
    return AlbumArtwork(
      size: widget.size,
      title: widget.playlistName,
      artworkUri: artStr != null ? Uri.tryParse(artStr) : null,
      sourceUri: lead != null ? Uri.tryParse(lead.path) : null,
      borderRadius: radius,
    );
  }

  Widget _tile(ImportedTrack track, double tileSize) {
    return AlbumArtwork(
      size: tileSize,
      title: track.title,
      artworkUri: track.artworkUri != null
          ? Uri.tryParse(track.artworkUri!)
          : null,
      sourceUri: Uri.tryParse(track.path),
      borderRadius: 0,
    );
  }
}
