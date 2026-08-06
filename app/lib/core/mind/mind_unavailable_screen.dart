import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// What the Airo Mind shell shows for a destination it does not ship.
///
/// `packages/feature_assistant` navigates to absolute super-app paths that
/// only the super app mounts — `/games` and `/quest/new` from the hub and the
/// chat screen, `/money*`, `/live/*`, `/offers`, `/reader` from the tool
/// registry, `/settings` from the profile screen's Settings tile. The package
/// must not learn which shell it is running in (that is a shell concern, and
/// an `if (shell == mind)` inside a package widget is exactly the branching
/// the modular-shell plan forbids), so the *shell* absorbs the gap: the Mind
/// router hands every unmatched location to this screen instead of GoRouter's
/// red error page.
///
/// The result is an explanation and a way back, rather than a dead end that
/// reads like a crash.
class MindUnavailableScreen extends StatelessWidget {
  const MindUnavailableScreen({required this.location, super.key});

  /// The location that did not resolve, shown so a dogfooder can report the
  /// exact path rather than "a button did nothing".
  final String location;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Not in Airo Mind')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.explore_off_outlined,
                size: 48,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                'That lives in the Airo app',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Airo Mind ships the recorder and the assistant. '
                '$location belongs to the full Airo app.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('Back to Mind'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
