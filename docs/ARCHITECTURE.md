# Tone Architecture

**Status:** Incremental architecture; the existing feature-first Flutter
structure is retained.  
**Platform focus:** Android first.  
**Product requirements:** [PRD.md](PRD.md).  
**Implementation sequencing:** [PROJECT_PLAN.md](../PROJECT_PLAN.md).

## 1. Current structure

```text
lib/
  app/                 Application composition, services, theme, appearance
  features/
    home/              Home presentation and local entry points
    search/            Local search and authorized discovery entry point
    library/           Library models, operations, browse UI
    mix/               Local mix generation and discovery logic
    auto_mix/          Transition policy, settings, analysis model, engine contract
    player/            Audio handler, player UI, lyrics, audio settings
    downloads/         Jamendo search and licensed import flow
    settings/          Playback, privacy, appearance, and app settings
    shell/             Top-level navigation and feature composition
  main.dart            Flutter entry point
```

The layout remains feature-first. Cross-feature primitives should be extracted
when at least two features need a stable shared contract; do not create empty
layers solely to match a proposed directory tree.

## 2. Runtime composition and dependency direction

```text
main
  └── ToneApp
       └── ToneServices.initialize()
            ├── AudioSession configuration
            ├── AudioService → ToneAudioHandler
            ├── MethodChannelLibraryPlatformDataSource → MusicLibrary
            ├── AudioServiceAudioProfileService → AudioHandler
            └── DriftLibraryRepository → ToneDatabase
       └── queue restoration / playback persistence subscriptions
       └── AppShell
            ├── screens receive feature dependencies
            └── AudioHandler for standard transport/queue streams
```

Rules:

1. `main.dart` starts the app; it does not own feature behavior.
2. `ToneServices` is the production composition root and owns application
   service instances and lifecycle subscriptions.
3. Screens may depend on feature-facing service interfaces and view data. They
   must not depend on audio-engine implementation classes.
4. `AudioHandler` remains the standard media transport/session boundary.
5. Pure policy (personal mix generation) stays independent of Flutter UI and
   platform channels.
6. Android channel details belong behind a platform data-source boundary.
   `MusicLibrary` still owns some Android `MethodChannel` and file-picker
   calls; this is a known follow-up, not a completed separation.
7. AutoMix policy stays independent of player widgets and the queue. The
   current `just_audio` dual-deck prototype is owned by `ToneAudioHandler`;
   it is not sample-accurate and does not replace the handler's queue owner.

## 3. Audio profile service

`features/player/audio_profile_service.dart` defines the typed audio-profile
service and its `AudioHandler` adapter. Audio settings use this boundary for
persisted equalizer profiles and capability reporting. Unsupported processing
capabilities remain explicitly unavailable.

## 4. Data and persistence

Library persistence now follows a repository/database boundary:

- `MusicLibrary` consumes `LibraryRepository`; production uses
  `DriftLibraryRepository` and a versioned SQLite database. Unit/widget
  construction can retain the legacy preferences implementation while tests
  migrate.
- The v2 schema stores tracks, normalized artists/albums, folders, playlists
  and ordered membership, favorites, exclusions, queue/state, and playback
  history. It also defines analysis, artwork-cache metadata, download,
  user-preference, and audio-profile tables. The current sound profile remains
  in `SharedPreferences`; the Drift audio-profile table is not yet connected
  to playback settings. Legacy analysis/session schema is retained for
  migration compatibility but is not used by playback.
- Track search uses a trigger-maintained FTS5 index. Track IDs and source URIs
  remain stable; rescans update known records and mark missing device tracks
  unavailable instead of silently dropping them.
- First launch imports legacy library preferences transactionally. The
  migration marker is written only after validation; old preference values
  are retained.
- SQLite runs with foreign keys and WAL enabled. Integrity is checked on
  startup; a failed quick check quarantines the database before a fresh
  database is initialized, preserving the original file for recovery.
- Device scans use modified-since queries between periodic full
  reconciliations. Missing device tracks remain indexed as unavailable.
- Artwork is cached in a bounded persistent file cache on Android. Likely
  duplicates are grouped for review; the app never deletes a source
  automatically.
- Lyrics/appearance preferences and the current sound profile use local
  preferences.
- `AudioProfileService` exposes a validated persisted `AudioProfile` and
  route capability contract. Android equalizer support is optional; unsupported
  routing, balance, and headphone profiles are not represented as working
  controls. See
  [ADR 0007](decisions/0007-audio-profile-and-safe-gain.md).
- Imported audio is kept in app-private storage; device and SAF content
  remains represented by source URIs/grants.
- Personal mix generation uses local library metadata and creates an ordinary
  queue. It does not analyze audio or control track transitions.

The database has a schema version and migration strategy; future schema
changes must add explicit forward migrations and upgrade tests. Library UI
still holds loaded track models in memory. Automated v1-to-v2 upgrade and
corruption-recovery tests, scan progress/cancellation, revoked-grant recovery,
and large-library/device lifecycle checks remain follow-ups.

## 5. Error handling and diagnostics

- Expected user-correctable states (permission denied, unavailable source,
  empty library, unsupported platform capability) should be typed or surfaced
  with an actionable UI state.
- Unexpected asynchronous failures should be reported with context using
  `FlutterError.reportError` or the project’s future diagnostics boundary.
- Do not silently convert storage, platform, or engine failures into
  success-shaped values.
