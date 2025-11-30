import 'package:core_ui/core_ui.dart';
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
      appBar: AppBar(
        title: const Text('Template Feature'),
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(TemplateState state) => switch (state) {
        TemplateInitial() => const Center(
            child: Text('Press button to load'),
          ),
        TemplateLoading() => const Center(
            child: LoadingIndicator(),
          ),
        TemplateLoaded(:final items) => _buildList(items),
        TemplateError(:final message) => ErrorView(
            message: message,
            onRetry: () => ref.read(templateProvider.notifier).load(),
          ),
      };

  Widget _buildList(List items) {
    if (items.isEmpty) {
      return const Center(child: Text('No items found'));
    }

    return ListView.builder(
      padding: AppSpacing.screenPadding,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return AppCard(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          onTap: () {
            // Handle item tap
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (item.description != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  item.description!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

