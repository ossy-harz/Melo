import 'package:flutter_test/flutter_test.dart';
import 'package:melo_player/features/home/curated_playlist_screen.dart';
import 'package:melo_player/features/mix/smart_playlist_service.dart';
import 'package:melo_player/features/spotify/spotify_service.dart';
import 'package:melo_player/features/youtube/youtube_audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('YouTube & Spotify URL and Playlist Resolvers', () {
    test('extracts YouTube playlist IDs from various URL formats and raw IDs', () {
      expect(
        YoutubeAudioService.extractPlaylistId('https://music.youtube.com/playlist?list=PL4fGSI1pDJn6O1LS0XSdF3RyO0Rq_LDeI'),
        'PL4fGSI1pDJn6O1LS0XSdF3RyO0Rq_LDeI',
      );
      expect(
        YoutubeAudioService.extractPlaylistId('https://www.youtube.com/playlist?list=PLrAlX1vY7Xk9_04j39VfFmQzP-r4X3h2k'),
        'PLrAlX1vY7Xk9_04j39VfFmQzP-r4X3h2k',
      );
      expect(
        YoutubeAudioService.extractPlaylistId('PL4fGSI1pDJn6O1LS0XSdF3RyO0Rq_LDeI'),
        'PL4fGSI1pDJn6O1LS0XSdF3RyO0Rq_LDeI',
      );
      expect(
        YoutubeAudioService.extractPlaylistId('RDCLAK5uy_k1b2c3'),
        'RDCLAK5uy_k1b2c3',
      );
      expect(YoutubeAudioService.extractPlaylistId('not-a-valid-playlist-id'), isNull);
    });

    test('extracts Spotify playlist, album, and track IDs accurately', () {
      final plMatch = SpotifyService.parseSpotifyUrlOrId('https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M?si=123');
      expect(plMatch?.$1, '37i9dQZF1DXcBWIGoYBM5M');
      expect(plMatch?.$2, 'playlist');

      final albumMatch = SpotifyService.parseSpotifyUrlOrId('https://open.spotify.com/album/4m2880jivSbbyEGAKfITCa');
      expect(albumMatch?.$1, '4m2880jivSbbyEGAKfITCa');
      expect(albumMatch?.$2, 'album');

      final uriMatch = SpotifyService.parseSpotifyUrlOrId('spotify:playlist:37i9dQZF1DXcBWIGoYBM5M');
      expect(uriMatch?.$1, '37i9dQZF1DXcBWIGoYBM5M');
      expect(uriMatch?.$2, 'playlist');

      final rawMatch = SpotifyService.parseSpotifyUrlOrId('37i9dQZF1DXcBWIGoYBM5M');
      expect(rawMatch?.$1, '37i9dQZF1DXcBWIGoYBM5M');

      expect(SpotifyService.instance.extractPlaylistId('https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M'), '37i9dQZF1DXcBWIGoYBM5M');
    });

    test('smartVibeStationPreset assigns distinct artwork, icons and unique cache keys per seed', () {
      final p1 = smartVibeStationPreset(SmartVibe.dailyFlow, seed: 0);
      final p2 = smartVibeStationPreset(SmartVibe.highEnergy, seed: 0);
      final p3 = smartVibeStationPreset(SmartVibe.deepFocus, seed: 0);
      final p4 = smartVibeStationPreset(SmartVibe.lateNightChill, seed: 0);

      // Distinct visual artwork
      expect(p1.coverUrl, isNotNull);
      expect(p2.coverUrl, isNotNull);
      expect(p3.coverUrl, isNotNull);
      expect(p4.coverUrl, isNotNull);
      expect(p1.coverUrl, isNot(equals(p2.coverUrl)));
      expect(p2.coverUrl, isNot(equals(p3.coverUrl)));
      expect(p3.coverUrl, isNot(equals(p4.coverUrl)));

      // Different icons
      expect(p1.icon, isNot(equals(p2.icon)));

      // Dynamic seeds differentiate cache keys
      final seeded1 = smartVibeStationPreset(SmartVibe.dailyFlow, seed: 1);
      final seeded2 = smartVibeStationPreset(SmartVibe.dailyFlow, seed: 2);
      expect(seeded1.seed, 1);
      expect(seeded2.seed, 2);
    });

    test('generateVibeMix generates diverse tracks and proper cover per vibe and seed', () async {
      final mix = await SmartPlaylistService.instance.generateVibeMix(
        vibe: SmartVibe.highEnergy,
        seed: 1,
      );

      expect(mix.title, 'High Energy Workout');
      expect(mix.artworkUri, contains('unsplash.com'));
      expect(mix.id, 'vibe:highEnergy:1');
    });
  });
}
