# Tone

Tone is a local-first personal music player built with Flutter. Its working
direction is an original, user-centered player with a personal DJ, thoughtful
offline controls, great playback, and clear privacy choices. The product name
and service integrations are not final.

## Status

The first Android playback and library slices are in progress:

- Home, Search, Library, and You navigation, plus a playable, editable
  personal mix built from the local library.
- Import selected audio files into Tone's private app storage; originals are
  left untouched.
- Scan the Android media library in one step and play device originals in
  place; manual file import remains available.
- Browse songs, albums, and artists; search titles, artists, and albums and
  play a result directly.
- Start an on-device artist radio from local tracks; it continues with library
  tracks sharing embedded genre or compatible tagged tempo.
- Get local playlist suggestions from actual genre tags and saved favorites;
  preview them or save them into the user's playlists.
- Save songs to a persistent Favorites collection from the library or player.
- Create and manage playlists, add or remove songs, reorder tracks, and play a
  playlist.
- Generate mixes by target duration and favorite-versus-discovery preference;
  prefer compatible embedded genre/BPM tags, explain picks, and allow favorite
  feedback, session removal, and persistent exclusions.
- Read Android's album, duration, track, year, indexed genre, and album-art
  metadata; read explicit ID3 BPM tags from imported audio when present.
- Enrich SAF folder tracks from embedded tags and artwork, automatically match
  same-name `.lrc`/`.txt` lyrics, and cache lyrics locally for Now Playing.
- Search Jamendo through its official API and import MP3 VBR or available FLAC
  downloads only when the API says the artist allows downloads. Transfers show
  progress and can be cancelled; imported tracks retain their Jamendo source
  and license metadata.
- Read tags and embedded cover art when importing audio; artwork loading also
  falls back to the playing file and standard folder covers when album art is
  not indexed separately.
- Show a personalized Home greeting, continue-listening card, recent library
  picks, a selectable local mood-mix carousel, an artwork-led listening hero,
  local discovery, a floating
  mini-player/navigation dock, and a light ink-and-paper Now Playing screen
  with centered artwork, a waveform seek control, and compact transport actions.
- Keep Tone's red accent in its broader visual system, with a charcoal
  mini-player and artwork-first album/artist grids. Album groups open a
  dedicated detail view with ordered tracks and working play/shuffle actions.
  The Now Playing seek control renders a cached, decoded audio-amplitude
  waveform on Android; approximate four-beat guides appear only when a track
  has a tagged BPM. If analysis fails, the normal seek slider remains usable
  and offers a retry.
- Rotate the Home library shelf deterministically each day using local album
  order; this is a fresh presentation, not a listening-history recommendation.
- Explain local data storage and let users clear cached lyrics, favorites, and
  personal-mix exclusions without deleting songs or playlists.
- Play songs in an audio-service-backed queue with a mini-player,
  Now Playing controls, Android media notification/lock-screen integration,
  queue/current-track/position restoration, smooth live progress, and a short
  dual-deck overlap at track boundaries. The Personal DJ can disable mixing,
  use a smooth equal-power blend, or pitch-correct small BPM adjustments when
  both songs have compatible embedded BPM tags.

Device-wide scanning uses Android's indexed audio library and requests audio
permission. Android users can also grant Tone persistent access to selected
music folders; folder tracks remain in place and the grant can be removed from
the library. That folder scan recursively matches same-name `.lrc`/`.txt`
sidecars with audio; synchronized `.lrc` lines follow playback in Now Playing
and the full lyrics sheet. Enhanced LRC word timestamps also highlight each
word; ordinary line-timed LRC and plain lyrics remain line-level. Android's
device-wide media index does not grant access to neighboring text files, so
automatic sidecar discovery requires a user-granted folder. Optional LRCLIB
lookup is off until the listener explicitly enables it. Tone tries an exact
metadata match first, then searches by title and artist and accepts only
matching track/artist results (and rejects durations more than 12 seconds
apart when both are known). It sends only the current title, artist, album,
and duration for matching and caches successful results on-device. Jamendo
search is separately user-initiated and sends the query plus a public client
ID configured by the listener; audio is requested only after tapping Download.

Artist radio and playlist sparks are local-library features, not internet
streaming: Tone builds stations and suggestions from available artist, genre,
BPM, and favorite tags. BPM is read only from embedded tags; Tone does not
invent tempo estimates. Beat matching currently requires BPM tags within six
percent and otherwise safely falls back to a smooth overlap; harmonic-key
matching, phrase analysis, echo-out, and energy-aware transitions are not
implemented. Mood-mix cards are explicit choices matched only against available
genre/BPM tags; they do not detect emotion or learn from listening history.
Automatic offline prediction, subscription-service downloads, and connected
network libraries are not implemented. Jamendo downloads are limited to
tracks whose official API response explicitly allows downloads; they are
stored in Tone's private library. Local music remains available offline when
its source file is on the device. Android scan/folder/playback permission
flow, device-wide scanning, codec inspection, and a live two-track DJ handoff
were verified on Android 17 / CPH2649. Queue restoration and playback
interruption handling still need real-device verification. The app name Tone
is provisional.

See [PROJECT_PLAN.md](./PROJECT_PLAN.md) for functional requirements,
architecture, stages, testing gates, and implementation tracking.

## Development

Requirements: Flutter stable and Dart versions specified by `pubspec.yaml`.

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter run -d <device-id>
```

The first delivery target is Android. iOS scaffolding is included to keep
platform-specific behavior behind interfaces as the app grows.
