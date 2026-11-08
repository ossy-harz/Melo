part of 'mini_player.dart';

/// The artwork-derived palette for [item], or `null` when it has no artwork or
/// the artwork is effectively monochrome. Shares the artwork cache so the
/// image is only ever fetched once per track.
Future<MeloPalette?> _paletteForItem(MediaItem item) {
  final artworkUri = item.artUri;
  final sourceUri = Uri.tryParse(item.id);
  if (artworkUri == null && sourceUri == null) {
    return Future<MeloPalette?>.value();
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
MeloPalette _paletteFor(MediaItem item, MeloPalette? artworkPalette) =>
    artworkPalette ?? MeloPalette.fromSeed(item.title.hashCode);

/// Public entry point so hero surfaces elsewhere (Home, Library) can pick up
/// the same artwork-derived colour as the Now Playing screen.
Future<MeloPalette?> tonePaletteForItem(MediaItem item) =>
    _paletteForItem(item);

class _ArtworkBackdrop extends StatelessWidget {
  const _ArtworkBackdrop({required this.palette});

  final MeloPalette palette;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: MeloMotion.slow,
      curve: MeloMotion.emphasized,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.deep, MeloColors.playerBackdrop, MeloColors.amoled],
          stops: const [0, 0.52, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedContainer(
            duration: MeloMotion.slow,
            curve: MeloMotion.emphasized,
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
            duration: MeloMotion.slow,
            curve: MeloMotion.emphasized,
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
          const MeloGrain(),
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
    final palette = MeloPalette.fromSeed(title.hashCode);
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
            colors: [palette.muted, palette.deep, MeloColors.cherryDeep],
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
  Widget _fallback(MeloPalette palette) {
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
        const MeloGrain(opacity: 0.07, density: 0.0006),
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
/// - Custom artwork when provided (or selected by user)
/// - A 2x2 album cover mosaic when the playlist contains 4+ distinct track covers
/// - Single hero track cover when 1-3 covers exist
/// - Apple Music editorial graphic cover with vinyl grooves and fluid mesh gradient
///   when no covers are available (never a boring mono-color box)
/// - Automatic background cover lookup from iTunes/Deezer on Android if tracks lack artwork
class PlaylistArtwork extends StatefulWidget {
  const PlaylistArtwork({
    required this.playlistName,
    required this.tracks,
    required this.size,
    this.library,
    this.borderRadius,
    this.customArtworkUri,
    this.themeIndex,
    super.key,
  });

  final String playlistName;
  final List<ImportedTrack> tracks;
  final double size;
  final MusicLibrary? library;
  final double? borderRadius;
  final String? customArtworkUri;
  final int? themeIndex;

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
    final radius = widget.borderRadius ?? (widget.size * 0.16).clamp(8.0, 28.0);

    // 1. User provided custom artwork (file or remote URL)
    final customUri = widget.customArtworkUri;
    if (customUri != null && customUri.trim().isNotEmpty) {
      final parsed = Uri.tryParse(customUri);
      return AlbumArtwork(
        size: widget.size,
        title: widget.playlistName,
        artworkUri: parsed,
        sourceUri: parsed,
        borderRadius: radius,
      );
    }

    // 2. Discover tracks with genuine artwork
    final distinctTrackCovers = <ImportedTrack>[];
    final seenCoverKeys = <String>{};

    for (final track in widget.tracks) {
      final hasExplicitArt = track.artworkUri != null && track.artworkUri!.trim().isNotEmpty;
      final key = hasExplicitArt
          ? track.artworkUri!
          : (track.album.isNotEmpty ? '${track.artist}|${track.album}' : track.path);
      if (hasExplicitArt && seenCoverKeys.add(key)) {
        distinctTrackCovers.add(track);
      }
      if (distinctTrackCovers.length >= 4) break;
    }

    // If 4 distinct covers are available, build an Apple Music 2x2 collage
    if (distinctTrackCovers.length >= 4) {
      final tileSize = widget.size / 2;
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: widget.size >= 70
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.38),
                    blurRadius: widget.size * 0.18,
                    offset: Offset(0, widget.size * 0.08),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
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

    // If at least one track has artwork or resolved online cover, feature that cover
    final lead = distinctTrackCovers.firstOrNull ??
        widget.tracks.where((t) => t.artworkUri != null && t.artworkUri!.trim().isNotEmpty).firstOrNull;
    final artStr = lead?.artworkUri ?? _fallbackCoverUrl;

    if (artStr != null && artStr.trim().isNotEmpty) {
      return AlbumArtwork(
        size: widget.size,
        title: widget.playlistName,
        artworkUri: Uri.tryParse(artStr),
        sourceUri: lead != null ? Uri.tryParse(lead.path) : null,
        borderRadius: radius,
      );
    }

    // 3. Fallback: Authentic Apple Music Editorial Graphic Cover
    return _buildAppleMusicEditorialCover(
      size: widget.size,
      radius: radius,
      name: widget.playlistName,
      themeIndex: widget.themeIndex,
    );
  }

  Widget _tile(ImportedTrack track, double tileSize) {
    return Container(
      width: tileSize,
      height: tileSize,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black.withValues(alpha: 0.28), width: 0.5),
      ),
      child: AlbumArtwork(
        size: tileSize,
        title: track.title,
        artworkUri: track.artworkUri != null ? Uri.tryParse(track.artworkUri!) : null,
        sourceUri: Uri.tryParse(track.path),
        borderRadius: 0,
      ),
    );
  }

  Widget _buildAppleMusicEditorialCover({
    required double size,
    required double radius,
    required String name,
    int? themeIndex,
  }) {
    // 7 Apple Music signature fluid palettes
    const themePalettes = <List<Color>>[
      // 0: Velvet Sunset
      [Color(0xFFFF2A4F), Color(0xFFC026D3), Color(0xFF311042), Color(0xFF0D0214)],
      // 1: Midnight Groove
      [Color(0xFF06B6D4), Color(0xFF2563EB), Color(0xFF1E1B4B), Color(0xFF030712)],
      // 2: Solar Flare
      [Color(0xFFF59E0B), Color(0xFFEA580C), Color(0xFF881337), Color(0xFF1F040A)],
      // 3: Emerald Wave
      [Color(0xFF10B981), Color(0xFF059669), Color(0xFF064E3B), Color(0xFF021E14)],
      // 4: Cosmic Neon
      [Color(0xFFF43F5E), Color(0xFF8B5CF6), Color(0xFF4C1D95), Color(0xFF090514)],
      // 5: Rose Gold
      [Color(0xFFFB7185), Color(0xFFE11D48), Color(0xFF4C0519), Color(0xFF140206)],
      // 6: Titanium Slate
      [Color(0xFF94A3B8), Color(0xFF475569), Color(0xFF1E293B), Color(0xFF090D16)],
    ];

    final index = themeIndex != null
        ? (themeIndex % themePalettes.length)
        : (name.hashCode.abs() % themePalettes.length);
    final palette = themePalettes[index];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette,
          stops: const [0.0, 0.35, 0.75, 1.0],
        ),
        boxShadow: size >= 70
            ? [
                BoxShadow(
                  color: palette.first.withValues(alpha: 0.34),
                  blurRadius: size * 0.22,
                  spreadRadius: -size * 0.05,
                  offset: Offset(0, size * 0.1),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.42),
                  blurRadius: size * 0.16,
                  offset: Offset(0, size * 0.08),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Vinyl acoustic groove lines
          CustomPaint(
            painter: _AppleVinylGroovesPainter(accentColor: palette.first),
          ),

          // Central Apple Music glass disc
          Center(
            child: Container(
              width: size * 0.42,
              height: size * 0.42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.24),
                    Colors.white.withValues(alpha: 0.06),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.36),
                  width: (size * 0.012).clamp(1.0, 2.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: size * 0.08,
                    offset: Offset(0, size * 0.04),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.music_note_rounded,
                  color: Colors.white.withValues(alpha: 0.95),
                  size: size * 0.22,
                ),
              ),
            ),
          ),

          // Apple Music typography for playlist cover when size is readable
          if (size >= 84)
            Positioned(
              left: size * 0.07,
              right: size * 0.07,
              bottom: size * 0.07,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: size * 0.055,
                  vertical: size * 0.035,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(size * 0.09),
                  color: Colors.black.withValues(alpha: 0.42),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: size * 0.05,
                      height: size * 0.05,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: palette.first,
                      ),
                    ),
                    SizedBox(width: size * 0.035),
                    Expanded(
                      child: Text(
                        'MELO PLAYLIST',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: (size * 0.06).clamp(8.0, 11.0),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Top edge highlight border
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.16),
                width: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppleVinylGroovesPainter extends CustomPainter {
  const _AppleVinylGroovesPainter({required this.accentColor});

  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final maxR = size.width * 0.48;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    final rings = [0.28, 0.42, 0.56, 0.70, 0.84, 0.96];
    for (var i = 0; i < rings.length; i++) {
      final r = maxR * rings[i];
      strokePaint.color = Colors.white.withValues(alpha: 0.04 + (i % 2 == 0 ? 0.04 : 0.02));
      strokePaint.strokeWidth = i % 2 == 0 ? 0.8 : 0.5;
      canvas.drawCircle(center, r, strokePaint);
    }

    final rect = Offset.zero & size;
    final sheenPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.14),
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.08),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, sheenPaint);
  }

  @override
  bool shouldRepaint(covariant _AppleVinylGroovesPainter oldDelegate) =>
      oldDelegate.accentColor != accentColor;
}
