import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:melo_player/features/auto_mix/audio_engine.dart';
import 'package:melo_player/features/auto_mix/auto_mix_controller.dart';
import 'package:melo_player/features/auto_mix/just_audio_dual_deck_engine.dart';
import 'package:melo_player/features/auto_mix/auto_mix_settings.dart';
import 'package:melo_player/features/auto_mix/auto_mix_profile.dart';
import 'package:melo_player/features/auto_mix/track_analysis.dart';
import 'package:melo_player/features/auto_mix/transition_diagnostic.dart';
import 'package:melo_player/features/auto_mix/transition_plan.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:melo_player/features/library/music_library.dart';
import 'package:melo_player/features/library/song_metadata_enricher.dart';
import 'package:melo_player/features/player/audio_profile.dart';
import 'package:melo_player/features/player/lyrics_repository.dart';
import 'package:melo_player/features/youtube/youtube_audio_service.dart';

class MeloAudioHandler extends BaseAudioHandler with SeekHandler {
  MeloAudioHandler({
    AudioEngine? audioEngine,
    TransitionDelay? transitionDelay,
    Duration transitionGainStep = AutoMixController.defaultGainStep,
  }) {
    _playerFilter = _PlayerFilter(_dspSupported ? AndroidEqualizer() : null);
    _incomingPlayerFilter = _PlayerFilter(
      _dspSupported ? AndroidEqualizer() : null,
    );
    _audioEngine =
        audioEngine ??
        JustAudioDualDeckEngine(
          playerFactory: JustAudioDeckPlayerFactory(
            primaryAudioPipeline: _playerFilter.pipeline,
            secondaryAudioPipeline: _incomingPlayerFilter.pipeline,
          ),
        );
    _autoMixController = AutoMixController(
      audioEngine: _audioEngine,
      delay: transitionDelay,
      gainStep: transitionGainStep,
    );
    _listenToPlayer();
    _settingsReady = _initialize();
  }

  static const _audioProfileKey = 'tone_audio_profile';
  static const _repeatModeKey = 'tone_playback_repeat_mode';
  static const _shuffleModeKey = 'tone_playback_shuffle_mode';
  static const _autoplayContinuousKey = 'tone_autoplay_continuous';

  /// Real hardware filtering is only reachable on Android.
  static bool get _dspSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// The player's actual position, so progress never relies on projection.
  Stream<Duration> get positionStream => _positions.stream;
  Duration get currentPosition => _audioEngine.stateFor(AudioDeck.a).position;
  final StreamController<Duration> _positions =
      StreamController<Duration>.broadcast();

  late final _PlayerFilter _playerFilter;
  late final _PlayerFilter _incomingPlayerFilter;
  late final AudioEngine _audioEngine;
  late final AutoMixController _autoMixController;
  late final Future<void> _settingsReady;
  final List<StreamSubscription<dynamic>> _playerSubscriptions = [];
  final List<StreamSubscription<dynamic>> _audioSessionSubscriptions = [];
  AudioSession? _audioSession;

  List<MediaItem> _items = const [];
  List<int> _playOrder = const [];
  int _currentIndex = 0;
  int _orderPosition = 0;
  bool _isAdvancing = false;
  bool _automaticTransitionPending = false;
  String? _automaticTransitionAttempt;
  bool _transitionCancelRequested = false;
  String? _transitionCancellationReason;
  int? _preloadedQueueIndex;
  int? _loadingQueueIndex;
  int _preloadGeneration = 0;
  bool _isLoadingTrack = false;
  int _activeLoadId = 0;
  bool _desiredPlaying = false;
  Future<void>? _activeTransitionOperation;
  TransitionDiagnostic? _activeDiagnostic;
  bool _audioSessionActive = false;
  bool _interruptionActive = false;
  bool _resumeAfterInterruption = false;
  AudioServiceRepeatMode _repeatMode = AudioServiceRepeatMode.none;
  AudioServiceShuffleMode _shuffleMode = AudioServiceShuffleMode.none;
  AudioProfile _audioProfile = const AudioProfile();
  AutoMixSettings _autoMixSettings = AutoMixSettings();
  MusicLibrary? _musicLibrary;
  DateTime? _lastPlatformStatePublishTime;
  AudioProcessingState? _lastPublishedProcessingState;
  bool? _lastPublishedPlaying;
  int? _lastPublishedIndex;
  bool? _lastPublishedLiked;
  AudioServiceRepeatMode? _lastPublishedRepeatMode;

  bool _autoplayContinuous = true;
  bool _isExtendingAutoplay = false;
  double _userVolume = 1.0;

  double get _effectiveTargetGain =>
      (_userVolume * _audioProfile.outputHeadroom).clamp(0.0, 1.0);
  final List<MediaItem> _sessionHistory = [];
  final Map<String, Duration> _incomingTrackCues = {};
  final Map<String, Duration> _outgoingTrackCues = {};

