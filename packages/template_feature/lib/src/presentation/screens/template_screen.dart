
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/template_provider.dart';

/// Template screen - replace with your actual screen
class TemplateScreen extends ConsumerStatefulWidget {
  const TemplateScreen({super.key});

  @override
  ConsumerState<TemplateScreen> createState() => _TemplateScreenState();
}

class _TemplateScreenState extends ConsumerState<TemplateScreen> {
  @override
  void initState() {
    super.initState();
    // Load data when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(templateProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(templateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Template Feature')),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(TemplateState state) => switch (state) {
    TemplateInitial() => const Center(child: Text('Press button to load')),
    TemplateLoading() => const Center(child: CircularProgressIndicator()),
    TemplateLoaded(:final items) => _buildList(items),
    TemplateError(:final message) => Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Error: $message'),
          ElevatedButton(
            onPressed: () => ref.read(templateProvider.notifier).load(),
            child: const Text('Retry'),
          ),
        ],
      ),
    ),
  };

  Widget _buildList(List items) {
    if (items.isEmpty) {
      return const Center(child: Text('No items found'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () {
              // Handle item tap
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: Theme.of(context).textTheme.titleMedium),
                  if (item.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.description!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
