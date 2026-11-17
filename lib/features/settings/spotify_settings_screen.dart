import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:melo_player/app/melo_glass.dart';
import 'package:melo_player/app/melo_theme.dart';
import 'package:melo_player/features/library/music_library.dart';
import 'package:melo_player/features/spotify/spotify_import_sheet.dart';
import 'package:melo_player/features/spotify/spotify_service.dart';

class SpotifySettingsScreen extends StatefulWidget {
  const SpotifySettingsScreen({
    this.library,
    this.audioHandler,
    super.key,
  });

  final MusicLibrary? library;
  final AudioHandler? audioHandler;

  @override
  State<SpotifySettingsScreen> createState() => _SpotifySettingsScreenState();
}

class _SpotifySettingsScreenState extends State<SpotifySettingsScreen> {
  final TextEditingController _clientIdController = TextEditingController();
  final TextEditingController _clientSecretController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSigningIn = false;
  bool _isSyncing = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    SpotifyService.instance.authState.addListener(_onSpotifyChanged);
    SpotifyService.instance.feedRevision.addListener(_onSpotifyChanged);
    _loadSaved();
  }

  @override
  void dispose() {
    SpotifyService.instance.authState.removeListener(_onSpotifyChanged);
    SpotifyService.instance.feedRevision.removeListener(_onSpotifyChanged);
    _clientIdController.dispose();
    _clientSecretController.dispose();
    super.dispose();
  }

  void _onSpotifyChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _signInInApp() async {
    setState(() => _isSigningIn = true);
    try {
      final success = await SpotifyService.instance.launchInAppLogin();
      if (!mounted) return;
      if (success) {
        await SpotifyService.instance.refreshPersonalFeed(
          library: widget.library,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Connected Spotify account! Your personal feed is live.'
                  : 'Spotify sign-in was cancelled or incomplete.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  Future<void> _showTokenOrProfileDialog() async {
    final submitted = await showDialog<String>(
      context: context,
      builder: (_) => const _SpotifyTokenDialog(),
    );
    if (submitted == null || submitted.isEmpty || !mounted) return;

    setState(() => _isSigningIn = true);
    try {
      final ok = await SpotifyService.instance.connectWithTokenOrCookie(
        submitted,
      );
      if (ok && widget.library != null) {
        await SpotifyService.instance.refreshPersonalFeed(
          library: widget.library,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? 'Spotify account connected (${SpotifyService.instance.displayName ?? "Synced"})!'
                  : 'Could not verify Spotify token, cookie, or public profile.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  Future<void> _syncLibrary() async {
    final library = widget.library;
    if (library == null || _isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      final count = await SpotifyService.instance.syncAccountToLibrary(library);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              count > 0
                  ? 'Synced $count Spotify tracks & playlists into your Library!'
                  : 'Refreshed Spotify feed (no public or liked tracks returned).',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _loadSaved() async {
    final id = await SpotifyService.instance.getSavedClientId();
    final secret = await SpotifyService.instance.getSavedClientSecret();
    if (mounted) {
      setState(() {
        if (id != null) _clientIdController.text = id;
        if (secret != null) _clientSecretController.text = secret;
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    await SpotifyService.instance.saveCredentials(
      clientId: _clientIdController.text,
      clientSecret: _clientSecretController.text,
    );
    if (mounted) {
      setState(() {
        _isSaving = false;
        _statusMessage = 'Credentials saved securely on your device.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Spotify credentials saved!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _clear() async {
    _clientIdController.clear();
    _clientSecretController.clear();
    await SpotifyService.instance.saveCredentials();
    if (mounted) {
      setState(() {
        _statusMessage = 'Credentials cleared. Using public embed mode.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final spotify = SpotifyService.instance;
    final isLoggedIn = spotify.isLoggedIn;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spotify Integration'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: MeloColors.cherry.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.playlist_play_rounded,
                        color: MeloColors.cherry,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Spotify in Melo',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'Sync your personal Spotify feed, liked songs & playlists directly.',
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
                const SizedBox(height: 22),
                Text(
                  'ACCOUNT & PERSONAL FEED SYNC',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                ),
                const SizedBox(height: 12),
                MeloGlass(
                  borderRadius: MeloRadii.lg,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: MeloColors.cherry.withValues(
                                alpha: 0.2,
                              ),
                              backgroundImage: spotify.avatarUrl != null
                                  ? NetworkImage(spotify.avatarUrl!)
                                  : null,
                              child: spotify.avatarUrl == null
                                  ? const Icon(
                                      Icons.person_rounded,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isLoggedIn
                                        ? (spotify.displayName ??
                                            'Connected Account')
                                        : 'Not Connected',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    isLoggedIn
                                        ? '${spotify.userPlaylists.length} playlists · ${spotify.personalFeedTracks.length} feed tracks'
                                        : 'Sign in to load your real Spotify feed on Home',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isLoggedIn
                                          ? MeloColors.cherry
                                          : colors.onSurfaceVariant,
                                      fontWeight: isLoggedIn
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isLoggedIn)
                              TextButton(
                                onPressed: () => spotify.logout(),
                                child: const Text('Sign Out'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: _isSigningIn ? null : _signInInApp,
                          icon: _isSigningIn
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.login_rounded),
                          label: Text(
                            _isSigningIn
                                ? 'Connecting…'
                                : isLoggedIn
                                ? 'Reconnect Spotify Account'
                                : 'Sign in with Spotify (1-Tap In-App)',
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _isSigningIn
                              ? null
                              : _showTokenOrProfileDialog,
                          icon: const Icon(Icons.key_rounded, size: 18),
                          label: const Text(
                            'Connect via Token, Cookie or Profile Link',
                          ),
                        ),
                        if (isLoggedIn) ...[
                          const SizedBox(height: 10),
                          if (widget.library != null)
                            FilledButton.tonalIcon(
                              onPressed: _isSyncing ? null : _syncLibrary,
                              icon: _isSyncing
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.sync_rounded),
                              label: Text(
                                _isSyncing
                                    ? 'Syncing to Library…'
                                    : 'Sync Spotify Feed & Playlists to Library',
                              ),
                            ),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: _isSyncing
                                  ? null
                                  : () async {
                                      await spotify.refreshPersonalFeed(
                                        library: widget.library,
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                          ..hideCurrentSnackBar()
                                          ..showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Spotify personal feed refreshed!',
                                              ),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                            ),
                                          );
                                      }
                                    },
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Refresh Feed'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.tonalIcon(
                  onPressed: () => SpotifyImportSheet.show(
                    context,
                    library: widget.library,
                    audioHandler: widget.audioHandler,
                  ),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Open Playlist Importer'),
                ),
                const SizedBox(height: 28),
                Text(
                  'OPTIONAL DEVELOPER API & PKCE',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Provide a Spotify Developer Client ID (with redirect URI melo://spotify-callback) for 1-Tap OAuth PKCE personal feed access, plus optional Client Secret for higher Web API limits.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                MeloGlass(
                  borderRadius: MeloRadii.lg,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _clientIdController,
                          decoration: const InputDecoration(
                            labelText: 'Client ID',
                            hintText: 'Spotify App Client ID',
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _clientSecretController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Client Secret',
                            hintText: 'Spotify App Client Secret',
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            FilledButton(
                              onPressed: _isSaving ? null : _save,
                              child: Text(_isSaving ? 'Saving…' : 'Save Keys'),
                            ),
                            const SizedBox(width: 10),
                            TextButton(
                              onPressed: _clear,
                              child: const Text('Clear'),
                            ),
                          ],
                        ),
                        if (_statusMessage != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _statusMessage!,
                            style: TextStyle(
                              color: colors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Stateful dialog so [_controller] outlives the route pop and IME animations.
class _SpotifyTokenDialog extends StatefulWidget {
  const _SpotifyTokenDialog();

  @override
  State<_SpotifyTokenDialog> createState() => _SpotifyTokenDialogState();
}

class _SpotifyTokenDialogState extends State<_SpotifyTokenDialog> {
  final TextEditingController _controller = TextEditingController();

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
      title: const Text('Connect Spotify Account'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Paste a Spotify Bearer access token, a web session cookie containing sp_dc=..., or your Spotify profile link (https://open.spotify.com/user/...):',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: 3,
            minLines: 1,
            decoration: const InputDecoration(
              hintText: 'https://open.spotify.com/user/... or sp_dc=...',
              isDense: true,
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
          child: const Text('Connect'),
        ),
      ],
    );
  }
}
