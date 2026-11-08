# Tone AutoMix Implementation Plan

**Status:** Milestones A and B complete; Milestone C gain-transition prototype
implemented. Milestone C.1 developer diagnostic driver is implemented;
human acoustic and remaining device qualification are pending.  
**Approved direction:** Introduce AutoMix incrementally while preserving Tone's
Flutter app, queue, and media-session boundary. Do not select or ship a native
audio engine before validating platform support, licensing, and cost.

## Repository-specific architecture

Keep `ToneAudioHandler` as the existing `audio_service` transport and
media-session boundary. Keep AutoMix policy in `lib/features/auto_mix/`, not
in player widgets or the library's queue code. `TransitionPlanner` is pure
Dart and plans only from supplied track metadata and confidence; it does not
analyze audio or perform playback.

`AudioEngine` has a two-player `just_audio` prototype. `ToneAudioHandler` owns
both decks and remains the playback-session and queue boundary. Deck A drives
existing queue transport; Deck B can be preloaded, inspected, played, paused,
seeked, gain-adjusted, and unloaded through explicit audio-service actions.
An explicit `autoMix.transitionToNextTrack` audio-service action runs a
profile-selected gain curve, promotes the incoming player to queue-owned Deck
A, and updates the existing queue/media-item state. Now Playing exposes this
as an optional, manually triggered 10-second “Mix next” action. Its animated
indicator reflects transition activity, and its progress bar tracks the
completed gain-ramp commands with the requested ramp duration shown as a
target. Neither is an audio-reactive waveform or a measurement of rendered
audio progress. During playback, the handler preloads the next queue item and
starts a profile-duration crossfade near the current track's end; ordinary
queue advancement remains the fallback when the incoming deck cannot be
prepared or the transition fails. This timing is duration-based, does not use
the displayed quiet-region estimates, and is not beat/phrase detection. Now
Playing analyzes the current and actual
next queue item concurrently on Android using the existing decoded,
per-track-normalized PCM peak waveform. It marks sustained quiet lead-in/tail
regions when detected; these are relative-energy estimates, not musical
intro/outro or mix-point claims. The manual crossfade still begins immediately
and does not schedule itself at those markers. The approach is not
sample-accurate or professional mixing.
The Now Playing artwork is sized to use more of the available screen while
remaining capped for larger displays. The existing decoded waveform remains
the seek/progress visualization, with a quiet-tail estimate marker when
available. Energy analysis is Android-only; other platforms retain manual
crossfade without these cues.

## Exact files created for Milestone A

| File | Responsibility |
|---|---|
| `lib/features/auto_mix/auto_mix_profile.dart` | Atmospheric, Balanced, and Energetic defaults and profile-selected transition styles. |
| `lib/features/auto_mix/auto_mix_settings.dart` | Immutable profile/duration settings, 3–30 second user duration bounds, and profile defaults. |
| `lib/features/auto_mix/track_analysis.dart` | Track identity, optional duration and BPM evidence, and caller-supplied BPM confidence. Rejects invalid identity/duration/confidence; does not produce analysis. |
| `lib/features/auto_mix/transition_plan.dart` | Validated plan values, style and tempo-assessment enums, positions, duration, fallback state, and confidence. |
| `lib/features/auto_mix/transition_planner.dart` | Pure policy: validates track identity, assesses only reliable BPM within a conservative 5% range, chooses duration/style, and falls back when evidence is unavailable or unreliable. |
| `lib/features/auto_mix/audio_engine.dart` | Player-independent contract for deck load, transport, gain, state, and lifecycle operations. |
| `lib/features/auto_mix/auto_mix_controller.dart` | Holds settings, requests plans, and forwards deck operations to an injected engine. |
| `test/auto_mix/transition_planner_test.dart` | Pure planner tests for missing, matching, different, invalid, and low-confidence BPM, profiles, duration bounds, and invalid track metadata. |
| `docs/AUTOMIX_IMPLEMENTATION_PLAN.md` | Records this repository-specific staged plan, exact integration surfaces, and validation gates. |

### Milestone A existing files modified

- `README.md`: records the implemented but unqualified dual-deck prototype.
- `PROJECT_PLAN.md`: records AutoMix's staged status and qualification gate.
- `docs/PRD.md`: removes AutoMix from initial non-goals and labels its current
  shipped status accurately.
- `docs/ARCHITECTURE.md`: documents the separate AutoMix feature boundary.

### Milestone B files added or modified

