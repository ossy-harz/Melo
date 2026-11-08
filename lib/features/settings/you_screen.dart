import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:tone_player/app/tone_appearance.dart';
import 'package:tone_player/app/tone_glass.dart';
import 'package:tone_player/app/tone_theme.dart';
import 'package:tone_player/features/library/music_library.dart';
import 'package:tone_player/features/mix/smart_playlist_service.dart';
import 'package:tone_player/features/player/audio_profile_service.dart';
import 'package:tone_player/features/player/lyrics_repository.dart';
import 'package:tone_player/features/settings/audio_settings_screen.dart';
import 'package:tone_player/features/settings/auto_mix_settings_screen.dart';
import 'package:tone_player/features/settings/youtube_settings_screen.dart';
import 'package:tone_player/features/sources/addons_screen.dart';
import 'package:tone_player/features/sources/lossless_audio_service.dart';
import 'package:tone_player/features/spotify/spotify_import_sheet.dart';
import 'package:tone_player/features/updates/app_update_service.dart';
import 'package:tone_player/features/youtube/youtube_audio_service.dart';
import 'package:tone_player/features/youtube/youtube_auth_service.dart';

class YouScreen extends StatelessWidget {
  const YouScreen({
    required this.onOpenLibrary,
    required this.onOpenMix,
    this.onSearch,
    this.audioHandler,
    this.audioProfileService,
    this.library,
    super.key,
  });

  final VoidCallback onOpenLibrary;
  final VoidCallback onOpenMix;
  final VoidCallback? onSearch;
  final AudioHandler? audioHandler;
  final AudioProfileService? audioProfileService;
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Your space',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                          ),
                    ),
                  ),
                  if (onSearch != null)
                    IconButton(
                      tooltip: 'Search',
                      onPressed: onSearch,
                      icon: const Icon(Icons.search_rounded),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Make it sound and feel like you.',
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              const _ProfileHero(),
              const SizedBox(height: 26),
              Text('YOUR TONE', style: _sectionLabel(context)),
              const SizedBox(height: 8),
              _SettingsRow(
                icon: Icons.tune_rounded,
                title: 'Sound & playback',
                subtitle: 'Equalizer and playback sound',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AudioSettingsScreen(
                      audioProfileService: audioProfileService,
                    ),
                  ),
                ),
              ),
              _SettingsRow(
                icon: Icons.auto_awesome_outlined,
                title: 'Personal mixes',
                subtitle: 'Build a set from your own library',
                onTap: onOpenMix,
              ),
              _SettingsRow(
                icon: Icons.sync_alt_outlined,
                title: 'AutoMix transitions',
                subtitle: 'Crossfade between tracks in your queue',
                onTap: audioHandler == null
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => AutoMixSettingsScreen(
                              audioHandler: audioHandler!,
                            ),
                          ),
                        ),
              ),
              const SizedBox(height: 22),
              Text('YOUR PRIVACY', style: _sectionLabel(context)),
              const SizedBox(height: 8),
              _SettingsRow(
                icon: Icons.wifi_off_rounded,
                title: 'Offline & data',
                subtitle: 'Download quality, streaming sources & local data',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => OfflineDataScreen(
                      library: library,
                      audioHandler: audioHandler,
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
                subtitle: 'Theme, motion, and player surfaces',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AppearanceInfoScreen(),
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: AppUpdateService.instance,
                builder: (context, _) {
                  final updater = AppUpdateService.instance;
                  final hasUpdate = updater.hasUpdateAvailable;
                  final latestTag = updater.lastResult?.latestRelease?.tagName;
                  return _SettingsRow(
                    icon: hasUpdate
                        ? Icons.system_update_rounded
                        : Icons.info_outline_rounded,
                    title: 'About Tone',
                    subtitle: hasUpdate
                        ? 'Update available ($latestTag) on GitHub · Tap to install'
                        : 'v${updater.currentVersion} · GitHub updates & versions',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AboutToneScreen(),
                      ),
                    ),
                  );
                },
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
    this.audioHandler,
    super.key,
  });

  final MusicLibrary? library;
  final AudioHandler? audioHandler;
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
          ToneGlass(
            borderRadius: ToneRadii.md,
            shadow: false,
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
          Text(
            'STREAMING & DOWNLOAD QUALITY',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
          ),
          const SizedBox(height: 12),
          _QualityAndStreamingSection(
            library: library,
            audioHandler: audioHandler,
          ),
          const SizedBox(height: 24),
          Text(
            'CONNECTED STREAMING SOURCES',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
          ),
          const SizedBox(height: 12),
          _ConnectedSourcesSection(
            library: library,
            audioHandler: audioHandler,
            onOpenLibrary: onOpenLibrary,
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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        children: [
          Container(
            height: 164,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ToneRadii.xl),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF351618),
                  Color(0xFF76251F),
                  Color(0xFFFF4B3E),
                ],
              ),
              boxShadow: ToneShadows.glow(ToneColors.cherry, opacity: 0.28),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(ToneRadii.xl),
              child: Stack(
                children: [
                  Positioned(
                    left: -30,
                    bottom: -50,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.22),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Positioned.fill(child: ToneGrain(opacity: 0.07)),
                  const Center(
                    child: Icon(
                      Icons.graphic_eq_rounded,
                      color: Colors.white,
                      size: 54,
                    ),
                  ),
                ],
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
          const SizedBox(height: 26),
          Text(
            'THEME',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ToneAppearanceController.instance,
            builder: (context, mode, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  expandedInsets: EdgeInsets.zero,
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('System'),
                    ),
                    ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                  ],
                  selected: {mode},
                  onSelectionChanged: (selection) => ToneAppearanceController
                      .instance
                      .setMode(selection.first),
                ),
                const SizedBox(height: 10),
                Text(
                  'Now Playing stays a deep, artwork-led surface in every '
                  'theme, so covers and controls stay vivid and readable.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AboutToneScreen extends StatefulWidget {
  const AboutToneScreen({super.key});

  @override
  State<AboutToneScreen> createState() => _AboutToneScreenState();
}

