import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:tone_player/features/library/music_library.dart';
import 'package:tone_player/features/player/lyrics_repository.dart';
import 'package:tone_player/features/settings/dj_mix_settings_screen.dart';

class YouScreen extends StatelessWidget {
  const YouScreen({
    required this.onOpenLibrary,
    required this.onOpenMix,
    this.audioHandler,
    this.library,
    super.key,
  });

  final VoidCallback onOpenLibrary;
  final VoidCallback onOpenMix;
  final AudioHandler? audioHandler;
  final MusicLibrary? library;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          sliver: SliverList.list(
            children: [
              Text(
                'Your space',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Make it sound and feel like you.',
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: colors.tertiaryContainer,
                        child: Icon(
                          Icons.person_outline_rounded,
                          color: colors.onTertiaryContainer,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Listening, your way',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'No account required',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: colors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: colors.primary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('YOUR TONE', style: _sectionLabel(context)),
              const SizedBox(height: 8),
              _SettingsRow(
                icon: Icons.tune_rounded,
                title: 'Sound & playback',
                subtitle: 'DJ blends and tempo matching',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        DjMixSettingsScreen(audioHandler: audioHandler),
                  ),
                ),
              ),
              _SettingsRow(
                icon: Icons.auto_awesome_outlined,
                title: 'Personal DJ',
                subtitle: 'Build a set from your own library',
                onTap: onOpenMix,
              ),
              const SizedBox(height: 22),
              Text('YOUR PRIVACY', style: _sectionLabel(context)),
              const SizedBox(height: 8),
              _SettingsRow(
                icon: Icons.wifi_off_rounded,
                title: 'Offline & data',
                subtitle: 'Local playback and data use',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => OfflineDataScreen(
                      library: library,
                      onOpenLibrary: onOpenLibrary,
                    ),
                  ),
                ),
              ),
              _SettingsRow(
                icon: Icons.shield_outlined,
                title: 'Privacy & your data',
                subtitle: 'Optional lyrics and local recommendations',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PrivacyDataScreen(library: library),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text('THE APP', style: _sectionLabel(context)),
              const SizedBox(height: 8),
              _SettingsRow(
                icon: Icons.palette_outlined,
                title: 'Appearance',
                subtitle: 'Red glass visuals and accessible motion',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AppearanceInfoScreen(),
                  ),
                ),
              ),
              _SettingsRow(
                icon: Icons.info_outline_rounded,
                title: 'About Tone',
                subtitle: 'Local-first music, made personal',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AboutToneScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  TextStyle _sectionLabel(BuildContext context) =>
      Theme.of(context).textTheme.labelMedium!.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
      );
}

class OfflineDataScreen extends StatelessWidget {
  const OfflineDataScreen({
    required this.onOpenLibrary,
    this.library,
    super.key,
  });

  final MusicLibrary? library;
  final VoidCallback onOpenLibrary;

  @override
  Widget build(BuildContext context) {
    final tracks = library?.tracks ?? const [];
    final deviceCount = tracks.where((track) => track.isDeviceMedia).length;
    final importedCount = tracks.length - deviceCount;
    return Scaffold(
      appBar: AppBar(title: const Text('Offline & data')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        children: [
          Text(
            'Your music, without the signal.',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            'Tone plays music already on this device. Local playback does not '
            'use mobile data, and scanned originals stay where they are.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 22),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.phone_android_rounded),
                  title: const Text('Scanned device music'),
                  trailing: Text('$deviceCount'),
                ),
                ListTile(
                  leading: const Icon(Icons.folder_copy_outlined),
                  title: const Text('Private imported copies'),
                  trailing: Text('$importedCount'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Automatic overnight downloads, streaming caches, and storage '
            'eviction are not available yet. Optional online lyrics use data '
            'only when you enable that lookup in Privacy & your data.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              onOpenLibrary();
            },
            icon: const Icon(Icons.library_music_rounded),
            label: const Text('Open your library'),
          ),
        ],
      ),
    );
  }
}

class AppearanceInfoScreen extends StatelessWidget {
  const AppearanceInfoScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Appearance')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      children: [
        Container(
          height: 164,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF351618), Color(0xFF76251F), Color(0xFFFF4B3E)],
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.graphic_eq_rounded,
              color: Colors.white,
              size: 54,
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Built around the album art.',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Text(
          'Tone uses a deep red, glass-inspired player with artwork-led color. '
          'Ambient motion follows your device’s Reduce animations accessibility '
          'setting so playback stays comfortable.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    ),
  );
}

