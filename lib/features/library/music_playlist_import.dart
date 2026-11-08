import 'package:path/path.dart' as p;
import 'package:melo_player/features/library/imported_track.dart';

class MusicPlaylistEntry {
  const MusicPlaylistEntry({
    required this.path,
    this.title,
    this.artist,
    this.durationSeconds,
  });

  final String path;
  final String? title;
  final String? artist;
  final int? durationSeconds;
}

class MusicPlaylistImport {
  const MusicPlaylistImport._();

  static List<String> parseM3u(String contents) =>
      parseM3uEntries(contents)
          .map((entry) => entry.path)
          .toList(growable: false);

  static List<ImportedTrack> resolveEntries(
    Iterable<String> entries,
    Iterable<ImportedTrack> tracks,
  ) => resolvePlaylistEntries(
    entries.map((entry) => MusicPlaylistEntry(path: entry)),
    tracks,
  );

  static List<MusicPlaylistEntry> parseM3uEntries(String contents) {
    final lines = contents
        .replaceFirst('\uFEFF', '')
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim());
    final entries = <MusicPlaylistEntry>[];
    String? title;
    String? artist;
    int? durationSeconds;
    for (final line in lines) {
      if (line.isEmpty) continue;
      if (line.startsWith('#EXTINF:')) {
        final comma = line.indexOf(',');
        final durationText = line.substring(8, comma < 0 ? line.length : comma);
        final parsedDuration = int.tryParse(durationText);
        durationSeconds = parsedDuration != null && parsedDuration > 0
            ? parsedDuration
            : null;
        final label = comma < 0 ? null : line.substring(comma + 1).trim();
        final separatorMatch = label == null
            ? null
            : RegExp(r'\s[-\u2013\u2014]\s').firstMatch(label);
        final separator = separatorMatch?.start ?? -1;
        if (label != null && separator > 0) {
          artist = label.substring(0, separator).trim();
          title = label.substring(separatorMatch!.end).trim();
        } else {
          title = label;
          artist = null;
        }
        continue;
      }
      if (line.startsWith('#')) continue;
      entries.add(
        MusicPlaylistEntry(
          path: line,
          title: title,
          artist: artist,
          durationSeconds: durationSeconds,
        ),
      );
      title = null;
      artist = null;
      durationSeconds = null;
    }
    return List.unmodifiable(entries);
  }

  static List<ImportedTrack> resolvePlaylistEntries(
    Iterable<MusicPlaylistEntry> entries,
    Iterable<ImportedTrack> tracks,
  ) {
    final availableTracks = tracks
        .where((track) => track.isAvailable)
        .toList(growable: false);
    final tracksByPathSuffix = <String, List<ImportedTrack>>{};
    final tracksByAlias = <String, List<ImportedTrack>>{};
    void indexTrack(
      Map<String, List<ImportedTrack>> index,
      String key,
      ImportedTrack track,
    ) {
      if (key.isEmpty) return;
      index.putIfAbsent(key, () => []).add(track);
    }

    for (final track in availableTracks) {
      final pathParts = _normalizePath(track.path)
          .split('/')
          .where((part) => part.isNotEmpty)
          .toList(growable: false);
      for (var start = 0; start < pathParts.length; start++) {
        indexTrack(tracksByPathSuffix, pathParts.skip(start).join('/'), track);
      }
      for (final alias in _trackAliases(track)) {
        indexTrack(tracksByAlias, alias, track);
      }
    }
    final resolved = <ImportedTrack>[];
    final includedIds = <String>{};

    for (final entry in entries) {
      final normalizedEntry = _normalizePath(entry.path);
      if (normalizedEntry.isEmpty) continue;

      final entryUri = Uri.tryParse(entry.path);
      final isRemote =
          entryUri?.scheme == 'http' || entryUri?.scheme == 'https';
      final pathKey = normalizedEntry.replaceFirst(RegExp(r'^/+'), '');
      final pathMatches = isRemote
          ? const <ImportedTrack>[]
          : tracksByPathSuffix[pathKey] ?? const [];
      final entryAliases = {
        if (!isRemote) _normalizeTrackName(p.posix.basename(normalizedEntry)),
        if (entry.title != null) _normalizeTrackName(entry.title!),
      }..remove('');
      final aliasCandidates = <String, ImportedTrack>{};
      for (final alias in entryAliases) {
        for (final track in tracksByAlias[alias] ?? const []) {
          aliasCandidates.putIfAbsent(track.id, () => track);
        }
      }
      final aliasMatches = aliasCandidates.values
          .where((track) {
            if (entry.artist != null &&
                _normalizeTrackName(entry.artist!) !=
                    _normalizeTrackName(track.artist)) {
              return false;
            }
            final seconds = entry.durationSeconds;
            if (seconds != null &&
                track.durationMs != null &&
                (track.durationMs! / 1000 - seconds).abs() > 3) {
              return false;
            }
            return true;
          })
          .toList(growable: false);
      final candidates = pathMatches.length == 1 ? pathMatches : aliasMatches;
      final match = candidates.length == 1 ? candidates.single : null;

      if (match != null && match.isAvailable && includedIds.add(match.id)) {
        resolved.add(match);
      }
    }

    return List.unmodifiable(resolved);
  }

  static Set<String> _trackAliases(ImportedTrack track) {
    final pathUri = Uri.tryParse(track.path);
    return {
      _normalizeTrackName(track.sourceName ?? ''),
      _normalizeTrackName(track.title),
      if (pathUri == null || !pathUri.hasScheme)
        _normalizeTrackName(p.posix.basename(_normalizePath(track.path))),
    }..remove('');
  }

  static String _normalizeTrackName(String value) {
    final basename = p.posix.basename(value.trim().replaceAll('\\', '/'));
    final withoutExtension = basename.replaceFirst(
      RegExp(r'\.[a-z0-9]{2,5}$', caseSensitive: false),
      '',
    );
    return withoutExtension
        .replaceAll('&', ' and ')
        .replaceAll(RegExp(r'[\s._-]+'), ' ')
        .trim()
        .toLowerCase();
  }

  static String _normalizePath(String value) {
    var path = value.trim().replaceAll('\\', '/');
    final uri = Uri.tryParse(path);
    if (uri != null && uri.scheme == 'file') {
      try {
        path = uri.toFilePath().replaceAll('\\', '/');
      } on FormatException {
        path = uri.path;
      } on ArgumentError {
        path = uri.path;
      }
    } else {
      try {
        path = Uri.decodeComponent(path);
      } on FormatException {
        // Some playlist producers leave literal percent characters unescaped.
      } on ArgumentError {
        // Some playlist producers leave literal percent characters unescaped.
      }
    }
    return p.posix.normalize(path).replaceFirst(RegExp(r'^\./'), '');
  }
}
