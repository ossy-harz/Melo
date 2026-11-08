part of 'library_screen.dart';

class _AlbumDetailHeader extends StatelessWidget {
  const _AlbumDetailHeader({
    required this.group,
    required this.tracks,
    required this.onBack,
    required this.onSearch,
    required this.onPlay,
    required this.onShuffle,
    required this.onAddToPlaylist,
    required this.onArtistRadio,
    required this.onShowDetails,
  });

  final _LibraryGroup group;
  final List<ImportedTrack> tracks;
  final VoidCallback onBack;
  final VoidCallback? onSearch;
  final VoidCallback onPlay;
  final VoidCallback onShuffle;
  final VoidCallback onAddToPlaylist;
  final VoidCallback onArtistRadio;
  final VoidCallback onShowDetails;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final artwork = group.artworkTrack;
    int? year;
    for (final track in tracks) {
      if (track.year != null) {
        year = track.year;
        break;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Back to albums',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const Spacer(),
            if (onSearch != null)
              IconButton(
                tooltip: 'Search music',
                onPressed: onSearch,
                icon: const Icon(Icons.search_rounded),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AlbumArtwork(
              size: 96,
              title: artwork.title,
              artworkUri: artwork.artworkUri == null
                  ? null
                  : Uri.tryParse(artwork.artworkUri!),
              sourceUri: Uri.tryParse(artwork.path),
              borderRadius: 16,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Album · ${tracks.length} songs · ${year ?? 'Year not tagged'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    group.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    displayArtistName(artwork.artist),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Add album to playlist',
                        visualDensity: VisualDensity.compact,
                        onPressed: onAddToPlaylist,
                        icon: const Icon(Icons.playlist_add_rounded),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Album options',
                        onSelected: (value) {
                          if (value == 'radio') onArtistRadio();
                          if (value == 'details') onShowDetails();
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'radio',
                            child: Text('Start artist radio'),
                          ),
                          PopupMenuItem(
                            value: 'details',
                            child: Text('Album details'),
                          ),
                        ],
                        icon: const Icon(Icons.more_horiz_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: tracks.isEmpty ? null : onPlay,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  minimumSize: const Size(48, 46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.play_circle_outline_rounded, size: 19),
                label: const Text('Play'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: tracks.isEmpty ? null : onShuffle,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.onSurface,
                  backgroundColor: colors.surfaceContainerHigh,
                  side: BorderSide.none,
                  minimumSize: const Size(48, 46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.shuffle_rounded, size: 18),
                label: const Text('Shuffle'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LibraryMenuChoice extends StatelessWidget {
  const _LibraryMenuChoice({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label)),
      if (selected) const Icon(Icons.check_rounded, size: 18),
    ],
  );
}

class _LibraryTrackFilterSheet extends StatefulWidget {
  const _LibraryTrackFilterSheet({required this.initial});

  final LibraryTrackFilters initial;

  @override
  State<_LibraryTrackFilterSheet> createState() =>
      _LibraryTrackFilterSheetState();
}

class _LibraryTrackFilterSheetState extends State<_LibraryTrackFilterSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _minimumSizeController;
  late final TextEditingController _maximumSizeController;
  late final TextEditingController _minimumDurationController;
  late final TextEditingController _maximumDurationController;
  DateTimeRange? _modifiedRange;

  @override
  void initState() {
    super.initState();
    _minimumSizeController = TextEditingController(
      text: _formatThreshold(widget.initial.minimumSizeBytes, 1024 * 1024),
    );
    _maximumSizeController = TextEditingController(
      text: _formatThreshold(widget.initial.maximumSizeBytes, 1024 * 1024),
    );
    _minimumDurationController = TextEditingController(
      text: _formatThreshold(widget.initial.minimumDurationMs, 60 * 1000),
    );
    _maximumDurationController = TextEditingController(
      text: _formatThreshold(widget.initial.maximumDurationMs, 60 * 1000),
    );
    if (widget.initial.modifiedFrom != null ||
        widget.initial.modifiedThrough != null) {
      final start =
          widget.initial.modifiedFrom ?? widget.initial.modifiedThrough!;
      final end = widget.initial.modifiedThrough ?? start;
      _modifiedRange = DateTimeRange(start: start, end: end);
    }
  }

  @override
  void dispose() {
    _minimumSizeController.dispose();
    _maximumSizeController.dispose();
    _minimumDurationController.dispose();
    _maximumDurationController.dispose();
    super.dispose();
  }

  Future<void> _pickModifiedRange() async {
    final today = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1970),
      lastDate: DateTime(today.year + 1, 12, 31),
      initialDateRange: _modifiedRange,
      helpText: 'Choose modified dates',
    );
    if (selected != null && mounted) {
      setState(() => _modifiedRange = selected);
    }
  }

  String? _validatePair(
    String? value,
    TextEditingController minimum,
    TextEditingController maximum,
    String unit,
  ) {
    final text = value?.trim() ?? '';
    final parsed = text.isEmpty ? null : double.tryParse(text);
    if (text.isNotEmpty && (parsed == null || !parsed.isFinite || parsed < 0)) {
      return 'Enter a valid $unit value';
    }
    final minimumValue = double.tryParse(minimum.text.trim());
    final maximumValue = double.tryParse(maximum.text.trim());
    if (minimumValue != null &&
        maximumValue != null &&
        minimumValue > maximumValue) {
      return 'Minimum must not exceed maximum';
    }
    return null;
  }

  int? _threshold(TextEditingController controller, int multiplier) {
    final value = double.tryParse(controller.text.trim());
    return value == null ? null : (value * multiplier).round();
  }

  void _apply() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      LibraryTrackFilters(
        modifiedFrom: _modifiedRange?.start,
        modifiedThrough: _modifiedRange?.end,
        minimumSizeBytes: _threshold(_minimumSizeController, 1024 * 1024),
        maximumSizeBytes: _threshold(_maximumSizeController, 1024 * 1024),
        minimumDurationMs: _threshold(_minimumDurationController, 60 * 1000),
        maximumDurationMs: _threshold(_maximumDurationController, 60 * 1000),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'More filters',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Text(
                'Date modified',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _modifiedRange == null
                          ? 'Any date'
                          : '${_formatFilterDate(_modifiedRange!.start)} – ${_formatFilterDate(_modifiedRange!.end)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: _pickModifiedRange,
                    child: Text(_modifiedRange == null ? 'Choose' : 'Change'),
                  ),
                  if (_modifiedRange != null)
                    IconButton(
                      tooltip: 'Clear date range',
                      onPressed: () => setState(() => _modifiedRange = null),
                      icon: const Icon(Icons.close_rounded),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'File size (MB)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('minimum-file-size'),
                      controller: _minimumSizeController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Minimum',
                        suffixText: 'MB',
                      ),
                      validator: (value) => _validatePair(
                        value,
                        _minimumSizeController,
                        _maximumSizeController,
                        'size',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('maximum-file-size'),
                      controller: _maximumSizeController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Maximum',
                        suffixText: 'MB',
                      ),
                      validator: (value) => _validatePair(
                        value,
                        _minimumSizeController,
                        _maximumSizeController,
                        'size',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Duration (minutes)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('minimum-track-duration'),
                      controller: _minimumDurationController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Minimum',
                        suffixText: 'min',
                      ),
                      validator: (value) => _validatePair(
                        value,
                        _minimumDurationController,
                        _maximumDurationController,
                        'duration',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('maximum-track-duration'),
                      controller: _maximumDurationController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Maximum',
                        suffixText: 'min',
                      ),
                      validator: (value) => _validatePair(
                        value,
                        _minimumDurationController,
                        _maximumDurationController,
                        'duration',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pop(const LibraryTrackFilters()),
                    child: const Text('Reset'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _apply,
                    child: const Text('Apply filters'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

String? _formatThreshold(int? value, int divisor) {
  if (value == null) return null;
  return (value / divisor)
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'\.?0+$'), '');
}

String _formatFilterDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class _AlbumTrackList extends StatelessWidget {
  const _AlbumTrackList({
    required this.tracks,
    required this.currentTrackId,
    required this.onPlay,
    required this.onQueue,
    required this.onRemove,
    required this.onToggleFavorite,
    required this.isFavorite,
  });

  final List<ImportedTrack> tracks;
  final String? currentTrackId;
  final ValueChanged<ImportedTrack> onPlay;
  final ValueChanged<ImportedTrack> onQueue;
  final ValueChanged<ImportedTrack> onRemove;
  final ValueChanged<ImportedTrack> onToggleFavorite;
  final bool Function(ImportedTrack) isFavorite;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final track = tracks[index];
            final isPlaying = track.id == currentTrackId;
            final number = track.trackNumber ?? index + 1;
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 0),
              minLeadingWidth: 28,
              leading: SizedBox(
                width: 28,
                child: Center(
                  child: isPlaying
                      ? Icon(
                          Icons.equalizer_rounded,
                          color: colors.primary,
                          size: 20,
                        )
                      : Text(
                          number.toString().padLeft(2, '0'),
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
              ),
              title: Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                '${displayArtistName(track.artist)} · ${_formatAlbumDuration(track.durationMs)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
              ),
              onTap: () => onPlay(track),
              onLongPress: () => TrackDetailsSheet.show(
                context,
                track.toMediaItem(),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Add to queue',
                    onPressed: () => onQueue(track),
                    icon: const Icon(Icons.queue_music_rounded),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Song options',
                    onSelected: (value) {
                      if (value == 'favorite') onToggleFavorite(track);
                      if (value == 'details') {
                        TrackDetailsSheet.show(context, track.toMediaItem());
                      }
                      if (value == 'remove') onRemove(track);
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'favorite',
                        child: Text(
                          isFavorite(track)
                              ? 'Remove from favorites'
                              : 'Add to favorites',
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'details',
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded, size: 19),
                            SizedBox(width: 8),
                            Text('Track details'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'remove',
                        child: Text(
                          track.isDeviceMedia
                              ? 'Delete original file'
                              : 'Delete imported copy',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
          childCount: tracks.length,
          addAutomaticKeepAlives: false,
        ),
      ),
    );
  }
}

String _formatAlbumDuration(int? durationMs) {
  if (durationMs == null || durationMs <= 0) return '--:--';
  final totalSeconds = durationMs ~/ 1000;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.isAvailable});

  final bool isAvailable;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 38),
      child: Column(
        children: [
          Icon(
            Icons.queue_music_rounded,
            size: 54,
            color: colors.primary.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 18),
          Text(
            'Your library starts with you.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Scan your device to find your music in one go. Melo plays those originals in place, without copying them.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          if (!isAvailable) ...[
            const SizedBox(height: 18),
            Text(
              'Music import is available in the installed app.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrackList extends StatelessWidget {
  const _TrackList({
    required this.tracks,
    required this.onPlay,
    required this.onQueue,
    required this.onRemove,
    required this.onToggleFavorite,
    required this.isFavorite,
    this.selectedIds,
    this.onToggleSelection,
  });

  final List<ImportedTrack> tracks;
  final ValueChanged<ImportedTrack> onPlay;
  final ValueChanged<ImportedTrack> onQueue;
  final ValueChanged<ImportedTrack> onRemove;
  final ValueChanged<ImportedTrack> onToggleFavorite;
  final bool Function(ImportedTrack) isFavorite;
  final Set<String>? selectedIds;
  final ValueChanged<ImportedTrack>? onToggleSelection;

  @override
  Widget build(BuildContext context) => SliverPadding(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
    sliver: SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final track = tracks[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 2),
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onToggleSelection != null)
                  SizedBox(
                    width: 40,
                    child: Checkbox(
                      value: selectedIds?.contains(track.id) ?? false,
                      onChanged: (_) => onToggleSelection!(track),
                    ),
                  ),
                AlbumArtwork(
                  size: 52,
                  title: track.title,
                  artworkUri: track.artworkUri == null
                      ? null
                      : Uri.tryParse(track.artworkUri!),
                  sourceUri: Uri.tryParse(track.path),
                  borderRadius: 12,
                ),
              ],
            ),
            title: Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              track.album == 'Unknown album'
                  ? displayArtistName(track.artist)
                  : '${displayArtistName(track.artist)} · ${track.album}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => onPlay(track),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onToggleSelection == null)
                  IconButton(
                    tooltip: 'Add to queue',
                    onPressed: () => onQueue(track),
                    icon: const Icon(Icons.queue_music_rounded),
                  ),
                PopupMenuButton<String>(
                  tooltip: 'Song options',
                  onSelected: (value) {
                    if (value == 'favorite') onToggleFavorite(track);
                    if (value == 'remove') onRemove(track);
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'favorite',
                      child: Text(
                        isFavorite(track)
                            ? 'Remove from favorites'
                            : 'Add to favorites',
                      ),
                    ),
                    PopupMenuItem(
                      value: 'remove',
                      child: Text(
                        track.isDeviceMedia
                            ? 'Delete original file'
                            : 'Delete imported copy',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        childCount: tracks.length,
        addAutomaticKeepAlives: false,
      ),
    ),
  );
}

class _LibraryGroup {
  const _LibraryGroup({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.artworkTrack,
  });

  final String key;
  final String title;
  final String subtitle;
  final ImportedTrack artworkTrack;
}

class _GroupList extends StatelessWidget {
  const _GroupList({required this.groups, required this.onSelect});

  final List<_LibraryGroup> groups;
  final ValueChanged<_LibraryGroup> onSelect;

  @override
  Widget build(BuildContext context) {
    final columns = MediaQuery.sizeOf(context).width >= 640 ? 3 : 2;
    final colors = Theme.of(context).colorScheme;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 14,
          childAspectRatio: 0.78,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final group = groups[index];
            final artwork = group.artworkTrack;
            final radius = BorderRadius.circular(MeloRadii.lg);
            return Material(
              color: Colors.transparent,
              borderRadius: radius,
              clipBehavior: Clip.antiAlias,
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colors.surfaceContainerHigh,
                      colors.surfaceContainerLow,
                    ],
                  ),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.1),
                  ),
                ),
                child: InkWell(
                  onTap: () => onSelect(group),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) => AlbumArtwork(
                              size: constraints.maxWidth,
                              title: artwork.title,
                              artworkUri: artwork.artworkUri == null
                                  ? null
                                  : Uri.tryParse(artwork.artworkUri!),
                              sourceUri: Uri.tryParse(artwork.path),
                              borderRadius: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          group.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          group.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
          childCount: groups.length,
          addAutomaticKeepAlives: false,
        ),
      ),
    );
  }
}

