import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../assistant_surface_policy.dart';
import '../../../widgets/airo_action_card.dart';

/// On-device AI: chat, skills, transcription, prompts, models.
///
/// This hub lived at `/mind` and was called "Mind" until milestone 22 needed
/// that name for the local-first runtime in `packages/feature_mind`. Several
/// of these screens are that runtime's predecessors — Audio Scribe, Prompt
/// Lab, and model management all get proper Mind surfaces in M22 — so expect
/// this list to shrink rather than grow.
class AssistantScreen extends ConsumerWidget {
  const AssistantScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final policy = ref.watch(assistantSurfacePolicyProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Text('Airo AI Lab', style: theme.textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Explore private, on-device AI use cases. Downloaded local models keep prompts on this device.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          AiroActionCard(
            title: 'AI Chat',
            subtitle: 'Multi-turn chat with runtime and action traces.',
            icon: Icons.chat_bubble_outline,
            onTap: () => context.push('/assistant/chat'),
          ),
          const SizedBox(height: 10),
          AiroActionCard(
            title: 'Agent Skills',
            subtitle: 'Ground answers with tools, maps, and visual summaries.',
            icon: Icons.extension_outlined,
            onTap: () => context.push('/assistant/skills'),
          ),
          if (policy.showQuestImage) ...[
            const SizedBox(height: 10),
            AiroActionCard(
              title: 'Ask Image',
              subtitle: 'Upload an image and ask Airo questions about it.',
              icon: Icons.image_outlined,
              onTap: () => context.push('/quest/new'),
            ),
          ],
          const SizedBox(height: 10),
          AiroActionCard(
            title: 'Meeting Scribe',
            subtitle:
                'Record meetings, extract decisions and action items offline.',
            icon: Icons.record_voice_over_outlined,
            onTap: () => context.push('/scribe'),
          ),
          const SizedBox(height: 10),
          AiroActionCard(
            title: 'Audio Scribe',
            subtitle:
                'Capture speech, review the transcript, and translate with Airo.',
            icon: Icons.mic_none,
            onTap: () => context.push('/assistant/audio-scribe'),
          ),
          const SizedBox(height: 10),
          AiroActionCard(
            title: 'Prompt Lab',
            subtitle: 'Compare prompts with temperature and top-k controls.',
            icon: Icons.tune,
            onTap: () => context.push('/assistant/prompt-lab'),
          ),
          if (policy.showMobileActions) ...[
            const SizedBox(height: 10),
            AiroActionCard(
              title: 'Mobile Actions & Tiny Garden',
              subtitle:
                  'Try safe device commands and a playful natural-language garden.',
              icon: Icons.local_florist_outlined,
              onTap: () => context.push('/assistant/mobile-actions'),
            ),
          ],
          const SizedBox(height: 10),
          AiroActionCard(
            title: 'Model Management & Benchmark',
            subtitle:
                'Install models, check readiness, and understand performance.',
            icon: Icons.analytics_outlined,
            onTap: () => context.push('/assistant/models'),
          ),
          const SizedBox(height: 10),
          AiroActionCard(
            title: 'Device Capability Report',
            subtitle: 'See memory, on-device AI support, and model fit.',
            icon: Icons.memory_outlined,
            onTap: () => context.push('/assistant/device-capabilities'),
          ),
          const SizedBox(height: 10),
          AiroActionCard(
            title: 'Model Advisor',
            subtitle:
                'Choose a capability and get a device-fit recommendation.',
            icon: Icons.auto_awesome_outlined,
            onTap: () => context.push('/assistant/model-advisor'),
          ),
          const SizedBox(height: 24),
          Text('Wellbeing', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          AiroActionCard(
            title: 'Reflection & Breathing',
            subtitle: 'Daily insight, a breathing reset, and your streak.',
            icon: Icons.self_improvement_outlined,
            onTap: () => context.push('/wellbeing'),
          ),
        ],
      ),
    );
  }
}
