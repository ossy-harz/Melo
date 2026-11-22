import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:melo_player/app/melo_theme.dart';
import 'package:melo_player/features/home/curated_playlist_screen.dart';
import 'package:melo_player/features/library/imported_track.dart';
import 'package:melo_player/features/library/music_library.dart';
import 'package:melo_player/features/library/song_metadata_enricher.dart';
import 'package:melo_player/features/player/melo_audio_handler.dart';
import 'package:melo_player/features/player/mini_player.dart';
import 'package:melo_player/features/mix/smart_playlist_service.dart';
import 'package:melo_player/features/settings/spotify_settings_screen.dart';
import 'package:melo_player/features/sources/external_feed_service.dart';
import 'package:melo_player/features/sources/multi_download_provider.dart';
import 'package:melo_player/features/sources/music_provider_models.dart';
import 'package:melo_player/features/spotify/spotify_service.dart';
import 'package:melo_player/features/youtube/youtube_audio_service.dart';

final List<CuratedPlaylistPreset> kRecommendedPlaylists = [
  CuratedPlaylistPreset(
    title: 'Matata Radio',
    curatorSubtitle: 'With KODONGKLAN, Sauti Sol, Chris Kaiga and more',
    badge: 'MADE FOR YOU',
    searchQuery: 'Matata Bien Sauti Sol Chris Kaiga Kenyan Hits Official Audio',
    gradient: [MeloColors.cherry, MeloColors.cherryDeep],
    icon: Icons.radio_rounded,
    coverUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=600&q=80',
    genre: 'Kenyan & Bongo',
  ),
  CuratedPlaylistPreset(
    title: 'Arbantone & Kenyan Wave',
    curatorSubtitle: 'Gody Tennor, Benzema, Boutross, Trio Mio',
    badge: 'KENYAN HEAT',
    searchQuery: 'Arbantone Gengetone Kenyan Hits 2025 Official Audio',
    gradient: [Color(0xFF8A0E22), Color(0xFF0A0A0C)],
    icon: Icons.bolt_rounded,
    coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&q=80',
    genre: 'Kenyan & Bongo',
  ),
  CuratedPlaylistPreset(
    title: 'Bongo & Kenyan Vibes',
    curatorSubtitle: 'Diamond, Harmonize, Sauti Sol, Otile Brown, Bien',
    badge: 'EAST AFRICA',
    searchQuery: 'Bongo Flava Kenyan Hits Official Audio',
    gradient: [Color(0xFF6E0B1C), Color(0xFF0D0205)],
    icon: Icons.music_note_rounded,
    coverUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=600&q=80',
    genre: 'Kenyan & Bongo',
  ),
  CuratedPlaylistPreset(
    title: 'Dancehall Heavyweights',
    curatorSubtitle: 'Vybz Kartel, Popcaan, Shenseea, Masicka, Skillibeng',
    badge: 'DANCEHALL',
    searchQuery: 'Dancehall Vybz Kartel Popcaan Masicka Official Audio',
    gradient: [MeloColors.cherry, Color(0xFF1A0408)],
    icon: Icons.wb_sunny_rounded,
    coverUrl: 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=600&q=80',
    genre: 'Dancehall',
  ),
  CuratedPlaylistPreset(
    title: 'Kingston Street Riddims',
    curatorSubtitle: 'Byron Messia, Chronic Law, Valiant, Teejay',
    badge: 'RIDDIM MIX',
    searchQuery: 'Jamaica Dancehall Riddim 2025 Official Audio',
    gradient: [Color(0xFF7A0C1E), Color(0xFF080808)],
    icon: Icons.speaker_group_rounded,
    coverUrl: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=600&q=80',
    genre: 'Dancehall',
  ),
  CuratedPlaylistPreset(
    title: 'New Wave Bashment',
    curatorSubtitle: 'Modern club bashment & Afro-Dancehall',
    badge: 'BASHMENT',
    searchQuery: 'Shenseea Skillibeng Afro Dancehall Official Audio',
    gradient: [Color(0xFF4A0915), Color(0xFF000000)],
    icon: Icons.local_fire_department_rounded,
    coverUrl: 'https://images.unsplash.com/photo-1571266028243-e4733b0f0bb0?w=600&q=80',
    genre: 'Dancehall',
  ),
  CuratedPlaylistPreset(
    title: 'Afrobeats Essentials',
    curatorSubtitle: 'Lagos to the World · Burna, Rema, Tems, Asake',
    badge: 'ESSENTIALS',
    searchQuery: 'Afrobeats Hits 2025 Official Audio',
    gradient: [MeloColors.cherry, MeloColors.cherryDeep],
    icon: Icons.bolt_rounded,
    coverUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=600&q=80',
    genre: 'Afrobeats',
  ),
  CuratedPlaylistPreset(
    title: "Today's Top Hits",
    curatorSubtitle: 'Melo Editorial · Global Chart Toppers',
    badge: 'UPDATED TODAY',
    searchQuery: 'Top Pop Global Hits 2025 Official Audio',
    gradient: [Color(0xFFFA243C), Color(0xFF4A0812)],
    icon: Icons.local_fire_department_rounded,
    coverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
    genre: 'Pop',
  ),
  CuratedPlaylistPreset(
    title: 'Rap Life',
    curatorSubtitle: 'Kendrick Lamar, Drake, Future, Travis Scott',
    badge: 'HIP-HOP',
    searchQuery: 'Hip Hop Rap Hits 2025 Official Audio',
    gradient: [Color(0xFF1C1C1E), Color(0xFF000000)],
    icon: Icons.mic_external_on_rounded,
    coverUrl: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=600&q=80',
    genre: 'Hip-Hop',
  ),
  CuratedPlaylistPreset(
    title: 'Late Night R&B',
    curatorSubtitle: 'SZA, Summer Walker, Brent Faiyaz, Bryson Tiller',
    badge: 'CHILL & SOUL',
    searchQuery: 'Late Night R&B Soul Hits Official Audio',
    gradient: [Color(0xFF4A0915), Color(0xFF080808)],
    icon: Icons.nightlight_round,
    coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&q=80',
    genre: 'R&B',
  ),
  CuratedPlaylistPreset(
    title: 'Roots & Lovers Reggae',
    curatorSubtitle: 'Bob Marley, Chronixx, Protoje, Koffee, Tarrus Riley',
    badge: 'REGGAE',
    searchQuery: 'Reggae Roots Conscious Hits Official Audio',
    gradient: [Color(0xFF2C2C2E), Color(0xFF0A0A0C)],
    icon: Icons.park_rounded,
    coverUrl: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=600&q=80',
    genre: 'Reggae',
  ),
  CuratedPlaylistPreset(
    title: 'Amapiano Grooves',
    curatorSubtitle: 'Tyler ICU, Kabza De Small, Uncle Waffles, Tyla',
    badge: 'DANCE FLOOR',
    searchQuery: 'Amapiano Hits 2025 Official Audio',
    gradient: [Color(0xFF7A0C1E), Color(0xFF000000)],
    icon: Icons.graphic_eq_rounded,
    coverUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=600&q=80',
    genre: 'Amapiano',
  ),
  CuratedPlaylistPreset(
    title: 'Electronic & Dance Floor',
    curatorSubtitle: 'Peak Time Club & Synth Waves',
    badge: 'ELECTRONIC',
    searchQuery: 'EDM Electronic Dance Hits 2025 Official Audio',
    gradient: [Color(0xFFFA243C), Color(0xFF140307)],
    icon: Icons.speaker_group_rounded,
    coverUrl: 'https://images.unsplash.com/photo-1571266028243-e4733b0f0bb0?w=600&q=80',
    genre: 'Dance',
  ),
  CuratedPlaylistPreset(
    title: 'Rock Classics & Alt',
    curatorSubtitle: 'Heavy Riffs & Timeless Anthems',
    badge: 'ROCK & ALT',
    searchQuery: 'Classic Rock Alternative Hits Official Audio',
    gradient: [Color(0xFF242426), Color(0xFF000000)],
    icon: Icons.electric_bolt_rounded,
    coverUrl: 'https://images.unsplash.com/photo-1498038432885-c6f3f1b912ee?w=600&q=80',
    genre: 'Rock',
  ),
  CuratedPlaylistPreset(
    title: 'Gospel & Elevation',
    curatorSubtitle: 'Soulful Worship & Uplifting Praise',
    badge: 'SPIRITUAL',
    searchQuery: 'Contemporary Gospel Praise Worship Hits',
    gradient: [Color(0xFF5E0A19), Color(0xFF080808)],
    icon: Icons.favorite_border_rounded,
    coverUrl: 'https://images.unsplash.com/photo-1445743432342-eac500ce72b7?w=600&q=80',
    genre: 'Gospel',
  ),
  CuratedPlaylistPreset(
    title: 'Pure Focus',
    curatorSubtitle: 'Instrumental Beats for Deep Work',
    badge: 'INSTRUMENTAL',
    searchQuery: 'Chill Lofi Study Beats Instrumental',
    gradient: [Color(0xFF1C1C1E), Color(0xFF080808)],
    icon: Icons.headphones_rounded,
    coverUrl: 'https://images.unsplash.com/photo-1518495973542-4542c06a5843?w=600&q=80',
    genre: 'Focus',
  ),
  CuratedPlaylistPreset(
    title: 'Music & Creator Podcasts',
    curatorSubtitle: 'Full studio sessions, artist interviews & deep dives',
    badge: 'PODCASTS',
    searchQuery: 'music producer interview podcast full episode',
    gradient: [Color(0xFF6E0B1C), Color(0xFF000000)],
    icon: Icons.podcasts_rounded,
    coverUrl: 'https://images.unsplash.com/photo-1590602847861-f357a9332bbc?w=600&q=80',
    genre: 'Podcasts',
    allowLongEpisodes: true,
  ),
  CuratedPlaylistPreset(
    title: 'Deep Talks & Culture Pods',
    curatorSubtitle: 'Storytelling, culture & long-form conversations',
    badge: 'EPISODES',
    searchQuery: 'culture storytelling podcast full episode',
    gradient: [Color(0xFF242426), Color(0xFF000000)],
    icon: Icons.mic_rounded,
    coverUrl: 'https://images.unsplash.com/photo-1478737270239-2f02b77fc618?w=600&q=80',
    genre: 'Podcasts',
    allowLongEpisodes: true,
  ),
];

class TopPicksShelf extends StatefulWidget {
  const TopPicksShelf({
    required this.onPlayVibe,
    required this.onPlayPreset,
    this.library,
    this.onOpenArtistRadio,
    this.refreshGeneration = 0,
    super.key,
  });

  static final ValueNotifier<String> selectedGenreNotifier =
      ValueNotifier<String>('For You');

  final ValueChanged<SmartVibe> onPlayVibe;
  final ValueChanged<CuratedPlaylistPreset> onPlayPreset;
  final MusicLibrary? library;
  final ValueChanged<String>? onOpenArtistRadio;
  final int refreshGeneration;

  @override
  State<TopPicksShelf> createState() => _TopPicksShelfState();
}

int _timeOfDayPresetBoost(CuratedPlaylistPreset preset, [DateTime? now]) {
  final hour = (now ?? DateTime.now()).hour;
  final genre = preset.genre.toLowerCase();
  if (hour >= 4 && hour < 12) {
    return (genre.contains('focus') ||
            genre.contains('gospel') ||
            genre.contains('pop') ||
            genre.contains('afro') ||
            genre.contains('kenyan') ||
            genre.contains('reggae'))
        ? 2
        : 0;
  }
  if (hour >= 12 && hour < 17) {
    return (genre.contains('afro') ||
            genre.contains('pop') ||
            genre.contains('kenyan') ||
            genre.contains('dancehall') ||
            genre.contains('amapiano') ||
            genre.contains('hip'))
        ? 2
        : 0;
  }
  if (hour >= 17 && hour < 22) {
    return (genre.contains('dancehall') ||
            genre.contains('amapiano') ||
            genre.contains('dance') ||
            genre.contains('hip') ||
            genre.contains('afro') ||
            genre.contains('kenyan'))
        ? 2
        : 0;
  }
  return (genre.contains('r&b') ||
          genre.contains('focus') ||
          genre.contains('reggae') ||
          genre.contains('podcast') ||
          genre.contains('rock'))
      ? 2
      : 0;
}

class _TopPickEntry {
  const _TopPickEntry({
    required this.categoryBadge,
    required this.title,
    required this.description,
    required this.gradient,
    required this.icon,
    required this.onTap,
    this.coverUrl,
    this.preset,
  });

  final String categoryBadge;
  final String title;
  final String description;
  final List<Color> gradient;
  final IconData icon;
  final VoidCallback onTap;
  final String? coverUrl;
  final CuratedPlaylistPreset? preset;
}

/// Stateful vibe-tuning dialog so [_controller] survives route pop & IME close animations.
class _TuneVibeDialog extends StatefulWidget {
  const _TuneVibeDialog();

  @override
  State<_TuneVibeDialog> createState() => _TuneVibeDialogState();
}

class _TuneVibeDialogState extends State<_TuneVibeDialog> {
  static const List<String> _quickIdeas = [
    'Dancehall',
    '90s Dancehall',
    'Arbantone',
    'Rhumba',
    'Mugithi',
    'Amapiano',
    'UK Drill',
    'Lovers Rock',
  ];

  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit([String? explicitValue]) {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop((explicitValue ?? _controller.text).trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      backgroundColor: const Color(0xFF141416),
      title: const Text(
        'Influence Your Top Picks',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter any genre, mood, artist, or playlist vibe to generate dynamic Top Picks.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(color: Colors.white),
            onSubmitted: _submit,
            decoration: InputDecoration(
              hintText: 'e.g. Dancehall, Arbantone, Rhumba...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.black,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white24),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _quickIdeas
                .map(
                  (idea) => ActionChip(
                    backgroundColor: Colors.black,
                    side: const BorderSide(color: Colors.white24),
                    label: Text(
                      idea,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                      ),
                    ),
                    onPressed: () => _submit(idea),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            FocusScope.of(context).unfocus();
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: MeloColors.cherry,
            foregroundColor: Colors.white,
          ),
          onPressed: _submit,
          child: const Text('Tune Mix'),
        ),
      ],
    );
  }
}

class _TopPicksShelfState extends State<TopPicksShelf> {
  static const String _customVibesPrefKey = 'tone_custom_home_vibes';
  static const String _selectedVibePrefKey = 'tone_selected_home_vibe';

  static const List<String> _defaultGenres = [
    'For You',
    'Dancehall',
    'Kenyan & Bongo',
    'Afrobeats',
    'Amapiano',
    'Reggae',
    'Hip-Hop',
    'R&B & Soul',
    'Party & Club',
    'Chill & Focus',
    'Podcasts',
  ];

