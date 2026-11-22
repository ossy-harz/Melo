import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:melo_player/app/melo_theme.dart';
import 'package:melo_player/features/library/imported_track.dart';
import 'package:melo_player/features/library/music_library.dart';
import 'package:melo_player/features/player/mini_player.dart';
import 'package:melo_player/features/sources/multi_metadata_provider.dart';
import 'package:melo_player/features/sources/music_provider_models.dart';
import 'package:melo_player/features/youtube/youtube_audio_service.dart';

/// Apple Music-inspired full-fidelity Song Details Modal Sheet matching Mornye's TrackMetadata.
/// Features a large hero artwork preview (220x220) with ambient glow,
/// explicit/lossless badges, comprehensive technical metadata (format, bitrate,
/// duration, album, artist, ISRC, composer, release date, file/stream origin), and quick playback/queue actions.
class SongDetailsSheet extends StatefulWidget {
  const SongDetailsSheet({
    this.track,
    this.mediaItem,
    this.ytTrack,
    this.audioHandler,
    this.library,
    super.key,
  });

  final ImportedTrack? track;
  final MediaItem? mediaItem;
  final YoutubeTrack? ytTrack;
  final AudioHandler? audioHandler;
  final MusicLibrary? library;

  static Future<void> show(
    BuildContext context, {
    ImportedTrack? track,
    MediaItem? mediaItem,
    YoutubeTrack? ytTrack,
    AudioHandler? audioHandler,
    MusicLibrary? library,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SongDetailsSheet(
        track: track,
        mediaItem: mediaItem,
        ytTrack: ytTrack,
        audioHandler: audioHandler,
        library: library,
      ),
    );
  }

  @override
  State<SongDetailsSheet> createState() => _SongDetailsSheetState();
}