| File | Responsibility |
|---|---|
| `lib/features/auto_mix/audio_engine.dart` | Expanded with deck state, source, error, and processing-state types. |
| `lib/features/auto_mix/just_audio_dual_deck_engine.dart` | Replaceable prototype using two independent `just_audio` players and an injectable player factory. |
| `lib/features/auto_mix/auto_mix_controller.dart` | Expanded to coordinate incoming-deck preload and controls through the engine interface. |
| `lib/features/player/tone_audio_handler.dart` | Owns both decks in the existing audio-service isolate, preserves queue/transport ownership, centralizes audio-session behavior, and exposes limited Deck B custom actions. |
| `test/auto_mix/dual_deck_engine_test.dart` | Engine-contract tests using an injected deck-player fake. |
| `test/auto_mix/tone_audio_handler_dual_deck_test.dart` | Queue regression verifying queue advancement remains on Deck A and clears the old Deck B preload. |

No database, Android, or iOS audio-configuration files are modified.

## Staged implementation and exact integration surfaces

### Milestone A — Foundation (implemented)

The files above establish models, settings, a pure planner, an injected
controller, and a backend contract. There is no real-time mixing, persistence,
analysis, UI, or playback behavior.

### Milestone B — Dual-deck playback prototype (implemented; qualification pending)

1. The repository's `just_audio` 0.10.6 documentation explicitly supports
   multiple players playing at once. Its Android plugin creates a separately
   identified ExoPlayer per `AudioPlayer`, and volume is set per player.
   Tone constructs both players with automatic focus activation and automatic
   interruption handling disabled; `ToneAudioHandler` centrally activates
   the shared music session and pauses/resumes both decks together.
2. The engine is owned inside `ToneAudioHandler`, which is created by
   `audio_service`; Deck A remains authoritative for queue, now-playing item,
   seek, repeat, shuffle, and media notification state. Queue mutations clear
   stale Deck B content. Deck B load errors are isolated from Deck A.
3. A physical-device smoke test ran on an OPPO CPH2649 (Android 17, API 37)
   using two distinct generated PCM WAV files: 44.1 kHz mono, 9 seconds
   (about 794 KB), and 48 kHz stereo, 13 seconds (about 2.5 MB). Both deck
   positions advanced concurrently; each deck reported its own gain; and
   Deck A remained playing when Deck B was paused, given a missing source, and
   unloaded. Android logs showed separate active `AudioTrack` instances. The
   check validates engine and decoder overlap for these WAV inputs, not
   subjective audibility or independent acoustic gain measurement.
4. The device smoke test does not qualify other codecs, MediaStore/SAF
   `content://` sources, the app's foreground media-service/background
   lifecycle with the screen locked, calls/audio-focus changes, Bluetooth,
   headphone route changes, repeated real transitions, long playback, CPU,
   memory, or battery. Those checks remain required.
5. `setVolume` is an independent player command; its gain-transition status is
   documented under Milestone C below. It does not promise sample-accurate
   gain or synchronized starts.
6. Research native engine options only after requirements and source access
   are known. Compare Android and iOS support, licensing, codec/source access,
   build cost, lifecycle integration, and DSP capabilities. Do not commit to
   JUCE or a replacement engine without that review.
7. Do not pass audio buffers through Dart or Flutter channels or schedule
   sample-timed work with Dart timers. Keep ordinary queue playback as the
   reliable path until the remaining device qualification passes.

### Remaining Android device validation checklist

On physical devices, extend the smoke test across different codecs and
sample rates, local imports, `content://` MediaStore items, and granted SAF
items. Verify actual audible overlap and gain independence, queue
edits/skip/repeat/shuffle, long background playback with the screen locked,
calls and audio-focus changes, headphone unplug/reconnect, Bluetooth output,
repeated transitions, CPU, memory, and battery. Record device/OS, source type,
codec, observed interruption/gap behavior, resource measurements, and
failures. Passing unit tests or the WAV smoke test is not a substitute for
this checklist.

### Milestone C — Stepped gain-transition prototype (implemented; quality gate open)

Files introduced or changed for this milestone include:

- `lib/features/auto_mix/transition_gain_curve.dart`: pure profile curves.
- `lib/features/auto_mix/audio_engine.dart` and
  `lib/features/auto_mix/just_audio_dual_deck_engine.dart`: promote incoming
  player to the queue-owned Deck A role while remapping deck state/events.
- `lib/features/auto_mix/auto_mix_controller.dart`: stepped gain ramp,
  cancellation, and recovery.
- `lib/features/player/tone_audio_handler.dart`: transition action, queue
  promotion, interruption-safe cancellation, and profile headroom.
- `test/auto_mix/auto_mix_controller_test.dart`,
  `test/auto_mix/dual_deck_engine_test.dart`, and
  `test/auto_mix/tone_audio_handler_dual_deck_test.dart`: curve, ramp,
  promotion, queue, cancellation, and failure coverage.

