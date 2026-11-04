# Personal Music Player — Product and Implementation Plan

> Living blueprint for a modern, user-centered Flutter music app. This is a
> starting point, not a locked specification. Product name, visual identity,
> and any service integrations remain open decisions.

## 1. Product direction

### Product promise

**A music player that feels like it knows the listening moment, while keeping
the listener in control.**

The app combines the care and polish of mainstream music apps with the
ownership, flexibility, and playback depth of Mornye. Its signature is a
personal DJ that makes useful, explainable mixes from music the user is
actually authorized to play.

### Principles

1. **User intent before feed engagement.** Help people choose what to hear;
   do not optimize for endless scrolling.
2. **One library, honest sources.** Bring sources together where possible,
   while clearly showing where a recording comes from and what can be done
   with it.
3. **Control is always visible.** Explain recommendations, make feedback
   immediate, and provide pause, reset, export, and privacy controls.
4. **Great playback is foundational.** The app must remain useful offline and
   responsive even when discovery services are unavailable.
5. **Warm, polished, accessible design.** A distinctive visual system should
   feel personal without sacrificing readability, consistency, or platform
   conventions.
6. **Build trust into the product.** Never imply that a service integration,
   download, offline mode, or playback route exists when it does not.

### Product boundaries

- Android is the first target; keep platform-specific details behind
  interfaces so iOS can follow without forcing premature cross-platform
  compromises.
- Local files and user-controlled libraries are the dependable first source.
- NAS/personal cloud, podcasts/radio, official video, and commercial streaming
  are separate source types, not interchangeable promises.
- Integrate commercial services only through documented, authorized APIs and
  permitted playback flows. Where direct playback is unavailable, clearly
  offer an external handoff.
- Do not build around stream extraction, DRM circumvention, or scraping
  private service endpoints.
- No account or cloud profile is required for the initial local-player
  experience.

## 2. Experience and information architecture

### Primary navigation

Use four destinations and a persistent mini-player:

1. **Home** — resume listening, start a listening session, and see a small
   number of relevant picks.
2. **Search** — search the user's library and enabled, authorized sources;
   results identify their source.
3. **Library** — songs, albums, artists, playlists, downloads, and connected
   sources.
4. **You** — listening preferences, history/recap, audio settings, privacy,
   and app settings.

The **Now Playing** screen opens from the mini-player and is not a permanent
navigation destination. Use adaptive navigation rails or wider layouts on
larger devices without changing the information architecture.

### Key screens

#### Home

- Greeting and a clear “Continue listening” item.
- One prominent **Make me a mix** action.
- A compact “For this moment” mix card with editable intent and duration.
- Offer explicit local mood mixes only when available library genre/BPM tags
  support them; do not infer emotion from the audio or listening history.
- A few useful rows such as recent albums, unfinished podcasts, and new items
  in the user's own library.
- Hide, reorder, and disable home sections. No mandatory recommendation feed.

#### Mix setup

Keep the first interaction approachable: a prompt such as “What are you in the
mood for?” plus optional controls:

- Mood/energy
- Familiarity versus discovery
- Vocals versus instrumental
- Session length
- Include/exclude selected sources, artists, tracks, or explicit content

Show a preview and let the listener adjust before starting. Avoid asking for
many preference settings before the first successful play.

#### Now Playing

- Keep the playback hierarchy calm and direct: centered artwork, readable
  title/artist, a seekable waveform, and a compact transport row.
- Play/pause, previous/next, seek, shuffle/repeat, queue, and output controls.
- Surface lyrics, queue, track details, artist radio, and DJ mode through
  concise actions without crowding the core playback controls.
- Gesture shortcuts and beat-aware haptics are discoverable, configurable,
  and never the only way to operate the player.
- Queue entries show their source and whether they are available offline.
- Contextual actions include “More like this,” “Less like this,” “Not now,”
  “Never play,” and “Why this pick?”
- Smooth transitions and optional crossfade are user-controlled, previewable,
  and never surprising.

#### Library and source management

- Start with a clear choice: add device music or connect a source.
- Distinguish files on-device, remote items, cached/offline items, and external
  service links.
- Treat alternate edits, live performances, remasters, and official videos as
  related versions when reliable metadata supports it; do not silently merge
  distinct recordings.
- Provide understandable scan progress, permission recovery, duplicate
  review, and source availability indicators.

### Visual design direction

- Create an original brand rather than reproducing Mornye or another service's
  layout or artwork.
- Use a distinctive red accent system, pairing calm ink-and-paper playback
  surfaces with a charcoal mini-player and restrained motion.
- Keep Now Playing focused on artwork, track identity, decoded waveform
  progress, and reachable playback actions. On Android, BPM-tag beat guides
  remain approximate and must not be presented as detected beats.
- Make albums and artists scannable as an artwork-first library grid; album
  selections open a compact detail view with ordered tracks and direct
  playback actions.
- Define design tokens for color, typography, spacing, shape, elevation, and
  motion before building screen-specific styling.
- Support light/dark themes, dynamic type, contrast, screen readers, reduced
  motion, touch targets, and landscape/tablet layouts.
- Prefer clear hierarchy and comfortable spacing over dense rows of
  recommendation carousels.

## 3. Functional requirements

Priority key: **MVP** is required for the first useful release; **Next** is
planned after the core is stable; **Later** is an intentional extension.

### Playback and queue

- **FR-PLAY-01 (MVP):** Play, pause, seek, previous/next, shuffle, repeat, and
  queue local audio files.