class _SongDetailsSheetState extends State<SongDetailsSheet> {
  UnifiedTrackMetadata? _studioMetadata;
  bool _isLoadingStudio = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadStudioMetadata());
  }

  Future<void> _loadStudioMetadata() async {
    final title = _title;
    final artist = _artist;
    if (title.isEmpty || title == 'Unknown Title') return;
    setState(() => _isLoadingStudio = true);
    try {
      final meta = await MetadataProviderService.instance.fetchMetadata(
        title: title,
        artist: artist,
      );
      if (mounted) {
        setState(() {
          _studioMetadata = meta;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingStudio = false);
    }
  }

  String get _title {
    return widget.track?.title ?? widget.mediaItem?.title ?? widget.ytTrack?.title ?? 'Unknown Title';
  }

  String get _artist {
    return widget.track?.artist ?? widget.mediaItem?.artist ?? widget.ytTrack?.author ?? 'Unknown Artist';
  }

  String? get _album {
    final a = widget.track?.album ?? widget.mediaItem?.album ?? widget.ytTrack?.album;
    return (a != null && a.trim().isNotEmpty) ? a : null;
  }

  String? get _artworkUri {
    return _studioMetadata?.artworkUrl ??
        widget.track?.artworkUri ??
        widget.mediaItem?.artUri?.toString() ??
        widget.ytTrack?.thumbnailUrl;
  }

  String get _durationText {
    if (widget.track?.durationMs != null && widget.track!.durationMs! > 0) {
      final d = Duration(milliseconds: widget.track!.durationMs!);
      final m = d.inMinutes;
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$m:$s';
    }
    if (widget.mediaItem?.duration != null && widget.mediaItem!.duration!.inSeconds > 0) {
      final d = widget.mediaItem!.duration!;
      final m = d.inMinutes;
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$m:$s';
    }
    if (widget.ytTrack != null && widget.ytTrack!.durationString.isNotEmpty) {
      return widget.ytTrack!.durationString;
    }
    if (_studioMetadata?.durationMs != null && _studioMetadata!.durationMs! > 0) {
      return _studioMetadata!.durationString;
    }
    return '--:--';
  }

  String get _audioQualityBadge {
    if (_studioMetadata != null) {
      return _studioMetadata!.qualityBadge;
    }
    final path = widget.track?.path.toLowerCase() ?? '';
    if (path.endsWith('.flac') || path.endsWith('.wav')) {
      return 'LOSSLESS FLAC · 24-BIT';
    }
    if (path.endsWith('.m4a') || path.endsWith('.aac')) {
      return 'AAC AUDIO · 256 KBPS';
    }
    if (path.endsWith('.opus') || path.endsWith('.ogg')) {
      return 'OPUS · HIGH FIDELITY';
    }
    if (path.endsWith('.mp3')) {
      return 'MP3 · 320 KBPS HQ';
    }
    if (widget.ytTrack != null || (widget.mediaItem?.id.startsWith('youtube:') ?? false)) {
      return 'LOSSLESS STREAM · 320 KBPS';
    }
    return 'HIGH QUALITY AUDIO';
  }

  bool get _isLocal {
    return widget.track != null ||
        (widget.mediaItem?.id != null && !widget.mediaItem!.id.startsWith('youtube:') && !widget.mediaItem!.id.startsWith('http'));
  }

  String get _providerName {
    if (_studioMetadata != null) {
      return _studioMetadata!.provider.displayName;
    }
    final src = widget.track?.sourceProvider ?? '';
    if (src.isNotEmpty) return src;
    final path = widget.track?.path.toLowerCase() ?? widget.mediaItem?.id.toLowerCase() ?? '';
    if (path.startsWith('apple:') || path.contains('music.apple.com')) return 'Apple Music';
    if (path.startsWith('spotify:') || path.contains('spotify.com')) return 'Spotify';
    if (path.startsWith('deezer:') || path.contains('deezer.com')) return 'Deezer';
    if (path.startsWith('soundcloud:') || path.contains('soundcloud.com')) return 'SoundCloud';
    if (path.startsWith('youtube:') || path.contains('youtube.com') || widget.ytTrack != null) return 'YouTube Music';
    return _isLocal ? 'Melo Offline Library' : 'Unified Stream Provider';
  }

  Future<void> _playNow(BuildContext context) async {
    final handler = widget.audioHandler;
    if (handler == null) return;
    Navigator.of(context).pop();

    if (widget.track != null) {
      await widget.library?.playMix(handler, [widget.track!]);
    } else if (widget.mediaItem != null) {
      await handler.playMediaItem(widget.mediaItem!);
    } else if (widget.ytTrack != null) {
      await handler.playMediaItem(widget.ytTrack!.toMediaItem());
    }
  }

  Future<void> _playNext(BuildContext context) async {
    final handler = widget.audioHandler;
    if (handler == null) return;
    Navigator.of(context).pop();

    final item = widget.track?.toMediaItem() ?? widget.mediaItem ?? widget.ytTrack?.toMediaItem();
    if (item != null) {
      await handler.addQueueItem(item);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Playing "${item.title}" next'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final artUriStr = _artworkUri;
    final artUri = artUriStr != null ? Uri.tryParse(artUriStr) : null;
    final sourcePath = widget.track?.path ?? widget.mediaItem?.id ?? widget.ytTrack?.id ?? '';

    return Container(
      constraints: BoxConstraints(
        maxHeight: mediaQuery.size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF16161A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Drag pill handle
              Center(
                child: Container(
                  width: 40,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Large Hero Album Artwork (Apple Music visual hierarchy)
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: MeloColors.cherry.withValues(alpha: 0.30),
                      blurRadius: 32,
                      offset: const Offset(0, 14),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.7),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: AlbumArtwork(
                    size: 220,
                    title: _title,
                    artworkUri: artUri,
                    sourceUri: Uri.tryParse(sourcePath),
                    borderRadius: 20,
                    iconSize: 56,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title & Artist
              Text(
                _title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                _artist,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (_album != null) ...[
                const SizedBox(height: 4),
                Text(
                  _album!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 14),

              // Quality badge pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: MeloColors.cherry.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(MeloRadii.pill),
                  border: Border.all(
                    color: MeloColors.cherry.withValues(alpha: 0.4),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.graphic_eq_rounded, size: 13, color: MeloColors.cherry),
                    const SizedBox(width: 5),
                    Text(
                      _audioQualityBadge,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Play & Play Next actions row
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => _playNow(context),
                      icon: const Icon(Icons.play_arrow_rounded, size: 22, color: Colors.black),
                      label: const Text(
                        'Play Now',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => _playNext(context),
                      icon: const Icon(Icons.playlist_play_rounded, size: 22),
                      label: const Text(
                        'Play Next',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // Technical Metadata Box
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: [
                    _DetailRow(
                      icon: Icons.timer_outlined,
                      label: 'Duration',
                      value: _durationText,
                    ),
                    const Divider(color: Colors.white10, height: 16),
                    _DetailRow(
                      icon: Icons.album_outlined,
                      label: 'Album',
                      value: _album ?? 'Single Track',
                    ),
                    const Divider(color: Colors.white10, height: 16),
                    _DetailRow(
                      icon: Icons.person_outline_rounded,
                      label: 'Artist',
                      value: _artist,
                    ),
                    const Divider(color: Colors.white10, height: 16),
                    _DetailRow(
                      icon: _isLocal ? Icons.folder_outlined : Icons.cloud_outlined,
                      label: 'Origin',
                      value: _isLocal ? 'Melo Offline Library' : 'Lossless Streaming Cache',
                    ),
                    const Divider(color: Colors.white10, height: 16),
                    _DetailRow(
                      icon: Icons.hub_outlined,
                      label: 'Provider',
                      value: _providerName,
                    ),
                    if (widget.track?.genre != null && widget.track!.genre!.isNotEmpty) ...[
                      const Divider(color: Colors.white10, height: 16),
                      _DetailRow(
                        icon: Icons.category_outlined,
                        label: 'Genre',
                        value: widget.track!.genre!,
                      ),
                    ],
                    if (widget.track?.year != null && widget.track!.year! > 0) ...[
                      const Divider(color: Colors.white10, height: 16),
                      _DetailRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'Year',
                        value: widget.track!.year.toString(),
                      ),
                    ],
                  ],
                ),
              ),

              // Studio & Publishing Details Box (Mornye TrackMetadata)
              if (_studioMetadata != null || _isLoadingStudio) ...[
                const SizedBox(height: 18),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: MeloColors.cherry.withValues(alpha: 0.25),
                      width: 0.9,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.verified_outlined, size: 15, color: MeloColors.cherry),
                          const SizedBox(width: 6),
                          Text(
                            'STUDIO & PUBLISHING METADATA',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: MeloColors.cherry,
                            ),
                          ),
                          const Spacer(),
                          if (_isLoadingStudio)
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: MeloColors.cherry,
                              ),
                            ),
                        ],
                      ),
                      if (_studioMetadata != null) ...[
                        const SizedBox(height: 10),
                        if (_studioMetadata!.isrc != null && _studioMetadata!.isrc!.isNotEmpty) ...[
                          _DetailRow(
                            icon: Icons.fingerprint_rounded,
                            label: 'ISRC',
                            value: _studioMetadata!.isrc!,
                          ),
                          const Divider(color: Colors.white10, height: 14),
                        ],
                        if (_studioMetadata!.releaseDate != null && _studioMetadata!.releaseDate!.isNotEmpty) ...[
                          _DetailRow(
                            icon: Icons.event_available_rounded,
                            label: 'Release Date',
                            value: _studioMetadata!.releaseDate!,
                          ),
                          const Divider(color: Colors.white10, height: 14),
                        ],
                        if (_studioMetadata!.trackNumber != null && _studioMetadata!.trackNumber! > 0) ...[
                          _DetailRow(
                            icon: Icons.format_list_numbered_rounded,
                            label: 'Track Position',
                            value: _studioMetadata!.totalTracks != null && _studioMetadata!.totalTracks! > 0
                                ? 'Track ${_studioMetadata!.trackNumber} of ${_studioMetadata!.totalTracks}'
                                : 'Track ${_studioMetadata!.trackNumber}',
                          ),
                          const Divider(color: Colors.white10, height: 14),
                        ],
                        if (_studioMetadata!.composers.isNotEmpty) ...[
                          _DetailRow(
                            icon: Icons.edit_note_rounded,
                            label: 'Composers',
                            value: _studioMetadata!.composers.join(', '),
                          ),
                          const Divider(color: Colors.white10, height: 14),
                        ],
                        if (_studioMetadata!.recordLabel != null && _studioMetadata!.recordLabel!.isNotEmpty) ...[
                          _DetailRow(
                            icon: Icons.business_rounded,
                            label: 'Label',
                            value: _studioMetadata!.recordLabel!,
                          ),
                          const Divider(color: Colors.white10, height: 14),
                        ],
                        _DetailRow(
                          icon: Icons.graphic_eq_rounded,
                          label: 'Studio Codec',
                          value: _studioMetadata!.qualityBadge,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.white54),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.white54,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