class _AboutToneScreenState extends State<AboutToneScreen> {
  final AppUpdateService _updater = AppUpdateService.instance;

  @override
  void initState() {
    super.initState();
    _updater.addListener(_onUpdaterChanged);
    unawaited(_updater.initialize(runStartupCheck: false));
    if (_updater.lastResult == null) {
      unawaited(_updater.checkForUpdates(silent: true));
    }
  }

  @override
  void dispose() {
    _updater.removeListener(_onUpdaterChanged);
    super.dispose();
  }

  void _onUpdaterChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _checkNow() async {
    final res = await _updater.checkForUpdates(silent: false);
    if (!mounted) return;
    final msg = res.errorMessage != null
        ? res.errorMessage!
        : res.isUpdateAvailable
        ? 'New version ${res.latestRelease?.tagName} is available!'
        : 'You are on the latest version (v${_updater.currentVersion}).';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _downloadAndInstall(GithubReleaseInfo release) async {
    try {
      final status = await _updater.downloadAndInstallRelease(release);
      if (!mounted) return;
      final message = status == 'PERMISSION_REQUIRED'
          ? 'Allow "Install unknown apps" for Tone, then tap Install APK again.'
          : 'Launching Android package installer for ${release.tagName}...';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Update error: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<void> _editRepositoryDialog() async {
    final controller = TextEditingController(text: _updater.repository);
    final saved = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('GitHub Repository'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your GitHub repository (owner/repo) where Tone releases and APKs are published:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'owner/repo',
                hintText: 'ossy-harz/Tone',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved != null) {
      await _updater.setRepository(saved);
      await _checkNow();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final checkResult = _updater.lastResult;
    final latest = checkResult?.latestRelease;
    final isUpdateAvailable = checkResult?.isUpdateAvailable == true;
    final allReleases = checkResult?.allReleases ?? const <GithubReleaseInfo>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('About Tone'),
        actions: [
          IconButton(
            tooltip: 'Check for updates',
            onPressed: _updater.isChecking ? null : _checkNow,
            icon: _updater.isChecking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF09070C), Color(0xFF3D0919)],
                  ),
                  boxShadow: ToneShadows.glow(ToneColors.cherry, opacity: 0.25),
                ),
                child: const Icon(
                  Icons.graphic_eq_rounded,
                  size: 32,
                  color: ToneColors.cherry,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your music. Your moment.',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Version ${_updater.currentVersion} (Build ${_updater.currentBuildNumber}) · arm64-v8a',
                      style: textTheme.labelMedium?.copyWith(
                        color: ToneColors.cherry,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Tone is a local-first music player. It works without an account, '
            'keeps recommendations on-device, and gives you control over how '
            'your music flows.',
            style: textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          Text(
            'APP UPDATES & VERSIONS (GITHUB)',
            style: textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          ToneGlass(
            borderRadius: ToneRadii.lg,
            shadow: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isUpdateAvailable
                            ? Icons.system_update_rounded
                            : Icons.verified_rounded,
                        color: isUpdateAvailable
                            ? ToneColors.cherry
                            : Colors.greenAccent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isUpdateAvailable
                                  ? 'Update Available · ${latest?.tagName}'
                                  : 'Tone v${_updater.currentVersion} Installed',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'GitHub: github.com/${_updater.repository}',
                              style: textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _editRepositoryDialog,
                        icon: const Icon(Icons.edit_rounded, size: 15),
                        label: const Text('Repo'),
                      ),
                    ],
                  ),
                  if (checkResult?.errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest.withValues(
                          alpha: 0.45,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        checkResult!.errorMessage!,
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                  if (latest != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isUpdateAvailable
                              ? ToneColors.cherry.withValues(alpha: 0.5)
                              : colors.outlineVariant.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${latest.title} (${latest.tagName})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Text(
                                latest.formattedDate,
                                style: textTheme.labelSmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            latest.body,
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                          if (latest.preferredApkAsset != null) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _updater.isDownloading
                                    ? null
                                    : () => _downloadAndInstall(latest),
                                icon: const Icon(
                                  Icons.system_update_alt_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  isUpdateAvailable
                                      ? 'Download & Install ${latest.tagName} (${latest.preferredApkAsset!.formattedSize})'
                                      : 'Reinstall ${latest.tagName} APK (${latest.preferredApkAsset!.formattedSize})',
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (_updater.isDownloading) ...[
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: _updater.downloadProgress > 0.02
                          ? _updater.downloadProgress
                          : null,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Downloading APK update... ${(_updater.downloadProgress * 100).round()}%',
                      style: textTheme.labelSmall?.copyWith(
                        color: ToneColors.cherry,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _updater.isChecking ? null : _checkNow,
                      icon: const Icon(Icons.sync_rounded, size: 18),
                      label: Text(
                        _updater.isChecking
                            ? 'Checking GitHub Releases...'
                            : 'Check for Updates on GitHub',
                      ),
                    ),
                  ),
                  const Divider(height: 20),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text(
                      'Automatically check for updates',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Check github.com/ossy-harz/Tone when Tone starts',
                    ),
                    value: _updater.autoCheckOnStartup,
                    onChanged: (v) => _updater.setAutoCheckOnStartup(v),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text(
                      'Include beta / pre-release versions',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Receive early preview builds tagged as pre-release',
                    ),
                    value: _updater.includePrereleases,
                    onChanged: (v) async {
                      await _updater.setIncludePrereleases(v);
                      await _checkNow();
                    },
                  ),
                ],
              ),
            ),
          ),
          if (allReleases.length > 1) ...[
            const SizedBox(height: 22),
            Text(
              'VERSION HISTORY (${allReleases.length} RELEASES)',
              style: textTheme.labelMedium?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            for (final rel in allReleases.skip(1))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ToneGlass(
                  borderRadius: ToneRadii.md,
                  shadow: false,
                  child: ListTile(
                    title: Text(
                      '${rel.title} (${rel.tagName})',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${rel.formattedDate}${rel.isPrerelease ? " · Pre-release" : ""}',
                    ),
                    trailing: rel.preferredApkAsset != null
                        ? TextButton.icon(
                            onPressed: _updater.isDownloading
                                ? null
                                : () => _downloadAndInstall(rel),
                            icon: const Icon(Icons.download_rounded, size: 16),
                            label: Text(rel.preferredApkAsset!.formattedSize),
                          )
                        : null,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
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

class _ProfileHero extends StatelessWidget {
  const _ProfileHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ToneRadii.xl),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ToneColors.shellRaised,
            Color(0xFF2A0C14),
            ToneColors.cherryDeep,
          ],
          stops: [0, 0.55, 1],
        ),
        boxShadow: ToneShadows.glow(ToneColors.cherry, opacity: 0.24),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ToneRadii.xl),
        child: Stack(
          children: [
            Positioned(
              right: -40,
              top: -50,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      ToneColors.cherryGlow.withValues(alpha: 0.45),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            const Positioned.fill(child: ToneGrain(opacity: 0.06)),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [ToneColors.cherryGlow, ToneColors.cherry],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: ToneColors.cherry.withValues(alpha: 0.5),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.graphic_eq_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Listening, your way',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'No account. No cloud. Just your music.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.72),
                                height: 1.35,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(
                      Icons.high_quality_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'FLAC / Quality',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    backgroundColor: Colors.white.withValues(alpha: 0.14),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.24),
                    ),
                    onPressed: () {
                      LosslessAudioService.instance.selectDownloadQuality(
                        context,
                        title: 'Default Download Format',
                        artist: 'Saved to Music/Tone on your device',
                        forceSheet: true,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(ToneRadii.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(ToneRadii.sm),
                    color: colors.primary.withValues(alpha: dark ? 0.16 : 0.1),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.16),
                    ),
                  ),
                  child: Icon(icon, color: colors.primary, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QualityAndStreamingSection extends StatefulWidget {
  const _QualityAndStreamingSection({
    this.library,
    this.audioHandler,
  });

  final MusicLibrary? library;
  final AudioHandler? audioHandler;

  @override
  State<_QualityAndStreamingSection> createState() =>
      _QualityAndStreamingSectionState();
}

class _QualityAndStreamingSectionState
    extends State<_QualityAndStreamingSection> {
  LosslessAudioQuality _downloadQuality = LosslessAudioQuality.flacHiRes;
  YoutubeAudioQuality _streamingQuality = YoutubeAudioQuality.standard;
  bool _askEveryTime = true;
  bool _continuousAutoplay = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPreferences());
  }

  Future<void> _loadPreferences() async {
    final dlQuality = await LosslessAudioService.instance.getPreferredQuality();
    final ask = await LosslessAudioService.instance.getAskQualityBeforeDownload();
    final streamQ = await YoutubeAudioService.instance.getPreferredQuality();
    final autoplay = SmartPlaylistService.instance.isContinuousAutoplayEnabled;
    if (!mounted) return;
    setState(() {
      _downloadQuality = dlQuality;
      _askEveryTime = ask;
      _streamingQuality = streamQ;
      _continuousAutoplay = autoplay;
    });
  }

  String _streamingQualityLabel(YoutubeAudioQuality q) => switch (q) {
    YoutubeAudioQuality.highest => 'High · 256 kbps AAC / Opus',
    YoutubeAudioQuality.standard => 'Balanced · 128 kbps AAC',
    YoutubeAudioQuality.dataSaver => 'Data Saver · 64 kbps',
  };

  Future<void> _pickDownloadQuality() async {
    final chosen = await LosslessAudioService.instance.selectDownloadQuality(
      context,
      title: 'Default Download Format',
      artist: 'Saved to Music/Tone on your device',
      forceSheet: true,
    );
    if (chosen != null) {
      await _loadPreferences();
    }
  }

  Future<void> _pickStreamingQuality() async {
    final chosen = await showModalBottomSheet<YoutubeAudioQuality>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final colors = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Material(
              color: colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(28),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live Streaming Quality',
                      style: Theme.of(sheetContext).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Streaming plays immediately from the network without saving files to your device.',
                      style: Theme.of(sheetContext).textTheme.bodySmall
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 14),
                    for (final q in YoutubeAudioQuality.values)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          _streamingQuality == q
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: _streamingQuality == q
                              ? ToneColors.cherry
                              : colors.onSurfaceVariant,
                        ),
                        title: Text(
                          _streamingQualityLabel(q),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        onTap: () => Navigator.of(sheetContext).pop(q),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    if (chosen != null) {
      await YoutubeAudioService.instance.setPreferredQuality(chosen);
      if (mounted) setState(() => _streamingQuality = chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ToneGlass(
      borderRadius: ToneRadii.lg,
      shadow: false,
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            ListTile(
              leading: const Icon(
                Icons.high_quality_rounded,
                color: ToneColors.cherry,
              ),
              title: const Text(
                'Download Audio Quality',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(_downloadQuality.shortLabel),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ToneColors.cherry.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _downloadQuality.badge,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: ToneColors.cherry,
                  ),
                ),
              ),
              onTap: _pickDownloadQuality,
            ),
            Divider(
              height: 1,
              color: colors.outlineVariant.withValues(alpha: 0.3),
            ),
            SwitchListTile.adaptive(
              secondary: Icon(
                Icons.tune_rounded,
                color: colors.onSurfaceVariant,
              ),
              title: const Text(
                'Ask quality before downloading',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Choose FLAC, 320 kbps, or 128 kbps each time you tap Download',
              ),
              value: _askEveryTime,
              onChanged: (val) async {
                await LosslessAudioService.instance
                    .setAskQualityBeforeDownload(val);
                if (mounted) setState(() => _askEveryTime = val);
              },
            ),
            Divider(
              height: 1,
              color: colors.outlineVariant.withValues(alpha: 0.3),
            ),
            ListTile(
              leading: const Icon(
                Icons.graphic_eq_rounded,
                color: ToneColors.cherry,
              ),
              title: const Text(
                'Live Streaming Quality',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(_streamingQualityLabel(_streamingQuality)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _pickStreamingQuality,
            ),
            Divider(
              height: 1,
              color: colors.outlineVariant.withValues(alpha: 0.3),
            ),
            SwitchListTile.adaptive(
              secondary: Icon(
                Icons.all_inclusive_rounded,
                color: colors.onSurfaceVariant,
              ),
              title: const Text(
                'Continuous Smart Autoplay',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Keep playing similar studio songs when your queue finishes',
              ),
              value: _continuousAutoplay,
              onChanged: (val) async {
                await SmartPlaylistService.instance
                    .setContinuousAutoplayEnabled(val);
                if (mounted) setState(() => _continuousAutoplay = val);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectedSourcesSection extends StatefulWidget {
  const _ConnectedSourcesSection({
    required this.onOpenLibrary,
    this.library,
    this.audioHandler,
  });

  final MusicLibrary? library;
  final AudioHandler? audioHandler;
  final VoidCallback onOpenLibrary;

  @override
  State<_ConnectedSourcesSection> createState() =>
      _ConnectedSourcesSectionState();
}

class _ConnectedSourcesSectionState extends State<_ConnectedSourcesSection> {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isYtSignedIn = YoutubeAuthService.instance.isLoggedIn;
    final accountName = YoutubeAuthService.instance.accountName;
    return ToneGlass(
      borderRadius: ToneRadii.lg,
      shadow: false,
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            ListTile(
              leading: const Icon(
                Icons.play_circle_fill_rounded,
                color: ToneColors.cherry,
              ),
              title: const Text(
                'YouTube Music Account',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                isYtSignedIn
                    ? 'Connected${accountName != null ? " as $accountName" : ""} · Personalized taste active'
                    : 'Sign in for personalized mixes & liked songs',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context)
                  .push(
                    MaterialPageRoute<void>(
                      builder: (_) => YoutubeSettingsScreen(
                        library: widget.library,
                        audioHandler: widget.audioHandler,
                      ),
                    ),
                  )
                  .then((_) {
                    if (mounted) setState(() {});
                  }),
            ),
            Divider(
              height: 1,
              color: colors.outlineVariant.withValues(alpha: 0.3),
            ),
            ListTile(
              leading: const Icon(
                Icons.playlist_add_check_circle_rounded,
                color: Color(0xFF1DB954),
              ),
              title: const Text(
                'Import Spotify or Music Link',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Paste any Spotify, YouTube, or Deezer playlist link',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => SpotifyImportSheet.show(
                context,
                library: widget.library,
                audioHandler: widget.audioHandler,
              ),
            ),
            Divider(
              height: 1,
              color: colors.outlineVariant.withValues(alpha: 0.3),
            ),
            ListTile(
              leading: Icon(
                Icons.extension_rounded,
                color: colors.primary,
              ),
              title: const Text(
                'Streaming & Source Addons',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Manage providers, LRCLIB/iTunes enricher & Subsonic',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AddonsScreen(
                    library: widget.library,
                    audioHandler: widget.audioHandler,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