- **FR-PLAY-02 (MVP):** Continue playback in the background and expose Android
  media notification, lock-screen controls, headset controls, and media
  metadata.
- **FR-PLAY-03 (MVP):** Persist queue and playback position safely across
  normal app restarts.
- **FR-PLAY-04 (MVP):** Handle audio focus, calls, route changes, Bluetooth,
  headphone removal, and interruptions without duplicate or stuck playback.
- **FR-PLAY-05 (MVP):** Show meaningful loading, unavailable-file, and
  recoverable-error states.
- **FR-PLAY-06 (Next):** Configurable gentle fade, beat-matched, and echo-out
  mix styles, plus sleep timer and improved output routing. Each style must
  have a safe fallback when analysis is unavailable. The current Android slice
  has user-selectable off, smooth dual-deck blend, and BPM-tagged tempo
  matching; echo-out, sleep timer, and output routing remain open.
- **FR-PLAY-07 (Later):** High-resolution or exclusive output only after a
  platform capability spike and device testing.
- **FR-PLAY-08 (Next):** Keep transitions musically coherent using beat grid,
  harmonic-key compatibility, phrase boundaries, and a session energy curve.
  Treat key/tempo estimates as uncertain; users can disable analysis or
  choose a simple fade. Current BPM matching only uses compatible embedded
  tags and otherwise falls back to a smooth blend; key and phrase analysis
  remain unimplemented.
- **FR-PLAY-09 (Next):** Optional beat-synced haptics and gesture controls
  provide equivalent accessible buttons and can be disabled independently.

### Smart offline

- **FR-OFFLINE-01 (MVP):** Provide a persistent “Never use mobile data”
  setting enforced by the download/cache layer, not just a screen preference.
  Offline preparation must pause or fail closed when Wi-Fi-only is enabled
  and the connection is metered, unknown, or changes during transfer.
- **FR-OFFLINE-02 (Next):** On-device prediction may prepare likely listening
  choices overnight, only after explicit opt-in, on unmetered Wi-Fi, while
  charging or above a user-configurable battery threshold, and within a user
  storage budget.
- **FR-OFFLINE-03 (Next):** Show what is queued for offline use, why it was
  selected, transfer state, and a one-tap pause/cancel action. Respect source
  download rights, provider restrictions, and cache expiration.
- **FR-OFFLINE-04 (Next):** Automatic eviction uses a transparent
  least-recently-used policy among app-managed cache items, with pinned items
  protected. Never remove user-owned files or explicit downloads; warn and
  provide recovery if the app-managed cache cannot meet the budget.
- **FR-OFFLINE-05 (Next):** Make storage usage, reserve space, maximum cache
  size, Wi-Fi-only status, battery conditions, and last successful refresh
  visible and understandable.

### Mixing and sound personalization

- **FR-MIX-01 (Next):** Improve transitions with beat alignment, compatible
  harmonic key, phrase-aware cue points, and an energy curve that can settle,
  build, or wind down over the session.
- **FR-MIX-02 (Next):** Offer gentle fade, beat-matched, and echo-out styles.
  Explain when analysis is unavailable and fall back without interrupting
  playback.
- **FR-SOUND-01 (Next):** Offer optional headphone-model Auto-EQ using
  profiles from a verified, appropriately licensed AutoEQ data source. Match
  device models conservatively, show the selected profile, and let users
  preview, adjust, disable, or choose another profile.
- **FR-SOUND-02 (Next):** Provide loudness normalization and a configurable
  hearing-comfort limiter with clear, non-medical language. Avoid sudden gain
  changes; disclose when the device/output path prevents processing.
- **FR-SOUND-03 (Later):** Optional spatial/room effects are off by default,
  output-aware, and must not silently stack with conflicting system effects.
- **FR-SOUND-04 (Gate):** Validate processing latency, clipping, loudness,
  output-route behavior, battery cost, and bypass behavior on physical
  devices. Sound effects must never alter source files.

### Social and recaps

- **FR-SOCIAL-01 (Next):** Offline Jam uses QR or local-network discovery to
  join a shared queue. The session host controls queue policy and participants
  can request/add tracks according to host settings.
- **FR-SOCIAL-02 (Gate):** Jam syncs queue/transport metadata only by default;
  it does not redistribute audio. Each participant must have an available,
  authorized source for a requested track, or the UI clearly marks it
  unavailable. QR codes carry short-lived session credentials only—never
  account credentials or long-lived personal identifiers.
- **FR-SOCIAL-03 (Later):** Friend Blend requires mutual, revocable consent
  before sharing any listening signals; provide preview, scope, expiration,
  and deletion controls.
- **FR-SOCIAL-04 (Later):** Shareable moment cards may include track metadata,
  artwork, or lyrics only where applicable rights and provider terms allow.
  A 15-second audio preview is available only when the user has rights to
  share that excerpt or a provider explicitly authorizes it; merely owning a
  music file does not grant redistribution rights. Never extract it from a
  protected stream.
- **FR-SOCIAL-05 (Next):** Monthly/yearly recaps are generated from local
  history, explain their time range, and are exportable or deletable by the
  user. Sharing is opt-in and previews the exact exported content.

### Library and metadata

- **FR-LIB-01 (MVP):** Add/remove user-selected folders using Android's
  supported file access model; scan, index, search, and browse tracks, albums,
  and artists.
- **FR-LIB-02 (MVP):** Favorites and user-created/editable playlists.
- **FR-LIB-03 (MVP):** Preserve user data when scans fail or a source is
  temporarily unavailable; explain permission recovery.