- Optional data may be absent when absence is part of the contract (for
  example, no current track); malformed data is an error.
- Avoid polling-based diagnostics that report the same persistent error every
  frame. Throttle repeated reports while retaining a recovery path.
- Never log credentials, private file contents, or unnecessary personal
  metadata.

There is no centralized structured logger or app-wide error model yet. Add one
only with a clear redaction policy, severity/context contract, and test seam.

## 6. Android platform boundary

`MainActivity.kt` currently serves one method channel for folder selection,
MediaStore scans, metadata, lyrics, artwork, codec details, and waveform
decoding. Library scan, SAF folder, and imported-metadata operations now use
`LibraryPlatformDataSource`; production creates
`MethodChannelLibraryPlatformDataSource` at app composition. `ToneAudioHandler`,
`LyricsRepository`, and player artwork/waveform helpers still invoke the
shared channel directly in their respective features.

Next boundary: define narrow feature-owned interfaces for lyrics file access,
artwork, and waveform analysis, and inject them at app composition. Preserve
current channel method names and payloads during extraction; add channel
contract tests before changing the Kotlin implementation. Avoid one generic
“native platform” god-service.

## 7. Refactoring sequence and quality gates

1. **Library platform boundary (implemented):** typed library platform
   interface, Android MethodChannel adapter, injected production source, and
   folder operation contract tests.
2. **Library persistence boundary (implemented, v1):** Drift schema,
   transactional repository, FTS search, legacy preference migration,
   playback history, and regression tests.
3. **Library data workflows:** incremental MediaStore scans, duplicate
   resolution, artwork cache lifecycle, richer history, and safe recovery.
4. **Android capabilities:** extract remaining channel calls behind narrow interfaces
   with fake implementations and method-channel contract tests.
5. **Playback decomposition:** split engine policy/state from audio-service
   adapter only when state ownership and lifecycle are testable; retain the
   current audio library unless measured evidence requires replacement.
6. **UI decomposition:** extract focused widgets from large screen files in
   behavior-preserving slices, adding widget coverage for each extracted
   component.

## 8. AutoMix boundary

`features/auto_mix/` contains validated settings and track-evidence models, a
pure-Dart transition planner, a controller, an `AudioEngine` contract, and a
two-player `just_audio` prototype. `ToneAudioHandler` owns both players and
remains the only queue owner; Deck A drives normal transport and media-session
state, while Deck B can preload and play independently through explicit audio
service actions. Queue replacement, advancement, and edits clear stale Deck B
content. Both players share Tone's configured audio session, with session
activation and interruptions controlled by the handler.

The prototype has independent positions and a controller-driven gain ramp.
`autoMix.transitionToNextTrack` starts an explicit transition to the next queue
item, applies the profile's gain curve through per-player `setVolume` calls,
then promotes the incoming player and updates queue ownership. Commands are
issued at a nominal 20 ms cadence, but platform-channel/player latency can
make them uneven; the backend is not proven sufficiently smooth for a
production crossfade and is not sample-accurate. When Deck A is playing and a
next queue item exists, the handler preloads Deck B and automatically starts
the profile-duration crossfade near the end of Deck A; the existing
end-of-track queue advance remains the fallback if preload or transition
fails. This is duration-based, not scheduled from waveform cues. Now Playing
also has a manual “Mix next” action; its activity animation and progress bar
reflect gain-ramp command state and step completion, not rendered audio output
or an analyzed mix point. The displayed duration is the ramp target, not a
measured acoustic duration. On Android, Now Playing also
decodes the current and actual next queue item concurrently into normalized
PCM peak waveforms and marks sustained quiet lead-in/tail estimates. These are
relative-energy cues only: they do not detect beats, phrases, or guaranteed
musical intro/outro points, and the manual transition still starts
immediately. A separate debug-only diagnostic screen is available with the
`TONE_AUTOMIX_DIAGNOSTICS` compile-time define for Milestone C.1 device tests.
The Android launcher uses a native adaptive Tone waveform icon; no runtime
dependency is needed for it.

On Android, each physical player has a separate equalizer effect instance so
promoting the incoming player does not drop the equalizer pipeline. A
cancelled transition restores the prior gains and playback state.

The planner only assesses BPM values and confidence supplied by its caller;
it does not analyze audio or infer beat grids, key, or phrase boundaries. A
physical-device smoke test confirmed concurrent WAV playback on an OPPO
CPH2649 running Android 17, but did not measure audible fade quality.
The subsequent 2-second equal-power device ramp emitted 101 gain-state updates
per deck, with 22 ms median spacing and 30–31 ms maximum observed spacing;
the operation took 2251 ms. These Dart-side timings do not measure rendered
volume or prove perceptual smoothness.
Validation remains required for other codecs and URI types, background and
screen-locked playback, interruptions, Bluetooth/routes, repeated transitions,
CPU, memory, and long-duration stability.

The Drift schema already contains a `TrackAnalysis` table but it is not wired
to a real analyzer or playback. Do not add a competing analysis store without
first checking that schema and its migrations. See
[AUTOMIX_IMPLEMENTATION_PLAN.md](AUTOMIX_IMPLEMENTATION_PLAN.md) for staged
engine qualification, persistence, integration, and test gates.

For each step run targeted tests, `flutter analyze`, and the Android debug
build when native wiring or application composition changes. Verify physical
device behavior separately; a successful build does not prove lifecycle,
audio quality, or performance.
