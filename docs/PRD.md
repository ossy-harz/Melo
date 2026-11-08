# Tone Product Requirements

**Status:** Product direction approved; implementation is incremental.  
**Platform:** Android first, built with Flutter and native Android capabilities.  
**Product name:** Tone.  
**Tagline:** The art of uninterrupted listening.

This is the product source of truth. It describes the intended experience and
labels existing behavior separately from planned work; a requirement is not a
claim that the corresponding feature has shipped. The implementation sequence
and release gates remain in [PROJECT_PLAN.md](../PROJECT_PLAN.md).

## 1. Product vision

Tone is a premium, local-first music player that makes listening feel
continuous and intentional. Everyday playback must be excellent on its own.
When the listener chooses, Tone can generate an editable personal mix from
available local music and play it as a regular queue. AutoMix is an optional
two-deck transition prototype that automatically crossfades near the end of a
track and also provides a manual “Mix next” action. Its current trigger is
based on track duration rather than musical cue detection. Ordinary queue
advancement remains the fallback if a transition cannot run. Audio quality is
not yet qualified for release.

**Promise:** Personal music, ready to play.

**Product identity:** Performance-minded engineering, calm precision, and
artwork-led music design. Reliability and honest capability claims take
priority over effects or features that are not proven on real devices.

## 2. Target listeners and primary use cases

### Primary audience

- **Everyday music listeners** who want an attractive, dependable player for
  finding music, managing a personal library, and resuming playback easily.
- **Personal-library listeners** who own or control local audio files and want
  useful organization and offline access.

Tone is a balanced premium music player, not a DJ tool. Personal mixes are an
optional way to build a regular queue from the local library. Tone does not
require an account or a listening-history profile to play local music.

### Core use cases

1. Add or scan music, browse it, and play a chosen song or album.
2. Resume playback and control it from the player, queue, notification, or
   lock screen.
3. Generate and edit a personal mix, then play it as a regular queue.
4. Search for licensed downloadable music, understand its source and license,
   and import it only when the provider permits it.
5. Read available local or explicitly requested online lyrics and manage
   playback, appearance, privacy, and source settings.

## 3. Experience model

Personal mixes are ordinary editable queues, not a separate playback mode.

| Experience | Listener intent | Required behavior | Status in this repository |
|---|---|---|---|
| **Everyday playback** | “Play my music.” | Familiar library, search, queue, transport, resume, and dependable conventional playback. | Core screens and local playback exist; device lifecycle qualification remains open. |
| **Personal mixes** | “Make me a set.” | Generate an explainable local running order, let the listener edit it, and play it as a regular queue. | Local mix generation and queue playback exist; source recovery and listening review remain. |
| **AutoMix** | “Keep the music flowing.” | Plan optional transitions from available evidence; fall back to ordinary playback when evidence or engine support is insufficient. | Planner, dual-deck engine, and manually triggered stepped-gain transition exist. No musical analysis or automatic trigger/UI; audible fade quality and broader Android qualification remain. |

Generating or editing a mix must not start a network transfer. The listener
remains able to pause, skip, seek, and manage the ordinary playback queue.

## 4. Product principles and boundaries

1. **Playback before spectacle.** Visualizations never block transport or
   consume the audio path.
2. **Local-first and useful offline.** Internet discovery is optional; local
   playback does not depend on it.
3. **Listener control is explicit.** Explain mix selections, offer ordinary
   playback controls, and provide visible source and privacy choices.
4. **Be honest about analysis.** Distinguish embedded tags and waveform
   envelope cues from detected beats, key, mood, or musical structure.
5. **Authorize every source action.** Use documented provider flows and
   respect download and playback permissions. Never extract protected streams
   or imply a download right Tone does not have.
6. **Dependable across ordinary Android devices.** Fall back gracefully when
   DSP, metadata, artwork, permissions, or network access are unavailable.
7. **Private by default.** Process library-based mixes on-device. Send no
   listening history or telemetry by default.
8. **Accessible and calm.** Motion, color, gestures, and advanced controls
   supplement—not replace—readable text and accessible controls.

### Explicit non-goals for the initial product

- Requiring an account, cloud profile, or uploaded listening history.
- Unauthorised streaming, DRM circumvention, or scraping private APIs.
- Promising commercial streaming playback, offline prediction, NAS access,
  social listening, or podcast/video support before those are implemented and
  provider constraints are verified.
- Claiming beat/key/phrase detection or bit-perfect/Hi-Res output without
  measured evidence.
- Manual deck operation, or claims of beat synchronization, sample-accurate
  mixing, loudness leveling, or clipping protection before those capabilities
  are implemented and qualified.

## 5. Feature priorities

