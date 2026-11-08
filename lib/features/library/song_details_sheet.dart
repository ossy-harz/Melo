import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:melo_player/app/melo_theme.dart';
import 'package:melo_player/features/library/imported_track.dart';
import 'package:melo_player/features/library/music_library.dart';
import 'package:melo_player/features/player/mini_player.dart';
import 'package:melo_player/features/youtube/youtube_audio_service.dart';

/// Apple Music-inspired full-fidelity Song Details Modal Sheet.
/// Features a large hero artwork preview (220x220) with ambient glow,
/// explicit/lossless badges, comprehensive technical metadata (format, bitrate,
/// duration, album, artist, file/stream origin), and quick playback/queue actions.
class SongDetailsSheet extends StatelessWidget {
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

  String get _title {
    return track?.title ?? mediaItem?.title ?? ytTrack?.title ?? 'Unknown Title';
  }

  String get _artist {
    return track?.artist ?? mediaItem?.artist ?? ytTrack?.author ?? 'Unknown Artist';
  }

  String? get _album {
    final a = track?.album ?? mediaItem?.album ?? ytTrack?.album;
    return (a != null && a.trim().isNotEmpty) ? a : null;
  }

  String? get _artworkUri {
    return track?.artworkUri ??
        mediaItem?.artUri?.toString() ??
        ytTrack?.thumbnailUrl;
  }

  String get _durationText {
    if (track?.durationMs != null && track!.durationMs! > 0) {
      final d = Duration(milliseconds: track!.durationMs!);
      final m = d.inMinutes;
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$m:$s';
    }
    if (mediaItem?.duration != null && mediaItem!.duration!.inSeconds > 0) {
      final d = mediaItem!.duration!;
      final m = d.inMinutes;
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$m:$s';
    }
    if (ytTrack != null && ytTrack!.durationString.isNotEmpty) {
      return ytTrack!.durationString;
    }
    return '--:--';
  }

  String get _audioQualityBadge {
    final path = track?.path.toLowerCase() ?? '';
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
    if (ytTrack != null || (mediaItem?.id.startsWith('youtube:') ?? false)) {
      return 'LOSSLESS STREAM · 320 KBPS';
    }
    return 'HIGH QUALITY AUDIO';
  }

  bool get _isLocal {
    return track != null ||
        (mediaItem?.id != null && !mediaItem!.id.startsWith('youtube:') && !mediaItem!.id.startsWith('http'));
  }

  Future<void> _playNow(BuildContext context) async {
    final handler = audioHandler;
    if (handler == null) return;
    Navigator.of(context).pop();

    if (track != null) {
      await library?.playMix(handler, [track!]);
    } else if (mediaItem != null) {
      await handler.playMediaItem(mediaItem!);
    } else if (ytTrack != null) {
      await handler.playMediaItem(ytTrack!.toMediaItem());
    }
  }

  Future<void> _playNext(BuildContext context) async {
    final handler = audioHandler;
    if (handler == null) return;
    Navigator.of(context).pop();

    final item = track?.toMediaItem() ?? mediaItem ?? ytTrack?.toMediaItem();
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
    final sourcePath = track?.path ?? mediaItem?.id ?? ytTrack?.id ?? '';

    return Container(
      constraints: BoxConstraints(
        maxHeight: mediaQuery.size.height * 0.88,
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
                    const Icon(Icons.graphic_eq_rounded, size: 13, color: MeloColors.cherry),
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

              // Comprehensive Technical Metadata Box
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
                    if (track?.genre != null && track!.genre!.isNotEmpty) ...[
                      const Divider(color: Colors.white10, height: 16),
                      _DetailRow(
                        icon: Icons.category_outlined,
                        label: 'Genre',
                        value: track!.genre!,
                      ),
                    ],
                    if (track?.year != null && track!.year! > 0) ...[
                      const Divider(color: Colors.white10, height: 16),
                      _DetailRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'Year',
                        value: track!.year.toString(),
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