- **FR-LIB-04 (MVP):** Deduplicate cautiously using stable identifiers and
  normalized metadata, with user review for ambiguous matches.
- **FR-LIB-05 (Next):** Import/export playlists and backup/restore user data.
- **FR-LIB-06 (Next):** NAS/personal cloud browsing and playback through
  supported protocols with credentials stored securely.
- **FR-LIB-07 (Later):** Rich recording/version relationships and optional
  metadata enrichment.

### Personal DJ and discovery

- **FR-DJ-01 (MVP):** Generate a useful session from locally available,
  playable tracks with a duration and a small set of explicit intent controls.
- **FR-DJ-02 (MVP):** Let the user accept, skip, remove, or replace a proposed
  track before/during a session.
- **FR-DJ-03 (MVP):** Explain each pick in plain language and provide
  immediate positive/negative feedback.
- **FR-DJ-04 (MVP):** Exclude blocked tracks/artists and respect explicit
  content preferences.
- **FR-DJ-05 (MVP):** Work with a cold-start profile; never require a long
  listening history to produce a mix.
- **FR-DJ-06 (Next):** Learn from skips, saves, replay, and explicit feedback,
  with a visible pause/reset control and documented local data behavior.
- **FR-DJ-07 (Next):** Session “arc” controls (settle in, build, wind down)
  and mix continuation.
- **FR-DJ-08 (Later):** Multi-source recommendations, subject to source
  availability and authorized API access.

### Lyrics, spoken audio, video, and integrations

- **FR-MEDIA-01 (MVP):** Read embedded metadata and lyrics where present;
  present lyrics with a clear unavailable state if not present.
- **FR-MEDIA-02 (Next):** Add an authorized lyrics provider only after terms,
  attribution, caching, and privacy behavior are reviewed.
- **FR-SPOKEN-01 (Next):** Podcasts/radio use suitable playback controls,
  resume position, and queue behavior distinct from music.
- **FR-VIDEO-01 (Later):** Play or hand off official video only through a
  permitted integration; clearly distinguish video from audio-only playback.
- **FR-SOURCE-01 (Next/Later):** Every connector declares supported
  capabilities (search, play, offline, lyrics, library, handoff); unsupported
  actions are not shown as if functional.
- **FR-SOURCE-02 (Gate):** Before implementation, verify each external
  provider's current API access, commercial terms, platform policy, and
  playback restrictions.

**Implemented source slice:** Jamendo search and private MP3 VBR/FLAC imports
use the official API's `audiodownload_allowed` field and its HTTPS download
URL. Search requires a listener-configured public client ID; only explicitly
downloadable tracks expose the Download action. Tone stores source/license
metadata and does not extract tracks from subscription services. LRCLIB remains
opt-in; it now tries an exact metadata match before a strict title/artist
search fallback.

### Privacy, accessibility, settings

- **FR-TRUST-01 (MVP):** Explain what listening data is stored, where it is
  stored, and how to clear it.
- **FR-TRUST-02 (MVP):** No analytics or personalization data leaves the
  device by default; any future opt-in is explicit and revocable.
- **FR-TRUST-03 (MVP):** Store credentials only in platform-backed secure
  storage; never write credentials to logs, backups, or playback queues.
- **FR-TRUST-04 (MVP):** No account is needed to start local playback.
  Recommendations and taste signals are processed on-device by default.
- **FR-TRUST-05 (Next):** Export a portable, human-readable taste profile
  containing only user-approved preferences, exclusions, and optional
  summaries. Exclude raw listening history by default; preview, redact, and
  delete exports.
- **FR-TRUST-06 (MVP):** Treat “Never use mobile data” as a system-wide
  invariant for app-initiated downloads and cache refreshes, including
  background jobs, retries, and connectivity changes.
- **FR-A11Y-01 (MVP):** Screen-reader labels, scalable text, adequate
  contrast, non-color status cues, and usable touch targets on core flows.
- **FR-A11Y-02 (Next):** Now Playing remains operable with gestures, shaders,
  haptics, and animation disabled; reduced-motion settings are respected
  across artwork and transitions.
- **FR-SET-01 (MVP):** Playback, appearance, library source, privacy, and
  storage settings have clear descriptions and safe defaults.

## 4. Technical foundation

### Architecture

Use a **feature-first Flutter structure with clear boundaries**, not a
framework-heavy or service-oriented design:

```text
lib/
  app/                 # app bootstrap, router, theme
  core/                # shared errors, logging, design tokens, utilities
  features/
    home/
    search/
    player/
    library/
    playlists/
    mix/
    offline/
    social/
    recap/
    settings/
  data/                # database, file access, source implementations
  domain/              # stable entities and repository contracts where useful
```

Keep UI widgets focused on rendering and interaction. Put I/O and business
rules in testable services/repositories. Introduce domain/use-case layers
where they improve clarity or protect meaningful logic; do not create a class
for every function.

### Recommended decisions to validate early

- **Flutter/Dart:** Use the current stable Flutter channel and sound null
  safety. Pin the toolchain for CI and document the version used.
- **State:** Riverpod is a good candidate for explicit dependency injection
  and test overrides. Keep state feature-scoped and avoid global mutable
  singletons.
- **Navigation:** `go_router` is a reasonable candidate; deep links and
  restoration should be tested before relying on them.
- **Playback:** Spike `just_audio` with `audio_service` (or an equivalent
  maintained option) for Android background playback, interruptions, queue
  restoration, and codecs before committing. Encapsulate it behind a
  `PlaybackEngine` contract.
