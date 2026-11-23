part of 'mini_player.dart';

Future<Map<String, Object?>?> _audioQualityFor(MediaItem item) {
  final extras = item.extras;
  if (extras != null && extras['mimeType'] != null) {
    final liveResult = Future<Map<String, Object?>?>.value({
      'mimeType': extras['mimeType'] as String?,
      'bitRate': extras['bitRate'] as num?,
      'sampleRate': extras['sampleRate'] as num?,
      'channelCount': extras['channelCount'] as num?,
    });
    _audioQualityCache[item.id] = liveResult;
    return liveResult;
  }
  return _audioQualityCache.putIfAbsent(item.id, () async {
    final isOnline =
        item.id.startsWith('youtube:') ||
        item.id.startsWith('spotify:') ||
        item.id.startsWith('http://') ||
        item.id.startsWith('https://') ||
        extras?['source'] == 'youtube' ||
        extras?['source'] == 'spotify' ||
        extras?['isLiveStream'] == true;
    final localPath = extras?['localPath'] as String?;
    if (isOnline && localPath == null) {
      final isFlac =
          extras?['quality'] == 'flacHiRes' ||
          item.title.contains('FLAC') ||
          (extras?['isLossless'] == true);
      return {
        'mimeType': isFlac ? 'audio/flac' : 'audio/mp4a-latm',
        'sampleRate': isFlac ? 48000 : 44100,
        'channelCount': 2,
        'bitRate': isFlac ? 1411200 : 320000,
      };
    }

    if (defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      return await _artworkChannel.invokeMapMethod<String, Object?>(
        'readAudioQuality',
        {'uri': localPath ?? item.id},
      );
    } catch (e) {
      debugPrint('Could not read audio quality: $e');
      return null;
    }
  });
}

Future<Map<String, Object?>?> _audioTagsFor(MediaItem item) =>
    _audioTagsCache.putIfAbsent(item.id, () async {
      final localPath = item.extras?['localPath'] as String?;
      final isOnline =
          localPath == null &&
          (item.id.startsWith('youtube:') ||
              item.id.startsWith('spotify:') ||
              item.id.startsWith('http://') ||
              item.id.startsWith('https://') ||
              item.extras?['source'] == 'youtube' ||
              item.extras?['source'] == 'spotify');
      if (isOnline) {
        return {
          'mimeType': item.extras?['mimeType'] ?? 'audio/opus',
          'sampleRate': item.extras?['sampleRate'] ?? 48000,
          'channelCount': item.extras?['channelCount'] ?? 2,
          'bitRate': item.extras?['bitRate'] ?? 256000,
          'title': item.title,
          'artist': item.artist,
          'album': item.album,
          'durationMs': item.duration?.inMilliseconds,
        };
      }

      if (defaultTargetPlatform != TargetPlatform.android) return null;
      try {
        return await _artworkChannel.invokeMapMethod<String, Object?>(
          'readLocalAudioMetadata',
          {'path': localPath ?? item.id, 'fallbackTitle': item.title},
        );
      } catch (e) {
        debugPrint('Could not read audio tags: $e');
        return null;
      }
    });