Priorities describe product sequencing; repository status is called out
separately so an existing prototype is not mistaken for a release-ready
feature.

| Priority | Feature set | Acceptance direction |
|---|---|---|
| **P0 — Foundation** | Local library, everyday playback, queue, Android media controls, accessible navigation, privacy/source clarity | A listener can add authorized local music, find and play it, operate playback outside the app UI, and recover from common unavailable-source errors. |
| **P1 — Personal mixes** | Explainable local mix generation, preview/edit, ordinary queue playback | A cold-start listener can make and edit a useful set; every pick is eligible and its reason is truthful. |
| **P1 — Product quality** | Accessibility, lifecycle/device validation, scan/source recovery, data migration, performance baselines | Quality gates in the implementation plan pass before broad release claims. |
| **P2 — Sound settings** | Optional audio-profile controls supported by the active playback route | The UI reflects real capabilities and unsupported processing can be bypassed safely. |
| **P2 — Authorized discovery** | Jamendo and other individually verified source integrations | Source, license, download eligibility, transfer state, and attribution are clear. Local playback remains independent. |
| **Later / gated** | Intelligent audio analysis, social sessions, history-based personalization, remote libraries, prediction, additional content types | Requires measurable quality, privacy, device, legal, or provider evidence before commitment. |

## 6. Navigation architecture

Keep three persistent top-level destinations. Now Playing is a full-screen
player, not a fourth destination. Queue, lyrics, album/artist detail, and
settings are contextual destinations or sheets.

```text
App
├── Home
│   ├── Continue listening ───────────────> Now Playing
│   ├── Make a mix ───────────────────────> Personal mix setup / preview
│   ├── Local mood mix / recent album ────> Queue → Now Playing
│   └── Browse shortcut ──────────────────> Library
├── Library
│   ├── Songs / Albums / Artists
│   ├── Playlists / Favorites
│   ├── Device / granted folders
│   └── Downloads
├── You
│   ├── Sound & playback
│   ├── Personal mixes
│   ├── Offline & data / Privacy
│   ├── Appearance
│   └── About

Home top-right action (not a navigation destination):
  Search
  ├── Local results ─────────────────────> Track / Album / Artist
  └── Authorized discovery ──────────────> Downloads

Library inline search filters the selected library view.

Persistent shell when a track is active:
  Mini Player → Now Playing → Queue / Lyrics
```

On wider screens, use adaptive navigation presentation without changing these
destinations or nesting. Back closes a sheet or returns from a detail/player
before leaving the selected top-level destination.

## 7. User journeys

### J1. First local play (Everyday)

1. Open Tone and understand that local playback works without an account.
2. Choose device scan or grant a music folder; understand what access is
   requested.
3. See scan/import progress and a useful empty, denied, or failed state.
4. Browse or search the resulting library and play a track.
5. Continue using mini-player, Now Playing, queue, and Android media controls.
6. If the source disappears, keep playlist/library metadata and offer a
   recovery action rather than silently deleting user data.

### J2. Build and play a personal mix

1. Choose Make a mix and select available mix preferences and session length.
2. Review picks, their available explanations, and actual session duration.
3. Remove or refresh picks before starting; favorites and exclusions remain
   under listener control.
4. Start the mix as a regular queue and use standard playback and queue
   controls to pause, skip, seek, or reorder tracks.

### J3. Find and save licensed music

1. Open authorized discovery and enter a search.
2. See provider/source identity and only see download actions when the
   provider explicitly permits the selected format.
3. Review progress, cancellation, failure, attribution/license information,
   and where the completed file is stored.
4. Play the imported track offline from the Tone library, subject to its
   source and license terms.

### J4. Find lyrics and manage preferences

1. View available local lyrics without leaving Now Playing.
2. If online lookup is off, see the provider/privacy explanation and opt in
   before any lookup; send only the metadata needed for matching.
3. Change appearance and audio preferences, or clear the relevant local
   personal data without deleting music or playlists.

## 8. Functional requirements

### Playback and queue

- **FR-PB-01 (P0):** Play, pause, seek, next, previous, shuffle, repeat, and
  queue supported local audio.
- **FR-PB-02 (P0):** Expose background playback and Android media controls,
  subject to OS permission and lifecycle behavior.
- **FR-PB-03 (P0):** Restore queue, active item, and position after a normal
  restart; handle missing sources without losing unrelated library data.
- **FR-PB-04 (P0):** Show meaningful loading, unsupported/unavailable source,
  permission, and recoverable error states.
- **FR-PB-05 (P0):** Add an available library track to the current queue
  without duplicating an existing entry; remove upcoming entries without
  interrupting or removing the active track.

### Library and sessions

