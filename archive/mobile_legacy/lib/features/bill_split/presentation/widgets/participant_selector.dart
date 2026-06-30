import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/bill_split_providers.dart';

/// Widget for selecting participants from contacts
class ParticipantSelector extends ConsumerStatefulWidget {
  final VoidCallback onContinue;

  const ParticipantSelector({super.key, required this.onContinue});

  @override
  ConsumerState<ParticipantSelector> createState() =>
      _ParticipantSelectorState();
}

class _ParticipantSelectorState extends ConsumerState<ParticipantSelector> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedParticipants = ref.watch(selectedParticipantsProvider);
    final contactsAsync = ref.watch(searchContactsProvider(_searchQuery));
    final bill = ref.watch(currentBillProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Bill summary
        if (bill != null)
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            child: Row(
              children: [
                Icon(Icons.receipt, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bill.vendor ?? 'Bill',
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        'Total: ${bill.formattedTotal}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selectedParticipants.isNotEmpty)
                  Chip(
                    label: Text(
                      '${bill.totalPaise ~/ selectedParticipants.length / 100} each',
                    ),
                  ),
              ],
            ),
          ),

        // Selected participants
        if (selectedParticipants.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: selectedParticipants.map((p) {
                return Chip(
                  avatar: CircleAvatar(
                    backgroundColor: theme.colorScheme.primary,
                    child: Text(
                      p.initials,
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  label: Text(p.name),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () {
                    ref
                        .read(billSplitControllerProvider)
                        .removeParticipant(p.id);
                  },
                );
              }).toList(),
            ),
          ),

        // Search bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search contacts...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value);
            },
          ),
        ),

        // Contacts list
        Expanded(
          child: contactsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (contacts) {
              if (contacts.isEmpty) {
                return Center(
                  child: Text(
                    'No contacts found',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }

              return ListView.builder(
                itemCount: contacts.length,
                itemBuilder: (context, index) {
                  final contact = contacts[index];
                  final isSelected = selectedParticipants.any(
                    (p) => p.id == contact.id,
                  );

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceContainerHighest,
                      child: Text(
                        contact.initials,
                        style: TextStyle(
                          color: isSelected
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    title: Text(contact.name),
                    subtitle: Text(contact.phone ?? contact.email ?? ''),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle,
                            color: theme.colorScheme.primary,
                          )
                        : const Icon(Icons.add_circle_outline),
                    onTap: () {
                      final controller = ref.read(billSplitControllerProvider);
                      if (isSelected) {
                        controller.removeParticipant(contact.id);
                      } else {
                        controller.addParticipant(contact);
                      }
                    },
                  );
                },
              );
            },
          ),
        ),

        // Continue button
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: selectedParticipants.isEmpty ? null : widget.onContinue,
            icon: const Icon(Icons.calculate),
            label: Text(
              selectedParticipants.isEmpty
                  ? 'Select at least 1 person'
                  : 'Split among ${selectedParticipants.length} people',
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
}
