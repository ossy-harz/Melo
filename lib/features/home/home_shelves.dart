import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:melo_player/app/melo_theme.dart';
import 'package:melo_player/features/home/curated_playlist_preview_sheet.dart';
import 'package:melo_player/features/home/curated_playlist_screen.dart';
import 'package:melo_player/features/library/imported_track.dart';
import 'package:melo_player/features/library/music_library.dart';
import 'package:melo_player/features/player/mini_player.dart';
import 'package:melo_player/features/mix/smart_playlist_service.dart';

const List<CuratedPlaylistPreset> kRecommendedPlaylists = [
  CuratedPlaylistPreset(
    title: 'Afrobeats Essentials',
    curatorSubtitle: 'Lagos to the World · Burna, Rema, Tems, Asake',
    badge: 'ESSENTIALS',
    searchQuery: 'Afrobeats Hits 2025 Official Audio',
    gradient: [Color(0xFFFF6B35), Color(0xFF9E2A2B)],
    icon: Icons.bolt_rounded,
    coverUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=600&q=80',
    genre: 'Afrobeats',
  ),
  CuratedPlaylistPreset(
    title: 'Bongo & Kenyan Vibes',
    curatorSubtitle: 'Diamond, Harmonize, Sauti Sol, Otile Brown, Bien',
    badge: 'EAST AFRICA',
    searchQuery: 'Bongo Flava Kenyan Gengetone Hits Official Audio',
    gradient: [Color(0xFFE65100), Color(0xFFBF360C)],
    icon: Icons.music_note_rounded,
    coverUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=600&q=80',
    genre: 'Kenyan & Bongo',
  ),
  CuratedPlaylistPreset(
    title: "Today's Top Hits",
    curatorSubtitle: 'Melo Editorial · Global Chart Toppers',
    badge: 'UPDATED TODAY',
    searchQuery: 'Top Pop Global Hits 2025 Official Audio',
    gradient: [Color(0xFFE8173B), Color(0xFF6A051D)],
    icon: Icons.local_fire_department_rounded,
    coverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
    genre: 'Pop',
  ),
  CuratedPlaylistPreset(
    title: 'Rap Life',
    curatorSubtitle: 'Heavyweight Bars & Street Anthems',
    badge: 'HIP-HOP',
    searchQuery: 'Hip Hop Rap Hits 2025 Official Audio',
    gradient: [Color(0xFF232526), Color(0xFF414345)],
    icon: Icons.mic_external_on_rounded,
    coverUrl: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=600&q=80',
    genre: 'Hip-Hop',
  ),
  CuratedPlaylistPreset(
    title: 'Late Night R&B',
    curatorSubtitle: 'Smooth Soul & Midnight Moods',
    badge: 'CHILL & SOUL',
    searchQuery: 'Late Night R&B Soul Hits Official Audio',
    gradient: [Color(0xFF5F0F40), Color(0xFF310E68)],
    icon: Icons.nightlight_round,
    coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&q=80',
    genre: 'R&B',
  ),
  CuratedPlaylistPreset(
    title: 'Dancehall Heavyweights',
    curatorSubtitle: 'Vybz Kartel, Popcaan, Shenseea, Skillibeng',
    badge: 'DANCEHALL',
    searchQuery: 'Dancehall Kingston Hits 2025 Official Audio',
    gradient: [Color(0xFFE65100), Color(0xFFFF8F00)],
    icon: Icons.wb_sunny_rounded,
    coverUrl: 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=600&q=80',
    genre: 'Dancehall',
  ),
  CuratedPlaylistPreset(
    title: 'Roots & Lovers Reggae',
    curatorSubtitle: 'Bob Marley, Chronixx, Protoje, Koffee, Tarrus Riley',
    badge: 'REGGAE',
    searchQuery: 'Reggae Roots Conscious Hits Official Audio',
    gradient: [Color(0xFF1B5E20), Color(0xFF33691E)],
    icon: Icons.park_rounded,
    coverUrl: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=600&q=80',
    genre: 'Reggae',
  ),
  CuratedPlaylistPreset(
    title: 'Amapiano Grooves',
    curatorSubtitle: 'Log Drums & Private School Piano',
    badge: 'DANCE FLOOR',
    searchQuery: 'Amapiano Hits 2025 Official Audio',
    gradient: [Color(0xFF007991), Color(0xFF222E50)],
    icon: Icons.graphic_eq_rounded,
    coverUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=600&q=80',
    genre: 'Amapiano',
  ),
  CuratedPlaylistPreset(
    title: 'Reggae & Dancehall Energy',
    curatorSubtitle: 'Kingston Anthems & Island Heat',
    badge: 'ISLAND SOUNDS',
    searchQuery: 'Dancehall Reggae Hits 2025 Official Audio',
    gradient: [Color(0xFF1B5E20), Color(0xFFF57F17)],
    icon: Icons.wb_sunny_rounded,
    coverUrl: 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=600&q=80',
    genre: 'Dancehall',
  ),
  CuratedPlaylistPreset(
    title: 'Electronic & Dance Floor',
    curatorSubtitle: 'Peak Time Club & Synth Waves',
    badge: 'ELECTRONIC',
    searchQuery: 'EDM Electronic Dance Hits 2025 Official Audio',
    gradient: [Color(0xFF8A2387), Color(0xFFE94057)],
    icon: Icons.speaker_group_rounded,
    coverUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=600&q=80',
    genre: 'Dance',
  ),
  CuratedPlaylistPreset(
    title: 'Rock Classics & Alt',
    curatorSubtitle: 'Heavy Riffs & Timeless Anthems',
    badge: 'ROCK & ALT',
    searchQuery: 'Classic Rock Alternative Hits Official Audio',
    gradient: [Color(0xFF3E2723), Color(0xFF212121)],
    icon: Icons.electric_bolt_rounded,
    coverUrl: 'https://images.unsplash.com/photo-1498038432885-c6f3f1b912ee?w=600&q=80',
    genre: 'Rock',
  ),
  CuratedPlaylistPreset(
    title: 'Gospel & Elevation',
    curatorSubtitle: 'Soulful Worship & Uplifting Praise',
    badge: 'SPIRITUAL',
    searchQuery: 'Contemporary Gospel Praise Worship Hits',
    gradient: [Color(0xFF4A148C), Color(0xFF880E4F)],
    icon: Icons.favorite_border_rounded,
    coverUrl: 'https://images.unsplash.com/photo-1445743432342-eac500ce72b7?w=600&q=80',
    genre: 'Gospel',
  ),
  CuratedPlaylistPreset(
    title: 'Pure Focus',
    curatorSubtitle: 'Instrumental Beats for Deep Work',
    badge: 'INSTRUMENTAL',
    searchQuery: 'Chill Lofi Study Beats Instrumental',
    gradient: [Color(0xFF134E5E), Color(0xFF71B280)],
    icon: Icons.headphones_rounded,
    coverUrl: 'https://images.unsplash.com/photo-1518495973542-4542c06a5843?w=600&q=80',
    genre: 'Focus',
  ),
];