1. `TransitionGainCurve` defines equal-power cosine/sine, eased
   gradual-atmospheric, and linear quick-blend amplitude curves.
2. `AutoMixController` executes the selected curve by issuing independent
   `just_audio.setVolume` commands at a nominal 20 ms cadence. Each pair of
   deck-gain commands is awaited before the next step; platform-channel and
   player processing latency can make the actual interval longer or uneven.
   This is stepped volume automation, not native scheduled DSP, and it cannot
   guarantee sample accuracy or synchronized starts.
3. `ToneAudioHandler` exposes `autoMix.transitionToNextTrack`. The explicit
   action transitions to the queue's next item immediately, bounded by the
   outgoing track's remaining duration; on completion it promotes Deck B to
   the queue-owned Deck A role, updates the current queue item, and releases
   the outgoing player. Pause and queue mutations cancel an in-progress ramp
   and restore pre-transition gains.
4. `lib/features/auto_mix/transition_gain_curve.dart` contains the pure curves;
   `test/auto_mix/auto_mix_controller_test.dart` tests curve endpoints,
   midpoints, ramp updates, cancellation, and promotion. Handler tests verify
   queue/media-item advancement and cancellation. The tests establish gain
   commands and queue behavior, not perceptual smoothness.
5. A 2-second equal-power ramp was exercised on the OPPO CPH2649, Android 17,
   using the distinct 44.1 kHz mono and 48 kHz stereo WAV fixtures. Each deck
   reported 101 gain-state updates (including initial/final corrections).
   Measured inter-update intervals had a 22 ms median on both decks; averages
   were 21.65 ms (A) and 21.85 ms (B), with maxima of 31 ms (A) and 30 ms (B).
   The operation took 2251 ms versus 2000 ms requested. These are Dart-side
   player-state update timings, not measurements of rendered acoustic gain.
6. **Automation quality assessment:** the current backend is not yet
   demonstrated sufficiently smooth for a production crossfade. This device
   timing is close to the nominal 20 ms command cadence, but no listening or
   output-loopback assessment was performed; platform-channel/player timing
   and acoustic response may differ. The backend remains a replaceable
   prototype until audible fade quality is evaluated.
7. No automatic transition trigger or production AutoMix UI has been added.
   The separate Milestone C.1 debug diagnostic screen is not part of the
   ordinary app interface. These milestones add no BPM analysis, database
   writes, or native audio configuration.

### Milestone C.1 — Diagnostic driver and acoustic/device validation (driver implemented; human tests pending)

This is a validation gate, not a feature milestone. The OPPO timing results
above describe Dart/player-state updates only; they are not acoustic evidence.
Do not begin analysis, intelligent planning, automatic transitions, or
user-facing AutoMix controls until this gate has adequate evidence.

#### Run the developer diagnostic driver

The diagnostic UI is compiled into the app but only opens in a debug build
when the explicit developer define is enabled. It uses `ToneServices`, the
existing `ToneAudioHandler`, queue, transition controller, and dual-deck
engine; it does not implement a second transition. Diagnostic mode disables
queue/playback-position persistence so test selections do not overwrite the
saved playback queue. Normal debug/release launches are unchanged.

On the connected OPPO, launch it with:

```powershell
flutter run --debug -d ab49fece --dart-define=TONE_AUTOMIX_DIAGNOSTICS=true
```

In the diagnostic screen:

1. Select two different available tracks from the existing library. This
   replaces the in-memory playback queue for the current diagnostic launch;
   the last normal app queue remains persisted and will be restored by a
   normal launch.
2. Select one of **3, 5, 10, 15, 20, or 30 seconds**. Run each selected pair
   at every duration required by the listening matrix. The AutoMix profile is
   currently the controller's default Balanced profile; the active equalizer
   preset is included in each result.
3. Press **Start trial** and listen through the transition and briefly after
   promotion. Press **Cancel** to cancel without queue promotion. A finished,
   cancelled, or failed trial can be repeated without restarting the app.
4. The on-screen diagnostic status displays lifecycle data and observed gain
   state updates while running. Afterward, the full JSON record is shown and
   appended to `automix-diagnostic-results.jsonl` in the app's private
   application-support directory. The screen shows the exact path. Use
   Android Studio's Device Explorer to retrieve the file.
5. Record human ratings and listening observations separately in the
   per-trial template below. Device, route, approximate volume, listener,
   profile observations, and subjective scores are not inferred by software.

