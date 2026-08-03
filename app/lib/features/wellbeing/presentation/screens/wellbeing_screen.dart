import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/airo_action_card.dart';
import '../../../quotes/presentation/widgets/daily_quote_card.dart';

/// Reflection, breathing, and light motivation.
///
/// Not Airo Mind — that is `packages/feature_mind`, the local-first runtime.
/// This screen and the assistant hub were one screen called "Mind" until
/// milestone 22 needed the name back, and neither half was wellbeing alone.
class WellbeingScreen extends ConsumerStatefulWidget {
  const WellbeingScreen({super.key});

  @override
  ConsumerState<WellbeingScreen> createState() => _WellbeingScreenState();
}

class _WellbeingScreenState extends ConsumerState<WellbeingScreen> {
  bool _showGreeting = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Wellbeing')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          if (_showGreeting) ...[
            _GreetingCard(
              greeting: _timeGreeting(),
              onDismiss: () => setState(() => _showGreeting = false),
            ),
            const SizedBox(height: 16),
          ],
          const DailyQuoteCard(
            showGreeting: false,
            padding: EdgeInsets.zero,
            elevation: 0,
          ),
          const SizedBox(height: 16),
          Text('Wellbeing Actions', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          AiroActionCard(
            title: 'Daily Insight',
            subtitle: 'Open your assistant for a short guided check-in.',
            icon: Icons.lightbulb_outline,
            onTap: () => context.push('/assistant/chat'),
          ),
          const SizedBox(height: 12),
          AiroActionCard(
            title: 'Breathing Exercise',
            subtitle: 'A guided 60-second breathing reset.',
            icon: Icons.air,
            onTap: () => _showBreathingExercise(context),
          ),
          const SizedBox(height: 12),
          AiroActionCard(
            title: 'Reflection',
            subtitle: 'Capture a quick note about how today feels.',
            icon: Icons.edit_note,
            onTap: () => _showReflectionPrompt(context),
          ),
          const SizedBox(height: 16),
          Text('Progress', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          Row(
            children: const [
              Expanded(
                child: _WellbeingStatCard(
                  label: 'Wellbeing Streak',
                  value: '4 days',
                  detail: 'Daily check-ins',
                  icon: Icons.local_fire_department,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _WellbeingStatCard(
                  label: 'Reflections',
                  value: '2 this week',
                  detail: 'Journaling momentum',
                  icon: Icons.auto_stories,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _WellbeingProgressCard(),
        ],
      ),
    );
  }

  String _timeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _showBreathingExercise(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Breathing Exercise',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text('1. Breathe in for 4 seconds.'),
            SizedBox(height: 8),
            Text('2. Hold for 4 seconds.'),
            SizedBox(height: 8),
            Text('3. Exhale for 6 seconds.'),
            SizedBox(height: 8),
            Text('Repeat this cycle for one minute.'),
          ],
        ),
      ),
    );
  }

  void _showReflectionPrompt(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reflection'),
        content: const Text(
          'Take one minute to write down what energized you today and what you want to protect tomorrow.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _GreetingCard extends StatelessWidget {
  const _GreetingCard({required this.greeting, required this.onDismiss});

  final String greeting;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AiroSurface(
      level: AiroSurfaceLevel.raised,
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.wb_sunny_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Welcome back. Take a moment to reset, reflect, and choose one small action for your mind today.',
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            tooltip: 'Dismiss greeting',
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _WellbeingStatCard extends StatelessWidget {
  const _WellbeingStatCard({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final accent = AiroDomainTokens.of(context).accent;
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: '$label: $value. $detail',
      child: AiroSurface(
        level: AiroSurfaceLevel.raised,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent),
            const SizedBox(height: 10),
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(detail),
          ],
        ),
      ),
    );
  }
}

class _WellbeingProgressCard extends StatelessWidget {
  const _WellbeingProgressCard();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      excludeSemantics: true,
      label:
          'Focus Momentum. Breathing goal 60 percent. Reflection goal 40 percent.',
      child: AiroSurface(
        level: AiroSurfaceLevel.raised,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Focus Momentum',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            const _ProgressRow(
              label: 'Breathing goal',
              value: '60%',
              progress: 0.6,
            ),
            const SizedBox(height: 12),
            const _ProgressRow(
              label: 'Reflection goal',
              value: '40%',
              progress: 0.4,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.value,
    required this.progress,
  });

  final String label;
  final String value;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [Text(label), const Spacer(), Text(value)]),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          minHeight: 8,
          borderRadius: BorderRadius.circular(999),
        ),
      ],
    );
  }
}
