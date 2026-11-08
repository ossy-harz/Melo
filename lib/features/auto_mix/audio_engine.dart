enum AudioDeck { a, b }

enum AudioDeckProcessingState {
  idle,
  loading,
  buffering,
  ready,
  completed,
  error,
}

class AudioDeckSource {
  const AudioDeckSource({required this.uri, this.tag, this.headers});

  final Uri uri;
  final Object? tag;
  final Map<String, String>? headers;
}

class AudioDeckState {
  const AudioDeckState({
    required this.deck,
    required this.processingState,
    required this.playing,
    required this.position,
    required this.bufferedPosition,
    required this.duration,
    required this.gain,
    required this.playbackRate,
    required this.loaded,
    this.error,
  });

  final AudioDeck deck;
  final AudioDeckProcessingState processingState;
  final bool playing;
  final Duration position;
  final Duration bufferedPosition;
  final Duration? duration;
  final double gain;
  final double playbackRate;
  final bool loaded;
  final String? error;
}

class AudioEngineError {
  const AudioEngineError({
    required this.deck,
    required this.error,
    required this.stackTrace,
  });

  final AudioDeck deck;
  final Object error;
  final StackTrace stackTrace;
}

/// Abstraction over independently controllable audio decks.
///
/// Implementations must not use Flutter animation or periodic Dart timers to
/// schedule sample-timed audio work. This interface does not promise
/// sample-accurate synchronization or transition automation.
abstract interface class AudioEngine {
  Future<void> initialize();
  Stream<AudioDeckState> get states;
  Stream<AudioEngineError> get errors;
  AudioDeckState stateFor(AudioDeck deck);
  Future<void> loadDeck(AudioDeck deck, AudioDeckSource source);
  Future<void> unloadDeck(AudioDeck deck);
  Future<void> playDeck(AudioDeck deck);
  Future<void> pauseDeck(AudioDeck deck);
  Future<void> stopDeck(AudioDeck deck);
  Future<void> seekDeck(AudioDeck deck, Duration position);
  Future<void> setDeckGain(AudioDeck deck, double gain);
  Future<void> promoteIncomingDeck();
  Future<void> dispose();
}
