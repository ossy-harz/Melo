# Tone Design System

**Direction:** Dark-first, artwork-led, precise and calm.  
**Platform:** Android first; follow platform accessibility and navigation
conventions.  
**Source of truth for current Flutter tokens:** `lib/app/melo_theme.dart`,
`tone_palette.dart`, `tone_glass.dart`, and `tone_appearance.dart`.

This document records current values and product intent. A value marked
**proposed** is a design standard, not a claim that a centralized token or
component already exists in code. Product scope and screen behavior are in
[PRD.md](./PRD.md).

## 1. Visual principles

- Use deep near-black/graphite as the default listening environment and
  restrained cherry red for identity, selection, and important actions.
- Let album art provide character. Artwork-derived color may tint a contained
  surface, but must not reduce text/control contrast or wash out the whole UI.
- Keep information hierarchy clear: track identity and playback state before
  decoration; essential transport before secondary actions.
- Prefer a few deliberate surfaces over nested cards, persistent blur, or
  decorative effects everywhere.
- Use opaque or tinted surfaces by default; backdrop blur is opt-in because it
  can increase GPU cost during scrolling and playback.
- Reserve low-radius blur for small, fixed player/navigation surfaces. Keep
  scrolling track lists opaque, and cap blur strength to bound compositing cost.
- Use motion to communicate state and navigation—not as
  continuous ambient activity.
- Retain the optional light theme for listener choice and accessibility. Dark
  is the product default, and the listening/player surfaces remain deep dark
  across shell appearance choices so Tone's listening identity stays coherent.

## 2. Color tokens

Values below are the current constants or theme values in
`lib/app/melo_theme.dart` unless labeled proposed.

### Brand and player

| Token | Value | Use |
|---|---|---|
| `ink` | `#1A1114` | Light-theme primary text |
| `mutedInk` | `#6F5F66` | Light-theme secondary text |
| `paper` | `#FAF6F7` | Warm light-theme background |
| `card` | `#FFFFFF` | Light-theme card |
| `cherry` | `#FA243C` | Brand accent |
| `plum` | `#FA243C` | Light-theme primary |
| `ember` | `#FA243C` | Dark-theme primary |
| `cherrySoft` | `#FF8997` | Soft accent on dark surfaces |
| `cherryDeep` | `#5E0A19` | Deep accent surface |
| `amoled` | `#000000` | True-black surface where appropriate |
| `playerBackdrop` | `#000000` | Pure-black player backdrop |
| `playerText` | `#FFFFFF` | Player primary text |
| `playerMuted` | `#A1A1A6` | Player secondary text |
| `shell` | `#000000` | Main dark app surface |
| `shellRaised` | `#111111` | Raised dark app surface |

### Theme surfaces and effects

| Token | Value | Use |
|---|---|---|
| Dark surface containers | `#0B0B0B`, `#111111`, `#181818`, `#202020`, `#292929` | Ordered Material 3 surface hierarchy |
| Dark outline | `#5A5A5A` | Borders and focus affordance |
| Dark outline variant | `#2D2D2D` | Subtle separators |
| Glass tint | `#14FFFFFF` | Restrained translucent surface |
| Glass border | `#2EFFFFFF` | Glass edge |
| Glass shadow | `#A6000000` | Dark-surface shadow color |

Color pairings must be checked for text and control contrast in actual UI
states; the presence of a token does not imply every pairing is accessible.
Selection, error, disabled, focus, and progress states must remain
distinguishable without color alone.

## 3. Typography

**Family:** Plus Jakarta Sans, bundled in `assets/fonts/`. Use the theme text
styles instead of screen-specific font sizing wherever possible.

| Role | Current size / weight |
|---|---|
| Display large / medium / small | 56 / 44 / 35 px, 800 |
| Headline large / medium / small | 31 / 26 / 22 px, 800 / 800 / 700 |
| Title large / medium / small | 19.5 / 16.5 / 14.5 px, 700 / 600 / 600 |
| Body large / medium / small | 15.5 / 14 / 12.5 px, 500 |
| Label large / medium / small | 14 / 12 / 11 px, 700 / 700 / 600 |