- **Persistence:** Use SQLite through a maintained Flutter package for
  library/playlists/history when relational queries are useful. Use
  migrations from the first schema; keep preferences separate from library
  records.
- **Models/code generation:** Prefer straightforward immutable Dart models.
  Add Freezed/JSON generation only if it reduces meaningful boilerplate and
  the team accepts generated-code workflows.
- **File access:** Use Android's Storage Access Framework/document providers
  rather than assuming broad filesystem access. Preserve access grants and
  handle revoked permissions.
- **Secrets:** Use Android Keystore-backed secure storage for credentials.
- **Source adapters:** Define one capability-based interface for source
  discovery and playback. Do not let provider-specific behavior leak into
  widgets or the core queue.
- **Networking:** Introduce an HTTP client only when a permitted remote source
  needs it; centralize timeouts, cancellation, error mapping, and redacted
  logging.
- **No backend for MVP:** Keep the core useful without accounts or a server.
  Add sync/accounts only when a validated user need justifies their cost and
  privacy impact.

Package versions, Android minimum/target SDK, licensing, maintenance health,
and platform support must be verified during the dependency spike; do not
copy Mornye's stack wholesale.

### Core contracts

Establish small contracts before building multiple features:

- `PlaybackEngine`: transport state/events, queue operations, seek, and
  playback errors.
- `MusicSource`: source identity, capabilities, search/browse, availability,
  and playback handoff/stream where authorized.
- `LibraryRepository`: library queries, playlists, favorites, and scan
  results.
- `ListeningProfileStore`: local preference signals, exclusions, reset, and
  export behavior.
- `OfflinePolicy`: connectivity/metering, battery, charging, storage budget,
  user pins, and source download permission. Every background cache job must
  consult the same policy before starting and while transferring.
- `AudioAnalysis`: beat/key/phrase/energy estimates with confidence and
  cancellation; analysis failure must never block normal playback.
- `JamSession`: local discovery, authenticated session join, queue/transport
  messages, host policy, and deterministic disconnect behavior. Audio bytes
  are out of scope for the sync protocol.
- Typed result/error models: distinguish unavailable, permission denied,
  unsupported, offline, and unexpected failures.

The queue should reference stable media identity and source identity, not
credentials or expiring URLs.

Run background work through platform-appropriate schedulers with explicit
constraints and idempotent jobs. The app must not claim an overnight refresh
will occur at an exact time: Android may defer scheduled work. Show the last
refresh and explain unmet conditions. Keep download authorization and
provider-specific expiry rules in the source adapter.

## 5. Stage-by-stage delivery

Each stage is a vertical slice: design the user flow, implement it end to end,
test it, then mark it done. Do not begin the next major feature while the
current slice has unresolved release-blocking defects.

### Stage 0 — Product definition and technical spikes

**Deliver:** named user journeys, acceptance criteria, low-fidelity navigation
and player wireframes, risk register, package/toolchain decision, and Android
playback/file-access spikes.

**Tasks**

- Confirm target users and the primary first-use journey.
- Validate the authorized integration options and constraints for any desired
  streaming, lyrics, video, radio, or podcast provider.
- Prototype background playback, media notification, SAF folder grants,
  database migrations, and audio interruption behavior.
- Define the original design tokens and accessibility checklist.

**Exit gate:** a track can be selected from a user-granted location, play in
the background on a real Android device, and recover from a normal
interruption; unresolved integration/legal questions are explicitly deferred.

### Stage 1 — App shell and quality foundation

**Deliver:** Flutter app shell, theme, navigation, dependency setup, CI, error
model, logging policy, and test harness.

**Tasks**

- Create feature-first project structure and environment/toolchain pin.
- Establish lint rules and format-on-save/CI formatting checks.
- Add light/dark theme tokens, typography, spacing, components, and
  accessibility semantics.
- Add router, app lifecycle handling, typed errors, and redacted structured
  logs.
- Set up unit/widget test jobs and an Android build job.

**Exit gate:** app launches, navigates, supports system text scaling/themes,
and passes analyzer, formatting, and CI checks on a clean checkout.

### Stage 2 — Playback vertical slice

**Deliver:** select and play local audio, persistent mini-player, Now Playing,
queue, and background controls.

**Tasks**

- [x] Implement a `just_audio` engine behind an `audio_service` handler.
- [x] Import selected audio files into app-private storage without changing
  the originals.
- [x] Add a queue with stable track IDs, current-item restoration, and
  periodic playback-position persistence.
- [x] Configure Android foreground media playback service and media-button
  receiver.
- [x] Build mini-player and Now Playing transport/seek UI.
- Test file removal, unsupported/corrupt audio, rapid transport actions, and
  app/process lifecycle.
- Verify background notification, lock-screen/headset controls, audio focus,
  interruption recovery, and process-death restoration on real Android
  hardware.

**Exit gate:** file import and queue persistence tests pass; uninterrupted
real-device playback works through backgrounding, screen lock, Bluetooth
route changes, call/audio-focus interruptions, and restart without duplicate
playback or corrupted queue.

**Implementation checkpoint (2026-10-30):** audio service, audio session,
local-file import, queue/current-item/position persistence, mini-player, and
Now Playing are implemented. Static analysis, widget/library tests, and an
Android debug APK build pass. Real-device playback/lifecycle validation is
still outstanding; do not mark this stage done yet.

### Stage 3 — Personal library

