import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:melo_player/app/melo_theme.dart';
import 'package:melo_player/features/insights/melo_insights_service.dart';
import 'package:melo_player/features/library/imported_track.dart';
import 'package:melo_player/features/library/music_library.dart';
import 'package:melo_player/features/player/mini_player.dart';

class MeloInsightsScreen extends StatefulWidget {
  const MeloInsightsScreen({
    this.library,
    this.audioHandler,
    super.key,
  });

  final MusicLibrary? library;
  final AudioHandler? audioHandler;

  @override
  State<MeloInsightsScreen> createState() => _MeloInsightsScreenState();
}

class _MeloInsightsScreenState extends State<MeloInsightsScreen> {
  MeloInsightsReport? _report;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    final report = await MeloInsightsService.instance.generateReport(
      library: widget.library,
    );
    if (mounted) {
      setState(() {
        _report = report;
        _isLoading = false;
      });
    }
  }

  Future<void> _playTracks(List<ImportedTrack> tracks, String label) async {
    final lib = widget.library;
    final handler = widget.audioHandler;
    if (tracks.isEmpty || lib == null || handler == null) return;
    unawaited(HapticFeedback.mediumImpact());
    await lib.playMix(handler, tracks);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Playing $label (${tracks.length} tracks)'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _shareInsights(MeloInsightsReport report) {
    unawaited(HapticFeedback.lightImpact());
    final hours = (report.totalListeningMinutes / 60).toStringAsFixed(1);
    final topArtist = report.topArtists.isNotEmpty ? report.topArtists.first.artist : 'My Collection';
    final text = 'My Melo Listening Insights:\n'
        '• $hours hours of music across ${report.totalPlays} plays\n'
        '• #1 Artist: $topArtist\n'
        '• Dominant Vibe: ${report.dominantVibe.title} (${report.dominantVibe.subtitle})\n'
        '#MeloInsights #Audiophile';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Insights summary copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Melo Insights',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.3),
        ),
        actions: [
          if (_report != null)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share insights',
              onPressed: () => _shareInsights(_report!),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _report == null || _report!.totalPlays == 0
              ? _buildEmptyState()
              : _buildReportView(_report!, isDark),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_graph_rounded, size: 64, color: MeloColors.cherry.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            const Text(
              'Your Musical Journey Begins',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Play a few songs from your library or connected sources. Melo Insights will automatically calculate your listening habits, favorite artists, and forgotten gems.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportView(MeloInsightsReport report, bool isDark) {
    final hours = (report.totalListeningMinutes / 60).toStringAsFixed(1);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dominant Vibe Hero Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF2A1420), const Color(0xFF161118)]
                    : [const Color(0xFFFFECEF), const Color(0xFFFFF7F8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: MeloColors.cherry.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: MeloColors.cherry.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(MeloRadii.pill),
                      ),
                      child: Text(
                        'LISTENING VIBE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: MeloColors.cherry,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    Icon(Icons.nights_stay_rounded, color: MeloColors.cherry, size: 20),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  report.dominantVibe.title,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.6),
                ),
                const SizedBox(height: 4),
                Text(
                  report.dominantVibe.subtitle,
                  style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.75)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Core Stats Row
          Row(
            children: [
              Expanded(
                child: _buildStatCard('Hours Listened', hours, Icons.access_time_filled_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard('Total Plays', '${report.totalPlays}', Icons.play_circle_fill_rounded),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Top Artists
          if (report.topArtists.isNotEmpty) ...[
            const Text(
              'Top Artists',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A1E) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < report.topArtists.length; i++) ...[
                    _buildArtistRow(i + 1, report.topArtists[i]),
                    if (i < report.topArtists.length - 1)
                      const Divider(color: Colors.white10, height: 18),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 28),
          ],

          // Forgotten Gems Section
          if (report.forgottenGems.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Forgotten Gems',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                TextButton.icon(
                  onPressed: () => _playTracks(report.forgottenGems, 'Forgotten Gems'),
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('Play All'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Songs you loved but haven\'t heard in a while.',
              style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: report.forgottenGems.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, idx) {
                  final track = report.forgottenGems[idx];
                  return _buildTrackMiniCard(track);
                },
              ),
            ),
            const SizedBox(height: 28),
          ],

          // Top Tracks Shelf
          if (report.topTracks.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Heavy Rotation',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                TextButton.icon(
                  onPressed: () => _playTracks(report.topTracks, 'Heavy Rotation'),
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('Play All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < report.topTracks.take(5).length; i++)
              _buildTrackTile(i + 1, report.topTracks[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: MeloColors.cherry),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildArtistRow(int rank, ArtistPlayStat stat) {
    return Row(
      children: [
        SizedBox(
          width: 24,
          child: Text(
            '$rank',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: rank == 1 ? MeloColors.cherry : Colors.white54,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stat.artist,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: stat.percentage.clamp(0.05, 1.0),
                  minHeight: 4,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation(MeloColors.cherry),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Text(
          '${stat.playCount} plays',
          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)),
        ),
      ],
    );
  }

  Widget _buildTrackMiniCard(ImportedTrack track) {
    return InkWell(
      onTap: () => _playTracks([track], track.title),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 110,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AlbumArtwork(
                size: 90,
                title: track.title,
                artworkUri: track.artworkUri != null ? Uri.tryParse(track.artworkUri!) : null,
                sourceUri: Uri.tryParse(track.path),
                borderRadius: 10,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              track.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackTile(int rank, ImportedTrack track) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AlbumArtwork(
          size: 48,
          title: track.title,
          artworkUri: track.artworkUri != null ? Uri.tryParse(track.artworkUri!) : null,
          sourceUri: Uri.tryParse(track.path),
          borderRadius: 8,
        ),
      ),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        track.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.play_circle_outline_rounded),
        onPressed: () => _playTracks([track], track.title),
      ),
    );
  }
}