Preserve font scaling. Do not truncate essential track names, controls, error
recovery instructions, or lyrics solely to preserve a fixed-height layout.
Use uppercase/tracked labels sparingly; never use them for long instructions.

## 4. Spacing, shape, and layout

### Shape tokens in code

| Token | Value |
|---|---:|
| `MeloRadii.sm` | 12 px |
| `MeloRadii.md` | 16 px |
| `MeloRadii.lg` | 22 px |
| `MeloRadii.xl` | 28 px |
| `MeloRadii.pill` | 999 px |

### Spacing standard

**Proposed scale:** 4, 8, 12, 16, 24, 32, 40, 48 px. Use 4/8 for compact
control internals, 12/16 for related content, 24/32 for section separation,
and 40/48 for major screen margins or visual breathing room. This scale is
not yet a centralized Dart token; consolidate it only as touched surfaces
are updated.

Use comfortable responsive side insets rather than hard-coded narrow-screen
width assumptions. On tablets and landscape layouts, constrain reading/list
widths and use adaptive navigation; do not simply stretch phone artwork cards.
Minimum interactive target is 48 logical pixels where practical.

## 5. Elevation, artwork, and materials

- Prefer tonal surface separation and borders over heavy shadows.
- Current `MeloShadows.soft` and `MeloShadows.glow` are optional recipes;
  reserve glow for an active hero/play state, not every card.
- `MeloGlass` is an optional translucent/blurred surface. Use it selectively
  for player overlays or floating controls with an opaque/tinted fallback.
  Do not use blur as the only contrast treatment or on dense scrolling lists.
- `MeloGrain` is decorative and must be omitted or reduced when motion,
  rendering cost, or accessibility preferences require a simpler surface.
- `MeloPalette` derives a contained palette from album art and provides a
  deterministic fallback. Never make controls depend on extracted colors.
- Artwork loading must handle absent, malformed, or inaccessible art with a
  consistent placeholder and no layout shift that obscures transport.

### ColorOS 17 inspiration

Tone borrows the ColorOS 17 direction of responsive transitions, restrained
translucency, and progress that reacts to playback—not its operating-system
branding or a claim of equivalent rendering performance. Blur stays limited
to the fixed mini-player/navigation dock; library content remains
unblurred while scrolling.

Reference: [OPPO ColorOS 17](https://www.oppo.com/en/coloros17/) (accessed
2026-11-06).

## 6. Iconography and controls

- Use familiar Material Symbols through Flutter Material icons for standard
  actions (play, pause, skip, search, queue, navigation, settings).
- Keep icon style, stroke/weight, and container treatment consistent within a
  surface. Avoid mixing ornamental icon families.
- Icon-only actions require a semantic label/tooltip. Distinguish selected,
  disabled, loading, and destructive states.
- Primary actions use text plus icon when the action is not universally
  recognizable. Use confirmation for destructive collection/data removal.
- Sliders and waveforms expose accessible names, current values, and keyboard/
  assistive-technology adjustment where supported.

## 7. Motion and feedback

### Existing motion tokens

- `MeloMotion.fast`: 180 ms.
- `MeloMotion.slow`: 520 ms.
- `MeloMotion.emphasized`: cubic `(0.2, 0.9, 0.2, 1)`.
- `MeloMotion.respecting(context, duration)` reduces duration to zero when
  the OS requests reduced motion.

Use short, purposeful transitions for navigation, selection, reveal, and
state change. Avoid motion that delays access to controls. Waveform animation
is a visualization of playback state, not evidence of musical analysis.
Haptics and gestures remain optional and never replace visible controls.

## 8. Reusable component library

Use shared components rather than reproducing screen-specific styling.
Existing implementation names are listed as implementation references; many
are currently private or colocated in large screen files and are not yet a
formal, independently tested component package.