**Deliver:** user-granted folders, scanning/indexing, browse/search, favorites,
and playlists.

**Tasks**

- Add database schema and forward-only migrations.
- [x] Add an Android device-wide media-library scan with runtime permission,
  persisted content URIs, stable cursor-based paging compatible with Android
  MediaStore, and direct playback without copying originals; verified a full
  device scan on Android 17 / CPH2649 after removing unsupported SQL
  `LIMIT/OFFSET` syntax.
- [x] Search local songs by title/artist and play results from Search.
- [x] Read Android album, year, track number, duration, and cover-art metadata;
  provide lazy song/album/artist browsing for large libraries.
- [x] Read embedded tags/artwork when importing audio and fall back to
  embedded track art or standard cover images from granted folders.
- [x] Load locally supplied synchronized `.lrc` and plain-text lyrics, cache
  them per song, and highlight timed lines in Now Playing; use enhanced-LRC
  word timestamps for word-level highlighting when that timing is present.
- [x] Read the active Android track's available codec, sample rate, channel
  count, and bitrate from its source stream for Now Playing.
- [x] Add Android SAF folder selection with persisted access, folder scanning,
  removal, and grant release; report revoked access errors.
- Implement scan progress/cancellation and a guided folder re-selection flow
  for revoked grants.
- [x] Read embedded tags and cover art for SAF folder tracks, automatically
  match same-name `.lrc`/`.txt` files, and cache matched lyrics locally.
- Read available metadata safely and expose scan failures without losing
  existing indexed data.
- [x] Browse indexed songs, albums, and artists with virtualized lists and
  search the local title/artist/album metadata.
- [x] Save and remove persistent favorites from the library and Now Playing.
- [x] Create, rename, and delete playlists; add/remove songs, reorder tracks,
  persist playlists, and play their queues.
- Add duplicate review rather than destructive automatic merging.

**Exit gate:** large-library scans remain responsive; scan interruption,
permission revocation, duplicate metadata, deleted files, and database
migration tests pass.

### Stage 4 — Distinctive personal DJ MVP

**Deliver:** local-library mixes, intent controls, preview/edit, explanations,
and explicit feedback.

**Tasks**

- [x] Define candidate eligibility using indexed local tracks with known
  durations, saved favorites, user discovery preference, and mix exclusions.
- [x] Respect the requested session duration, avoid duplicate picks, support a
  cold start, and report tracks omitted for missing duration.
- [x] Build an editable mix list with per-track removal, favorite feedback,
  persistent future-mix exclusions, and a real playback queue.
- [x] Use available embedded genre/BPM tags to keep compatible tracks
  together, and explain picks using the actual signal used; do not claim
  inferred emotion, acoustic energy, or listening-history analysis.
- [x] Add on-device artist radio from same-artist tracks plus known genre or
  compatible tagged tempo; never imply network radio playback.
- [x] Generate small, explainable playlist suggestions from actual genre tags
  and saved favorites; allow previewing or saving them as regular playlists.
- [x] Add explicit Home mood mixes matched from actual genre/BPM tags and play
  the selected mix from the local library; no mood or history inference.
- [ ] Add source-availability validation for revoked device/folder grants and
  improve fallback/replace behavior during a session.
- Evaluate results with curated test libraries and human listening sessions;
  tune for usefulness rather than time-in-app.

**Exit gate:** a new user can create a sensible mix with no listening history;
every candidate is playable; feedback changes the session; exclusions are
respected; recommendations are explainable and resettable.

### Stage 5 — Now Playing hero and everyday trust

**Deliver:** distinctive Now Playing screen, embedded lyrics, haptic/gesture
controls, core visual effects, privacy controls, and accessibility polish.

**Tasks**

- [x] Refresh Home with speed-dial albums and quick picks; add a floating
  navigation dock, continue listening, art-led Now Playing, a subtle artwork
  backdrop, and mini-player progress. Rotate the Home library shelf by day
  without collecting or implying listening-history data.
- [x] Decode and cache Android audio amplitude peaks for an accessible,
  seekable Now Playing waveform; show BPM-tag-based approximate bar guides
  only when tagged tempo exists, and preserve standard seeking with retry on
  analysis failure.
- [x] Align Now Playing to a compact light artwork-and-waveform hierarchy and
  give album groups a dedicated detail view with working album playback.
- [x] Show indexed album artwork and metadata; load local synchronized or
  plain-text lyrics automatically from granted folders or saved cache, and
  highlight timed lines or enhanced-LRC words in Now Playing.
- Build art-driven palette extraction, restrained looping visuals, and a
  lyrics layer that keeps controls readable.
- Add optional gesture shortcuts and beat-aware haptics with accessible
  button alternatives and independent toggles.
- Keep unavailable lyrics states clear; defer remote lyrics until provider
  rights and terms are verified.
- Add settings for playback, appearance, privacy, and storage; explain local
  history and recommendation data.
- [x] Explain which personal data Tone persists locally, disclose that
  listening history is not currently recorded, and provide safe controls to
  clear cached lyrics and personal mix signals without deleting music.
- Add data export/restore only after schema and migration behavior is tested.
- Audit TalkBack, focus order, contrast, large text, reduced motion, thermal
  behavior, and touch targets.
- Run usability sessions on adding music, finding a track, starting a mix,
  controlling playback, and recovering a failed permission.

**Exit gate:** all playback controls remain discoverable and usable with
visualizers, gestures, and haptics disabled; effects do not obscure lyrics or
controls; users can understand and clear local listening data.