class TopPicksShelf extends StatelessWidget {
  const TopPicksShelf({
    required this.onPlayVibe,
    required this.onPlayPreset,
    super.key,
  });

  final ValueChanged<SmartVibe> onPlayVibe;
  final ValueChanged<CuratedPlaylistPreset> onPlayPreset;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top Picks for You',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: 22,
                letterSpacing: -0.5,
              ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 195,
          child: ListView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            children: [
              TopPickCard(
                categoryBadge: 'WE RECOMMEND',
                title: 'Rap Life: Best of 2026',
                description: 'Heavyweight bars and modern street anthems.',
                gradient: const [Color(0xFF2C3E50), Color(0xFF000000)],
                icon: Icons.local_fire_department_rounded,
                coverUrl: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=800&q=80',
                onTap: () => onPlayPreset(kRecommendedPlaylists[4]),
              ),
              const SizedBox(width: 14),
              TopPickCard(
                categoryBadge: 'MADE FOR YOU',
                title: "Personal Station",
                description:
                    'Continuous flow tailored to your favorites & library.',
                gradient: const [
                  Color(0xFFD31027),
                  Color(0xFFEA384D),
                  Color(0xFF2B0A12),
                ],
                icon: Icons.graphic_eq_rounded,
                onTap: () => onPlayVibe(SmartVibe.dailyFlow),
              ),
              const SizedBox(width: 14),
              TopPickCard(
                categoryBadge: 'TRENDING',
                title: 'Afrobeats Essentials',
                description: 'Global heat: Burna, Rema, Tems, Asake & more.',
                gradient: const [Color(0xFFF37335), Color(0xFFFDC830)],
                icon: Icons.bolt_rounded,
                coverUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=800&q=80',
                onTap: () => onPlayPreset(kRecommendedPlaylists[1]),
              ),
              const SizedBox(width: 14),
              TopPickCard(
                categoryBadge: 'INSTRUMENTAL',
                title: 'Deep Focus & Study',
                description: 'Ambient lofi and calm instrumental grooves.',
                gradient: const [Color(0xFF0B486B), Color(0xFFF56217)],
                icon: Icons.headphones_rounded,
                coverUrl: 'https://images.unsplash.com/photo-1518495973542-4542c06a5843?w=800&q=80',
                onTap: () => onPlayVibe(SmartVibe.deepFocus),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class TopPickCard extends StatelessWidget {
  const TopPickCard({
    required this.categoryBadge,
    required this.title,
    required this.description,
    required this.gradient,
    required this.icon,
    required this.onTap,
    this.coverUrl,
    super.key,
  });

  final String categoryBadge;
  final String title;
  final String description;
  final List<Color> gradient;
  final IconData icon;
  final VoidCallback onTap;
  final String? coverUrl;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 250,
          height: 195,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            boxShadow: [
              BoxShadow(
                color: gradient.first.withValues(alpha: 0.32),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (coverUrl != null)
                  Image.network(
                    coverUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.35),
                        Colors.black.withValues(alpha: 0.85),
                      ],
                      stops: const [0.0, 1.0],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              categoryBadge,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white.withValues(alpha: 0.9),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          Icon(
                            icon,
                            color: Colors.white.withValues(alpha: 0.9),
                            size: 20,
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.15,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.8),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ],
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

class RecentlyPlayedShelf extends StatelessWidget {
  const RecentlyPlayedShelf({
    required this.library,
    required this.onPlay,
    required this.onOpenLibrary,
    super.key,
  });

  final MusicLibrary library;
  final ValueChanged<ImportedTrack> onPlay;
  final VoidCallback onOpenLibrary;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: library,
      builder: (context, _) {
        final allTracks = library.tracks;
        if (allTracks.isEmpty) return const SizedBox.shrink();

        final recents = allTracks.reversed.take(10).toList(growable: false);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onOpenLibrary,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Recently Played',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                            letterSpacing: -0.5,
                          ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 24,
                      color: Colors.white70,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 182,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: recents.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final track = recents[index];
                  return SizedBox(
                    width: 128,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => onPlay(track),
                        onLongPress: () => TrackDetailsSheet.show(
                          context,
                          track.toMediaItem(),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AlbumArtwork(
                              size: 128,
                              title: track.title,
                              artworkUri: track.artworkUri != null
                                  ? Uri.tryParse(track.artworkUri!)
                                  : null,
                              sourceUri: Uri.tryParse(track.path),
                              borderRadius: 14,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              displayArtistName(track.artist),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.55),
                              ),
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
      },
    );
  }
}

class StationsForYouShelf extends StatelessWidget {
  const StationsForYouShelf({
    required this.onPlayVibe,
    this.library,
    super.key,
  });

  final ValueChanged<SmartVibe> onPlayVibe;
  final MusicLibrary? library;

  @override
  Widget build(BuildContext context) {
    final tracks = library?.tracks ?? const [];
    final favorites = library?.favoriteTracks ?? const [];

    final personalTrack = favorites.isNotEmpty
        ? favorites.first
        : (tracks.isNotEmpty ? tracks.first : null);
    final discoveryTrack = tracks.length > 1 ? tracks[1] : null;
    final focusTrack = tracks.length > 2 ? tracks[2] : null;
    final chillTrack = tracks.length > 3 ? tracks[3] : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Stations for You',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      letterSpacing: -0.5,
                    ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: MeloColors.cherry.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sensors_rounded,
                      size: 13, color: MeloColors.cherry),
                  SizedBox(width: 4),
                  Text(
                    'LIVE RADIO',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: MeloColors.cherry,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 194,
          child: ListView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            children: [
              StationTile(
                title: "Personal Station",
                subtitle: 'Radio Station · Personal flow',
                artworkTrack: personalTrack,
                defaultArtworkUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&q=80',
                gradient: const [
                  Color(0xFFE52D27),
                  Color(0xFFB31217),
                  Color(0xFF1E0608),
                ],
                icon: Icons.graphic_eq_rounded,
                onTap: () => onPlayVibe(SmartVibe.dailyFlow),
              ),
              const SizedBox(width: 14),
              StationTile(
                title: 'Discovery Station',
                subtitle: 'Radio Station · Exploration',
                artworkTrack: discoveryTrack,
                defaultArtworkUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=600&q=80',
                gradient: const [
                  Color(0xFF4A00E0),
                  Color(0xFF8E2DE2),
                  Color(0xFF0F051D),
                ],
                icon: Icons.radar_rounded,
                onTap: () => onPlayVibe(SmartVibe.highEnergy),
              ),
              const SizedBox(width: 14),
              StationTile(
                title: 'Deep Focus & Study',
                subtitle: 'Radio Station · Instrumental',
                artworkTrack: focusTrack,
                defaultArtworkUrl: 'https://images.unsplash.com/photo-1518495973542-4542c06a5843?w=600&q=80',
                gradient: const [
                  Color(0xFF134E5E),
                  Color(0xFF71B280),
                  Color(0xFF061A21),
                ],
                icon: Icons.headphones_rounded,
                onTap: () => onPlayVibe(SmartVibe.deepFocus),
              ),
              const SizedBox(width: 14),
              StationTile(
                title: 'Late Night Chill',
                subtitle: 'Radio Station · Midnight soul',
                artworkTrack: chillTrack,
                defaultArtworkUrl: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=600&q=80',
                gradient: const [
                  Color(0xFF3A1C71),
                  Color(0xFFD76D77),
                  Color(0xFF190A2E),
                ],
                icon: Icons.nightlight_round,
                onTap: () => onPlayVibe(SmartVibe.lateNightChill),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class StationTile extends StatelessWidget {
  const StationTile({
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.icon,
    required this.onTap,
    this.artworkTrack,
    this.defaultArtworkUrl,
    super.key,
  });

  final String title;
  final String subtitle;
  final List<Color> gradient;
  final IconData icon;
  final VoidCallback onTap;
  final ImportedTrack? artworkTrack;
  final String? defaultArtworkUrl;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 136,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 136,
                height: 136,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradient,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: gradient.first.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    children: [
                      if (artworkTrack != null)
                        Positioned.fill(
                          child: AlbumArtwork(
                            size: 136,
                            title: artworkTrack!.title,
                            artworkUri: artworkTrack!.artworkUri != null
                                ? Uri.tryParse(artworkTrack!.artworkUri!)
                                : null,
                            sourceUri: Uri.tryParse(artworkTrack!.path),
                            borderRadius: 0,
                          ),
                        )
                      else if (defaultArtworkUrl != null)
                        Positioned.fill(
                          child: Image.network(
                            defaultArtworkUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => CustomPaint(
                              painter: FoldedPrismPainter(
                                color: Colors.white.withValues(alpha: 0.14),
                              ),
                            ),
                          ),
                        )
                      else
                        Positioned.fill(
                          child: CustomPaint(
                            painter: FoldedPrismPainter(
                              color: Colors.white.withValues(alpha: 0.14),
                            ),
                          ),
                        ),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.72),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'melo',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        bottom: 12,
                        child: Icon(
                          icon,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.black,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Authentic Apple Music dynamic 3D chevron origami waves (Screenshot 3).
/// Renders multi-layered perspective folds with gradients and specular highlights.
class AppleStationWavePainter extends CustomPainter {
  const AppleStationWavePainter({
    required this.color,
    this.accentColor,
  });

  final Color color;
  final Color? accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final accent = accentColor ?? Colors.white;

    // Layer 1: Deep shadow angled chevron
    final p1 = Path()
      ..moveTo(w * 0.15, h)
      ..lineTo(w * 0.95, h * 0.52)
      ..lineTo(w * 0.95, h * 0.65)
      ..lineTo(w * 0.25, h)
      ..close();
    canvas.drawPath(
      p1,
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );

    // Layer 2: Main dynamic folded chevron wing
    final p2 = Path()
      ..moveTo(0, h * 0.30)
      ..lineTo(w * 0.70, h * 0.50)
      ..lineTo(0, h * 0.78)
      ..close();
    canvas.drawPath(
      p2,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.45),
            color.withValues(alpha: 0.20),
          ],
        ).createShader(Rect.fromLTWH(0, h * 0.3, w * 0.7, h * 0.48)),
    );

    // Layer 3: Secondary perspective wing (origami fold)
    final p3 = Path()
      ..moveTo(w * 0.32, h * 0.15)
      ..lineTo(w, h * 0.50)
      ..lineTo(w * 0.32, h * 0.88)
      ..close();
    canvas.drawPath(
      p3,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Colors.white.withValues(alpha: 0.28),
            Colors.white.withValues(alpha: 0.08),
          ],
        ).createShader(Rect.fromLTWH(w * 0.32, h * 0.15, w * 0.68, h * 0.73)),
    );

    // Specular glossy edge
    final edgePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.40)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(w * 0.32, h * 0.15),
      Offset(w, h * 0.50),
      edgePaint,
    );
  }

  @override
  bool shouldRepaint(covariant AppleStationWavePainter oldDelegate) =>
      oldDelegate.color != color;
}

class FoldedPrismPainter extends AppleStationWavePainter {
  const FoldedPrismPainter({required super.color, super.accentColor});
}

class RecommendedPlaylistsSection extends StatefulWidget {
  const RecommendedPlaylistsSection({
    required this.audioHandler,
    required this.library,
    super.key,
  });

