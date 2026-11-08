# ADR 0003: Retain the just_audio and audio_service Playback Stack

**Status:** Accepted  
**Date:** 2026-11-05

## Context

Phase 4 requires dependable foreground/background playback, media controls,
audio focus, interruption handling, and restoration across app restarts. Tone
already uses `just_audio` for decoding/transport and `audio_service` for the
Android media playback service and MediaSession.

## Decision

Keep the existing playback stack. Android declares the audio_service
`AudioService` as a `mediaPlayback` foreground service with the corresponding
foreground-service permissions and media-button receiver. Playback commands
and queue state continue through `AudioHandler`; audio sources stay in the
just_audio players.

Configure the shared audio session for music and pause when Android focus is
ducked. The handler requests focus before playback, releases it on ordinary
pause/stop, pauses on interruption and noisy-route events, and resumes only
when it had been playing before a transient interruption. Playback queue,
current track, position, repeat mode, and shuffle mode are retained locally
for restoration. Do not request notification permission solely for media
controls: Android media-session notifications are exempt from the
`POST_NOTIFICATIONS` runtime permission.

## Consequences

- Keep just_audio and audio_service integration as the supported transport and
  Android media-session boundary; no alternative engine is justified.
- Removing the app activity from recents does not stop service-owned playback.
- Restoration is user-safe: the queue and position are loaded, but playback
  does not start unexpectedly after a process restart.
- Automated tests and APK builds validate application behavior/configuration;
  they do not prove physical-device route changes, focus, Bluetooth controls,
  or process-death behavior. Those checks remain part of the device matrix.
