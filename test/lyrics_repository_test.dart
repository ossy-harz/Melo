import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tone_player/features/player/lyrics_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parses synchronized timestamps and ignores LRC metadata', () {
    final lyrics = SongLyrics.parse(
      synchronized:
          '[ar:Tone Test]\n'
          '[00:02.50]Second line\n'
          '[00:01.00][00:01.50]First line',
    );

    expect(lyrics, isNotNull);
    expect(lyrics!.isSynchronized, isTrue);
    expect(lyrics.lines.map((line) => line.text), [
      'First line',
      'First line',
      'Second line',
    ]);
    expect(lyrics.activeLineAt(const Duration(milliseconds: 1700)), 1);
    expect(lyrics.activeLineAt(const Duration(milliseconds: 2600)), 2);
  });

  test('applies LRC offset metadata to synchronized line times', () {
    final lyrics = SongLyrics.parse(
      synchronized: '[offset:750]\n[00:01.00]A delayed line',
    );

    expect(lyrics, isNotNull);
    expect(lyrics!.lines.single.time, const Duration(milliseconds: 1750));
    expect(lyrics.activeLineAt(const Duration(milliseconds: 1600)), -1);
    expect(lyrics.activeLineAt(const Duration(milliseconds: 1800)), 0);
  });

  test('parses enhanced LRC word timings for karaoke-style highlighting', () {
    final lyrics = SongLyrics.parse(
      synchronized:
          '[offset:100]\n'
          '[00:01.00]<00:01.00>Hello <00:01.45>there',
    );

    expect(lyrics, isNotNull);
    expect(lyrics!.hasWordTiming, isTrue);
    expect(lyrics.lines.single.text, 'Hello there');
    expect(lyrics.lines.single.words.map((word) => word.text), [
      'Hello',
      'there',
    ]);
    expect(lyrics.activeWordAt(0, const Duration(milliseconds: 1400)), 0);
    expect(lyrics.activeWordAt(0, const Duration(milliseconds: 1600)), 1);
    expect(lyrics.activeWordAt(0, const Duration(milliseconds: 1000)), -1);
  });

  test('parses word-timed lyrics without a separate line timestamp', () {
    final lyrics = SongLyrics.parse(
      synchronized: '<00:02.00>First <00:02.50>second',
    );

    expect(lyrics, isNotNull);
    expect(lyrics!.isSynchronized, isTrue);
    expect(lyrics.lines.single.time, const Duration(seconds: 2));
    expect(lyrics.activeLineAt(const Duration(seconds: 2)), 0);
    expect(lyrics.activeWordAt(0, const Duration(milliseconds: 2600)), 1);
  });

  test('parses plain text lyrics without timestamps', () {
    final lyrics = SongLyrics.parse(plain: 'First line\n\nSecond line');

    expect(lyrics, isNotNull);
    expect(lyrics!.isSynchronized, isFalse);
    expect(lyrics.lines.map((line) => line.text), [
      'First line',
      'Second line',
    ]);
  });

  test('loads matching folder lyrics automatically and caches them', () async {
    SharedPreferences.setMockInitialValues({});
    var reads = 0;
    const channel = MethodChannel('app.tone.tone_player/library');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'readLyrics');
          reads++;
          return '[00:01.00]A line from the song';
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final item = MediaItem(
      id: 'song-1',
      title: 'A song',
      extras: {'lyricsUri': 'content://music/lyrics/song-1.lrc'},
    );

    final lyrics = await LyricsRepository.loadFor(item);
    final cachedLyrics = await LyricsRepository.loadFor(item);

    expect(lyrics?.isSynchronized, isTrue);
    expect(lyrics?.lines.single.text, 'A line from the song');
    expect(cachedLyrics?.lines.single.text, 'A line from the song');
    expect(reads, 1);
  });

  test('clears only Tone cached lyric entries', () async {
    SharedPreferences.setMockInitialValues({
      'tone_lyrics_v1_song-a': '[00:01.00]A line',
      'tone_lyrics_v1_song-b': 'Plain lyrics',
      'unrelated-setting': 'preserve',
    });

    expect(await LyricsRepository.clearCache(), 2);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getKeys(), {'unrelated-setting'});
    expect(preferences.getString('unrelated-setting'), 'preserve');
  });

  test('online lyrics require opt-in and cache synced results', () async {
    SharedPreferences.setMockInitialValues({
      'tone_online_lyrics_enabled': true,
    });
    final item = MediaItem(
      id: 'online-song',
      title: 'A song',
      artist: 'Tone Test',
      album: 'An album',
      duration: const Duration(minutes: 3),
    );
    Uri? requested;
    final lyrics = await LyricsRepository.loadFor(
      item,
      onlineLookup: (uri) async {
        requested = uri;
        return {
          'instrumental': false,
          'syncedLyrics': '[00:01.00]A matched line',
          'plainLyrics': 'A matched line',
        };
      },
    );

    expect(requested?.host, 'lrclib.net');
    expect(requested?.queryParameters, {
      'track_name': 'A song',
      'artist_name': 'Tone Test',
      'album_name': 'An album',
      'duration': '180',
    });
    expect(lyrics?.isSynchronized, isTrue);
    expect(lyrics?.lines.single.text, 'A matched line');

    final cached = await LyricsRepository.loadFor(
      item,
      onlineLookup: (_) async => fail('cached lyrics should not refetch'),
    );
    expect(cached?.lines.single.text, 'A matched line');
  });

  test(
    'searches LRCLIB by exact metadata when its direct match misses',
    () async {
      SharedPreferences.setMockInitialValues({
        'tone_online_lyrics_enabled': true,
      });
      final item = MediaItem(
        id: 'search-song',
        title: 'A song',
        artist: 'Tone Test',
        album: 'An album',
        duration: const Duration(minutes: 3),
      );
      final requests = <Uri>[];

      final lyrics = await LyricsRepository.findOnlineFor(
        item,
        onlineLookup: (uri) async {
          requests.add(uri);
          if (uri.path == '/api/get') return null;
          return [
            {
              'trackName': 'A song',
              'artistName': 'Different artist',
              'albumName': 'An album',
              'duration': 180,
              'syncedLyrics': '[00:01.00]Wrong artist',
            },
            {
              'trackName': 'A song',
              'artistName': 'Tone Test',
              'albumName': 'Other album',
              'duration': 181,
              'syncedLyrics': '[00:01.00]Other version',
            },
            {
              'trackName': 'A song',
              'artistName': 'Tone Test',
              'albumName': 'An album',
              'duration': 185,
              'syncedLyrics': '[00:01.00]Matched search result',
            },
          ];
        },
      );

      expect(requests, hasLength(2));
      expect(requests.first.path, '/api/get');
      expect(requests.last.path, '/api/search');
      expect(requests.last.queryParameters['q'], 'A song Tone Test');
      expect(lyrics?.lines.single.text, 'Matched search result');

      final cachedLyrics = await LyricsRepository.loadFor(item);
      expect(cachedLyrics?.lines.single.text, 'Matched search result');
    },
  );

  test('rejects LRCLIB search results for other tracks or durations', () async {
    SharedPreferences.setMockInitialValues({
      'tone_online_lyrics_enabled': true,
    });
    const item = MediaItem(
      id: 'wrong-search-song',
      title: 'A song',
      artist: 'Tone Test',
      duration: Duration(minutes: 3),
    );

    final lyrics = await LyricsRepository.findOnlineFor(
      item,
      onlineLookup: (uri) async {
        if (uri.path == '/api/get') return null;
        return [
          {
            'trackName': 'A song (Live)',
            'artistName': 'Tone Test',
            'duration': 180,
            'syncedLyrics': '[00:01.00]Different version',
          },
          {
            'trackName': 'A song',
            'artistName': 'Tone Test',
            'duration': 220,
            'syncedLyrics': '[00:01.00]Wrong duration',
          },
        ];
      },
    );

    expect(lyrics, isNull);
  });

  test('does not request online lyrics before explicit opt-in', () async {
    SharedPreferences.setMockInitialValues({});
    var requested = false;
    final item = const MediaItem(
      id: 'private-song',
      title: 'A song',
      artist: 'Tone Test',
    );

    final lyrics = await LyricsRepository.loadFor(
      item,
      onlineLookup: (_) async {
        requested = true;
        return {'syncedLyrics': '[00:01.00]A line'};
      },
    );

    expect(lyrics, isNull);
    expect(requested, isFalse);
    expect(await LyricsRepository.onlineLookupEnabled, isFalse);
  });
}