  final AudioHandler? audioHandler;
  final MusicLibrary? library;

  @override
  State<RecommendedPlaylistsSection> createState() =>
      _RecommendedPlaylistsSectionState();
}

class _RecommendedPlaylistsSectionState
    extends State<RecommendedPlaylistsSection> {
  String _selectedGenre = 'All';

  static const List<String> _genres = [
    'All',
    'Afrobeats',
    'Kenyan & Bongo',
    'Dancehall',
    'Reggae',
    'Pop',
    'Hip-Hop',
    'R&B',
    'Amapiano',
    'Dance',
    'Rock',
    'Gospel',
    'Focus',
  ];

  void _openPlaylist(BuildContext context, CuratedPlaylistPreset preset) {
    showCuratedPlaylistPreviewSheet(
      context: context,
      preset: preset,
      audioHandler: widget.audioHandler,
      library: widget.library,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final filteredPlaylists = _selectedGenre == 'All'
        ? kRecommendedPlaylists
        : kRecommendedPlaylists
            .where((p) => p.genre.toLowerCase() == _selectedGenre.toLowerCase())
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.stars_rounded,
              size: 19,
              color: MeloColors.cherry,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Recommended Playlists',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            Text(
              'Melo Curated Picks',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: _genres.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final genre = _genres[index];
              final isSelected = genre == _selectedGenre;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(17),
                  onTap: () => setState(() => _selectedGenre = genre),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(17),
                      color: isSelected
                          ? MeloColors.cherry
                          : colors.surfaceContainerHigh.withValues(alpha: 0.6),
                      border: Border.all(
                        color: isSelected
                            ? MeloColors.cherrySoft
                            : Colors.white.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        genre,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? Colors.white : Colors.white70,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 204,
          child: filteredPlaylists.isEmpty
              ? Center(
                  child: Text(
                    'No playlists found for $_selectedGenre',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  itemCount: filteredPlaylists.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final preset = filteredPlaylists[index];
              return SizedBox(
                width: 156,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _openPlaylist(context, preset),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 156,
                          height: 156,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (preset.coverUrl != null &&
                                    preset.coverUrl!.isNotEmpty)
                                  Image.network(
                                    preset.coverUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: preset.gradient,
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: preset.gradient,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          preset.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          preset.curatorSubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: colors.onSurfaceVariant,
                                fontSize: 11.5,
                              ),
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

class ArtistRadioItem {
  const ArtistRadioItem({
    required this.name,
    required this.avatarUrl,
    required this.genres,
  });

  final String name;
  final String avatarUrl;
  final String genres;
}

/// Dynamic horizontal artist radio carousel (Spotify Signature Artist Stations)
class ArtistRadioShelf extends StatelessWidget {
  const ArtistRadioShelf({
    required this.onOpenArtistRadio,
    this.library,
    super.key,
  });

  final ValueChanged<String> onOpenArtistRadio;
  final MusicLibrary? library;

  static const List<ArtistRadioItem> _defaultArtists = [
    ArtistRadioItem(
      name: 'King Saha',
      avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&q=80',
      genres: 'Afro-Pop · Uganda',
    ),
    ArtistRadioItem(
      name: 'Joshua Baraka',
      avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&q=80',
      genres: 'R&B · Afrobeats',
    ),
    ArtistRadioItem(
      name: 'Burna Boy',
      avatarUrl: 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=400&q=80',
      genres: 'Afro-Fusion · Lagos',
    ),
    ArtistRadioItem(
      name: 'Kendrick Lamar',
      avatarUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=400&q=80',
      genres: 'Hip-Hop · Rap Life',
    ),
    ArtistRadioItem(
      name: 'Asake',
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&q=80',
      genres: 'Amapiano · Fujipiano',
    ),
    ArtistRadioItem(
      name: 'SZA',
      avatarUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=400&q=80',
      genres: 'Contemporary R&B',
    ),
    ArtistRadioItem(
      name: 'Drake',
      avatarUrl: 'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?w=400&q=80',
      genres: 'Hip-Hop · Melodic Rap',
    ),
    ArtistRadioItem(
      name: 'Tems',
      avatarUrl: 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=400&q=80',
      genres: 'Soul · Afrobeats',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    // Collect distinct artist names from library if available
    final libraryArtists = library?.tracks
            .map((t) => t.artist.trim())
            .where((a) => a.isNotEmpty && a.toLowerCase() != 'unknown artist')
            .toSet()
            .take(6)
            .toList() ??
        const <String>[];

    final artists = <ArtistRadioItem>[
      ...libraryArtists.map(
        (a) => ArtistRadioItem(
          name: a,
          avatarUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=400&q=80',
          genres: 'From Your Library',
        ),
      ),
      ..._defaultArtists.where((d) => !libraryArtists.contains(d.name)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.sensors_rounded,
              size: 20,
              color: MeloColors.cherry,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Artist Radio',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      letterSpacing: -0.5,
                    ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: MeloColors.cherry.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.radio_rounded, size: 12, color: MeloColors.cherry),
                  SizedBox(width: 4),
                  Text(
                    'ENDLESS STATIONS',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: MeloColors.cherry,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: artists.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final artist = artists[index];
              return SizedBox(
                width: 112,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => onOpenArtistRadio(artist.name),
                    child: Column(
                      children: [
                        // Circular Artist Avatar with Ambient Glow
                        Container(
                          width: 104,
                          height: 104,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.45),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  artist.avatarUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    color: colors.surfaceContainerHigh,
                                    child: const Icon(Icons.person_rounded, size: 40, color: Colors.white54),
                                  ),
                                ),
                                Positioned(
                                  bottom: 4,
                                  right: 4,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: MeloColors.cherry,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.play_arrow_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          artist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          artist.genres,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
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