  List<String> _customVibes = const [];
  int _rotationSeed = 0;
  String? _preloadedSignature;

  @override
  void initState() {
    super.initState();
    TopPicksShelf.selectedGenreNotifier.addListener(_onGenreChanged);
    SpotifyService.instance.authState.addListener(_onSpotifyChanged);
    SpotifyService.instance.feedRevision.addListener(_onSpotifyChanged);
    unawaited(_loadSavedVibePrefs());
  }

  @override
  void didUpdateWidget(covariant TopPicksShelf oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshGeneration != widget.refreshGeneration) {
      setState(() => _rotationSeed++);
    }
  }

  @override
  void dispose() {
    TopPicksShelf.selectedGenreNotifier.removeListener(_onGenreChanged);
    SpotifyService.instance.authState.removeListener(_onSpotifyChanged);
    SpotifyService.instance.feedRevision.removeListener(_onSpotifyChanged);
    super.dispose();
  }

  void _onGenreChanged() {
    if (mounted) setState(() {});
  }

  void _onSpotifyChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadSavedVibePrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customJson = prefs.getString(_customVibesPrefKey);
      final savedSelected = prefs.getString(_selectedVibePrefKey);
      final parsedCustom = <String>[];
      if (customJson != null && customJson.isNotEmpty) {
        final decoded = jsonDecode(customJson);
        if (decoded is List) {
          for (final item in decoded) {
            final clean = item.toString().trim();
            if (clean.isNotEmpty) parsedCustom.add(clean);
          }
        }
      }
      if (!mounted) return;
      setState(() => _customVibes = parsedCustom);
      if (savedSelected != null && savedSelected.isNotEmpty) {
        TopPicksShelf.selectedGenreNotifier.value = savedSelected;
      }
    } catch (_) {}
  }

  Future<void> _persistVibePrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_customVibesPrefKey, jsonEncode(_customVibes));
      await prefs.setString(
        _selectedVibePrefKey,
        TopPicksShelf.selectedGenreNotifier.value,
      );
    } catch (_) {}
  }

  void _selectGenre(String genre) {
    TopPicksShelf.selectedGenreNotifier.value = genre;
    if (mounted) setState(() {});
    unawaited(_persistVibePrefs());
  }

  Future<void> _showTuneVibeDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => const _TuneVibeDialog(),
    );
    if (!mounted || result == null || result.isEmpty) return;

    final existingMatch = [..._defaultGenres, ..._customVibes]
        .where((g) => g.toLowerCase() == result.toLowerCase())
        .firstOrNull;
    if (existingMatch != null) {
      _selectGenre(existingMatch);
      return;
    }

    setState(() => _customVibes = [result, ..._customVibes]);
    _selectGenre(result);
  }

  List<_TopPickEntry> _buildDynamicTopPicks() {
    final activeGenre = TopPicksShelf.selectedGenreNotifier.value;
    final library = widget.library;
    final spotify = SpotifyService.instance;

    if (activeGenre != 'For You') {
      final mappedPresetGenre = switch (activeGenre) {
        'R&B & Soul' => 'R&B',
        'Chill & Focus' => 'Focus',
        'Party & Club' => 'Dance',
        _ => activeGenre,
      };
      final matchingPresets = kRecommendedPlaylists
          .where(
            (p) =>
                p.genre.toLowerCase() == mappedPresetGenre.toLowerCase() ||
                p.title.toLowerCase().contains(activeGenre.toLowerCase()) ||
                p.curatorSubtitle.toLowerCase().contains(
                  activeGenre.toLowerCase(),
                ),
          )
          .toList();

      final entries = <_TopPickEntry>[];
      final isPodcastMode = activeGenre.toLowerCase().contains('podcast');
      if (matchingPresets.isNotEmpty) {
        final offset = _rotationSeed % matchingPresets.length;
        final rotated = [
          ...matchingPresets.skip(offset),
          ...matchingPresets.take(offset),
        ];
        for (final preset in rotated) {
          entries.add(
            _TopPickEntry(
              categoryBadge: preset.badge,
              title: preset.title,
              description: preset.curatorSubtitle,
              gradient: preset.gradient,
              icon: preset.icon,
              coverUrl: preset.coverUrl,
              preset: preset,
              onTap: () => widget.onPlayPreset(preset),
            ),
          );
        }
      } else {
        final dynamicPreset = CuratedPlaylistPreset(
          title: '$activeGenre Essentials',
          curatorSubtitle: 'Tailored $activeGenre essentials',
          badge: activeGenre.toUpperCase(),
          searchQuery: '$activeGenre top hits songs official audio',
          gradient: [MeloColors.cherry, MeloColors.cherryDeep],
          icon: Icons.local_fire_department_rounded,
          genre: activeGenre,
          allowLongEpisodes: isPodcastMode,
        );
        entries.add(
          _TopPickEntry(
            categoryBadge: activeGenre.toUpperCase(),
            title: '$activeGenre Essentials',
            description: 'Top $activeGenre tracks & hottest anthems right now.',
            gradient: [MeloColors.cherry, MeloColors.cherryDeep],
            icon: Icons.local_fire_department_rounded,
            coverUrl:
                'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=800&q=80',
            preset: dynamicPreset,
            onTap: () => widget.onPlayPreset(dynamicPreset),
          ),
        );
      }

      final genreRadioPreset = CuratedPlaylistPreset(
        title: '$activeGenre Radio',
        curatorSubtitle: 'With top $activeGenre artists & similar tracks',
        badge: 'MADE FOR YOU',
        searchQuery: '$activeGenre radio mix songs official audio',
        gradient: [MeloColors.cherry, const Color(0xFF0A0A0C)],
        icon: Icons.sensors_rounded,
        isArtistRadio: true,
        genre: activeGenre,
        allowLongEpisodes: isPodcastMode,
      );
      final genreFreshPreset = CuratedPlaylistPreset(
        title: '$activeGenre Fresh & Trending',
        curatorSubtitle: 'Newest $activeGenre hits & street anthems',
        badge: 'NEW RELEASES',
        searchQuery: 'new $activeGenre songs 2025 2026 official audio',
        gradient: const [Color(0xFF4A0915), Color(0xFF000000)],
        icon: Icons.bolt_rounded,
        genre: activeGenre,
        allowLongEpisodes: isPodcastMode,
      );
      final genreClassicsPreset = CuratedPlaylistPreset(
        title: '$activeGenre Classics & Anthems',
        curatorSubtitle: 'Greatest $activeGenre classics of all time',
        badge: 'ALL-TIME CLASSICS',
        searchQuery: 'best $activeGenre classics anthems official audio',
        gradient: const [Color(0xFF2C2C2E), Color(0xFF000000)],
        icon: Icons.album_rounded,
        genre: activeGenre,
        allowLongEpisodes: isPodcastMode,
      );

      entries.addAll([
        _TopPickEntry(
          categoryBadge: 'RADIO MIX',
          title: genreRadioPreset.title,
          description: 'Continuous $activeGenre station tailored to your taste.',
          gradient: const [Color(0xFF7A0C1E), Color(0xFF0A0A0C)],
          icon: Icons.sensors_rounded,
          coverUrl:
              'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=800&q=80',
          preset: genreRadioPreset,
          onTap: () => widget.onPlayPreset(genreRadioPreset),
        ),
        _TopPickEntry(
          categoryBadge: 'FRESH HEAT',
          title: genreFreshPreset.title,
          description: 'New $activeGenre releases & viral club cuts.',
          gradient: const [Color(0xFF1C1C1E), Color(0xFF000000)],
          icon: Icons.bolt_rounded,
          coverUrl:
              'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=800&q=80',
          preset: genreFreshPreset,
          onTap: () => widget.onPlayPreset(genreFreshPreset),
        ),
        _TopPickEntry(
          categoryBadge: 'CLASSICS',
          title: genreClassicsPreset.title,
          description: 'Timeless $activeGenre bangers & unforgettable anthems.',
          gradient: const [Color(0xFF2C2C2E), Color(0xFF000000)],
          icon: Icons.album_rounded,
          coverUrl:
              'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=800&q=80',
          preset: genreClassicsPreset,
          onTap: () => widget.onPlayPreset(genreClassicsPreset),
        ),
      ]);
      return entries;
    }

    // 'For You': Personalized + Taste-Scored + Seed-Rotated dynamic picks
    final entries = <_TopPickEntry>[];
    final topArtist =
        library?.topAffinityArtists.firstOrNull ??
        library?.tracks.firstOrNull?.artist ??
        spotify.topArtists.firstOrNull;
    if (topArtist != null) {
      final topArtistCover = SongMetadataEnricher.instance
          .cachedArtistImageUrl(topArtist);
      entries.add(
        _TopPickEntry(
          categoryBadge: 'BECAUSE YOU PLAYED',
          title: '$topArtist Mix',
          description:
              'Non-stop $topArtist & similar artists tailored to your taste.',
          gradient: [MeloColors.cherry, MeloColors.cherryDeep],
          icon: Icons.auto_awesome_rounded,
          coverUrl: topArtistCover,
          preset: CuratedPlaylistPreset(
            title: '$topArtist Radio',
            curatorSubtitle: 'With similar artists & trending tracks',
            badge: 'ARTIST RADIO',
            searchQuery: '$topArtist songs',
            gradient: [MeloColors.cherry, MeloColors.cherryDeep, const Color(0xFF0A0A0C)],
            icon: Icons.sensors_rounded,
            coverUrl: topArtistCover,
            isArtistRadio: true,
            artistName: topArtist,
          ),
          onTap: () => widget.onOpenArtistRadio?.call(topArtist),
        ),
      );
    }

    if (spotify.isLoggedIn && spotify.userPlaylists.isNotEmpty) {
      final sp =
          spotify.userPlaylists[_rotationSeed % spotify.userPlaylists.length];
      final spPreset = CuratedPlaylistPreset(
        title: sp.title,
        curatorSubtitle: sp.subtitle,
        badge: 'SPOTIFY PLAYLIST',
        searchQuery: '${sp.title} official audio',
        gradient: [MeloColors.cherry, MeloColors.cherryDeep],
        icon: Icons.graphic_eq_rounded,
        coverUrl: sp.artworkUrl.isNotEmpty ? sp.artworkUrl : null,
        spotifyPlaylistId: sp.id,
      );
      entries.add(
        _TopPickEntry(
          categoryBadge: 'YOUR SPOTIFY',
          title: sp.title,
          description: sp.subtitle,
          gradient: const [Color(0xFF7A0C1E), Color(0xFF000000)],
          icon: Icons.graphic_eq_rounded,
          coverUrl: sp.artworkUrl.isNotEmpty ? sp.artworkUrl : null,
          preset: spPreset,
          onTap: () => widget.onPlayPreset(spPreset),
        ),
      );
    }

    final tasteArtists = [
      ...(library?.topAffinityArtists ?? const <String>[]),
      ...spotify.topArtists,
    ].map((a) => a.toLowerCase()).toSet();
    final tasteGenres = <String>{
      if (library != null) ...[
        for (final item in library.recentSessionItems.take(20))
          if ((item.genre ?? '').trim().isNotEmpty) item.genre!.toLowerCase(),
        for (final track in library.favoriteTracks)
          if ((track.genre ?? '').trim().isNotEmpty)
            track.genre!.toLowerCase(),
      ],
    };

    final scoredPresets =
        <({CuratedPlaylistPreset preset, int score, int index})>[];
    for (var i = 0; i < kRecommendedPlaylists.length; i++) {
      final p = kRecommendedPlaylists[i];
      var score = _timeOfDayPresetBoost(p);
      final gLower = p.genre.toLowerCase();
      final subLower = '${p.title} ${p.curatorSubtitle}'.toLowerCase();
      for (final g in tasteGenres) {
        if (gLower.contains(g) || g.contains(gLower)) score += 3;
      }
      for (final a in tasteArtists) {
        if (subLower.contains(a)) score += 4;
      }
      scoredPresets.add((preset: p, score: score, index: i));
    }
    scoredPresets.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return ((a.index + _rotationSeed * 3) % kRecommendedPlaylists.length)
          .compareTo(
            (b.index + _rotationSeed * 3) % kRecommendedPlaylists.length,
          );
    });

    entries.add(
      _TopPickEntry(
        categoryBadge: 'MADE FOR YOU',
        title: 'Personal Station',
        description: 'Continuous flow tailored to your favorites & library.',
        gradient: const [
          MeloColors.cherry,
          MeloColors.cherryDeep,
          Color(0xFF0A0A0C),
        ],
        icon: Icons.graphic_eq_rounded,
        preset: smartVibeStationPreset(SmartVibe.dailyFlow),
        onTap: () => widget.onPlayVibe(SmartVibe.dailyFlow),
      ),
    );

    final rotateOffset = _rotationSeed % scoredPresets.length;
    final dynamicPool = [
      ...scoredPresets.skip(rotateOffset),
      ...scoredPresets.take(rotateOffset),
    ].take(8);
    for (final entry in dynamicPool) {
      final preset = entry.preset;
      entries.add(
        _TopPickEntry(
          categoryBadge: preset.badge,
          title: preset.title,
          description: preset.curatorSubtitle,
          gradient: preset.gradient,
          icon: preset.icon,
          coverUrl: preset.coverUrl,
          preset: preset,
          onTap: () => widget.onPlayPreset(preset),
        ),
      );
    }
    return entries;
  }

  void _schedulePreload(List<_TopPickEntry> cards, String activeGenre) {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    final signature =
        '$activeGenre|$_rotationSeed|${cards.take(4).map((c) => c.title).join(',')}';
    if (_preloadedSignature == signature) return;
    _preloadedSignature = signature;
    final presets = cards
        .map((c) => c.preset)
        .whereType<CuratedPlaylistPreset>()
        .take(4)
        .toList(growable: false);
    if (presets.isEmpty) return;
    unawaited(
      CuratedPlaylistScreen.preloadPresets(presets, library: widget.library),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allGenres = [..._defaultGenres, ..._customVibes];
    final activeGenre = TopPicksShelf.selectedGenreNotifier.value;

    return ValueListenableBuilder<int>(
      valueListenable:
          widget.library?.playbackHistoryRevision ??
          const AlwaysStoppedAnimation<int>(0),
      builder: (context, _, _) {
        final cards = _buildDynamicTopPicks();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _schedulePreload(cards, activeGenre);
        });
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Top Picks for You',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                Material(
                  color: MeloColors.cherry.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(99),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _showTuneVibeDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: MeloColors.cherry.withValues(alpha: 0.45),
                          width: 0.9,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            size: 13,
                            color: MeloColors.cherry,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Tune Vibe',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: MeloColors.cherry,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Refresh top picks',
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.refresh_rounded,
                    size: 19,
                    color: Colors.white70,
                  ),
                  onPressed: () => setState(() => _rotationSeed++),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: allGenres.length + 1,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  if (index == allGenres.length) {
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: _showTuneVibeDialog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: const Color(0xFF141416),
                            border: Border.all(
                              color: MeloColors.cherry.withValues(alpha: 0.45),
                              width: 0.9,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_rounded,
                                size: 14,
                                color: MeloColors.cherry,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Custom Genre',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  final genre = allGenres[index];
                  final isSelected = genre == activeGenre;
                  final isCustom = _customVibes.contains(genre);
                  return Semantics(
                    button: true,
                    selected: isSelected,
                    label: 'Tune Top Picks to $genre',
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _selectGenre(genre),
                        onLongPress: isCustom
                            ? () {
                                setState(() {
                                  _customVibes = _customVibes
                                      .where((v) => v != genre)
                                      .toList(growable: false);
                                });
                                if (isSelected) {
                                  _selectGenre('For You');
                                } else {
                                  unawaited(_persistVibePrefs());
                                }
                              }
                            : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: isSelected
                                ? MeloColors.cherry
                                : const Color(0xFF141416),
                            border: Border.all(
                              color: isSelected
                                  ? MeloColors.cherrySoft
                                  : Colors.white.withValues(alpha: 0.14),
                              width: 0.9,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              genre,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 195,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: cards.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final card = cards[index];
                  return TopPickCard(
                    categoryBadge: card.categoryBadge,
                    title: card.title,
                    description: card.description,
                    gradient: card.gradient,
                    icon: card.icon,
                    coverUrl: card.coverUrl,
                    onTap: card.onTap,
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
            boxShadow: MeloShadows.hdrBloom(
              gradient.first,
              secondary: gradient.last,
              opacity: 0.36,
            ),
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.16),
              width: 1.0,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (coverUrl != null)
                  CachedNetworkArtwork(
                    url: coverUrl!,
                    width: 250,
                    height: 195,
                    fit: BoxFit.cover,
                    errorWidget: const SizedBox.shrink(),
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
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                categoryBadge,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
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

class _StationSpec {
  const _StationSpec({
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.icon,
    required this.preset,
    required this.onTap,
    this.artworkTrack,
    this.defaultArtworkUrl,
  });

  final String title;
  final String subtitle;
  final List<Color> gradient;
  final IconData icon;
  final CuratedPlaylistPreset preset;
  final VoidCallback onTap;
  final ImportedTrack? artworkTrack;
  final String? defaultArtworkUrl;
}

class StationsForYouShelf extends StatefulWidget {
  const StationsForYouShelf({
    required this.onPlayVibe,
    this.onPlayPreset,
    this.library,
    this.audioHandler,
    this.refreshGeneration = 0,
    super.key,
  });

  final ValueChanged<SmartVibe> onPlayVibe;
  final ValueChanged<CuratedPlaylistPreset>? onPlayPreset;
  final MusicLibrary? library;
  final AudioHandler? audioHandler;
  final int refreshGeneration;

  @override
  State<StationsForYouShelf> createState() => _StationsForYouShelfState();
}

class _StationsForYouShelfState extends State<StationsForYouShelf> {
  int _stationSeed = 0;
  String? _preloadedSignature;

  @override
  void initState() {
    super.initState();
    TopPicksShelf.selectedGenreNotifier.addListener(_onChanged);
    SpotifyService.instance.feedRevision.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant StationsForYouShelf oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshGeneration != widget.refreshGeneration) {
      setState(() => _stationSeed++);
    }
  }

  @override
  void dispose() {
    TopPicksShelf.selectedGenreNotifier.removeListener(_onChanged);
    SpotifyService.instance.feedRevision.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _openPreset(CuratedPlaylistPreset preset) {
    if (widget.onPlayPreset != null) {
      widget.onPlayPreset!(preset);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CuratedPlaylistScreen(
          preset: preset,
          audioHandler: widget.audioHandler,
          library: widget.library,
        ),
      ),
    );
  }

  _StationSpec _timeOfDayStation(ImportedTrack? fallbackTrack) {
    final hour = DateTime.now().hour;
    final (title, subtitle, badge, query, cover, gradient, icon) =
        (hour >= 4 && hour < 12)
        ? (
            'Morning Boost Radio',
            'Morning flow · Upbeat hits & sunrise energy',
            'MORNING RADIO',
            'upbeat morning feel good afrobeats pop hits burna boy dua lipa official audio',
            'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&q=80',
            const [Color(0xFFFA243C), Color(0xFF6B0B1A), Color(0xFF0A0A0C)],
            Icons.wb_sunny_rounded,
          )
        : (hour >= 12 && hour < 17)
        ? (
            'Afternoon Pulse Radio',
            'Midday rhythm · Trending global & local waves',
            'MIDDAY RADIO',
            'trending afternoon groove dancehall afrobeats asake ayra starr official audio',
            'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=800&q=80',
            const [Color(0xFFFA243C), Color(0xFF4A0915), Color(0xFF080808)],
            Icons.bolt_rounded,
          )
        : (hour >= 17 && hour < 22)
        ? (
            'Evening Unwind Radio',
            'Golden hour · Smooth vibes & warm anthems',
            'EVENING RADIO',
            'evening unwind smooth afrobeats rnb hits sza tems giveon official audio',
            'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=800&q=80',
            const [Color(0xFF7A0C1E), Color(0xFF140307), Color(0xFF000000)],
            Icons.nights_stay_rounded,
          )
        : (
            'After Hours Radio',
            'Late night · Slow soul & ambient cuts',
            'MIDNIGHT RADIO',
            'late night slow jams chill rnb brent faiyaz daniel caesar official audio',
            'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=800&q=80',
            const [Color(0xFF4A0915), Color(0xFF100306), Color(0xFF000000)],
            Icons.nightlight_round,
          );

    final preset = CuratedPlaylistPreset(
      title: title,
      curatorSubtitle: subtitle,
      badge: badge,
      searchQuery: query,
      gradient: gradient,
      icon: icon,
      coverUrl: cover,
      seed: _stationSeed,
    );
    return _StationSpec(
      title: title,
      subtitle: subtitle,
      gradient: gradient,
      icon: icon,
      preset: preset,
      artworkTrack: fallbackTrack,
      defaultArtworkUrl: cover,
      onTap: () => _openPreset(preset),
    );
  }

  List<_StationSpec> _buildStations() {
    final library = widget.library;
    final tracks = library?.tracks ?? const <ImportedTrack>[];
    final favorites = library?.favoriteTracks ?? const <ImportedTrack>[];
    final pool = favorites.isNotEmpty ? [...favorites, ...tracks] : tracks;
    ImportedTrack? trackAt(int slot) =>
        pool.isEmpty ? null : pool[(slot + _stationSeed) % pool.length];

    final stations = <_StationSpec>[
      _timeOfDayStation(trackAt(0)),
    ];

    final activeGenre = TopPicksShelf.selectedGenreNotifier.value;
    if (activeGenre != 'For You') {
      final isPodcast = activeGenre.toLowerCase().contains('podcast');
      final genrePreset = CuratedPlaylistPreset(
        title: '$activeGenre Live Radio',
        curatorSubtitle: 'Continuous $activeGenre station tailored to you',
        badge: 'LIVE STATION',
        searchQuery: '$activeGenre mix hits official audio',
        gradient: [MeloColors.cherry, const Color(0xFF1A0408), const Color(0xFF000000)],
        icon: isPodcast ? Icons.podcasts_rounded : Icons.sensors_rounded,
        isArtistRadio: !isPodcast,
        genre: activeGenre,
        allowLongEpisodes: isPodcast,
        coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=800&q=80',
        seed: _stationSeed,
      );
      stations.add(
        _StationSpec(
          title: genrePreset.title,
          subtitle: 'Radio Station · $activeGenre flow',
          gradient: genrePreset.gradient,
          icon: genrePreset.icon,
          preset: genrePreset,
          defaultArtworkUrl: genrePreset.coverUrl,
          onTap: () => _openPreset(genrePreset),
        ),
      );
    }

    final spotify = SpotifyService.instance;
    final dynamicArtists = <String>[
      ...(library?.topAffinityArtists ?? const <String>[]),
      ...spotify.topArtists,
      ...tracks
          .map((t) => t.artist.trim())
          .where((a) => a.isNotEmpty && a.toLowerCase() != 'unknown artist'),
    ];
    final seenArtists = <String>{};
    final uniqueArtists = <String>[
      for (final artist in dynamicArtists)
        if (seenArtists.add(artist.toLowerCase())) artist,
    ];
    if (uniqueArtists.isNotEmpty) {
      final idx = _stationSeed % uniqueArtists.length;
      final pickedArtist = uniqueArtists[idx];
      final matchingTrack = tracks
          .where((t) => t.artist.toLowerCase() == pickedArtist.toLowerCase())
          .firstOrNull;
      final artistArt =
          matchingTrack?.artworkUri ??
          SongMetadataEnricher.instance.cachedArtistImageUrl(pickedArtist);
      final artistPreset = CuratedPlaylistPreset(
        title: '$pickedArtist Radio',
        curatorSubtitle: 'With similar artists & trending tracks',
        badge: 'ARTIST STATION',
        searchQuery: '$pickedArtist songs',
        gradient: const [Color(0xFF8A0E22), Color(0xFF0A0A0C)],
        icon: Icons.sensors_rounded,
        coverUrl: artistArt,
        isArtistRadio: true,
        artistName: pickedArtist,
        seed: _stationSeed,
      );
      stations.add(
        _StationSpec(
          title: '$pickedArtist Station',
          subtitle: 'Based on your $pickedArtist plays',
          gradient: artistPreset.gradient,
          icon: Icons.sensors_rounded,
          preset: artistPreset,
          artworkTrack: matchingTrack,
          defaultArtworkUrl:
              artistArt ??
              'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=800&q=80',
          onTap: () => _openPreset(artistPreset),
        ),
      );
    }

    final coreVibes = [
      (
        vibe: SmartVibe.dailyFlow,
        subtitle: 'Radio Station · Personal flow',
        track: trackAt(1),
        cover:
            'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=800&q=80',
      ),
      (
        vibe: SmartVibe.highEnergy,
        subtitle: 'Radio Station · High Energy',
        track: trackAt(2),
        cover:
            'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=800&q=80',
      ),
      (
        vibe: SmartVibe.deepFocus,
        subtitle: 'Radio Station · Instrumental',
        track: trackAt(3),
        cover:
            'https://images.unsplash.com/photo-1518495973542-4542c06a5843?w=800&q=80',
      ),
      (
        vibe: SmartVibe.lateNightChill,
        subtitle: 'Radio Station · Midnight soul',
        track: trackAt(4),
        cover:
            'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=800&q=80',
      ),
    ];
    final coreOffset = _stationSeed % coreVibes.length;
    final rotatedCore = [
      ...coreVibes.skip(coreOffset),
      ...coreVibes.take(coreOffset),
    ];
    for (final item in rotatedCore) {
      final preset = smartVibeStationPreset(item.vibe, seed: _stationSeed);
      stations.add(
        _StationSpec(
          title: preset.title,
          subtitle: item.subtitle,
          gradient: preset.gradient,
          icon: preset.icon,
          preset: preset,
          artworkTrack: item.track,
          defaultArtworkUrl: item.cover,
          onTap: () => widget.onPlayVibe(item.vibe),
        ),
      );
    }

    return stations;
  }

  void _schedulePreload(List<_StationSpec> stations) {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    final sig =
        '$_stationSeed|${stations.take(4).map((s) => s.title).join(',')}';
    if (_preloadedSignature == sig) return;
    _preloadedSignature = sig;
    unawaited(
      CuratedPlaylistScreen.preloadPresets(
        stations.take(4).map((s) => s.preset),
        library: widget.library,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable:
          widget.library?.playbackHistoryRevision ??
          const AlwaysStoppedAnimation<int>(0),
      builder: (context, _, _) {
        final stations = _buildStations();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _schedulePreload(stations);
        });

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
                IconButton(
                  tooltip: 'Refresh stations',
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.refresh_rounded,
                    size: 19,
                    color: Colors.white70,
                  ),
                  onPressed: () => setState(() => _stationSeed++),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: MeloColors.cherry.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.sensors_rounded,
                        size: 13,
                        color: MeloColors.cherry,
                      ),
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
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: stations.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final station = stations[index];
                  return StationTile(
                    title: station.title,
                    subtitle: station.subtitle,
                    artworkTrack: station.artworkTrack,
                    defaultArtworkUrl: station.defaultArtworkUrl,
                    gradient: station.gradient,
                    icon: station.icon,
                    onTap: station.onTap,
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
                      if (defaultArtworkUrl != null && defaultArtworkUrl!.isNotEmpty)
                        Positioned.fill(
                          child: CachedNetworkArtwork(
                            url: defaultArtworkUrl!,
                            width: 136,
                            height: 136,
                            fit: BoxFit.cover,
                            errorWidget: artworkTrack != null
                                ? AlbumArtwork(
                                    size: 136,
                                    title: artworkTrack!.title,
                                    artworkUri: artworkTrack!.artworkUri != null
                                        ? Uri.tryParse(artworkTrack!.artworkUri!)
                                        : null,
                                    sourceUri: Uri.tryParse(artworkTrack!.path),
                                    borderRadius: 0,
                                  )
                                : CustomPaint(
                                    painter: FoldedPrismPainter(
                                      color: Colors.white.withValues(alpha: 0.14),
                                    ),
                                  ),
                          ),
                        )
                      else if (artworkTrack != null)
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
    this.refreshGeneration = 0,
    super.key,
  });

  final AudioHandler? audioHandler;
  final MusicLibrary? library;
  final int refreshGeneration;

  @override
  State<RecommendedPlaylistsSection> createState() =>
      _RecommendedPlaylistsSectionState();
}

class _RecommendedPlaylistsSectionState
    extends State<RecommendedPlaylistsSection> {
  String _selectedGenre = 'All';
  int _rotationSeed = 0;
  String? _preloadedSignature;

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
    'Podcasts',
  ];

  @override
  void initState() {
    super.initState();
    TopPicksShelf.selectedGenreNotifier.addListener(_onTopPickGenreChanged);
  }

  @override
  void didUpdateWidget(covariant RecommendedPlaylistsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshGeneration != widget.refreshGeneration) {
      setState(() => _rotationSeed++);
    }
  }

  @override
  void dispose() {
    TopPicksShelf.selectedGenreNotifier.removeListener(_onTopPickGenreChanged);
    super.dispose();
  }

  void _onTopPickGenreChanged() {
    final picked = TopPicksShelf.selectedGenreNotifier.value;
    final mapped = switch (picked) {
      'For You' => 'All',
      'R&B & Soul' => 'R&B',
      'Chill & Focus' => 'Focus',
      'Party & Club' => 'Dance',
      _ => picked,
    };
    if (mounted && _selectedGenre != mapped) {
      setState(() => _selectedGenre = mapped);
    }
  }

  void _openPlaylist(BuildContext context, CuratedPlaylistPreset preset) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CuratedPlaylistScreen(
          preset: preset,
          audioHandler: widget.audioHandler,
          library: widget.library,
        ),
      ),
    );
  }

  List<CuratedPlaylistPreset> _sortedForTaste(
    List<CuratedPlaylistPreset> playlists,
  ) {
    final library = widget.library;
    final tasteArtists = (library?.topAffinityArtists ?? const <String>[])
        .take(8)
        .map((a) => a.toLowerCase())
        .toList();
    final tasteGenres = <String>{
      if (library != null) ...[
        for (final item in library.recentSessionItems.take(20))
          if ((item.genre ?? '').trim().isNotEmpty) item.genre!.toLowerCase(),
        for (final track in library.favoriteTracks)
          if ((track.genre ?? '').trim().isNotEmpty) track.genre!.toLowerCase(),
      ],
    };

    final scored = <({CuratedPlaylistPreset preset, int score, int index})>[];
    for (var i = 0; i < playlists.length; i++) {
      final preset = playlists[i];
      final genreLower = preset.genre.toLowerCase();
      final subtitleLower = preset.curatorSubtitle.toLowerCase();
      var score = _timeOfDayPresetBoost(preset);
      for (final g in tasteGenres) {
        if (g.contains(genreLower) || genreLower.contains(g)) score += 3;
      }
      for (var aIdx = 0; aIdx < tasteArtists.length; aIdx++) {
        if (subtitleLower.contains(tasteArtists[aIdx])) {
          score += (tasteArtists.length - aIdx) * 2;
        }
      }
      scored.add((preset: preset, score: score, index: i));
    }
    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return ((a.index + _rotationSeed * 2) % playlists.length).compareTo(
        (b.index + _rotationSeed * 2) % playlists.length,
      );
    });
    return scored.map((e) => e.preset).toList(growable: false);
  }

  void _schedulePreload(List<CuratedPlaylistPreset> presets) {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    final sig =
        '$_selectedGenre|$_rotationSeed|${presets.take(4).map((p) => p.title).join(',')}';
    if (_preloadedSignature == sig) return;
    _preloadedSignature = sig;
    unawaited(
      CuratedPlaylistScreen.preloadPresets(
        presets.take(4),
        library: widget.library,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textScaler = MediaQuery.textScalerOf(context);
    final chipStripHeight = (textScaler.scale(16) + 24).clamp(40.0, 64.0);
    final shelfCardHeight = 166.0 + textScaler.scale(42).clamp(38.0, 96.0);

    return ValueListenableBuilder<int>(
      valueListenable:
          widget.library?.playbackHistoryRevision ??
          const AlwaysStoppedAnimation<int>(0),
      builder: (context, _, _) {
        final matchedPresets = _selectedGenre == 'All'
            ? _sortedForTaste(kRecommendedPlaylists)
            : kRecommendedPlaylists
                  .where(
                    (p) =>
                        p.genre.toLowerCase() == _selectedGenre.toLowerCase() ||
                        p.title.toLowerCase().contains(
                          _selectedGenre.toLowerCase(),
                        ),
                  )
                  .toList();
        final filteredPlaylists = matchedPresets.isNotEmpty
            ? matchedPresets
            : [
                CuratedPlaylistPreset(
                  title: '$_selectedGenre Essentials',
                  curatorSubtitle: 'Top $_selectedGenre picks & viral hits',
                  badge: _selectedGenre.toUpperCase(),
                  searchQuery: '$_selectedGenre hits official audio',
                  gradient: [MeloColors.cherry, MeloColors.cherryDeep],
                  icon: Icons.music_note_rounded,
                  genre: _selectedGenre,
                ),
                CuratedPlaylistPreset(
                  title: '$_selectedGenre Radio',
                  curatorSubtitle: 'Continuous $_selectedGenre mix',
                  badge: 'RADIO MIX',
                  searchQuery: '$_selectedGenre radio mix official audio',
                  gradient: const [Color(0xFF4A0915), Color(0xFF000000)],
                  icon: Icons.radio_rounded,
                  isArtistRadio: true,
                  genre: _selectedGenre,
                ),
              ];
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _schedulePreload(filteredPlaylists);
        });

        return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ShelfHeader(
          icon: Icons.stars_rounded,
          title: 'Recommended Playlists',
          trailingText: 'Melo Curated Picks',
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: chipStripHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: _genres.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final genre = _genres[index];
              final isSelected = genre == _selectedGenre;
              return Semantics(
                button: true,
                selected: isSelected,
                label: 'Filter by $genre',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => setState(() => _selectedGenre = genre),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: isSelected
                            ? MeloColors.cherry
                            : colors.surfaceContainerHigh.withValues(alpha: 0.6),
                        border: Border.all(
                          color: isSelected
                              ? MeloColors.cherrySoft
                              : colors.outlineVariant.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          genre,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? Colors.white : colors.onSurface,
                          ),
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
          height: shelfCardHeight,
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
                                  CachedNetworkArtwork(
                                    url: preset.coverUrl!,
                                    width: 156,
                                    height: 156,
                                    fit: BoxFit.cover,
                                    errorWidget: Container(
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
      },
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
class ArtistRadioShelf extends StatefulWidget {
  const ArtistRadioShelf({
    required this.onOpenArtistRadio,
    this.library,
    super.key,
  });

  final ValueChanged<String> onOpenArtistRadio;
  final MusicLibrary? library;

  @override
  State<ArtistRadioShelf> createState() => _ArtistRadioShelfState();
}

class _ArtistRadioShelfState extends State<ArtistRadioShelf> {
  static const List<ArtistRadioItem> _defaultArtists = [
    ArtistRadioItem(
      name: 'King Saha',
      avatarUrl: '',
      genres: 'Afro-Pop · Uganda',
    ),
    ArtistRadioItem(
      name: 'Joshua Baraka',
      avatarUrl: '',
      genres: 'R&B · Afrobeats',
    ),
    ArtistRadioItem(
      name: 'Burna Boy',
      avatarUrl: '',
      genres: 'Afro-Fusion · Lagos',
    ),
    ArtistRadioItem(
      name: 'Kendrick Lamar',
      avatarUrl: '',
      genres: 'Hip-Hop · Rap Life',
    ),
    ArtistRadioItem(
      name: 'Asake',
      avatarUrl: '',
      genres: 'Amapiano · Fujipiano',
    ),
    ArtistRadioItem(
      name: 'SZA',
      avatarUrl: '',
      genres: 'Contemporary R&B',
    ),
    ArtistRadioItem(
      name: 'Drake',
      avatarUrl: '',
      genres: 'Hip-Hop · Melodic Rap',
    ),
    ArtistRadioItem(
      name: 'Tems',
      avatarUrl: '',
      genres: 'Soul · Afrobeats',
    ),
  ];

  final Map<String, String> _resolvedAvatars = {};
  final Set<String> _requestedArtists = {};
  final Map<String, List<String>> _relatedByArtist = {};
  final Set<String> _requestedRelated = {};

  @override
  void initState() {
    super.initState();
    widget.library?.playbackHistoryRevision.addListener(_onHistoryChanged);
    _ensureRelatedArtists();
  }

  @override
  void didUpdateWidget(covariant ArtistRadioShelf oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.library?.playbackHistoryRevision !=
        widget.library?.playbackHistoryRevision) {
      oldWidget.library?.playbackHistoryRevision.removeListener(
        _onHistoryChanged,
      );
      widget.library?.playbackHistoryRevision.addListener(_onHistoryChanged);
      _ensureRelatedArtists();
    }
  }

  @override
  void dispose() {
    widget.library?.playbackHistoryRevision.removeListener(_onHistoryChanged);
    super.dispose();
  }

  void _onHistoryChanged() {
    _ensureRelatedArtists();
    if (mounted) setState(() {});
  }

  void _ensureRelatedArtists() {
    final affinity = widget.library?.topAffinityArtists ?? const <String>[];
    for (final seed in affinity.take(2)) {
      final lower = seed.trim().toLowerCase();
      if (lower.isEmpty || _requestedRelated.contains(lower)) continue;
      _requestedRelated.add(lower);
      unawaited(
        SongMetadataEnricher.instance.fetchRelatedArtists(seed, limit: 4).then((
          related,
        ) {
          if (!mounted || related.isEmpty) return;
          setState(() => _relatedByArtist[seed] = related);
        }),
      );
    }
  }

  List<ArtistRadioItem> _buildArtists() {
    final libraryTracks = widget.library?.tracks ?? const <ImportedTrack>[];
    final affinityArtists = widget.library?.topAffinityArtists ?? const <String>[];
    final localArtByArtist = <String, String>{};
    final personalizedArtists = <({String name, String subtitle})>[];
    final seen = <String>{};

    for (final track in libraryTracks) {
      final name = track.artist.trim();
      final lower = name.toLowerCase();
      if (name.isEmpty || lower == 'unknown artist') continue;
      final art = track.artworkUri?.trim();
      if (art != null && art.isNotEmpty && !localArtByArtist.containsKey(lower)) {
        localArtByArtist[lower] = art;
      }
    }

    for (final artist in affinityArtists) {
      final clean = artist.trim();
      final lower = clean.toLowerCase();
      if (clean.isEmpty || lower == 'unknown artist') continue;
      if (seen.add(lower) && personalizedArtists.length < 6) {
        personalizedArtists.add((name: clean, subtitle: 'Based on Your Listening'));
      }
    }

    for (final track in libraryTracks) {
      final name = track.artist.trim();
      final lower = name.toLowerCase();
      if (name.isEmpty || lower == 'unknown artist') continue;
      if (seen.add(lower) && personalizedArtists.length < 6) {
        personalizedArtists.add((name: name, subtitle: 'From Your Library'));
      }
    }

    for (final entry in _relatedByArtist.entries) {
      for (final relatedName in entry.value) {
        final clean = relatedName.trim();
        final lower = clean.toLowerCase();
        if (clean.isEmpty || lower == 'unknown artist') continue;
        if (seen.add(lower) && personalizedArtists.length < 8) {
          personalizedArtists.add((
            name: clean,
            subtitle: 'Similar to ${entry.key}',
          ));
        }
      }
    }

    return <ArtistRadioItem>[
      ...personalizedArtists.map((entry) {
        final lower = entry.name.toLowerCase();
        final resolved = _resolvedAvatars[lower] ??
            SongMetadataEnricher.instance.cachedArtistImageUrl(entry.name) ??
            localArtByArtist[lower] ??
            '';
        return ArtistRadioItem(
          name: entry.name,
          avatarUrl: resolved,
          genres: entry.subtitle,
        );
      }),
      ..._defaultArtists
          .where((d) => !seen.contains(d.name.toLowerCase()))
          .map((d) {
        final lower = d.name.toLowerCase();
        final resolved = _resolvedAvatars[lower] ??
            SongMetadataEnricher.instance.cachedArtistImageUrl(d.name) ??
            d.avatarUrl;
        return ArtistRadioItem(
          name: d.name,
          avatarUrl: resolved,
          genres: d.genres,
        );
      }),
    ];
  }

  void _ensureArtistAvatars(List<ArtistRadioItem> artists) {
    for (final artist in artists) {
      final lower = artist.name.toLowerCase();
      if (_requestedArtists.contains(lower)) continue;
      _requestedArtists.add(lower);
      unawaited(
        SongMetadataEnricher.instance.fetchArtistImageUrl(artist.name).then((url) {
          if (!mounted || url == null || url.isEmpty) return;
          if (_resolvedAvatars[lower] != url) {
            setState(() => _resolvedAvatars[lower] = url);
          }
        }),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final artists = _buildArtists();
    _ensureArtistAvatars(artists);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ShelfHeader(
          icon: Icons.sensors_rounded,
          title: 'Artist Radio',
          badgeLabel: 'ENDLESS STATIONS',
          badgeIcon: Icons.radio_rounded,
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 118.0 + MediaQuery.textScalerOf(context).scale(44).clamp(40.0, 96.0),
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
                    onTap: () => widget.onOpenArtistRadio(artist.name),
                    child: Column(
                      children: [
                        // Circular Artist Avatar with QLED Ambient Gradient Ring
                        Container(
                          width: 104,
                          height: 104,
                          padding: const EdgeInsets.all(2.4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                MeloColors.cherryGlow,
                                MeloColors.cherryDeep,
                                Color(0x38FFFFFF),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: MeloColors.cherry.withValues(alpha: 0.24),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.55),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                _ArtistAvatarImage(
                                  avatarUrl: artist.avatarUrl,
                                  artistName: artist.name,
                                  fallbackColor: colors.surfaceContainerHigh,
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

class PopularSongsShelf extends StatefulWidget {
  const PopularSongsShelf({
    required this.audioHandler,
    this.library,
    super.key,
  });

  final AudioHandler? audioHandler;
  final MusicLibrary? library;

  @override
  State<PopularSongsShelf> createState() => _PopularSongsShelfState();
}

class _PopularSongsShelfState extends State<PopularSongsShelf> {
  static final List<YoutubeTrack> _defaultPopular = [
    const YoutubeTrack(
      id: 'kPa7bsKwL-c',
      title: 'Die With A Smile',
      author: 'Lady Gaga & Bruno Mars',
      duration: Duration(minutes: 4, seconds: 12),
      thumbnailUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
    ),
    const YoutubeTrack(
      id: 'd5gf9dXbPi0',
      title: 'Birds of a Feather',
      author: 'Billie Eilish',
      duration: Duration(minutes: 3, seconds: 18),
      thumbnailUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&q=80',
    ),
    const YoutubeTrack(
      id: '2Vv-BfVoq4g',
      title: 'Taste',
      author: 'Sabrina Carpenter',
      duration: Duration(minutes: 2, seconds: 37),
      thumbnailUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=600&q=80',
    ),
    const YoutubeTrack(
      id: 'T6eK-DY7hGE',
      title: 'Not Like Us',
      author: 'Kendrick Lamar',
      duration: Duration(minutes: 4, seconds: 34),
      thumbnailUrl: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=600&q=80',
    ),
    const YoutubeTrack(
      id: '421w1j87fEM',
      title: 'Higher',
      author: 'Burna Boy',
      duration: Duration(minutes: 3, seconds: 15),
      thumbnailUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=600&q=80',
    ),
    const YoutubeTrack(
      id: 'WcIcVapfqXw',
      title: 'MMS',
      author: 'Asake & Wizkid',
      duration: Duration(minutes: 3, seconds: 39),
      thumbnailUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=600&q=80',
    ),
    const YoutubeTrack(
      id: 'hBCS_4pC03g',
      title: 'Love Me JeJe',
      author: 'Tems',
      duration: Duration(minutes: 2, seconds: 58),
      thumbnailUrl: 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=600&q=80',
    ),
    const YoutubeTrack(
      id: 'XbGs_qK2PQA',
      title: 'Dancing In The Flames',
      author: 'The Weeknd',
      duration: Duration(minutes: 3, seconds: 40),
      thumbnailUrl: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=600&q=80',
    ),
    const YoutubeTrack(
      id: 'XqeUpQzUe4Y',
      title: 'Water',
      author: 'Tyla',
      duration: Duration(minutes: 3, seconds: 20),
      thumbnailUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&q=80',
    ),
    const YoutubeTrack(
      id: 'p7i88HqZpA8',
      title: 'MILLION DOLLAR BABY',
      author: 'Tommy Richman',
      duration: Duration(minutes: 2, seconds: 35),
      thumbnailUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
    ),
  ];

  static List<YoutubeTrack>? _cachedOnline;
  static String? _cachedSeedArtist;
  List<YoutubeTrack> _tracks = _cachedOnline ?? _defaultPopular;
  String? _lastSeedArtist = _cachedSeedArtist;
  bool _isPersonalized = _cachedSeedArtist != null;

  @override
  void initState() {
    super.initState();
    widget.library?.playbackHistoryRevision.addListener(_onHistoryChanged);
    final initialSeed = widget.library?.topAffinityArtists.firstOrNull;
    if (_cachedOnline == null ||
        (initialSeed != null && initialSeed != _lastSeedArtist)) {
      unawaited(_loadOnlinePopular(seedArtist: initialSeed));
    }
  }

  @override
  void didUpdateWidget(covariant PopularSongsShelf oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.library?.playbackHistoryRevision !=
        widget.library?.playbackHistoryRevision) {
      oldWidget.library?.playbackHistoryRevision.removeListener(
        _onHistoryChanged,
      );
      widget.library?.playbackHistoryRevision.addListener(_onHistoryChanged);
      _onHistoryChanged();
    }
  }

  @override
  void dispose() {
    widget.library?.playbackHistoryRevision.removeListener(_onHistoryChanged);
    super.dispose();
  }

  void _onHistoryChanged() {
    final seedArtist = widget.library?.topAffinityArtists.firstOrNull;
    if (seedArtist != null && seedArtist != _lastSeedArtist) {
      unawaited(_loadOnlinePopular(seedArtist: seedArtist));
    }
  }

  Future<void> _loadOnlinePopular({String? seedArtist}) async {
    try {
      final activeItem = widget.audioHandler?.mediaItem.value;
      final excludeIds = <String>{
        if (activeItem != null) activeItem.id,
      };
      final excludeTitles = <String>{
        if (activeItem != null)
          SongMetadataEnricher.cleanTitle(
            activeItem.title,
            rawArtist: activeItem.artist,
          ).trim().toLowerCase(),
      }..removeWhere((t) => t.isEmpty);

      final collected = <YoutubeTrack>[];
      final seenIds = <String>{};
      final cleanSeed = seedArtist?.trim();
      var personalized = false;

      if (cleanSeed != null && cleanSeed.isNotEmpty) {
        final related = await YoutubeAudioService.instance.getRelatedTracks(
          'dQw4w9WgXcQ',
          artist: cleanSeed,
          recentArtists: widget.library?.topAffinityArtists ?? const [],
          excludeIds: excludeIds,
          excludeTitleKeys: excludeTitles,
        );
        for (final t in related) {
          if (seenIds.add(t.id)) collected.add(t);
        }
        personalized = collected.isNotEmpty;
      }

      if (collected.length < 10) {
        final results = await YoutubeAudioService.instance.search(
          'Billboard Hot 100 Global Hits official single',
          filterMixtapes: true,
        );
        for (final t in results) {
          if (t.duration.inSeconds > 660 || t.duration.inSeconds < 45) continue;
          if (YoutubeAudioService.isMixtapeOrNonstop(t.title, t.duration)) {
            continue;
          }
          if (seenIds.add(t.id)) collected.add(t);
          if (collected.length >= 15) break;
        }
      }

      if (collected.isNotEmpty) {
        _cachedOnline = collected;
        _cachedSeedArtist = personalized ? cleanSeed : null;
        _lastSeedArtist = cleanSeed;
        if (mounted) {
          setState(() {
            _tracks = collected;
            _isPersonalized = personalized;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _playSong(int index) async {
    final handler = widget.audioHandler;
    if (handler == null || _tracks.isEmpty) return;
    try {
      final items = _tracks.map((t) => t.toMediaItem()).toList(growable: false);
      if (handler is MeloAudioHandler) {
        await handler.replaceQueue(
          items,
          initialIndex: index,
          playWhenReady: true,
        );
      } else {
        await handler.updateQueue(items);
        await handler.skipToQueueItem(index);
        await handler.play();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not start playback: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final activeItem = widget.audioHandler?.mediaItem.value;
    final activeTitleLower = activeItem?.title.trim().toLowerCase();
    final visibleTracks = _tracks
        .where((t) {
          if (activeItem != null &&
              (activeItem.id == 'youtube:${t.id}' ||
                  activeItem.extras?['providerTrackId'] == t.id)) {
            return false;
          }
          if (activeTitleLower != null &&
              activeTitleLower.isNotEmpty &&
              t.title.trim().toLowerCase() == activeTitleLower) {
            return false;
          }
          return true;
        })
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ShelfHeader(
          icon: Icons.trending_up_rounded,
          title: 'Popular Songs',
          badgeLabel: _isPersonalized ? 'PICKED FOR YOU' : 'GLOBAL HITS',
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 166.0 + MediaQuery.textScalerOf(context).scale(42).clamp(38.0, 96.0),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: visibleTracks.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final track = visibleTracks[index];
              final sourceIndex = _tracks.indexOf(track);
              return SizedBox(
                width: 140,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _playSong(sourceIndex >= 0 ? sourceIndex : index),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (track.thumbnailUrl != null)
                                  CachedNetworkArtwork(
                                    url: track.thumbnailUrl!,
                                    width: 140,
                                    height: 140,
                                    fit: BoxFit.cover,
                                    errorWidget: Container(
                                      color: colors.surfaceContainerHighest,
                                      child: const Icon(Icons.music_note_rounded, size: 36, color: Colors.white54),
                                    ),
                                  )
                                else
                                  Container(
                                    color: colors.surfaceContainerHighest,
                                    child: const Icon(Icons.music_note_rounded, size: 36, color: Colors.white54),
                                  ),
                                Positioned(
                                  bottom: 6,
                                  right: 6,
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: const BoxDecoration(
                                      color: MeloColors.cherry,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.play_arrow_rounded, size: 16, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          track.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, color: colors.onSurfaceVariant),
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

class _ArtistAvatarImage extends StatelessWidget {
  const _ArtistAvatarImage({
    required this.avatarUrl,
    required this.artistName,
    required this.fallbackColor,
  });

  final String avatarUrl;
  final String artistName;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    final trimmed = avatarUrl.trim();
    if (trimmed.isNotEmpty) {
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        return CachedNetworkArtwork(
          url: trimmed,
          width: 104,
          height: 104,
          fit: BoxFit.cover,
          errorWidget: _fallback(),
        );
      }
      final filePath = trimmed.startsWith('file://')
          ? Uri.parse(trimmed).toFilePath()
          : trimmed;
      return Image.file(
        File(filePath),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    final initial = artistName.trim().isNotEmpty
        ? artistName.trim()[0].toUpperCase()
        : '';
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            fallbackColor,
            MeloColors.cherry.withValues(alpha: 0.45),
          ],
        ),
      ),
      child: Center(
        child: initial.isNotEmpty
            ? Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                ),
              )
            : const Icon(Icons.person_rounded, size: 40, color: Colors.white54),
      ),
    );
  }
}

class _ShelfHeader extends StatelessWidget {
  const _ShelfHeader({
    required this.icon,
    required this.title,
    this.trailingText,
    this.badgeLabel,
    this.badgeIcon,
    this.accentColor,
    this.trailingAction,
  });

  final IconData icon;
  final String title;
  final String? trailingText;
  final String? badgeLabel;
  final IconData? badgeIcon;
  final Color? accentColor;
  final Widget? trailingAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tint = accentColor ?? MeloColors.cherry;
    return Row(
      children: [
        Icon(icon, size: 20, color: tint),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  letterSpacing: -0.4,
                ),
          ),
        ),
        if (trailingAction != null) ...[
          trailingAction!,
          if (badgeLabel != null) const SizedBox(width: 6),
        ],
        if (badgeLabel != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: tint.withValues(alpha: 0.35),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: tint.withValues(alpha: 0.2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (badgeIcon != null) ...[
                  Icon(badgeIcon, size: 12, color: tint),
                  const SizedBox(width: 4),
                ],
                Text(
                  badgeLabel!,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: tint,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          )
        else if (trailingText != null)
          Text(
            trailingText!,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
      ],
    );
  }
}

/// Live Spotify editorial feed carousel and track strip with QLED 4K HDR cards.
class SpotifyFeedShelf extends StatefulWidget {
  const SpotifyFeedShelf({
    required this.audioHandler,
    this.library,
    super.key,
  });

  final AudioHandler? audioHandler;
  final MusicLibrary? library;

  @override
  State<SpotifyFeedShelf> createState() => _SpotifyFeedShelfState();
}

class _SpotifyFeedShelfState extends State<SpotifyFeedShelf> {
  static const List<String> _feedFilters = [
    'For You',
    'Your Playlists',
    'Recently Played',
    'Charts',
  ];

  List<SpotifyTrack> _feedTracks = const [];
  String? _streamingPlaylistId;
  String _selectedFeedFilter = 'For You';
  String? _selectedPlaylistId;
  final Map<String, List<SpotifyTrack>> _tracksByPlaylistId = {};
  final Set<String> _loadingPlaylistIds = {};

  @override
  void initState() {
    super.initState();
    widget.library?.playbackHistoryRevision.addListener(_onHistoryChanged);
    SpotifyService.instance.authState.addListener(_onSpotifyChanged);
    SpotifyService.instance.feedRevision.addListener(_onSpotifyChanged);
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      unawaited(_loadFeedTracks());
    }
  }

  @override
  void didUpdateWidget(covariant SpotifyFeedShelf oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.library?.playbackHistoryRevision !=
        widget.library?.playbackHistoryRevision) {
      oldWidget.library?.playbackHistoryRevision.removeListener(
        _onHistoryChanged,
      );
      widget.library?.playbackHistoryRevision.addListener(_onHistoryChanged);
    }
  }

  @override
  void dispose() {
    widget.library?.playbackHistoryRevision.removeListener(_onHistoryChanged);
    SpotifyService.instance.authState.removeListener(_onSpotifyChanged);
    SpotifyService.instance.feedRevision.removeListener(_onSpotifyChanged);
    super.dispose();
  }

  void _onHistoryChanged() {
    if (mounted) setState(() {});
  }

  void _onSpotifyChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadFeedTracks() async {
    final tracks = await SpotifyService.instance.fetchFeedTracks(limit: 12);
    if (!mounted || tracks.isEmpty) return;
    setState(() => _feedTracks = tracks);
    final playlists = _tasteOrderedPlaylists();
    final first = _effectiveSelectedPlaylist(playlists);
    if (first != null) {
      unawaited(_loadTracksForPlaylist(first.id));
    }
  }

  FeaturedSpotifyPlaylist? _effectiveSelectedPlaylist(
    List<FeaturedSpotifyPlaylist> playlists,
  ) {
    if (playlists.isEmpty) return null;
    if (_selectedPlaylistId != null) {
      final match =
          playlists.where((p) => p.id == _selectedPlaylistId).firstOrNull;
      if (match != null) return match;
    }
    return playlists.first;
  }

  void _selectPlaylist(FeaturedSpotifyPlaylist playlist) {
    if (_selectedPlaylistId == playlist.id) {
      _openSpotifyPlaylistScreen(playlist);
      return;
    }
    setState(() => _selectedPlaylistId = playlist.id);
    unawaited(_loadTracksForPlaylist(playlist.id));
  }

  Future<void> _loadTracksForPlaylist(String playlistId) async {
    if (_tracksByPlaylistId.containsKey(playlistId) ||
        _loadingPlaylistIds.contains(playlistId)) {
      return;
    }
    _loadingPlaylistIds.add(playlistId);
    try {
      List<SpotifyTrack> tracks;
      if (playlistId == 'liked') {
        final spotify = SpotifyService.instance;
        tracks = spotify.likedTracks.isNotEmpty
            ? spotify.likedTracks
            : spotify.personalFeedTracks;
      } else {
        final data = await SpotifyService.instance.fetchPlaylist(playlistId);
        tracks = data.tracks;
      }
      final seen = <String>{};
      final uniqueTracks = <SpotifyTrack>[];
      for (final t in tracks) {
        final key =
            '${t.title.trim().toLowerCase()}|${t.artist.trim().toLowerCase()}';
        if (seen.add(key)) uniqueTracks.add(t);
      }
      if (mounted) {
        setState(() {
          _tracksByPlaylistId[playlistId] = uniqueTracks;
        });
      }
    } catch (_) {
      // Fallback to feed tracks if network error
    } finally {
      _loadingPlaylistIds.remove(playlistId);
    }
  }

  List<FeaturedSpotifyPlaylist> _tasteOrderedPlaylists() {
    final spotify = SpotifyService.instance;
    final personalPlaylists = [
      if (spotify.likedTracks.isNotEmpty)
        FeaturedSpotifyPlaylist(
          id: 'liked',
          title: 'Spotify Liked Songs',
          subtitle: '${spotify.likedTracks.length} synced tracks',
          artworkUrl: spotify.likedTracks.first.artworkUrl ?? '',
          category: 'Liked Songs',
        ),
      for (final p in spotify.userPlaylists)
        FeaturedSpotifyPlaylist(
          id: p.id,
          title: p.title,
          subtitle: p.subtitle,
          artworkUrl: p.artworkUrl,
          category: 'Your Library',
        ),
    ];

    if (spotify.isLoggedIn && _selectedFeedFilter == 'Your Playlists') {
      return personalPlaylists.isNotEmpty
          ? personalPlaylists
          : SpotifyService.featuredPlaylists;
    }

    final library = widget.library;
    final recentText = [
      if (library != null) ...[
        ...library.recentSessionItems.map(
          (e) => '${e.title} ${e.artist ?? ''} ${e.album ?? ''}',
        ),
        ...library.topAffinityArtists,
      ],
      ...spotify.topArtists,
    ].join(' ').toLowerCase();

    final editorial = [...SpotifyService.featuredPlaylists];
    if (recentText.trim().isNotEmpty) {
      int scoreFor(FeaturedSpotifyPlaylist playlist) {
        var score = 0;
        final category = playlist.category.toLowerCase();
        if (recentText.contains(category)) score += 3;
        if (category.contains('afro') &&
            (recentText.contains('afro') ||
                recentText.contains('burna') ||
                recentText.contains('tems') ||
                recentText.contains('asake') ||
                recentText.contains('rema'))) {
          score += 4;
        }
        if (category.contains('hip-hop') &&
            (recentText.contains('rap') ||
                recentText.contains('hip') ||
                recentText.contains('kendrick') ||
                recentText.contains('drake'))) {
          score += 4;
        }
        if (category.contains('focus') &&
            (recentText.contains('lofi') ||
                recentText.contains('ambient') ||
                recentText.contains('study') ||
                recentText.contains('instrumental'))) {
          score += 3;
        }
        return score;
      }

      editorial.sort((a, b) => scoreFor(b).compareTo(scoreFor(a)));
    }

    if (spotify.isLoggedIn && _selectedFeedFilter != 'Charts') {
      return [...personalPlaylists, ...editorial];
    }
    return editorial;
  }

  Future<void> _streamPlaylist(FeaturedSpotifyPlaylist playlist) async {
    final handler = widget.audioHandler;
    if (handler == null || _streamingPlaylistId != null) return;
    setState(() => _streamingPlaylistId = playlist.id);
    try {
      List<SpotifyTrack> tracks;
      if (playlist.id == 'liked') {
        tracks = SpotifyService.instance.likedTracks.isNotEmpty
            ? SpotifyService.instance.likedTracks
            : SpotifyService.instance.personalFeedTracks;
      } else {
        final data = await SpotifyService.instance.fetchPlaylist(playlist.id);
        tracks = data.tracks;
      }
      if (!mounted) return;
      if (tracks.isEmpty) {
        if (playlist.id == 'liked') {
          _openSpotifySync();
          return;
        }
        _openSpotifyPlaylistScreen(playlist);
        return;
      }
      final items = tracks
          .map((t) {
            final localMatch = widget.library?.findMatchingLocalTrack(
              providerTrackId: t.id,
              title: t.title,
              artist: t.artist,
            );
            return localMatch != null
                ? localMatch.toMediaItem()
                : t.toImportedTrack().toMediaItem();
          })
          .toList(growable: false);
      if (handler is MeloAudioHandler) {
        await handler.replaceQueue(items, initialIndex: 0, playWhenReady: true);
      } else {
        await handler.updateQueue(items);
        await handler.skipToQueueItem(0);
        await handler.play();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Streaming Spotify "${playlist.title}"'),
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
            content: Text('Could not stream Spotify playlist: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) setState(() => _streamingPlaylistId = null);
    }
  }

  void _openSpotifyPlaylistScreen(FeaturedSpotifyPlaylist playlist) {
    final spotify = SpotifyService.instance;
    final initialTracks = playlist.id == 'liked'
        ? (spotify.likedTracks.isNotEmpty
              ? spotify.likedTracks
              : spotify.personalFeedTracks)
        : null;
    final preset = CuratedPlaylistPreset(
      title: playlist.title,
      curatorSubtitle: playlist.subtitle,
      badge: playlist.category.toUpperCase(),
      searchQuery: '${playlist.title} official audio',
      gradient: [MeloColors.cherry, MeloColors.cherryDeep],
      icon: playlist.id == 'liked'
          ? Icons.favorite_rounded
          : Icons.graphic_eq_rounded,
      coverUrl: playlist.artworkUrl.isNotEmpty ? playlist.artworkUrl : null,
      spotifyPlaylistId: playlist.id,
      initialSpotifyTracks: initialTracks,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CuratedPlaylistScreen(
          preset: preset,
          audioHandler: widget.audioHandler,
          library: widget.library,
        ),
      ),
    );
  }

  void _openSpotifySync() {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => SpotifySettingsScreen(
              library: widget.library,
              audioHandler: widget.audioHandler,
            ),
          ),
        )
        .then((_) {
          if (mounted) setState(() {});
        });
  }

  Future<void> _streamFeedTrack(
    SpotifyTrack track, {
    required List<SpotifyTrack> contextTracks,
  }) async {
    final handler = widget.audioHandler;
    if (handler == null) return;
    try {
      final items = contextTracks
          .map((t) {
            final localMatch = widget.library?.findMatchingLocalTrack(
              providerTrackId: t.id,
              title: t.title,
              artist: t.artist,
            );
            return localMatch != null
                ? localMatch.toMediaItem()
                : t.toImportedTrack().toMediaItem();
          })
          .toList(growable: false);
      final tappedIndex = contextTracks.indexWhere((t) => t.id == track.id);
      if (handler is MeloAudioHandler) {
        await handler.replaceQueue(
          items,
          initialIndex: tappedIndex < 0 ? 0 : tappedIndex,
          playWhenReady: true,
        );
      } else {
        await handler.updateQueue(items);
        await handler.skipToQueueItem(tappedIndex < 0 ? 0 : tappedIndex);
        await handler.play();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not stream "${track.title}": $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<void> _queueFeedTrack(
    SpotifyTrack track, {
    bool playNext = false,
  }) async {
    final handler = widget.audioHandler;
    if (handler == null) return;
    try {
      final localMatch = widget.library?.findMatchingLocalTrack(
        providerTrackId: track.id,
        title: track.title,
        artist: track.artist,
      );
      final item = localMatch != null
          ? localMatch.toMediaItem()
          : track.toImportedTrack().toMediaItem();
      if (playNext && handler is MeloAudioHandler) {
        await handler.insertQueueItemNext(item);
      } else {
        await handler.addQueueItem(item);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              playNext
                  ? 'Playing "${track.title}" next'
                  : 'Added "${track.title}" to Up Next',
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
            content: Text('Could not queue "${track.title}": $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  List<SpotifyTrack> _tracksForCurrentSelection(
    FeaturedSpotifyPlaylist? selectedPlaylist,
  ) {
    // 1. If user explicitly tapped a playlist or is in 'Your Playlists', show that playlist's tracks
    if (_selectedPlaylistId != null || _selectedFeedFilter == 'Your Playlists') {
      final active = selectedPlaylist;
      if (active != null) {
        final cached = _tracksByPlaylistId[active.id];
        if (cached != null && cached.isNotEmpty) {
          return cached;
        }
        unawaited(_loadTracksForPlaylist(active.id));
      }
    }

    final spotify = SpotifyService.instance;

    // 2. Filter-specific views
    if (_selectedFeedFilter == 'Recently Played') {
      if (spotify.recentlyPlayedTracks.isNotEmpty) {
        return spotify.recentlyPlayedTracks;
      }
      final history = widget.library?.recentSessionItems ?? const [];
      if (history.isNotEmpty) {
        return history
            .map(
              (item) => SpotifyTrack(
                id: item.id,
                title: item.title,
                artist: item.artist ?? 'Unknown artist',
                album: item.album ?? '',
                durationMs: item.duration?.inMilliseconds ?? 0,
                artworkUrl: item.artUri?.toString(),
              ),
            )
            .toList(growable: false);
      }
    }

    if (_selectedFeedFilter == 'Charts') {
      if (_feedTracks.isNotEmpty) {
        return _feedTracks;
      }
    }

    // 3. For You (Personalized Feed)
    if (spotify.isLoggedIn && spotify.personalFeedTracks.isNotEmpty) {
      final seen = <String>{};
      final combined = <SpotifyTrack>[];
      for (final t in [...spotify.personalFeedTracks, ..._feedTracks]) {
        final key =
            '${t.title.trim().toLowerCase()}|${t.artist.trim().toLowerCase()}';
        if (seen.add(key)) combined.add(t);
      }
      if (combined.isNotEmpty) return combined;
    }

    // Fallback: if cached tracks exist for current playlist, show them
    if (selectedPlaylist != null) {
      final cached = _tracksByPlaylistId[selectedPlaylist.id];
      if (cached != null && cached.isNotEmpty) return cached;
    }

    return _feedTracks;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final spotify = SpotifyService.instance;
    final isLoggedIn = spotify.isLoggedIn;
    final playlists = _tasteOrderedPlaylists();
    final selectedPlaylist = _effectiveSelectedPlaylist(playlists);
    if (selectedPlaylist != null &&
        !_tracksByPlaylistId.containsKey(selectedPlaylist.id) &&
        !_loadingPlaylistIds.contains(selectedPlaylist.id)) {
      unawaited(_loadTracksForPlaylist(selectedPlaylist.id));
    }
    final rawTracks = _tracksForCurrentSelection(selectedPlaylist);
    final seenKeys = <String>{};
    final uniqueTracks = <SpotifyTrack>[];
    for (final t in rawTracks) {
      final key =
          '${t.title.trim().toLowerCase()}|${t.artist.trim().toLowerCase()}';
      if (seenKeys.add(key)) uniqueTracks.add(t);
    }
    final visibleFeedTracks = uniqueTracks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ShelfHeader(
          icon: Icons.radar_rounded,
          title: 'Spotify Feed',
          accentColor: MeloColors.cherry,
          trailingAction: Material(
            color: MeloColors.cherry.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(99),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _openSpotifySync,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: MeloColors.cherry.withValues(alpha: 0.4),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isLoggedIn
                          ? Icons.verified_user_rounded
                          : Icons.sync_rounded,
                      size: 13,
                      color: MeloColors.cherry,
                    ),
                    const SizedBox(width: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 118),
                      child: Text(
                        isLoggedIn
                            ? 'Synced · ${spotify.displayName ?? "Account"}'
                            : 'Sync Account',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: MeloColors.cherry,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (isLoggedIn) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: _feedFilters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final label = _feedFilters[index];
                final selected = label == _selectedFeedFilter;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      setState(() {
                        _selectedFeedFilter = label;
                        _selectedPlaylistId = null;
                      });
                      final newPlaylists = _tasteOrderedPlaylists();
                      final first = _effectiveSelectedPlaylist(newPlaylists);
                      if (first != null) {
                        unawaited(_loadTracksForPlaylist(first.id));
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: selected
                            ? MeloColors.cherry
                            : MeloColors.qledElevated,
                        border: Border.all(
                          color: selected
                              ? MeloColors.cherrySoft
                              : Colors.white.withValues(alpha: 0.14),
                          width: 0.9,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 14),
        SizedBox(
          height:
              154.0 +
              MediaQuery.textScalerOf(context).scale(42).clamp(38.0, 96.0),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: playlists.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final playlist = playlists[index];
              final isStreaming = _streamingPlaylistId == playlist.id;
              final isSelected = selectedPlaylist?.id == playlist.id;
              return SizedBox(
                width: 158,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _selectPlaylist(playlist),
                    onLongPress: () => _openSpotifyPlaylistScreen(playlist),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: MeloColors.qledCard,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected
                              ? MeloColors.cherry
                              : Colors.white.withValues(alpha: 0.12),
                          width: isSelected ? 1.8 : 1.0,
                        ),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: MeloColors.cherry.withValues(alpha: 0.28),
                              blurRadius: 18,
                              offset: const Offset(0, 4),
                            ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.55),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 112,
                            width: double.infinity,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (playlist.artworkUrl.isNotEmpty)
                                    CachedNetworkArtwork(
                                      url: playlist.artworkUrl,
                                      width: 158,
                                      height: 112,
                                      fit: BoxFit.cover,
                                      errorWidget: Container(
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              MeloColors.cherry,
                                              MeloColors.cherryDeep,
                                            ],
                                          ),
                                        ),
                                        child: Icon(
                                          playlist.id == 'liked'
                                              ? Icons.favorite_rounded
                                              : Icons.queue_music_rounded,
                                          color: Colors.white70,
                                          size: 36,
                                        ),
                                      ),
                                    )
                                  else
                                    Container(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            MeloColors.cherry,
                                            MeloColors.cherryDeep,
                                          ],
                                        ),
                                      ),
                                      child: Icon(
                                        playlist.id == 'liked'
                                            ? Icons.favorite_rounded
                                            : Icons.queue_music_rounded,
                                        color: Colors.white70,
                                        size: 36,
                                      ),
                                    ),
                                  Positioned(
                                    top: 6,
                                    left: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.72,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.24,
                                          ),
                                          width: 0.7,
                                        ),
                                      ),
                                      child: Text(
                                        playlist.category.toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 6,
                                    right: 6,
                                    child: Semantics(
                                      button: true,
                                      label: 'Stream ${playlist.title}',
                                      child: Material(
                                        color: MeloColors.cherry,
                                        shape: const CircleBorder(),
                                        elevation: 4,
                                        child: InkWell(
                                          customBorder: const CircleBorder(),
                                          onTap: () => _streamPlaylist(playlist),
                                          child: SizedBox(
                                            width: 30,
                                            height: 30,
                                            child: isStreaming
                                                ? const Padding(
                                                    padding: EdgeInsets.all(7),
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors.white,
                                                        ),
                                                  )
                                                : const Icon(
                                                    Icons.play_arrow_rounded,
                                                    size: 18,
                                                    color: Colors.white,
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            playlist.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            playlist.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (visibleFeedTracks.isNotEmpty) ...[
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedPlaylistId != null && selectedPlaylist != null
                        ? '${selectedPlaylist.title} · Tracks'
                        : _selectedFeedFilter == 'Recently Played'
                            ? 'Recently Played · Tracks'
                            : _selectedFeedFilter == 'Charts'
                                ? 'Top Charts · Tracks'
                                : selectedPlaylist != null
                                    ? '${selectedPlaylist.title} · Quick Tracks'
                                    : 'Trending Tracks',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70,
                    ),
                  ),
                ),
                if (selectedPlaylist != null)
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => _openSpotifyPlaylistScreen(selectedPlaylist),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View all',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: MeloColors.cherry,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 14,
                            color: MeloColors.cherry,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 62,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: visibleFeedTracks.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final track = visibleFeedTracks[index];
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _streamFeedTrack(
                      track,
                      contextTracks: visibleFeedTracks,
                    ),
                    child: Container(
                      width: 224,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: MeloColors.qledElevated,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.10),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(9),
                              color: MeloColors.cherry.withValues(
                                alpha: 0.16,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: track.artworkUrl != null
                                ? CachedNetworkArtwork(
                                    url: track.artworkUrl!,
                                    width: 38,
                                    height: 38,
                                    fit: BoxFit.cover,
                                    errorWidget: const Icon(
                                      Icons.music_note_rounded,
                                      size: 18,
                                      color: MeloColors.cherry,
                                    ),
                                  )
                                : const Icon(
                                    Icons.music_note_rounded,
                                    size: 18,
                                    color: MeloColors.cherry,
                                  ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  track.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  track.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          PopupMenuButton<String>(
                            tooltip: 'Options',
                            icon: Icon(
                              Icons.more_vert_rounded,
                              size: 18,
                              color: colors.onSurfaceVariant,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            color: MeloColors.qledCard,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            onSelected: (val) {
                              if (val == 'play_next') {
                                _queueFeedTrack(track, playNext: true);
                              } else if (val == 'queue') {
                                _queueFeedTrack(track, playNext: false);
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'play_next',
                                child: Row(
                                  children: [
                                    Icon(Icons.playlist_play_rounded, size: 20),
                                    SizedBox(width: 10),
                                    Text('Play next'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'queue',
                                child: Row(
                                  children: [
                                    Icon(Icons.queue_music_rounded, size: 20),
                                    SizedBox(width: 10),
                                    Text('Add to Up Next'),
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
          ),
        ],
      ],
    );
  }
}

/// Trace & Soundcity Immersive Broadcast Playlists
final List<CuratedPlaylistPreset> kTraceSoundcityBroadcastPlaylists = [
  CuratedPlaylistPreset(
    title: 'Soundcity Top 10 Naija & Africa',
    curatorSubtitle: 'Official Soundcity TV Hitlist · Hot on Rotation',
    badge: 'SOUNDCITY TOP 10',
    searchQuery: 'Soundcity Top 10 Naija Hits Official Audio 2025 2026',
    gradient: [const Color(0xFFEAB308), const Color(0xFF7F1D1D), const Color(0xFF000000)],
    icon: Icons.tv_rounded,
    coverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
    genre: 'Afrobeats',
    isBroadcastChannel: true,
    broadcastStation: 'SOUNDCITY TV',
    initialSpotifyTracks: const [
      SpotifyTrack(
        id: 'sc_top10_1',
        title: 'Higher',
        artist: 'Burna Boy',
        album: 'Higher - Single',
        durationMs: 195000,
        artworkUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'sc_top10_2',
        title: 'MMS',
        artist: 'Asake & Wizkid',
        album: 'Lungu Boy',
        durationMs: 219000,
        artworkUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'sc_top10_3',
        title: 'HEHEHE',
        artist: 'Rema',
        album: 'HEIS',
        durationMs: 104000,
        artworkUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'sc_top10_4',
        title: 'Santa',
        artist: 'Ayra Starr & Rvssian',
        album: 'The Year I Turned 21',
        durationMs: 198000,
        artworkUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'sc_top10_5',
        title: 'Love Me JeJe',
        artist: 'Tems',
        album: 'Born in the Wild',
        durationMs: 178000,
        artworkUrl: 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'sc_top10_6',
        title: 'Marhaba',
        artist: 'Kizz Daniel',
        album: 'Marhaba - Single',
        durationMs: 165000,
        artworkUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'sc_top10_7',
        title: 'Moving',
        artist: 'Omah Lay',
        album: 'Moving - Single',
        durationMs: 184000,
        artworkUrl: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'sc_top10_8',
        title: 'Kante',
        artist: 'Davido ft. Fave',
        album: 'Timeless',
        durationMs: 194000,
        artworkUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'sc_top10_9',
        title: 'Everything',
        artist: 'Victony',
        album: 'Stubborn',
        durationMs: 201000,
        artworkUrl: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'sc_top10_10',
        title: 'Casablanca',
        artist: 'Seyi Vibez',
        album: 'Loseyi Professor',
        durationMs: 153000,
        artworkUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=600&q=80',
      ),
    ],
  ),
  CuratedPlaylistPreset(
    title: 'Trace Urban Global Hitlist',
    curatorSubtitle: 'Trace Urban Music TV · Non-Stop Heavyweight Rotation',
    badge: 'TRACE URBAN',
    searchQuery: 'Trace Urban Hits Hip Hop Afrobeats Pop 2025 Official Audio',
    gradient: [const Color(0xFFEC4899), const Color(0xFF831843), const Color(0xFF000000)],
    icon: Icons.live_tv_rounded,
    coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&q=80',
    genre: 'Urban & Hip-Hop',
    isBroadcastChannel: true,
    broadcastStation: 'TRACE URBAN',
    initialSpotifyTracks: const [
      SpotifyTrack(
        id: 'tu_hit_1',
        title: 'Not Like Us',
        artist: 'Kendrick Lamar',
        album: 'Not Like Us',
        durationMs: 274000,
        artworkUrl: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'tu_hit_2',
        title: 'Taste',
        artist: 'Sabrina Carpenter',
        album: 'Short n\' Sweet',
        durationMs: 157000,
        artworkUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'tu_hit_3',
        title: 'Birds of a Feather',
        artist: 'Billie Eilish',
        album: 'HIT ME HARD AND SOFT',
        durationMs: 198000,
        artworkUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'tu_hit_4',
        title: 'Die With A Smile',
        artist: 'Lady Gaga & Bruno Mars',
        album: 'Die With A Smile',
        durationMs: 252000,
        artworkUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'tu_hit_5',
        title: 'Dancing In The Flames',
        artist: 'The Weeknd',
        album: 'Hurry Up Tomorrow',
        durationMs: 220000,
        artworkUrl: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'tu_hit_6',
        title: 'fukumean',
        artist: 'Gunna',
        album: 'a Gift & a Curse',
        durationMs: 125000,
        artworkUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'tu_hit_7',
        title: 'Saturn',
        artist: 'SZA',
        album: 'Lana',
        durationMs: 186000,
        artworkUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'tu_hit_8',
        title: 'FE!N',
        artist: 'Travis Scott ft. Playboi Carti',
        album: 'UTOPIA',
        durationMs: 191000,
        artworkUrl: 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'tu_hit_9',
        title: 'MILLION DOLLAR BABY',
        artist: 'Tommy Richman',
        album: 'COYOTE',
        durationMs: 155000,
        artworkUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'tu_hit_10',
        title: 'First Person Shooter',
        artist: 'Drake ft. J. Cole',
        album: 'For All The Dogs',
        durationMs: 247000,
        artworkUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&q=80',
      ),
    ],
  ),
  CuratedPlaylistPreset(
    title: 'Trace Africa / Naija Gold',
    curatorSubtitle: 'Trace Africa Network · African Music Worldwide',
    badge: 'TRACE AFRICA',
    searchQuery: 'Trace Africa Naija Bongo Amapiano Hits Official Audio',
    gradient: [const Color(0xFF10B981), const Color(0xFF064E3B), const Color(0xFF000000)],
    icon: Icons.sensors_rounded,
    coverUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=600&q=80',
    genre: 'Afrobeats',
    isBroadcastChannel: true,
    broadcastStation: 'TRACE AFRICA',
    initialSpotifyTracks: const [
      SpotifyTrack(
        id: 'ta_gold_1',
        title: 'City Boys',
        artist: 'Burna Boy',
        album: 'I Told Them...',
        durationMs: 153000,
        artworkUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'ta_gold_2',
        title: 'Water',
        artist: 'Tyla',
        album: 'TYLA',
        durationMs: 200000,
        artworkUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'ta_gold_3',
        title: 'Active',
        artist: 'Asake ft. Travis Scott',
        album: 'Lungu Boy',
        durationMs: 171000,
        artworkUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'ta_gold_4',
        title: 'Komasava',
        artist: 'Diamond Platnumz ft. Jason Derulo',
        album: 'Komasava (Remix)',
        durationMs: 182000,
        artworkUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'ta_gold_5',
        title: 'Tshwala Bam (Remix)',
        artist: 'TitoM, Yuppe, Burna Boy ft. S.N.E',
        album: 'Tshwala Bam',
        durationMs: 251000,
        artworkUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'ta_gold_6',
        title: 'Commas',
        artist: 'Ayra Starr',
        album: 'The Year I Turned 21',
        durationMs: 158000,
        artworkUrl: 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'ta_gold_7',
        title: 'EGWU',
        artist: 'Chike & Mohbad',
        album: 'EGWU',
        durationMs: 161000,
        artworkUrl: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'ta_gold_8',
        title: 'Calm Down',
        artist: 'Rema',
        album: 'Rave & Roses',
        durationMs: 219000,
        artworkUrl: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'ta_gold_9',
        title: 'Twe Twe (Remix)',
        artist: 'Kizz Daniel ft. Davido',
        album: 'TWS',
        durationMs: 154000,
        artworkUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'ta_gold_10',
        title: 'Mayday',
        artist: 'Fally Ipupa',
        album: 'Formule 7',
        durationMs: 260000,
        artworkUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=600&q=80',
      ),
    ],
  ),
  CuratedPlaylistPreset(
    title: 'Soundcity Amapiano Takeover',
    curatorSubtitle: 'Private School Yanos & Deep Bass · Soundcity Curated',
    badge: 'SOUNDCITY AMAPIANO',
    searchQuery: 'Soundcity Amapiano Mix Hits Official Audio',
    gradient: [const Color(0xFFF97316), const Color(0xFF7C2D12), const Color(0xFF000000)],
    icon: Icons.graphic_eq_rounded,
    coverUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=600&q=80',
    genre: 'Amapiano',
    isBroadcastChannel: true,
    broadcastStation: 'SOUNDCITY RADIO',
    initialSpotifyTracks: const [
      SpotifyTrack(
        id: 'sc_pfd_1',
        title: 'Imithandazo',
        artist: 'Kabza De Small & Mthunzi ft. Young Stunna',
        album: 'Isimo',
        durationMs: 330000,
        artworkUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'sc_pfd_2',
        title: 'Mnike',
        artist: 'Tyler ICU & Tumelo.za ft. DJ Maphorisa',
        album: 'Buya Nini',
        durationMs: 289000,
        artworkUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'sc_pfd_3',
        title: 'Tshwala Bam',
        artist: 'TitoM & Yuppe ft. S.N.E',
        album: 'Tshwala Bam',
        durationMs: 240000,
        artworkUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'sc_pfd_4',
        title: 'Wadibusa',
        artist: 'Uncle Waffles ft. Oompa',
        album: 'An Asylum',
        durationMs: 275000,
        artworkUrl: 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'sc_pfd_5',
        title: 'Dalie',
        artist: 'Kamo Mphela, Khalil Harrison, Tyler ICU',
        album: 'Dalie',
        durationMs: 236000,
        artworkUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'sc_pfd_6',
        title: 'Amalobolo',
        artist: 'Kelvin Momo ft. Babalwa M',
        album: 'Kurhula',
        durationMs: 350000,
        artworkUrl: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'sc_pfd_7',
        title: 'Funk 55',
        artist: 'DBN Gogo, Shazmicsoul ft. Ceeka RSA',
        album: 'Funk 55',
        durationMs: 271000,
        artworkUrl: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'sc_pfd_8',
        title: 'Ke Star (Remix)',
        artist: 'Focalistic & Davido ft. Vigro Deep',
        album: 'Ke Star',
        durationMs: 232000,
        artworkUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'sc_pfd_9',
        title: 'John Wick',
        artist: 'De Mthuda ft. Sir Trill & Da Muziqal Chef',
        album: 'The Landlord',
        durationMs: 375000,
        artworkUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'sc_pfd_10',
        title: 'Soundcheck',
        artist: 'Vigro Deep',
        album: 'Baby Boy 4',
        durationMs: 340000,
        artworkUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=600&q=80',
      ),
    ],
  ),
  CuratedPlaylistPreset(
    title: 'Trace Gospel Elevation',
    curatorSubtitle: 'Trace Gospel TV · Spirit & Soul Worldwide',
    badge: 'TRACE GOSPEL',
    searchQuery: 'Trace Gospel Worship Contemporary Hits Official Audio',
    gradient: [const Color(0xFF6366F1), const Color(0xFF312E81), const Color(0xFF000000)],
    icon: Icons.favorite_rounded,
    coverUrl: 'https://images.unsplash.com/photo-1445743432342-eac500ce72b7?w=600&q=80',
    genre: 'Gospel',
    isBroadcastChannel: true,
    broadcastStation: 'TRACE GOSPEL',
    initialSpotifyTracks: const [
      SpotifyTrack(
        id: 'tg_gosp_1',
        title: 'Miracle No Dey Tire Jesus',
        artist: 'Moses Bliss',
        album: 'More Than Music',
        durationMs: 245000,
        artworkUrl: 'https://images.unsplash.com/photo-1445743432342-eac500ce72b7?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'tg_gosp_2',
        title: 'Tobechukwu',
        artist: 'Nathaniel Bassey ft. Mercy Chinwo',
        album: 'Hallelujah Live',
        durationMs: 440000,
        artworkUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'tg_gosp_3',
        title: 'Wonder',
        artist: 'Mercy Chinwo',
        album: 'Overwhelming Victory',
        durationMs: 275000,
        artworkUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'tg_gosp_4',
        title: 'Finger of God',
        artist: 'Dunsin Oyekan',
        album: 'The Birth of Revival',
        durationMs: 480000,
        artworkUrl: 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'tg_gosp_5',
        title: 'Jireh (My Provider)',
        artist: 'Limoblaze ft. Lecrae & Happi',
        album: 'Sunday in Lagos',
        durationMs: 172000,
        artworkUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'tg_gosp_6',
        title: 'Promises',
        artist: 'Maverick City Music',
        album: 'Maverick City Vol. 3',
        durationMs: 310000,
        artworkUrl: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'tg_gosp_7',
        title: 'Way Maker',
        artist: 'Sinach',
        album: 'Way Maker',
        durationMs: 305000,
        artworkUrl: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'tg_gosp_8',
        title: 'Capable God',
        artist: 'Judikay',
        album: 'Man of Galilee',
        durationMs: 280000,
        artworkUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'tg_gosp_9',
        title: 'Goodness of God',
        artist: 'CeCe Winans',
        album: 'Believe For It',
        durationMs: 298000,
        artworkUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'tg_gosp_10',
        title: 'See How Far',
        artist: 'Victoria Orenze',
        album: 'Truth in Sounds',
        durationMs: 360000,
        artworkUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
      ),
    ],
  ),
  CuratedPlaylistPreset(
    title: 'Soundcity Underground & New Wave',
    curatorSubtitle: 'Next Gen Street Anthems & Rising Stars · Soundcity',
    badge: 'SOUNDCITY NEW WAVE',
    searchQuery: 'Soundcity Underground Afrobeats New Wave Hits Official Audio',
    gradient: [const Color(0xFF06B6D4), const Color(0xFF164E63), const Color(0xFF000000)],
    icon: Icons.bolt_rounded,
    coverUrl: 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=600&q=80',
    genre: 'Alternative & New Wave',
    isBroadcastChannel: true,
    broadcastStation: 'SOUNDCITY TV',
    initialSpotifyTracks: const [
      SpotifyTrack(
        id: 'sc_nw_1',
        title: 'Declan Rice',
        artist: 'Odumodublvck',
        album: 'EZIOKWU',
        durationMs: 215000,
        artworkUrl: 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'sc_nw_2',
        title: 'Cast',
        artist: 'Shallipopi ft. Odumodublvck',
        album: 'Presido La Pluto',
        durationMs: 168000,
        artworkUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'sc_nw_3',
        title: 'Like Ice Spice',
        artist: 'Blaqbonez',
        album: 'Emeka Must Shine',
        durationMs: 147000,
        artworkUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'sc_nw_4',
        title: 'Bando Diaries',
        artist: 'PsychoYP ft. Odumodublvck',
        album: 'YPSZN3',
        durationMs: 172000,
        artworkUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'sc_nw_5',
        title: 'Big Big Things',
        artist: 'Young Jonn ft. Kizz Daniel & Seyi Vibez',
        album: 'Jiggy Forever',
        durationMs: 198000,
        artworkUrl: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'sc_nw_6',
        title: 'Bust Down',
        artist: 'Zlatan ft. Asake',
        album: 'Bust Down',
        durationMs: 165000,
        artworkUrl: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'sc_nw_7',
        title: 'How To Kill A Man',
        artist: 'Bloody Civilian',
        album: 'Anger Management',
        durationMs: 184000,
        artworkUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'sc_nw_8',
        title: 'No Days Off',
        artist: 'Teni',
        album: 'TEARS OF THE SUN',
        durationMs: 149000,
        artworkUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'sc_nw_9',
        title: 'Ye Anthem',
        artist: 'Smada ft. King Perryy',
        album: 'Ye Anthem',
        durationMs: 158000,
        artworkUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
      ),
      SpotifyTrack(
        id: 'sc_nw_10',
        title: 'Wo Wo',
        artist: 'Minz ft. BNXN & Blaqbonez',
        album: 'Wo Wo (Remix)',
        durationMs: 190000,
        artworkUrl: 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=600&q=80',
      ),
    ],
  ),
];

/// Mornye-Style Mood & Activity Speed Dial Filter Bar
class MornyeMoodFilterBar extends StatelessWidget {
  const MornyeMoodFilterBar({
    required this.selectedMood,
    required this.onSelectMood,
    super.key,
  });

  final String selectedMood;
  final ValueChanged<String> onSelectMood;

  static const List<({String label, String iconText})> moods = [
    (label: 'All', iconText: '✨'),
    (label: 'Energize', iconText: '⚡'),
    (label: 'Chill & Lo-Fi', iconText: '🌙'),
    (label: 'Deep Focus', iconText: '🎧'),
    (label: 'Party & Club', iconText: '🔥'),
    (label: 'Workout', iconText: '💪'),
    (label: 'Commute', iconText: '🚗'),
    (label: 'Afrobeats', iconText: '🥁'),
    (label: 'Trace & Soundcity', iconText: '📺'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: moods.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final m = moods[index];
          final isSelected = m.label == selectedMood;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onSelectMood(m.label),
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.primary
                      : MeloColors.qledCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? colors.primary
                        : Colors.white.withValues(alpha: 0.12),
                    width: 0.9,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: colors.primary.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      m.iconText,
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      m.label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? Colors.white : Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Mornye-Style Signature Quick Picks Shelf
/// (Compact 4-row swipeable multi-column grid with duration, Hi-Res tags, and 1-tap radio)
class QuickPicksShelf extends StatefulWidget {
  const QuickPicksShelf({
    required this.audioHandler,
    this.library,
    this.activeMood = 'All',
    this.provider = MusicProviderType.all,
    super.key,
  });

  final AudioHandler? audioHandler;
  final MusicLibrary? library;
  final String activeMood;
  final MusicProviderType provider;

  @override
  State<QuickPicksShelf> createState() => _QuickPicksShelfState();
}

class _QuickPicksShelfState extends State<QuickPicksShelf> {
  static List<YoutubeTrack>? _cachedTracks;
  List<YoutubeTrack> _tracks = _cachedTracks ?? _PopularSongsShelfState._defaultPopular;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (_cachedTracks == null) {
      unawaited(_loadQuickPicks());
    }
  }

  @override
  void didUpdateWidget(covariant QuickPicksShelf oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeMood != widget.activeMood || oldWidget.provider != widget.provider) {
      unawaited(_loadQuickPicks(mood: widget.activeMood, provider: widget.provider));
    }
  }

  Future<void> _loadQuickPicks({String mood = 'All', MusicProviderType? provider}) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final activeProvider = provider ?? widget.provider;
      if (activeProvider != MusicProviderType.all) {
        final feedTracks = await ExternalFeedService.instance.fetchFeedForProvider(activeProvider, limit: 20);
        if (feedTracks.isNotEmpty && mounted) {
          final mapped = feedTracks.map((t) => YoutubeTrack(
            id: t.providerTrackId ?? t.id.replaceAll(RegExp(r'^[a-z]+:'), ''),
            title: t.title,
            author: t.artist,
            duration: Duration(milliseconds: t.durationMs ?? 180000),
            thumbnailUrl: t.artworkUri,
            album: t.album,
          )).toList();
          _cachedTracks = mapped;
          setState(() {
            _tracks = mapped;
          });
          return;
        }
      }

      final query = switch (mood) {
        'Energize' => 'High Energy Workout Upbeat Dance Hits Official Audio',
        'Chill & Lo-Fi' => 'Chill Lo-Fi Late Night R&B Relaxing Hits Official Audio',
        'Deep Focus' => 'Deep Focus Ambient Electronic Study Beats Instrumental',
        'Party & Club' => 'Club Party Dancefloor Hits Nonstop Official Audio',
        'Workout' => 'Workout Gym Hype Trap Hip Hop Bass Official Audio',
        'Commute' => 'Road Trip Driving Feel Good Hits Official Audio',
        'Afrobeats' => 'Top Afrobeats Amapiano Hits 2025 2026 Official Audio',
        'Trace & Soundcity' => 'Soundcity Trace Top Hits Afrobeats Dancehall Official Audio',
        _ => 'Top Hits 2025 2026 Viral Music Official Audio',
      };

      final results = await YoutubeAudioService.instance.search(
        query,
        filterMixtapes: true,
      );

      final valid = results
          .where((t) =>
              t.duration.inSeconds >= 45 &&
              t.duration.inSeconds <= 660 &&
              !YoutubeAudioService.isMixtapeOrNonstop(t.title, t.duration))
          .take(16)
          .toList();

      if (valid.isNotEmpty && mounted) {
        _cachedTracks = valid;
        setState(() {
          _tracks = valid;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _playTrack(YoutubeTrack track) async {
    final handler = widget.audioHandler;
    if (handler == null) return;
    try {
      final items = _tracks.map((t) => t.toMediaItem()).toList();
      final idx = _tracks.indexWhere((t) => t.id == track.id);
      if (handler is MeloAudioHandler) {
        await handler.replaceQueue(
          items,
          initialIndex: idx >= 0 ? idx : 0,
          playWhenReady: true,
        );
      } else {
        await handler.playMediaItem(track.toMediaItem());
      }
    } catch (_) {}
  }

  Future<void> _queueTrack(YoutubeTrack track, {bool playNext = false}) async {
    final handler = widget.audioHandler;
    if (handler == null) return;
    try {
      final item = track.toMediaItem();
      if (playNext && handler is MeloAudioHandler) {
        await handler.insertQueueItemNext(item);
      } else {
        await handler.addQueueItem(item);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              playNext
                  ? 'Playing "${track.title}" next'
                  : 'Added "${track.title}" to Up Next',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
    } catch (_) {}
  }

  Future<void> _queueSimilar(YoutubeTrack track) async {
    final handler = widget.audioHandler;
    if (handler == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Finding music similar to "${track.title}"...'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
    try {
      final related = await YoutubeAudioService.instance.getRelatedTracks(
        track.id,
        artist: track.author,
        title: track.title,
      );
      var count = 0;
      for (final t in related) {
        await handler.addQueueItem(t.toMediaItem());
        count++;
        if (count >= 10) break;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Added $count similar songs to Up Next'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } catch (_) {}
  }

  Future<void> _downloadTrack(YoutubeTrack track) async {
    final lib = widget.library;
    if (lib == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Downloading "${track.title}" for offline playback...'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    try {
      await DownloadProviderService.instance.downloadTrack(
        library: lib,
        title: track.title,
        artist: track.author,
        artworkUrl: track.thumbnailUrl,
        youtubeTrack: track,
        preferredProvider: widget.provider,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Downloaded "${track.title}" to library'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: MeloColors.cherry,
            duration: const Duration(seconds: 2),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_tracks.isEmpty && !_isLoading) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final currentItem = widget.audioHandler?.mediaItem.value;

    // Group into columns of 4 rows (Mornye standard)
    const chunkSize = 4;
    final columns = <List<YoutubeTrack>>[];
    for (var i = 0; i < _tracks.length; i += chunkSize) {
      columns.add(
        _tracks.sublist(
          i,
          i + chunkSize > _tracks.length ? _tracks.length : i + chunkSize,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ShelfHeader(
          icon: widget.provider == MusicProviderType.all
              ? Icons.trending_up_rounded
              : widget.provider.icon,
          title: widget.provider == MusicProviderType.all
              ? 'Top Hits & Heavy Rotation'
              : '${widget.provider.displayName} Hits',
          badgeLabel: widget.provider == MusicProviderType.all
              ? (widget.activeMood == 'All'
                  ? 'LATEST CHART SINGLES'
                  : widget.activeMood.toUpperCase())
              : widget.provider.displayName.toUpperCase(),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 248,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: columns.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, colIndex) {
              final colTracks = columns[colIndex];
              return SizedBox(
                width: MediaQuery.sizeOf(context).width * 0.84,
                child: Column(
                  children: colTracks.map((track) {
                    final isPlaying = currentItem != null &&
                        (currentItem.id == 'youtube:${track.id}' ||
                            currentItem.id == track.id);
                    return Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _playTrack(track),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(
                                    width: 46,
                                    height: 46,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        if (track.thumbnailUrl != null)
                                          CachedNetworkArtwork(
                                            url: track.thumbnailUrl!,
                                            width: 46,
                                            height: 46,
                                            fit: BoxFit.cover,
                                          )
                                        else
                                          Container(
                                            color: MeloColors.qledCard,
                                            child: const Icon(
                                              Icons.music_note_rounded,
                                              size: 20,
                                              color: Colors.white38,
                                            ),
                                          ),
                                        if (isPlaying)
                                          Container(
                                            color: Colors.black54,
                                            child: const Center(
                                              child: Icon(
                                                Icons.equalizer_rounded,
                                                color: MeloColors.cherry,
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        track.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: isPlaying
                                              ? colors.primary
                                              : Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 1,
                                            ),
                                            decoration: BoxDecoration(
                                              color: colors.primary.withValues(alpha: 0.14),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'HI-RES',
                                              style: TextStyle(
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.w900,
                                                color: colors.primary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              '${track.author} · ${track.durationString}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                color: colors.onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  tooltip: 'Options',
                                  icon: Icon(
                                    Icons.more_vert_rounded,
                                    size: 18,
                                    color: colors.onSurfaceVariant,
                                  ),
                                  color: MeloColors.qledCard,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(
                                      color: Colors.white.withValues(alpha: 0.12),
                                    ),
                                  ),
                                  onSelected: (val) {
                                    if (val == 'play_next') {
                                      _queueTrack(track, playNext: true);
                                    } else if (val == 'queue') {
                                      _queueTrack(track, playNext: false);
                                    } else if (val == 'similar') {
                                      _queueSimilar(track);
                                    } else if (val == 'download') {
                                      _downloadTrack(track);
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    const PopupMenuItem(
                                      value: 'play_next',
                                      child: Row(
                                        children: [
                                          Icon(Icons.playlist_play_rounded, size: 20),
                                          SizedBox(width: 10),
                                          Text('Play next'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'queue',
                                      child: Row(
                                        children: [
                                          Icon(Icons.queue_music_rounded, size: 20),
                                          SizedBox(width: 10),
                                          Text('Add to Up Next'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'similar',
                                      child: Row(
                                        children: [
                                          Icon(Icons.auto_awesome_rounded, size: 20),
                                          SizedBox(width: 10),
                                          Text('Queue similar songs'),
                                        ],
                                      ),
                                    ),
                                    if (widget.library != null)
                                      const PopupMenuItem(
                                        value: 'download',
                                        child: Row(
                                          children: [
                                            Icon(Icons.download_rounded, size: 20),
                                            SizedBox(width: 10),
                                            Text('Download to library'),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Trace & Soundcity Live Broadcast Channels Shelf
class BroadcastChannelsShelf extends StatelessWidget {
  const BroadcastChannelsShelf({
    required this.onPlayPreset,
    super.key,
  });

  final ValueChanged<CuratedPlaylistPreset> onPlayPreset;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.live_tv_rounded,
                    size: 14,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Trace & Soundcity Live Channels',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.5),
                    width: 0.8,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('● ', style: TextStyle(color: Color(0xFFEF4444), fontSize: 9)),
                    Text(
                      'LIVE ON AIR',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 175,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: kTraceSoundcityBroadcastPlaylists.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final preset = kTraceSoundcityBroadcastPlaylists[index];
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => onPlayPreset(preset),
                  child: Container(
                    width: 210,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          preset.gradient.first.withValues(alpha: 0.55),
                          const Color(0xFF0C0A10),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: preset.gradient.first.withValues(alpha: 0.35),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: preset.gradient.first.withValues(alpha: 0.2),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Text(
                                preset.broadcastStation ?? 'BROADCAST',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              preset.icon,
                              color: Colors.white70,
                              size: 18,
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          preset.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          preset.curatorSubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.65),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: MeloColors.cherry.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'ROTATION',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: MeloColors.cherry,
                                ),
                              ),
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.play_circle_fill_rounded,
                              color: MeloColors.cherry,
                              size: 26,
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
