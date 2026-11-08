# ADR 0001: Retain feature-first structure and isolate platform data

- **Status:** Accepted
- **Date:** 2026-11-05
- **Scope:** Initial Phase 2 architecture work

## Context

Tone already has working feature areas for home, search, library, mixes,
playback, downloads, settings, and shell composition. A wholesale move to a
new `core/audio/database/network/...` tree would add churn without resolving
current cross-layer coupling.

The library feature also owned Android method-channel calls for scanning,
folder grants, and imported metadata, making platform access harder to test
without running the Android implementation.

## Decision

Retain the feature-first directory structure. Keep `AudioHandler` as the
standard playback transport and queue boundary.

Define `LibraryPlatformDataSource` with a
`MethodChannelLibraryPlatformDataSource` Android adapter for library scan,
folder, and imported-metadata operations. Create that adapter at
`MeloServices` composition and retain method-channel payloads.

Do not move audio-engine internals or change the native channel protocol in
this step.

## Consequences

- Library platform operations can be tested independently from
  `MusicLibrary`; lyrics, waveform, and artwork still use the shared channel
  directly and remain extraction candidates.
- The audio handler continues to own the current engine and AudioService
  integration; this is not yet a full engine/adapter separation.
- Library persistence and Android channel access remain coupled and require
  subsequent, separately tested boundaries.