| Component | Purpose | Existing reference / guidance |
|---|---|---|
| App navigation | Three destinations and persistent player entry | `AppShell` in `features/shell/app_shell.dart`; preserve Home, Library, You. Home opens global Search; Library filters inline. |
| Section header | Consistent title, subtitle, and optional action | `_SectionHeader` in `features/home/home_screen.dart`; standardize label hierarchy. |
| Track row | Artwork, title, artist, source/availability, contextual actions | `_TrackList` in `features/library/library_screen.dart`; keep metadata secondary to title. |
| Album artwork | Shared artwork loading, clipping, and fallback | `AlbumArtwork` in `features/player/mini_player.dart`; used across Home, Library, and player. |
| Album/artist tile | Artwork-led browse item with readable metadata | Existing Home/Library cards; support variable text scale. |
| Primary/secondary action | High-contrast action with consistent size and state | Material 3 themed `FilledButton`, `OutlinedButton`, and `TextButton`. |
| Icon action | Accessible compact action | `IconButton` with tooltip/semantic label and visible state. |
| Surface/card | Group related content without visual nesting | Material `Card`; use `MeloGlass` only for intentional overlays. |
| Mini player | Active item and compact transport/entry | `MiniPlayer` in `features/player/mini_player.dart`; persistent when a media item exists. |
| Playback seek control | Seek with waveform when available; conventional slider fallback | `_PlaybackSeekBar` in `features/player/mini_player.dart`; never make seeking waveform-only. |
| Queue sheet | Current queue, selected item, track selection | `PlayerQueueSheet` in `features/player/player_queue_sheet.dart`; stream/state orchestration remains in Now Playing for this first extraction. |
| Empty/error/permission state | Explain what happened and provide next action | Reuse a consistent icon, concise explanation, and recovery action. Do not show success-shaped fallbacks. |
| Progress/cancellation | Communicate long scans/downloads and allow cancellation | Required for long-running work; scan progress/cancel is not complete. |
| Lyrics surface | Readable plain/synchronized lyrics | `_LyricsPeek` / `_FullLyricsSheet`; timing and unavailable state must remain clear. |

When extracting shared widgets, keep names and public contracts focused,
provide semantic labels and loading/error states, and add widget tests for
interaction and text scaling. Do not refactor all large screens solely to
match a folder diagram.

## 9. Screen composition guidance

### Home wireframe

```text
┌─────────────────────────────────────┐
│ tone.                         Search│  Brand + global search
│                                     │
│ Your listening                      │
│ A quick read of what you love/replay│
│ [♥ Favorites: first saved song]      │
│ [↻ Most played: top song + plays]   │
│                                     │
│ Your playlists                      │
│ [Playlist art + name] [Playlist …]  │  Only when the listener has lists
│                                     │
│ Picked for you                 ↻   │
│ One considered mix from your music │
│ ┌─────────────────────────────────┐ │
│ │ Featured artwork                │ │
│ │ Mood / artist / library source  │ │
│ │ Mix name       [Save] [Play mix]│ │
│ └─────────────────────────────────┘ │
│                                     │
│ Recently added                     │
│ [Album art] [Album art] [Album art] │
└─────────────────────────────────────┘
       Persistent mini-player + navigation
```

Home is Tone's discovery surface rather than an extra bottom-navigation tab.
The first compact row is grounded in the listener's own data: saved favorites
and the track with the highest recorded play count. User playlists appear only
when they exist. One large local recommendation follows; refresh rotates that
feature instead of stacking competing recommendation carousels. Recently added
remains a short artwork shelf. The mini-player owns current playback status and
controls, so Home does not repeat a Now Playing card.

Local artist radio begins with a rotating seed, then favors related songs
across different artists using shared genre family, tempo, favorites, and
listening counts. When useful metadata is missing, it makes a restrained local
discovery pass rather than claiming precise similarity. The station is limited
to playable local music, not represented as a remote or endless radio service.

M3U import resolves in confidence order: matching path, preserved source
filename, then playlist title/artist/duration metadata. Ambiguous matches are
not guessed. M3U `EXTINF` metadata is retained for matching, and unmatched
entries are reported without copying their audio.

### Research translated into Tone's layout

The inspiration sources inform information hierarchy, not a copied skin:

- [Spotify Your Library](https://support.spotify.com/us/article/your-library/)
  keeps saved songs separate from saved artists/albums and offers filtering.
- [Spotify Recents](https://support.spotify.com/us/article/recent-activity/)
  separates listening history from the queue and exposes a recent-song view.
- [Apple Music Replay](https://support.apple.com/en-us/109356) is a reference
  for making repeated listening visible as a listener-facing summary.
- [Dribbble music player concept](https://dribbble.com/shots/25878564-UI-UX-Design-Music-player-App-Design)
  and [Figma web-player concept](https://www.figma.com/community/file/1396367792083209260/music-player-web-ui-design-concept)
  suggest artwork-led home surfaces and clear library/radio/search groupings;
  these are design concepts, not evidence of tested product behavior.
- [VideoLAN's M3U description](https://wiki.videolan.org/M3U/) documents
  location-per-line playlists and comment lines, motivating path-first matching
  with metadata as a fallback for Android content URIs.

The shared Apple Music page was signed out and region-gated, so it only
supported a high-level navigation observation (Search/Home/New/Radio), not a
claim about personalized Home content.

- **Home:** treat this as a compact discovery surface, not a second player or
  navigation hub. The persistent mini-player owns current playback controls;
  app navigation owns destination switching. Show one rotating, library-aware
  “Picked for you” feature followed by recently added albums, with no stacked mood,
  artist-radio, and playlist recommendation sections. Keep recommendations
  local, explainable, available-only, and diverse; omit similar picks rather
  than filling space with near-duplicates.
- **Library:** keep only inline search and library ordering on the controls row.
  Include every track in the same searchable list; do not expose source or
  availability filters.
- **Glass surfaces:** reserve backdrop blur for a few bounded, fixed surfaces.
  Scrolling cards use translucent tint and borders without per-row blur.
- **Search/Library:** expose global Search from Home and use Library's inline
  field to filter the selected view. Make query and source scope visible; keep
  list rows scannable and virtualized; do not bury permission/source recovery.
- **Albums/Artists/Playlists:** artwork supports recognition but title,
  artist, count, and playback actions remain legible.
- **Now Playing:** artwork and left-aligned track identity lead; available
  audio-quality badges stay secondary; transport and seeking are always
  reachable; lyrics are a secondary layer. Keep waveform drawing bounded and
  avoid per-bar blur or continuously animated decoration.
- **Mini Player:** must not obscure app navigation or report stale playback
  state.
- **Queue:** pin the current item above an ordered Up Next list; support
  selecting, reordering, removing, and clearing upcoming tracks without
  allowing the current track to be removed.
- **Personal mixes:** show session length, picks, explanations, and
  remove/refresh affordances before playback starts.
- **Lyrics:** maintain contrast and line readability over artwork or glass;
  timed highlighting is supplementary.
- **Downloads:** show provider, permitted action, progress/cancel, license and
  imported destination.
- **Sound & playback/Settings:** group by user goal, state defaults and capability
  limitations, and explain effects of privacy/data operations.

## 10. Design quality checklist

- [ ] Dark theme is the default, using pure black, white, and `#FA243C` as the
      primary identity colors; verify legibility in bright and dim environments.
- [ ] Optional light/system appearance remains usable and does not change
      player controls unexpectedly.
- [ ] Core controls meet touch target, focus, label, and contrast needs.
- [ ] Screen-reader users can identify track, playback state, and seek value.
- [ ] Large text does not hide transport, dialogs, or recovery actions.
- [ ] Reduced motion disables/collapses nonessential transitions and
      visualization.
- [ ] Color is not the only signal for selected mode, error, or
      progress.
- [ ] Missing artwork, lyrics, metadata, analysis, permissions, and network
      each have intentional fallback states.
- [ ] Narrow, large-font, landscape, and tablet layouts are reviewed.
- [ ] Blur, grain, palette extraction, and animation do not interfere with
      scrolling, playback control, or thermal/battery behavior.

## 11. Design-system completion criteria

Phase 1 documents the palette, typography, shapes, spacing standard, motion,
navigation, and component inventory. Implementation is complete only as
shared Flutter tokens/components are adopted and verified incrementally,
with accessibility and widget coverage; this specification alone does not
claim that all screens already conform.