  void _recordSessionItem(MediaItem item) {
    _sessionHistory.removeWhere((existing) => existing.id == item.id);
    _sessionHistory.insert(0, item);
    if (_sessionHistory.length > 30) {
      _sessionHistory.removeRange(30, _sessionHistory.length);
    }
    final library = _musicLibrary;
    if (library != null) {
      unawaited(library.recordPlayedMediaItem(item).catchError((_) {}));
    }
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      unawaited(LyricsRepository.autoDownloadForMediaItem(item));
    }
  }

  bool get autoplayContinuous => _autoplayContinuous;

  Future<void> setAutoplayContinuous(bool enabled) async {
    _autoplayContinuous = enabled;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_autoplayContinuousKey, enabled);
    _publishState();
  }

  void attachMusicLibrary(MusicLibrary library) {
    if (identical(_musicLibrary, library)) return;
    _musicLibrary?.removeListener(_onLibraryChanged);
    _musicLibrary = library;
    library.addListener(_onLibraryChanged);
    _publishState();
  }

  void _onLibraryChanged() {
    _publishState();
  }

  Future<void> _initialize() async {
    await _loadPlaybackSettings();
    await _audioEngine.initialize();
  }

  Future<void> _loadPlaybackSettings() async {
    final preferences = await SharedPreferences.getInstance();
    final savedRepeatMode = preferences.getString(_repeatModeKey);
    if (savedRepeatMode != null) {
      _repeatMode = AudioServiceRepeatMode.values.firstWhere(
        (mode) => mode.name == savedRepeatMode,
        orElse: () => AudioServiceRepeatMode.none,
      );
    }
    final savedShuffleMode = preferences.getString(_shuffleModeKey);
    if (savedShuffleMode != null) {
      _shuffleMode = AudioServiceShuffleMode.values.firstWhere(
        (mode) => mode.name == savedShuffleMode,
        orElse: () => AudioServiceShuffleMode.none,
      );
    }
    final savedProfile = preferences.getString(_audioProfileKey);
    if (savedProfile != null) {
      try {
        final decoded = jsonDecode(savedProfile);
        if (decoded is Map) {
          _audioProfile = AudioProfile.fromJson(
            Map<String, Object?>.from(decoded),
          );
        }
      } catch (error, stackTrace) {
        _reportPlaybackError(
          error,
          stackTrace,
          'while loading saved audio profile; falling back to defaults',
        );
      }
    }
    _playerFilter.applyProfile(_audioProfile);
    _incomingPlayerFilter.applyProfile(_audioProfile);
    _autoMixSettings = await AutoMixSettings.load();
    _autoMixController.updateSettings(_autoMixSettings);
    final savedAutoplay = preferences.getBool(_autoplayContinuousKey);
    if (savedAutoplay != null) {
      _autoplayContinuous = savedAutoplay;
    }
  }

  Future<void> attachAudioSession(AudioSession session) async {
    if (identical(_audioSession, session)) return;
    for (final subscription in _audioSessionSubscriptions) {
      await subscription.cancel();
    }
    _audioSessionSubscriptions.clear();
    _audioSession = session;
    _audioSessionSubscriptions
      ..add(
        session.interruptionEventStream.listen(
          _handleInterruption,
          onError: (Object error, StackTrace stackTrace) =>
              _reportPlaybackError(
                error,
                stackTrace,
                'while monitoring audio interruptions',
              ),
        ),
      )
      ..add(
        session.becomingNoisyEventStream.listen(
          (_) {
            _interruptionActive = false;
            _resumeAfterInterruption = false;
            if (_isAnyDeckPlaying) _runSessionOperation(_pausePlayback());
          },
          onError: (Object error, StackTrace stackTrace) =>
              _reportPlaybackError(
                error,
                stackTrace,
                'while monitoring audio route changes',
              ),
        ),
      );
  }

  void _handleInterruption(AudioInterruptionEvent event) {
    if (event.begin) {
      if (_interruptionActive) return;
      _interruptionActive = true;
      _resumeAfterInterruption = _isAnyDeckPlaying;
      if (_resumeAfterInterruption) {
        _runSessionOperation(_pausePlayback(retainAudioFocus: true));
      }
      return;
    }

    if (!_interruptionActive) return;
    final shouldResume = _resumeAfterInterruption;
    _interruptionActive = false;
    _resumeAfterInterruption = false;
    _runSessionOperation(
      shouldResume ? _startPlayback() : _deactivateAudioSession(),
    );
  }

  void _runSessionOperation(Future<void> operation) {
    unawaited(
      operation.catchError((Object error, StackTrace stackTrace) {
        _reportPlaybackError(
          error,
          stackTrace,
          'while responding to an audio-session event',
        );
      }),
    );
  }

  @override
  Future<dynamic> customAction(
    String name, [
    Map<String, dynamic>? extras,
  ]) async {
    await _settingsReady;
    if (name == 'reorderUpcomingQueue') {
      final oldIndex = extras?['oldIndex'];
      final newIndex = extras?['newIndex'];
      if (oldIndex is! int || newIndex is! int) {
        throw ArgumentError(
          'reorderUpcomingQueue expects integer oldIndex and newIndex values.',
        );
      }
      await reorderUpcomingQueue(oldIndex, newIndex);
      return null;
    }
    if (name == 'clearUpcomingQueue') {
      await clearUpcomingQueue();
      return null;
    }
    if (name == 'setVolume') {
      final vol = (extras?['volume'] as num?)?.toDouble() ?? 1.0;
      _userVolume = vol.clamp(0.0, 1.0);
      final effectiveGain = _effectiveTargetGain;
      if (_audioEngine.stateFor(AudioDeck.a).loaded &&
          !_autoMixController.isTransitioning) {
        await _audioEngine.setDeckGain(AudioDeck.a, effectiveGain);
      }
      return _userVolume;
    }
    if (name == 'getVolume') {
      return _userVolume;
    }
    if (name == 'getAudioProfile') return _audioProfile.toJson();
    if (name == 'getAudioCapabilities') {
      return <String, Object>{
        'equalizer':
            _playerFilter.isAvailable && _incomingPlayerFilter.isAvailable,
        'loudnessNormalization': false,
        'balance': false,
        'outputSelection': false,
        'headphoneProfiles': false,
      };
    }
    if (name == 'setAudioProfile') {
      await _cancelAndWaitForTransition();
      final values = extras?['profile'];
      if (values is! Map) {
        throw const FormatException('Audio profile payload is invalid.');
      }
      final profile = AudioProfile.fromJson(Map<String, Object?>.from(values));
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _audioProfileKey,
        jsonEncode(profile.toJson()),
      );
      _audioProfile = profile;
      _playerFilter.applyProfile(profile);
      _incomingPlayerFilter.applyProfile(profile);
      if (_items.isNotEmpty) {
        await _audioEngine.setDeckGain(
          AudioDeck.a,
          _effectiveTargetGain,
        );
      }
      if (_audioEngine.stateFor(AudioDeck.b).loaded) {
        await _audioEngine.setDeckGain(
          AudioDeck.b,
          _audioEngine.stateFor(AudioDeck.b).playing
              ? _effectiveTargetGain
              : 0.0,
        );
      }
      _publishState();
      return null;
    }
    if (name == 'autoMix.preloadNextTrack') {
      await _preloadNextTrack();
      return null;
    }
    if (name == 'autoMix.getNextTrackForAnalysis') {
      final nextIndex = _nextQueueIndex();
      if (nextIndex == null) return null;
      final nextItem = _items[nextIndex];
      return <String, Object?>{
        'id': nextItem.id,
        'title': nextItem.title,
        'durationMs': nextItem.duration?.inMilliseconds,
      };
    }
    if (name == 'autoMix.transitionToNextTrack') {
      final diagnostic = extras?['diagnostic'] == true;
      final hasDuration = extras?.containsKey('durationMs') ?? false;
      if (diagnostic || hasDuration) {
        if (!diagnostic || !kDebugMode) {
          throw StateError(
            'Custom transition durations are available only in the debug diagnostic driver.',
          );
        }
        final durationMs = extras?['durationMs'];
        if (durationMs is! int) {
          throw ArgumentError.value(
            durationMs,
            'durationMs',
            'Must be one of the supported diagnostic durations.',
          );
        }
        final duration = Duration(milliseconds: durationMs);
        if (!AutoMixSettings.diagnosticTransitionDurations.contains(duration)) {
          throw ArgumentError.value(
            durationMs,
            'durationMs',
            'Must be one of the supported diagnostic durations.',
          );
        }
        return _transitionToNextTrack(diagnosticDuration: duration);
      }
      return _transitionToNextTrack();
    }
    if (name == 'autoMix.cancelTransition') {
      final reason = extras?['reason'];
      if (reason != null && (reason is! String || reason.trim().isEmpty)) {
        throw ArgumentError.value(
          reason,
          'reason',
          'Must be a non-empty string when provided.',
        );
      }
      await _cancelAndWaitForTransition(
        reason: reason as String? ?? 'developerCancelled',
      );
      return null;
    }
    if (name == 'autoMix.getDiagnosticStatus') {
      if (!kDebugMode) {
        throw StateError('Diagnostic status is available only in debug mode.');
      }
      final diagnostic = _activeDiagnostic;
      return diagnostic == null
          ? const {'active': false}
          : {'active': true, ...diagnostic.toJson()};
    }
    if (name == 'autoMix.getDeckBState') {
      await _settingsReady;
      return _deckStateToMap(_autoMixController.incomingDeckState);
    }
    if (name == 'autoMix.playDeckB') {
      await _settingsReady;
      await _cancelAndWaitForTransition();
      if (!_audioEngine.stateFor(AudioDeck.a).playing) {
        throw StateError('Deck A must be playing before Deck B can overlap.');
      }
      await _activateAudioSession();
      await _autoMixController.playIncomingDeck();
      return null;
    }
    if (name == 'autoMix.pauseDeckB') {
      await _settingsReady;
      await _cancelAndWaitForTransition();
      await _autoMixController.pauseIncomingDeck();
      if (!_audioEngine.stateFor(AudioDeck.a).playing) {
        await _deactivateAudioSession();
      }
      return null;
    }
    if (name == 'autoMix.seekDeckB') {
      await _settingsReady;
      await _cancelAndWaitForTransition();
      final positionMs = extras?['positionMs'];
      if (positionMs is! int || positionMs < 0) {
        throw ArgumentError.value(
          positionMs,
          'positionMs',
          'Must be a non-negative integer.',
        );
      }
      await _autoMixController.seekIncomingDeck(
        Duration(milliseconds: positionMs),
      );
      return null;
    }
    if (name == 'autoMix.setDeckBGain') {
      await _settingsReady;
      await _cancelAndWaitForTransition();
      final gain = extras?['gain'];
      if (gain is! num || !gain.isFinite) {
        throw ArgumentError.value(gain, 'gain', 'Must be a finite number.');
      }
      await _autoMixController.setIncomingDeckGain(gain.toDouble());
      return null;
    }
    if (name == 'autoMix.unloadDeckB') {
      await _settingsReady;
      await _cancelAndWaitForTransition();
      await _autoMixController.unloadIncomingDeck();
      _preloadedQueueIndex = null;
      if (!_audioEngine.stateFor(AudioDeck.a).playing) {
        await _deactivateAudioSession();
      }
      return null;
    }
    if (name == 'autoMix.getSettings') {
      await _settingsReady;
      return <String, Object?>{
        'profile': _autoMixSettings.profile.name,
        'transitionDurationMs':
            _autoMixSettings.transitionDuration?.inMilliseconds,
        'automaticTransitions': _autoMixSettings.automaticTransitions,
        'effectiveTransitionDurationMs':
            _autoMixSettings.effectiveTransitionDuration.inMilliseconds,
      };
    }
    if (name == 'autoMix.updateSettings') {
      await _settingsReady;
      final profileName = extras?['profile'] as String?;
      final durationMs = extras?['transitionDurationMs'];
      final automatic = extras?['automaticTransitions'] as bool?;
      final profile = profileName != null
          ? AutoMixProfile.values.firstWhere(
              (p) => p.name == profileName,
              orElse: () => _autoMixSettings.profile,
            )
          : _autoMixSettings.profile;
      Duration? transitionDuration;
      if (durationMs is int && durationMs > 0) {
        final candidate = Duration(milliseconds: durationMs);
        if (candidate >= AutoMixSettings.minimumTransitionDuration &&
            candidate <= AutoMixSettings.maximumTransitionDuration) {
          transitionDuration = candidate;
        }
      }
      final next = _autoMixSettings.copyWith(
        profile: profile,
        transitionDuration: transitionDuration,
        automaticTransitions: automatic ?? _autoMixSettings.automaticTransitions,
      );
      await next.save();
      _autoMixSettings = next;
      _autoMixController.updateSettings(next);
      return null;
    }
    if (name == 'autoMix.toggleAutomatic') {
      await _settingsReady;
      final next = _autoMixSettings.copyWith(
        automaticTransitions: !_autoMixSettings.automaticTransitions,
      );
      await next.save();
      _autoMixSettings = next;
      _autoMixController.updateSettings(next);
      return <String, Object?>{
        'automaticTransitions': next.automaticTransitions,
      };
    }
    if (name == 'autoMix.setCuePoints') {
      final trackId = extras?['trackId'] as String?;
      final entryMs = extras?['entryPositionMs'];
      final exitMs = extras?['exitPositionMs'];
      if (trackId != null && trackId.isNotEmpty) {
        if (entryMs is int && entryMs >= 0) {
          _incomingTrackCues[trackId] = Duration(milliseconds: entryMs);
          if (_incomingTrackCues.length > 32) {
            _incomingTrackCues.remove(_incomingTrackCues.keys.first);
          }
        }
        if (exitMs is int && exitMs > 0) {
          _outgoingTrackCues[trackId] = Duration(milliseconds: exitMs);
          if (_outgoingTrackCues.length > 32) {
            _outgoingTrackCues.remove(_outgoingTrackCues.keys.first);
          }
        }
      }
      return null;
    }
    if (name == 'autoplay.get') {
      await _settingsReady;
      return <String, Object?>{'enabled': _autoplayContinuous};
    }
    if (name == 'autoplay.set') {
      await _settingsReady;
      final enabled = extras?['enabled'] == true;
      await setAutoplayContinuous(enabled);
      return <String, Object?>{'enabled': _autoplayContinuous};
    }
    if (name == 'autoplay.toggle') {
      await _settingsReady;
      await setAutoplayContinuous(!_autoplayContinuous);
      return <String, Object?>{'enabled': _autoplayContinuous};
    }
    if (name == 'notification.toggleLike') {
      await _settingsReady;
      final current =
          mediaItem.value ??
          (_items.isNotEmpty && _currentIndex < _items.length
              ? _items[_currentIndex]
              : null);
      final library = _musicLibrary;
      if (current == null || library == null) return false;
      final isFavorite = await library.toggleFavoriteMediaItem(current);
      _publishState();
      return isFavorite;
    }
    if (name == 'notification.cycleRepeat') {
      await _settingsReady;
      final next = switch (_repeatMode) {
        AudioServiceRepeatMode.none => AudioServiceRepeatMode.all,
        AudioServiceRepeatMode.all ||
        AudioServiceRepeatMode.group => AudioServiceRepeatMode.one,
        AudioServiceRepeatMode.one => AudioServiceRepeatMode.none,
      };
      await setRepeatMode(next);
      return next.name;
    }
    if (name == 'player.updateMediaItemArtUri') {
      final id = extras?['id'] as String?;
      final artUriStr = extras?['artUri'] as String?;
      final artUri = artUriStr != null ? Uri.tryParse(artUriStr) : null;
      if (id != null && artUri != null) {
        final idx = _items.indexWhere((i) => i.id == id);
        if (idx >= 0 && _items[idx].artUri == null) {
          _updateQueueItem(_items[idx].copyWith(artUri: artUri));
        } else if (mediaItem.value?.id == id &&
            mediaItem.value?.artUri == null) {
          mediaItem.add(mediaItem.value!.copyWith(artUri: artUri));
        }
      }
      return null;
    }
    return super.customAction(name, extras);
  }

  Future<void> _preloadNextTrack({bool fromTransition = false}) async {
    if (_isLoadingTrack && !fromTransition) return;
    final nextIndex = _nextQueueIndex();
    if (nextIndex == null) {
      throw StateError('There is no upcoming track to preload.');
    }
    if (_loadingQueueIndex == nextIndex) return;
    final incomingState = _audioEngine.stateFor(AudioDeck.b);
    if (_preloadedQueueIndex == nextIndex && incomingState.loaded) return;

    final generation = ++_preloadGeneration;
    _loadingQueueIndex = nextIndex;
    try {
      await _performPreloadNextTrack(
        nextIndex,
        generation: generation,
        fromTransition: fromTransition,
      );
    } on PlayerInterruptedException {
      // Expected when playback advances or changes mid-preload.
    } finally {
      if (_loadingQueueIndex == nextIndex) {
        _loadingQueueIndex = null;
      }
    }
  }

  Future<void> _performPreloadNextTrack(
    int nextIndex, {
    required int generation,
    required bool fromTransition,
  }) async {
    await _settingsReady;
    if (!fromTransition) await _cancelAndWaitForTransition();
    if ((!fromTransition && _isLoadingTrack) ||
        generation != _preloadGeneration ||
        nextIndex != _nextQueueIndex()) {
      return;
    }
    final incomingState = _audioEngine.stateFor(AudioDeck.b);
    if (_preloadedQueueIndex == nextIndex &&
        incomingState.loaded &&
        incomingState.processingState != AudioDeckProcessingState.error) {
      return;
    }
    if (incomingState.loaded) {
      if (fromTransition) {
        await _audioEngine.stopDeck(AudioDeck.b);
        await _autoMixController.unloadIncomingDeck();
        _preloadedQueueIndex = null;
      } else {
        await _unloadDeckBBeforeQueueChange();
      }
    }
    if ((!fromTransition && _isLoadingTrack) ||
        generation != _preloadGeneration ||
        nextIndex != _nextQueueIndex()) {
      return;
    }
    final nextSource = _needsAsyncResolution(_items[nextIndex])
        ? await _resolveSourceFor(_items[nextIndex])
        : _sourceFor(_items[nextIndex]);
    if ((!fromTransition && _isLoadingTrack) ||
        generation != _preloadGeneration ||
        nextIndex != _nextQueueIndex()) {
      return;
    }
    await _autoMixController.preloadIncoming(nextSource);
    if ((!fromTransition && _isLoadingTrack) ||
        generation != _preloadGeneration ||
        nextIndex != _nextQueueIndex()) {
      return;
    }
    _preloadedQueueIndex = nextIndex;
  }

  void _scheduleNextTrackPreload() {
    if (_isLoadingTrack) return;
    final nextIndex = _nextQueueIndex();
    if (nextIndex == null && _autoplayContinuous && _items.isNotEmpty) {
      unawaited(_ensureUpcomingAutoplayTracks().then((extended) {
        if (extended) _scheduleNextTrackPreload();
      }));
    }
    if (nextIndex == null ||
        _activeTransitionOperation != null ||
        _loadingQueueIndex != null ||
        _preloadedQueueIndex == nextIndex) {
      return;
    }
    unawaited(
      _preloadNextTrack().catchError((Object error, StackTrace stackTrace) {
        if (error is! PlayerInterruptedException) {
          _reportPlaybackError(
            error,
            stackTrace,
            'while preloading the upcoming track for AutoMix',
          );
        }
      }),
    );
  }

  void _maybeStartAutomaticTransition(AudioDeckState state) {
    if (!_autoMixSettings.automaticTransitions ||
        !state.playing ||
        _activeTransitionOperation != null ||
        _automaticTransitionPending ||
        _isAdvancing ||
        _repeatMode == AudioServiceRepeatMode.one) {
      return;
    }
    final nextIndex = _nextQueueIndex();
    final duration = state.duration;
    if (nextIndex == null || duration == null) return;
    final transitionDuration =
        _autoMixController.settings.effectiveTransitionDuration;
    final remaining = duration - state.position;
    final attemptKey = '${_items[_currentIndex].id}:${_items[nextIndex].id}';

    // Preload Deck B well before the crossfade begins so transitions enter on beat
    // without stream-loading stalls.
    if (remaining <= const Duration(seconds: 28)) {
      _scheduleNextTrackPreload();
    }

    // Begin crossfade at the detected quiet outro (when within the final 18s and
    // long enough for the crossfade) or transitionDuration + 2s before track end.
    final defaultWindowSeconds = (transitionDuration.inSeconds + 2).clamp(6, 14);
    var mixAhead = Duration(seconds: defaultWindowSeconds);
    final outroCue = _outgoingTrackCues[_items[_currentIndex].id];
    if (outroCue != null && outroCue < duration) {
      final cueRemaining = duration - outroCue;
      if (cueRemaining <= const Duration(seconds: 18) &&
          cueRemaining >= transitionDuration) {
        mixAhead = cueRemaining;
      }
    }

    if (remaining > mixAhead) {
      if (_automaticTransitionAttempt == attemptKey) {
        _automaticTransitionAttempt = null;
      }
      return;
    }
    if (_automaticTransitionAttempt == attemptKey) {
      return;
    }

    _automaticTransitionAttempt = attemptKey;
    _automaticTransitionPending = true;
    unawaited(_runAutomaticTransition());
  }

  Future<void> _runAutomaticTransition() async {
    try {
      await _transitionToNextTrack(reportErrors: false);
    } on Object catch (error, stackTrace) {
      _reportPlaybackError(
        error,
        stackTrace,
        'while automatically mixing to the next queue track',
      );
    } finally {
      _automaticTransitionPending = false;
    }
  }

  Future<Map<String, Object?>> _transitionToNextTrack({
    Duration? diagnosticDuration,
    bool reportErrors = true,
  }) async {
    await _settingsReady;
    if (_activeTransitionOperation != null) {
      throw StateError('An AutoMix transition is already running.');
    }
    final diagnosticNextIndex = diagnosticDuration == null
        ? null
        : _nextQueueIndex();
    if (diagnosticDuration != null &&
        (_items.isEmpty || diagnosticNextIndex == null)) {
      throw StateError(
        'A diagnostic transition requires two tracks in the playback queue.',
      );
    }
    _transitionCancelRequested = false;
    _transitionCancellationReason = null;
    final diagnostic = diagnosticDuration == null
        ? null
        : TransitionDiagnostic(
            trialId: '${DateTime.now().toUtc().microsecondsSinceEpoch}',
            outgoingTrackId: _items[_currentIndex].id,
            incomingTrackId: _items[diagnosticNextIndex!].id,
            profile: _autoMixController.settings.profile,
            requestedDuration: diagnosticDuration,
          );
    _activeDiagnostic = diagnostic;
    StreamSubscription<AudioDeckState>? diagnosticSubscription;
    var transitionStarted = false;
    var transitionCompleted = false;
    var lastProgressEventAt = Duration.zero;
    final transitionClock = Stopwatch()..start();
    void publishTransitionStarted(Duration duration) {
      transitionStarted = true;
      customEvent.add({
        'type': 'autoMix.transitionStarted',
        'durationMs': duration.inMilliseconds,
      });
    }

    void publishTransitionProgress(double progress, Duration duration) {
      final elapsed = transitionClock.elapsed;
      if (progress < 1 &&
          elapsed - lastProgressEventAt < const Duration(milliseconds: 50)) {
        return;
      }
      lastProgressEventAt = elapsed;
      customEvent.add({
        'type': 'autoMix.transitionProgress',
        'progress': progress,
        'durationMs': duration.inMilliseconds,
      });
    }

    if (diagnostic != null) {
      for (final deck in AudioDeck.values) {
        diagnostic.seedDeckState(_audioEngine.stateFor(deck));
      }
      diagnosticSubscription = _audioEngine.states.listen(
        diagnostic.recordDeckState,
      );
      diagnostic.recordEvent('trialStarted');
    }
    final operation = _runTransitionToNextTrack(
      diagnosticDuration: diagnosticDuration,
      diagnostic: diagnostic,
      onTransitionStarted: publishTransitionStarted,
      onTransitionProgress: publishTransitionProgress,
    );
    _activeTransitionOperation = operation;
    try {
      final result = await operation;
      transitionCompleted = result['completed'] == true;
      return diagnostic == null
          ? result
          : {
              ...result,
              ...diagnostic.toJson(),
              'equalizerPreset': _audioProfile.preset.name,
            };
    } on Object catch (error, stackTrace) {
      if (reportErrors) {
        _reportPlaybackError(
          error,
          stackTrace,
          'while transitioning to the next track with AutoMix',
        );
      }
      if (diagnostic != null) {
        diagnostic
          ..error = error.toString()
          ..recoveryBehavior = _diagnosticRecoveryBehavior()
          ..finish('transitionFailed');
        return {
          'completed': false,
          ...diagnostic.toJson(),
          'equalizerPreset': _audioProfile.preset.name,
        };
      }
      rethrow;
    } finally {
      if (transitionStarted) {
        customEvent.add({
          'type': 'autoMix.transitionEnded',
          'completed': transitionCompleted,
        });
      }
      await diagnosticSubscription?.cancel();
      if (identical(_activeTransitionOperation, operation)) {
        _activeTransitionOperation = null;
        _transitionCancelRequested = false;
        _transitionCancellationReason = null;
        _activeDiagnostic = null;
      }
      if (transitionCompleted && _isPlaying) {
        _automaticTransitionAttempt = null;
        _scheduleNextTrackPreload();
      }
    }
  }

  Future<Map<String, Object?>> _runTransitionToNextTrack({
    Duration? diagnosticDuration,
    TransitionDiagnostic? diagnostic,
    required void Function(Duration duration) onTransitionStarted,
    required void Function(double progress, Duration duration)
    onTransitionProgress,
  }) async {
    diagnostic?.recordEvent('transitionPreparationStarted');
    if (_transitionCancelRequested) {
      diagnostic
        ?..cancellationReason = _transitionCancellationReason
        ..recoveryBehavior = _diagnosticRecoveryBehavior()
        ..finish('transitionCancelled');
      return const {'completed': false};
    }
    final nextIndex = _nextQueueIndex();
    if (nextIndex == null) {
      throw StateError('There is no upcoming track to transition to.');
    }
    final outgoingState = _audioEngine.stateFor(AudioDeck.a);
    if (!outgoingState.loaded || !outgoingState.playing) {
      throw StateError(
        'Deck A must be playing to start an AutoMix transition.',
      );
    }
    if (_preloadedQueueIndex != nextIndex ||
        !_audioEngine.stateFor(AudioDeck.b).loaded) {
      diagnostic?.recordEvent('incomingPreloadStarted');
      await _preloadNextTrack(fromTransition: true);
      diagnostic?.recordEvent('incomingPreloadCompleted');
    }
    if (_transitionCancelRequested) {
      diagnostic
        ?..cancellationReason = _transitionCancellationReason
        ..recoveryBehavior = _diagnosticRecoveryBehavior()
        ..finish('transitionCancelled');
      return const {'completed': false};
    }
    final currentOutgoingState = _audioEngine.stateFor(AudioDeck.a);
    final incomingState = _audioEngine.stateFor(AudioDeck.b);
    final outgoingItem = _items[_currentIndex];
    final incomingItem = _items[nextIndex];
    final plan = _autoMixController.planTransition(
      outgoing: TrackAnalysis(
        trackId: outgoingItem.id,
        duration: _analysisDuration(outgoingItem, currentOutgoingState.duration),
      ),
      incoming: TrackAnalysis(
        trackId: incomingItem.id,
        duration: _analysisDuration(incomingItem, incomingState.duration),
      ),
      transitionDuration: diagnosticDuration,
    );
    final remaining = currentOutgoingState.duration == null
        ? null
        : currentOutgoingState.duration! - currentOutgoingState.position;
    if (remaining != null && remaining <= Duration.zero) {
      throw StateError('The outgoing track has no remaining transition time.');
    }
    final analyzedIntro = _incomingTrackCues[incomingItem.id];
    final incomingEntry =
        analyzedIntro != null &&
            analyzedIntro > Duration.zero &&
            (incomingState.duration == null ||
                analyzedIntro < incomingState.duration!)
        ? analyzedIntro
        : plan.incomingEntryPosition;
    final effectiveDuration =
        remaining != null && remaining < plan.transitionDuration
        ? remaining
        : plan.transitionDuration;
    final effectiveStyle =
        diagnosticDuration == null ? TransitionStyle.quickBlend : plan.style;
    final effectivePlan =
        (remaining != null && remaining < plan.transitionDuration) ||
            incomingEntry != plan.incomingEntryPosition ||
            effectiveStyle != plan.style
        ? TransitionPlan(
            outgoingTrackId: plan.outgoingTrackId,
            incomingTrackId: plan.incomingTrackId,
            profile: plan.profile,
            transitionDuration: effectiveDuration,
            outgoingTransitionPosition:
                remaining != null && remaining < plan.transitionDuration
                ? currentOutgoingState.position
                : plan.outgoingTransitionPosition,
            incomingEntryPosition: incomingEntry,
            style: effectiveStyle,
            tempoCompatibility: plan.tempoCompatibility,
            bpmDifferencePercent: plan.bpmDifferencePercent,
            confidenceScore: plan.confidenceScore,
          )
        : plan;

    await _activateAudioSession();
    if (_transitionCancelRequested) {
      diagnostic
        ?..cancellationReason = _transitionCancellationReason
        ..recoveryBehavior = _diagnosticRecoveryBehavior()
        ..finish('transitionCancelled');
      return const {'completed': false};
    }
    void startDiagnosticMeasurement() {
      if (diagnostic == null) return;
      for (final deck in AudioDeck.values) {
        diagnostic.seedDeckState(_audioEngine.stateFor(deck));
      }
      diagnostic.start();
    }

    final completed = await _autoMixController.transitionIncoming(
      plan: effectivePlan,
      targetGain: _effectiveTargetGain,
      onStarted: () {
        onTransitionStarted(effectivePlan.transitionDuration);
        startDiagnosticMeasurement();
      },
      onProgress: (progress) =>
          onTransitionProgress(progress, effectivePlan.transitionDuration),
    );
    if (!completed) {
      diagnostic
        ?..cancellationReason = _transitionCancellationReason
        ..recoveryBehavior = _diagnosticRecoveryBehavior()
        ..finish('transitionCancelled');
      return const {'completed': false};
    }
    diagnostic?.finish('gainRampCompleted');

    _isLoadingTrack = true;
    try {
      _currentIndex = nextIndex;
      _orderPosition = _playOrder.indexOf(nextIndex);
      if (_orderPosition < 0) {
        _rebuildPlayOrder(nextIndex);
      }
      _preloadedQueueIndex = null;
      await _autoMixController.promoteIncomingDeck();
      diagnostic
        ?..incomingPromoted = true
        ..recordEvent('incomingDeckPromoted');
      await _autoMixController.unloadIncomingDeck();
    } finally {
      _isLoadingTrack = false;
    }
    _publishState();
    mediaItem.add(incomingItem);
    _publishDuration(_audioEngine.stateFor(AudioDeck.a).duration);
    _recordSessionItem(incomingItem);
    diagnostic?.finish('transitionCompleted');
    return {
      'completed': true,
      'trackId': incomingItem.id,
      'durationMs': effectivePlan.transitionDuration.inMilliseconds,
      'effectiveDurationMs': effectivePlan.transitionDuration.inMilliseconds,
      'style': effectivePlan.style.name,
      if (diagnostic != null) 'actualElapsedMs': diagnostic.elapsedMilliseconds,
    };
  }

  Duration? _analysisDuration(MediaItem item, Duration? deckDuration) {
    final duration = item.duration ?? deckDuration;
    return duration != null && duration > Duration.zero ? duration : null;
  }

  Map<String, Object?> _diagnosticRecoveryBehavior() => {
    'deckAPlaying': _audioEngine.stateFor(AudioDeck.a).playing,
    'deckAGain': _audioEngine.stateFor(AudioDeck.a).gain,
    'deckBPlaying': _audioEngine.stateFor(AudioDeck.b).playing,
    'deckBLoaded': _audioEngine.stateFor(AudioDeck.b).loaded,
    'queueTrackId': _items.isEmpty ? null : _items[_currentIndex].id,
  };

  Future<void> _cancelAndWaitForTransition({
    String reason = 'playbackOperation',
    bool restoreDecks = true,
  }) async {
    final operation = _activeTransitionOperation;
    if (operation == null) return;
    _transitionCancelRequested = true;
    _transitionCancellationReason = reason;
    _activeDiagnostic
      ?..cancellationReason = reason
      ..recordEvent('cancellationRequested', details: {'reason': reason});
    await _autoMixController.cancelTransition(restoreDecks: restoreDecks);
    await operation;
  }

  Map<String, Object?> _deckStateToMap(AudioDeckState state) => {
    'deck': state.deck.name,
    'processingState': state.processingState.name,
    'playing': state.playing,
    'positionMs': state.position.inMilliseconds,
    'bufferedPositionMs': state.bufferedPosition.inMilliseconds,
    'durationMs': state.duration?.inMilliseconds,
    'gain': state.gain,
    'playbackRate': state.playbackRate,
    'loaded': state.loaded,
    'error': state.error,
  };

  void _listenToPlayer() {
    _playerSubscriptions
      ..add(
        _audioEngine.states.listen(
          (state) {
            if (state.deck == AudioDeck.b) {
              _publishState();
              if (state.processingState == AudioDeckProcessingState.completed) {
                if (_autoMixController.isTransitioning) {
                  _runSessionOperation(_cancelAndWaitForTransition());
                } else if (!_audioEngine.stateFor(AudioDeck.a).playing) {
                  _runSessionOperation(_deactivateAudioSession());
                }
              }
              return;
            }
            if (_isLoadingTrack) return;
            _positions.add(state.position);
            _publishDuration(state.duration);
            _publishState(throttled: true);
            if (_activeTransitionOperation == null &&
                state.processingState != AudioDeckProcessingState.completed) {
              _scheduleNextTrackPreload();
              _maybeStartAutomaticTransition(state);
            }
            if (state.processingState == AudioDeckProcessingState.completed &&
                !_isAdvancing &&
                _activeTransitionOperation == null) {
              unawaited(_advanceAtEnd());
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            playbackState.add(
              playbackState.value.copyWith(
                processingState: AudioProcessingState.error,
                errorMessage: error.toString(),
              ),
            );
            _reportPlaybackError(
              error,
              stackTrace,
              'while receiving audio playback events',
            );
          },
        ),
      )
      ..add(
        _audioEngine.errors.listen(
          (event) {
            if (event.deck != AudioDeck.a) {
              _reportPlaybackError(
                event.error,
                event.stackTrace,
                'while handling AutoMix deck ${event.deck.name}',
              );
              if (_activeTransitionOperation != null) {
                _runSessionOperation(_cancelAndWaitForTransition());
              }
              return;
            }
            playbackState.add(
              playbackState.value.copyWith(
                processingState: AudioProcessingState.error,
                errorMessage: event.error.toString(),
              ),
            );
            _reportPlaybackError(
              event.error,
              event.stackTrace,
              'while receiving audio playback events',
            );
          },
          onError: (Object error, StackTrace stackTrace) =>
              _reportPlaybackError(
                error,
                stackTrace,
                'while monitoring audio engine errors',
              ),
        ),
      );
  }

  @override
  Future<void> play() async {
    _interruptionActive = false;
    _resumeAfterInterruption = false;
    _desiredPlaying = true;
    await _startPlayback();
  }

  Future<void> _startPlayback() async {
    await _settingsReady;
    if (_items.isEmpty) return;
    if (_audioEngine.stateFor(AudioDeck.a).processingState ==
        AudioDeckProcessingState.completed) {
      await _audioEngine.seekDeck(AudioDeck.a, Duration.zero);
    }
    await _activateAudioSession();
    _startPlaybackOnPlayer();
    _scheduleNextTrackPreload();
  }

  Future<void> _activateAudioSession() async {
    if (_audioSessionActive) return;
    final session = _audioSession ?? await AudioSession.instance;
    if (!await session.setActive(true)) {
      throw StateError('The audio session is unavailable for playback.');
    }
    _audioSessionActive = true;
  }

  void _startPlaybackOnPlayer() {
    unawaited(
      _audioEngine.playDeck(AudioDeck.a).catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        playbackState.add(
          playbackState.value.copyWith(
            processingState: AudioProcessingState.error,
            errorMessage: error.toString(),
          ),
        );
        _reportPlaybackError(error, stackTrace, 'while starting audio');
        _runSessionOperation(_deactivateAudioSession());
      }),
    );
  }

  @override
  Future<void> pause() async {
    _resumeAfterInterruption = false;
    _desiredPlaying = false;
    await _pausePlayback(retainAudioFocus: _interruptionActive);
  }

  Future<void> _pausePlayback({bool retainAudioFocus = false}) async {
    await _cancelAndWaitForTransition();
    await Future.wait([
      _audioEngine.pauseDeck(AudioDeck.a),
      _audioEngine.pauseDeck(AudioDeck.b),
    ]);
    if (!retainAudioFocus) await _deactivateAudioSession();
    _publishState();
  }

  Future<void> _deactivateAudioSession() async {
    if (!_audioSessionActive) return;
    final session = _audioSession ?? await AudioSession.instance;
    await session.setActive(false);
    _audioSessionActive = false;
  }

  @override
  Future<void> stop() async {
    _interruptionActive = false;
    _resumeAfterInterruption = false;
    _desiredPlaying = false;
    await pause();
    await Future.wait([
      _audioEngine.stopDeck(AudioDeck.a),
      _audioEngine.stopDeck(AudioDeck.b),
    ]);
    await super.stop();
    _publishState();
  }

  @override
  Future<void> seek(Duration position) async {
    await _cancelAndWaitForTransition();
    await _audioEngine.seekDeck(AudioDeck.a, position);
    _publishState();
  }

  @override
  Future<void> skipToNext() async {
    final nextIndex = _nextQueueIndex();
    if (nextIndex == null) return;
    final shouldPlay = _isAnyDeckPlaying || _desiredPlaying;
    await _loadNextPlayable(firstIndex: nextIndex, playWhenReady: shouldPlay);
  }

  @override
  Future<void> skipToPrevious() async {
    if (_audioEngine.stateFor(AudioDeck.a).position >
        const Duration(seconds: 3)) {
      await seek(Duration.zero);
      return;
    }
    if (_orderPosition > 0) {
      final shouldPlay = _isAnyDeckPlaying || _desiredPlaying;
      await _loadIndex(
        _playOrder[_orderPosition - 1],
        playWhenReady: shouldPlay,
      );
    } else {
      await seek(Duration.zero);
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _items.length) return;
    final shouldPlay = _isAnyDeckPlaying || _desiredPlaying;
    await _loadIndex(index, playWhenReady: shouldPlay);
  }

  @override
  Future<void> playMediaItem(MediaItem mediaItem) async {
    await _settingsReady;
    final existingIndex = _items.indexWhere((item) => item.id == mediaItem.id);
    if (existingIndex >= 0) {
      await _loadIndex(existingIndex, playWhenReady: true);
      return;
    }
    final newIndex = _items.length;
    _items = List.unmodifiable([..._items, mediaItem]);
    _playOrder = List.unmodifiable([..._playOrder, newIndex]);
    queue.add(_items);
    await _loadIndex(newIndex, playWhenReady: true);
  }

  void _updateQueueItem(MediaItem updatedItem) {
    final index = _items.indexWhere((i) => i.id == updatedItem.id);
    if (index >= 0) {
      final updatedList = [..._items];
      updatedList[index] = updatedItem;
      _items = List.unmodifiable(updatedList);
      queue.add(_items);
      if (_currentIndex == index) {
        mediaItem.add(updatedItem);
      }
    }
  }

  List<int> get upcomingQueueIndices =>
      List.unmodifiable(_playOrder.skip(_orderPosition + 1));

  Future<void> reorderUpcomingQueue(int oldIndex, int newIndex) async {
    await _settingsReady;
    final upcoming = [...upcomingQueueIndices];
    if (oldIndex < 0 || oldIndex >= upcoming.length) {
      throw RangeError.index(oldIndex, upcoming, 'oldIndex');
    }
    if (newIndex < 0 || newIndex >= upcoming.length) {
      throw RangeError.index(newIndex, upcoming, 'newIndex');
    }
    if (oldIndex == newIndex) return;

    await _unloadDeckBBeforeQueueChange();
    final start = _orderPosition + 1;
    final moved = upcoming.removeAt(oldIndex);
    upcoming.insert(newIndex, moved);
    _playOrder = List.unmodifiable([..._playOrder.take(start), ...upcoming]);
    _publishState();
  }

  Future<void> clearUpcomingQueue() async {
    await _settingsReady;
    final removedIndices = upcomingQueueIndices.toSet();
    if (removedIndices.isEmpty) return;

    await _unloadDeckBBeforeQueueChange();
    final remappedIndices = <int, int>{};
    final retainedItems = <MediaItem>[];
    for (var index = 0; index < _items.length; index++) {
      if (removedIndices.contains(index)) continue;
      remappedIndices[index] = retainedItems.length;
      retainedItems.add(_items[index]);
    }

    _items = List.unmodifiable(retainedItems);
    _playOrder = List.unmodifiable(
      _playOrder
          .where(remappedIndices.containsKey)
          .map((index) => remappedIndices[index]!),
    );
    _currentIndex = remappedIndices[_currentIndex]!;
    _orderPosition = _playOrder.indexOf(_currentIndex);
    queue.add(_items);
    _publishState();
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    await _settingsReady;
    if (_items.any((item) => item.id == mediaItem.id)) return;
    if (_items.isEmpty) {
      await replaceQueue([mediaItem], playWhenReady: false);
      return;
    }

    final newIndex = _items.length;
    _items = List.unmodifiable([..._items, mediaItem]);
    _playOrder = List.unmodifiable([..._playOrder, newIndex]);
    queue.add(_items);
    _publishState();
  }

  @override
  Future<void> removeQueueItem(MediaItem mediaItem) async {
    await _settingsReady;
    final removeIndex = _items.indexWhere((item) => item.id == mediaItem.id);
    if (removeIndex < 0) return;
    if (removeIndex == _currentIndex) {
      throw StateError('The currently playing song cannot be removed.');
    }

    await _unloadDeckBBeforeQueueChange();
    final currentIndex = _currentIndex;
    _items = List.unmodifiable([
      ..._items.take(removeIndex),
      ..._items.skip(removeIndex + 1),
    ]);
    _playOrder = List.unmodifiable(
      _playOrder
          .where((index) => index != removeIndex)
          .map((index) => index > removeIndex ? index - 1 : index),
    );
    _currentIndex = removeIndex < currentIndex
        ? currentIndex - 1
        : currentIndex;
    _orderPosition = _playOrder.indexOf(_currentIndex);
    queue.add(_items);
    _publishState();
  }

  @override
  Future<void> updateQueue(List<MediaItem> queue) async {
    await replaceQueue(queue, initialIndex: 0, playWhenReady: false);
  }

  Future<void> replaceQueue(
    List<MediaItem> items, {
    int initialIndex = 0,
    required bool playWhenReady,
  }) async {
    await _settingsReady;
    final loadId = ++_activeLoadId;
    ++_preloadGeneration;
    _loadingQueueIndex = null;
    _isLoadingTrack = true;
    _desiredPlaying = items.isNotEmpty && playWhenReady;
    try {
      await _cancelAndWaitForTransition(restoreDecks: false);
      if (loadId != _activeLoadId) return;
      if (items.isEmpty) {
        await _audioEngine.stopDeck(AudioDeck.a);
        await _unloadDeckBBeforeQueueChange();
        if (loadId != _activeLoadId) return;
        await _deactivateAudioSession();
        _items = const [];
        _playOrder = const [];
        _currentIndex = 0;
        _orderPosition = 0;
        queue.add(_items);
        mediaItem.add(null);
        _publishState();
        return;
      }
      if (initialIndex < 0 || initialIndex >= items.length) {
        throw RangeError.index(initialIndex, items, 'initialIndex');
      }
      if (_audioEngine.stateFor(AudioDeck.a).playing) {
        await _audioEngine.setDeckGain(AudioDeck.a, 0.0);
      }
      if (_audioEngine.stateFor(AudioDeck.b).playing) {
        await _audioEngine.setDeckGain(AudioDeck.b, 0.0);
      }
      await _audioEngine.stopDeck(AudioDeck.a);
      await _unloadDeckBBeforeQueueChange();
      if (loadId != _activeLoadId) return;
      if (!playWhenReady) await _deactivateAudioSession();
      _items = List.unmodifiable(items);
      _currentIndex = initialIndex;
      _automaticTransitionAttempt = null;
      _rebuildPlayOrder(initialIndex);
      queue.add(_items);
      mediaItem.add(_items[initialIndex]);
      _positions.add(Duration.zero);
      final loadedSource = await _loadDeckAWithFallback(
        initialIndex,
        isCancelled: () => loadId != _activeLoadId,
      );
      if (loadedSource == null || loadId != _activeLoadId) return;
      _isLoadingTrack = false;
      final activeItem = loadedSource.tag is MediaItem
          ? loadedSource.tag as MediaItem
          : _items[initialIndex];
      mediaItem.add(activeItem);
      _publishDuration(_audioEngine.stateFor(AudioDeck.a).duration);
      _recordSessionItem(activeItem);
      _publishState();
      if (playWhenReady) await play();
      _prefetchUpcomingStream();
    } finally {
      if (loadId == _activeLoadId) {
        _isLoadingTrack = false;
      }
    }
  }

  Future<void> _unloadDeckBBeforeQueueChange() async {
    await _cancelAndWaitForTransition();
    _preloadedQueueIndex = null;
    await _audioEngine.stopDeck(AudioDeck.b);
    try {
      await _audioEngine.unloadDeck(AudioDeck.b);
    } on Object catch (error, stackTrace) {
      _reportPlaybackError(
        error,
        stackTrace,
        'while clearing the preloaded AutoMix deck before changing the queue',
      );
    }
  }

  bool get _isPlaying => _audioEngine.stateFor(AudioDeck.a).playing;
  bool get _isAnyDeckPlaying =>
      _audioEngine.stateFor(AudioDeck.a).playing ||
      _audioEngine.stateFor(AudioDeck.b).playing;

  bool _needsAsyncResolution(MediaItem item) {
    if (item.id.startsWith('/') || item.id.startsWith('file:')) {
      return false;
    }
    final cachedStreamUrl = item.extras?['streamUrl'] as String?;
    if (cachedStreamUrl != null &&
        (cachedStreamUrl.startsWith('http://') ||
            cachedStreamUrl.startsWith('https://'))) {
      return false;
    }
    return item.id.startsWith('youtube:') ||
        item.extras?['source'] == 'youtube' ||
        item.id.startsWith('spotify:') ||
        item.extras?['source'] == 'spotify';
  }

  static const _networkStreamHeaders = <String, String>{
    'User-Agent':
        'Mozilla/5.0 (Android; Tablet) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': '*/*',
    'Accept-Encoding': 'identity',
  };

  AudioDeckSource _sourceFor(MediaItem item) {
    // 0. Coordinate with local device library: if downloaded, stream from local disk!
    final localTrack = _musicLibrary?.findMatchingLocalTrack(
      providerTrackId: item.extras?['providerTrackId'] as String? ??
          (item.id.startsWith('youtube:') ? item.id.substring(8) : null),
      title: item.title,
      artist: item.artist,
      path: item.id.startsWith('file:') || item.id.startsWith('/') ? item.id : null,
    );
    if (localTrack != null && File(localTrack.path).existsSync()) {
      return AudioDeckSource(uri: Uri.file(localTrack.path), tag: item);
    }

    final streamUrl = item.extras?['streamUrl'] as String?;
    final customUa = item.extras?['userAgent'] as String?;
    final effectiveHeaders = customUa != null && customUa.isNotEmpty
        ? <String, String>{
            ..._networkStreamHeaders,
            'User-Agent': customUa,
          }
        : _networkStreamHeaders;
    if (streamUrl != null &&
        (streamUrl.startsWith('http://') || streamUrl.startsWith('https://'))) {
      return AudioDeckSource(
        uri: Uri.parse(streamUrl),
        tag: item,
        headers: effectiveHeaders,
      );
    }
    if (item.id.startsWith('http://') ||
        item.id.startsWith('https://') ||
        item.id.startsWith('content://') ||
        item.extras?['source'] == 'device') {
      return AudioDeckSource(
        uri: Uri.parse(item.id),
        tag: item,
        headers: (item.id.startsWith('http://') || item.id.startsWith('https://'))
            ? effectiveHeaders
            : null,
      );
    }
    return AudioDeckSource(uri: Uri.file(item.id), tag: item);
  }

  Future<AudioDeckSource> _resolveSourceFor(MediaItem item) async {
    // 0. Coordinate with local device library: if downloaded, stream from local disk!
    final localTrack = _musicLibrary?.findMatchingLocalTrack(
      providerTrackId: item.extras?['providerTrackId'] as String? ??
          (item.id.startsWith('youtube:') ? item.id.substring(8) : null),
      title: item.title,
      artist: item.artist,
    );
    if (localTrack != null && File(localTrack.path).existsSync()) {
      debugPrint('Found local matching track in device library for "${item.title}": ${localTrack.path}');
      final localItem = item.copyWith(
        id: item.id,
        extras: {
          ...?item.extras,
          'streamUrl': null,
          'localPath': localTrack.path,
          'source': 'device',
          'isLocal': true,
        },
      );
      _updateQueueItem(localItem);
      return AudioDeckSource(
        uri: Uri.file(localTrack.path),
        tag: localItem,
      );
    }

    if (item.id.startsWith('youtube:') ||
        item.extras?['downloadProvider'] == 'YouTube' ||
        item.extras?['source'] == 'youtube') {
      try {
        final videoId = item.extras?['providerTrackId'] as String? ??
            item.id.replaceFirst('youtube:', '');
        final streamDetails =
            await YoutubeAudioService.instance.getStreamDetails(videoId);
        final resolvedItem = item.copyWith(
          extras: {
            ...?item.extras,
            'streamUrl': streamDetails.url,
            'mimeType': streamDetails.mimeType,
            'bitRate': streamDetails.bitrate,
            'sampleRate': streamDetails.sampleRate,
            'channelCount': streamDetails.channelCount,
            'codec': streamDetails.codec,
            'userAgent': streamDetails.headers['User-Agent'],
            'source': 'youtube',
            'isLiveStream': true,
            'providerTrackId': videoId,
          },
        );
        _updateQueueItem(resolvedItem);
        return AudioDeckSource(
          uri: Uri.parse(streamDetails.url),
          tag: resolvedItem,
          headers: streamDetails.headers,
        );
      } catch (e, st) {
        debugPrint('Could not resolve YouTube stream: $e\n$st');
        throw StateError('Could not resolve YouTube stream for "${item.title}": $e');
      }
    }

    if (item.id.startsWith('spotify:') ||
        item.extras?['downloadProvider'] == 'Spotify' ||
        item.extras?['source'] == 'spotify') {
      try {
        final query = '${item.title} ${item.artist}';
        final ytTracks = await YoutubeAudioService.instance.search(query);
        if (ytTracks.isNotEmpty) {
          final matched = ytTracks.first;
          final streamDetails =
              await YoutubeAudioService.instance.getStreamDetails(matched.id);
          final resolvedItem = item.copyWith(
            extras: {
              ...?item.extras,
              'streamUrl': streamDetails.url,
              'mimeType': streamDetails.mimeType,
              'bitRate': streamDetails.bitrate,
              'sampleRate': streamDetails.sampleRate,
              'channelCount': streamDetails.channelCount,
              'codec': streamDetails.codec,
              'userAgent': streamDetails.headers['User-Agent'],
              'matchedYoutubeId': matched.id,
              'source': 'spotify',
            },
          );
          _updateQueueItem(resolvedItem);
          return AudioDeckSource(
            uri: Uri.parse(streamDetails.url),
            tag: resolvedItem,
            headers: streamDetails.headers,
          );
        } else {
          throw StateError('No audio source found matching "${item.title}" by "${item.artist}".');
        }
      } catch (e, st) {
        debugPrint('Could not resolve Spotify stream: $e\n$st');
        throw StateError('Could not resolve streaming track "${item.title}": $e');
      }
    }

    return _sourceFor(item);
  }

  Future<void> _loadIndex(int index, {required bool playWhenReady}) async {
    final loadId = ++_activeLoadId;
    ++_preloadGeneration;
    _loadingQueueIndex = null;
    _isLoadingTrack = true;
    _desiredPlaying = playWhenReady;

    // Snapshot Deck B state before cancelling any active transition so we know
    // whether Deck B was already loaded with [index] (or mid-crossfade to it).
    final incomingBeforeCancel = _audioEngine.stateFor(AudioDeck.b);
    final hadPreloadedDeck =
        _preloadedQueueIndex == index &&
        incomingBeforeCancel.loaded &&
        incomingBeforeCancel.processingState != AudioDeckProcessingState.error;
    final incomingAlreadyPlaying = hadPreloadedDeck && incomingBeforeCancel.playing;

    // Immediately advance queue indices and emit the new mediaItem so the UI
    // updates instantaneously and rapid Next presses never re-select this track.
    _currentIndex = index;
    _orderPosition = _playOrder.indexOf(index);
    if (_orderPosition < 0) {
      _rebuildPlayOrder(index);
    }
    final targetItem = _items[index];
    mediaItem.add(targetItem);
    _positions.add(Duration.zero);
    _publishState();

    try {
      // Cancel any active transition without restoring outgoing Deck A gain so
      // cancelling an AutoMix crossfade never spikes the previous song back to 1.0.
      await _cancelAndWaitForTransition(restoreDecks: false);
      if (loadId != _activeLoadId) return;

      final incomingState = _audioEngine.stateFor(AudioDeck.b);
      final canPromotePreloadedDeck =
          hadPreloadedDeck &&
          incomingState.loaded &&
          incomingState.processingState != AudioDeckProcessingState.error;
      if (canPromotePreloadedDeck) {
        if (!incomingAlreadyPlaying) {
          final entryCue = _incomingTrackCues[targetItem.id];
          if (entryCue != null &&
              entryCue > Duration.zero &&
              (incomingState.duration == null ||
                  entryCue < incomingState.duration!)) {
            try {
              await _audioEngine.seekDeck(AudioDeck.b, entryCue);
            } catch (_) {}
          }
        }
        if (loadId != _activeLoadId) return;

        final targetGain = _effectiveTargetGain;
        final outgoingState = _audioEngine.stateFor(AudioDeck.a);
        final outgoingPlaying = outgoingState.playing;
        if (playWhenReady && outgoingPlaying) {
          await _activateAudioSession();
          if (loadId != _activeLoadId) return;
          if (!incomingAlreadyPlaying) {
            final initialOut = outgoingState.gain < targetGain * 0.65
                ? outgoingState.gain
                : targetGain * 0.65;
            await Future.wait([
              _audioEngine.setDeckGain(AudioDeck.a, initialOut),
              _audioEngine.setDeckGain(AudioDeck.b, targetGain * 0.35),
            ]);
            await _audioEngine.playDeck(AudioDeck.b);
          }
          if (!Platform.environment.containsKey('FLUTTER_TEST')) {
            for (final (outFactor, inFactor) in const [
              (0.30, 0.70),
              (0.08, 0.92),
            ]) {
              await Future<void>.delayed(const Duration(milliseconds: 25));
              if (loadId != _activeLoadId) return;
              final curA = _audioEngine.stateFor(AudioDeck.a).gain;
              final nextA =
                  curA < targetGain * outFactor ? curA : targetGain * outFactor;
              final curB = _audioEngine.stateFor(AudioDeck.b).gain;
              final nextB = curB > targetGain * inFactor && curB <= targetGain
                  ? curB
                  : targetGain * inFactor;
              await Future.wait([
                _audioEngine.setDeckGain(AudioDeck.a, nextA),
                _audioEngine.setDeckGain(AudioDeck.b, nextB),
              ]);
            }
          }
          if (loadId != _activeLoadId) return;
          await Future.wait([
            _audioEngine.setDeckGain(AudioDeck.a, 0.0),
            _audioEngine.setDeckGain(AudioDeck.b, targetGain),
          ]);
          await _audioEngine.stopDeck(AudioDeck.a);
        } else {
          if (outgoingPlaying) {
            await _audioEngine.setDeckGain(AudioDeck.a, 0.0);
          }
          await _audioEngine.stopDeck(AudioDeck.a);
          await _audioEngine.setDeckGain(AudioDeck.b, targetGain);
        }
        if (loadId != _activeLoadId) return;

        await _autoMixController.promoteIncomingDeck();
        _preloadedQueueIndex = null;
        await _audioEngine.stopDeck(AudioDeck.b);
        await _autoMixController.unloadIncomingDeck();
        if (loadId != _activeLoadId) return;

        _isLoadingTrack = false;
        final activeItem = _items[index];
        mediaItem.add(activeItem);
        _publishDuration(_audioEngine.stateFor(AudioDeck.a).duration);
        _recordSessionItem(activeItem);
        _automaticTransitionAttempt = null;
        _publishState();
        if (playWhenReady && !_audioEngine.stateFor(AudioDeck.a).playing) {
          await play();
        }
        _prefetchUpcomingStream();
        return;
      }

      // Silence both decks immediately to eliminate popping and volume surge on track change.
      if (_audioEngine.stateFor(AudioDeck.a).playing) {
        await _audioEngine.setDeckGain(AudioDeck.a, 0.0);
      }
      if (_audioEngine.stateFor(AudioDeck.b).playing) {
        await _audioEngine.setDeckGain(AudioDeck.b, 0.0);
      }
      await _audioEngine.stopDeck(AudioDeck.a);
      await _unloadDeckBBeforeQueueChange();
      if (loadId != _activeLoadId) return;

      final source = await _loadDeckAWithFallback(
        index,
        isCancelled: () => loadId != _activeLoadId,
      );
      if (source == null || loadId != _activeLoadId) return;

      _isLoadingTrack = false;
      final activeItem =
          source.tag is MediaItem ? source.tag as MediaItem : _items[index];
      mediaItem.add(activeItem);
      _publishDuration(_audioEngine.stateFor(AudioDeck.a).duration);
      _recordSessionItem(activeItem);
      _automaticTransitionAttempt = null;
      _publishState();
      if (playWhenReady) await play();
      _prefetchUpcomingStream();
    } finally {
      if (loadId == _activeLoadId) {
        _isLoadingTrack = false;
      }
    }
  }

  /// Resolves and loads [_items[index]] onto Deck A, falling back to refreshing
  /// an expired cached stream URL or a secondary proxy stream on HTTP failure.
  Future<AudioDeckSource?> _loadDeckAWithFallback(
    int index, {
    bool Function()? isCancelled,
  }) async {
    final targetItem = _items[index];
    AudioDeckSource? source;
    try {
      source = _needsAsyncResolution(targetItem)
          ? await _resolveSourceFor(targetItem)
          : _sourceFor(targetItem);
      if (isCancelled?.call() == true) return null;
      await _audioEngine.loadDeck(AudioDeck.a, source);
      if (isCancelled?.call() == true) return null;
      await _audioEngine.setDeckGain(AudioDeck.a, _effectiveTargetGain);
      return source;
    } catch (error, stackTrace) {
      if (isCancelled?.call() == true) return null;
      if (source != null &&
          (source.uri.scheme == 'http' || source.uri.scheme == 'https')) {
        final hadCachedUrl = targetItem.extras?['streamUrl'] != null;
        if (hadCachedUrl) {
          try {
            final clearedItem = targetItem.copyWith(
              extras: {
                ...?targetItem.extras,
                'streamUrl': null,
              },
            );
            if (_needsAsyncResolution(clearedItem)) {
              final refreshed = await _resolveSourceFor(clearedItem);
              if (isCancelled?.call() == true) return null;
              await _audioEngine.loadDeck(AudioDeck.a, refreshed);
              if (isCancelled?.call() == true) return null;
              await _audioEngine.setDeckGain(
                AudioDeck.a,
                _effectiveTargetGain,
              );
              return refreshed;
            }
          } catch (_) {
            if (isCancelled?.call() == true) return null;
          }
        }
        debugPrint('Source load error ($error). Attempting secondary fallback proxy stream...');
        try {
          final item = _items[index];
          final rawId = item.extras?['providerTrackId'] as String? ??
              (item.id.startsWith('youtube:') ? item.id.substring(8) : null);
          if (rawId != null) {
            final fallback = await YoutubeAudioService.instance
                .getFallbackStream(rawId);
            if (isCancelled?.call() == true) return null;
            if (fallback != null) {
              final fallbackSource = AudioDeckSource(
                uri: Uri.parse(fallback.url),
                tag: item.copyWith(
                  extras: {
                    ...?item.extras,
                    'streamUrl': fallback.url,
                    'userAgent': fallback.headers['User-Agent'],
                  },
                ),
                headers: fallback.headers,
              );
              await _audioEngine.loadDeck(AudioDeck.a, fallbackSource);
              if (isCancelled?.call() == true) return null;
              await _audioEngine.setDeckGain(
                AudioDeck.a,
                _effectiveTargetGain,
              );
              return fallbackSource;
            }
          }
        } catch (fallbackError) {
          if (isCancelled?.call() == true) return null;
          debugPrint('Secondary fallback also failed: $fallbackError');
        }
      }
      if (isCancelled?.call() == true) return null;
      playbackState.add(
        playbackState.value.copyWith(
          processingState: AudioProcessingState.error,
          errorMessage: error.toString(),
        ),
      );
      _reportPlaybackError(error, stackTrace, 'while loading track for playback');
      rethrow;
    }
  }

  void _prefetchUpcomingStream() {
    _scheduleNextTrackPreload();
    final upcomingIndices = _playOrder.skip(_orderPosition + 1).take(3).toList();
    if (upcomingIndices.isEmpty &&
        _repeatMode == AudioServiceRepeatMode.all &&
        _playOrder.isNotEmpty) {
      upcomingIndices.add(_playOrder.first);
    }
    if (upcomingIndices.isEmpty) return;

    final firstItem = _items[upcomingIndices.first];
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      unawaited(LyricsRepository.autoDownloadForMediaItem(firstItem));
    }
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;

    for (var offset = 0; offset < upcomingIndices.length; offset++) {
      final item = _items[upcomingIndices[offset]];
      if (!_needsAsyncResolution(item)) continue;
      final isSpotify = item.id.startsWith('spotify:') ||
          item.extras?['downloadProvider'] == 'Spotify' ||
          item.extras?['source'] == 'spotify';
      if (isSpotify) {
        if (item.extras?['streamUrl'] == null) {
          unawaited(
            _prefetchSpotifyStream(item).then((_) {
              if (offset == 0) _scheduleNextTrackPreload();
            }),
          );
        }
        continue;
      }
      final pId = item.extras?['providerTrackId'] as String? ??
          (item.id.startsWith('youtube:') ? item.id.substring(8) : null);
      if (pId != null && pId.isNotEmpty) {
        unawaited(
          YoutubeAudioService.instance
              .getStreamDetails(pId)
              .then((details) {
                _updateQueueItem(
                  item.copyWith(
                    extras: {
                      ...?item.extras,
                      'streamUrl': details.url,
                      'mimeType': details.mimeType,
                      'bitRate': details.bitrate,
                      'sampleRate': details.sampleRate,
                      'channelCount': details.channelCount,
                      'codec': details.codec,
                      'userAgent': details.headers['User-Agent'],
                      'providerTrackId': pId,
                    },
                  ),
                );
                if (offset == 0) _scheduleNextTrackPreload();
              })
              .catchError((Object error, StackTrace stackTrace) {
                debugPrint('Prefetch stream failed for $pId: $error');
              }),
        );
      }
    }
  }

  Future<void> _prefetchSpotifyStream(MediaItem item) async {
    try {
      final query = '${item.title} ${item.artist ?? ''}'.trim();
      if (query.isEmpty) return;
      final ytTracks = await YoutubeAudioService.instance.search(query);
      if (ytTracks.isEmpty) return;
      final matched = ytTracks.first;
      final streamDetails =
          await YoutubeAudioService.instance.getStreamDetails(matched.id);
      _updateQueueItem(
        item.copyWith(
          extras: {
            ...?item.extras,
            'streamUrl': streamDetails.url,
            'mimeType': streamDetails.mimeType,
            'bitRate': streamDetails.bitrate,
            'sampleRate': streamDetails.sampleRate,
            'channelCount': streamDetails.channelCount,
            'codec': streamDetails.codec,
            'userAgent': streamDetails.headers['User-Agent'],
            'matchedYoutubeId': matched.id,
            'source': 'spotify',
          },
        ),
      );
    } catch (e) {
      debugPrint('Prefetch Spotify stream failed for ${item.title}: $e');
    }
  }

  void _rebuildPlayOrder(int currentIndex) {
    final order = List<int>.generate(_items.length, (index) => index);
    if (_shuffleMode == AudioServiceShuffleMode.all) {
      order.remove(currentIndex);
      order.shuffle();
      _playOrder = List.unmodifiable([currentIndex, ...order]);
      _orderPosition = 0;
      return;
    }
    _playOrder = List.unmodifiable(order);
    _orderPosition = currentIndex;
  }

  int? _nextQueueIndex({bool automatic = false}) {
    if (_items.isEmpty) return null;
    if (automatic && _repeatMode == AudioServiceRepeatMode.one) {
      return _currentIndex;
    }
    if (_orderPosition + 1 < _playOrder.length) {
      return _playOrder[_orderPosition + 1];
    }
    if (_repeatMode == AudioServiceRepeatMode.all) {
      return _playOrder.first;
    }
    return null;
  }

  /// Advances to the next playable queue item, respecting the repeat mode.
  Future<void> _advanceAtEnd() async {
    if (_isAdvancing) return;
    _isAdvancing = true;
    try {
      var nextIndex = _nextQueueIndex(automatic: true);
      if (nextIndex == null && _autoplayContinuous && _items.isNotEmpty) {
        final extended = await _ensureUpcomingAutoplayTracks();
        if (extended) {
          nextIndex = _nextQueueIndex(automatic: true);
        }
      }
      if (nextIndex == null) {
        _publishState();
        return;
      }
      final loaded = await _loadNextPlayable(
        firstIndex: nextIndex,
        playWhenReady: true,
      );
      if (!loaded) {
        final error = StateError('No playable tracks remain in the queue.');
        playbackState.add(
          playbackState.value.copyWith(
            processingState: AudioProcessingState.error,
            errorMessage: error.toString(),
          ),
        );
        _reportPlaybackError(
          error,
          StackTrace.current,
          'while recovering from a track decoder failure',
        );
      }
    } on Object catch (error, stackTrace) {
      playbackState.add(
        playbackState.value.copyWith(
          processingState: AudioProcessingState.error,
          errorMessage: error.toString(),
        ),
      );
      _reportPlaybackError(error, stackTrace, 'while advancing the queue');
    } finally {
      _isAdvancing = false;
    }
  }

  /// Automatically fetches and appends related tracks to create an infinite,
  /// context-aware continuous queue using session & listening memory.
  Future<bool> _ensureUpcomingAutoplayTracks() async {
    if (!_autoplayContinuous || _isExtendingAutoplay || _items.isEmpty) return false;
    _isExtendingAutoplay = true;

    try {
      final currentItem = _items[_currentIndex];
      final library = _musicLibrary;
      final excludeIds = <String>{
        ..._items.map((i) => i.id),
        ..._sessionHistory.map((i) => i.id),
        if (library != null) ...library.excludedTrackIds,
      };
      final excludeTitleKeys = <String>{
        for (final i in _items)
          SongMetadataEnricher.cleanTitle(
            i.title,
            rawArtist: i.artist,
          ).trim().toLowerCase(),
        for (final i in _sessionHistory.take(15))
          SongMetadataEnricher.cleanTitle(
            i.title,
            rawArtist: i.artist,
          ).trim().toLowerCase(),
      }..removeWhere((key) => key.isEmpty);

      final recentArtists = <String>[];
      final seenArtistKeys = <String>{};
      void addArtist(String? raw) {
        final clean = (raw ?? '').trim();
        final lower = clean.toLowerCase();
        if (clean.isNotEmpty &&
            lower != 'unknown artist' &&
            seenArtistKeys.add(lower)) {
          recentArtists.add(clean);
        }
      }

      for (final item in _sessionHistory) {
        addArtist(item.artist);
      }
      if (library != null) {
        for (final artist in library.topAffinityArtists) {
          addArtist(artist);
        }
      }

      final rawId = currentItem.extras?['providerTrackId'] as String? ??
          (currentItem.id.startsWith('youtube:') ? currentItem.id.substring(8) : null);

      final newItems = <MediaItem>[];

      // 1. Fetch context-aware related tracks from YouTube/Deezer artist graph
      if (rawId != null || (currentItem.artist != null && currentItem.title.isNotEmpty)) {
        final related = await YoutubeAudioService.instance.getRelatedTracks(
          rawId ?? 'dQw4w9WgXcQ',
          artist: currentItem.artist,
          title: currentItem.title,
          recentArtists: recentArtists,
          excludeIds: excludeIds,
          excludeTitleKeys: excludeTitleKeys,
        );
        for (final t in related) {
          final item = t.toMediaItem();
          if (!excludeIds.contains(item.id)) {
            excludeIds.add(item.id);
            newItems.add(item);
          }
          if (newItems.length >= 6) break;
        }
      }

      // 2. Fallback to scored local library tracks (artist, genre, taste, BPM, favorites)
      if (newItems.isEmpty && library != null) {
        final currentArtist = currentItem.artist?.toLowerCase().trim() ?? '';
        final currentGenre = currentItem.genre?.toLowerCase().trim() ?? '';
        final currentBpm = (currentItem.extras?['bpm'] as num?)?.toDouble();
        final recentArtistSet =
            recentArtists.map((a) => a.toLowerCase().trim()).toSet();

        final scored = <({MediaItem item, String artistKey, int score})>[];
        for (final t in library.tracks) {
          if (!t.isAvailable) continue;
          if (library.isExcludedFromMixes(t.id)) continue;
          final item = t.toMediaItem();
          if (excludeIds.contains(item.id)) continue;

          final tArtistLower = t.artist.toLowerCase().trim();
          final tGenreLower = t.genre?.toLowerCase().trim() ?? '';
          var score = 0;
          if (currentArtist.isNotEmpty && tArtistLower == currentArtist) {
            score += 4;
          }
          if (currentGenre.isNotEmpty && tGenreLower == currentGenre) {
            score += 3;
          }
          if (recentArtistSet.contains(tArtistLower)) {
            score += 2;
          }
          if (currentBpm != null &&
              t.bpm != null &&
              (t.bpm! - currentBpm).abs() <= 10) {
            score += 2;
          }
          if (library.isFavorite(t.id)) {
            score += 1;
          }
          if (score > 0) {
            scored.add((item: item, artistKey: tArtistLower, score: score));
          }
        }

        scored.shuffle();
        scored.sort((a, b) => b.score.compareTo(a.score));

        final artistCap = <String, int>{};
        final deferred = <({MediaItem item, String artistKey, int score})>[];
        for (final entry in scored) {
          final count = artistCap[entry.artistKey] ?? 0;
          if (count < 2) {
            artistCap[entry.artistKey] = count + 1;
            newItems.add(entry.item);
            if (newItems.length >= 6) break;
          } else {
            deferred.add(entry);
          }
        }
        if (newItems.length < 6) {
          for (final entry in deferred) {
            newItems.add(entry.item);
            if (newItems.length >= 6) break;
          }
        }
      }

      if (newItems.isNotEmpty) {
        debugPrint('Continuous autoplay added ${newItems.length} similar tracks to the queue');
        final updatedList = List<MediaItem>.from(_items)..addAll(newItems);
        _items = List.unmodifiable(updatedList);
        final newIndices = List<int>.generate(
          newItems.length,
          (i) => _items.length - newItems.length + i,
        );
        _playOrder = List.unmodifiable([..._playOrder, ...newIndices]);
        queue.add(_items);
        _publishState();
        return true;
      }
    } catch (e) {
      debugPrint('Error extending queue with autoplay: $e');
    } finally {
      _isExtendingAutoplay = false;
    }
    return false;
  }

  Future<bool> _loadNextPlayable({
    required int firstIndex,
    required bool playWhenReady,
  }) async {
    var candidate = firstIndex;
    for (var attempt = 0; attempt < _items.length; attempt++) {
      final attemptLoadId = _activeLoadId + 1;
      try {
        await _loadIndex(candidate, playWhenReady: playWhenReady);
        return true;
      } on Object catch (error, stackTrace) {
        if (_activeLoadId > attemptLoadId) {
          return true;
        }
        _reportPlaybackError(
          error,
          stackTrace,
          'while loading the next queue item; trying the following item',
        );
      }
      final position = _playOrder.indexOf(candidate);
      if (position < 0) return false;
      if (position + 1 < _playOrder.length) {
        candidate = _playOrder[position + 1];
      } else if (_repeatMode == AudioServiceRepeatMode.all) {
        candidate = _playOrder.first;
      } else {
        return false;
      }
    }
    return false;
  }

  void _publishDuration(Duration? duration) {
    if (duration == null ||
        _items.isEmpty ||
        _currentIndex >= _items.length ||
        _items[_currentIndex].duration == duration) {
      return;
    }
    final updatedItems = [..._items];
    updatedItems[_currentIndex] = updatedItems[_currentIndex].copyWith(
      duration: duration,
    );
    _items = List.unmodifiable(updatedItems);
    queue.add(_items);
    mediaItem.add(_items[_currentIndex]);
  }

  void _publishState({bool throttled = false}) {
    // Seeks, loads and pauses may not emit a position event, so keep the
    // position stream in sync whenever playback state is published.
    final deckState = _audioEngine.stateFor(AudioDeck.a);
    _positions.add(deckState.position);
    final processingState = switch (deckState.processingState) {
      AudioDeckProcessingState.idle => AudioProcessingState.idle,
      AudioDeckProcessingState.loading => AudioProcessingState.loading,
      AudioDeckProcessingState.buffering => AudioProcessingState.buffering,
      AudioDeckProcessingState.ready => AudioProcessingState.ready,
      AudioDeckProcessingState.completed => AudioProcessingState.completed,
      AudioDeckProcessingState.error => AudioProcessingState.error,
    };
    final isPlaying =
        deckState.playing || _audioEngine.stateFor(AudioDeck.b).playing;
    final queueIndex = _items.isEmpty ? null : _currentIndex;

    final currentItem =
        mediaItem.value ??
        (_items.isNotEmpty && _currentIndex < _items.length
            ? _items[_currentIndex]
            : null);
    final isLiked =
        currentItem != null &&
        (_musicLibrary?.isFavoriteMediaItem(currentItem) ?? false);

    if (throttled) {
      final now = DateTime.now();
      final hasStateChange =
          processingState != _lastPublishedProcessingState ||
          isPlaying != _lastPublishedPlaying ||
          queueIndex != _lastPublishedIndex ||
          isLiked != _lastPublishedLiked ||
          _repeatMode != _lastPublishedRepeatMode;
      final timeSinceLast = _lastPlatformStatePublishTime == null
          ? const Duration(seconds: 10)
          : now.difference(_lastPlatformStatePublishTime!);

      if (!hasStateChange &&
          timeSinceLast < const Duration(milliseconds: 1000)) {
        return;
      }
      _lastPlatformStatePublishTime = now;
    } else {
      _lastPlatformStatePublishTime = DateTime.now();
    }

    _lastPublishedProcessingState = processingState;
    _lastPublishedPlaying = isPlaying;
    _lastPublishedIndex = queueIndex;
    _lastPublishedLiked = isLiked;
    _lastPublishedRepeatMode = _repeatMode;

    final likeControl = MediaControl.custom(
      androidIcon: isLiked
          ? 'drawable/ic_notif_heart_filled'
          : 'drawable/ic_notif_heart_outline',
      label: isLiked ? 'Unlike' : 'Like',
      name: 'notification.toggleLike',
    );
    final repeatControl = MediaControl.custom(
      androidIcon: switch (_repeatMode) {
        AudioServiceRepeatMode.one => 'drawable/ic_notif_repeat_one',
        AudioServiceRepeatMode.all ||
        AudioServiceRepeatMode.group => 'drawable/ic_notif_repeat_all',
        AudioServiceRepeatMode.none => 'drawable/ic_notif_repeat_off',
      },
      label: switch (_repeatMode) {
        AudioServiceRepeatMode.one => 'Repeat one',
        AudioServiceRepeatMode.all ||
        AudioServiceRepeatMode.group => 'Repeat all',
        AudioServiceRepeatMode.none => 'Repeat off',
      },
      name: 'notification.cycleRepeat',
    );

    playbackState.add(
      PlaybackState(
        controls: [
          likeControl,
          MediaControl.skipToPrevious,
          _isAnyDeckPlaying ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
          repeatControl,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.setRepeatMode,
          MediaAction.setShuffleMode,
        },
        androidCompactActionIndices: const [1, 2, 3],
        processingState: processingState,
        playing: isPlaying,
        updatePosition: deckState.position,
        bufferedPosition: deckState.bufferedPosition,
        speed: deckState.playbackRate,
        queueIndex: queueIndex,
        repeatMode: _repeatMode,
        shuffleMode: _shuffleMode,
      ),
    );
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    await _settingsReady;
    final mode = repeatMode == AudioServiceRepeatMode.group
        ? AudioServiceRepeatMode.all
        : repeatMode;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_repeatModeKey, mode.name);
    if (_repeatMode != mode) await _unloadDeckBBeforeQueueChange();
    _repeatMode = mode;
    _publishState();
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    await _settingsReady;
    final mode = shuffleMode == AudioServiceShuffleMode.all
        ? AudioServiceShuffleMode.all
        : AudioServiceShuffleMode.none;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_shuffleModeKey, mode.name);
    if (_shuffleMode != mode) await _unloadDeckBBeforeQueueChange();
    _shuffleMode = mode;
    if (_items.isNotEmpty) _rebuildPlayOrder(_currentIndex);
    _publishState();
  }

  Future<void> dispose() async {
    _musicLibrary?.removeListener(_onLibraryChanged);
    for (final subscription in _audioSessionSubscriptions) {
      await subscription.cancel();
    }
    for (final subscription in _playerSubscriptions) {
      await subscription.cancel();
    }
    await _cancelAndWaitForTransition(reason: 'handlerDisposed');
    await _deactivateAudioSession();
    await _audioEngine.dispose();
    await _positions.close();
  }

  static void _reportPlaybackError(
    Object error,
    StackTrace stackTrace,
    String context,
  ) {
    if (error is PlayerInterruptedException) return;
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'tone playback',
        context: ErrorDescription(context),
      ),
    );
  }
}

