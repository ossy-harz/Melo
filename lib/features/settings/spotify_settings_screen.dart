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
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  @override
  void dispose() {
    _clientIdController.dispose();
    _clientSecretController.dispose();
    super.dispose();
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
                        color: const Color(0xFF1DB954).withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.playlist_play_rounded,
                        color: Color(0xFF1DB954),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cloud Integration in Melo',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'Import playlists, albums, and tracks directly into your music library.',
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
                const SizedBox(height: 20),
                FilledButton.icon(
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
                  'OPTIONAL DEVELOPER API',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Public playlists work immediately without credentials. If you wish to import private user playlists or use higher API limits, you can provide your own Spotify Developer App keys.',
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
