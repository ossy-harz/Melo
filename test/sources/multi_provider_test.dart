import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:melo_player/features/home/home_screen.dart';
import 'package:melo_player/features/library/music_library.dart';
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

  group('Home Screen Provider Switcher UI', () {
    testWidgets('renders minimalist provider switcher bar and toggles provider', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final directory = await tester.runAsync(
        () => Directory.systemTemp.createTemp('tone_provider_switcher_test_'),
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

      // Verify first providers visible
      expect(find.text('All Curated'), findsOneWidget);
      expect(find.text('Apple Music'), findsOneWidget);
      expect(find.text('Spotify Web'), findsOneWidget);

      // Tap Apple Music provider pill
      await tester.tap(find.text('Apple Music'));
      await tester.pumpAndSettle();

      // Scroll to view trailing providers
      await tester.scrollUntilVisible(
        find.text('SoundCloud'),
        100,
        scrollable: find.byType(Scrollable).at(1),
      );
      expect(find.text('SoundCloud'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  });
}
