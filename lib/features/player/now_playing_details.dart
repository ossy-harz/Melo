part of 'mini_player.dart';

Future<Map<String, Object?>?> _audioQualityFor(MediaItem item) =>
    _audioQualityCache.putIfAbsent(item.id, () async {
      final extras = item.extras;
      if (extras != null && extras['mimeType'] != null) {
        return {
          'mimeType': extras['mimeType'] as String?,
          'bitRate': extras['bitRate'] as num?,
          'sampleRate': extras['sampleRate'] as num?,
          'channelCount': extras['channelCount'] as num?,
        };
      }

      if (item.id.startsWith('youtube:') ||
          extras?['source'] == 'youtube' ||
          extras?['downloadProvider'] == 'YouTube') {
        return {
          'mimeType': 'audio/mp4',
          'bitRate': 128000,
          'sampleRate': 44100,
          'channelCount': 2,
        };
      }

      if (item.id.startsWith('spotify:') ||
          extras?['source'] == 'spotify' ||
          extras?['downloadProvider'] == 'Spotify') {
        return {
          'mimeType': 'audio/mp4',
          'bitRate': 128000,
          'sampleRate': 44100,
          'channelCount': 2,
        };
      }

      if (item.id.startsWith('http://') || item.id.startsWith('https://')) {
        return {
          'mimeType': 'audio/mp4',
          'bitRate': 128000,
          'sampleRate': 44100,
          'channelCount': 2,
        };
      }

      if (defaultTargetPlatform != TargetPlatform.android) return null;
      try {
        return await _artworkChannel.invokeMapMethod<String, Object?>(
          'readAudioQuality',
          {'uri': item.id},
        );
      } catch (e) {
        debugPrint('Could not read audio quality: $e');
        return null;
      }
    });

Future<Map<String, Object?>?> _audioTagsFor(MediaItem item) =>
    _audioTagsCache.putIfAbsent(item.id, () async {
      final isOnline = item.id.startsWith('youtube:') ||
          item.id.startsWith('spotify:') ||
          item.id.startsWith('http://') ||
          item.id.startsWith('https://') ||
          item.extras?['source'] == 'youtube' ||
          item.extras?['source'] == 'spotify';
      if (isOnline) {
        return {
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
          {'path': item.id, 'fallbackTitle': item.title},
        );
      } catch (e) {
        debugPrint('Could not read audio tags: $e');
        return null;
      }
    });

String _audioQualityLabel(Map<String, Object?> details) {
  final mimeType = details['mimeType'] as String?;
  if (mimeType == null || mimeType.isEmpty) return 'Unavailable';
  final codec = switch (mimeType.toLowerCase()) {
    final value when value.contains('flac') => 'FLAC',
    final value when value.contains('mpeg') || value.contains('mp3') => 'MP3',
    final value when value.contains('aac') || value.contains('mp4a') => 'AAC',
    final value when value.contains('opus') => 'Opus',
    final value when value.contains('vorbis') => 'Vorbis',
    final value when value.contains('alac') => 'ALAC',
    final value
        when value.contains('pcm') ||
            value.contains('wav') ||
            value.contains('raw') =>
      'PCM',
    _ => mimeType.substring(mimeType.indexOf('/') + 1).toUpperCase(),
  };
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
    if (bitRate != null && bitRate > 0) '${bitRate ~/ 1000} kbps',
  ].join(' · ');
}

class _AudioQualityBadges extends StatelessWidget {
  const _AudioQualityBadges({required this.item});

  final MediaItem item;

  bool get _isStreaming {
    final extras = item.extras;
    if (item.id.startsWith('/') || item.id.startsWith('file:')) return false;
    return extras?['isLiveStream'] == true ||
        item.id.startsWith('youtube:') ||
        item.id.startsWith('spotify:') ||
        item.id.startsWith('http://') ||
        item.id.startsWith('https://') ||
        extras?['source'] == 'youtube' ||
        extras?['source'] == 'spotify';
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, Object?>?>(
    future: _audioQualityFor(item),
    builder: (context, snapshot) {
      final isStream = _isStreaming;
      if (snapshot.hasError) {
        return Wrap(
          spacing: 6,
          runSpacing: 5,
          children: [
            _QualityBadge(
              label: isStream ? 'LIVE STREAM' : 'ON DEVICE',
              highlighted: isStream,
            ),
            const _QualityBadge(label: 'Quality unavailable'),
          ],
        );
      }
      final details = snapshot.data;
      if (details == null) {
        return _QualityBadge(
          label: isStream ? 'LIVE STREAM' : 'ON DEVICE',
          highlighted: isStream,
        );
      }
      final quality = _audioQualityLabel(details);
      if (quality == 'Unavailable') {
        return _QualityBadge(
          label: isStream ? 'LIVE STREAM' : 'ON DEVICE',
          highlighted: isStream,
        );
      }
      return Wrap(
        spacing: 6,
        runSpacing: 5,
        children: [
          _QualityBadge(
            label: isStream ? 'LIVE STREAM' : 'ON DEVICE',
            highlighted: isStream,
          ),
          for (final label in quality.split(' · ').take(3))
            _QualityBadge(label: label),
        ],
      );
    },
  );
}

class _QualityBadge extends StatelessWidget {
  const _QualityBadge({required this.label, this.highlighted = false});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: highlighted
          ? ToneColors.cherry.withValues(alpha: 0.24)
          : Colors.white.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(ToneRadii.pill),
      border: Border.all(
        color: highlighted
            ? ToneColors.cherrySoft.withValues(alpha: 0.45)
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
      child: Text(
        label,
        style: TextStyle(
          color: highlighted ? ToneColors.cherrySoft : ToneColors.playerText,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    ),
  );
}

class _TrackDetailsSheet extends StatelessWidget {
  const _TrackDetailsSheet({
    required this.item,
    this.onEnrichMetadata,
  });

  final MediaItem item;
  final VoidCallback? onEnrichMetadata;

  @override
  Widget build(BuildContext context) {
    final extras = item.extras ?? const <String, dynamic>{};
    final genre = extras['genre'] as String?;
    final bpm = (extras['bpm'] as num?)?.toDouble();
    final year = extras['year'];
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
            : 'Not tagged',
      ),
      ('Release year', year == null ? 'Not tagged' : '$year'),
      ('Track', trackNumber == null ? 'Not tagged' : '$trackNumber'),
      (
        'Genre',
        genre?.trim().isNotEmpty == true ? genre!.trim() : 'Not tagged',
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
        child: ToneGlass(
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
                child: Row(
                  children: [
                    AlbumArtwork(
                      size: 64,
                      title: item.title,
                      artworkUri: item.artUri,
                      sourceUri: Uri.tryParse(item.id),
                      borderRadius: 14,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Track details',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: const Color(0xFFFF827A),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PlayerGlassIconButton(
                      icon: Icons.close_rounded,
                      tooltip: 'Close track details',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
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
                                  ? 'Tag reader unavailable. Restart Tone after installing the latest Android build.'
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
