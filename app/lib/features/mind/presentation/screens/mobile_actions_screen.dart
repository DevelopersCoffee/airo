import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Safe entry point for device commands and the Tiny Garden experiment.
class MobileActionsScreen extends StatefulWidget {
  const MobileActionsScreen({super.key});

  @override
  State<MobileActionsScreen> createState() => _MobileActionsScreenState();
}

class _MobileActionsScreenState extends State<MobileActionsScreen> {
  final Set<int> _plantedPlots = <int>{};

  void _openCommand(String command) {
    context.push('/mind/chat?prefill=${Uri.encodeComponent(command)}');
  }

  void _plant(int plot) => setState(() => _plantedPlots.add(plot));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mobile Actions')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Control Airo with simple commands',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Commands open in AI Chat, where the active runtime explains the action and asks for confirmation before sensitive changes.',
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _commandChip(
                        'Open Wi-Fi settings',
                        'Open WiFi settings.',
                      ),
                      _commandChip('Flashlight on', 'Turn the flashlight on.'),
                      _commandChip(
                        'Flashlight off',
                        'Turn the flashlight off.',
                      ),
                      _commandChip('Create contact', 'Create contact.'),
                      _commandChip('Send email', 'Send email.'),
                      _commandChip(
                        'Show location on map',
                        'Show my location on a map.',
                      ),
                      _commandChip('Show my budget', 'Show my budget summary.'),
                      _commandChip('Play chess', 'Open chess in Airo Arena.'),
                      _commandChip('Split a bill', 'Open bill split.'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tiny Garden',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Try natural-language gardening commands. The garden state is kept locally in this session.',
                  ),
                  const SizedBox(height: 14),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 9,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                    itemBuilder: (context, index) => InkWell(
                      onTap: () => _plant(index),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.brown.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.brown.shade300),
                        ),
                        child: Center(
                          child: _plantedPlots.contains(index)
                              ? const Text('🌱', style: TextStyle(fontSize: 30))
                              : Text('${index + 1}'),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        label: const Text('Plant sunflower on plot 1'),
                        onPressed: () => _plant(0),
                      ),
                      ActionChip(
                        label: const Text('Ask AI to plant'),
                        onPressed: () => _openCommand(
                          'Plant a sunflower seed on plot 1 in Tiny Garden.',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _commandChip(String label, String prompt) =>
      ActionChip(label: Text(label), onPressed: () => _openCommand(prompt));
}