String _audioQualityLabel(Map<String, Object?> details) {
  final mimeType = (details['mimeType'] as String?)?.toLowerCase() ?? '';
  final path = (details['path'] as String? ?? '').toLowerCase();

  String codec;
  if (path.endsWith('.flac') || mimeType.contains('flac')) {
    codec = 'FLAC';
  } else if (path.endsWith('.alac') || mimeType.contains('alac')) {
    codec = 'ALAC';
  } else if (path.endsWith('.opus') || mimeType.contains('opus')) {
    codec = 'Opus';
  } else if (path.endsWith('.mp3') || mimeType.contains('mpeg') || mimeType.contains('mp3')) {
    codec = 'MP3';
  } else if (path.endsWith('.m4a') || path.endsWith('.aac') || mimeType.contains('aac') || mimeType.contains('mp4a')) {
    codec = 'AAC';
  } else if (path.endsWith('.wav') || mimeType.contains('wav')) {
    codec = 'WAV';
  } else if (mimeType.contains('pcm') || mimeType.contains('raw')) {
    codec = 'Lossless PCM';
  } else if (mimeType.isNotEmpty && mimeType.contains('/')) {
    codec = mimeType.substring(mimeType.indexOf('/') + 1).toUpperCase();
  } else {
    codec = 'AAC';
  }

  final sampleRate = (details['sampleRate'] as num?)?.toInt();
  final channels = (details['channelCount'] as num?)?.toInt();
  final bitRate = (details['bitRate'] as num?)?.toInt();

  return [
    codec,
    if (sampleRate != null && sampleRate > 0)
      '${(sampleRate / 1000).toStringAsFixed(sampleRate % 1000 == 0 ? 0 : 1)} kHz',
    if (channels != null && channels > 0)
      channels == 1
          ? 'Mono'
          : channels == 2
          ? 'Stereo'
          : '$channels ch',
    if (bitRate != null && bitRate > 0)
      bitRate >= 1000000
          ? '${(bitRate / 1000000).toStringAsFixed(1)} Mbps'
          : '${bitRate ~/ 1000} kbps',
  ].join(' · ');
}

Future<(Map<String, Object?>?, UnifiedTrackMetadata?)> _loadBadgesData(MediaItem item) async {
  final audioFuture = _audioQualityFor(item);
  final metaFuture = MetadataProviderService.instance.fetchMetadata(
    title: item.title,
    artist: item.artist ?? '',
  );
  final results = await Future.wait([audioFuture, metaFuture]);
  return (
    results[0] as Map<String, Object?>?,
    results[1] as UnifiedTrackMetadata?,
  );
}