- **FR-LIB-01 (P0):** Scan the Android media library and allow persistent,
  user-granted folder access; clearly distinguish device media from copied
  imports and provider downloads.
- **FR-LIB-02 (P0):** Browse and search songs, albums, artists, playlists, and
  favorites; support playlist create/edit/reorder/play.
- **FR-LIB-03 (P0):** Preserve metadata and user collections across scan
  failure, permission revocation, source loss, and restart, including the
  original media filename needed to reconcile external playlists with Android
  content URIs.
- **FR-LIB-04 (P1):** Search the full library by text without source or
  availability filters; prevent exact duplicate copied-file imports while
  preserving similar but distinct recordings for listener review.
- **FR-LIB-08 (P1):** Group likely duplicate recordings and offer a reversible
  smart selection that prioritizes available, favorited, frequently played,
  and better-tagged copies. Require review and confirmation before deleting
  selected files.
- **FR-LIB-05 (P1):** Import M3U/M3U8 playlists by linking matching available
  library tracks in listed order. Resolve paths first, then preserved source
  filenames and `EXTINF` title/artist/duration metadata; do not guess between
  ambiguous tracks, report unmatched entries, and never copy referenced audio.
- **FR-LIB-06 (P1):** Sort tracks by title, modification date, file size, or
  duration. Keep the default source scope implicit rather than presenting a
  redundant “All tracks” choice.
- **FR-LIB-07 (P1):** Delete a track's managed audio file only after explicit
  in-app confirmation. Shared Android media must use the platform's user
  authorization flow; bulk MediaStore cleanup requests authorization once for
  all selected copies. Canceling deletion leaves the tracks in Tone. Deleting a
  Tone import removes only Tone's private copy, not its selected original.
- **FR-MIX-01 (P1):** Generate an editable local mix from eligible,
  playable items using the requested duration and explicit listener controls.
- **FR-MIX-02 (P1):** Preview, remove, refresh, and play a generated mix as an
  ordinary queue; explain only signals actually used.
- **FR-MIX-03 (P1):** Make exclusions and favorites explicit and reversible.
- **FR-MIX-04 (P2):** Offer genre/tempo-based mix preferences only when the
  supporting metadata and meaning are clearly explained.

### Discovery, lyrics, and settings

- **FR-DISC-01 (P1):** Local discovery is based on available library metadata,
  favorites, and recorded play counts, and is clearly identified as local.
- **FR-DISC-04 (P1):** Surface local genre and mood mixes from embedded genre,
  tempo, favorites, and recorded plays. Describe these as local metadata-based
  groupings, not as human-validated emotion detection.
- **FR-DISC-03 (P1):** Make favorites and most-played tracks visible from Home;
  show saved playlists when present. Local artist radio starts from its named
  seed, favors related tracks across artists, and rotates on each start.
- **FR-DISC-02 (P2):** Remote sources use authorized APIs/flows and identify
  source, capabilities, rights, and data sent.
- **FR-LYR-01 (P1):** Show local lyrics when available; online lookup is
  optional, user-initiated, and disclosed.
- **FR-SET-01 (P0):** Expose appearance, playback, permissions/source,
  privacy, and app information in a predictable settings area.
- **FR-SET-02 (P1):** Clearing one category of local data must explain its
  effect and must not silently remove audio or playlists.

## 9. Non-functional requirements

- **Reliability:** Audio remains controlled outside the foreground screen.
  Initialization, interruption, route change, queue replacement, decoder
  error, and process restoration have explicit behavior and device evidence.
- **Performance:** Scanning, search, artwork, and waveform analysis must not
  block the UI or audio callback. Establish measured startup, memory, battery,
  scan, and interaction baselines before setting numeric release thresholds.
- **Audio safety:** Audio processing can be bypassed; normal playback does not
  depend on analysis or transition effects.
- **Privacy:** Local library and mix signals remain on-device by default.
  Network requests are initiated for a user-visible purpose and disclose the
  minimum metadata/query sent.
- **Accessibility:** All essential actions have labeled, focusable controls;
  no gesture, color, waveform, or motion animation is the sole source of
  meaning or interaction.
- **Compatibility:** Android is the release focus. Unsupported platform or
  device capabilities are guarded and communicate a useful fallback.
- **Maintainability:** Separate product UI, playback behavior, library
  persistence, and native platform responsibilities; use tested, forward-only
  data migrations when persistence changes.
- **Integrity:** Do not advertise a feature as available until its user path,
  failure path, tests, and supported-device behavior meet its acceptance
  criteria.

## 10. Screen specifications

“Exists” describes current repository surfaces, not release readiness.

