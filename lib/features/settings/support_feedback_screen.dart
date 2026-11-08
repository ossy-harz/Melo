import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:melo_player/app/melo_theme.dart';
import 'package:melo_player/features/updates/app_update_service.dart';

class SupportFeedbackScreen extends StatefulWidget {
  const SupportFeedbackScreen({
    this.initialTab = 0,
    super.key,
  });

  final int initialTab;

  @override
  State<SupportFeedbackScreen> createState() => _SupportFeedbackScreenState();
}

class _SupportFeedbackScreenState extends State<SupportFeedbackScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _feedbackController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();

  static const List<String> _categories = [
    '💡 Feature Request',
    '🎨 UI & Visual Design',
    '🔊 Audio Quality & EQ',
    '⚡ Performance & Battery',
    '🐞 Bug Report',
    '💬 General Feedback',
  ];

  String _selectedCategory = _categories.first;
  bool _isSubmitting = false;

  static const String _buyMeACoffeeUrl = 'https://buymeacoffee.com/ossyharz';
  static const String _githubRepoUrl = 'https://github.com/ossy-harz/Melo';
  static const String _githubSponsorUrl = 'https://github.com/sponsors/ossy-harz';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _feedbackController.dispose();
    _titleController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _openUrl(String url) async {
    final opened = await AppUpdateService.openExternalUrl(url);
    if (!opened && mounted) {
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Link copied to clipboard: $url'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _submitFeedback() async {
    final message = _feedbackController.text.trim();
    final title = _titleController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your feedback or feature recommendation.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final appVersion = AppUpdateService.instance.currentVersion;
      final categoryClean = _selectedCategory.replaceAll(RegExp(r'^[^\w]+'), '').trim();
      final issueTitle = title.isNotEmpty
          ? '[$categoryClean] $title'
          : '[$categoryClean] Recommendation from Melo v$appVersion';

      final contact = _contactController.text.trim();
      final body = StringBuffer()
        ..writeln('### Feedback Category')
        ..writeln(_selectedCategory)
        ..writeln()
        ..writeln('### Recommendation / Description')
        ..writeln(message)
        ..writeln()
        ..writeln('### Environment Details')
        ..writeln('- **App Version**: Melo v$appVersion')
        ..writeln('- **Platform**: Android')
        ..writeln('- **Submitted Via**: In-App Feedback');

      if (contact.isNotEmpty) {
        body.writeln('- **Contact/Username**: $contact');
      }

      final encodedTitle = Uri.encodeComponent(issueTitle);
      final encodedBody = Uri.encodeComponent(body.toString());
      final repo = AppUpdateService.instance.repository;
      final issueUrl = 'https://github.com/$repo/issues/new?title=$encodedTitle&body=$encodedBody';

      await _openUrl(issueUrl);

      if (mounted) {
        _feedbackController.clear();
        _titleController.clear();
        _contactController.clear();
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.favorite_rounded, color: MeloColors.cherry),
                SizedBox(width: 10),
                Text('Thank You!'),
              ],
            ),
            content: const Text(
              'Your recommendation has been sent! Melo is shaped by real listener feedback, '
              'and every suggestion is reviewed to make Melo the ultimate audio experience.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Awesome'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Support & Feedback'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: MeloColors.cherry,
          labelColor: colors.onSurface,
          unselectedLabelColor: colors.onSurfaceVariant,
          tabs: const [
            Tab(
              icon: Icon(Icons.coffee_rounded, size: 20),
              text: 'Support Melo',
            ),
            Tab(
              icon: Icon(Icons.lightbulb_outline_rounded, size: 20),
              text: 'Feature Requests',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSupportTab(colors, textTheme),
          _buildFeedbackTab(colors, textTheme),
        ],
      ),
    );
  }

  Widget _buildSupportTab(ColorScheme colors, TextTheme textTheme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        // Hero Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                MeloColors.cherry.withValues(alpha: 0.22),
                colors.surfaceContainerHigh,
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: MeloColors.cherry.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: MeloColors.cherry.withValues(alpha: 0.2),
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: MeloColors.cherry,
                  size: 38,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Melo is 100% Free & Open Source',
                textAlign: TextAlign.center,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'No advertisements. No subscriptions. No locked codecs.\n'
                'Built for pure, bit-perfect music lovers around the globe.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Why Support Card
        Text(
          'FUEL FUTURE DEVELOPMENT',
          style: textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFDD00).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.local_cafe_rounded,
                      color: Color(0xFFFFDD00),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Buy Me a Coffee',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Keep audio servers, lyrics sync, and daily updates thriving.',
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Every donation directly supports maintenance, continuous integration tests, '
                'high-resolution streaming servers, and new community-voted features.',
                style: textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _openUrl(_buyMeACoffeeUrl),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFFDD00),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.coffee_rounded, size: 20),
                  label: const Text(
                    'Support on Buy Me a Coffee',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openUrl(_githubSponsorUrl),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.favorite_border_rounded, size: 18),
                  label: const Text('Sponsor on GitHub'),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Free Ways to Support
        Text(
          'FREE WAYS TO HELP MELO GROW',
          style: textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        _SupportOptionTile(
          icon: Icons.star_rounded,
          iconColor: Colors.amber,
          title: 'Star on GitHub',
          subtitle: 'Give Melo a star on GitHub to boost visibility.',
          onTap: () => _openUrl(_githubRepoUrl),
        ),
        const SizedBox(height: 10),
        _SupportOptionTile(
          icon: Icons.share_rounded,
          iconColor: Colors.lightBlueAccent,
          title: 'Share with Audiophile Friends',
          subtitle: 'Tell other music lovers looking for clean lossless playback.',
          onTap: () {
            Clipboard.setData(
              const ClipboardData(
                text: 'Check out Melo - High-res lossless audio player for Android: https://github.com/ossy-harz/Melo',
              ),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Download link copied to clipboard!'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        _SupportOptionTile(
          icon: Icons.rate_review_outlined,
          iconColor: Colors.greenAccent,
          title: 'Recommend New Features',
          subtitle: 'Tell us what features would take Melo to the top of the leaderboards.',
          onTap: () => _tabController.animateTo(1),
        ),
      ],
    );
  }

  Widget _buildFeedbackTab(ColorScheme colors, TextTheme textTheme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        Text(
          'WHAT WOULD YOU LIKE TO SEE IN MELO?',
          style: textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Have an idea for a killer feature, a design polish, or a bug to report? '
          'We read every submission to make Melo the best audio player in the market.',
          style: textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 18),

        // Category Chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categories.map((cat) {
            final isSelected = cat == _selectedCategory;
            return ChoiceChip(
              label: Text(cat),
              selected: isSelected,
              selectedColor: MeloColors.cherry.withValues(alpha: 0.25),
              onSelected: (selected) {
                if (selected) setState(() => _selectedCategory = cat);
              },
            );
          }).toList(),
        ),

        const SizedBox(height: 20),

        // Title Input
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: 'Summary or Feature Title',
            hintText: 'e.g. Smart Sleep Timer with gradual audio fade out',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            filled: true,
            fillColor: colors.surfaceContainerLow,
          ),
        ),

        const SizedBox(height: 14),

        // Detailed Message Input
        TextField(
          controller: _feedbackController,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: 'Details / Description',
            hintText: 'Describe how this feature should work or what problem it solves...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            filled: true,
            fillColor: colors.surfaceContainerLow,
            alignLabelWithHint: true,
          ),
        ),

        const SizedBox(height: 14),

        // Contact Input (Optional)
        TextField(
          controller: _contactController,
          decoration: InputDecoration(
            labelText: 'Your Contact or GitHub username (Optional)',
            hintText: 'e.g. @yourhandle or listener@email.com',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            filled: true,
            fillColor: colors.surfaceContainerLow,
          ),
        ),

        const SizedBox(height: 22),

        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isSubmitting ? null : _submitFeedback,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded, size: 18),
            label: Text(
              _isSubmitting ? 'Opening Submission...' : 'Submit Feedback & Ideas',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),

        const SizedBox(height: 32),

        // Community Roadmap Preview
        Text(
          'COMMUNITY ROADMAP PROGRESS',
          style: textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        _RoadmapTile(
          title: 'Dual-Deck AutoMix Crossfade',
          status: 'Shipped in v1.1.0',
          isDone: true,
        ),
        _RoadmapTile(
          title: 'Apple Music & Spotify Hybrid Hero Playlist',
          status: 'Shipped in v1.1.0',
          isDone: true,
        ),
        _RoadmapTile(
          title: 'Pull-to-Refresh Device Library Scan',
          status: 'Shipped in v1.1.0',
          isDone: true,
        ),
        _RoadmapTile(
          title: 'Smart In-App GitHub APK Updater (No Re-download)',
          status: 'Shipped in v1.2.0',
          isDone: true,
        ),
        _RoadmapTile(
          title: 'Smart Sleep Timer with Gentle Audio Fade',
          status: 'In Progress (v1.2.0)',
          isDone: false,
        ),
        _RoadmapTile(
          title: 'Custom Equalizer Profiles Per Audio Device',
          status: 'Planned for v1.3.0',
          isDone: false,
        ),
      ],
    );
  }
}

class _SupportOptionTile extends StatelessWidget {
  const _SupportOptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: colors.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoadmapTile extends StatelessWidget {
  const _RoadmapTile({
    required this.title,
    required this.status,
    required this.isDone,
  });

  final String title;
  final String status;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: isDone ? Colors.greenAccent : colors.outlineVariant,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: isDone ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13,
                color: isDone ? colors.onSurface : colors.onSurfaceVariant,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isDone
                  ? Colors.greenAccent.withValues(alpha: 0.15)
                  : colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDone ? Colors.greenAccent : colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
