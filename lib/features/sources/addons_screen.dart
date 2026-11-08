import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:melo_player/app/melo_glass.dart';
import 'package:melo_player/app/melo_theme.dart';
import 'package:melo_player/features/library/music_library.dart';
import 'package:melo_player/features/settings/spotify_settings_screen.dart';
import 'package:melo_player/features/settings/youtube_settings_screen.dart';
import 'package:melo_player/features/sources/audio_addon.dart';

class AddonsScreen extends StatefulWidget {
  const AddonsScreen({
    this.library,
    this.audioHandler,
    super.key,
  });

  final MusicLibrary? library;
  final AudioHandler? audioHandler;

  @override
  State<AddonsScreen> createState() => _AddonsScreenState();
}

class _AddonsScreenState extends State<AddonsScreen> {
  final AudioAddonManager _manager = AudioAddonManager.instance;

  @override
  void initState() {
    super.initState();
    _manager.initialize().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _showSubsonicConfigDialog() {
    final current = _manager.subsonicConfig;
    final urlController = TextEditingController(text: current.serverUrl);
    final userController = TextEditingController(text: current.username);
    final passController = TextEditingController(text: current.password);

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.dns_rounded, color: Colors.deepPurpleAccent),
              SizedBox(width: 10),
              Text('Subsonic / Navidrome'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Connect your personal self-hosted music server for streaming and syncing.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: urlController,
                  decoration: const InputDecoration(
                    labelText: 'Server URL',
                    hintText: 'https://music.example.com',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: userController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password / Token',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final newConfig = SubsonicConfig(
                  serverUrl: urlController.text.trim(),
                  username: userController.text.trim(),
                  password: passController.text.trim(),
                );
                await _manager.saveSubsonicConfig(newConfig);
                if (newConfig.isConfigured) {
                  await _manager.setAddonEnabled('subsonic_navidrome', true);
                }
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                if (mounted) setState(() {});
              },
              child: const Text('Save & Connect'),
            ),
          ],
        );
      },
    );
  }

  void _configureAddon(AudioSourceAddon addon) {
    switch (addon.id) {
      case 'youtube_music':
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => YoutubeSettingsScreen(
              library: widget.library,
              audioHandler: widget.audioHandler,
            ),
          ),
        ).then((_) {
          if (mounted) setState(() {});
        });
        break;
      case 'spotify_matcher':
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SpotifySettingsScreen(
              library: widget.library,
              audioHandler: widget.audioHandler,
            ),
          ),
        ).then((_) {
          if (mounted) setState(() {});
        });
        break;
      case 'lrclib_itunes_metadata':
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'LRCLIB & iTunes Hi-Res Enricher is active automatically for all streams & downloads.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        break;
      case 'subsonic_navidrome':
        _showSubsonicConfigDialog();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Streaming & Source Addons'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: MeloColors.cherry.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.extension_rounded,
                  color: MeloColors.cherry,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Modular Source Addons',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Enable and prioritize music sources inspired by BitChord architecture.',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'INSTALLED ADDONS',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<List<AudioSourceAddon>>(
            valueListenable: _manager.addonsNotifier,
            builder: (context, addons, _) {
              final list = addons.isNotEmpty ? addons : _manager.addons;
              return Column(
                children: list.map((addon) {
                  final isConfigured = _manager.isAddonConfigured(addon.id);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: MeloGlass(
                      borderRadius: MeloRadii.lg,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(addon.icon, size: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              addon.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: (isConfigured
                                                      ? Colors.greenAccent
                                                      : Colors.amberAccent)
                                                  .withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              isConfigured ? 'Ready' : 'Guest/Optional',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: isConfigured
                                                    ? Colors.greenAccent
                                                    : Colors.amberAccent,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'v${addon.version} · Priority #${addon.priority}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: colors.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: addon.isEnabled,
                                  onChanged: (val) {
                                    _manager.setAddonEnabled(addon.id, val);
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              addon.description,
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.onSurfaceVariant,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _configureAddon(addon),
                                  icon: const Icon(Icons.settings_rounded, size: 16),
                                  label: const Text('Configure'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
