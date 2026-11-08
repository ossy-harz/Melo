import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:melo_player/features/auto_mix/audio_engine.dart';
import 'package:melo_player/features/auto_mix/just_audio_dual_deck_engine.dart';

void main() {
  late _FakeAudioDeckPlayerFactory factory;
  late JustAudioDualDeckEngine engine;

  setUp(() {
    factory = _FakeAudioDeckPlayerFactory();
    engine = JustAudioDualDeckEngine(playerFactory: factory);
  });

  tearDown(() async {
    await engine.dispose();
  });

  Future<void> initialize() => engine.initialize();

  AudioDeckSource source(String name) =>
      AudioDeckSource(uri: Uri.parse('file:///$name.mp3'));

  test(
    'loads and plays Deck A while preloading Deck B independently',
    () async {
      await initialize();
      await engine.loadDeck(AudioDeck.a, source('current'));
      await engine.playDeck(AudioDeck.a);
      await engine.seekDeck(AudioDeck.a, const Duration(seconds: 12));
      await engine.loadDeck(AudioDeck.b, source('upcoming'));

      final deckA = engine.stateFor(AudioDeck.a);
      final deckB = engine.stateFor(AudioDeck.b);
      expect(deckA.loaded, isTrue);
      expect(deckA.playing, isTrue);
      expect(deckA.position, const Duration(seconds: 12));
      expect(deckB.loaded, isTrue);
      expect(deckB.playing, isFalse);
      expect(deckB.position, Duration.zero);
      expect(factory.players[AudioDeck.a]!.loadedUri, source('current').uri);
      expect(factory.players[AudioDeck.b]!.loadedUri, source('upcoming').uri);
    },
  );

  test('both decks can overlap with independent gains and positions', () async {
    await initialize();
    await engine.loadDeck(AudioDeck.a, source('current'));
    await engine.loadDeck(AudioDeck.b, source('next'));
    await engine.setDeckGain(AudioDeck.a, 0.7);
    await engine.setDeckGain(AudioDeck.b, 0.25);
    await engine.playDeck(AudioDeck.a);
    await engine.playDeck(AudioDeck.b);
    await engine.seekDeck(AudioDeck.a, const Duration(seconds: 9));
    await engine.seekDeck(AudioDeck.b, const Duration(seconds: 2));

    expect(engine.stateFor(AudioDeck.a).playing, isTrue);
    expect(engine.stateFor(AudioDeck.b).playing, isTrue);
    expect(engine.stateFor(AudioDeck.a).gain, 0.7);
    expect(engine.stateFor(AudioDeck.b).gain, 0.25);
    expect(engine.stateFor(AudioDeck.a).position, const Duration(seconds: 9));
    expect(engine.stateFor(AudioDeck.b).position, const Duration(seconds: 2));
  });

  test('unloading Deck B leaves Deck A playing', () async {
    await initialize();
    await engine.loadDeck(AudioDeck.a, source('current'));
    await engine.loadDeck(AudioDeck.b, source('next'));
    await engine.playDeck(AudioDeck.a);
    await engine.playDeck(AudioDeck.b);

    await engine.unloadDeck(AudioDeck.b);

    expect(engine.stateFor(AudioDeck.a).playing, isTrue);
    expect(engine.stateFor(AudioDeck.a).loaded, isTrue);
    expect(engine.stateFor(AudioDeck.b).playing, isFalse);
    expect(engine.stateFor(AudioDeck.b).loaded, isFalse);
    expect(factory.players[AudioDeck.b]!.unloadCount, 1);
  });

  test('promotes Deck B to Deck A and remaps deck states', () async {
    await initialize();
    await engine.loadDeck(AudioDeck.a, source('current'));
    await engine.loadDeck(AudioDeck.b, source('next'));
    await engine.setDeckGain(AudioDeck.a, 0);
    await engine.setDeckGain(AudioDeck.b, 0.8);
    await engine.playDeck(AudioDeck.b);
    await engine.seekDeck(AudioDeck.b, const Duration(seconds: 7));

    await engine.promoteIncomingDeck();

    expect(engine.stateFor(AudioDeck.a).deck, AudioDeck.a);
    expect(engine.stateFor(AudioDeck.a).playing, isTrue);
    expect(engine.stateFor(AudioDeck.a).position, const Duration(seconds: 7));
    expect(engine.stateFor(AudioDeck.a).gain, 0.8);
    expect(engine.stateFor(AudioDeck.b).deck, AudioDeck.b);
    expect(engine.stateFor(AudioDeck.b).playing, isFalse);
    expect(engine.stateFor(AudioDeck.b).gain, 0);

    await engine.unloadDeck(AudioDeck.b);
    expect(engine.stateFor(AudioDeck.a).playing, isTrue);
  });

  test('a Deck B load error is reported without stopping Deck A', () async {
    await initialize();
    await engine.loadDeck(AudioDeck.a, source('current'));
    await engine.playDeck(AudioDeck.a);
    final errors = <AudioEngineError>[];
    final subscription = engine.errors.listen(errors.add);
    addTearDown(subscription.cancel);

    await expectLater(
      engine.loadDeck(
        AudioDeck.b,
        AudioDeckSource(uri: Uri.parse('file:///load-failure.mp3')),
      ),
      throwsStateError,
    );
    await Future<void>.delayed(Duration.zero);

    expect(engine.stateFor(AudioDeck.a).playing, isTrue);
    expect(engine.stateFor(AudioDeck.a).loaded, isTrue);
    expect(engine.stateFor(AudioDeck.b).loaded, isFalse);
    expect(errors, isNotEmpty);
    expect(errors.any((error) => error.deck == AudioDeck.b), isTrue);
  });

  test('repeated loads reuse the same deck players', () async {
    await initialize();
    await engine.loadDeck(AudioDeck.a, source('a-first'));
    await engine.loadDeck(AudioDeck.a, source('a-second'));
    await engine.loadDeck(AudioDeck.b, source('b-first'));
    await engine.loadDeck(AudioDeck.b, source('b-second'));

    expect(factory.createCount, 2);
    expect(factory.players[AudioDeck.a]!.loadCount, 2);
    expect(factory.players[AudioDeck.b]!.loadCount, 2);
    expect(factory.players[AudioDeck.a]!.loadedUri, source('a-second').uri);
    expect(factory.players[AudioDeck.b]!.loadedUri, source('b-second').uri);
  });

  test(
    'supports pause, seek, resume, stop, and rejects invalid gain',
    () async {
      await initialize();
      await engine.loadDeck(AudioDeck.a, source('current'));
      await engine.playDeck(AudioDeck.a);
      await engine.pauseDeck(AudioDeck.a);
      expect(engine.stateFor(AudioDeck.a).playing, isFalse);

      await engine.seekDeck(AudioDeck.a, const Duration(seconds: 5));
      await engine.playDeck(AudioDeck.a);
      expect(engine.stateFor(AudioDeck.a).playing, isTrue);
      expect(engine.stateFor(AudioDeck.a).position, const Duration(seconds: 5));

      await engine.stopDeck(AudioDeck.a);
      expect(engine.stateFor(AudioDeck.a).playing, isFalse);
      expect(engine.stateFor(AudioDeck.a).loaded, isTrue);

      await expectLater(engine.setDeckGain(AudioDeck.a, 1.1), throwsRangeError);
      await expectLater(
        engine.setDeckGain(AudioDeck.b, double.nan),
        throwsRangeError,
      );
    },
  );

  test('releases both deck players and rejects later use', () async {
    await initialize();
    await engine.dispose();

    expect(factory.players.values.every((player) => player.disposed), isTrue);
    expect(() => engine.stateFor(AudioDeck.a), throwsStateError);
    await expectLater(engine.initialize(), throwsStateError);
  });
}