### Stage 6 — Smart offline

**Deliver:** dependable manual offline controls first, followed by opt-in
overnight preparation and transparent cache management.

**Tasks**

- Implement one shared offline policy for foreground and background
  transfers, with “Never use mobile data” enforced at the transfer boundary.
- Add user-visible Wi-Fi/metered status, storage budget, reserve, download
  queue, pins, and cache eviction preview.
- Implement bounded, idempotent jobs with cancellation, retry policy,
  connectivity re-checks, battery/charging constraints, and job status.
- Add local prediction only after there is enough user data or explicit
  favorites; use an understandable cold-start strategy and opt-in onboarding.
- Restrict preparation to user-owned content or sources that explicitly allow
  offline caching; honor expiration and revocation.
- Verify system scheduler behavior and communicate that Android may defer
  background work.

**Exit gate:** automated tests prove no app-initiated transfer occurs over
metered/mobile networks with the switch enabled, including connectivity
changes mid-transfer, retries, and background execution. Cache eviction never
deletes source files, explicit downloads, or pinned items. The user can see
and cancel every prepared item.

### Stage 7 — Better mixes and sound personalization

**Deliver:** harmonic/energy-aware transitions, additional mix styles,
headphone Auto-EQ, normalization, and a carefully bounded comfort limiter.

**Tasks**

- [x] Add configurable smooth and BPM-matched dual-deck overlaps, a safe
  smooth fallback when tagged tempos are missing or incompatible, and a
  short live position ticker.
- [ ] Add echo-out and cue-point/phrase analysis; do not imply key matching
  until reliable key metadata or analysis exists.
- Add cancellable, cached analysis with confidence values for beat, key,
  phrase/cue points, and energy; cap analysis cost and avoid delaying play.
- Build gentle fade, beat-matched, and echo-out transitions with clear
  previews, per-style controls, and reliable fallback.
- Test short tracks, silence, tempo/key changes, low-confidence analysis,
  codec/decoder differences, and back-to-back transitions.
- Verify AutoEQ dataset provenance/license and attribution before bundling or
  downloading profiles; implement headphone identification with manual
  selection/override.
- Add loudness normalization and a configurable, non-medical hearing-comfort
  limiter; ensure gain staging cannot introduce clipping or abrupt jumps.
- Keep room/spatial effects off by default and defer until route behavior,
  processing compatibility, and battery impact are measured.

**Exit gate:** playback stays uninterrupted when analysis/effects fail or are
disabled; transitions meet measured timing and loudness targets on supported
devices; users can identify and override the selected headphone profile.

### Stage 8 — Offline social and recaps

**Deliver:** local-network Jam, monthly/yearly recaps, and consent-first
sharing foundations.

**Tasks**

- Design host/member permissions, queue conflict rules, disconnect behavior,
  local discovery, QR join, expiry, and explicit leave/revoke controls.
- Sync queue/transport metadata only. Make per-participant track availability
  clear; do not send audio bytes or credentials through Jam.
- Threat-model local discovery and QR/session tokens; test replay, expired
  tokens, unauthorized joins, host departure, and network loss.
- Add monthly/yearly recap from local history with date range, data reset, and
  export preview.
- Defer Friend Blend until mutual consent, data scope, expiration, and
  deletion UX are reviewed.
- Permit moment-card artwork/lyrics/audio previews only when rights and
  provider terms allow; otherwise export safe metadata or a link.

**Exit gate:** Jam works without internet on a representative local network;
no audio is transferred by queue sync; unauthorized or expired joins fail
closed. Recaps and cards reveal only the user-approved fields and can be
exported or deleted.

### Stage 9 — Network libraries, spoken audio, and authorized connectors

**Deliver:** one validated remote source or spoken-audio source, followed by
only those external integrations with viable official access.

**Tasks**

- Select one NAS/personal cloud or podcast/radio source based on validated
  demand; document authentication, storage, streaming, seeking, offline, and
  failure behavior.
- Add source capability declarations, secure credential storage, cancellation,
  timeouts, and source-specific offline rules.
- Add spoken-audio resume position, playback speed, and skip controls where
  appropriate.
- Reconfirm provider terms, API access, commercial rights, and supported
  surfaces before each commercial/video connector.
- Keep the Jamendo connector scoped to search and artist-authorized downloads;
  it does not claim streaming playback or subscription-service offline access.
- Clearly distinguish native playback, permitted embedded playback, and
  external handoff; test unavailable accounts, regions, and API changes.

**Exit gate:** source tests cover offline operation, expired credentials,
server restart, seeking, cancellation, credential removal, and unsupported
actions. The app remains useful if any connector is unavailable.

### Stage 10 — Release, learn, and maintain

**Deliver:** signed Android release, privacy disclosures, support path,
crash-free baseline, and a prioritized feedback loop.

**Tasks**

- Test a representative device/OS matrix and low-storage/low-memory cases.
- Verify backup/restore and upgrade from the previous release.
- Review dependency licenses (including AutoEQ/profile and media assets),
  permissions, privacy declarations, and store requirements.
- Use opt-in diagnostics only if justified; redact track names, paths,
  credentials, and identifiers.
- Triage user feedback into defects, usability improvements, and evidence for
  later features.

**Exit gate:** release checklist complete, no known critical/high defects in
core playback/library/offline-safety flows, and rollback/hotfix process
documented.

## 6. Testing and engineering quality gates

### Required checks for every feature

1. Acceptance criteria are written before implementation.
2. Unit tests cover business rules, parsing, ranking, error mapping, and state
   transitions.