class _PlaylistList extends StatelessWidget {
  const _PlaylistList({
    required this.playlists,
    required this.library,
    required this.tracksFor,
    required this.trackCount,
    required this.onSelect,
    required this.onPlay,
    required this.onRename,
    required this.onDelete,
  });

  final List<MusicPlaylist> playlists;
  final MusicLibrary? library;
  final List<ImportedTrack> Function(MusicPlaylist) tracksFor;
  final int Function(MusicPlaylist) trackCount;
  final ValueChanged<MusicPlaylist> onSelect;
  final ValueChanged<MusicPlaylist> onPlay;
  final ValueChanged<MusicPlaylist> onRename;
  final ValueChanged<MusicPlaylist> onDelete;

  @override
  Widget build(BuildContext context) => SliverPadding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
    sliver: SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 20,
        crossAxisSpacing: 16,
        childAspectRatio: 0.74,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final playlist = playlists[index];
          final playlistTracks = tracksFor(playlist);
          final count = trackCount(playlist);
          final themeIndex = playlist.coverStyle != null ? int.tryParse(playlist.coverStyle!) : null;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onSelect(playlist),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Apple Music Square Artwork
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        PlaylistArtwork(
                          playlistName: playlist.name,
                          tracks: playlistTracks,
                          library: library,
                          size: 180,
                          borderRadius: 14,
                          customArtworkUri: playlist.customArtworkUri,
                          themeIndex: themeIndex,
                        ),
                        if (count > 0)
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: Material(
                              color: MeloColors.cherry,
                              shape: const CircleBorder(),
                              elevation: 4,
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => onPlay(playlist),
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Title & Count
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          playlist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.more_vert_rounded, size: 18, color: Colors.white54),
                        tooltip: 'Playlist options',
                        onSelected: (value) {
                          if (value == 'rename') onRename(playlist);
                          if (value == 'delete') onDelete(playlist);
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'rename', child: Text('Rename')),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete playlist', style: TextStyle(color: Colors.redAccent)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Text(
                    '$count ${count == 1 ? 'song' : 'songs'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.55),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        childCount: playlists.length,
        addAutomaticKeepAlives: false,
      ),
    ),
  );
}