| Screen | Purpose and required content | Primary actions and states | Current status |
|---|---|---|---|
| **Home** | A compact local discovery feed: favorites, most-played, saved playlists when present, one rotating local pick, and recent additions. | Play a favorite or playlist, open a local pick, browse/search; handle empty history, library, and unavailable artwork. | Listening history is recorded locally; Home surfaces favorites and play-count leaders without duplicating Now Playing controls. |
| **Search** | Search local title, artist, and album; clearly separate authorized-provider results. | Play local result, open album/artist, enter provider discovery; empty/loading/error states. | Exists; Jamendo discovery is an explicit separate flow. |
| **Library** | Organize songs, albums, artists, playlists, favorites, folders, and downloads. | Scan/import, search/filter/sort, confirmed file deletion, play/shuffle, playlist CRUD/reorder/import, source recovery; permission and empty states. | Date/size/duration refinement, sorting, and confirmed deletion exist; M3U/M3U8 import links available local tracks; scan progress/cancellation and recovery still require work. |
| **Albums** | Artwork-led album grid and focused album detail with ordered tracks. | Play, shuffle, play track; handle partial metadata and missing artwork. | Grid and album detail exist. |
| **Artists** | Browse artists and tracks grouped from available metadata; start a clearly local artist radio. | Open artist, play, start local radio; avoid implying a remote station or endless catalog. | Radio uses local genre-family/tempo matches, favorites and listening counts where available, diversifies across artists, and rotates its seed/order. |
| **Playlists** | Show user playlists and membership; clearly distinguish generated suggestions from saved lists. | Create, rename, delete, add/remove/reorder, play; empty and stale-source states. | User playlists and local suggestions exist. |
| **Now Playing** | Track identity/artwork, seekable position, transport, queue access, and optional lyrics. | Play/pause, seek, previous/next, shuffle/repeat, favorite, queue, lyrics; waveform failure falls back to seek. | Exists; Android waveform and lyrics support have platform limits. |
| **Mini Player** | Persistent compact active-track identity and essential play/pause/Now Playing entry. | Open full player; play/pause; absent when no active item. | Exists in app shell. |
| **Queue** | Ordered tracks, active item, source/availability where known. | Select item, inspect ordering; handle removed or unavailable sources. | Queue sheet exists; source-availability validation is incomplete. |
| **Lyrics** | Show local/authorized lyrics with line- or word-level timing only when supplied; distinguish timing precision. | Open/close, follow position; explicitly opt into remote lookup; unavailable/error state. | Local LRC/enhanced-LRC/plain text and optional LRCLIB support exist. |
| **Downloads** | Search authorized catalog; show provider identity, format, license, permission, and transfer state. | Search, download eligible tracks, cancel, open imported item; unavailable/network/error state. | Jamendo licensed-download flow exists; not a general download manager. |
| **Sound & playback** | Configure available audio-profile settings for the active playback route. | Configure implemented/capable controls; show when processing is unavailable. | Audio profile settings exist; advanced route-specific controls remain gated on support. |
| **Settings** | Appearance, privacy/data, offline/source permissions, playback, and About. | Change preference; clear data with consequences explained; recover access. | Partial settings exist; full storage, export, and permission-recovery UX is planned. |

## 11. Feature acceptance criteria

- **Everyday playback:** A listener can play, pause, seek, navigate, and use
  the queue from the UI and Android media controls. Track changes use ordinary
  playback. The path handles missing media and reports errors.
- **Library:** A failed or cancelled scan does not erase the last good library.
  Playlists/favorites survive restart and source loss; unavailable items are
  identified and recoverable.
- **Personal mixes:** A new user with no history can build a mix from eligible
  local tracks. Duration is truthful, picks are unique, exclusions are
  honored, explanations cite actual signals, and the preview can be edited.
- **Lyrics and downloads:** Online lookup is opt-in and disclose-before-send;
  licensed downloads are gated by provider authorization and show progress,
  cancellation, source, and license details.
- **Accessibility and design:** Core actions are usable with screen readers,
  larger text, reduced motion, and without color-only cues or gestures.

## 12. Phase 1 exit criteria

Phase 1 is complete when:

1. Product vision, audience, use cases, boundaries, and priorities are
   documented in this PRD.
2. Everyday playback and personal-mix behavior are explicit and match the
   current implementation.
3. Primary navigation, requested screens, and four key journeys are
   specified.
4. Functional/non-functional requirements and testable feature acceptance
   criteria exist.
5. Design tokens and reusable component guidance are recorded in
   [DESIGN_SYSTEM.md](./DESIGN_SYSTEM.md), with existing tokens separated from
   proposed standards.
6. README and implementation plan link to the specifications and no longer
   contradict approved product decisions.
