import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:melo_player/app/melo_theme.dart';
import 'package:melo_player/features/home/curated_playlist_screen.dart';
import 'package:melo_player/features/home/home_screen.dart';
import 'package:melo_player/features/home/home_shelves.dart';
import 'package:melo_player/features/library/imported_track.dart';
import 'package:melo_player/features/library/music_library.dart';
import 'package:melo_player/features/library/song_details_sheet.dart';
import 'package:melo_player/features/mix/personal_mix.dart';
import 'package:melo_player/features/mix/smart_playlist_service.dart';
import 'package:melo_player/features/settings/you_screen.dart';
import 'package:melo_player/features/sources/external_feed_service.dart';
import 'package:melo_player/features/sources/multi_lyrics_provider.dart';
import 'package:melo_player/features/sources/multi_metadata_provider.dart';
import 'package:melo_player/features/sources/music_provider_models.dart';
import 'package:melo_player/features/sources/soundcloud_audio_service.dart';
import 'package:melo_player/features/shell/app_shell.dart';
import 'package:melo_player/features/spotify/spotify_import_sheet.dart';
import 'package:melo_player/features/spotify/spotify_service.dart';
import 'package:melo_player/features/youtube/youtube_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MusicProviderType & Models', () {
    test('defines all 7 required external providers with brand identities', () {
      expect(MusicProviderType.values.length, 8); // all + 7 providers

      expect(MusicProviderType.spotify.displayName, 'Spotify Web');
      expect(MusicProviderType.appleMusic.displayName, 'Apple Music');
      expect(MusicProviderType.youtubeMusic.displayName, 'YouTube Music');
      expect(MusicProviderType.deezer.displayName, 'Deezer');
      expect(MusicProviderType.soundcloud.displayName, 'SoundCloud');
      expect(MusicProviderType.tidal.displayName, 'TIDAL');
      expect(MusicProviderType.amazonMusic.displayName, 'Amazon Music');

      expect(MusicProviderType.fromId('apple_music'), MusicProviderType.appleMusic);
      expect(MusicProviderType.fromId('spotify'), MusicProviderType.spotify);
      expect(MusicProviderType.fromId('deezer'), MusicProviderType.deezer);
      expect(MusicProviderType.fromId('soundcloud'), MusicProviderType.soundcloud);
      expect(MusicProviderType.fromId('unknown'), MusicProviderType.all);
    });

    test('validates provider capabilities correctly', () {
      expect(MusicProviderType.youtubeMusic.canDownload, isTrue);
      expect(MusicProviderType.soundcloud.canDownload, isTrue);
      expect(MusicProviderType.deezer.canDownload, isTrue);

      expect(MusicProviderType.spotify.hasLyrics, isTrue);
      expect(MusicProviderType.appleMusic.hasLyrics, isTrue);
      expect(MusicProviderType.deezer.hasLyrics, isTrue);

      expect(MusicProviderType.appleMusic.hasHomeFeed, isTrue);
      expect(MusicProviderType.spotify.hasHomeFeed, isTrue);
      expect(MusicProviderType.soundcloud.hasHomeFeed, isTrue);
      expect(MusicProviderType.deezer.hasHomeFeed, isTrue);
    });

    test('creates UnifiedTrackMetadata with quality badges', () {
      const metaFlac = UnifiedTrackMetadata(
        title: 'Starboy',
        artist: 'The Weeknd',
        album: 'Starboy',
        provider: MusicProviderType.tidal,
        audioCodec: 'FLAC',
        bitrateKbps: 1411,
        isrc: 'USUG11601738',
      );
      expect(metaFlac.qualityBadge, 'FLAC · 1411 KBPS');

      const metaAac = UnifiedTrackMetadata(
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        album: 'After Hours',
        provider: MusicProviderType.appleMusic,
        audioCodec: 'AAC',
        bitrateKbps: 256,
      );
      expect(metaAac.qualityBadge, 'AAC · 256 KBPS');
    });
  });

  group('LyricsAndUtilityProvider', () {
    test('inspects audio formats and bitrates with high accuracy', () {
      final flac = LyricsAndUtilityProvider.inspectAudioFormat('/storage/music/song.flac');
      expect(flac.format, 'FLAC');
      expect(flac.bitrateKbps, 1411);
      expect(flac.isLossless, isTrue);

      final wav = LyricsAndUtilityProvider.inspectAudioFormat('https://cdn.example.com/audio.wav');
      expect(wav.format, 'WAV');
      expect(wav.isLossless, isTrue);

      final m4a = LyricsAndUtilityProvider.inspectAudioFormat('/music/song.m4a');
      expect(m4a.format, 'AAC');
      expect(m4a.isLossless, isFalse);

      final mp3 = LyricsAndUtilityProvider.inspectAudioFormat('https://dzcdn.net/preview.mp3');
      expect(mp3.format, 'MP3');
      expect(mp3.bitrateKbps, 320);
      expect(mp3.isLossless, isFalse);
    });
  });

  group('SoundCloud Audio Service & Feed', () {
    test('SoundCloudTrack converts properly to ImportedTrack', () {
      const sc = SoundCloudTrack(
        id: '123456789',
        title: 'Electronic Odyssey',
        artist: 'Wave Producer',
        durationMs: 240000,
        permalinkUrl: 'https://soundcloud.com/wave/odyssey',
        artworkUrl: 'https://i1.sndcdn.com/art-t500x500.jpg',
        genre: 'Electronic',
      );

      final imported = sc.toImportedTrack();
      expect(imported.id, 'soundcloud:123456789');
      expect(imported.title, 'Electronic Odyssey');
      expect(imported.artist, 'Wave Producer');
      expect(imported.sourceProvider, 'SoundCloud');
      expect(imported.genre, 'Electronic');
    });
  });

  group('Home Feed Provider Settings & Discovery UI', () {
    test('persists and restores selected provider', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      HomeFeedProviderSettings.instance.resetForTesting();

      expect(HomeFeedProviderSettings.instance.activeProvider.value, MusicProviderType.all);

      await HomeFeedProviderSettings.instance.setProvider(MusicProviderType.appleMusic, prefs);
      expect(HomeFeedProviderSettings.instance.activeProvider.value, MusicProviderType.appleMusic);
      expect(prefs.getString('tone_home_feed_provider'), 'apple_music');

      // Re-initialize from prefs
      HomeFeedProviderSettings.instance.resetForTesting();
      await HomeFeedProviderSettings.instance.init(prefs);
      expect(HomeFeedProviderSettings.instance.activeProvider.value, MusicProviderType.appleMusic);

      HomeFeedProviderSettings.instance.resetForTesting();
    });

    testWidgets('renders provider row in Settings and shows bottom sheet picker', (tester) async {
      SharedPreferences.setMockInitialValues({});
      HomeFeedProviderSettings.instance.resetForTesting();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: YouScreen(
              onOpenLibrary: _noop,
              onOpenMix: _noop,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify row exists under APP PREFERENCES
      final providerRow = find.text('Home feed & discovery provider');
      expect(providerRow, findsOneWidget);
      expect(find.textContaining('All Curated'), findsOneWidget);

      // Tap settings row to open bottom sheet
      await tester.tap(providerRow);
      await tester.pumpAndSettle();

      // Verify bottom sheet title and options
      expect(find.text('Home Feed & Discovery Provider'), findsOneWidget);
      expect(find.text('Apple Music'), findsOneWidget);
      expect(find.text('Spotify Web'), findsOneWidget);
      expect(find.text('YouTube Music'), findsOneWidget);

      // Select Apple Music
      await tester.tap(find.text('Apple Music'));
      await tester.pumpAndSettle();

      expect(HomeFeedProviderSettings.instance.activeProvider.value, MusicProviderType.appleMusic);
      HomeFeedProviderSettings.instance.resetForTesting();
    });

    testWidgets('HomeScreen adapts editorial header to active provider', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      HomeFeedProviderSettings.instance.resetForTesting();

      final directory = await tester.runAsync(
        () => Directory.systemTemp.createTemp('tone_provider_home_test_'),
      );
      if (directory == null) fail('Failed to create temp dir');
      addTearDown(() => directory.deleteSync(recursive: true));

      final library = MusicLibrary.forTesting(
        musicDirectory: directory,
        preferences: preferences,
        pickAudio: () async => const [],
        scanDeviceAudio: () async => const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeScreen(
              onOpenLibrary: () {},
              library: library,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Clean home UI: no switcher pills exposed in the open
      expect(find.text('Listen Now'), findsOneWidget);

      // Change provider in settings
      await HomeFeedProviderSettings.instance.setProvider(MusicProviderType.appleMusic);
      await tester.pumpAndSettle();

      // Verify clean home header without corporate provider branding
      expect(find.text('Listen Now'), findsOneWidget);
      expect(find.textContaining('APPLE MUSIC FEED'), findsNothing);
      expect(find.textContaining('SPOTIFY FEED'), findsNothing);
      // Verify Tune Vibe genre customization is accessible directly on Home
      expect(find.text('Tune Vibe'), findsOneWidget);

      HomeFeedProviderSettings.instance.resetForTesting();
      expect(tester.takeException(), isNull);
    });

    test('ExploreItem and ExploreSection serialize to and from JSON', () {
      const item = ExploreItem(
        id: 'am_1',
        uri: 'apple:station:1',
        type: 'station',
        name: 'Apple Music 1 Worldwide',
        artists: 'Zane Lowe',
        heading: 'LIVE BROADCAST',
        coverUrl: 'https://example.com/cover.jpg',
        featuredCoverUrl: 'https://example.com/feat.jpg',
        description: 'Global broadcast',
        explicit: false,
        providerId: 'apple_music',
        durationMs: 180000,
      );

      final jsonItem = item.toJson();
      final fromJsonItem = ExploreItem.fromJson(jsonItem);
      expect(fromJsonItem.id, 'am_1');
      expect(fromJsonItem.uri, 'apple:station:1');
      expect(fromJsonItem.name, 'Apple Music 1 Worldwide');
      expect(fromJsonItem.heading, 'LIVE BROADCAST');
      expect(fromJsonItem.durationMs, 180000);

      const section = ExploreSection(
        uri: 'apple:featured',
        title: 'New in Apple Music',
        layout: 'featured',
        items: [item],
      );
      expect(section.isFeatured, isTrue);
      expect(section.isQuickPicks, isFalse);
      expect(section.isShelf, isFalse);

      final jsonSection = section.toJson();
      final fromJsonSection = ExploreSection.fromJson(jsonSection);
      expect(fromJsonSection.title, 'New in Apple Music');
      expect(fromJsonSection.layout, 'featured');
      expect(fromJsonSection.items.length, 1);
      expect(fromJsonSection.items.first.id, 'am_1');
    });

    test('ExploreFeedCacheStore reads, writes, and clears cache', () async {
      SharedPreferences.setMockInitialValues({});
      final store = ExploreFeedCacheStore.instance;

      final initial = await store.read();
      expect(initial.payload, isNull);

      await store.write('{"sections": []}');
      final afterWrite = await store.read();
      expect(afterWrite.payload, '{"sections": []}');
      expect(afterWrite.timestampMs, isNotNull);

      await store.clear();
      final afterClear = await store.read();
      expect(afterClear.payload, isNull);
    });

    test('ExternalFeedService returns structured Mornye ExploreSections per provider', () async {
      final appleSections = await ExternalFeedService.instance.getHomeFeed(MusicProviderType.appleMusic);
      expect(appleSections.isNotEmpty, isTrue);
      expect(appleSections.any((s) => s.isFeatured), isTrue);
      expect(appleSections.any((s) => s.isQuickPicks), isTrue);
      expect(appleSections.any((s) => s.isShelf), isTrue);

      final ytSections = await ExternalFeedService.instance.getHomeFeed(MusicProviderType.youtubeMusic);
      expect(ytSections.isNotEmpty, isTrue);
      expect(ytSections.any((s) => s.isFeatured), isTrue);

      final spSections = await ExternalFeedService.instance.getHomeFeed(MusicProviderType.spotify);
      expect(spSections.isNotEmpty, isTrue);

      final dzSections = await ExternalFeedService.instance.getHomeFeed(MusicProviderType.deezer);
      expect(dzSections.isNotEmpty, isTrue);

      final scSections = await ExternalFeedService.instance.getHomeFeed(MusicProviderType.soundcloud);
      expect(scSections.isNotEmpty, isTrue);

      final allSections = await ExternalFeedService.instance.getHomeFeed(MusicProviderType.all);
      expect(allSections.isNotEmpty, isTrue);
    });

    testWidgets('ExploreFeaturedSection renders editorial hero cards correctly', (tester) async {
      ExploreItem? tapped;
      const section = ExploreSection(
        uri: 'test:featured',
        title: 'Editorial Spotlight',
        layout: 'featured',
        items: [
          ExploreItem(
            id: 'feat_1',
            uri: 'test:uri:1',
            type: 'station',
            name: 'Apple Music 1 Worldwide',
            artists: 'Zane Lowe & Ebro Darden',
            heading: 'LIVE BROADCAST',
            description: 'Live broadcast of global chart hits',
            providerId: 'apple_music',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExploreFeaturedSection(
              section: section,
              onItemTap: (item) => tapped = item,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Editorial Spotlight'), findsOneWidget);
      expect(find.text('LIVE BROADCAST'), findsOneWidget);
      expect(find.text('Apple Music 1 Worldwide'), findsOneWidget);
      expect(find.text('Zane Lowe & Ebro Darden'), findsOneWidget);
      expect(find.text('Live broadcast of global chart hits'), findsOneWidget);

      await tester.tap(find.text('Apple Music 1 Worldwide'));
      await tester.pumpAndSettle();

      expect(tapped, isNotNull);
      expect(tapped!.id, 'feat_1');
    });

    test('MornyeLyricsMatching normalizes titles, artists and tolerances correctly', () {
      expect(MornyeLyricsMatching.simplifyTrack('Blinding Lights (feat. Rosalía) [Official Audio]'), 'blinding lights');
      expect(MornyeLyricsMatching.simplifyTrack('Hotel California - 2013 Remaster'), 'hotel california');
      expect(MornyeLyricsMatching.primaryArtist('Drake feat. 21 Savage & Project Pat'), 'Drake');
      expect(MornyeLyricsMatching.primaryArtist('Kendrick Lamar, SZA'), 'Kendrick Lamar');
      expect(MornyeLyricsMatching.durationMatches(200.0, 204.0), isTrue);
      expect(MornyeLyricsMatching.durationMatches(200.0, 220.0), isFalse);
      expect(MornyeLyricsMatching.titlesMatch('Espresso (Radio Edit)', 'Espresso'), isTrue);
      expect(MornyeLyricsMatching.artistsMatch('Billie Eilish feat. Khalid', 'Billie Eilish'), isTrue);
    });

    test('LyricsLookupResult serializes and deserializes rich translation & romanization data', () {
      const res = LyricsLookupResult(
        provider: MusicProviderType.appleMusic,
        plainLyrics: 'Hello world',
        syncedLyrics: '[00:10.00]Hello world',
        isWordSynced: true,
        translation: 'Bonjour le monde',
        romanization: 'Konnichiwa sekai',
        writers: 'Songwriter A, Songwriter B',
        source: 'BetterLyrics (Apple Music TTML)',
      );

      final json = res.toJson();
      final fromJson = LyricsLookupResult.fromJson(json);
      expect(fromJson.provider, MusicProviderType.appleMusic);
      expect(fromJson.plainLyrics, 'Hello world');
      expect(fromJson.syncedLyrics, '[00:10.00]Hello world');
      expect(fromJson.isWordSynced, isTrue);
      expect(fromJson.translation, 'Bonjour le monde');
      expect(fromJson.romanization, 'Konnichiwa sekai');
      expect(fromJson.writers, 'Songwriter A, Songwriter B');
      expect(fromJson.source, 'BetterLyrics (Apple Music TTML)');
    });

    test('UnifiedTrackMetadata serializes and deserializes Mornye studio fields', () {
      const meta = UnifiedTrackMetadata(
        title: 'Starboy',
        artist: 'The Weeknd',
        album: 'Starboy',
        provider: MusicProviderType.deezer,
        albumArtist: 'The Weeknd',
        durationMs: 230000,
        artworkUrl: 'https://e-cdns-images.dzcdn.net/images/cover/1400x1400.jpg',
        releaseDate: '2016-11-25',
        isrc: 'USUM71607007',
        genres: ['R&B', 'Pop'],
        composers: ['Abel Tesfaye', 'Thomas Bangalter', 'Guy-Manuel de Homem-Christo'],
        recordLabel: 'Republic Records',
        trackNumber: 1,
        totalTracks: 18,
        discNumber: 1,
        totalDiscs: 1,
        explicit: true,
        audioTraits: ['lossless'],
        audioCodec: 'FLAC',
        bitrateKbps: 1411,
      );

      final json = meta.toJson();
      final fromJson = UnifiedTrackMetadata.fromJson(json);
      expect(fromJson.title, 'Starboy');
      expect(fromJson.artist, 'The Weeknd');
      expect(fromJson.isrc, 'USUM71607007');
      expect(fromJson.trackNumber, 1);
      expect(fromJson.totalTracks, 18);
      expect(fromJson.discNumber, 1);
      expect(fromJson.explicit, isTrue);
      expect(fromJson.audioTraits.contains('lossless'), isTrue);
      expect(fromJson.qualityBadge, 'HI-RES LOSSLESS · 24-BIT');
    });

    testWidgets('SongDetailsSheet mounts cleanly and displays comprehensive metadata', (tester) async {
      SharedPreferences.setMockInitialValues({});
      const meta = UnifiedTrackMetadata(
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        album: 'After Hours',
        provider: MusicProviderType.appleMusic,
        isrc: 'USUG11904206',
        releaseDate: '2020-03-20',
        trackNumber: 9,
        totalTracks: 14,
        composers: ['Abel Tesfaye', 'Ahmad Balshe', 'Jason Quenneville', 'Max Martin', 'Oscar Holter'],
        recordLabel: 'XO / Republic Records',
      );

      final track = ImportedTrack(
        id: 'weeknd_blinding_lights',
        path: '/storage/emulated/0/Music/blinding_lights.mp3',
        title: meta.title,
        artist: meta.artist,
        album: meta.album,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SongDetailsSheet(
              track: track,
              mediaItem: null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Duration'), findsOneWidget);
      expect(find.text('Album'), findsOneWidget);
      expect(find.text('Artist'), findsOneWidget);
      expect(find.text('Origin'), findsOneWidget);
      expect(find.text('Provider'), findsOneWidget);
      expect(find.text('Play Now'), findsOneWidget);
      expect(find.text('Play Next'), findsOneWidget);
    });

    test('MetadataProviderService gracefully handles empty search queries', () async {
      SharedPreferences.setMockInitialValues({});
      final service = MetadataProviderService.instance;
      final result = await service.fetchMetadata(title: '', artist: '');
      expect(result, isNull);
    });

    testWidgets('CuratedPlaylistScreen renders actual catalog tracks directly from preset', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preset = CuratedPlaylistPreset(
        title: "Today's Top Hits",
        curatorSubtitle: 'The hottest 50 tracks worldwide',
        badge: 'TOP 50',
        searchQuery: '',
        gradient: const [Color(0xFF1DB954), Color(0xFF000000)],
        icon: Icons.graphic_eq_rounded,
        deezerPlaylistId: '3155776842',
        initialTracks: const [
          ImportedTrack(
            id: 'sp_1',
            path: 'spotify:track1',
            title: 'Starboy',
            artist: 'The Weeknd',
            album: 'Starboy',
            durationMs: 230000,
          ),
          ImportedTrack(
            id: 'sp_2',
            path: 'spotify:track2',
            title: 'As It Was',
            artist: 'Harry Styles',
            album: "Harry's House",
            durationMs: 167000,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CuratedPlaylistScreen(
              preset: preset,
              audioHandler: null,
              library: null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Today's Top Hits"), findsWidgets);
      expect(find.text('Starboy'), findsOneWidget);
      expect(find.text('As It Was'), findsOneWidget);
    });

    testWidgets('SpotifyImportSheet mounts cleanly with modern segmented cloud tabs', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SpotifyImportSheet(initialTab: 0),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Cloud & Online Playlists'), findsOneWidget);
      expect(find.text('Spotify'), findsOneWidget);
      expect(find.text('YouTube'), findsOneWidget);
      expect(find.text('Direct Link'), findsOneWidget);

      // Tap YouTube tab
      await tester.tap(find.text('YouTube'));
      await tester.pump();

      expect(find.text('Connect Your YouTube Account'), findsOneWidget);

      // Tap Direct Link tab
      await tester.tap(find.text('Direct Link'));
      await tester.pump();

      expect(find.text('Load'), findsOneWidget);
    });

    test('YoutubePlaylistSummary serializes and deserializes properly', () {
      const summary = YoutubePlaylistSummary(
        id: 'PL123456',
        title: 'My Top Afrobeats',
        subtitle: '50 tracks · Curated by Melo',
        thumbnailUrl: 'https://images.unsplash.com/cover.jpg',
        trackCount: 50,
      );

      final json = summary.toJson();
      expect(json['id'], 'PL123456');
      expect(json['title'], 'My Top Afrobeats');
      expect(json['trackCount'], 50);

      final restored = YoutubePlaylistSummary.fromJson(json);
      expect(restored.id, summary.id);
      expect(restored.title, summary.title);
      expect(restored.subtitle, summary.subtitle);
      expect(restored.thumbnailUrl, summary.thumbnailUrl);
      expect(restored.trackCount, summary.trackCount);
    });

    test('SpotifyService exposes userPlaylists and featuredPlaylists cleanly', () {
      expect(SpotifyService.featuredPlaylists.isNotEmpty, isTrue);
      expect(SpotifyService.featuredPlaylists.first.id, '37i9dQZF1DXcBWIGoYBM5M');
      expect(SpotifyService.instance.userPlaylists, isNotNull);
      expect(YoutubeAuthService.instance.userPlaylists, isNotNull);
    });
  });

  group('Dynamic Bespoke Theming & RGB Custom Color Engine', () {
    test('supports MeloThemePalette.custom and dynamic MeloColors getters', () async {
      SharedPreferences.setMockInitialValues({});
      final service = MeloThemeService.instance;
      await service.load();

      // Check default
      expect(service.value.palette, MeloThemePalette.cherry);
      expect(MeloColors.cherry, const Color(0xFFFA243C));

      // Set custom color to electric cyan
      const electricCyan = Color(0xFF06B6D4);
      await service.setCustomColor(electricCyan);

      expect(service.value.palette, MeloThemePalette.custom);
      expect(service.value.customColor.toARGB32(), electricCyan.toARGB32());
      expect(service.value.primaryColor.toARGB32(), electricCyan.toARGB32());

      // MeloColors.cherry now dynamically resolves to the user's custom accent!
      expect(MeloColors.cherry.toARGB32(), electricCyan.toARGB32());
      expect(MeloColors.plum.toARGB32(), electricCyan.toARGB32());
      expect(MeloColors.ember.toARGB32(), electricCyan.toARGB32());

      // Verify theme data builder uses custom color
      final lightTheme = MeloTheme.light;
      final darkTheme = MeloTheme.dark;
      expect(lightTheme.colorScheme.primary.toARGB32(), electricCyan.toARGB32());
      expect(darkTheme.colorScheme.primary.toARGB32(), electricCyan.toARGB32());

      // Reset to cherry
      await service.setPalette(MeloThemePalette.cherry);
      expect(MeloColors.cherry, const Color(0xFFFA243C));
    });

    testWidgets('AppearanceInfoScreen renders custom bespoke picker and spectrum chips', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: MeloTheme.dark,
          home: const AppearanceInfoScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AUDIOPHILE THEME PALETTES'), findsOneWidget);
      expect(find.text('Custom Bespoke'), findsOneWidget);
      expect(find.text('BESPOKE SPECTRUM & RGB PICKER'), findsOneWidget);
      expect(find.text('Quick Spectrum Swatches'), findsOneWidget);
      expect(find.text('Open RGB Sliders & Hex Code Picker'), findsOneWidget);

      // Open RGB dialog
      await tester.tap(find.text('Open RGB Sliders & Hex Code Picker'));
      await tester.pumpAndSettle();

      expect(find.text('Custom RGB & Hex Accent'), findsOneWidget);
      expect(find.text('LIVE PREVIEW'), findsOneWidget);
      expect(find.text('Apply Color Accent App-Wide'), findsOneWidget);
    });
  });

  group('Trace & Soundcity Live Broadcast Charts & New Releases', () {
    test('kTraceSoundcityBroadcastPlaylists are hooked to live verified chart IDs', () {
      expect(kTraceSoundcityBroadcastPlaylists.length >= 4, isTrue);

      final soundcityTop10 = kTraceSoundcityBroadcastPlaylists.firstWhere(
        (p) => p.title.contains('Soundcity Top 10'),
      );
      expect(soundcityTop10.deezerPlaylistId, '1362529295');
      expect(soundcityTop10.spotifyPlaylistId, '37i9dQZF1DWYkaDif7Ztbp');
      expect(soundcityTop10.isBroadcastChannel, isTrue);

      final traceUrban = kTraceSoundcityBroadcastPlaylists.firstWhere(
        (p) => p.title.contains('Trace Urban'),
      );
      expect(traceUrban.deezerPlaylistId, '3155776842');
      expect(traceUrban.spotifyPlaylistId, '37i9dQZF1DXcBWIGoYBM5M');

      final traceAfrica = kTraceSoundcityBroadcastPlaylists.firstWhere(
        (p) => p.title.contains('Trace Africa'),
      );
      expect(traceAfrica.deezerPlaylistId, '1393664765');

      final amapiano = kTraceSoundcityBroadcastPlaylists.firstWhere(
        (p) => p.title.contains('Amapiano'),
      );
      expect(amapiano.deezerPlaylistId, '6158737704');
    });

    test('kRecommendedPlaylists includes dedicated live New Releases preset', () {
      final newReleases = kRecommendedPlaylists.firstWhere(
        (p) => p.badge == 'NEW RELEASES',
      );
      expect(newReleases.title, 'New Releases & Fresh Drops');
      expect(newReleases.deezerPlaylistId, isNotNull);
      expect(newReleases.genre, 'New Releases');
    });
  });

  group('SpotifyRecommendationEngine & Algorithm Verification', () {
    test('computes Camelot harmonic compatibility accurately', () {
      expect(SpotifyRecommendationEngine.parseCamelot('8A'), (8, 'A'));
      expect(SpotifyRecommendationEngine.parseCamelot('11b'), (11, 'B'));
      expect(SpotifyRecommendationEngine.parseCamelot('invalid'), isNull);

      // Same key = perfect score 30
      expect(SpotifyRecommendationEngine.harmonicScore('8A', '8A'), 30.0);

      // Relative major / minor = 22
      expect(SpotifyRecommendationEngine.harmonicScore('8A', '8B'), 22.0);

      // Adjacent Camelot step (8A -> 7A or 9A) = 25
      expect(SpotifyRecommendationEngine.harmonicScore('8A', '7A'), 25.0);
      expect(SpotifyRecommendationEngine.harmonicScore('8A', '9A'), 25.0);

      // Wrap around (12A -> 1A) = 25
      expect(SpotifyRecommendationEngine.harmonicScore('12A', '1A'), 25.0);

      // Distant key clash = 0
      expect(SpotifyRecommendationEngine.harmonicScore('8A', '4A'), 0.0);
    });

    test('computes BPM tempo matching within Spotify +-8% tolerance', () {
      // 120 BPM vs 122 BPM (1.6% diff) -> +25
      expect(SpotifyRecommendationEngine.tempoScore(120.0, 122.0), 25.0);

      // 120 BPM vs 130 BPM (8.3% diff) -> +15
      expect(SpotifyRecommendationEngine.tempoScore(120.0, 130.0), 15.0);

      // Half-time / Double-time (70 BPM vs 140 BPM) -> +18
      expect(SpotifyRecommendationEngine.tempoScore(70.0, 140.0), 18.0);

      // Huge tempo mismatch (80 BPM vs 145 BPM) -> 0
      expect(SpotifyRecommendationEngine.tempoScore(80.0, 145.0), 0.0);
    });

    test('computes release era scoring based on chronological proximity', () {
      // Same year or +-1 year (e.g. 2024 vs 2025) -> +20
      expect(SpotifyRecommendationEngine.eraScore(2025, 2024), 20.0);

      // Within 3 years (e.g. 2025 vs 2022) -> +15
      expect(SpotifyRecommendationEngine.eraScore(2025, 2022), 15.0);

      // Within 6 years -> +8
      expect(SpotifyRecommendationEngine.eraScore(2025, 2019), 8.0);

      // 20 years apart -> 0
      expect(SpotifyRecommendationEngine.eraScore(2025, 1995), 0.0);
    });

    test('scores composite candidate with multi-dimensional affinity', () {
      final highAffinity = SpotifyRecommendationEngine.scoreCandidate(
        seedTitle: 'Last Last',
        seedArtist: 'Burna Boy',
        seedGenre: 'Afrobeats',
        seedYear: 2022,
        seedBpm: 104.0,
        seedMusicalKey: '8A',
        candidateTitle: 'City Boys',
        candidateArtist: 'Burna Boy',
        candidateGenre: 'Afrobeats',
        candidateYear: 2023,
        candidateBpm: 106.0,
        candidateMusicalKey: '9A',
      );

      final unrelatedCandidate = SpotifyRecommendationEngine.scoreCandidate(
        seedTitle: 'Last Last',
        seedArtist: 'Burna Boy',
        seedGenre: 'Afrobeats',
        seedYear: 2022,
        seedBpm: 104.0,
        seedMusicalKey: '8A',
        candidateTitle: 'Fur Elise',
        candidateArtist: 'Beethoven',
        candidateGenre: 'Classical',
        candidateYear: 1810,
        candidateBpm: 140.0,
        candidateMusicalKey: '2B',
      );

      expect(highAffinity > 100.0, isTrue);
      expect(unrelatedCandidate < 25.0, isTrue);
    });
  });

  group('Spotify URL Parsing & Light Theme Fixes (v1.6.9)', () {
    test('parses international, user, and query-parameter Spotify URLs correctly', () {
      // International /intl-de/ URL with query string
      final res1 = SpotifyService.parseSpotifyUrlOrId(
        'https://open.spotify.com/intl-de/playlist/37i9dQZF1DXcBWIGoYBM5M?si=b3579b1836fd4ce8',
      );
      expect(res1, isNotNull);
      expect(res1!.$1, '37i9dQZF1DXcBWIGoYBM5M');
      expect(res1.$2, 'playlist');

      // International /intl-es/ album URL
      final res2 = SpotifyService.parseSpotifyUrlOrId(
        'https://open.spotify.com/intl-es/album/4aawyAB9vmqN3uQ7FjRGTy?si=xyz',
      );
      expect(res2, isNotNull);
      expect(res2!.$1, '4aawyAB9vmqN3uQ7FjRGTy');
      expect(res2.$2, 'album');

      // User playlist URL
      final res3 = SpotifyService.parseSpotifyUrlOrId(
        'https://open.spotify.com/user/spotify/playlist/37i9dQZF1DXcBWIGoYBM5M',
      );
      expect(res3, isNotNull);
      expect(res3!.$1, '37i9dQZF1DXcBWIGoYBM5M');
      expect(res3.$2, 'playlist');

      // Spotify user URI
      final res4 = SpotifyService.parseSpotifyUrlOrId(
        'spotify:user:12345:playlist:37i9dQZF1DXcBWIGoYBM5M',
      );
      expect(res4, isNotNull);
      expect(res4!.$1, '37i9dQZF1DXcBWIGoYBM5M');
      expect(res4.$2, 'playlist');

      // Standard URI
      final res5 = SpotifyService.parseSpotifyUrlOrId(
        'spotify:track:5ViLKrbyL3HD6wsq3AB9eI',
      );
      expect(res5, isNotNull);
      expect(res5!.$1, '5ViLKrbyL3HD6wsq3AB9eI');
      expect(res5.$2, 'track');

      // Raw ID with 22 characters
      final res6 = SpotifyService.parseSpotifyUrlOrId('37i9dQZF1DXcBWIGoYBM5M');
      expect(res6, isNotNull);
      expect(res6!.$1, '37i9dQZF1DXcBWIGoYBM5M');
      expect(res6.$2, 'playlist');
    });

    testWidgets('AppShell renders with light paper surface under light theme', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final lightTheme = MeloTheme.themeFor(Brightness.light);
      expect(lightTheme.colorScheme.surface, MeloColors.paper);

      await tester.pumpWidget(
        MaterialApp(
          theme: lightTheme,
          home: const AppShell(),
        ),
      );
      await tester.pump();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, MeloColors.paper);
      expect(scaffold.backgroundColor, isNot(MeloColors.amoled));
    });

    test('ImportedTrack.fromMediaItem correctly copies genre and metadata', () {
      const item = MediaItem(
        id: 'test_track_1',
        title: 'Clarks',
        artist: 'Vybz Kartel',
        genre: 'Dancehall',
        extras: {'genre': 'Dancehall', 'year': 2010},
      );
      final track = ImportedTrack.fromMediaItem(item);
      expect(track.id, 'test_track_1');
      expect(track.title, 'Clarks');
      expect(track.artist, 'Vybz Kartel');
      expect(track.genre, 'Dancehall');
      expect(track.year, 2010);
    });

    test('PersonalMixGenerator filters and prioritizes by genre', () {
      final tracks = [
        const ImportedTrack(
          id: '1',
          path: '/music/1.mp3',
          title: 'Fever',
          artist: 'Vybz Kartel',
          album: 'King of the Dancehall',
          durationMs: 180000,
          genre: 'Dancehall',
        ),
        const ImportedTrack(
          id: '2',
          path: '/music/2.mp3',
          title: 'Midnight Sky',
          artist: 'Miley Cyrus',
          album: 'Plastic Hearts',
          durationMs: 200000,
          genre: 'Pop',
        ),
      ];

      final mix = PersonalMixGenerator.generate(
        tracks: tracks,
        favoriteTrackIds: {},
        excludedTrackIds: {},
        targetDuration: const Duration(minutes: 5),
        discovery: 0.5,
        genre: 'Dancehall',
      );

      expect(mix.isNotEmpty, isTrue);
      expect(mix.first.track.genre, 'Dancehall');
      expect(mix.first.track.artist, 'Vybz Kartel');
    });

    test('SmartPlaylistService generateGenreMix generates stamped genre items', () async {
      final mix = await SmartPlaylistService.instance.generateGenreMix(
        genre: 'Dancehall',
        seed: 42,
      );

      expect(mix.title, contains('Dancehall'));
      expect(mix.isContinuous, isTrue);
      expect(mix.seedArtist, 'Dancehall');
    });
  });
}

void _noop() {}
