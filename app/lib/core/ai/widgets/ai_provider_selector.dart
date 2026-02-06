import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ai_provider.dart';
import '../ai_router_service.dart';

/// AI Provider Selector Widget
/// Shows available AI providers and allows user to select one
class AIProviderSelector extends ConsumerWidget {
  final VoidCallback? onProviderSelected;

  const AIProviderSelector({super.key, this.onProviderSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providerStatusAsync = ref.watch(aiProviderStatusProvider);
    final selectedProvider = ref.watch(selectedAIProviderProvider);

    return providerStatusAsync.when(
      data: (statuses) =>
          _buildSelector(context, ref, statuses, selectedProvider),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) =>
          Center(child: Text('Error loading AI providers: $error')),
    );
  }

  Widget _buildSelector(
    BuildContext context,
    WidgetRef ref,
    Map<AIProvider, AIProviderStatus> statuses,
    AIProvider selectedProvider,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.psychology, size: 28),
              const SizedBox(width: 12),
              const Text(
                'Select AI Provider',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  ref.invalidate(aiProviderStatusProvider);
                },
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Provider options
        ...AIProvider.values.map((provider) {
          final status = statuses[provider];
          final isSelected = selectedProvider == provider;
          final isAvailable = status?.isAvailable ?? false;

          return _buildProviderTile(
            context,
            ref,
            provider,
            status,
            isSelected,
            isAvailable,
          );
        }),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildProviderTile(
    BuildContext context,
    WidgetRef ref,
    AIProvider provider,
    AIProviderStatus? status,
    bool isSelected,
    bool isAvailable,
  ) {
    final capabilities = status?.capabilities;

    return ListTile(
      leading: _getProviderIcon(provider, isAvailable),
      title: Text(
        provider.displayName,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isAvailable ? null : Colors.grey,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            provider.description,
            style: TextStyle(
              fontSize: 12,
              color: isAvailable ? Colors.grey[600] : Colors.grey,
            ),
          ),
          if (capabilities != null && isAvailable) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: [
                if (capabilities.supportsStreaming)
                  _buildCapabilityChip('Streaming', Icons.stream),
                if (capabilities.supportsImages)
                  _buildCapabilityChip('Images', Icons.image),
                if (capabilities.supportsFiles)
                  _buildCapabilityChip('Files', Icons.attach_file),
              ],
            ),
          ],
          if (!isAvailable && capabilities?.errorMessage != null) ...[
            const SizedBox(height: 4),
            Text(
              capabilities!.errorMessage!,
              style: const TextStyle(fontSize: 11, color: Colors.red),
            ),
          ],
        ],
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: Colors.green)
          : null,
      enabled: isAvailable || provider == AIProvider.auto,
      onTap: isAvailable || provider == AIProvider.auto
          ? () {
              ref.read(selectedAIProviderProvider.notifier).state = provider;
              ref.read(aiRouterServiceProvider).setProvider(provider);
              onProviderSelected?.call();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Switched to ${provider.displayName}'),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          : null,
    );
  }

  Widget _getProviderIcon(AIProvider provider, bool isAvailable) {
    IconData icon;
    Color? color;

    switch (provider) {
      case AIProvider.nano:
        icon = Icons.phone_android;
        color = isAvailable ? Colors.blue : Colors.grey;
        break;
      case AIProvider.cloud:
        icon = Icons.cloud;
        color = isAvailable ? Colors.purple : Colors.grey;
        break;
      case AIProvider.auto:
        icon = Icons.auto_awesome;
        color = Colors.orange;
        break;
    }

    return Icon(icon, color: color);
  }

  Widget _buildCapabilityChip(String label, IconData icon) {
    return Chip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 10)),
        ],
      ),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}

/// Show AI Provider Selector as bottom sheet
Future<void> showAIProviderSelector(BuildContext context) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => SingleChildScrollView(
        controller: scrollController,
        child: AIProviderSelector(
          onProviderSelected: () {
            // Keep sheet open to show selection
          },
        ),
      ),
    ),
  );
}