3. Widget tests cover user-visible states and interactions.
4. Integration tests cover the end-to-end journey on Android.
5. Manual device verification covers behavior that mocks cannot validate:
   audio focus, notifications, SAF, Bluetooth, codecs, and lifecycle.
6. Analyzer, formatter, and relevant tests pass before the feature is marked
   done.
7. Documentation, permissions, migration notes, and accessibility semantics
   are updated with the feature.

### Test matrix

- **Unit:** queue ordering/restoration, source capabilities, ID normalization,
  playlist operations, mix constraints, exclusions, duration, preference
  reset, offline policy decisions, cache eviction eligibility, and Jam
  message/session rules.
- **Widget:** loading/error/empty/success, navigation, large text, theme,
  player controls, lyrics contrast, visualizer/reduced-motion states, offline
  controls, transfer status, and permission recovery.
- **Integration:** first launch → grant folder → scan → play → background
  control → favorite → create playlist → restart and restore queue; offline
  policy → schedule refresh → change to metered network → verify transfer
  stops; Jam QR join → queue sync → disconnect.
- **Platform/device:** supported Android versions, at least one low/mid-range
  device, notification permission behavior, Bluetooth/headphones, audio
  interruptions, process death, storage permission revocation, actual
  metered/unmetered network changes, battery saver, and background scheduler
  behavior.
- **Performance:** startup, library scan responsiveness, search latency,
  scrolling, memory during artwork loading, battery during long playback,
  overnight analysis cost, visualizer frame time/thermal behavior, and
  transition analysis latency.
- **Accessibility:** TalkBack, font scaling, contrast, focus order, semantics,
  touch targets, reduced motion, non-gesture control parity, and disabling
  beat haptics/visual effects.
- **Resilience:** airplane mode, source removed, malformed tags, unreadable
  files, low disk space, interrupted scans, expired credentials, and database
  upgrade; interrupted cache jobs, changed network type, revoked offline
  rights, low battery, low storage, stale headphone profile, unsupported
  effect route, and expired/forged Jam join requests.
- **Audio quality:** measure transition timing, peak/clipping, loudness
  changes, normalization consistency, Auto-EQ profile selection, effect
  bypass, and no audible interruption on analysis failure.

### Definition of done

A feature is done only when:

- Its user story and acceptance criteria pass.
- Errors are visible and actionable; no silent success-shaped fallback masks
  failure.
- Tests cover the important normal, boundary, and failure cases.
- It follows existing project style and passes formatting/analyzer checks.
- It works with accessibility settings and supported device layouts.
- It does not expose private listening data or credentials.
- Its docs, permission text, and release notes are current.

## 7. Tracking board

Use one card per user-visible vertical slice. Keep work-in-progress limited to
one main feature per contributor.

| ID | Feature | Stage | Status | Acceptance evidence | Dependencies |
|---|---|---:|---|---|---|
| PLAN-01 | Confirm first-use journey and product name | 0 | In progress | Approved journey and working name; Tone is provisional | None |
| SPIKE-01 | Validate Android playback and background controls | 0 | In progress | Audio-service integration and APK build complete; physical lifecycle validation outstanding | None |
| SPIKE-02 | Validate SAF folder access and persistence | 0 | Not started | Grant/revoke/restart test | None |
| SPIKE-03 | Verify network metering and Android background scheduling | 0 | Not started | Device proof for metered changes, battery constraints, and deferred jobs | None |
| SPIKE-04 | Validate playback engine/DSP/visualizer options | 0 | Not started | Playback, processing, shader, and device compatibility report | SPIKE-01 |
| FOUNDATION-01 | App shell, design tokens, CI, and linting | 1 | In progress | Flutter analysis/tests and Android debug build pass; CI and accessibility audit remain | Stage 0 |
| PLAYER-01 | Local playback, queue, mini-player, and Now Playing | 2 | In progress | `flutter test`, `flutter analyze`, and APK build pass; a live two-track handoff was smoke-tested on CPH2649; broader interruption and queue-restoration tests remain | FOUNDATION-01, SPIKE-01 |
| LIBRARY-IMPORT-01 | Import and persist selected local audio | 3 | In progress | `test/music_library_test.dart` passes; Android picker/device smoke test pending | FOUNDATION-01 |
| LIBRARY-01 | Local library scan, browse, and search | 3 | In progress | Device/SAF scans, stable MediaStore cursor paging, imported tags, embedded/album/folder cover fallback, local sidecar lyric auto-match/cache, browse/search tests pass; Android 17 / CPH2649 returned a successful scan; scan progress/cancellation and permission-revocation recovery remain | FOUNDATION-01, SPIKE-02 |
| LIBRARY-02 | Favorites and playlists | 3 | In progress | Favorite persistence, playlist CRUD/membership/reorder/persistence, and playlist-screen tests pass; real-device flow remains | LIBRARY-01 |
| DJ-01 | Intent-based local mix and editable preview | 4 | In progress | `test/personal_mix_test.dart` covers duration, known-duration eligibility, favorites, exclusions, genre/BPM ordering, and cold-start rules; `test/widget_test.dart` verifies a generated mix starts a real queue; source-availability validation and listening review remain | PLAYER-01, LIBRARY-01 |
| DJ-02 | Explainable picks and immediate feedback | 4 | In progress | Reasons reflect favorites, library membership, and available genre/tempo matches; favorite, per-session removal, persistent exclusion, and exclusion reset are wired; usability review and feedback tuning remain | DJ-01 |
| PLAYER-02 | Art-led Now Playing, lyrics, gestures, and haptics | 5 | In progress | Album art in library/search rows; live position ticker; sidecar and opt-in LRCLIB lyrics; enhanced-LRC word timing; Android source codec/sample-rate/channel/bitrate details; source-level cover extraction fallback; smooth page transitions. Accessibility, reduced-motion, gestures, and haptics remain | PLAYER-01, SPIKE-04 |
| TRUST-01 | Privacy controls, local profile export, and reset | 5 | In progress | Privacy screen controls optional LRCLIB lookup and clears cached lyrics/favorites/mix exclusions; portable profile export and data-flow review remain | DJ-02 |
| OFFLINE-01 | Wi-Fi-only policy and protected manual downloads | 6 | Not started | Prove no mobile transfer across foreground/background and network changes | LIBRARY-01, SPIKE-03 |
| OFFLINE-02 | Opt-in overnight prediction and cache eviction | 6 | Not started | Battery/network/storage constraints and protected-item tests | OFFLINE-01, DJ-02 |
| MIX-01 | Harmonic/energy-aware transitions and three mix styles | 7 | Not started | Audio quality measurements and fallback tests | PLAYER-01, SPIKE-04 |
| SOUND-01 | Auto-EQ, normalization, and comfort limiter | 7 | Not started | License review, route tests, loudness/clipping measurements | SPIKE-04 |
| SOCIAL-01 | Local Jam with QR/local-network queue sync | 8 | Not started | Offline security, disconnect, and no-audio-transfer tests | PLAYER-01, LIBRARY-02 |
| RECAP-01 | Exportable monthly/yearly recap | 8 | Not started | Time-range, consent, deletion, and export tests | TRUST-01 |
| SOURCE-01 | First remote or spoken-audio source | 9 | Not started | Provider-specific failure and security tests | Core stable, provider selected |
| INTEGRATION-01 | First authorized commercial/video connector | 9 | Deferred | Terms/API verification and working supported flow | Provider verification |
| RELEASE-01 | Android release readiness | 10 | Not started | Release checklist, device matrix, upgrade and rollback evidence | Core feature gates |

