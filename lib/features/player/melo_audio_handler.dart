import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

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
import 'package:melo_player/features/player/audio_profile.dart';
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

  bool _autoplayContinuous = true;
  bool _isExtendingAutoplay = false;
  double _userVolume = 1.0;

  bool get autoplayContinuous => _autoplayContinuous;

  Future<void> setAutoplayContinuous(bool enabled) async {
    _autoplayContinuous = enabled;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_autoplayContinuousKey, enabled);
    _publishState();
  }

  void attachMusicLibrary(MusicLibrary library) {
    _musicLibrary = library;
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
        orElse: () => throw FormatException(
          'Unknown saved repeat mode: $savedRepeatMode',
        ),
      );
    }
    final savedShuffleMode = preferences.getString(_shuffleModeKey);
    if (savedShuffleMode != null) {
      _shuffleMode = AudioServiceShuffleMode.values.firstWhere(
        (mode) => mode.name == savedShuffleMode,
        orElse: () => throw FormatException(
          'Unknown saved shuffle mode: $savedShuffleMode',
        ),
      );
    }
    final savedProfile = preferences.getString(_audioProfileKey);
    if (savedProfile != null) {
      final decoded = jsonDecode(savedProfile);
      if (decoded is! Map) {
        throw const FormatException('Saved audio profile is not an object.');
      }
      _audioProfile = AudioProfile.fromJson(Map<String, Object?>.from(decoded));
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
    if (_audioSession != null) {
      throw StateError('An audio session is already attached.');
    }
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
      final effectiveGain = _userVolume * _audioProfile.outputHeadroom;
      if (_audioEngine.stateFor(AudioDeck.a).playing) {
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
          _audioProfile.outputHeadroom,
        );
      }
      if (_audioEngine.stateFor(AudioDeck.b).loaded &&
          !_audioEngine.stateFor(AudioDeck.b).playing) {
        await _audioEngine.setDeckGain(
          AudioDeck.b,
          _audioProfile.outputHeadroom,
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
    return super.customAction(name, extras);
  }

  Future<void> _preloadNextTrack({bool fromTransition = false}) async {
    final nextIndex = _nextQueueIndex();
    if (nextIndex == null) {
      throw StateError('There is no upcoming track to preload.');
    }
    if (_loadingQueueIndex == nextIndex) return;
    final incomingState = _audioEngine.stateFor(AudioDeck.b);
    if (_preloadedQueueIndex == nextIndex && incomingState.loaded) return;

    _loadingQueueIndex = nextIndex;
    try {
      await _performPreloadNextTrack(
        nextIndex,
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
    required bool fromTransition,
  }) async {
    await _settingsReady;
    if (!fromTransition) await _cancelAndWaitForTransition();
    if (nextIndex != _nextQueueIndex()) {
      throw StateError(
        'The queue changed while the next track was preloading.',
      );
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
    final nextSource = _needsAsyncResolution(_items[nextIndex])
        ? await _resolveSourceFor(_items[nextIndex])
        : _sourceFor(_items[nextIndex]);
    await _autoMixController.preloadIncoming(nextSource);
    _preloadedQueueIndex = nextIndex;
  }

  void _scheduleNextTrackPreload() {
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

    // Start the mix well before the track ends so both tracks overlap like a
    // DJ crossfade instead of a hard cut at the very end. Begin mixing when
    // there's at least one full transition plus an overlap window remaining.
    final mixAhead = Duration(
      seconds: math.max(
        30,
        (transitionDuration.inSeconds * 2).toInt(),
      ),
    );

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
      final result = await _transitionToNextTrack(reportErrors: false);
      if (result['completed'] != true) {
        _automaticTransitionAttempt = null;
      }
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
    final incomingState = _audioEngine.stateFor(AudioDeck.b);
    final outgoingItem = _items[_currentIndex];
    final incomingItem = _items[nextIndex];
    final plan = _autoMixController.planTransition(
      outgoing: TrackAnalysis(
        trackId: outgoingItem.id,
        duration: _analysisDuration(outgoingItem, outgoingState.duration),
      ),
      incoming: TrackAnalysis(
        trackId: incomingItem.id,
        duration: _analysisDuration(incomingItem, incomingState.duration),
      ),
      transitionDuration: diagnosticDuration,
    );
    final remaining = outgoingState.duration == null
        ? null
        : outgoingState.duration! - outgoingState.position;
    if (remaining != null && remaining <= Duration.zero) {
      throw StateError('The outgoing track has no remaining transition time.');
    }
    final effectivePlan =
        remaining != null && remaining < plan.transitionDuration
        ? TransitionPlan(
            outgoingTrackId: plan.outgoingTrackId,
            incomingTrackId: plan.incomingTrackId,
            profile: plan.profile,
            transitionDuration: remaining,
            outgoingTransitionPosition: outgoingState.position,
            incomingEntryPosition: plan.incomingEntryPosition,
            style: plan.style,
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
      targetGain: _audioProfile.outputHeadroom,
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

    _currentIndex = nextIndex;
    _orderPosition = _playOrder.indexOf(nextIndex);
    mediaItem.add(incomingItem);
    _preloadedQueueIndex = null;
    await _autoMixController.promoteIncomingDeck();
    diagnostic
      ?..incomingPromoted = true
      ..recordEvent('incomingDeckPromoted');
    await _autoMixController.unloadIncomingDeck();
    _publishState();
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
  }) async {
    final operation = _activeTransitionOperation;
    if (operation == null) return;
    _transitionCancelRequested = true;
    _transitionCancellationReason = reason;
    _activeDiagnostic
      ?..cancellationReason = reason
      ..recordEvent('cancellationRequested', details: {'reason': reason});
    await _autoMixController.cancelTransition();
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
    await _loadNextPlayable(firstIndex: nextIndex, playWhenReady: _isPlaying);
  }

  @override
  Future<void> skipToPrevious() async {
    if (_audioEngine.stateFor(AudioDeck.a).position >
        const Duration(seconds: 3)) {
      await seek(Duration.zero);
      return;
    }
    if (_orderPosition > 0) {
      await _loadIndex(
        _playOrder[_orderPosition - 1],
        playWhenReady: _isPlaying,
      );
    } else {
      await seek(Duration.zero);
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _items.length) return;
    await _loadIndex(index, playWhenReady: _isPlaying);
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
    await _cancelAndWaitForTransition();
    if (items.isEmpty) {
      await _audioEngine.stopDeck(AudioDeck.a);
      await _unloadDeckBBeforeQueueChange();
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
    await _audioEngine.stopDeck(AudioDeck.a);
    await _unloadDeckBBeforeQueueChange();
    if (!playWhenReady) await _deactivateAudioSession();
    _items = List.unmodifiable(items);
    _currentIndex = initialIndex;
    _automaticTransitionAttempt = null;
    _rebuildPlayOrder(initialIndex);
    queue.add(_items);
    mediaItem.add(_items[initialIndex]);
    final initialSource = _needsAsyncResolution(_items[initialIndex])
        ? await _resolveSourceFor(_items[initialIndex])
        : _sourceFor(_items[initialIndex]);
    await _audioEngine.loadDeck(AudioDeck.a, initialSource);
    await _audioEngine.setDeckGain(AudioDeck.a, _audioProfile.outputHeadroom);
    _publishState();
    if (playWhenReady) await play();
    _prefetchUpcomingStream();
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
        id: localTrack.path,
        extras: {
          ...?item.extras,
          'streamUrl': null,
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
    // Cancel any active transition first so it does not restore gains afterwards
    await _cancelAndWaitForTransition();

    // Immediately update media item so UI displays next track details/artwork without delay
    final targetItem = _items[index];
    mediaItem.add(targetItem);

    // Silence both decks immediately to eliminate popping and volume surge on track change
    if (_audioEngine.stateFor(AudioDeck.a).playing) {
      await _audioEngine.setDeckGain(AudioDeck.a, 0.0);
    }
    if (_audioEngine.stateFor(AudioDeck.b).playing) {
      await _audioEngine.setDeckGain(AudioDeck.b, 0.0);
    }
    await _audioEngine.stopDeck(AudioDeck.a);
    await _unloadDeckBBeforeQueueChange();
    final source = _needsAsyncResolution(targetItem)
        ? await _resolveSourceFor(targetItem)
        : _sourceFor(targetItem);
    try {
      await _audioEngine.loadDeck(AudioDeck.a, source);
      await _audioEngine.setDeckGain(AudioDeck.a, _audioProfile.outputHeadroom);
    } catch (error, stackTrace) {
      // If network stream failed with a source error, attempt secondary fallback proxy stream
      if (source.uri.scheme == 'http' || source.uri.scheme == 'https') {
        debugPrint('Source load error ($error). Attempting secondary fallback proxy stream...');
        try {
          final item = _items[index];
          final rawId = item.extras?['providerTrackId'] as String? ??
              (item.id.startsWith('youtube:') ? item.id.substring(8) : null);
          if (rawId != null) {
            final fallback = await YoutubeAudioService.instance
                .getFallbackStream(rawId);
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
              await _audioEngine.setDeckGain(
                AudioDeck.a,
                _audioProfile.outputHeadroom,
              );
              _currentIndex = index;
              _orderPosition = _playOrder.indexOf(index);
              if (_orderPosition < 0) _rebuildPlayOrder(index);
              final activeFallback = fallbackSource.tag is MediaItem
                  ? fallbackSource.tag as MediaItem
                  : item;
              mediaItem.add(activeFallback);
              _automaticTransitionAttempt = null;
              _publishState();
              if (playWhenReady) await play();
              return;
            }
          }
        } catch (fallbackError) {
          debugPrint('Secondary fallback also failed: $fallbackError');
        }
      }
      _reportPlaybackError(error, stackTrace, 'while loading track for playback');
      rethrow;
    }
    _currentIndex = index;
    _orderPosition = _playOrder.indexOf(index);
    if (_orderPosition < 0) {
      _rebuildPlayOrder(index);
    }
    final activeItem = source.tag is MediaItem ? source.tag as MediaItem : _items[index];
    mediaItem.add(activeItem);
    _automaticTransitionAttempt = null;
    _publishState();
    if (playWhenReady) await play();
    _prefetchUpcomingStream();
  }

  void _prefetchUpcomingStream() {
    final nextIndex = _nextQueueIndex();
    if (nextIndex == null || nextIndex < 0 || nextIndex >= _items.length) return;
    final nextItem = _items[nextIndex];
    if (_needsAsyncResolution(nextItem)) {
      final pId = nextItem.extras?['providerTrackId'] as String? ??
          (nextItem.id.startsWith('youtube:') ? nextItem.id.substring(8) : null);
      if (pId != null && pId.isNotEmpty) {
        unawaited(YoutubeAudioService.instance.getStreamDetails(pId));
      }
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
    _isAdvancing = true;
    try {
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

  /// Automatically fetches and appends related tracks to create an infinite, continuous queue.
  Future<bool> _ensureUpcomingAutoplayTracks() async {
    if (!_autoplayContinuous || _isExtendingAutoplay || _items.isEmpty) return false;
    _isExtendingAutoplay = true;

    try {
      final currentItem = _items[_currentIndex];
      final existingIds = _items.map((i) => i.id).toSet();
      final rawId = currentItem.extras?['providerTrackId'] as String? ??
          (currentItem.id.startsWith('youtube:') ? currentItem.id.substring(8) : null);

      final newItems = <MediaItem>[];

      // 1. Fetch related tracks from YouTube Audio Service
      if (rawId != null || (currentItem.artist != null && currentItem.title.isNotEmpty)) {
        final related = await YoutubeAudioService.instance.getRelatedTracks(
          rawId ?? 'dQw4w9WgXcQ',
          artist: currentItem.artist,
          title: currentItem.title,
        );
        for (final t in related) {
          final item = t.toMediaItem();
          if (!existingIds.contains(item.id)) {
            existingIds.add(item.id);
            newItems.add(item);
          }
          if (newItems.length >= 6) break;
        }
      }

      // 2. Fallback to similar local library tracks
      if (newItems.isEmpty && _musicLibrary != null) {
        final artist = currentItem.artist?.toLowerCase().trim();
        final candidates = _musicLibrary!.tracks.where((t) {
          if (!t.isAvailable) return false;
          final id = t.toMediaItem().id;
          if (existingIds.contains(id)) return false;
          if (artist != null && t.artist.toLowerCase().trim() == artist) return true;
          return false;
        }).toList();

        candidates.shuffle();
        for (final t in candidates.take(6)) {
          newItems.add(t.toMediaItem());
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
      try {
        await _loadIndex(candidate, playWhenReady: playWhenReady);
        return true;
      } on Object catch (error, stackTrace) {
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

    if (throttled) {
      final now = DateTime.now();
      final hasStateChange = processingState != _lastPublishedProcessingState ||
          isPlaying != _lastPublishedPlaying ||
          queueIndex != _lastPublishedIndex;
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

    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          _isAnyDeckPlaying ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
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
    if (_parameters != null) unawaited(_shape());
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
