# ADR 0007: Persisted audio profile and supported EQ

**Status:** Accepted  
**Date:** 2026-03-16

## Context

Tone needs listener-controlled EQ without claiming output capabilities the
current Android playback path does not provide.

## Decision

- Add a typed, strictly validated `AudioProfile` persisted in
  `SharedPreferences`, matching the existing local sound-setting boundary.
- Expose only equalizer controls supported by the active Android playback
  route.
- Keep loudness normalization unavailable when its analysis inputs are not
  present; do not infer loudness from unrelated track metadata.
- Report platform capabilities explicitly. Do not offer balance, output
  selection, headphone profiles, ReplayGain/LUFS labels, or bit-perfect /
  universal Hi-Res claims without a verified end-to-end implementation.

## Consequences

- Unsupported routes remain unaltered and report the limitation.
- Output routing, balance, headphone Auto-EQ, ReplayGain metadata ingestion,
  a true peak limiter, and codec/output fidelity measurement remain deferred.
- Unit tests cover profile bounds, serialization, and capability contracts.
  Android device tests must still establish audible EQ behavior, route
  compatibility, clipping, CPU, and battery impact before broader quality
  claims.