Status values: **Not started**, **In progress**, **Blocked**, **In review**,
**Done**. A blocked card must state the dependency or decision needed. Add
acceptance evidence (test name, device result, or reviewed artifact) before
marking any card Done.

## 8. Open decisions to resolve before implementation

- Product name and original brand identity.
- Minimum Android version and device support policy.
- First-use persona and whether the first release is strictly personal/local
  or includes a validated network source.
- Which audio formats/codecs and playback-quality goals are essential.
- Which devices/headphone models need Auto-EQ support first, and whether
  profile data may be bundled or must be fetched.
- What cache budget and battery policy should be the defaults; recommended
  default is opt-in prediction, Wi-Fi-only, charging preferred, and a modest
  user-editable cache cap.
- Whether Jam is one host output shared in a room/car or a synchronized
  multi-device session. The initial safe design is queue/transport sync only;
  each device plays a source it is authorized to access.
- What information is acceptable in exported moment cards and recaps; default
  to explicit per-export preview and no automatic sharing.
- Whether Jam should support host-device playback for a shared room/car
  alongside optional synchronized playback on each participant's device.
  Neither mode should transmit protected audio by default.
- Which licensed streaming services, if any, have viable official integration
  paths for this product.
- Whether any account/sync feature is needed; default recommendation is to
  defer it.
- How much personalization should be automatic versus explicit controls;
  default recommendation is transparent, local-first learning.
- Release channel, distribution model, and sustainability/business model.

## 9. Product risks and mitigations

| Risk | Mitigation |
|---|---|
| Streaming services do not permit the desired integration | Verify terms/API access in Stage 0; make source handoff a first-class option |
| Scope balloons into a clone of several products | Protect the “personal DJ + great personal library” core; defer connectors until validated |
| Audio playback works in foreground but fails in real life | Spike early and test on physical devices, interruptions, and process lifecycle |
| Storage permissions are fragile across Android versions/providers | Use SAF grants, test revocation/recovery, preserve indexed data |
| Recommendations feel random or opaque | Start with explicit intent, constrained candidates, explanations, and user feedback |
| Personalization harms trust | Keep it local by default, disclose signals, allow pause/reset/export |
| “Never use mobile data” fails during a network switch or background retry | Enforce the policy at the transfer boundary, re-check during jobs, and test with real metered/unmetered transitions |
| Smart caching consumes battery/storage or evicts something valuable | Make prediction opt-in, bound jobs/storage, protect explicit downloads and pins, and expose every eviction |
| Beat/key analysis makes transitions worse or interrupts playback | Use confidence-gated analysis, conservative fallbacks, cancellation, and measured device tests |
| Audio processing is mistaken for medical hearing protection | Use non-medical language, clear limits, conservative defaults, and no safety guarantee claims |
| Jam becomes an unauthorized audio redistribution mechanism | Sync metadata only by default; require each device to resolve a playable authorized source |
| Social cards violate rights or expose private history | Gate fields/previews by rights, show an export preview, and make sharing opt-in |
| Shader/animation polish harms accessibility, battery, or thermals | Respect reduced motion, cap frame cost, provide a full off switch, and test low-end devices |
| Visual polish hides weak fundamentals | Require playback/library quality gates before adding decorative features |
| Package churn or poor maintenance creates rework | Verify package health/compatibility, pin versions, and isolate dependencies behind adapters |
