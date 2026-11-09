import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:melo_player/features/library/song_metadata_enricher.dart';
import 'package:melo_player/features/player/lyrics_repository.dart';
import 'package:melo_player/features/sources/audio_addon.dart';
import 'package:melo_player/features/spotify/spotify_service.dart';
import 'package:melo_player/features/updates/app_update_service.dart';
import 'package:melo_player/features/youtube/youtube_audio_service.dart';
import 'package:melo_player/features/youtube/youtube_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('YouTube Audio Service', () {
    test('YoutubeTrack models convert accurately to Tone ImportedTrack and MediaItem', () {
      const track = YoutubeTrack(
        id: 'dQw4w9WgXcQ',
        title: 'Never Gonna Give You Up',
        author: 'Rick Astley',
        duration: Duration(minutes: 3, seconds: 33),
        thumbnailUrl: 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
        viewCount: '1.5B views',
      );

      expect(track.durationString, '3:33');

      final imported = track.toImportedTrack();
      expect(imported.id, 'youtube:dQw4w9WgXcQ');
      expect(imported.title, 'Never Gonna Give You Up');
      expect(imported.artist, 'Rick Astley');
      expect(imported.album, 'YouTube Music');
      expect(imported.durationMs, 213000);
      expect(imported.sourceProvider, 'YouTube');
      expect(imported.providerTrackId, 'dQw4w9WgXcQ');
      expect(imported.artworkUri, 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg');

      final mediaItem = imported.toMediaItem();
      expect(mediaItem.id, 'youtube:dQw4w9WgXcQ');
      expect(mediaItem.title, 'Never Gonna Give You Up');
      expect(mediaItem.extras?['downloadProvider'], 'YouTube');
      expect(mediaItem.extras?['providerTrackId'], 'dQw4w9WgXcQ');
    });

    test('YoutubeStreamDetails holds audio stream metadata', () {
      const details = YoutubeStreamDetails(
        url: 'https://example.com/audio.m4a',
        mimeType: 'audio/mp4',
        bitrate: 128000,
        sampleRate: 44100,
        channelCount: 2,
        codec: 'AAC',
      );
      expect(details.url, 'https://example.com/audio.m4a');
      expect(details.mimeType, 'audio/mp4');
      expect(details.bitrate, 128000);
      expect(details.codec, 'AAC');
    });

    test('Audio quality setting persists and retrieves correctly', () async {
      SharedPreferences.setMockInitialValues({});
      await YoutubeAudioService.instance.setPreferredQuality(YoutubeAudioQuality.dataSaver);
      final pref = await YoutubeAudioService.instance.getPreferredQuality();
      expect(pref, YoutubeAudioQuality.dataSaver);

      await YoutubeAudioService.instance.setPreferredQuality(YoutubeAudioQuality.highest);
      final pref2 = await YoutubeAudioService.instance.getPreferredQuality();
      expect(pref2, YoutubeAudioQuality.highest);
    });
  });

  group('YouTube Auth & Taste Service', () {
    test('initializes with default taste genres and logged out state', () async {
      SharedPreferences.setMockInitialValues({});
      final auth = YoutubeAuthService.instance;
      await auth.initialize();

      expect(auth.isLoggedIn, isFalse);
      expect(auth.favoriteGenres, contains('Hip-Hop'));
      expect(auth.favoriteGenres, contains('Electronic'));
    });

    test('updates and persists favorite genre tags', () async {
      SharedPreferences.setMockInitialValues({});
      final auth = YoutubeAuthService.instance;
      await auth.initialize();

      await auth.setFavoriteGenres(['Synthwave', 'Deep House', 'Lo-Fi']);
      expect(auth.favoriteGenres, ['Synthwave', 'Deep House', 'Lo-Fi']);
    });

    test('handles logout and clears session', () async {
      SharedPreferences.setMockInitialValues({});
      final auth = YoutubeAuthService.instance;
      await auth.logout();

      expect(auth.isLoggedIn, isFalse);
      expect(auth.accountName, isNull);
      expect(auth.avatarUrl, isNull);
    });
  });

  group('Spotify Service', () {
    final service = SpotifyService.instance;

    test('extracts playlist IDs from various Spotify URL formats', () {
      expect(
        service.extractPlaylistId('https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M'),
        '37i9dQZF1DXcBWIGoYBM5M',
      );
      expect(
        service.extractPlaylistId('https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M?si=abcd1234'),
        '37i9dQZF1DXcBWIGoYBM5M',
      );
      expect(
        service.extractPlaylistId('spotify:playlist:37i9dQZF1DXcBWIGoYBM5M'),
        '37i9dQZF1DXcBWIGoYBM5M',
      );
      expect(
        service.extractPlaylistId('37i9dQZF1DXcBWIGoYBM5M'),
        '37i9dQZF1DXcBWIGoYBM5M',
      );
      expect(service.extractPlaylistId('invalid-url-string'), isNull);
    });

    test('SpotifyTrack models convert accurately to Tone ImportedTrack', () {
      const track = SpotifyTrack(
        id: '4cOdK2wGLETKBW3PvgPWqT',
        title: 'Starboy',
        artist: 'The Weeknd, Daft Punk',
        album: 'Starboy',
        durationMs: 230453,
        artworkUrl: 'https://i.scdn.co/image/ab67616d0000b2734718e2b124f79258be7bc452',
      );

      expect(track.durationString, '3:50');

      final imported = track.toImportedTrack();
      expect(imported.id, 'spotify:4cOdK2wGLETKBW3PvgPWqT');
      expect(imported.title, 'Starboy');
      expect(imported.artist, 'The Weeknd, Daft Punk');
      expect(imported.album, 'Starboy');
      expect(imported.durationMs, 230453);
      expect(imported.sourceProvider, 'Spotify');
      expect(imported.providerTrackId, '4cOdK2wGLETKBW3PvgPWqT');

      final mediaItem = imported.toMediaItem();
      expect(mediaItem.id, 'spotify:4cOdK2wGLETKBW3PvgPWqT');
      expect(mediaItem.extras?['downloadProvider'], 'Spotify');
    });

    test('SpotifyPlaylistData calculates total duration accurately', () {
      const playlist = SpotifyPlaylistData(
        id: 'test-playlist',
        title: 'My Test Playlist',
        description: 'Testing duration',
        tracks: [
          SpotifyTrack(
            id: 't1',
            title: 'Track 1',
            artist: 'Artist 1',
            album: 'Album 1',
            durationMs: 180000, // 3 min
          ),
          SpotifyTrack(
            id: 't2',
            title: 'Track 2',
            artist: 'Artist 2',
            album: 'Album 2',
            durationMs: 240000, // 4 min
          ),
        ],
      );

      expect(playlist.tracks.length, 2);
      expect(playlist.totalDurationMs, 420000);
      expect(playlist.totalDurationString, '7m');
    });

    test('Featured playlists list is populated with rich presets', () {
      expect(SpotifyService.featuredPlaylists.isNotEmpty, isTrue);
      for (final featured in SpotifyService.featuredPlaylists) {
        expect(featured.id.isNotEmpty, isTrue);
        expect(featured.title.isNotEmpty, isTrue);
        expect(featured.artworkUrl.startsWith('https://'), isTrue);
      }
    });
  });

  group('Audio Addon Manager (BitChord Architecture)', () {
    test('loads default addons with correct priority and enabled state', () async {
      SharedPreferences.setMockInitialValues({});
      final manager = AudioAddonManager.instance;
      await manager.initialize();

      expect(manager.addons.length, 4);
      expect(manager.isAddonActive('youtube_music'), isTrue);
      expect(manager.isAddonActive('spotify_matcher'), isTrue);
      expect(manager.isAddonActive('lrclib_itunes_metadata'), isTrue);
      expect(manager.isAddonActive('subsonic_navidrome'), isFalse);
    });

    test('toggles addon status and persists preference', () async {
      SharedPreferences.setMockInitialValues({});
      final manager = AudioAddonManager.instance;
      await manager.initialize();

      await manager.setAddonEnabled('youtube_music', false);
      expect(manager.isAddonActive('youtube_music'), isFalse);

      await manager.setAddonEnabled('youtube_music', true);
      expect(manager.isAddonActive('youtube_music'), isTrue);
    });

    test('saves and detects Subsonic server configuration', () async {
      SharedPreferences.setMockInitialValues({});
      final manager = AudioAddonManager.instance;
      await manager.initialize();

      expect(manager.isAddonConfigured('subsonic_navidrome'), isFalse);

      await manager.saveSubsonicConfig(
        const SubsonicConfig(
          serverUrl: 'https://music.home.internal',
          username: 'audiophile',
          password: 'secretPassword123',
        ),
      );

      expect(manager.subsonicConfig.isConfigured, isTrue);
      expect(manager.isAddonConfigured('subsonic_navidrome'), isTrue);
    });
  });

  group('Mornye Lyrics & Word Timing', () {
    test('parses explicit word timings in enhanced LRC', () {
      const lrc = '[00:01.00]<00:01.00>Never <00:01.50>gonna <00:02.00>give';
      final lyrics = SongLyrics.parse(synchronized: lrc);
      expect(lyrics, isNotNull);
      expect(lyrics!.isSynchronized, isTrue);
      expect(lyrics.hasWordTiming, isTrue);
      expect(lyrics.lines.first.words.length, 3);
      expect(lyrics.lines.first.hasExplicitWords, isTrue);
      expect(lyrics.lines.first.activeWordAt(const Duration(milliseconds: 1600)), 1);
    });

    test('interpolates word timings for line-synced lyrics without breaking line timing', () {
      const lrc = '[00:01.00]Hello world from Tone\n[00:05.00]Next lyric line';
      final lyrics = SongLyrics.parse(synchronized: lrc);
      expect(lyrics, isNotNull);
      expect(lyrics!.isSynchronized, isTrue);
      expect(lyrics.hasWordTiming, isFalse); // hasExplicitWords is false
      expect(lyrics.lines.first.words.isNotEmpty, isTrue); // interpolated for sing-along
      expect(lyrics.lines.first.words.length, 4); // Hello, world, from, Tone
      expect(lyrics.lines.first.hasExplicitWords, isFalse);
    });
  });

  group('SongMetadataEnricher & Duplicate Detection', () {
    test('cleans noisy video suffixes and artist-prefixed titles', () {
      expect(
        SongMetadataEnricher.cleanTitle(
          'The Weeknd - Starboy (Official Video) ft. Daft Punk.m4a',
          rawArtist: 'The Weeknd',
        ),
        'Starboy ft. Daft Punk',
      );
      expect(
        SongMetadataEnricher.cleanArtist('The Weeknd - Topic'),
        'The Weeknd',
      );
      expect(
        SongMetadataEnricher.cleanArtist(
          'Unknown artist',
          rawTitle: 'Daft Punk - Get Lucky (Official Audio)',
        ),
        'Daft Punk',
      );
    });

    test('produces identical canonical song keys across local and streaming variants', () {
      final keyA = SongMetadataEnricher.canonicalSongKey(
        'Starboy (Official Music Video)',
        'The Weeknd - Topic',
      );
      final keyB = SongMetadataEnricher.canonicalSongKey(
        '01 - Starboy.mp3',
        'The Weeknd feat. Daft Punk',
      );
      expect(keyA, keyB);
    });
  });

  group('GitHub Releases AppUpdateService', () {
    test('compares semantic versions and build numbers accurately', () {
      expect(
        AppUpdateService.isRemoteVersionNewer(
          currentVersion: '1.0.0',
          currentBuild: 1,
          remoteTag: 'v1.0.1',
        ),
        isTrue,
      );
      expect(
        AppUpdateService.isRemoteVersionNewer(
          currentVersion: '1.0.0',
          currentBuild: 1,
          remoteTag: 'v1.1.0',
        ),
        isTrue,
      );
      expect(
        AppUpdateService.isRemoteVersionNewer(
          currentVersion: '1.2.0',
          currentBuild: 5,
          remoteTag: 'v1.2.0',
        ),
        isFalse,
      );
      expect(
        AppUpdateService.isRemoteVersionNewer(
          currentVersion: '1.2.0',
          currentBuild: 5,
          remoteTag: 'v1.2.0+6',
        ),
        isTrue,
      );
    });

    test('selects arm64-v8a APK asset from GitHub release assets', () {
      const release = GithubReleaseInfo(
        tagName: 'v1.1.0',
        title: 'Tone v1.1.0',
        body: 'New features and fixes',
        htmlUrl: 'https://github.com/ossy-harz/Tone/releases/tag/v1.1.0',
        publishedAt: null,
        isPrerelease: false,
        assets: [
          GithubReleaseAsset(
            name: 'checksums.txt',
            downloadUrl: 'https://example.com/checksums.txt',
            sizeBytes: 256,
          ),
          GithubReleaseAsset(
            name: 'Tone-v1.1.0-arm64-v8a.apk',
            downloadUrl: 'https://example.com/Tone-v1.1.0-arm64-v8a.apk',
            sizeBytes: 24117248,
          ),
        ],
      );
      expect(release.preferredApkAsset, isNotNull);
      expect(release.preferredApkAsset!.name, 'Tone-v1.1.0-arm64-v8a.apk');
      expect(release.preferredApkAsset!.formattedSize, '23.0 MB');
    });

    test('prefers universal release apk for all-device compatibility', () {
      const release = GithubReleaseInfo(
        tagName: 'v1.3.7',
        title: 'Melo v1.3.7',
        body: 'Release notes',
        htmlUrl: 'https://github.com/ossy-harz/Melo/releases/tag/v1.3.7',
        publishedAt: null,
        isPrerelease: false,
        assets: [
          GithubReleaseAsset(
            name: 'melo-v1.3.7-arm64-v8a.apk',
            downloadUrl: 'https://example.com/arm64.apk',
            sizeBytes: 20000000,
          ),
          GithubReleaseAsset(
            name: 'app-release.apk',
            downloadUrl: 'https://example.com/app-release.apk',
            sizeBytes: 45000000,
          ),
        ],
      );
      expect(release.preferredApkAsset, isNotNull);
      expect(release.preferredApkAsset!.name, 'app-release.apk');
    });
  });
}
