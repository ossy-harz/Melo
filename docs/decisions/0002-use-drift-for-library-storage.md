# ADR 0002: Use Drift for the Local Library Database

**Status:** Accepted  
**Date:** 2026-11-05

## Context

The local library had outgrown its `SharedPreferences` JSON records. Tracks,
playlists, favorites, playback queue, and current position were persisted as
separate values, so related updates could be interrupted independently.
Library search and grouping also operated over an in-memory collection.

The app must remain local-first, preserve existing installations, and support
large libraries without making platform method channels the persistence
contract.

## Decision

Use SQLite through Drift for library-owned persistent data. Keep
`MusicLibrary` as the feature-facing API and put database operations behind
`LibraryRepository`; `DriftLibraryRepository` is the production implementation.

The version-two schema includes tracks, artists, albums, folders, playlists and
ordered playlist membership, favorites, mix exclusions, playback queue/state,
playback history, track analysis, artwork cache metadata, downloads, historical
session records, user preferences, and audio profiles. Track search uses an
FTS5 index maintained by SQLite triggers. Foreign keys protect playlist,
favorite, exclusion, analysis, download, and historical session relationships
where deletion should cascade; playback history keeps a metadata snapshot so
it survives track removal.

On first open, legacy preferences are decoded and copied into the database in
one transaction. A database migration marker is committed only after the
track-count check succeeds. Legacy preference values are retained rather than
deleted. Malformed legacy data aborts the transaction and remains available
for diagnosis or recovery.

SQLite integrity is checked before library use. If `PRAGMA quick_check`
reports corruption, the app closes and quarantines the original database,
opens a fresh database, and retries the legacy-preference migration. It reports
the recovery and preserves the damaged file for manual recovery; it does not
silently overwrite the original. Recovery for failures that prevent opening
or checking the database, and automated corruption/upgrade tests, remain
follow-up work.

## Consequences

- Database writes for library records are transactional and use typed schema
  and migration tooling.
- Existing library APIs and the test-only preferences path remain compatible
  during the transition.
- Search results use token-prefix matching across title, artist, and album;
  this is intentionally indexed search rather than arbitrary substring search.
- The schema reserves tables for analysis, artwork caching, downloads, and
  historical session data; unused legacy tables remain for compatibility and
  do not imply that corresponding workflows are active.
- Schema changes must increment `schemaVersion` and add a forward migration.
  Migration tests must preserve data and exercise failure/restart behavior.
- `SharedPreferences` remains appropriate for small presentation settings;
  library entities and playback persistence belong in the repository.
