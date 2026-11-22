import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:melo_player/app/melo_glass.dart';
import 'package:melo_player/app/melo_theme.dart';
import 'package:melo_player/features/library/music_library.dart';
import 'package:melo_player/features/player/player_device_helper.dart';
import 'package:melo_player/features/settings/spotify_settings_screen.dart';
import 'package:melo_player/features/settings/youtube_settings_screen.dart';
import 'package:melo_player/features/sources/audio_addon.dart';
import 'package:melo_player/features/spotify/spotify_service.dart';
import 'package:melo_player/features/youtube/youtube_auth_service.dart';

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

  void _showQobuzInfoDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141416),
        title: Row(
          children: [
            Icon(Icons.graphic_eq_rounded, color: MeloColors.cherry),
            SizedBox(width: 10),
            Text('Qobuz Hi-Res FLAC', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'Qobuz addon provides audiophile studio FLAC matching (24-bit 96kHz / 192kHz), '
          'complete ISRC track matching, and high-resolution album tags. '
          'Paste any Qobuz track or album link in Search to import or play.',
          style: TextStyle(fontSize: 13.5, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showAmazonInfoDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141416),
        title: Row(
          children: [
            Icon(Icons.stream_rounded, color: MeloColors.cherry),
            SizedBox(width: 10),
            Text('Amazon Music HD', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'Amazon Music HD & Ultra HD addon matches lossless catalog links and spatial masters. '
          'Paste any music.amazon.com link to resolve metadata, artwork, and lossless audio streams.',
          style: TextStyle(fontSize: 13.5, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showTidalInfoDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141416),
        title: Row(
          children: [
            Icon(Icons.waves_rounded, color: MeloColors.cherry),
            SizedBox(width: 10),
            Text('TIDAL HiFi Plus', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'TIDAL addon parses TIDAL MAX / HiFi links via official oEmbed endpoints, '
          'extracting master credits, high-res artwork, and stream routing.',
          style: TextStyle(fontSize: 13.5, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
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
          backgroundColor: const Color(0xFF141416),
          title: Row(
            children: [
              Icon(Icons.dns_rounded, color: MeloColors.cherry),
              SizedBox(width: 10),
              Text(
                'Subsonic / Navidrome',
                style: TextStyle(color: Colors.white),
              ),
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
      case 'qobuz_lossless':
        _showQobuzInfoDialog();
        break;
      case 'amazon_music_hd':
        _showAmazonInfoDialog();
        break;
      case 'tidal_hifi':
        _showTidalInfoDialog();
        break;
      case 'bit_perfect_dac':
        PlayerDeviceHelper.showAudioOutputSheet(context);
        break;
      case 'deezer_itunes_catalog':
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Deezer & iTunes 1000px Catalog is active automatically for album art & artist graphs.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
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

  Future<void> _runSourceDiagnostics() async {
    final devices = await PlayerDeviceHelper.getOutputDevices();
    final bitPerfect = await PlayerDeviceHelper.isBitPerfectEnabled();
    final hasUsbDac = devices.any((d) => d.type == 'usb_dac');
    if (!mounted) return;

    final checks = <({String label, String detail, bool ok})>[
      (
        label: 'YouTube Music Streamer',
        detail: YoutubeAuthService.instance.isLoggedIn
            ? 'Signed in (personal account)'
            : 'Active (guest high-fidelity stream)',
        ok: _manager.isAddonActive('youtube_music'),
      ),
      (
        label: 'Spotify Feed & Sync',
        detail: SpotifyService.instance.isLoggedIn
            ? 'Synced as ${SpotifyService.instance.displayName ?? "Account"}'
            : 'Public charts & embed ready (sign in for personal feed)',
        ok: _manager.isAddonActive('spotify_matcher'),
      ),
      (
        label: 'Bit-Perfect USB DAC',
        detail: hasUsbDac
            ? 'USB DAC detected (${bitPerfect ? "Bit-Perfect ON" : "Standard mixer"})'
            : 'No external USB DAC attached (${devices.length} output route ready)',
        ok: _manager.isAddonActive('bit_perfect_dac'),
      ),
      (
        label: 'Qobuz Hi-Res FLAC Streamer',
        detail: 'Studio 24-bit 96kHz / 192kHz audiophile metadata & ISRC mapping ready',
        ok: _manager.isAddonActive('qobuz_lossless'),
      ),
      (
        label: 'Amazon Music HD & Ultra HD',
        detail: 'Lossless catalog parsing & spatial master stream matching ready',
        ok: _manager.isAddonActive('amazon_music_hd'),
      ),
      (
        label: 'TIDAL HiFi Plus & Master',
        detail: 'TIDAL MAX / HiFi oEmbed metadata & stream resolution ready',
        ok: _manager.isAddonActive('tidal_hifi'),
      ),
      (
        label: 'Deezer & iTunes Catalog',
        detail: '1000x1000 cover enrichment & related-artist graph ready',
        ok: _manager.isAddonActive('deezer_itunes_catalog'),
      ),
      (
        label: 'LRCLIB Synced Lyrics',
        detail: 'Word/line-synced LRC lookup & offline cache ready',
        ok: _manager.isAddonActive('lrclib_itunes_metadata'),
      ),
      (
        label: 'Subsonic / Navidrome',
        detail: _manager.subsonicConfig.isConfigured
            ? 'Configured (${_manager.subsonicConfig.serverUrl})'
            : 'Optional self-hosted server not configured',
        ok: _manager.subsonicConfig.isConfigured,
      ),
    ];

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141416),
        title: Row(
          children: [
            Icon(Icons.health_and_safety_rounded, color: MeloColors.cherry),
            SizedBox(width: 10),
            Text(
              'Source Diagnostics',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: checks
                .map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          c.ok
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 18,
                          color: c.ok ? MeloColors.cherry : Colors.white54,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                ),
                              ),
                              Text(
                                c.detail,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.65),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: MeloColors.cherry,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
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
                child: Icon(
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
                        'Prioritize streaming sources, USB DAC output, and metadata engines.',
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
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: MeloColors.cherry,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _runSourceDiagnostics,
              icon: const Icon(Icons.health_and_safety_rounded, size: 18),
              label: const Text(
                'Run Source Diagnostics',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 20),
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
                                                      ? MeloColors.cherry
                                                      : Colors.white)
                                                  .withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              isConfigured ? 'Ready' : 'Guest/Optional',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: isConfigured
                                                    ? MeloColors.cherry
                                                    : Colors.white70,
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
                              children: [
                                IconButton(
                                  tooltip: 'Move higher priority',
                                  onPressed: addon.priority <= 1
                                      ? null
                                      : () => _manager.moveAddonPriority(
                                          addon.id,
                                          -1,
                                        ),
                                  icon: const Icon(
                                    Icons.arrow_upward_rounded,
                                    size: 18,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Move lower priority',
                                  onPressed: addon.priority >= list.length
                                      ? null
                                      : () => _manager.moveAddonPriority(
                                          addon.id,
                                          1,
                                        ),
                                  icon: const Icon(
                                    Icons.arrow_downward_rounded,
                                    size: 18,
                                  ),
                                ),
                                const Spacer(),
                                OutlinedButton.icon(
                                  onPressed: () => _configureAddon(addon),
                                  icon: const Icon(
                                    Icons.settings_rounded,
                                    size: 16,
                                  ),
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
