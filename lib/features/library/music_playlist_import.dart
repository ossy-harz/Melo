import 'package:path/path.dart' as p;
import 'package:melo_player/features/library/imported_track.dart';
import 'package:melo_player/features/sources/multi_lyrics_provider.dart';

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
    Iterable<ImportedTrack> tracks, {
    String? baseDir,
  }) => resolvePlaylistEntries(
    entries.map((entry) => MusicPlaylistEntry(path: entry)),
    tracks,
    baseDir: baseDir,
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
    Iterable<ImportedTrack> tracks, {
    String? baseDir,
    bool preserveRemoteStreams = false,
  }) {
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
      final lower = key.toLowerCase();
      if (lower != key) {
        index.putIfAbsent(lower, () => []).add(track);
      }
    }

    for (final track in availableTracks) {
      final normalizedTrackPath = _normalizePath(track.path);
      final pathParts = normalizedTrackPath
          .split('/')
          .where((part) => part.isNotEmpty)
          .toList(growable: false);
      for (var start = 0; start < pathParts.length; start++) {
        indexTrack(tracksByPathSuffix, pathParts.skip(start).join('/'), track);
      }
      // Also index Android storage mount aliases
      if (normalizedTrackPath.startsWith('storage/emulated/0/')) {
        final alt = normalizedTrackPath.replaceFirst('storage/emulated/0/', 'sdcard/');
        indexTrack(tracksByPathSuffix, alt, track);
      } else if (normalizedTrackPath.startsWith('sdcard/')) {
        final alt = normalizedTrackPath.replaceFirst('sdcard/', 'storage/emulated/0/');
        indexTrack(tracksByPathSuffix, alt, track);
      }

      for (final alias in _trackAliases(track)) {
        indexTrack(tracksByAlias, alias, track);
      }
    }

    final resolved = <ImportedTrack>[];
    final includedIds = <String>{};

    for (final entry in entries) {
      var entryPath = entry.path;
      if (baseDir != null &&
          !entryPath.startsWith('/') &&
          !entryPath.startsWith('\\') &&
          !entryPath.contains('://') &&
          !RegExp(r'^[a-zA-Z]:').hasMatch(entryPath)) {
        entryPath = p.posix.join(_normalizePath(baseDir), _normalizePath(entryPath));
      }

      final normalizedEntry = _normalizePath(entryPath);
      if (normalizedEntry.isEmpty) continue;

      final entryUri = Uri.tryParse(entry.path);
      final isRemote =
          entryUri?.scheme == 'http' || entryUri?.scheme == 'https';

      final pathKey = normalizedEntry.replaceFirst(RegExp(r'^/+'), '');
      final lowerPathKey = pathKey.toLowerCase();
      final pathMatches = isRemote
          ? const <ImportedTrack>[]
          : (tracksByPathSuffix[pathKey] ??
              tracksByPathSuffix[lowerPathKey] ??
              (pathKey.startsWith('storage/emulated/0/')
                  ? tracksByPathSuffix[pathKey.replaceFirst('storage/emulated/0/', 'sdcard/')]
                  : (pathKey.startsWith('sdcard/')
                      ? tracksByPathSuffix[pathKey.replaceFirst('sdcard/', 'storage/emulated/0/')]
                      : null)) ??
              const <ImportedTrack>[]);

      // Extract inferred artist & title from entry filename if missing from #EXTINF
      var effectiveTitle = entry.title;
      var effectiveArtist = entry.artist;
      if (effectiveTitle == null && !isRemote) {
        final base = p.posix.basenameWithoutExtension(normalizedEntry);
        final cleanBase = _stripTrackPrefix(base);
        final sepMatch = RegExp(r'\s[-\u2013\u2014]\s').firstMatch(cleanBase);
        if (sepMatch != null && sepMatch.start > 0) {
          effectiveArtist ??= cleanBase.substring(0, sepMatch.start).trim();
          effectiveTitle = cleanBase.substring(sepMatch.end).trim();
        } else {
          effectiveTitle = cleanBase;
        }
      }

      final simplifiedTitle = effectiveTitle != null
          ? MornyeLyricsMatching.simplifyTrack(effectiveTitle)
          : null;
      final rawBasename = p.posix.basename(normalizedEntry);
      final cleanBasename = _stripTrackPrefix(rawBasename);

      final entryAliases = {
        if (!isRemote) ...[
          _normalizeTrackName(rawBasename),
          _normalizeTrackName(cleanBasename),
        ],
        if (effectiveTitle != null) ...[
          _normalizeTrackName(effectiveTitle),
          _normalizeTrackName(_stripTrackPrefix(effectiveTitle)),
        ],
        if (simplifiedTitle != null) _normalizeTrackName(simplifiedTitle),
        if (effectiveArtist != null && effectiveTitle != null) ...[
          _normalizeTrackName('$effectiveArtist $effectiveTitle'),
          _normalizeTrackName('$effectiveTitle $effectiveArtist'),
          _normalizeTrackName('${MornyeLyricsMatching.primaryArtist(effectiveArtist)} $simplifiedTitle'),
          _normalizeTrackName('$simplifiedTitle ${MornyeLyricsMatching.primaryArtist(effectiveArtist)}'),
        ],
      }..remove('');

      final aliasCandidates = <String, ImportedTrack>{};
      for (final alias in entryAliases) {
        for (final track in tracksByAlias[alias] ?? const <ImportedTrack>[]) {
          aliasCandidates.putIfAbsent(track.id, () => track);
        }
      }

      // Collect all candidate matches
      final candidates = <ImportedTrack>{
        ...pathMatches,
        ...aliasCandidates.values,
      };

      // Preserve remote HTTP/HTTPS streaming entries directly if requested
      if (preserveRemoteStreams && isRemote && candidates.isEmpty) {
        final remoteTrack = ImportedTrack(
          id: entry.path,
          path: entry.path,
          title: effectiveTitle ?? p.posix.basenameWithoutExtension(entry.path),
          artist: effectiveArtist ?? 'Streaming Audio',
          album: 'Imported Playlist',
          durationMs: entry.durationSeconds != null ? entry.durationSeconds! * 1000 : null,
          isDeviceMedia: false,
          isAvailable: true,
          sourceProvider: 'Stream',
        );
        if (includedIds.add(remoteTrack.id)) {
          resolved.add(remoteTrack);
        }
        continue;
      }

      if (candidates.isEmpty) continue;

      // Ambiguity check: if ONLY bare filename was provided without metadata or folder,
      // and multiple different files match, do not arbitrarily guess.
      if (entry.title == null &&
          entry.artist == null &&
          entry.durationSeconds == null &&
          !normalizedEntry.contains('/') &&
          pathMatches.length > 1) {
        continue;
      }

      // Score each candidate to pick the absolute best match
      ImportedTrack? bestMatch;
      var bestScore = -1000.0;

      for (final candidate in candidates) {
        var score = 0.0;
        final normCandPath = _normalizePath(candidate.path);

        // Path / Filename scoring
        if (!isRemote) {
          if (normCandPath == normalizedEntry ||
              normCandPath.endsWith('/$pathKey') ||
              normCandPath == pathKey) {
            score += 500;
          } else if (normCandPath.toLowerCase() == normalizedEntry.toLowerCase() ||
              normCandPath.toLowerCase().endsWith('/$lowerPathKey')) {
            score += 400;
          } else if (pathMatches.contains(candidate)) {
            score += 250;
          }

          final candBasename = _normalizeTrackName(p.posix.basename(normCandPath));
          final entryBasename = _normalizeTrackName(p.posix.basename(normalizedEntry));
          if (candBasename == entryBasename && candBasename.isNotEmpty) {
            score += 150;
          } else if (_stripTrackPrefix(candBasename) == _stripTrackPrefix(entryBasename)) {
            score += 140;
          }
        }

        // Title scoring
        final activeTitle = effectiveTitle ?? entry.title;
        if (activeTitle != null) {
          final entryT = _normalizeTrackName(activeTitle);
          final candT = _normalizeTrackName(candidate.title);
          if (entryT == candT) {
            score += 250;
          } else if (MornyeLyricsMatching.titlesMatch(candidate.title, activeTitle)) {
            score += 180;
          } else if (_stripTrackPrefix(entryT) == _stripTrackPrefix(candT)) {
            score += 170;
          } else if (entryT.contains(candT) || candT.contains(entryT)) {
            score += 90;
          }
        }

        // Artist scoring
        final activeArtist = effectiveArtist ?? entry.artist;
        if (activeArtist != null) {
          final entryA = _normalizeTrackName(activeArtist);
          final candA = _normalizeTrackName(candidate.artist);
          if (entryA == candA) {
            score += 200;
          } else if (MornyeLyricsMatching.artistsMatch(candidate.artist, activeArtist)) {
            score += 160;
          } else if (MornyeLyricsMatching.primaryArtist(candidate.artist).toLowerCase() ==
              MornyeLyricsMatching.primaryArtist(activeArtist).toLowerCase()) {
            score += 130;
          } else if (entryA.contains(candA) || candA.contains(entryA)) {
            score += 80;
          } else if (candA.isNotEmpty && candA != 'unknown artist') {
            // Strong penalty only if artists clearly conflict
            score -= 100;
          }
        }

        // Duration scoring
        if (entry.durationSeconds != null && candidate.durationMs != null) {
          final candSec = candidate.durationMs! / 1000.0;
          final diff = (candSec - entry.durationSeconds!).abs();
          if (diff <= 2.5) {
            score += 90;
          } else if (diff <= 7.0) {
            score += 60;
          } else if (diff <= 15.0) {
            score += 30;
          } else if (diff > 45.0) {
            score -= 50;
          }
        }

        if (candidate.isAvailable) score += 20;

        if (score > bestScore) {
          bestScore = score;
          bestMatch = candidate;
        }
      }

      if (bestMatch != null && bestScore > 0) {
        if (bestMatch.isAvailable && includedIds.add(bestMatch.id)) {
          resolved.add(bestMatch);
        }
      }
    }

    return List.unmodifiable(resolved);
  }

  static String _stripTrackPrefix(String value) {
    return value
        .replaceFirst(RegExp(r'^\s*([a-zA-Z]?\d{1,3}[\s._-]+|\(\d{1,3}\)\s*)'), '')
        .trim();
  }

  static Set<String> _trackAliases(ImportedTrack track) {
    final pathUri = Uri.tryParse(track.path);
    final simplifiedTitle = MornyeLyricsMatching.simplifyTrack(track.title);
    final rawBasename = p.posix.basename(_normalizePath(track.path));
    final cleanBasename = _stripTrackPrefix(rawBasename);
    final primaryArt = MornyeLyricsMatching.primaryArtist(track.artist);

    final aliases = <String>{
      _normalizeTrackName(track.sourceName ?? ''),
      _normalizeTrackName(track.title),
      _normalizeTrackName(simplifiedTitle),
      _normalizeTrackName(_stripTrackPrefix(track.title)),
      if (pathUri == null || !pathUri.hasScheme) ...[
        _normalizeTrackName(rawBasename),
        _normalizeTrackName(cleanBasename),
      ],
      if (track.artist.isNotEmpty && track.artist.toLowerCase() != 'unknown artist') ...[
        _normalizeTrackName('${track.artist} ${track.title}'),
        _normalizeTrackName('${track.title} ${track.artist}'),
        _normalizeTrackName('$primaryArt $simplifiedTitle'),
        _normalizeTrackName('$simplifiedTitle $primaryArt'),
        _normalizeTrackName('$primaryArt ${_stripTrackPrefix(track.title)}'),
      ],
    };
    aliases.remove('');
    return aliases;
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

  static String _safeDecode(String input) {
    try {
      return Uri.decodeComponent(input);
    } catch (_) {
      return input.replaceAllMapped(RegExp(r'%([0-9a-fA-F]{2})'), (match) {
        try {
          final charCode = int.parse(match.group(1)!, radix: 16);
          return String.fromCharCode(charCode);
        } catch (_) {
          return match.group(0)!;
        }
      });
    }
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
      path = _safeDecode(path);
    }
    return p.posix.normalize(path).replaceFirst(RegExp(r'^\./'), '');
  }
}