class _AudioQualityBadges extends StatelessWidget {
  const _AudioQualityBadges({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) => FutureBuilder<(Map<String, Object?>?, UnifiedTrackMetadata?)>(
    future: _loadBadgesData(item),
    builder: (context, snapshot) {
      final details = snapshot.data?.$1;
      final studioMeta = snapshot.data?.$2;
      final quality = (details != null) ? _audioQualityLabel(details) : 'Unavailable';
      final mime = (details?['mimeType'] as String?)?.toLowerCase() ?? '';
      final path = item.id.toLowerCase();
      final isLossless = mime.contains('flac') ||
          mime.contains('alac') ||
          mime.contains('wav') ||
          path.endsWith('.flac') ||
          path.endsWith('.alac') ||
          path.endsWith('.wav');

      String labelText;
      if (quality == 'Unavailable') {
        labelText = 'AAC';
      } else {
        final parts = quality.split(' · ');
        final codec = parts.first;
        final khz = parts.length > 1 ? parts[1] : '';
        if (isLossless && khz.isNotEmpty) {
          labelText = '$codec · $khz';
        } else if (isLossless) {
          labelText = '$codec Hi-Res';
        } else if (khz.isNotEmpty) {
          labelText = '$codec · $khz';
        } else {
          labelText = codec;
        }
      }

      final resolvedGenre = (item.extras?['genre'] as String?)?.trim().isNotEmpty == true
          ? (item.extras!['genre'] as String).trim()
          : item.genre?.trim().isNotEmpty == true
              ? item.genre!.trim()
              : studioMeta?.genres.firstOrNull;

      final sourceProvider = item.extras?['downloadProvider'] as String? ??
          (item.id.startsWith('spotify:') || item.extras?['source'] == 'spotify'
              ? 'Spotify'
              : item.id.startsWith('youtube:') || item.extras?['source'] == 'youtube'
                  ? 'YouTube Music'
                  : item.id.startsWith('deezer:')
                      ? 'Deezer'
                      : item.id.startsWith('soundcloud:')
                          ? 'SoundCloud'
                          : item.extras?['source'] == 'device'
                              ? 'Local Audio'
                              : studioMeta?.provider.displayName);

      return InkWell(
        onTap: () => TrackDetailsSheet.show(context, item),
        borderRadius: BorderRadius.circular(MeloRadii.pill),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (resolvedGenre != null && resolvedGenre.isNotEmpty) ...[
                _QualityBadge(
                  label: resolvedGenre.toUpperCase(),
                  icon: Icons.music_note_rounded,
                  highlighted: true,
                ),
                const SizedBox(width: 6),
              ],
              _QualityBadge(
                label: labelText,
                icon: isLossless ? Icons.high_quality_rounded : null,
                highlighted: isLossless,
              ),
              if (sourceProvider != null && sourceProvider.isNotEmpty) ...[
                const SizedBox(width: 6),
                _QualityBadge(
                  label: sourceProvider.toUpperCase(),
                  icon: Icons.cloud_outlined,
                  highlighted: false,
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _QualityBadge extends StatelessWidget {
  const _QualityBadge({
    required this.label,
    this.icon,
    this.highlighted = false,
  });

  final String label;
  final IconData? icon;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: highlighted
          ? MeloColors.cherry.withValues(alpha: 0.22)
          : Colors.white.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(MeloRadii.pill),
      border: Border.all(
        color: highlighted
            ? MeloColors.cherrySoft.withValues(alpha: 0.50)
            : Colors.white.withValues(alpha: 0.14),
        width: 0.8,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 11,
              color: highlighted ? MeloColors.cherrySoft : MeloColors.playerMuted,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: highlighted ? MeloColors.cherrySoft : MeloColors.playerText,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    ),
  );
}

class TrackDetailsSheet extends StatelessWidget {
  const TrackDetailsSheet({
    required this.item,
    this.onEnrichMetadata,
    super.key,
  });

  final MediaItem item;
  final VoidCallback? onEnrichMetadata;

  static void show(
    BuildContext context,
    MediaItem item, {
    VoidCallback? onEnrichMetadata,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (context) => TrackDetailsSheet(
        item: item,
        onEnrichMetadata: onEnrichMetadata,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final extras = item.extras ?? const <String, dynamic>{};
    final cachedStudio = MetadataProviderService.instance.getCachedMetadata(
      title: item.title,
      artist: item.artist ?? '',
    );
    final rawGenre = (extras['genre'] as String?)?.trim().isNotEmpty == true
        ? (extras['genre'] as String).trim()
        : item.genre?.trim().isNotEmpty == true
            ? item.genre!.trim()
            : (cachedStudio != null && cachedStudio.genres.isNotEmpty)
                ? cachedStudio.genres.first
                : null;
    final bpm = (extras['bpm'] as num?)?.toDouble();
    final year = extras['year'] ??
        (cachedStudio?.releaseDate != null
            ? DateTime.tryParse(cachedStudio!.releaseDate!)?.year
            : null);
    final trackNumber = extras['trackNumber'];
    final fileSizeBytes = (extras['fileSizeBytes'] as num?)?.toInt();
    final modifiedAt = DateTime.tryParse(
      extras['dateModifiedAt'] as String? ?? '',
    );
    final downloadProvider = extras['downloadProvider'] as String?;
    final itemSource = extras['source'] as String?;
    final isOnlineTrack =
        (!item.id.startsWith('/') && !item.id.startsWith('file:')) &&
        (extras['isLiveStream'] == true ||
            item.id.startsWith('youtube:') ||
            item.id.startsWith('spotify:') ||
            item.id.startsWith('http://') ||
            item.id.startsWith('https://') ||
            itemSource == 'youtube' ||
            itemSource == 'spotify');

    final source = isOnlineTrack
        ? (itemSource == 'spotify' || item.id.startsWith('spotify:')
            ? 'Live Stream (Spotify Match · Not downloaded)'
            : 'Live Stream (YouTube Music · Not downloaded)')
        : downloadProvider != null
        ? 'Saved on Device ($downloadProvider)'
        : itemSource == 'device'
        ? 'On-device library'
        : 'Imported audio';
    final licenseUrl = extras['licenseUrl'] as String?;
    final theme = Theme.of(context);
    final details = <(String, String)>[
      ('Artist', displayArtistName(item.artist)),
      (
        'Album',
        item.album?.trim().isNotEmpty == true &&
                item.album!.trim().toLowerCase() != 'unknown album'
            ? item.album!.trim()
            : (cachedStudio?.album.trim().isNotEmpty == true
                ? cachedStudio!.album.trim()
                : 'Not tagged'),
      ),
      ('Release year', year == null ? 'Not tagged' : '$year'),
      ('Track', trackNumber == null ? 'Not tagged' : '$trackNumber'),
      (
        'Genre',
        rawGenre != null && rawGenre.isNotEmpty
            ? (rawGenre.length > 1 ? rawGenre[0].toUpperCase() + rawGenre.substring(1) : rawGenre.toUpperCase())
            : 'Not tagged',
      ),
      if (bpm != null && bpm > 0) ('Tempo', '${bpm.round()} BPM'),
      (
        'Duration',
        item.duration == null
            ? 'Unknown'
            : _formatTime(item.duration!.inMilliseconds),
      ),
      ('Source', source),
      if (item.id.startsWith('youtube:'))
        ('YouTube ID', item.id.replaceFirst('youtube:', ''))
      else if (item.id.startsWith('spotify:'))
        ('Spotify ID', item.id.replaceFirst('spotify:', ''))
      else if (item.id.startsWith('http://') || item.id.startsWith('https://'))
        ('Stream URL', item.id)
      else
        ('File', _trackFileName(item.id)),
      if (fileSizeBytes != null)
        ('File size', _formatTrackFileSize(fileSizeBytes)),
      if (modifiedAt != null)
        (
          'Modified',
          '${modifiedAt.year}-${modifiedAt.month.toString().padLeft(2, '0')}-${modifiedAt.day.toString().padLeft(2, '0')}',
        ),
      if (licenseUrl != null) ('License', licenseUrl),
    ];
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.82,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: MeloGlass(
          borderRadius: 28,
          tint: const Color(0xE817171B),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.32),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 16),
              // Big Centered Hero Artwork (Apple Music visual fidelity)
              Center(
                child: Container(
                  width: 210,
                  height: 210,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: MeloColors.cherry.withValues(alpha: 0.35),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.7),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: AlbumArtwork(
                      size: 210,
                      title: item.title,
                      artworkUri: item.artUri,
                      sourceUri: Uri.tryParse(item.id),
                      borderRadius: 20,
                      iconSize: 64,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Text(
                      item.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      displayArtistName(item.artist),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  children: [
                    if (onEnrichMetadata != null) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: OutlinedButton.icon(
                          onPressed: onEnrichMetadata,
                          icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                          label: const Text('Download lyrics, artwork & metadata'),
                        ),
                      ),
                    ],
                    for (final (label, value) in details)
                      _TrackDetailRow(label: label, value: value),
                    if (!isOnlineTrack &&
                        defaultTargetPlatform == TargetPlatform.android) ...[
                      const SizedBox(height: 8),
                      Text(
                        'More embedded tags',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.62),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FutureBuilder<Map<String, Object?>?>(
                        future: _audioTagsFor(item),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return _TrackDetailRow(
                              label: 'Embedded tags',
                              value: snapshot.error is MissingPluginException
                                  ? 'Tag reader unavailable. Restart Melo after installing the latest Android build.'
                                  : 'Could not read: ${snapshot.error}',
                            );
                          }
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            return const _TrackDetailRow(
                              label: 'Embedded tags',
                              value: 'Reading tags from the file…',
                            );
                          }
                          final tags = snapshot.data;
                          if (tags == null) {
                            return const _TrackDetailRow(
                              label: 'Embedded tags',
                              value: 'Not available for this source',
                            );
                          }
                          final extraTags = _additionalTrackTagRows(tags);
                          if (extraTags.isEmpty) {
                            return const _TrackDetailRow(
                              label: 'Additional tags',
                              value: 'No additional tags found',
                            );
                          }
                          return Column(
                            children: [
                              for (final (label, value) in extraTags)
                                _TrackDetailRow(label: label, value: value),
                            ],
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      'Audio quality',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<Map<String, Object?>?>(
                      future: _audioQualityFor(item),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const _TrackDetailRow(
                            label: 'Source format',
                            value: 'Could not read audio stream details',
                          );
                        }
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const _TrackDetailRow(
                            label: 'Source format',
                            value: 'Reading audio stream…',
                          );
                        }
                        final quality = snapshot.data;
                        if (quality == null) {
                          return const _TrackDetailRow(
                            label: 'Source format',
                            value: 'Not available for this source',
                          );
                        }
                        return Column(
                          children: [
                            for (final (label, value)
                                in _audioQualityDetailRows(quality))
                              _TrackDetailRow(label: label, value: value),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Audio output route',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<List<AudioOutputDeviceInfo>>(
                      future: PlayerDeviceHelper.getOutputDevices(),
                      builder: (context, snapshot) {
                        final devices = snapshot.data ?? const [];
                        final active = devices.where((d) => d.isActive).firstOrNull ?? devices.firstOrNull;
                        if (active == null) {
                          return const _TrackDetailRow(
                            label: 'Active output',
                            value: 'Internal speaker',
                          );
                        }
                        return Column(
                          children: [
                            _TrackDetailRow(
                              label: 'Active device',
                              value: active.name,
                            ),
                            _TrackDetailRow(
                              label: 'Output path',
                              value: active.type.toUpperCase().replaceAll('_', ' '),
                            ),
                            _TrackDetailRow(
                              label: 'Output spec',
                              value: active.specLabel,
                            ),
                            if (active.isBitPerfectCapable)
                              const _TrackDetailRow(
                                label: 'Bit-perfect DAC',
                                value: 'Supported · Direct hardware playback',
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Tags come from the audio file or device media index. '
                      'Stream details describe the actual file being played.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.48),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<(String, String)> _audioQualityDetailRows(Map<String, Object?> quality) {
  final labels = _audioQualityLabel(quality).split(' · ');
  final rows = <(String, String)>[('Codec', labels.first)];
  final sampleRate = (quality['sampleRate'] as num?)?.toInt();
  if (sampleRate != null && sampleRate > 0) {
    rows.add((
      'Sample rate',
      '${(sampleRate / 1000).toStringAsFixed(sampleRate % 1000 == 0 ? 0 : 1)} kHz',
    ));
  }
  final channels = (quality['channelCount'] as num?)?.toInt();
  if (channels != null && channels > 0) {
    rows.add((
      'Channels',
      channels == 1
          ? 'Mono'
          : channels == 2
          ? 'Stereo'
          : '$channels channels',
    ));
  }
  final bitRate = (quality['bitRate'] as num?)?.toInt();
  if (bitRate != null && bitRate > 0) {
    rows.add((
      'Bit rate',
      bitRate >= 1000 ? '${bitRate ~/ 1000} kbps' : '$bitRate bps',
    ));
  }
  return rows;
}

List<(String, String)> _additionalTrackTagRows(Map<String, Object?> tags) {
  const fields = <(String, String)>[
    ('Album artist', 'albumArtist'),
    ('Disc', 'discNumber'),
    ('Track count', 'trackCount'),
    ('Composer', 'composer'),
    ('Writer', 'writer'),
    ('Compilation', 'compilation'),
  ];
  return [
    for (final (label, key) in fields)
      if (tags[key]?.toString().trim().isNotEmpty == true)
        (
          label,
          key == 'compilation' &&
                  {
                    '1',
                    'true',
                  }.contains(tags[key]!.toString().trim().toLowerCase())
              ? 'Yes'
              : tags[key]!.toString().trim(),
        ),
  ];
}

String _trackFileName(String path) {
  final uri = Uri.tryParse(path);
  final pathPart = uri?.path ?? path;
  final segments = pathPart.split(RegExp(r'[/\\]'));
  return segments.isEmpty || segments.last.isEmpty ? path : segments.last;
}

String _formatTrackFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class _TrackDetailRow extends StatelessWidget {
  const _TrackDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.52)),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
