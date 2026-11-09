part of 'mini_player.dart';

/// Inline, auto-scrolling lyrics that follow playback, shown in place of the
/// artwork on the Now Playing screen.
class _NowPlayingLyrics extends StatefulWidget {
  const _NowPlayingLyrics({
    required this.lyrics,
    required this.isLoading,
    required this.audioHandler,
    required this.palette,
    required this.onBackToArtwork,
    required this.onFindOnline,
    required this.onImportFile,
    super.key,
  });

  final SongLyrics? lyrics;
  final bool isLoading;
  final AudioHandler audioHandler;
  final MeloPalette palette;
  final VoidCallback onBackToArtwork;
  final Future<void> Function() onFindOnline;
  final Future<void> Function() onImportFile;

  @override
  State<_NowPlayingLyrics> createState() => _NowPlayingLyricsState();
}

class _NowPlayingLyricsState extends State<_NowPlayingLyrics> {
  final ScrollController _scrollController = ScrollController();
  List<GlobalKey> _lineKeys = const [];
  int? _lastScrolledIndex;
  int _syncOffsetMs = 0;
  String? _loadedItemId;

  @override
  void initState() {
    super.initState();
    _lineKeys = _buildLineKeys();
    _loadSyncOffset();
  }

  @override
  void didUpdateWidget(covariant _NowPlayingLyrics oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.lyrics, widget.lyrics)) {
      _lineKeys = _buildLineKeys();
      _lastScrolledIndex = null;
      _loadSyncOffset();
    }
  }

  Future<void> _loadSyncOffset() async {
    final itemId = widget.audioHandler.mediaItem.value?.id;
    if (itemId == null || itemId == _loadedItemId) return;
    _loadedItemId = itemId;
    final offset = await LyricsRepository.getSyncOffsetMs(itemId);
    if (mounted) {
      setState(() => _syncOffsetMs = offset);
    }
  }

  Future<void> _adjustSyncOffset(int deltaMs) async {
    final next = (_syncOffsetMs + deltaMs).clamp(-15000, 15000);
    setState(() {
      _syncOffsetMs = next;
      _lastScrolledIndex = null;
    });
    final itemId = widget.audioHandler.mediaItem.value?.id;
    if (itemId != null) {
      await LyricsRepository.setSyncOffsetMs(itemId, next);
    }
  }

  List<GlobalKey> _buildLineKeys() => List<GlobalKey>.generate(
    widget.lyrics?.lines.length ?? 0,
    (_) => GlobalKey(),
  );

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToActiveLine(int index) {
    if (index < 0 || index == _lastScrolledIndex) return;
    _lastScrolledIndex = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || index >= _lineKeys.length) return;
      final lineContext = _lineKeys[index].currentContext;
      if (lineContext == null) return;
      Scrollable.ensureVisible(
        lineContext,
        duration: MeloMotion.slow,
        curve: MeloMotion.emphasized,
        alignment: 0.42,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final lyrics = widget.lyrics;
    return Column(
      children: [
        _header(context, lyrics),
        if (lyrics != null && lyrics.isSynchronized)
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
            child: Row(
              children: [
                _offsetChip(
                  label: '-0.5s',
                  onTap: () => unawaited(_adjustSyncOffset(-500)),
                ),
                const SizedBox(width: 6),
                _offsetChip(
                  label: _syncOffsetMs == 0
                      ? '+0.5s'
                      : '${_syncOffsetMs > 0 ? '+' : ''}${(_syncOffsetMs / 1000).toStringAsFixed(1)}s',
                  onTap: () => unawaited(_adjustSyncOffset(500)),
                  onLongPress: () => unawaited(_adjustSyncOffset(-_syncOffsetMs)),
                ),
              ],
            ),
          ),
        if (lyrics != null && !lyrics.isSynchronized)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _actionChip(
                icon: Icons.auto_awesome_rounded,
                label: 'Find synced lyrics',
                onTap: () => unawaited(widget.onFindOnline()),
              ),
            ),
          ),
        Expanded(
          child: lyrics == null
              ? (widget.isLoading ? _loadingState() : _emptyState(context))
              : _lyricsList(context, lyrics),
        ),
      ],
    );
  }

  Widget _header(BuildContext context, SongLyrics? lyrics) {
    final synced = lyrics?.isSynchronized ?? false;
    final timingLabel = lyrics == null
        ? null
        : !synced
        ? 'PLAIN'
        : lyrics.hasWordTiming
        ? 'WORD SYNC'
        : 'LINE SYNC';
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 12, 0),
      child: Row(
        children: [
          Icon(
            Icons.graphic_eq_rounded,
            size: 15,
            color: widget.palette.accent,
          ),
          const SizedBox(width: 8),
          Text(
            'LYRICS',
            style: TextStyle(
              color: MeloColors.playerText.withValues(alpha: 0.82),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
            ),
          ),
          if (lyrics != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: (synced ? widget.palette.accent : MeloColors.playerMuted)
                    .withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(
                  color:
                      (synced ? widget.palette.accent : MeloColors.playerMuted)
                          .withValues(alpha: 0.42),
                ),
              ),
              child: Text(
                timingLabel!,
                style: TextStyle(
                  color: synced
                      ? widget.palette.accent
                      : MeloColors.playerMuted,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
          const Spacer(),
          _actionChip(
            icon: Icons.album_rounded,
            label: 'Artwork',
            onTap: widget.onBackToArtwork,
          ),
        ],
      ),
    );
  }

  Widget _offsetChip({
    required String label,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(99),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          child: Text(
            label,
            style: TextStyle(
              color: MeloColors.playerText.withValues(alpha: 0.78),
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(99),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: MeloColors.playerText),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: MeloColors.playerText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: widget.palette.accent,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Looking for lyrics…',
            style: TextStyle(color: MeloColors.playerMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Icon(
                Icons.lyrics_outlined,
                color: MeloColors.playerText.withValues(alpha: 0.72),
                size: 28,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No lyrics yet',
              style: TextStyle(
                color: MeloColors.playerText,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Standard .lrc files follow each line. Enhanced .lrc files can '
              'time every word, or let Tone search for lyrics.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: MeloColors.playerText.withValues(alpha: 0.6),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () => unawaited(widget.onFindOnline()),
                  style: FilledButton.styleFrom(
                    backgroundColor: MeloColors.cherry,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.travel_explore_rounded, size: 18),
                  label: const Text('Find online'),
                ),
                OutlinedButton.icon(
                  onPressed: () => unawaited(widget.onImportFile()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MeloColors.playerText,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.24),
                    ),
                  ),
                  icon: const Icon(Icons.upload_file_rounded, size: 18),
                  label: const Text('Add file'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _lyricsList(BuildContext context, SongLyrics lyrics) {
    final base = Theme.of(context).textTheme.titleLarge ?? const TextStyle();
    return StreamBuilder<Duration>(
      stream: playbackPositionStream(widget.audioHandler),
      builder: (context, snapshot) {
        final rawPosition = snapshot.data ?? Duration.zero;
        final hasStarted = rawPosition > Duration.zero;
        final leadInMs = (hasStarted && widget.audioHandler is MeloAudioHandler) ? 120 : 0;
        final adjustedMs =
            (rawPosition.inMilliseconds + _syncOffsetMs + leadInMs).clamp(
              0,
              86400000,
            );
        final position = Duration(milliseconds: adjustedMs);
        final activeIndex = (hasStarted && lyrics.isSynchronized)
            ? lyrics.activeLineAt(position)
            : -1;
        if (activeIndex >= 0) {
          _scrollToActiveLine(activeIndex);
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final verticalPadding = constraints.maxHeight * 0.34;
            return ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black,
                  Colors.black,
                  Colors.transparent,
                ],
                stops: [0, 0.16, 0.84, 1],
              ).createShader(rect),
              child: ListView.builder(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  26,
                  verticalPadding,
                  26,
                  verticalPadding,
                ),
                itemCount: lyrics.lines.length,
                itemBuilder: (context, index) {
                  final line = lyrics.lines[index];
                  final isActive = index == activeIndex;
                  final activeWord = isActive && line.words.isNotEmpty
                      ? lyrics.activeWordAt(index, position)
                      : -1;
                  final distance = activeIndex < 0
                      ? 0
                      : (index - activeIndex).abs();
                  final dim = isActive ? 1.0 : (distance == 1 ? 0.6 : 0.38);
                  return Padding(
                    key: _lineKeys[index],
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: line.time != null
                          ? () => unawaited(widget.audioHandler.seek(line.time!))
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: AnimatedDefaultTextStyle(
                          duration: MeloMotion.slow,
                          curve: MeloMotion.emphasized,
                          style: base.copyWith(
                            fontSize: isActive ? 24 : 21,
                            height: 1.26,
                            letterSpacing: isActive ? -0.6 : -0.3,
                            fontWeight: isActive
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: isActive
                                ? widget.palette.accent
                                : MeloColors.playerText.withValues(alpha: dim),
                            shadows: isActive
                                ? [
                                    Shadow(
                                      color: widget.palette.accent.withValues(
                                        alpha: 0.5,
                                      ),
                                      blurRadius: 20,
                                    ),
                                  ]
                                : null,
                          ),
                          child: line.words.isEmpty
                              ? Text(line.text, textAlign: TextAlign.center)
                              : Text.rich(
                                  TextSpan(
                                    children: [
                                      for (
                                        var wordIndex = 0;
                                        wordIndex < line.words.length;
                                        wordIndex++
                                      )
                                        TextSpan(
                                          text:
                                              '${line.words[wordIndex].text}'
                                              '${wordIndex + 1 == line.words.length ? '' : ' '}',
                                          style: isActive
                                              ? TextStyle(
                                                  color: activeWord >= 0 &&
                                                          wordIndex < activeWord
                                                      ? Colors.white
                                                      : activeWord == wordIndex
                                                      ? widget.palette.accent
                                                      : Colors.white.withValues(
                                                          alpha: 0.38,
                                                        ),
                                                  fontWeight:
                                                      wordIndex <= activeWord
                                                          ? FontWeight.w800
                                                          : FontWeight.w600,
                                                  shadows:
                                                      activeWord == wordIndex
                                                          ? [
                                                              Shadow(
                                                                color: widget
                                                                    .palette
                                                                    .accent
                                                                    .withValues(
                                                                      alpha: 0.7,
                                                                    ),
                                                                blurRadius: 18,
                                                              ),
                                                            ]
                                                          : null,
                                                )
                                              : null,
                                        ),
                                    ],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _FullLyricsSheet extends StatefulWidget {
  const _FullLyricsSheet({
    required this.title,
    required this.artist,
    required this.lyrics,
    required this.audioHandler,
  });

  final String title;
  final String artist;
  final SongLyrics lyrics;
  final AudioHandler audioHandler;

  @override
  State<_FullLyricsSheet> createState() => _FullLyricsSheetState();
}

class _FullLyricsSheetState extends State<_FullLyricsSheet> {
  late final ScrollController _scrollController;
  late final List<GlobalKey> _lineKeys;
  int? _lastScrolledIndex;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _lineKeys = List.generate(widget.lyrics.lines.length, (_) => GlobalKey());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToActiveLine(int index) {
    if (index < 0 || index == _lastScrolledIndex) return;
    _lastScrolledIndex = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || index >= _lineKeys.length) return;
      final lineContext = _lineKeys[index].currentContext;
      if (lineContext == null) return;
      Scrollable.ensureVisible(
        lineContext,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
        alignment: 0.5,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.86,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: MeloGlass(
          borderRadius: 28,
          tint: Colors.black.withValues(alpha: 0.28),
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
              ListTile(
                title: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  widget.artist,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.62)),
                ),
                trailing: PlayerGlassIconButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Close lyrics',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              Expanded(
                child: StreamBuilder<Duration>(
                  stream: playbackPositionStream(widget.audioHandler),
                  builder: (context, snapshot) {
                    final activeIndex = widget.lyrics.isSynchronized
                        ? widget.lyrics.activeLineAt(
                            snapshot.data ?? Duration.zero,
                          )
                        : -1;
                    _scrollToActiveLine(activeIndex);
                    return ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                      children: List.generate(widget.lyrics.lines.length, (
                        index,
                      ) {
                        final isActive = index == activeIndex;
                        final line = widget.lyrics.lines[index];
                        final activeWord = isActive
                            ? widget.lyrics.activeWordAt(
                                index,
                                snapshot.data ?? Duration.zero,
                              )
                            : -1;
                        return Padding(
                          key: _lineKeys[index],
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: line.time != null
                                ? () => unawaited(widget.audioHandler.seek(line.time!))
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 180),
                                style:
                                    Theme.of(
                                      context,
                                    ).textTheme.titleMedium?.copyWith(
                                      color: isActive
                                          ? const Color(0xFFFF756C)
                                          : Colors.white.withValues(alpha: 0.68),
                                      fontWeight: isActive
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ) ??
                                    const TextStyle(),
                                child: !line.hasExplicitWords
                                    ? Text(
                                        line.text,
                                        textAlign: TextAlign.center,
                                        key: isActive
                                            ? const ValueKey('active-lyrics-line')
                                            : null,
                                      )
                                    : Text.rich(
                                        TextSpan(
                                          children: [
                                            for (
                                              var wordIndex = 0;
                                              wordIndex < line.words.length;
                                              wordIndex++
                                            )
                                              TextSpan(
                                                text:
                                                    '${line.words[wordIndex].text}${wordIndex + 1 == line.words.length ? '' : ' '}',
                                                style: TextStyle(
                                                  color: isActive && wordIndex == activeWord
                                                      ? const Color(0xFFFF827A)
                                                      : null,
                                                  fontWeight: isActive &&
                                                          wordIndex <= activeWord
                                                      ? FontWeight.w800
                                                      : FontWeight.w500,
                                                  shadows: isActive &&
                                                          wordIndex == activeWord
                                                      ? const [
                                                          Shadow(
                                                            color: Color(0x99FF827A),
                                                            blurRadius: 16,
                                                          ),
                                                        ]
                                                      : null,
                                                ),
                                              ),
                                          ],
                                        ),
                                        textAlign: TextAlign.center,
                                        key: isActive
                                            ? const ValueKey('active-lyrics-line')
                                            : null,
                                      ),
                              ),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