/// Applies the user's equalizer profile when the platform supports it.
class _PlayerFilter {
  _PlayerFilter(this._equalizer) {
    if (_equalizer != null) {
      // Seed enabled state upfront before the player platform becomes active.
      // In just_audio, setting enabled while inactive safely updates the internal
      // subject so that the initial InitRequest enables effects without an IPC race.
      unawaited(_equalizer.setEnabled(true));
      unawaited(_prime());
    }
  }

  final AndroidEqualizer? _equalizer;

  AndroidEqualizerParameters? _parameters;
  final Map<int, double> _applied = {};
  AudioProfile _profile = const AudioProfile();
  bool _isPriming = false;
  bool _isShaping = false;

  bool get isAvailable => _parameters != null;

  Map<String, Object> get diagnostics => {
    'supported': _equalizer != null,
    'ready': _parameters != null,
    'enabled': _equalizer?.enabled ?? false,
    'hasNonFlatBands': _applied.values.any((gain) => gain != 0),
  };

  /// An [AudioPipeline] carrying this filter, or `null` where there is none.
  AudioPipeline? get pipeline => _equalizer == null
      ? null
      : AudioPipeline(androidAudioEffects: [_equalizer]);

  Future<void> _prime() async {
    if (_isPriming || _parameters != null) return;
    _isPriming = true;
    try {
      final resolved = await _equalizer!.parameters;
      _parameters = resolved;
      unawaited(_shape());
    } on PlayerInterruptedException {
      // Expected if player source was superseded during priming.
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'tone playback',
          context: ErrorDescription('while initializing the player equalizer'),
        ),
      );
    } finally {
      _isPriming = false;
    }
  }

  void applyProfile(AudioProfile profile) {
    _profile = profile;
    if (_parameters != null) {
      unawaited(_shape());
    } else if (_equalizer != null) {
      unawaited(_prime());
    }
  }

  Future<void> _shape() async {
    final parameters = _parameters;
    if (parameters == null || _isShaping) return;
    _isShaping = true;
    try {
      for (final band in parameters.bands) {
        final gain = _profile
            .gainAt(band.centerFrequency)
            .clamp(parameters.minDecibels, parameters.maxDecibels)
            .toDouble();
        if (_applied[band.index] == gain) continue;
        await band.setGain(gain);
        _applied[band.index] = gain;
      }
    } on PlayerInterruptedException {
      // Ignore cancellation during track switch
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'tone playback',
          context: ErrorDescription(
            'while applying the audio equalizer profile',
          ),
        ),
      );
    } finally {
      _isShaping = false;
    }
  }
}