The action accepts only the listed durations and only in debug diagnostic
mode. Invalid durations are rejected; normal calls without diagnostic
arguments retain the existing default behavior. The planner still clips a
requested duration to known track lengths and the handler may clip it to the
outgoing track's remaining time. Results contain both requested and effective
transition durations. A clipped result must be recorded as such, not counted
as a trial at the full requested duration.

The JSON record includes trial and track IDs, AutoMix/EQ profiles, start and
completion timestamps, elapsed operation time, promotion outcome,
cancellation/error fields, lifecycle events, and per-deck changed-gain event
counts/minimum/maximum values and interval summaries. Interval values are
derived from Dart-side `AudioEngineState` event receipt timestamps during the
gain ramp only. They are not rendered audio timing, acoustic gain, or proof
that an audio buffer was rendered at that timestamp. Elapsed time covers the
gain ramp itself; lifecycle timestamps separately record promotion and
cleanup. These values support repeatability only; listeners must make the
acoustic assessment.

#### Repeatable listening procedure

1. Record the device model, Android version, app build, output route, source
   format, EQ/profile, and approximate device volume. Keep the device, route,
   volume, and EQ fixed when comparing trials. Use the flat EQ profile when
   available; record any other profile separately.
2. Select locally available tracks the tester is authorized to play. Record
   labels or anonymized IDs only; do not copy private audio into the
   repository. Confirm Deck A is playing and the intended next track is loaded
   on Deck B before each run.
3. Run the developer driver for the selected pair and duration. Record the
   requested and effective duration, completion result, queue item before
   and after, deck states, errors, and recovery action. Listen throughout the
   transition and briefly after deck promotion.
4. Record clicks, pops, gaps, volume dips or jumps, midpoint bass/loudness
   excursions, track imbalance, clashes, and any change at promotion. Do not
   use reported gain values or update timings as a substitute for listening.
5. Rate each dimension from 1 (unacceptable) to 5 (clean), and include a
   concise note. Preserve individual trial records; do not average away a
   severe artifact. Run each eligible pair/duration twice. Mark an ineligible
   combination with its reason rather than omitting it.

| Pair category | 3 s | 5 s | 10 s | 15 s | 20 s | 30 s |
|---|---:|---:|---:|---:|---:|---:|
| Similar genre, tempo, and loudness | 2 trials | 2 trials | 2 trials | 2 trials | 2 trials | 2 trials |
| Similar genre, different BPM | 2 trials | 2 trials | 2 trials | 2 trials | 2 trials | 2 trials |
| Different genre and BPM | 2 trials | 2 trials | 2 trials | 2 trials | 2 trials | 2 trials |
| Strong bass | 2 trials | 2 trials | 2 trials | 2 trials | 2 trials | 2 trials |
| Overlapping vocals | 2 trials | 2 trials | 2 trials | 2 trials | 2 trials | 2 trials |
| Quiet intro/outro or abrupt ending | 2 trials | 2 trials | 2 trials | 2 trials | 2 trials | 2 trials |

Per-trial record:

| Field | Record |
|---|---|
| Trial ID / listener | |
| Device, OS, app build, route, approximate volume | |
| Track labels or anonymized IDs / formats / pair category | |
| EQ/profile / requested duration / reported duration | |
| Completed / queue item before and after / deck states | |
| Error or recovery action | |
| Smoothness (1–5) / loudness continuity (1–5) | |
| Click-pop-gap severity (5 = none) / promotion continuity (1–5) | |
| Audible observations and notes | |

#### Real-device reliability matrix

For every run record whether playback continued, the transition completed or
recovered, the expected queue item became current, and either deck remained
stale or unintentionally playing. Record audible/reported errors separately.
If a route, format, interruption, or duration is unavailable, mark it
unverified. Do not infer absence of resource leaks from listening; any CPU or
memory check must include the Android profiling method and observation period.

| Check on OPPO CPH2649 | Result / evidence |
|---|---|
| Screen locked during transition | Pending |
| Bluetooth output | Pending |
| Wired headphones, if supported and available | Pending |
| Safe audio-focus interruption and recovery | Pending |
| At least 10 consecutive transitions, if practical | Pending |
| MP3, AAC, FLAC, and WAV where available/supported | Pending |
| Extended playback with repeated transitions | Pending |
| CPU/memory profiling, method and duration if performed | Pending |

#### Current execution constraints and results

The connected OPPO CPH2649 (Android 17/API 37) is available. The driver
selects only available tracks already in Tone's library; it does not scan,
copy, or import audio. Human listeners must identify pair categories and
record actual observations. No C.1 listening trials or reliability matrix
checks have been performed yet.

