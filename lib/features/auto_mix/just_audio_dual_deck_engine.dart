import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:melo_player/features/auto_mix/audio_engine.dart';

abstract interface class AudioDeckPlayer {
  Stream<AudioDeckState> get states;
  Stream<AudioEngineError> get errors;
  AudioDeckState get state;

  Future<void> initialize();
  Future<void> load(AudioDeckSource source);
  Future<void> unload();
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setGain(double gain);
  Future<void> dispose();
}

abstract interface class AudioDeckPlayerFactory {
  AudioDeckPlayer create(AudioDeck deck);
}

class JustAudioDeckPlayerFactory implements AudioDeckPlayerFactory {
  const JustAudioDeckPlayerFactory({
    this.primaryAudioPipeline,
    this.secondaryAudioPipeline,
  });

  final AudioPipeline? primaryAudioPipeline;
  final AudioPipeline? secondaryAudioPipeline;

  @override
  AudioDeckPlayer create(AudioDeck deck) => _JustAudioDeckPlayer(
    deck,
    AudioPlayer(
      handleAudioSessionActivation: false,
      handleInterruptions: false,
      audioPipeline: deck == AudioDeck.a
          ? primaryAudioPipeline
          : secondaryAudioPipeline,
    ),
  );
}

/// Two independent just_audio players. Commands are asynchronous platform
/// calls; this engine does not promise synchronized start or sample-accurate
/// gain automation.
class JustAudioDualDeckEngine implements AudioEngine {
  JustAudioDualDeckEngine({
    AudioDeckPlayerFactory playerFactory = const JustAudioDeckPlayerFactory(),
  }) : _players = {
         AudioDeck.a: playerFactory.create(AudioDeck.a),
         AudioDeck.b: playerFactory.create(AudioDeck.b),
       } {
    for (final player in _players.values) {
      _subscriptions
        ..add(
          player.states.listen(
            (state) => _states.add(_stateForCurrentDeck(player, state)),
          ),
        )
        ..add(
          player.errors.listen(
            (error) => _errors.add(_errorForCurrentDeck(player, error)),
          ),
        );
    }
  }

  final Map<AudioDeck, AudioDeckPlayer> _players;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final StreamController<AudioDeckState> _states =
      StreamController<AudioDeckState>.broadcast();
  final StreamController<AudioEngineError> _errors =
      StreamController<AudioEngineError>.broadcast();

  bool _initialized = false;
  bool _disposed = false;

  @override
  Stream<AudioDeckState> get states => _states.stream;

  @override
  Stream<AudioEngineError> get errors => _errors.stream;

  @override
  Future<void> initialize() async {
    _ensureNotDisposed();
    if (_initialized) return;
    await Future.wait(_players.values.map((player) => player.initialize()));
    _initialized = true;
  }

  @override
  AudioDeckState stateFor(AudioDeck deck) {
    _ensureNotDisposed();
    return _withDeck(_playerFor(deck).state, deck);
  }

  @override
  Future<void> loadDeck(AudioDeck deck, AudioDeckSource source) =>
      _run(deck, () => _playerFor(deck).load(source));

  @override
  Future<void> unloadDeck(AudioDeck deck) =>
      _run(deck, () => _playerFor(deck).unload());

  @override
  Future<void> playDeck(AudioDeck deck) =>
      _run(deck, () => _playerFor(deck).play());

  @override
  Future<void> pauseDeck(AudioDeck deck) =>
      _run(deck, () => _playerFor(deck).pause());

  @override
  Future<void> stopDeck(AudioDeck deck) =>
      _run(deck, () => _playerFor(deck).stop());

  @override
  Future<void> seekDeck(AudioDeck deck, Duration position) =>
      _run(deck, () => _playerFor(deck).seek(position));

  @override
  Future<void> setDeckGain(AudioDeck deck, double gain) =>
      _run(deck, () => _playerFor(deck).setGain(gain));

  @override
  Future<void> promoteIncomingDeck() async {
    _ensureInitialized();
    if (!stateFor(AudioDeck.b).loaded) {
      throw StateError('Deck B must be loaded before it can be promoted.');
    }
    final outgoing = _players[AudioDeck.a]!;
    _players[AudioDeck.a] = _players[AudioDeck.b]!;
    _players[AudioDeck.b] = outgoing;
    _states
      ..add(stateFor(AudioDeck.a))
      ..add(stateFor(AudioDeck.b));
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    try {
      await Future.wait(_players.values.map((player) => player.dispose()));
    } finally {
      await _states.close();
      await _errors.close();
    }
  }

  Future<void> _run(AudioDeck deck, Future<void> Function() operation) async {
    _ensureInitialized();
    try {
      await operation();
    } on Object catch (error, stackTrace) {
      _errors.add(
        AudioEngineError(deck: deck, error: error, stackTrace: stackTrace),
      );
      rethrow;
    }
  }

  AudioDeckPlayer _playerFor(AudioDeck deck) => _players[deck]!;

  AudioDeckState _stateForCurrentDeck(
    AudioDeckPlayer player,
    AudioDeckState state,
  ) {
    final deck = _players.entries
        .where((entry) => identical(entry.value, player))
        .map((entry) => entry.key)
        .firstOrNull;
    return deck == null ? state : _withDeck(state, deck);
  }

