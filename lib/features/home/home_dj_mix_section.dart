import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:melo_player/app/melo_theme.dart';
import 'package:melo_player/features/library/music_library.dart';
import 'package:melo_player/features/youtube/youtube_audio_service.dart';

class DjMixPreset {
  const DjMixPreset({
    required this.title,
    required this.djSubtitle,
    required this.durationBadge,
    required this.searchQuery,
    required this.gradient,
    required this.icon,
  });

  final String title;
  final String djSubtitle;
  final String durationBadge;
  final String searchQuery;
  final List<Color> gradient;
  final IconData icon;
}

class DjMixShowcaseSection extends StatefulWidget {
  const DjMixShowcaseSection({
    required this.audioHandler,
    required this.library,
    super.key,
  });

  final AudioHandler? audioHandler;
  final MusicLibrary? library;

  @override
  State<DjMixShowcaseSection> createState() => _DjMixShowcaseSectionState();
}

class _DjMixShowcaseSectionState extends State<DjMixShowcaseSection> {
  static const List<DjMixPreset> _presets = [
    DjMixPreset(
      title: 'Afrobeats & Amapiano Mix',
      djSubtitle: 'Live Club DJ Set · Turntable Transitions',
      durationBadge: '45+ MIN SET',
      searchQuery: 'Afrobeats Amapiano DJ Mix Nonstop Set 2025',
      gradient: [Color(0xFFFF4E50), Color(0xFFF9D423)],
      icon: Icons.album_rounded,
    ),
    DjMixPreset(
      title: 'Boiler Room Live Session',
      djSubtitle: 'Underground House & Electronic DJ Set',
      durationBadge: '60+ MIN SET',
      searchQuery: 'Boiler Room DJ Set House Techno Live Mix',
      gradient: [Color(0xFF1F1C2C), Color(0xFF928DAB)],
      icon: Icons.speaker_group_rounded,
    ),
    DjMixPreset(
      title: 'Hip-Hop & R&B Club Mix',
      djSubtitle: 'Mixed by DJs · Classics & Anthems',
      durationBadge: '50+ MIN SET',
      searchQuery: 'Hip Hop RnB Club DJ Mix Nonstop Turntable Set',
      gradient: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
      icon: Icons.queue_music_rounded,
    ),
    DjMixPreset(
      title: 'Afro House Sunset Set',
      djSubtitle: 'Deep Melodic & Tribal Rooftop Mix',
      durationBadge: '60+ MIN SET',
      searchQuery: 'Afro House Sunset DJ Mix Keinemusik Style Set',
      gradient: [Color(0xFFEB3349), Color(0xFFF45C43)],
      icon: Icons.wb_twilight_rounded,
    ),
    DjMixPreset(
      title: 'Dancehall & Party Megamix',
      djSubtitle: 'High-Energy Weekend DJ Blend',
      durationBadge: '45+ MIN SET',
      searchQuery: 'Dancehall Reggae Party DJ Mix Nonstop',
      gradient: [Color(0xFF11998E), Color(0xFF38EF7D)],
      icon: Icons.graphic_eq_rounded,
    ),
  ];

  String? _loadingMixTitle;

  Future<void> _startDjMix(DjMixPreset preset) async {
    final handler = widget.audioHandler;
    if (handler == null) return;
    if (_loadingMixTitle != null) return;

    setState(() => _loadingMixTitle = preset.title);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Loading DJ Mix: ${preset.title}...'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );

    try {
      final sets = await YoutubeAudioService.instance.searchDjMixes(
        preset.searchQuery,
      );
      if (sets.isEmpty) {
        throw StateError('No DJ mix streams found right now.');
      }
      final leadSet = sets.first;
      final localMatch = widget.library?.findMatchingLocalTrack(
        providerTrackId: leadSet.id,
        title: leadSet.title,
        artist: leadSet.author,
      );
      if (localMatch != null && widget.library != null) {
        final idx = widget.library!.indexOfTrack(localMatch.id);
        if (idx >= 0) {
          await widget.library!.playTrack(handler, idx);
          return;
        }
      }

      final queueItems = sets
          .take(5)
          .map(
            (setTrack) => MediaItem(
              id: 'youtube:${setTrack.id}',
              title: setTrack.title,
              artist: setTrack.author,
              album: 'DJ Mix Set',
              duration: setTrack.duration > Duration.zero
                  ? setTrack.duration
                  : null,
              artUri: setTrack.thumbnailUrl != null
                  ? Uri.tryParse(setTrack.thumbnailUrl!)
                  : null,
              extras: <String, Object?>{
                'videoId': setTrack.id,
                'source': 'youtube',
                'isDjMix': true,
              },
            ),
          )
          .toList(growable: false);

      await handler.updateQueue(queueItems);
      await handler.skipToQueueItem(0);
      await handler.play();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not start DJ mix: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) {
        setState(() => _loadingMixTitle = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.disc_full_rounded,
              size: 18,
              color: MeloColors.cherry,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'DJ Mix Sets · Mixed by DJs',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: MeloColors.cherry.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(MeloRadii.pill),
              ),
              child: const Text(
                'NON-STOP SETS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: MeloColors.cherry,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Real continuous DJ-mixed sets — not individual 3-minute songs.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 148,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: _presets.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final preset = _presets[index];
              final isLoading = _loadingMixTitle == preset.title;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _startDjMix(preset),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 224,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          preset.gradient.first.withValues(alpha: 0.36),
                          preset.gradient.last.withValues(alpha: 0.16),
                        ],
                      ),
                      border: Border.all(
                        color: preset.gradient.first.withValues(alpha: 0.38),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    preset.icon,
                                    color: Colors.white,
                                    size: 13,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    preset.durationBadge,
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 30,
                              height: 30,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: isLoading
                                  ? const Padding(
                                      padding: EdgeInsets.all(7),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.play_arrow_rounded,
                                      color: Colors.black,
                                      size: 18,
                                    ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              preset.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              preset.djSubtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.76),
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
        ),
      ],
    );
  }
}
