import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../quotes/presentation/widgets/daily_quote_card.dart';

/// Mind hub for wellbeing, reflection, and light motivation.
class MindScreen extends ConsumerStatefulWidget {
  const MindScreen({super.key});

  @override
  ConsumerState<MindScreen> createState() => _MindScreenState();
}

class _MindScreenState extends ConsumerState<MindScreen> {
  bool _showGreeting = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final greeting = _timeGreeting();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          if (_showGreeting) ...[
            _GreetingCard(
              greeting: greeting,
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
          Text('Mind Actions', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          _MindActionCard(
            title: 'Daily Insight',
            subtitle: 'Open your assistant for a short guided check-in.',
            icon: Icons.lightbulb_outline,
            color: Colors.orange,
            onTap: () => context.push('/mind/chat'),
          ),
          const SizedBox(height: 12),
          _MindActionCard(
            title: 'Breathing Exercise',
            subtitle: 'A guided 60-second breathing reset.',
            icon: Icons.air,
            color: Colors.teal,
            onTap: () => _showBreathingExercise(context),
          ),
          const SizedBox(height: 12),
          _MindActionCard(
            title: 'Reflection',
            subtitle: 'Capture a quick note about how today feels.',
            icon: Icons.edit_note,
            color: Colors.indigo,
            onTap: () => _showReflectionPrompt(context),
          ),
          const SizedBox(height: 16),
          Text('Progress', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          Row(
            children: const [
              Expanded(
                child: _MindStatCard(
                  label: 'Mind Streak',
                  value: '4 days',
                  detail: 'Daily check-ins',
                  icon: Icons.local_fire_department,
                  color: Colors.deepOrange,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _MindStatCard(
                  label: 'Reflections',
                  value: '2 this week',
                  detail: 'Journaling momentum',
                  icon: Icons.auto_stories,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _MindProgressCard(),
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
    return Card(
      child: Padding(
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
      ),
    );
  }
}

class _MindActionCard extends StatelessWidget {
  const _MindActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _MindStatCard extends StatelessWidget {
  const _MindStatCard({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
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
    );
  }
}

class _MindProgressCard extends StatelessWidget {
  const _MindProgressCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
