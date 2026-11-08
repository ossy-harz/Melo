import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:melo_player/features/spotify/spotify_service.dart';
import 'package:melo_player/features/youtube/youtube_auth_service.dart';

enum AudioAddonCategory {
  stream,
  metadata,
  freeMusic,
  selfHosted,
}

class AudioSourceAddon {
  const AudioSourceAddon({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.icon,
    this.isEnabled = true,
    this.priority = 0,
    this.version = '1.0.0',
  });

  final String id;
  final String name;
  final String description;
  final AudioAddonCategory category;
  final IconData icon;
  final bool isEnabled;
  final int priority;
  final String version;

  AudioSourceAddon copyWith({
    bool? isEnabled,
    int? priority,
  }) {
    return AudioSourceAddon(
      id: id,
      name: name,
      description: description,
      category: category,
      icon: icon,
      isEnabled: isEnabled ?? this.isEnabled,
      priority: priority ?? this.priority,
      version: version,
    );
  }
}

class SubsonicConfig {
  const SubsonicConfig({
    this.serverUrl = '',
    this.username = '',
    this.password = '',
  });

  final String serverUrl;
  final String username;
  final String password;

  bool get isConfigured => serverUrl.isNotEmpty && username.isNotEmpty;
}

class AudioAddonManager {
  AudioAddonManager._();
  static final AudioAddonManager instance = AudioAddonManager._();

  static const String _enabledAddonsPrefix = 'tone_addon_enabled_';
  static const String _subsonicUrlKey = 'tone_subsonic_url';
  static const String _subsonicUserKey = 'tone_subsonic_user';
  static const String _subsonicPassKey = 'tone_subsonic_pass';

  final List<AudioSourceAddon> _defaultAddons = [
    const AudioSourceAddon(
      id: 'youtube_music',
      name: 'YouTube Music Streamer',
      description: 'Stream full high-fidelity Opus/AAC audio, smart mixes, and cached lyrics.',
      category: AudioAddonCategory.stream,
      icon: Icons.play_circle_fill_rounded,
      isEnabled: true,
      priority: 1,
      version: '2.1.0',
    ),
    const AudioSourceAddon(
      id: 'spotify_matcher',
      name: 'Spotify Playlist Matcher',
      description: 'Import Spotify playlists, albums, and match verified tracks for playback.',
      category: AudioAddonCategory.metadata,
      icon: Icons.playlist_add_rounded,
      isEnabled: true,
      priority: 2,
      version: '1.4.0',
    ),
    const AudioSourceAddon(
      id: 'lrclib_itunes_metadata',
      name: 'LRCLIB & iTunes Hi-Res Enricher',
      description: 'Automatic word-synced LRC lyrics, 1000x1000 studio cover art, and album metadata.',
      category: AudioAddonCategory.metadata,
      icon: Icons.lyrics_rounded,
      isEnabled: true,
      priority: 3,
      version: '2.0.0',
    ),
    const AudioSourceAddon(
      id: 'subsonic_navidrome',
      name: 'Subsonic / Navidrome',
      description: 'Self-hosted music server streaming and offline synchronization.',
      category: AudioAddonCategory.selfHosted,
      icon: Icons.dns_rounded,
      isEnabled: false,
      priority: 4,
      version: '1.0.0',
    ),
  ];

  List<AudioSourceAddon> _addons = [];
  SubsonicConfig _subsonicConfig = const SubsonicConfig();

  List<AudioSourceAddon> get addons => List.unmodifiable(_addons);
  SubsonicConfig get subsonicConfig => _subsonicConfig;

  final ValueNotifier<List<AudioSourceAddon>> addonsNotifier =
      ValueNotifier<List<AudioSourceAddon>>([]);

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final updated = <AudioSourceAddon>[];

    for (final addon in _defaultAddons) {
      final key = '$_enabledAddonsPrefix${addon.id}';
      final isEnabled = prefs.getBool(key) ?? addon.isEnabled;
      updated.add(addon.copyWith(isEnabled: isEnabled));
    }

    _subsonicConfig = SubsonicConfig(
      serverUrl: prefs.getString(_subsonicUrlKey) ?? '',
      username: prefs.getString(_subsonicUserKey) ?? '',
      password: prefs.getString(_subsonicPassKey) ?? '',
    );

    _addons = updated;
    addonsNotifier.value = List.unmodifiable(_addons);
  }

  Future<void> setAddonEnabled(String addonId, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_enabledAddonsPrefix$addonId', enabled);

    _addons = _addons.map((a) {
      if (a.id == addonId) {
        return a.copyWith(isEnabled: enabled);
      }
      return a;
    }).toList();

    addonsNotifier.value = List.unmodifiable(_addons);
  }

  Future<void> saveSubsonicConfig(SubsonicConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_subsonicUrlKey, config.serverUrl);
    await prefs.setString(_subsonicUserKey, config.username);
    await prefs.setString(_subsonicPassKey, config.password);
    _subsonicConfig = config;
  }

  bool isAddonConfigured(String addonId) {
    switch (addonId) {
      case 'youtube_music':
        return YoutubeAuthService.instance.isLoggedIn;
      case 'spotify_matcher':
        return SpotifyService.instance.isConfigured;
      case 'lrclib_itunes_metadata':
        return true;
      case 'subsonic_navidrome':
        return _subsonicConfig.isConfigured;
      default:
        return false;
    }
  }

  bool isAddonActive(String addonId) {
    final addon = _addons.where((a) => a.id == addonId).firstOrNull;
    return addon?.isEnabled ?? false;
  }
}