class AboutToneScreen extends StatelessWidget {
  const AboutToneScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('About Tone')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      children: [
        Icon(
          Icons.graphic_eq_rounded,
          size: 54,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 18),
        Text(
          'Your music. Your moment.',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Text(
          'Tone is a local-first music player. It works without an account, '
          'keeps recommendations on-device, and gives you control over how '
          'your music flows.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    ),
  );
}

class PrivacyDataScreen extends StatefulWidget {
  const PrivacyDataScreen({this.library, super.key});

  final MusicLibrary? library;

  @override
  State<PrivacyDataScreen> createState() => _PrivacyDataScreenState();
}

class _PrivacyDataScreenState extends State<PrivacyDataScreen> {
  bool _isClearing = false;
  bool _onlineLyricsEnabled = false;
  bool _lyricsSettingLoaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadOnlineLyricsSetting());
  }

  Future<void> _loadOnlineLyricsSetting() async {
    final enabled = await LyricsRepository.onlineLookupEnabled;
    if (mounted) {
      setState(() {
        _onlineLyricsEnabled = enabled;
        _lyricsSettingLoaded = true;
      });
    }
  }

  Future<void> _setOnlineLyricsEnabled(bool enabled) async {
    try {
      await LyricsRepository.setOnlineLookupEnabled(enabled);
      if (mounted) setState(() => _onlineLyricsEnabled = enabled);
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'tone privacy',
          context: ErrorDescription('while updating online lyrics preference'),
        ),
      );
      if (mounted) _showMessage('Could not update online lyrics: $error');
    }
  }

  Future<void> _clearLyricsCache() async {
    setState(() => _isClearing = true);
    try {
      final count = await LyricsRepository.clearCache();
      if (!mounted) return;
      _showMessage(
        count == 0
            ? 'There were no cached lyrics to clear.'
            : 'Cleared cached lyrics for $count songs.',
      );
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'tone privacy',
          context: ErrorDescription('while clearing cached lyrics'),
        ),
      );
      if (mounted) _showMessage('Could not clear cached lyrics: $error');
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
  }

  Future<void> _clearPersonalPreferences() async {
    final library = widget.library;
    if (library == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear personal mix preferences?'),
        content: const Text(
          'This removes your favorites and songs excluded from mixes. '
          'Your music files, playlists, queue, and cached lyrics stay in Tone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep preferences'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear preferences'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isClearing = true);
    try {
      await library.clearPersonalPreferences();
      if (mounted) _showMessage('Favorites and mix exclusions were cleared.');
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'tone privacy',
          context: ErrorDescription('while clearing personal preferences'),
        ),
      );
      if (mounted) _showMessage('Could not clear preferences: $error');
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & your data')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(Icons.shield_moon_outlined, size: 38, color: colors.primary),
          const SizedBox(height: 14),
          Text(
            'Your data, in your control',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          const Text(
            'Tone stores your library references, favorites, playlists, '
            'playback queue and position, mix exclusions, and cached local '
            'lyrics on this device. Tone does not record listening history. '
            'Online lyrics are optional and send only the current song’s '
            'metadata to LRCLIB when enabled.',
          ),
          const SizedBox(height: 24),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Automatic online lyrics'),
            subtitle: const Text(
              'Search LRCLIB for lyrics when local lyrics are unavailable. '
              'The song title, artist, album, and duration are sent for matching.',
            ),
            value: _onlineLyricsEnabled,
            onChanged: _lyricsSettingLoaded ? _setOnlineLyricsEnabled : null,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Cached lyrics'),
            subtitle: const Text(
              'Remove lyrics copied into Tone’s local cache. Sidecar files '
              'and selected lyric files are not deleted.',
            ),
            trailing: TextButton(
              onPressed: _isClearing ? null : _clearLyricsCache,
              child: const Text('Clear'),
            ),
          ),
          if (widget.library != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Favorites and mix exclusions'),
              subtitle: const Text(
                'Clear personal mix signals without deleting music or playlists.',
              ),
              trailing: TextButton(
                onPressed: _isClearing ? null : _clearPersonalPreferences,
                child: const Text('Clear'),
              ),
            ),
          if (_isClearing)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(icon, color: colors.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
