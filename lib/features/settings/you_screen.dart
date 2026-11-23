import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:melo_player/app/melo_appearance.dart';
import 'package:melo_player/app/melo_glass.dart';
import 'package:melo_player/app/melo_theme.dart';
import 'package:melo_player/features/insights/melo_insights_screen.dart';
import 'package:melo_player/features/library/data/library_backup_service.dart';
import 'package:melo_player/features/library/music_library.dart';
import 'package:melo_player/features/mix/smart_playlist_service.dart';
import 'package:melo_player/features/player/audio_profile_service.dart';
import 'package:melo_player/features/player/lyrics_repository.dart';
import 'package:melo_player/features/player/mini_player.dart'
    show clearPlayerMemoryCaches;
import 'package:melo_player/features/settings/audio_settings_screen.dart';
import 'package:melo_player/features/settings/auto_mix_settings_screen.dart';
import 'package:melo_player/features/settings/spotify_settings_screen.dart';
import 'package:melo_player/features/settings/support_feedback_screen.dart';
import 'package:melo_player/features/settings/youtube_settings_screen.dart';
import 'package:melo_player/features/sources/addons_screen.dart';
import 'package:melo_player/features/sources/lossless_audio_service.dart';
import 'package:melo_player/features/sources/music_provider_models.dart';
import 'package:melo_player/features/spotify/spotify_import_sheet.dart';
import 'package:melo_player/features/spotify/spotify_service.dart';
import 'package:melo_player/features/updates/app_update_service.dart';
import 'package:melo_player/features/youtube/youtube_audio_service.dart';
import 'package:melo_player/features/youtube/youtube_auth_service.dart';

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
              const SizedBox(height: 14),
              _SettingsRow(
                icon: Icons.insights_rounded,
                accentColor: const Color(0xFFA855F7),
                title: 'Melo Insights',
                subtitle: 'Personal listening stats, top artists & habits',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MeloInsightsScreen(
                      library: library,
                      audioHandler: audioHandler,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 26),
              Text('APP PREFERENCES', style: _sectionLabel(context)),
              const SizedBox(height: 8),
              ValueListenableBuilder<MusicProviderType>(
                valueListenable: HomeFeedProviderSettings.instance.activeProvider,
                builder: (context, activeProvider, _) {
                  return _SettingsRow(
                    icon: Icons.hub_outlined,
                    accentColor: const Color(0xFF06B6D4),
                    title: 'Home feed & discovery provider',
                    subtitle: '${activeProvider.displayName} · Tap to change provider',
                    onTap: () => _showProviderSelectionSheet(context),
                  );
                },
              ),
              _SettingsRow(
                icon: Icons.tune_rounded,
                accentColor: const Color(0xFF10B981),
                title: 'Sound & playback',
                subtitle: 'Equalizer and playback sound',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AudioSettingsScreen(
                      audioProfileService: audioProfileService,
                      audioHandler: audioHandler,
                    ),
                  ),
                ),
              ),
              _SettingsRow(
                icon: Icons.sync_alt_outlined,
                accentColor: const Color(0xFFF59E0B),
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
                accentColor: const Color(0xFF3B82F6),
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
                accentColor: const Color(0xFF14B8A6),
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
                accentColor: const Color(0xFFEC4899),
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
                    accentColor: hasUpdate ? const Color(0xFF10B981) : const Color(0xFF64748B),
                    title: 'About Melo',
                    subtitle: hasUpdate
                        ? 'Update available ($latestTag) · Tap to install'
                        : 'v${updater.currentVersion} · Support, feedback & updates',
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

class OfflineDataScreen extends StatefulWidget {
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
  State<OfflineDataScreen> createState() => _OfflineDataScreenState();
}

class _OfflineDataScreenState extends State<OfflineDataScreen> {
  bool _isClearing = false;

  void _showStatus(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _clearArtworkAndStreamCache() async {
    final cleared = clearPlayerMemoryCaches();
    _showStatus(
      cleared == 0
          ? 'Artwork & stream caches are already clear.'
          : 'Cleared $cleared cached artwork and stream metadata entries.',
    );
  }

  Future<void> _clearLyricsCache() async {
    setState(() => _isClearing = true);
    try {
      final count = await LyricsRepository.clearCache();
      if (!mounted) return;
      _showStatus(
        count == 0
            ? 'There were no cached lyrics to clear.'
            : 'Cleared cached lyrics for $count songs.',
      );
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
  }

  Future<void> _clearUpdateApks() async {
    setState(() => _isClearing = true);
    try {
      final removed = await AppUpdateService.instance.clearCachedApks();
      if (!mounted) return;
      _showStatus(
        removed == 0
            ? 'No downloaded update APKs to remove.'
            : 'Removed $removed cached APK installer(s).',
      );
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
  }

  Future<void> _exportBackup() async {
    final library = widget.library;
    if (library == null) return;
    setState(() => _isClearing = true);
    try {
      final file = await library.exportExternalBackup();
      if (!mounted) return;
      if (file != null) {
        _showStatus('Persistent backup saved: ${file.path}');
      } else {
        _showStatus('No playlists or favorites to back up yet.');
      }
    } catch (e) {
      if (mounted) _showStatus('Backup failed: $e');
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
  }

  Future<void> _restoreBackup() async {
    final library = widget.library;
    if (library == null) return;
    setState(() => _isClearing = true);
    try {
      var data = await LibraryBackupService.pickAndImportBackup();
      if (data == null) {
        final latest = await LibraryBackupService.findLatestExternalBackup();
        if (latest != null) {
          data = await LibraryBackupService.readBackup(latest);
        }
      }
      if (!mounted) return;
      if (data == null) {
        _showStatus('No backup file found or selected.');
        return;
      }
      final count = await library.restoreFromBackupData(data);
      _showStatus('Restored $count playlist(s) and ${data.favoriteTrackIds.length} favorites!');
    } catch (e) {
      if (mounted) _showStatus('Restore failed: $e');
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tracks = widget.library?.tracks ?? const [];
    final deviceCount = tracks.where((track) => track.isDeviceMedia).length;
    final importedCount = tracks.length - deviceCount;
    return Scaffold(
      appBar: AppBar(title: const Text('Offline & data')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        children: [
          Text(
            'Your music, without the signal.',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            'Melo plays music stored on your device offline. Downloaded songs '
            'and artwork saved to Music/Tone remain available with zero mobile '
            'data usage.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 22),
          MeloGlass(
            borderRadius: MeloRadii.md,
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
                  title: const Text('Saved downloads & imports'),
                  trailing: Text('$importedCount'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'CACHE & STORAGE MANAGEMENT',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          MeloGlass(
            borderRadius: MeloRadii.lg,
            shadow: false,
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.image_outlined,
                      color: MeloColors.cherry,
                    ),
                    title: const Text(
                      'Clear artwork & stream cache',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Free in-memory cover thumbnails, waveforms & stream tags',
                    ),
                    trailing: TextButton(
                      onPressed: _isClearing
                          ? null
                          : _clearArtworkAndStreamCache,
                      child: const Text('Clear'),
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: colors.outlineVariant.withValues(alpha: 0.3),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.lyrics_outlined,
                      color: MeloColors.cherry,
                    ),
                    title: const Text(
                      'Clear cached lyrics',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Local .lrc sidecar files stay untouched on storage',
                    ),
                    trailing: TextButton(
                      onPressed: _isClearing ? null : _clearLyricsCache,
                      child: const Text('Clear'),
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: colors.outlineVariant.withValues(alpha: 0.3),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.cleaning_services_outlined,
                      color: MeloColors.cherry,
                    ),
                    title: const Text(
                      'Clear downloaded update APKs',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Remove temporary GitHub installer packages from cache',
                    ),
                    trailing: TextButton(
                      onPressed: _isClearing ? null : _clearUpdateApks,
                      child: const Text('Clear'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'PLAYLISTS & LIBRARY BACKUP (SURVIVES UNINSTALL)',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          MeloGlass(
            borderRadius: MeloRadii.lg,
            shadow: false,
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.backup_rounded,
                      color: MeloColors.cherry,
                    ),
                    title: const Text(
                      'Export Library Backup',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Saves all playlists, songs, and favorites to Music/Tone/Backups (persists across uninstalls)',
                    ),
                    trailing: FilledButton.tonal(
                      onPressed: _isClearing ? null : _exportBackup,
                      child: const Text('Export'),
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: colors.outlineVariant.withValues(alpha: 0.3),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.settings_backup_restore_rounded,
                      color: MeloColors.cherry,
                    ),
                    title: const Text(
                      'Restore from Backup',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Auto-scans external storage or lets you pick a melo_library_backup.json file',
                    ),
                    trailing: OutlinedButton(
                      onPressed: _isClearing ? null : _restoreBackup,
                      child: const Text('Restore'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'STREAMING & DOWNLOAD QUALITY',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          _QualityAndStreamingSection(
            library: widget.library,
            audioHandler: widget.audioHandler,
          ),
          const SizedBox(height: 24),
          Text(
            'CONNECTED STREAMING SOURCES',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          _ConnectedSourcesSection(
            library: widget.library,
            audioHandler: widget.audioHandler,
            onOpenLibrary: widget.onOpenLibrary,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onOpenLibrary();
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

  static void showCustomColorPicker(BuildContext context, Color initialColor) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CustomColorPickerDialog(initialColor: initialColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ValueListenableBuilder<MeloThemeSettings>(
      valueListenable: MeloThemeService.instance,
      builder: (context, themeSettings, _) {
        final activePalette = themeSettings.palette;
        return Scaffold(
          appBar: AppBar(title: const Text('Theme & Appearance')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            children: [
              // Dynamic Theme Preview Banner
              AnimatedContainer(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeInOut,
                height: 164,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(MeloRadii.xl),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: themeSettings.gradient,
                  ),
                  boxShadow: MeloShadows.glow(themeSettings.primaryColor, opacity: 0.32),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(MeloRadii.xl),
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
                      const Positioned.fill(child: MeloGrain(opacity: 0.07)),
                      Positioned(
                        left: 24,
                        bottom: 20,
                        right: 24,
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withValues(alpha: 0.28),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                              ),
                              child: const Icon(
                                Icons.palette_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    activePalette == MeloThemePalette.custom
                                        ? 'Custom Bespoke (${themeSettings.customColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()})'
                                        : activePalette.displayName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                    ),
                                  ),
                                  Text(
                                    activePalette == MeloThemePalette.custom
                                        ? 'RGB personalized spectrum · App-wide live dynamic accent'
                                        : activePalette.subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.8),
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'AUDIOPHILE THEME PALETTES',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 12),
              MeloGlass(
                borderRadius: MeloRadii.lg,
                shadow: false,
                child: Column(
                  children: [
                    for (var i = 0; i < MeloThemePalette.values.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          color: colors.outlineVariant.withValues(alpha: 0.3),
                        ),
                      _ThemePaletteTile(
                        palette: MeloThemePalette.values[i],
                        themeSettings: themeSettings,
                        isSelected: activePalette == MeloThemePalette.values[i],
                        onTap: () {
                          if (MeloThemePalette.values[i] == MeloThemePalette.custom) {
                            showCustomColorPicker(context, themeSettings.customColor);
                          } else {
                            MeloThemeService.instance
                                .setPalette(MeloThemePalette.values[i]);
                          }
                        },
                        onConfigureCustom: () =>
                            showCustomColorPicker(context, themeSettings.customColor),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'BESPOKE SPECTRUM & RGB PICKER',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => showCustomColorPicker(context, themeSettings.customColor),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.tune_rounded, size: 14, color: themeSettings.primaryColor),
                        const SizedBox(width: 4),
                        Text(
                          'Sliders & Hex',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: themeSettings.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              MeloGlass(
                borderRadius: MeloRadii.lg,
                shadow: false,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quick Spectrum Swatches',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Choose any signature tone or dial exact RGB / Hex values below.',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final color in const [
                          Color(0xFFFA243C), // Signature Obsidian Cherry
                          Color(0xFF06B6D4), // Electric Cyan
                          Color(0xFFA855F7), // Neon Violet
                          Color(0xFFE11D48), // Crimson Rose
                          Color(0xFF10B981), // Tokyo Emerald
                          Color(0xFFF59E0B), // Sunset Amber
                          Color(0xFFFF6B6B), // Coral Flame
                          Color(0xFF3B82F6), // Royal Cobalt
                          Color(0xFF84CC16), // Acid Lime
                          Color(0xFFEAB308), // Solar Gold
                          Color(0xFF7C3AED), // Deep Violet
                          Color(0xFF94A3B8), // Ice Titanium
                        ]) ...[
                          GestureDetector(
                            onTap: () => MeloThemeService.instance.setCustomColor(color),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: activePalette == MeloThemePalette.custom &&
                                          themeSettings.customColor.toARGB32() == color.toARGB32()
                                      ? Colors.white
                                      : Colors.transparent,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: activePalette == MeloThemePalette.custom &&
                                      themeSettings.customColor.toARGB32() == color.toARGB32()
                                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                                  : null,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: themeSettings.primaryColor.withValues(alpha: 0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => showCustomColorPicker(context, themeSettings.customColor),
                        icon: Icon(Icons.colorize_rounded, size: 18, color: themeSettings.primaryColor),
                        label: Text(
                          'Open RGB Sliders & Hex Code Picker',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: themeSettings.primaryColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              Text(
                'SURFACE & OLED DISPLAY',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 12),
              MeloGlass(
                borderRadius: MeloRadii.lg,
                shadow: false,
                child: Column(
                  children: [
                    SwitchListTile.adaptive(
                      title: const Text(
                        'True AMOLED Pitch Black (#000000)',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text(
                        'Zero battery consumption on OLED displays with true pure black canvases.',
                      ),
                      value: themeSettings.amoledPitchBlack,
                      onChanged: (v) =>
                          MeloThemeService.instance.setAmoledPitchBlack(v),
                    ),
                    Divider(
                      height: 1,
                      color: colors.outlineVariant.withValues(alpha: 0.3),
                    ),
                    SwitchListTile.adaptive(
                      title: const Text(
                        'Album Reactive Accents',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text(
                        'Extracts vibrant tones from playing track artwork to adapt seekbars and glows.',
                      ),
                      value: themeSettings.dynamicAlbumReactive,
                      onChanged: (v) =>
                          MeloThemeService.instance.setDynamicAlbumReactive(v),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              Text(
                'THEME MODE',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: MeloAppearanceController.instance,
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
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Light'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('Dark'),
                        ),
                      ],
                      selected: {mode},
                      onSelectionChanged: (selection) =>
                          MeloAppearanceController.instance
                              .setMode(selection.first),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ThemePaletteTile extends StatelessWidget {
  const _ThemePaletteTile({
    required this.palette,
    required this.themeSettings,
    required this.isSelected,
    required this.onTap,
    this.onConfigureCustom,
  });

  final MeloThemePalette palette;
  final MeloThemeSettings themeSettings;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onConfigureCustom;

  @override
  Widget build(BuildContext context) {
    final isCustom = palette == MeloThemePalette.custom;
    final primary = isCustom ? themeSettings.customColor : palette.primaryColor;
    final secondary = isCustom ? themeSettings.secondaryColor : palette.secondaryColor;

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [primary, secondary],
          ),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 2.2,
          ),
          boxShadow: isSelected
              ? MeloShadows.soft(primary, opacity: 0.4)
              : null,
        ),
      ),
      title: Row(
        children: [
          Text(
            palette.displayName,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? primary : null,
            ),
          ),
          if (isCustom) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: primary.withValues(alpha: 0.4), width: 0.8),
              ),
              child: Text(
                '#${primary.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: primary,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        palette.subtitle,
        style: const TextStyle(fontSize: 12.5),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCustom && onConfigureCustom != null) ...[
            IconButton(
              icon: const Icon(Icons.colorize_rounded, size: 20),
              tooltip: 'Configure custom RGB color',
              onPressed: onConfigureCustom,
              color: primary,
            ),
          ],
          if (isSelected)
            Icon(Icons.check_circle_rounded, color: primary),
        ],
      ),
    );
  }
}

class _CustomColorPickerDialog extends StatefulWidget {
  const _CustomColorPickerDialog({required this.initialColor});
  final Color initialColor;

  @override
  State<_CustomColorPickerDialog> createState() => _CustomColorPickerDialogState();
}

class _CustomColorPickerDialogState extends State<_CustomColorPickerDialog> {
  late int _r;
  late int _g;
  late int _b;
  late TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    _r = (widget.initialColor.r * 255).round().clamp(0, 255);
    _g = (widget.initialColor.g * 255).round().clamp(0, 255);
    _b = (widget.initialColor.b * 255).round().clamp(0, 255);
    _hexController = TextEditingController(text: _toHex(_r, _g, _b));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  static String _toHex(int r, int g, int b) =>
      '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}'
          .toUpperCase();

  void _onHexChanged(String val) {
    var clean = val.replaceAll('#', '').trim();
    if (clean.length == 6) {
      final intVal = int.tryParse(clean, radix: 16);
      if (intVal != null) {
        setState(() {
          _r = (intVal >> 16) & 0xFF;
          _g = (intVal >> 8) & 0xFF;
          _b = intVal & 0xFF;
        });
      }
    }
  }

  void _updateFromRgb(int r, int g, int b) {
    setState(() {
      _r = r;
      _g = g;
      _b = b;
      _hexController.text = _toHex(r, g, b);
    });
  }

  Color get _currentColor => Color.fromARGB(255, _r, _g, _b);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.3),
            width: 1.0,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: colors.outlineVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Custom RGB & Hex Accent',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Live Color Preview Card
              Container(
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: _currentColor,
                  boxShadow: [
                    BoxShadow(
                      color: _currentColor.withValues(alpha: 0.45),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _toHex(_r, _g, _b),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                            letterSpacing: 1.1,
                          ),
                        ),
                        Text(
                          'RGB($_r, $_g, $_b)',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.palette_rounded, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'LIVE PREVIEW',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Hex Input Field
              TextField(
                controller: _hexController,
                onChanged: _onHexChanged,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'HEX CODE (#RRGGBB)',
                  prefixIcon: const Icon(Icons.tag_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  filled: true,
                  fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.3),
                ),
              ),
              const SizedBox(height: 20),

              // Red Slider
              _RgbSliderRow(
                label: 'Red',
                value: _r,
                accentColor: const Color(0xFFEF4444),
                onChanged: (v) => _updateFromRgb(v, _g, _b),
              ),
              const SizedBox(height: 10),

              // Green Slider
              _RgbSliderRow(
                label: 'Green',
                value: _g,
                accentColor: const Color(0xFF10B981),
                onChanged: (v) => _updateFromRgb(_r, v, _b),
              ),
              const SizedBox(height: 10),

              // Blue Slider
              _RgbSliderRow(
                label: 'Blue',
                value: _b,
                accentColor: const Color(0xFF3B82F6),
                onChanged: (v) => _updateFromRgb(_r, _g, v),
              ),
              const SizedBox(height: 22),

              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _currentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  MeloThemeService.instance.setCustomColor(_currentColor);
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.check_rounded),
                label: const Text(
                  'Apply Color Accent App-Wide',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RgbSliderRow extends StatelessWidget {
  const _RgbSliderRow({
    required this.label,
    required this.value,
    required this.accentColor,
    required this.onChanged,
  });

  final String label;
  final int value;
  final Color accentColor;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: accentColor,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: accentColor,
              thumbColor: accentColor,
              inactiveTrackColor: accentColor.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: value.toDouble(),
              min: 0,
              max: 255,
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            '$value',
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}

class AboutToneScreen extends StatefulWidget {
  const AboutToneScreen({super.key});

  @override
  State<AboutToneScreen> createState() => _AboutToneScreenState();
}

class _AboutToneScreenState extends State<AboutToneScreen> with WidgetsBindingObserver {
  final AppUpdateService _updater = AppUpdateService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updater.addListener(_onUpdaterChanged);
    unawaited(_updater.initialize(runStartupCheck: false));
    if (_updater.lastResult == null) {
      unawaited(_updater.checkForUpdates(silent: true));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
          ? 'Allow "Install unknown apps" for Melo, then tap Install APK again.'
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
    final saved = await showDialog<String>(
      context: context,
      builder: (_) => _RepositoryEditDialog(initialValue: _updater.repository),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('About Melo'),
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
                  boxShadow: MeloShadows.glow(MeloColors.cherry, opacity: 0.25),
                ),
                child: Icon(
                  Icons.graphic_eq_rounded,
                  size: 32,
                  color: MeloColors.cherry,
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
                        color: MeloColors.cherry,
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
            'Melo is a local-first music player. It works without an account, '
            'keeps recommendations on-device, and gives you control over how '
            'your music flows.',
            style: textTheme.bodyLarge,
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  MeloColors.cherry.withValues(alpha: 0.15),
                  colors.surfaceContainerLow,
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: MeloColors.cherry.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.favorite_rounded, color: MeloColors.cherry, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      '100% Free & Community-Driven',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'No paywalls, ads, or locked codecs. Share your ideas or suggest features you want to see next in Melo!',
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SupportFeedbackScreen(initialTab: 1),
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: MeloColors.cherry,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.lightbulb_outline_rounded, size: 16),
                      label: const Text(
                        'Suggest a Feature',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SupportFeedbackScreen(initialTab: 0),
                        ),
                      ),
                      icon: const Icon(Icons.favorite_outline_rounded, size: 16),
                      label: const Text('Community'),
                    ),
                  ],
                ),
              ],
            ),
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
          MeloGlass(
            borderRadius: MeloRadii.lg,
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
                            ? MeloColors.cherry
                            : MeloColors.cherry,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isUpdateAvailable
                                  ? 'Update Available · ${latest?.tagName}'
                                  : 'Melo v${_updater.currentVersion} (Latest Installed)',
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
                              ? MeloColors.cherry.withValues(alpha: 0.5)
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
                                  isUpdateAvailable
                                      ? '${latest.title} (${latest.tagName})'
                                      : 'Melo v${_updater.currentVersion} (v${_updater.currentVersion})',
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
                          if (!isUpdateAvailable && latest.preferredApkAsset == null) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: MeloColors.cherry.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: MeloColors.cherry.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.verified_rounded,
                                    color: MeloColors.cherry,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'You are on the latest version (Melo v${_updater.currentVersion})',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (latest.preferredApkAsset != null) ...[
                            const SizedBox(height: 10),
                            FutureBuilder<File?>(
                              future: _updater.getDownloadedApkFile(latest),
                              builder: (context, snapshot) {
                                final isAlreadyDownloaded = snapshot.data != null;
                                if (!isUpdateAvailable) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: MeloColors.cherry.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: MeloColors.cherry.withValues(alpha: 0.35),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.verified_rounded,
                                              color: MeloColors.cherry,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                'You are on the latest version (Melo v${_updater.currentVersion})',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isAlreadyDownloaded) ...[
                                        const SizedBox(height: 8),
                                        OutlinedButton.icon(
                                          onPressed: _updater.isDownloading
                                              ? null
                                              : () => _downloadAndInstall(latest),
                                          icon: const Icon(
                                            Icons.install_mobile_rounded,
                                            size: 16,
                                          ),
                                          label: Text(
                                            'Install cached APK (${latest.preferredApkAsset!.formattedSize})',
                                          ),
                                        ),
                                      ],
                                    ],
                                  );
                                }
                                return SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: _updater.isDownloading
                                        ? null
                                        : () => _downloadAndInstall(latest),
                                    style: isAlreadyDownloaded
                                        ? FilledButton.styleFrom(
                                            backgroundColor: MeloColors.cherry,
                                            foregroundColor: Colors.white,
                                          )
                                        : null,
                                    icon: Icon(
                                      isAlreadyDownloaded
                                          ? Icons.system_update_rounded
                                          : Icons.system_update_alt_rounded,
                                      size: 18,
                                    ),
                                    label: Text(
                                      isAlreadyDownloaded
                                          ? 'Install ${latest.tagName} (Already downloaded)'
                                          : 'Download & Install ${latest.tagName} (${latest.preferredApkAsset!.formattedSize})',
                                    ),
                                  ),
                                );
                              },
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
                        color: MeloColors.cherry,
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
                    subtitle: Text(
                      'Check github.com/${_updater.repository} when Melo starts',
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
          'Your music files, playlists, queue, and cached lyrics stay in Melo.',
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
            'Melo stores your library references, favorites, playlists, '
            'playback queue and position, mix exclusions, and cached local '
            'lyrics on this device. Melo does not record listening history. '
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
              'Remove lyrics copied into Melo’s local cache. Sidecar files '
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
        borderRadius: BorderRadius.circular(MeloRadii.xl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MeloColors.qledCard,
            Color(0xFF280B16),
            MeloColors.cherryDeep,
          ],
          stops: [0, 0.55, 1],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
          width: 1.0,
        ),
        boxShadow: MeloShadows.hdrBloom(MeloColors.cherry, opacity: 0.28),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MeloRadii.xl),
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
                      MeloColors.cherryGlow.withValues(alpha: 0.45),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            const Positioned.fill(child: MeloGrain(opacity: 0.06)),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [MeloColors.cherryGlow, MeloColors.cherry],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: MeloColors.cherry.withValues(alpha: 0.5),
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
    this.accentColor,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color? accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tint = accentColor ?? colors.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(MeloRadii.md),
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
                    borderRadius: BorderRadius.circular(MeloRadii.sm),
                    color: tint.withValues(alpha: dark ? 0.16 : 0.1),
                    border: Border.all(
                      color: tint.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Icon(icon, color: tint, size: 20),
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
                              ? MeloColors.cherry
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
    return MeloGlass(
      borderRadius: MeloRadii.lg,
      shadow: false,
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            ListTile(
              leading: Icon(
                Icons.high_quality_rounded,
                color: MeloColors.cherry,
              ),
              title: const Text(
                'Download Audio Quality',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(_downloadQuality.shortLabel),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: MeloColors.cherry.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _downloadQuality.badge,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: MeloColors.cherry,
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
              leading: Icon(
                Icons.graphic_eq_rounded,
                color: MeloColors.cherry,
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
    return MeloGlass(
      borderRadius: MeloRadii.lg,
      shadow: false,
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            ListTile(
              leading: Icon(
                Icons.play_circle_fill_rounded,
                color: MeloColors.cherry,
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
            ValueListenableBuilder<bool>(
              valueListenable: SpotifyService.instance.authState,
              builder: (context, isSpotifyLoggedIn, _) {
                final spotify = SpotifyService.instance;
                return ListTile(
                  leading: Icon(
                    Icons.radar_rounded,
                    color: MeloColors.cherry,
                  ),
                  title: const Text(
                    'Spotify Account',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    isSpotifyLoggedIn
                        ? 'Connected as ${spotify.displayName ?? "Spotify User"} · Personal feed active'
                        : 'Sign in to sync your Spotify feed, playlists & liked songs',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context)
                      .push(
                        MaterialPageRoute<void>(
                          builder: (_) => SpotifySettingsScreen(
                            library: widget.library,
                            audioHandler: widget.audioHandler,
                          ),
                        ),
                      )
                      .then((_) {
                        if (mounted) setState(() {});
                      }),
                );
              },
            ),
            Divider(
              height: 1,
              color: colors.outlineVariant.withValues(alpha: 0.3),
            ),
            ListTile(
              leading: Icon(
                Icons.playlist_add_check_circle_rounded,
                color: MeloColors.cherry,
              ),
              title: const Text(
                'Import Music or Playlist Link',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Paste any shared music or playlist link',
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

/// Stateful dialog so [_controller] outlives the route pop and IME animations.
class _RepositoryEditDialog extends StatefulWidget {
  const _RepositoryEditDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_RepositoryEditDialog> createState() => _RepositoryEditDialogState();
}

class _RepositoryEditDialogState extends State<_RepositoryEditDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('GitHub Repository'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter your GitHub repository (owner/repo) where Melo releases and APKs are published:',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              labelText: 'owner/repo',
              hintText: 'ossy-harz/Melo',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            FocusScope.of(context).unfocus();
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

void _showProviderSelectionSheet(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final colors = Theme.of(context).colorScheme;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161618) : colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : colors.outlineVariant.withValues(alpha: 0.3),
            width: 0.8,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: MeloColors.cherry.withValues(alpha: 0.15),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.hub_rounded,
                        color: MeloColors.cherry,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Home Feed & Discovery Provider',
                          style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Select which music ecosystem shapes your Home shelves',
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    for (final p in const [
                      MusicProviderType.all,
                      MusicProviderType.appleMusic,
                      MusicProviderType.spotify,
                      MusicProviderType.youtubeMusic,
                      MusicProviderType.deezer,
                      MusicProviderType.soundcloud,
                    ])
                      ValueListenableBuilder<MusicProviderType>(
                        valueListenable: HomeFeedProviderSettings.instance.activeProvider,
                        builder: (c, current, _) {
                          final isSelected = current == p;
                          final subtitle = switch (p) {
                            MusicProviderType.all =>
                              'Balanced curation from Apple Music, Spotify & YouTube',
                            MusicProviderType.appleMusic =>
                              'Apple Music 1 Live, Spatial Audio & Global Top 100',
                            MusicProviderType.spotify =>
                              'Spotify Top 50, Today\'s Top Hits & RapCaviar',
                            MusicProviderType.youtubeMusic =>
                              'YouTube Music Trending, viral videos & charts',
                            MusicProviderType.deezer =>
                              'Deezer Flow, Hi-Fi editorial & worldwide charts',
                            MusicProviderType.soundcloud =>
                              'SoundCloud Next Wave, underground gems & VIP flips',
                            _ => p.displayName,
                          };

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: isSelected
                                  ? (isDark
                                      ? MeloColors.qledElevated
                                      : colors.surfaceContainerHighest)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () async {
                                  await HomeFeedProviderSettings.instance.setProvider(p);
                                  if (ctx.mounted) Navigator.of(ctx).pop();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context)
                                      ..hideCurrentSnackBar()
                                      ..showSnackBar(
                                        SnackBar(
                                          content: Text('Switched Home feed to ${p.displayName}'),
                                          behavior: SnackBarBehavior.floating,
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected
                                          ? p.brandColor.withValues(alpha: 0.6)
                                          : Colors.white.withValues(alpha: 0.06),
                                      width: isSelected ? 1.2 : 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: p.brandColor.withValues(alpha: 0.16),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Center(
                                          child: Icon(
                                            p.icon,
                                            color: p.brandColor,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              p.displayName,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: isSelected
                                                    ? FontWeight.w800
                                                    : FontWeight.w600,
                                                color: colors.onSurface,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              subtitle,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: colors.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(
                                          Icons.check_circle_rounded,
                                          color: p.brandColor,
                                          size: 22,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
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
    },
  );
}

