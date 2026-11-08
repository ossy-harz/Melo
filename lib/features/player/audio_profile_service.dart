import 'package:audio_service/audio_service.dart';
import 'package:tone_player/features/player/audio_profile.dart';

abstract interface class AudioProfileService {
  Future<AudioProfile> loadAudioProfile();
  Future<AudioOutputCapabilities> loadAudioCapabilities();
  Future<void> setAudioProfile(AudioProfile profile);
}

class AudioServiceAudioProfileService implements AudioProfileService {
  const AudioServiceAudioProfileService(this._audioHandler);

  final AudioHandler _audioHandler;

  @override
  Future<AudioProfile> loadAudioProfile() async {
    final value = await _audioHandler.customAction('getAudioProfile');
    if (value is! Map) {
      throw const FormatException(
        'The audio service returned no audio profile.',
      );
    }
    return AudioProfile.fromJson(Map<String, Object?>.from(value));
  }

  @override
  Future<AudioOutputCapabilities> loadAudioCapabilities() async {
    final value = await _audioHandler.customAction('getAudioCapabilities');
    return AudioOutputCapabilities.fromPlatform(value);
  }

  @override
  Future<void> setAudioProfile(AudioProfile profile) async {
    await _audioHandler.customAction('setAudioProfile', {
      'profile': profile.toJson(),
    });
  }
}