The prior 2-second equal-power device measurement remains timing-only
evidence: 2251 ms elapsed, 101 state updates per deck, 22 ms median spacing,
and 30–31 ms maximum observed spacing. It does not satisfy any acoustic
acceptance criterion. Diagnostic automated tests validate duration selection/
propagation, update aggregation, cancellation, failure recovery, queue
replacement, repeat trials, and concurrency guards; they do not establish
real-device or listening results.

#### Decision criteria and reporting

Acoustic acceptance requires no transition-attributable clicks, pops, gaps,
sudden volume jumps/severe dips, or severe/repeated midpoint excursion; at
least 90% of completed trials must score 4 or 5 for both smoothness and
loudness continuity; and no individual trial may have a clearly unacceptable
artifact. Any severe artifact blocks a pass until reproduced, explained, or
fixed and retested. Report completed trial and listener counts and retain raw
notes. These are practical listening criteria, not laboratory measurements.

Operational acceptance requires each supported run to end on the expected
queue item with one queue-owned playing deck; cancellation, errors, and
interruptions must not leave stale or unintentionally playing decks; and
repeated transitions must not duplicate, skip, or reorder queue advancement.
Report requested versus actual duration and command cadence separately from
acoustic findings. If evidence is insufficient, classify the result as
inconclusive.

Final recommendation must be exactly one of:

1. **Retain `just_audio` for the next AutoMix milestone** only with adequate
   documented acoustic and operational evidence.
2. **Investigate a native mixer** only if reproducible audible artifacts or
   backend limitations prevent acceptance. Propose a bounded investigation;
   do not implement or select a native engine during C.1.
3. **Inconclusive; repeat validation** if required listening or device
   coverage is incomplete.

### Milestone D — Analysis and persistence

1. Separate declared metadata (such as an embedded BPM tag) from measured
   analysis, with explicit confidence and analysis version.
2. Reuse the existing `TrackAnalysis` table in
   `lib/features/library/data/tone_database.dart` if its fields and migration
   behavior are sufficient. Inspect and update
   `lib/features/library/data/tone_database.g.dart` through the repository's
   Drift generation workflow only if the schema changes.
3. Add a narrow analysis repository to
   `lib/features/library/data/library_repository.dart` (or a feature-owned
   analysis repository if that better respects its boundary). Do not alter the
   queue schema for analysis results.
4. Persist BPM/key/energy or additional measurements only when an actual,
   tested analyzer supplies them. Store confidence, source, timestamp, and
   analyzer version; absent or low-confidence values remain unknown.
5. Run Drift migration, repository, and upgrade tests. Analysis must run
   asynchronously and never delay playback.

### Milestone E — Planning and controller integration

Feed available track evidence into `AutoMixController` and persist settings
only after choosing a repository that fits the existing preference patterns.
Do not force beat matching, harmonic mixing, tempo changes, EQ, or loudness
claims without the corresponding reliable inputs and engine capabilities.
Test planner edge cases independently and controller/backend coordination with
test doubles confined to tests.

### Milestone F — UI and release qualification

Only after functional engine integration, add controls to
`lib/features/settings/you_screen.dart` or the appropriate player/settings
surface and transition status to `lib/features/player/mini_player.dart` or
Now Playing. Preserve existing controls and ordinary playback. Add no UI that
suggests unsupported functions.

Validate foreground/background playback, lock screen, audio focus,
interruptions, Bluetooth/device route changes, source failures, repeated deck
load/unload, and resource use on real devices. Add iOS configuration only if
iOS playback is included in the qualified scope. Do not alter native audio
configuration before that scope and implementation exist.

## Database and dependency decisions

Milestone A needs no database changes: settings are in-memory, track evidence
is supplied by callers, and plans are ephemeral. The existing Drift schema
already defines a `TrackAnalysis` table; the analysis repository is not yet
wired to playback. Reuse it after inspecting migration compatibility rather
than creating a duplicate table. No package dependency is justified for the
pure-Dart foundation, so `pubspec.yaml` and `pubspec.lock` are unchanged.

## Validation strategy

- Pure unit tests cover planner confidence and fallback behavior, reliable
  BPM matching and mismatch at the 5% boundary, invalid/non-finite BPM,
  profile style/duration selection, configured duration limits, short-track
  clamping, and input validation.
- Run `flutter test test/auto_mix/transition_planner_test.dart` plus relevant
  player/library regression tests, then `flutter analyze`.
- Add database migration/repository tests only when persistence is changed.
- Add backend contract tests and real-device integration/performance tests
  before claiming gapless or synchronized playback.
- Unit tests do not establish audible quality, sample accuracy, clipping
  protection, battery cost, or lifecycle reliability.
