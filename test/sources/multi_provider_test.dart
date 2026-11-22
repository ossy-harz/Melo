import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:melo_player/features/home/home_screen.dart';
import 'package:melo_player/features/home/home_shelves.dart';
import 'package:melo_player/features/library/music_library.dart';
import 'package:melo_player/features/settings/you_screen.dart';
import 'package:melo_player/features/sources/external_feed_service.dart';
import 'package:melo_player/features/sources/multi_lyrics_provider.dart';
import 'package:melo_player/features/sources/music_provider_models.dart';
import 'package:melo_player/features/sources/soundcloud_audio_service.dart';

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

      // Verify eyebrow adapted specifically
      expect(find.textContaining('APPLE MUSIC FEED'), findsOneWidget);

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
  });
}

void _noop() {}