class _PlaylistTrackList extends StatelessWidget {
  const _PlaylistTrackList({
    required this.tracks,
    required this.onPlay,
    required this.onQueue,
    required this.onRemove,
    required this.onReorder,
  });

  final List<ImportedTrack> tracks;
  final ValueChanged<ImportedTrack> onPlay;
  final ValueChanged<ImportedTrack> onQueue;
  final ValueChanged<ImportedTrack> onRemove;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) => SliverPadding(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
    sliver: SliverReorderableList(
      itemCount: tracks.length,
      onReorderItem: onReorder,
      itemBuilder: (context, index) {
        final track = tracks[index];
        return ListTile(
          key: ValueKey(track.id),
          contentPadding: EdgeInsets.zero,
          leading: ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_handle_rounded),
          ),
          title: Text(
            track.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${displayArtistName(track.artist)} · ${track.album}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => onPlay(track),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Add to queue',
                onPressed: () => onQueue(track),
                icon: const Icon(Icons.queue_music_rounded),
              ),
              IconButton(
                tooltip: 'Remove from playlist',
                onPressed: () => onRemove(track),
                icon: const Icon(Icons.remove_circle_outline_rounded),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _NotAvailableFilter extends StatelessWidget {
  const _NotAvailableFilter({required this.filter});

  final String filter;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 54),
    child: Text(
      filter == 'Favorites'
          ? 'Your favorite songs will appear here.'
          : '$filter will appear here as your library grows.',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyLarge,
    ),
  );
}

class _NoopListenable implements Listenable {
  const _NoopListenable._();

  static const instance = _NoopListenable._();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

class _PlaylistNameDialog extends StatefulWidget {
  const _PlaylistNameDialog({required this.title, required this.initialName});

  final String title;
  final String initialName;

  @override
  State<_PlaylistNameDialog> createState() => _PlaylistNameDialogState();
}

class _PlaylistNameDialogState extends State<_PlaylistNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLength: 48,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(hintText: 'Playlist name'),
      onSubmitted: (value) => Navigator.of(context).pop(value),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(_controller.text),
        child: const Text('Save'),
      ),
    ],
  );
}
