import 'package:flutter/material.dart';
import '../../../shared/widgets/airo_app_bar.dart';
import '../../gemini_nano/screens/gemini_nano_chat_screen.dart';

class AiroHomeScreen extends StatelessWidget {
  const AiroHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AiroAppBar(title: 'Airo'),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome to Airo',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Your AI-powered assistant',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildFeatureCard(
                    context,
                    'Gemini Nano Chat',
                    'AI-powered conversations (Pixel 9)',
                    Icons.chat_bubble_outline,
                    Colors.blue,
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const GeminiNanoChatScreen(),
                        ),
                      );
                    },
                  ),
                  _buildFeatureCard(
                    context,
                    'Voice Commands',
                    'Speak to your AI',
                    Icons.mic_outlined,
                    Colors.green,
                    () {
                      // TODO: Navigate to voice
                    },
                  ),
                  _buildFeatureCard(
                    context,
                    'Smart Tasks',
                    'Automated workflows',
                    Icons.task_alt_outlined,
                    Colors.orange,
                    () {
                      // TODO: Navigate to tasks
                    },
                  ),
                  _buildFeatureCard(
                    context,
                    'Analytics',
                    'Usage insights',
                    Icons.analytics_outlined,
                    Colors.purple,
                    () {
                      // TODO: Navigate to analytics
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

  Widget _buildFeatureCard(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Keep the old class for backward compatibility
class AiroHello extends AiroHomeScreen {
  const AiroHello({super.key});
}
