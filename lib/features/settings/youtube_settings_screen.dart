import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:tone_player/app/tone_glass.dart';
import 'package:tone_player/app/tone_theme.dart';
import 'package:tone_player/features/library/music_library.dart';
import 'package:tone_player/features/youtube/youtube_audio_service.dart';
import 'package:tone_player/features/youtube/youtube_auth_service.dart';
import 'package:tone_player/features/youtube/youtube_search_screen.dart';

class YoutubeSettingsScreen extends StatefulWidget {
  const YoutubeSettingsScreen({
    this.library,
    this.audioHandler,
    super.key,
  });

  final MusicLibrary? library;
  final AudioHandler? audioHandler;

  @override
  State<YoutubeSettingsScreen> createState() => _YoutubeSettingsScreenState();
}

class _YoutubeSettingsScreenState extends State<YoutubeSettingsScreen> {
  YoutubeAudioQuality _quality = YoutubeAudioQuality.highest;
  bool _isSyncingLikes = false;
  int _syncedCount = 0;

  static const List<String> _availableGenres = [
    'Hip-Hop',
    'Electronic',
    'R&B',
    'Rock',
    'Pop',
    'Indie',
    'Jazz',
    'Lo-Fi',
    'Metal',
    'Classical',
    'Ambient',
    'Afrobeat',
    'Soul',
    'Synthwave',
  ];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final quality = await YoutubeAudioService.instance.getPreferredQuality();
    if (mounted) {
      setState(() => _quality = quality);
    }
  }

  Future<void> _updateQuality(YoutubeAudioQuality quality) async {
    await YoutubeAudioService.instance.setPreferredQuality(quality);
    if (mounted) {
      setState(() => _quality = quality);
    }
  }

  void _showConnectDialog() {
    final messenger = ScaffoldMessenger.of(context);
    final textController = TextEditingController();
    bool isSubmitting = false;
    String? errorText;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogInnerContext, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.account_circle_rounded, color: Colors.red),
                  SizedBox(width: 10),
                  Text('Connect YouTube'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sign in directly with your Google account to access your personalized taste, algorithmic mixes, liked music, and bypass streaming restrictions.',
                      style: TextStyle(fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.of(dialogContext).pop();
                          final success =
                              await YoutubeAuthService.instance.launchInAppLogin();
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  success
                                      ? 'Connected to YouTube Music successfully!'
                                      : 'Login cancelled or incomplete.',
                                ),
                              ),
                            );
                            setState(() {});
                          }
                        },
                        icon: const Icon(Icons.login_rounded),
                        label: const Text(
                          'Sign in with Google (1-Tap)',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            'OR SYNC CHANNEL HANDLE',
                            style: TextStyle(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: textController,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Enter YouTube Handle (e.g. @MyChannel)',
                        prefixIcon: const Icon(Icons.alternate_email_rounded, size: 18),
                        border: const OutlineInputBorder(),
                        errorText: errorText,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final handle = textController.text.trim();
                          if (handle.isEmpty) {
                            setDialogState(() => errorText = 'Please enter a valid channel handle');
                            return;
                          }
                          setDialogState(() {
                            isSubmitting = true;
                            errorText = null;
                          });
                          final ok = await YoutubeAuthService.instance.loginWithChannelHandle(handle);
                          if (!dialogContext.mounted) return;
                          if (ok) {
                            Navigator.of(dialogContext).pop();
                            if (mounted) {
                              setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Connected YouTube channel $handle successfully!'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } else {
                            setDialogState(() {
                              isSubmitting = false;
                              errorText = 'Could not find YouTube channel $handle.';
                            });
                          }
                        },
                    child: isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Sync Channel'),
                  ),
                ],
              );
          },
        );
      },
    );
  }

  Future<void> _syncLikedSongs() async {
    final library = widget.library;
    if (library == null) return;

    setState(() {
      _isSyncingLikes = true;
      _syncedCount = 0;
    });

    try {
      final likedTracks = await YoutubeAuthService.instance.getLikedMusic();
      if (likedTracks.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No liked songs found or account session expired.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final imported = likedTracks.map((t) => t.toImportedTrack()).toList();
      await library.importExternalTracks(imported);

      // Create or update "YouTube Liked Songs" playlist
      const playlistName = 'YouTube Liked Songs';
      final existing = library.playlists.where((p) => p.name == playlistName).firstOrNull;
      if (existing != null) {
        await library.addTracksToPlaylist(existing.id, imported.map((t) => t.id).toList());
      } else {
        final playlist = await library.createPlaylist(playlistName);
        await library.addTracksToPlaylist(playlist.id, imported.map((t) => t.id).toList());
      }

      if (!mounted) return;
      setState(() => _syncedCount = imported.length);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Synced ${imported.length} liked songs into "$playlistName"!'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync failed: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSyncingLikes = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final auth = YoutubeAuthService.instance;
    final isLoggedIn = auth.isLoggedIn;

    return Scaffold(
      appBar: AppBar(
        title: const Text('YouTube Audio Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_circle_fill_rounded,
                  color: Colors.red,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YouTube Audio Source',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'High fidelity audio streaming & offline caching.',
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
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => YoutubeSearchScreen(
                  audioHandler: widget.audioHandler,
                  library: widget.library,
                ),
              ),
            ),
            icon: const Icon(Icons.search_rounded),
            label: const Text('Search & Stream YouTube Music'),
          ),
          const SizedBox(height: 28),

          // ACCOUNT & PERSONAL TASTE SECTION
          Text(
            'ACCOUNT & PERSONAL TASTE',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
          ),
          const SizedBox(height: 12),
          ToneGlass(
            borderRadius: ToneRadii.lg,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.red.withValues(alpha: 0.2),
                        backgroundImage: auth.avatarUrl != null
                            ? NetworkImage(auth.avatarUrl!)
                            : null,
                        child: auth.avatarUrl == null
                            ? const Icon(Icons.person_rounded, color: Colors.white70)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isLoggedIn
                                  ? (auth.accountName ?? 'Connected Account')
                                  : 'Not Connected',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              isLoggedIn
                                  ? 'Personalized mixes & taste active'
                                  : 'Connect for algorithmic mixes & liked music',
                              style: TextStyle(
                                fontSize: 12,
                                color: isLoggedIn ? Colors.greenAccent : colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isLoggedIn)
                        TextButton(
                          onPressed: () async {
                            await auth.logout();
                            if (mounted) setState(() {});
                          },
                          child: const Text('Sign Out', style: TextStyle(color: Colors.redAccent)),
                        )
                      else
                        OutlinedButton(
                          onPressed: _showConnectDialog,
                          child: const Text('Connect'),
                        ),
                    ],
                  ),
                  if (isLoggedIn) ...[
                    const Divider(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: _isSyncingLikes ? null : _syncLikedSongs,
                        icon: _isSyncingLikes
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 18),
                        label: Text(
                          _isSyncingLikes
                              ? 'Syncing Liked Songs...'
                              : _syncedCount > 0
                                  ? 'Re-sync Liked Songs ($_syncedCount synced)'
                                  : 'Sync Liked Songs to Tone',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // TASTE SHAPING GENRES
          Text(
            'TASTE SHAPING VIBES',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select your favorite genres to influence personalized mix discovery:',
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableGenres.map((genre) {
              final isSelected = auth.favoriteGenres.contains(genre);
              return FilterChip(
                label: Text(genre),
                selected: isSelected,
                selectedColor: ToneColors.cherry.withValues(alpha: 0.25),
                checkmarkColor: ToneColors.cherry,
                onSelected: (selected) async {
                  final current = List<String>.from(auth.favoriteGenres);
                  if (selected) {
                    current.add(genre);
                  } else {
                    current.remove(genre);
                  }
                  await auth.setFavoriteGenres(current);
                  if (mounted) setState(() {});
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 28),

          // STREAMING QUALITY
          Text(
            'STREAMING QUALITY',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
          ),
          const SizedBox(height: 12),
          ToneGlass(
            borderRadius: ToneRadii.lg,
            child: Column(
              children: [
                RadioListTile<YoutubeAudioQuality>(
                  title: const Text('Highest Quality'),
                  subtitle: const Text('Highest bitrate stream (~160kbps Opus / AAC)'),
                  value: YoutubeAudioQuality.highest,
                  // ignore: deprecated_member_use
                  groupValue: _quality,
                  activeColor: colors.primary,
                  // ignore: deprecated_member_use
                  onChanged: (val) {
                    if (val != null) _updateQuality(val);
                  },
                ),
                RadioListTile<YoutubeAudioQuality>(
                  title: const Text('Standard Quality'),
                  subtitle: const Text('Balanced audio fidelity and bandwidth (~128kbps)'),
                  value: YoutubeAudioQuality.standard,
                  // ignore: deprecated_member_use
                  groupValue: _quality,
                  activeColor: colors.primary,
                  // ignore: deprecated_member_use
                  onChanged: (val) {
                    if (val != null) _updateQuality(val);
                  },
                ),
                RadioListTile<YoutubeAudioQuality>(
                  title: const Text('Data Saver'),
                  subtitle: const Text('Lower bitrate to minimize mobile data (~64kbps)'),
                  value: YoutubeAudioQuality.dataSaver,
                  // ignore: deprecated_member_use
                  groupValue: _quality,
                  activeColor: colors.primary,
                  // ignore: deprecated_member_use
                  onChanged: (val) {
                    if (val != null) _updateQuality(val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'OFFLINE SAVING & SYNCED LYRICS',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'When you download a YouTube track in Tone, the raw audio stream is tagged and cached locally alongside its synced .lrc lyrics file, allowing seamless word-by-word karaoke playback offline.',
            style: TextStyle(
              fontSize: 13,
              color: colors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