  AudioEngineError _errorForCurrentDeck(
    AudioDeckPlayer player,
    AudioEngineError error,
  ) {
    final deck = _players.entries
        .where((entry) => identical(entry.value, player))
        .map((entry) => entry.key)
        .firstOrNull;
    return deck == null
        ? error
        : AudioEngineError(
            deck: deck,
            error: error.error,
            stackTrace: error.stackTrace,
          );
  }

  AudioDeckState _withDeck(AudioDeckState state, AudioDeck deck) =>
      AudioDeckState(
        deck: deck,
        processingState: state.processingState,
        playing: state.playing,
        position: state.position,
        bufferedPosition: state.bufferedPosition,
        duration: state.duration,
        gain: state.gain,
        playbackRate: state.playbackRate,
        loaded: state.loaded,
        error: state.error,
      );

  void _ensureInitialized() {
    _ensureNotDisposed();
    if (!_initialized) {
      throw StateError('The audio engine has not been initialized.');
    }
  }

  void _ensureNotDisposed() {
    if (_disposed) throw StateError('The audio engine has been disposed.');
  }
}

class _JustAudioDeckPlayer implements AudioDeckPlayer {
  _JustAudioDeckPlayer(this._deck, this._player) {
    _subscriptions
      ..add(_player.positionStream.listen((_) => _publishState()))
      ..add(_player.durationStream.listen((_) => _publishState()))
      ..add(_player.playerStateStream.listen((_) => _publishState()))
      ..add(
        _player.errorStream.listen(
          (error) {
            _error = error.message;
            _publishState();
            _errors.add(
              AudioEngineError(
                deck: _deck,
                error: error,
                stackTrace: StackTrace.current,
              ),
            );
          },
          onError: (Object error, StackTrace stackTrace) {
            _error = error.toString();
            _publishState();
            _errors.add(
              AudioEngineError(
                deck: _deck,
                error: error,
                stackTrace: stackTrace,
              ),
            );
          },
        ),
      );
  }

  final AudioDeck _deck;
  final AudioPlayer _player;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final StreamController<AudioDeckState> _states =
      StreamController<AudioDeckState>.broadcast();
  final StreamController<AudioEngineError> _errors =
      StreamController<AudioEngineError>.broadcast();

  bool _loaded = false;
  String? _error;
  double _gain = 1;
  bool _disposed = false;

  @override
  Stream<AudioDeckState> get states => _states.stream;

  @override
  Stream<AudioEngineError> get errors => _errors.stream;

  @override
  AudioDeckState get state => AudioDeckState(
    deck: _deck,
    processingState: _error != null
        ? AudioDeckProcessingState.error
        : switch (_player.processingState) {
            ProcessingState.idle => AudioDeckProcessingState.idle,
            ProcessingState.loading => AudioDeckProcessingState.loading,
            ProcessingState.buffering => AudioDeckProcessingState.buffering,
            ProcessingState.ready => AudioDeckProcessingState.ready,
            ProcessingState.completed => AudioDeckProcessingState.completed,
          },
    playing: _player.playing,
    position: _player.position,
    bufferedPosition: _player.bufferedPosition,
    duration: _player.duration,
    gain: _gain,
    playbackRate: _player.speed,
    loaded: _loaded,
    error: _error,
  );

  @override
  Future<void> initialize() async {
    _ensureNotDisposed();
  }

  @override
  Future<void> load(AudioDeckSource source) async {
    _ensureNotDisposed();
    if (!source.uri.hasScheme) {
      throw ArgumentError.value(source.uri, 'source.uri', 'Must be absolute.');
    }
    _loaded = false;
    _error = null;
    _publishState();
    try {
      await _player.setAudioSource(
        AudioSource.uri(
          source.uri,
          headers: source.headers,
          tag: source.tag,
        ),
      );
      _loaded = true;
      _publishState();
    } on Object catch (error) {
      _error = error.toString();
      _publishState();
      rethrow;
    }
  }

  @override
  Future<void> unload() async {
    _ensureNotDisposed();
    await _player.stop();
    await _player.clearAudioSources();
    _loaded = false;
    _error = null;
    _publishState();
  }

  @override
  Future<void> play() async {
    _ensureNotDisposed();
    if (!_loaded) throw StateError('Deck ${_deck.name} has no loaded source.');
    unawaited(
      _player.play().catchError((Object error, StackTrace stackTrace) {
        _error = error.toString();
        _publishState();
        _errors.add(
          AudioEngineError(deck: _deck, error: error, stackTrace: stackTrace),
        );
      }),
    );
  }

  @override
  Future<void> pause() async {
    _ensureNotDisposed();
    await _player.pause();
    _publishState();
  }

  @override
  Future<void> stop() async {
    _ensureNotDisposed();
    await _player.stop();
    _publishState();
  }

  @override
  Future<void> seek(Duration position) async {
    _ensureNotDisposed();
    if (position < Duration.zero) {
      throw ArgumentError.value(position, 'position', 'Must not be negative.');
    }
    await _player.seek(position);
    _publishState();
  }

  @override
  Future<void> setGain(double gain) async {
    _ensureNotDisposed();
    if (!gain.isFinite || gain < 0 || gain > 1) {
      throw RangeError.range(gain, 0, 1, 'gain');
    }
    await _player.setVolume(gain);
    _gain = gain;
    _publishState();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    try {
      await _player.dispose();
    } finally {
      await _states.close();
      await _errors.close();
    }
  }

  void _publishState() {
    if (!_states.isClosed) _states.add(state);
  }

  void _ensureNotDisposed() {
    if (_disposed) throw StateError('Deck ${_deck.name} has been disposed.');
  }
}
