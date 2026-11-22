import 'package:flutter_test/flutter_test.dart';
import 'package:melo_player/features/library/imported_track.dart';
import 'package:melo_player/features/library/music_playlist_import.dart';

void main() {
  const first = ImportedTrack(
    id: 'one',
    path: '/music/Artist/First Song.mp3',
    title: 'First Song',
    artist: 'Artist',
  );
  const second = ImportedTrack(
    id: 'two',
    path: '/music/Artist/Second Song.flac',
    title: 'Second Song',
    artist: 'Artist',
  );

  test('parses ordered M3U entries and ignores metadata and blank lines', () {
    expect(
      MusicPlaylistImport.parseM3u(
        '\uFEFF#EXTM3U\r\n#EXTINF:123,Artist - First Song\r\n'
        'Artist/First Song.mp3\r\n\r\nSecond Song.flac',
      ),
      ['Artist/First Song.mp3', 'Second Song.flac'],
    );
  });

  test('retains M3U title, artist, and duration for metadata matching', () {
    final entries = MusicPlaylistImport.parseM3uEntries(
      '#EXTM3U\n#EXTINF:214,Artist - Song Title\nwrong-name.mp3\n'
      '#EXTINF:-1,Another Song\nanother.mp3',
    );
    expect(
      entries
          .map(
            (entry) =>
                (entry.path, entry.title, entry.artist, entry.durationSeconds),
          )
          .toList(),
      [
        ('wrong-name.mp3', 'Song Title', 'Artist', 214),
        ('another.mp3', 'Another Song', null, null),
      ],
    );
  });

  test('resolves paths and unique filenames in playlist order', () {
    expect(
      MusicPlaylistImport.resolveEntries(
        ['Artist/Second Song.flac', 'First Song.mp3', 'missing.mp3'],
        [first, second],
      ).map((track) => track.id),
      ['two', 'one'],
    );
  });

  test('does not guess between tracks with the same filename', () {
    const anotherCopy = ImportedTrack(
      id: 'another',
      path: '/other/Artist/First Song.mp3',
      title: 'First Song',
      artist: 'Artist',
    );
    expect(
      MusicPlaylistImport.resolveEntries(
        ['First Song.mp3'],
        [first, anotherCopy],
      ),
      isEmpty,
    );
  });

  test('skips unavailable and repeated playlist entries', () {
    const unavailable = ImportedTrack(
      id: 'gone',
      path: '/music/gone.mp3',
      title: 'Gone',
      isAvailable: false,
    );
    expect(
      MusicPlaylistImport.resolveEntries(
        ['First Song.mp3', 'First Song.mp3', 'gone.mp3'],
        [first, unavailable],
      ).map((track) => track.id),
      ['one'],
    );
  });

  test('matches literal and encoded percent signs in playlist paths', () {
    const percentTrack = ImportedTrack(
      id: 'percent',
      path: '/music/100% Mix.mp3',
      title: '100% Mix',
    );

    expect(
      MusicPlaylistImport.resolveEntries(
        ['100% Mix.mp3', '100%25%20Mix.mp3'],
        [percentTrack],
      ).map((track) => track.id),
      ['percent'],
    );
  });

  test('matches Mornye paths to Android content URIs by saved filename', () {
    const deviceTrack = ImportedTrack(
      id: 'media-42',
      path: 'content://media/external/audio/media/42',
      sourceName: 'Mornye_Track_01.flac',
      title: 'The Actual Song Title',
      artist: 'Artist',
      isDeviceMedia: true,
    );

    expect(
      MusicPlaylistImport.resolveEntries(
        ['/storage/emulated/0/Mornye/Mornye_Track_01.flac'],
        [deviceTrack],
      ).map((track) => track.id),
      ['media-42'],
    );
  });

  test('matches a playlist title and artist when filenames differ', () {
    const deviceTrack = ImportedTrack(
      id: 'media-43',
      path: 'content://media/external/audio/media/43',
      sourceName: 'download-2026-01.flac',
      title: 'Song Title',
      artist: 'Artist',
      isDeviceMedia: true,
      durationMs: 214000,
    );

    expect(
      MusicPlaylistImport.resolvePlaylistEntries(
        const [
          MusicPlaylistEntry(
            path: 'renamed-file.mp3',
            title: 'Song Title',
            artist: 'Artist',
            durationSeconds: 214,
          ),
        ],
        [deviceTrack],
      ).map((track) => track.id),
      ['media-43'],
    );
  });

  test('does not treat a remote stream URL as a local filename match', () {
    const deviceTrack = ImportedTrack(
      id: 'media-44',
      path: 'content://media/external/audio/media/44',
      sourceName: 'song.mp3',
      title: 'Song',
      artist: 'Artist',
      isDeviceMedia: true,
    );

    expect(
      MusicPlaylistImport.resolveEntries(
        ['https://example.invalid/audio/song.mp3'],
        [deviceTrack],
      ),
      isEmpty,
    );
    expect(
      MusicPlaylistImport.resolvePlaylistEntries(
        const [
          MusicPlaylistEntry(
            path: 'https://example.invalid/audio/song.mp3',
            title: 'Song',
            artist: 'Artist',
          ),
        ],
        [deviceTrack],
      ).map((track) => track.id),
      ['media-44'],
    );
  });

  test('decodes file URIs once and tolerates malformed percent escapes', () {
    const percentTrack = ImportedTrack(
      id: 'percent',
      path: '/music/100% Mix.mp3',
      title: '100% Mix',
    );

    expect(
      MusicPlaylistImport.resolveEntries(
        ['file:///music/100%25%20Mix.mp3', '100%ZZ Mix.mp3'],
        [percentTrack],
      ).map((track) => track.id),
      ['percent'],
    );
  });

  test('resolves relative M3U paths using baseDir', () {
    const relativeTrack = ImportedTrack(
      id: 'rel-1',
      path: '/storage/emulated/0/Music/Rock/Numb.mp3',
      title: 'Numb',
      artist: 'Linkin Park',
    );

    expect(
      MusicPlaylistImport.resolvePlaylistEntries(
        const [
          MusicPlaylistEntry(
            path: '../Rock/Numb.mp3',
            title: 'Numb',
            artist: 'Linkin Park',
          ),
        ],
        [relativeTrack],
        baseDir: '/storage/emulated/0/Music/Playlists',
      ).map((track) => track.id),
      ['rel-1'],
    );
  });

  test('matches featured artists and simplified titles with duration tolerance', () {
    const track = ImportedTrack(
      id: 'feat-1',
      path: '/storage/emulated/0/Music/Pop/Blinding Lights.mp3',
      title: 'Blinding Lights',
      artist: 'The Weeknd',
      durationMs: 200000,
    );

    expect(
      MusicPlaylistImport.resolvePlaylistEntries(
        const [
          MusicPlaylistEntry(
            path: 'custom_file.mp3',
            title: 'Blinding Lights (feat. Rosalía) [Official Audio]',
            artist: 'The Weeknd feat. Rosalía',
            durationSeconds: 205, // 5s difference tolerated
          ),
        ],
        [track],
      ).map((t) => t.id),
      ['feat-1'],
    );
  });

  test('selects best candidate when multiple copies exist', () {
    const genericCopy = ImportedTrack(
      id: 'copy-1',
      path: '/storage/emulated/0/Download/Song.mp3',
      title: 'Song',
      artist: 'Unknown artist',
    );
    const perfectCopy = ImportedTrack(
      id: 'copy-2',
      path: '/storage/emulated/0/Music/Artist/Song.mp3',
      title: 'Song',
      artist: 'Real Artist',
      durationMs: 180000,
    );

    expect(
      MusicPlaylistImport.resolvePlaylistEntries(
        const [
          MusicPlaylistEntry(
            path: 'Artist/Song.mp3',
            title: 'Song',
            artist: 'Real Artist',
            durationSeconds: 180,
          ),
        ],
        [genericCopy, perfectCopy],
      ).map((t) => t.id),
      ['copy-2'],
    );
  });

  test('matches filenames with track numbers prefix (e.g. "01 - " or "02. ")', () {
    const track = ImportedTrack(
      id: 'track-num-1',
      path: '/storage/emulated/0/Music/Album/Song Name.mp3',
      title: 'Song Name',
      artist: 'Artist',
    );

    expect(
      MusicPlaylistImport.resolvePlaylistEntries(
        const [
          MusicPlaylistEntry(
            path: '01 - Song Name.mp3',
          ),
        ],
        [track],
      ).map((t) => t.id),
      ['track-num-1'],
    );

    expect(
      MusicPlaylistImport.resolvePlaylistEntries(
        const [
          MusicPlaylistEntry(
            path: '02. Song Name.mp3',
          ),
        ],
        [track],
      ).map((t) => t.id),
      ['track-num-1'],
    );
  });

  test('matches case-insensitively across path suffixes and filenames', () {
    const track = ImportedTrack(
      id: 'case-1',
      path: '/storage/emulated/0/Download/Afrobeats/Burnaboy.MP3',
      title: 'City Boys',
      artist: 'Burna Boy',
    );

    expect(
      MusicPlaylistImport.resolvePlaylistEntries(
        const [
          MusicPlaylistEntry(
            path: 'download/afrobeats/burnaboy.mp3',
          ),
        ],
        [track],
      ).map((t) => t.id),
      ['case-1'],
    );
  });

  test('extracts artist and title from filename when EXTINF is missing', () {
    const track = ImportedTrack(
      id: 'extinf-missing-1',
      path: '/storage/emulated/0/Music/Asake/Asake - Lonely At The Top.mp3',
      title: 'Lonely At The Top',
      artist: 'Asake',
    );

    expect(
      MusicPlaylistImport.resolvePlaylistEntries(
        const [
          MusicPlaylistEntry(
            path: 'Music/Asake - Lonely At The Top.mp3',
          ),
        ],
        [track],
      ).map((t) => t.id),
      ['extinf-missing-1'],
    );
  });

  test('preserves remote HTTP stream entries as ImportedTracks when requested', () {
    final resolved = MusicPlaylistImport.resolvePlaylistEntries(
      const [
        MusicPlaylistEntry(
          path: 'https://example.com/audio/live_stream.mp3',
          title: 'Live Stream Song',
          artist: 'Web Artist',
        ),
      ],
      [],
      preserveRemoteStreams: true,
    );

    expect(resolved.length, 1);
    expect(resolved.first.path, 'https://example.com/audio/live_stream.mp3');
    expect(resolved.first.title, 'Live Stream Song');
    expect(resolved.first.artist, 'Web Artist');
  });
}