class _FakeAudioDeckPlayerFactory implements AudioDeckPlayerFactory {
  final players = <AudioDeck, _FakeAudioDeckPlayer>{};
  int createCount = 0;

  @override
  AudioDeckPlayer create(AudioDeck deck) {
    createCount++;
    final player = _FakeAudioDeckPlayer(deck);
    players[deck] = player;
    return player;
  }
}

class _FakeAudioDeckPlayer implements AudioDeckPlayer {
  _FakeAudioDeckPlayer(this._deck);

  final AudioDeck _deck;
  final StreamController<AudioDeckState> _states =
      StreamController<AudioDeckState>.broadcast(sync: true);
  final StreamController<AudioEngineError> _errors =
      StreamController<AudioEngineError>.broadcast(sync: true);
  AudioDeckProcessingState _processingState = AudioDeckProcessingState.idle;
  bool _playing = false;
  bool _loaded = false;
  bool disposed = false;
  int loadCount = 0;
  int unloadCount = 0;
  Duration _position = Duration.zero;
  double _gain = 1;
  Uri? loadedUri;

  @override
  Stream<AudioDeckState> get states => _states.stream;

  @override
  Stream<AudioEngineError> get errors => _errors.stream;

  @override
  AudioDeckState get state => AudioDeckState(
    deck: _deck,
    processingState: _processingState,
    playing: _playing,
    position: _position,
    bufferedPosition: _position,
    duration: const Duration(minutes: 3),
    gain: _gain,
    playbackRate: 1,
    loaded: _loaded,
  );

  @override
  Future<void> initialize() async {}

  @override
  Future<void> load(AudioDeckSource source) async {
    loadCount++;
    if (source.uri.path.contains('load-failure')) {
      _loaded = false;
      _processingState = AudioDeckProcessingState.error;
      _states.add(state);
      throw StateError('Test decoder failure.');
    }
    loadedUri = source.uri;
    _loaded = true;
    _processingState = AudioDeckProcessingState.ready;
    _position = Duration.zero;
    _states.add(state);
  }

  @override
  Future<void> unload() async {
    unloadCount++;
    _playing = false;
    _loaded = false;
    _position = Duration.zero;
    _processingState = AudioDeckProcessingState.idle;
    _states.add(state);
  }

  @override
  Future<void> play() async {
    if (!_loaded) throw StateError('No source loaded.');
    _playing = true;
    _states.add(state);
  }

  @override
  Future<void> pause() async {
    _playing = false;
    _states.add(state);
  }

  @override
  Future<void> stop() async {
    _playing = false;
    _states.add(state);
  }

  @override
  Future<void> seek(Duration position) async {
    _position = position;
    _states.add(state);
  }

  @override
  Future<void> setGain(double gain) async {
    if (!gain.isFinite || gain < 0 || gain > 1) {
      throw RangeError.range(gain, 0, 1, 'gain');
    }
    _gain = gain;
    _states.add(state);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await _states.close();
    await _errors.close();
  }
}
