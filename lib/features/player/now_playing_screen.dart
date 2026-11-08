part of 'mini_player.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({
    required this.audioHandler,
    this.musicLibrary,
    this.onNavigate,
    super.key,
  });

  final AudioHandler audioHandler;
  final MusicLibrary? musicLibrary;
  final ValueChanged<int>? onNavigate;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: MeloColors.amoled,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
    child: Scaffold(
      backgroundColor: MeloColors.amoled,
      body: StreamBuilder<MediaItem?>(
        stream: audioHandler.mediaItem,
        builder: (context, snapshot) {
          final item = snapshot.data;
          if (item == null) {
            return const _NowPlayingEmptyState();
          }
          return _NowPlayingContent(
            item: item,
            audioHandler: audioHandler,
            musicLibrary: musicLibrary,
            onNavigate: onNavigate,
          );
        },
      ),
    ),
  );
}

class _NowPlayingEmptyState extends StatelessWidget {
  const _NowPlayingEmptyState();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: RadialGradient(
        center: Alignment(0, -0.7),
        radius: 1.2,
        colors: [Color(0x4DE8173B), MeloColors.amoled],
      ),
    ),
    child: Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: MeloGlass(
          borderRadius: 30,
          tint: Color(0x0FFFFFFF),
          padding: EdgeInsets.fromLTRB(28, 30, 28, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [MeloColors.cherry, MeloColors.cherryDeep],
                  ),
                ),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: Icon(
                    Icons.graphic_eq_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
              SizedBox(height: 18),
              Text(
                'Nothing playing yet',
                style: TextStyle(
                  color: MeloColors.playerText,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Choose a song from your library to start listening.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: MeloColors.playerMuted,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _NowPlayingFavoriteButton extends StatefulWidget {
  const _NowPlayingFavoriteButton({
    required this.isFavorite,
    required this.onTap,
  });

  final bool isFavorite;
  final VoidCallback onTap;

  @override
  State<_NowPlayingFavoriteButton> createState() =>
      _NowPlayingFavoriteButtonState();
}

class _NowPlayingFavoriteButtonState extends State<_NowPlayingFavoriteButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.34), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.34, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(covariant _NowPlayingFavoriteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isFavorite && widget.isFavorite) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: IconButton(
        tooltip: widget.isFavorite
            ? 'Remove from favorites'
            : 'Add to favorites',
        onPressed: () {
          widget.onTap();
          if (!widget.isFavorite) {
            _controller.forward(from: 0);
          }
        },
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isFavorite
                ? MeloColors.cherry.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.06),
          ),
          child: Icon(
            widget.isFavorite
                ? Icons.star_rounded
                : Icons.star_border_rounded,
            color: widget.isFavorite ? MeloColors.cherry : MeloColors.playerMuted,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _NowPlayingContent extends StatefulWidget {
  const _NowPlayingContent({
    required this.item,
    required this.audioHandler,
    this.musicLibrary,
    this.onNavigate,
  });

  final MediaItem item;
  final AudioHandler audioHandler;
  final MusicLibrary? musicLibrary;
  final ValueChanged<int>? onNavigate;

  @override
  State<_NowPlayingContent> createState() => _NowPlayingContentState();
}

class _NowPlayingContentState extends State<_NowPlayingContent> {
  double? _dragPosition;
  SongLyrics? _lyrics;
  bool _isLoadingLyrics = false;
  bool _isTransitioning = false;
  double _transitionProgress = 0;
  Duration? _transitionDuration;
  bool _isAnalyzingTransition = false;
  bool _hasAnalysisTarget = false;
  bool _analysisUnsupported = false;
  bool _transitionAnalysisFailed = false;
  WaveformTransitionCues? _outgoingCues;
  WaveformTransitionCues? _incomingCues;
  String? _nextTrackTitle;
  int _analysisRequest = 0;
  String _queueSignature = '';
  String _playbackSignature = '';
  StreamSubscription<List<MediaItem>>? _queueSubscription;
  StreamSubscription<PlaybackState>? _playbackSubscription;
  StreamSubscription<dynamic>? _transitionSubscription;
  MeloPalette _palette = MeloPalette.fallback;
  bool _showLyrics = false;

  @override
  void initState() {
    super.initState();
    _isLoadingLyrics = true;
    _queueSignature = _signatureForQueue(widget.audioHandler.queue.value);
    _playbackSignature = _signatureForPlayback(
      widget.audioHandler.playbackState.value,
    );
    _queueSubscription = widget.audioHandler.queue.listen((items) {
      final signature = _signatureForQueue(items);
      if (signature == _queueSignature) return;
      _queueSignature = signature;
      unawaited(_refreshTransitionCues());
    });
    _playbackSubscription = widget.audioHandler.playbackState.listen((state) {
      final signature = _signatureForPlayback(state);
      if (signature == _playbackSignature) return;
      _playbackSignature = signature;
      unawaited(_refreshTransitionCues());
    });
    _transitionSubscription = widget.audioHandler.customEvent.listen(
      _handleTransitionEvent,
    );
    unawaited(_restoreLyrics(widget.item));
    unawaited(_resolvePalette(widget.item));
    unawaited(_refreshTransitionCues());
  }

  @override
  void didUpdateWidget(covariant _NowPlayingContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _lyrics = null;
      _isLoadingLyrics = true;
      unawaited(_restoreLyrics(widget.item));
      unawaited(_resolvePalette(widget.item));
      unawaited(_refreshTransitionCues());
    }
  }

  @override
  void dispose() {
    _analysisRequest++;
    unawaited(_queueSubscription?.cancel());
    unawaited(_playbackSubscription?.cancel());
    unawaited(_transitionSubscription?.cancel());
    super.dispose();
  }

  void _handleTransitionEvent(dynamic event) {
    if (event is! Map || event['type'] is! String) return;
    switch (event['type']) {
      case 'autoMix.transitionStarted':
        final durationMs = event['durationMs'];
        if (durationMs is! int || durationMs <= 0) return;
        if (!mounted) return;
        setState(() {
          _isTransitioning = true;
          _transitionProgress = 0;
          _transitionDuration = Duration(milliseconds: durationMs);
        });
        break;
      case 'autoMix.transitionProgress':
        final progress = event['progress'];
        final durationMs = event['durationMs'];
        if (progress is! num ||
            !progress.isFinite ||
            durationMs is! int ||
            durationMs <= 0) {
          return;
        }
        if (!mounted) return;
        setState(() {
          _isTransitioning = true;
          _transitionProgress = progress.toDouble().clamp(0, 1).toDouble();
          _transitionDuration = Duration(milliseconds: durationMs);
        });
        break;
      case 'autoMix.transitionEnded':
        if (!mounted) return;
        setState(() {
          _isTransitioning = false;
          _transitionProgress = 0;
          _transitionDuration = null;
        });
        break;
    }
  }

  String _signatureForQueue(List<MediaItem> items) =>
      items.map((item) => item.id).join('\u0000');

  String _signatureForPlayback(PlaybackState state) =>
      '${state.queueIndex}:${state.shuffleMode.name}:${state.repeatMode.name}';

  String? get _transitionCueLabel {
    if (_isAnalyzingTransition) return 'Analyzing current + next';
    if (_transitionAnalysisFailed) return 'Waveform cues unavailable';
    if (_analysisUnsupported) return 'Waveform cues available on Android';
    if (!_hasAnalysisTarget) return null;

    final parts = <String>[];
    final outro = _outgoingCues?.quietOutroStart;
    if (outro != null) {
      parts.add('Quiet outro ${_formatTime(outro.inMilliseconds)}');
    }
    final intro = _incomingCues?.quietIntroEnd;
    if (intro != null) {
      parts.add('Quiet intro ${_formatTime(intro.inMilliseconds)}');
    }
    if (parts.isEmpty) return 'No quiet intro/outro detected';
    return parts.join(' · ');
  }

  Future<void> _refreshTransitionCues() async {
    final request = ++_analysisRequest;
    final item = widget.item;
    if (!mounted) return;
    if (defaultTargetPlatform != TargetPlatform.android) {
      setState(() {
        _isAnalyzingTransition = false;
        _analysisUnsupported = true;
        _transitionAnalysisFailed = false;
        _hasAnalysisTarget = false;
        _outgoingCues = null;
        _incomingCues = null;
        _nextTrackTitle = null;
      });
      return;
    }

    setState(() {
      _isAnalyzingTransition = true;
      _analysisUnsupported = false;
      _transitionAnalysisFailed = false;
      _hasAnalysisTarget = false;
      _outgoingCues = null;
      _incomingCues = null;
      _nextTrackTitle = null;
    });
    try {
      final nextValue = await widget.audioHandler.customAction(
        'autoMix.getNextTrackForAnalysis',
      );
      if (!mounted || request != _analysisRequest) return;
      if (nextValue == null) {
        setState(() {
          _isAnalyzingTransition = false;
          _hasAnalysisTarget = false;
        });
        return;
      }
      if (nextValue is! Map || nextValue['id'] is! String) {
        throw const FormatException(
          'The queue returned an invalid next-track analysis target.',
        );
      }

      final nextId = nextValue['id']! as String;
      if (nextId == item.id) {
        setState(() {
          _isAnalyzingTransition = false;
          _hasAnalysisTarget = false;
        });
        return;
      }
      final nextItem = widget.audioHandler.queue.value
          .where((queuedItem) => queuedItem.id == nextId)
          .firstOrNull;
      final nextDurationMs = nextValue['durationMs'];
      final incoming =
          nextItem ??
          MediaItem(
            id: nextId,
            title: nextValue['title'] is String
                ? nextValue['title']! as String
                : 'Next track',
            duration: nextDurationMs is int && nextDurationMs > 0
                ? Duration(milliseconds: nextDurationMs)
                : null,
          );
      final currentDuration = item.duration;
      final incomingDuration = incoming.duration;
      if (currentDuration == null || incomingDuration == null) {
        throw StateError('Track durations are required for energy markers.');
      }

      final waveforms = await Future.wait([
        _audioWaveformFor(item),
        _audioWaveformFor(incoming),
      ]);
      if (!mounted || request != _analysisRequest) return;

      const analyzer = WaveformTransitionAnalyzer();
      setState(() {
        _outgoingCues = analyzer.analyze(
          trackId: item.id,
          duration: currentDuration,
          amplitudes: waveforms[0].amplitudes,
        );
        _incomingCues = analyzer.analyze(
          trackId: incoming.id,
          duration: incomingDuration,
          amplitudes: waveforms[1].amplitudes,
        );
        _nextTrackTitle = incoming.title;
        _hasAnalysisTarget = true;
        _isAnalyzingTransition = false;
      });
    } on Object {
      if (!mounted || request != _analysisRequest) return;
      setState(() {
        _transitionAnalysisFailed = true;
        _hasAnalysisTarget = true;
        _isAnalyzingTransition = false;
      });
    }
  }

  Future<void> _resolvePalette(MediaItem item) async {
    final artworkPalette = await _paletteForItem(item);
    if (!mounted || widget.item.id != item.id) return;
    setState(() => _palette = _paletteFor(item, artworkPalette));
  }

  Future<void> _restoreLyrics(MediaItem item) async {
    try {
      final lyrics = await LyricsRepository.loadFor(item);
      if (!mounted || widget.item.id != item.id) return;
      setState(() {
        _lyrics = lyrics;
      });

      // Automatically search and fetch lyrics online in background when enabled
      if (lyrics == null && await LyricsRepository.onlineLookupEnabled) {
        unawaited(() async {
          try {
            final online = await LyricsRepository.findOnlineFor(item);
            if (mounted && widget.item.id == item.id && online != null) {
              setState(() => _lyrics = online);
            }
          } catch (_) {}
        }());
      }
    } on LyricsServiceUnavailableException {
      // Online lookup is optional; the player simply keeps local lyrics.
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'tone player',
          context: ErrorDescription('while loading local song lyrics'),
        ),
      );
      if (mounted && widget.item.id == item.id) {
        _showMessage('Could not load saved lyrics: $error');
      }
    } finally {
      if (mounted && widget.item.id == item.id) {
        setState(() => _isLoadingLyrics = false);
      }
    }
  }

  Future<void> _findLyrics() async {
    final item = widget.item;
    setState(() {
      _isLoadingLyrics = true;
    });
    try {
      final lyrics = await LyricsRepository.importFor(item);
      if (!mounted || widget.item.id != item.id) return;
      setState(() {
        _lyrics = lyrics;
      });
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'tone player',
          context: ErrorDescription('while importing song lyrics'),
        ),
      );
      if (mounted) _showMessage('Could not add lyrics: $error');
    } finally {
      if (mounted) setState(() => _isLoadingLyrics = false);
    }
  }

  /// Tempo embedded in the track's tags, if the file carries one.
  double? get _trackBpm {
    final bpm = (widget.item.extras?['bpm'] as num?)?.toDouble();
    return bpm != null && bpm > 0 ? bpm : null;
  }

  Future<void> _startTrackRadio() async {
    final item = widget.item;
    _showMessage('Starting ${item.title} Radio (Continuous autoplay)...');
    try {
      final radio = await SmartPlaylistService.instance.generateTrackRadio(
        seedTrack: item,
        library: widget.musicLibrary,
      );
      await SmartPlaylistService.instance.playSmartPlaylist(
        audioHandler: widget.audioHandler,
        playlist: radio,
      );
      if (mounted) {
        _showMessage('Radio started · ${radio.tracks.length} continuous tracks queued.');
      }
    } catch (e) {
      if (mounted) _showMessage('Could not start track radio: $e');
    }
  }

  Future<void> _playArtistRadio() async {
    final artist = widget.item.artist?.trim();
    if (artist == null ||
        artist.isEmpty ||
        artist.toLowerCase() == 'unknown artist' ||
        artist.toLowerCase() == 'on-device audio') {
      _showMessage('Artist radio needs a known artist.');
      return;
    }
    final library = widget.musicLibrary;
    if (library != null &&
        LocalDiscovery.artistRadio(library.tracks, artist).isNotEmpty) {
      await library.playArtistRadio(widget.audioHandler, artist);
      if (mounted) _showMessage('Playing $artist radio.');
      return;
    }
    _showMessage('Starting $artist Radio (Continuous stream)...');
    try {
      final radio = await SmartPlaylistService.instance.generateArtistRadio(
        artist: artist,
        library: widget.musicLibrary,
        artworkUri: widget.item.artUri?.toString(),
      );
      await SmartPlaylistService.instance.playSmartPlaylist(
        audioHandler: widget.audioHandler,
        playlist: radio,
      );
      if (mounted) _showMessage('Playing $artist continuous radio.');
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'tone player',
          context: ErrorDescription('while starting Now Playing artist radio'),
        ),
      );
      if (mounted) _showMessage('Could not start artist radio: $error');
    }
  }

  void _openTrackDetails() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.48),
      builder: (context) => TrackDetailsSheet(
        item: widget.item,
        onEnrichMetadata: () {
          Navigator.of(context).pop();
          unawaited(_enrichTrackMetadata());
        },
      ),
    );
  }

  void _retryWaveform() {
    _audioWaveformCache.remove(widget.item.id);
    setState(() {});
  }

  Future<void> _findLyricsOnline() async {
    final item = widget.item;
    try {
      if (!await LyricsRepository.onlineLookupEnabled) {
        if (!mounted) return;
        final approved = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Find lyrics online?'),
            content: const Text(
              'Melo will send this song’s title, artist, album, and duration to '
              'LRCLIB to find matching lyrics. Your listening history is not sent. '
              'You can turn automatic online lyrics off in Privacy & your data.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Not now'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Enable & search'),
              ),
            ],
          ),
        );
        if (approved != true) return;
        await LyricsRepository.setOnlineLookupEnabled(true);
      }

      if (!mounted) return;
      setState(() => _isLoadingLyrics = true);
      final lyrics = await LyricsRepository.findOnlineFor(item);
      if (!mounted || widget.item.id != item.id) return;
      setState(() {
        _lyrics = lyrics;
      });
      if (lyrics == null) {
        _showMessage('No matching lyrics found. You can add a lyrics file.');
      }
    } on LyricsServiceUnavailableException catch (error) {
      if (mounted && widget.item.id == item.id) {
        _showMessage('$error Try again in a little while.');
      }
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'tone player',
          context: ErrorDescription('while enabling or finding online lyrics'),
        ),
      );
      if (mounted) _showMessage('Could not search online for lyrics: $error');
    } finally {
      if (mounted) setState(() => _isLoadingLyrics = false);
    }
  }

  Future<void> _toggleFavorite(String trackId) async {
    final library = widget.musicLibrary;
    if (library == null) {
      _showMessage('Favorites are unavailable in this preview.');
      return;
    }
    try {
      final isFavorite = await library.toggleFavorite(trackId);
      if (!mounted) return;
      _showMessage(
        isFavorite ? 'Added to favorites.' : 'Removed from favorites.',
      );
    } on Object catch (error) {
      if (!mounted) return;
      _showMessage('Could not update favorite: $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  void _openLyrics() {
    final lyrics = _lyrics;
    if (lyrics == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (context) => _FullLyricsSheet(
        title: widget.item.title,
        artist: displayArtistName(widget.item.artist),
        lyrics: lyrics,
        audioHandler: widget.audioHandler,
      ),
    );
  }

  void _openQueue() {
    showPlayerQueue(context, widget.audioHandler);
  }

  Future<void> _toggleTransition() async {
    if (_isTransitioning) {
      try {
        await widget.audioHandler.customAction('autoMix.cancelTransition', {
          'reason': 'userCancelled',
        });
      } on Object catch (error, stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'tone player',
            context: ErrorDescription('while cancelling a manual crossfade'),
          ),
        );
        if (mounted) _showMessage('Could not cancel the crossfade: $error');
      }
      return;
    }

    setState(() {
      _isTransitioning = true;
      _transitionProgress = 0;
      _transitionDuration = null;
    });
    try {
      final result = await widget.audioHandler.customAction(
        'autoMix.transitionToNextTrack',
      );
      if (result is! Map || result['completed'] is! bool) {
        throw StateError(
          'The audio handler returned an invalid transition result.',
        );
      }
      if (!mounted) return;
      if (result['completed'] == true) {
        final nextTrackId = result['trackId'];
        MediaItem? nextTrack;
        for (final item in widget.audioHandler.queue.value) {
          if (item.id == nextTrackId) {
            nextTrack = item;
            break;
          }
        }
        _showMessage(
          nextTrack == null
              ? 'Crossfade complete.'
              : 'Crossfaded to ${nextTrack.title}.',
        );
      } else {
        _showMessage('Crossfade cancelled.');
      }
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'tone player',
          context: ErrorDescription('while starting a manual crossfade'),
        ),
      );
      if (mounted) {
        _showMessage('Could not crossfade to the next track: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTransitioning = false;
          _transitionProgress = 0;
          _transitionDuration = null;
        });
      }
    }
  }

  Future<void> _handleMenu(String action) async {
    if (action == 'lyrics') {
      await _findLyrics();
    } else if (action == 'online-lyrics') {
      await _findLyricsOnline();
    } else if (action == 'enrich-metadata') {
      await _enrichTrackMetadata();
    } else if (action == 'read-lyrics') {
      _openLyrics();
    } else if (action == 'queue') {
      _openQueue();
    } else if (action == 'details') {
      _openTrackDetails();
    } else if (action == 'track-radio') {
      await _startTrackRadio();
    } else if (action == 'artist-radio') {
      await _playArtistRadio();
    } else if (action == 'save-device') {
      await _saveCurrentStreamToDevice();
    }
  }

  Future<void> _enrichTrackMetadata() async {
    final item = widget.item;
    _showMessage('Downloading lyrics, artwork & metadata for "${item.title}"...');
    setState(() => _isLoadingLyrics = true);
    try {
      final enriched = await SongMetadataEnricher.instance.enrichAndSaveForMediaItem(
        item: item,
        library: widget.musicLibrary,
      );
      _audioTagsCache.remove(item.id);
      if (!mounted || widget.item.id != item.id) return;
      final lyrics = await LyricsRepository.loadFor(item);
      if (!mounted || widget.item.id != item.id) return;
      setState(() {
        if (lyrics != null) {
          _lyrics = lyrics;
        }
      });
      final updatedParts = <String>[
        'metadata',
        if (enriched.artworkUrl != null) 'high-res artwork',
        if (enriched.lyricsContent != null || lyrics != null) 'lyrics',
      ];
      _showMessage('Downloaded ${updatedParts.join(', ')} for "${enriched.title}".');
    } on Object catch (error) {
      if (mounted) {
        _showMessage('Could not download metadata: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingLyrics = false);
      }
    }
  }

  bool _isSavingToDevice = false;

  bool get _isStreamTrack {
    final item = widget.item;
    if (item.id.startsWith('/') || item.id.startsWith('file:')) return false;
    return item.extras?['isLiveStream'] == true ||
        item.id.startsWith('youtube:') ||
        item.id.startsWith('spotify:') ||
        item.extras?['source'] == 'youtube' ||
        item.extras?['source'] == 'spotify' ||
        item.extras?['matchedYoutubeId'] != null;
  }

  bool get _isCurrentTrackAlreadyOnDevice {
    final library = widget.musicLibrary;
    if (library == null) return false;
    final item = widget.item;
    final rawId =
        item.extras?['providerTrackId'] as String? ??
        item.extras?['matchedYoutubeId'] as String? ??
        (item.id.startsWith('youtube:') ? item.id.substring(8) : null);
    return library.isTrackDownloaded(
      providerTrackId: rawId,
      title: item.title,
      artist: item.artist,
    );
  }

  Future<void> _saveCurrentStreamToDevice() async {
    final library = widget.musicLibrary;
    if (library == null) {
      _showMessage('Library is unavailable in this preview.');
      return;
    }
    if (_isSavingToDevice) return;
    final item = widget.item;
    final rawId =
        item.extras?['providerTrackId'] as String? ??
        item.extras?['matchedYoutubeId'] as String? ??
        (item.id.startsWith('youtube:') ? item.id.substring(8) : null);
    if (_isCurrentTrackAlreadyOnDevice) {
      _showMessage('"${item.title}" is already saved on your device.');
      return;
    }
    final chosenQuality = await LosslessAudioService.instance.selectDownloadQuality(
      context,
      title: item.title,
      artist: item.artist,
    );
    if (chosenQuality == null || !mounted) return;

    setState(() => _isSavingToDevice = true);
    _showMessage(
      'Downloading "${item.title}" in ${chosenQuality.shortLabel} to Music/Tone...',
    );
    try {
      String? targetYtId = rawId;
      if (targetYtId == null || targetYtId.isEmpty || item.id.startsWith('spotify:')) {
        final results = await YoutubeAudioService.instance.search(
          '${item.title} ${item.artist ?? ''}',
        );
        if (results.isEmpty) {
          throw StateError('No matching stream found to save.');
        }
        targetYtId = results.first.id;
      }
      final ytTrack = YoutubeTrack(
        id: targetYtId,
        title: item.title,
        author: item.artist ?? 'Unknown artist',
        album: item.album,
        duration: item.duration ?? Duration.zero,
        thumbnailUrl: item.artUri?.toString(),
      );
      await YoutubeAudioService.instance.downloadTrack(
        track: ytTrack,
        library: library,
        qualityOverride: chosenQuality,
        onProgress: (_) {},
      );
      if (mounted) {
        _showMessage(
          'Saved "${item.title}" (${chosenQuality.shortLabel} + Artwork & Lyrics) to Music/Tone.',
        );
      }
    } on Object catch (error) {
      if (mounted) {
        _showMessage('Could not save "${item.title}": $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingToDevice = false);
      }
    }
  }

  void _cycleRepeat(AudioServiceRepeatMode current) {
    final next = switch (current) {
      AudioServiceRepeatMode.none => AudioServiceRepeatMode.all,
      AudioServiceRepeatMode.all ||
      AudioServiceRepeatMode.group => AudioServiceRepeatMode.one,
      AudioServiceRepeatMode.one => AudioServiceRepeatMode.none,
    };
    HapticFeedback.selectionClick();
    _run(context, () => widget.audioHandler.setRepeatMode(next));
  }

  void _toggleShuffle(AudioServiceShuffleMode current) {
    final next = current == AudioServiceShuffleMode.all
        ? AudioServiceShuffleMode.none
        : AudioServiceShuffleMode.all;
    HapticFeedback.selectionClick();
    _run(context, () => widget.audioHandler.setShuffleMode(next));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlaybackState>(
      stream: widget.audioHandler.playbackState,
      builder: (context, stateSnapshot) {
        final state = stateSnapshot.data;
        final playing = state?.playing == true;
        final duration = widget.item.duration ?? Duration.zero;
        final trackId =
            widget.item.extras?['libraryId'] as String? ?? widget.item.id;
        return Stack(
          fit: StackFit.expand,
          children: [
            _ArtworkBackdrop(palette: _palette),
            const _PlayerScrim(),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 780),
                  child: Column(
                    children: [
                      // Subtle top drag handle affordance
                      Center(
                        child: Container(
                          width: 38,
                          height: 4.5,
                          margin: const EdgeInsets.only(top: 6, bottom: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.28),
                            borderRadius: BorderRadius.circular(MeloRadii.pill),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                        child: MeloGlass(
                          borderRadius: 24,
                          tint: Colors.black.withValues(alpha: 0.32),
                          borderColor: Colors.white.withValues(alpha: 0.08),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                tooltip: 'Close player',
                                onPressed: () =>
                                    Navigator.of(context).maybePop(),
                                color: MeloColors.playerText,
                                icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 28,
                                ),
                              ),
                              const Expanded(
                                child: Text(
                                  'NOW PLAYING',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: MeloColors.playerText,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.4,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: _showLyrics
                                    ? 'Show artwork'
                                    : 'Show live lyrics',
                                onPressed: () {
                                  setState(() => _showLyrics = !_showLyrics);
                                },
                                style: IconButton.styleFrom(
                                  backgroundColor: _showLyrics
                                      ? MeloColors.cherry.withValues(
                                          alpha: 0.22,
                                        )
                                      : null,
                                ),
                                color: _showLyrics
                                    ? MeloColors.cherrySoft
                                    : MeloColors.playerText,
                                icon: Icon(
                                  _showLyrics
                                      ? Icons.album_rounded
                                      : Icons.lyrics_rounded,
                                  size: 22,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Up next',
                                onPressed: _openQueue,
                                color: MeloColors.playerText,
                                icon: const Icon(
                                  Icons.queue_music_rounded,
                                  size: 22,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: MeloMotion.slow,
                          switchInCurve: MeloMotion.emphasized,
                          switchOutCurve: MeloMotion.emphasized,
                          transitionBuilder: _safeFadeSwitcherTransition,
                          layoutBuilder: _safeAnimatedSwitcherLayout,
                          child: _showLyrics
                              ? _NowPlayingLyrics(
                                  key: const ValueKey('now-playing-lyrics'),
                                  lyrics: _lyrics,
                                  isLoading: _isLoadingLyrics,
                                  audioHandler: widget.audioHandler,
                                  palette: _palette,
                                  onBackToArtwork: () {
                                    setState(() => _showLyrics = false);
                                  },
                                  onFindOnline: _findLyricsOnline,
                                  onImportFile: _findLyrics,
                                )
                              : LayoutBuilder(
                                  key: const ValueKey('now-playing-artwork'),
                                  builder: (context, constraints) {
                                    final artSize = math
                                        .min(
                                          constraints.maxWidth - 36,
                                          constraints.maxHeight * 0.96,
                                        )
                                        .clamp(0.0, 380.0);
                                    return Center(
                                      child: GestureDetector(
                                        onTap: () =>
                                            setState(() => _showLyrics = true),
                                        child: _BeatPulse(
                                          audioHandler: widget.audioHandler,
                                          bpm: _trackBpm,
                                          live: true,
                                          palette: _palette,
                                          child: AnimatedScale(
                                            scale: playing ? 1.0 : 0.92,
                                            duration: MeloMotion.slow,
                                            curve: MeloMotion.emphasized,
                                            child: AnimatedContainer(
                                              duration: MeloMotion.slow,
                                              curve: MeloMotion.emphasized,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(22),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: _palette.accent
                                                        .withValues(
                                                          alpha: playing
                                                              ? 0.44
                                                              : 0.20,
                                                        ),
                                                    blurRadius: playing
                                                        ? 56
                                                        : 30,
                                                    spreadRadius: playing
                                                        ? 0
                                                        : -4,
                                                    offset: const Offset(0, 24),
                                                  ),
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withValues(
                                                          alpha: playing
                                                              ? 0.58
                                                              : 0.42,
                                                        ),
                                                    blurRadius: playing
                                                        ? 40
                                                        : 24,
                                                    offset: const Offset(0, 20),
                                                  ),
                                                ],
                                              ),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(22),
                                                  border: Border.all(
                                                    color: Colors.white
                                                        .withValues(alpha: 0.14),
                                                    width: 1.2,
                                                  ),
                                                ),
                                                child: Hero(
                                                  tag:
                                                      'tone-art-${widget.item.id}',
                                                  child: AlbumArtwork(
                                                    size: artSize,
                                                    title: widget.item.title,
                                                    iconSize: 76,
                                                    artworkUri:
                                                        widget.item.artUri,
                                                    sourceUri: Uri.tryParse(
                                                      widget.item.id,
                                                    ),
                                                    borderRadius: 22,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 6, 10, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: _openTrackDetails,
                                borderRadius: BorderRadius.circular(14),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.item.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall
                                            ?.copyWith(
                                              color: MeloColors.playerText,
                                              fontSize: 23,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: -0.6,
                                              height: 1.2,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        displayArtistName(
                                          widget.item.artist,
                                          fallback:
                                              widget.item.album == null ||
                                                  widget.item.album ==
                                                      'Unknown album'
                                              ? 'From your library'
                                              : widget.item.album,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: MeloColors.playerMuted,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(height: 8),
                                      _AudioQualityBadges(item: widget.item),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            AnimatedBuilder(
                              animation:
                                  widget.musicLibrary ??
                                  _NoopListenable.instance,
                              builder: (context, _) {
                                final favorite =
                                    widget.musicLibrary?.isFavorite(trackId) ??
                                    false;
                                final onDevice = _isCurrentTrackAlreadyOnDevice;
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_isStreamTrack &&
                                        widget.musicLibrary != null)
                                      _isSavingToDevice
                                          ? const Padding(
                                              padding: EdgeInsets.all(10),
                                              child: SizedBox(
                                                width: 22,
                                                height: 22,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2.2,
                                                      color: MeloColors.cherry,
                                                    ),
                                              ),
                                            )
                                          : IconButton(
                                              tooltip: onDevice
                                                  ? 'Saved on device'
                                                  : 'Download to device',
                                              onPressed: onDevice
                                                  ? null
                                                  : _saveCurrentStreamToDevice,
                                              icon: Icon(
                                                onDevice
                                                    ? Icons
                                                          .download_done_rounded
                                                    : Icons
                                                          .download_for_offline_outlined,
                                                color: onDevice
                                                    ? Colors.greenAccent
                                                    : MeloColors.playerMuted,
                                                size: 24,
                                              ),
                                            ),
                                    _NowPlayingFavoriteButton(
                                      isFavorite: favorite,
                                      onTap: () => _toggleFavorite(trackId),
                                    ),
                                  ],
                                );
                              },
                            ),
                            PopupMenuButton<String>(
                              tooltip: 'More options',
                              onSelected: _handleMenu,
                              itemBuilder: (context) => [
                                if (widget.audioHandler.queue.value.length > 1)
                                  const PopupMenuItem(
                                    value: 'queue',
                                    child: Text('Up next'),
                                  ),
                                const PopupMenuItem(
                                  value: 'details',
                                  child: Text('Track details'),
                                ),
                                if (_lyrics != null)
                                  const PopupMenuItem(
                                    value: 'read-lyrics',
                                    child: Text('Read lyrics'),
                                  ),
                                PopupMenuItem(
                                  value: 'online-lyrics',
                                  enabled: !_isLoadingLyrics,
                                  child: const Text('Find lyrics online'),
                                ),
                                PopupMenuItem(
                                  value: 'enrich-metadata',
                                  enabled: !_isLoadingLyrics,
                                  child: const Text('Download lyrics & metadata'),
                                ),
                                PopupMenuItem(
                                  value: 'lyrics',
                                  enabled: !_isLoadingLyrics,
                                  child: Text(
                                    _lyrics == null
                                        ? 'Choose lyrics file'
                                        : 'Replace lyrics',
                                  ),
                                ),
                                if (_isStreamTrack &&
                                    widget.musicLibrary != null &&
                                    !_isCurrentTrackAlreadyOnDevice)
                                  const PopupMenuItem(
                                    value: 'save-device',
                                    child: Text('Save to device'),
                                  ),
                                const PopupMenuItem(
                                  value: 'track-radio',
                                  child: Text('Start track radio'),
                                ),
                                const PopupMenuItem(
                                  value: 'artist-radio',
                                  child: Text('Start artist radio'),
                                ),
                              ],
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.06),
                                ),
                                child: const Icon(
                                  Icons.more_horiz_rounded,
                                  color: MeloColors.playerMuted,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!_showLyrics && _lyrics != null && _lyrics!.lines.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                          child: _LyricsPeek(
                            key: ValueKey('lyrics-peek-$trackId'),
                            lyrics: _lyrics!,
                            audioHandler: widget.audioHandler,
                            palette: _palette,
                            onExpand: () {
                              setState(() => _showLyrics = true);
                            },
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                        child: MeloGlass(
                          borderRadius: 32,
                          tint: Colors.black.withValues(alpha: 0.44),
                          borderColor: Colors.white.withValues(alpha: 0.12),
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: StreamBuilder<Duration>(
                                  stream: playbackPositionStream(
                                    widget.audioHandler,
                                  ),
                                  builder: (context, positionSnapshot) {
                                    final position =
                                        _dragPosition ??
                                        (positionSnapshot.data ?? Duration.zero)
                                            .inMilliseconds
                                            .toDouble();
                                    final max = duration.inMilliseconds
                                        .toDouble()
                                        .clamp(1.0, double.infinity);
                                    return FutureBuilder<AudioWaveformData>(
                                      future: _audioWaveformFor(widget.item),
                                      builder: (context, waveformSnapshot) =>
                                          _PlaybackSeekBar(
                                            value: position.clamp(0, max),
                                            max: max,
                                            duration: duration,
                                            bufferedPosition:
                                                state?.bufferedPosition,
                                            waveform: waveformSnapshot
                                                .data
                                                ?.amplitudes,
                                            waveformError:
                                                waveformSnapshot.error,
                                            bpm: _trackBpm,
                                            mixMarkerPosition:
                                                (_outgoingCues
                                                            ?.outroConfidence ??
                                                        0) >=
                                                    0.6
                                                ? _outgoingCues?.quietOutroStart
                                                : null,
                                            onRetry: _retryWaveform,
                                            onChanged: (value) => setState(
                                              () => _dragPosition = value,
                                            ),
                                            onChangeEnd: (value) {
                                              setState(
                                                () => _dragPosition = null,
                                              );
                                              _run(
                                                context,
                                                () => widget.audioHandler.seek(
                                                  Duration(
                                                    milliseconds: value.round(),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 4),
                              _PlaybackControls(
                                playing: playing,
                                shuffleMode:
                                    state?.shuffleMode ??
                                    AudioServiceShuffleMode.none,
                                repeatMode:
                                    state?.repeatMode ??
                                    AudioServiceRepeatMode.none,
                                onShuffle: () => _toggleShuffle(
                                  state?.shuffleMode ??
                                      AudioServiceShuffleMode.none,
                                ),
                                onPrevious: () => _run(
                                  context,
                                  widget.audioHandler.skipToPrevious,
                                ),
                                onToggle: () => _run(
                                  context,
                                  playing
                                      ? widget.audioHandler.pause
                                      : widget.audioHandler.play,
                                ),
                                onNext: () => _run(
                                  context,
                                  widget.audioHandler.skipToNext,
                                ),
                                onRepeat: () => _cycleRepeat(
                                  state?.repeatMode ??
                                      AudioServiceRepeatMode.none,
                                ),
                              ),
                              if (widget.audioHandler.queue.value.length > 1 ||
                                  _isTransitioning) ...[
                                const SizedBox(height: 8),
                                _MixNextControl(
                                  transitioning: _isTransitioning,
                                  enabled: _isTransitioning || playing,
                                  accent: _palette.accent,
                                  progress: _transitionProgress,
                                  transitionDuration: _transitionDuration,
                                  analysisHint: _transitionCueLabel,
                                  nextTrackTitle: _nextTrackTitle,
                                  onPressed: () =>
                                      unawaited(_toggleTransition()),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (widget.onNavigate case final onNavigate?)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
                          child: MeloGlass(
                            borderRadius: 26,
                            tint: Colors.black.withValues(alpha: 0.44),
                            borderColor: Colors.white.withValues(alpha: 0.10),
                            child: _PlayerBottomNavigation(
                              onNavigate: onNavigate,
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: 14),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PlayerBottomNavigation extends StatelessWidget {
  const _PlayerBottomNavigation({required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) => NavigationBarTheme(
    data: NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: MeloColors.cherry.withValues(alpha: 0.24),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? MeloColors.cherry
              : MeloColors.playerMuted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? MeloColors.cherry
              : MeloColors.playerMuted,
        ),
      ),
    ),
    child: NavigationBar(
      height: 64,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      selectedIndex: 0,
      onDestinationSelected: onNavigate,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.library_music_outlined),
          selectedIcon: Icon(Icons.library_music_rounded),
          label: 'Library',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'You',
        ),
      ],
    ),
  );
}
