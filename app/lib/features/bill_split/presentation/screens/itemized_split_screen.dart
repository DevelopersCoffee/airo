import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/utils/locale_settings.dart';
import '../../domain/models/receipt_item.dart';
import '../../domain/services/receipt_parser_service.dart';

/// Test IDs for Playwright/Patrol testing
class ItemizedSplitTestIds {
  static const String screen = 'itemized-split-screen';
  static const String cameraButton = 'itemized-camera-button';
  static const String galleryButton = 'itemized-gallery-button';
  static const String loadingIndicator = 'itemized-loading-indicator';
  static const String vendorHeader = 'itemized-vendor-header';
  static const String itemsList = 'itemized-items-list';
  static const String itemCard = 'itemized-item-card';
  static const String participantChip = 'itemized-participant-chip';
  static const String summaryFooter = 'itemized-summary-footer';
  static const String confirmButton = 'itemized-confirm-button';
  static const String quickAssignButton = 'itemized-quick-assign-button';
  static String itemCardId(String itemId) => 'item-$itemId';
  static String participantChipId(String participantId) =>
      'chip-$participantId';
}

/// Provider for receipt parser service
final receiptParserProvider = Provider<ReceiptParserService>((ref) {
  return MLKitReceiptParserService();
});

/// Provider for participants list
final participantsProvider = StateProvider<List<ItemParticipant>>((ref) => []);

/// Provider for receipt items with participant assignments
final receiptItemsProvider =
    StateNotifierProvider<ReceiptItemsNotifier, List<ReceiptItem>>((ref) {
      return ReceiptItemsNotifier();
    });

class ReceiptItemsNotifier extends StateNotifier<List<ReceiptItem>> {
  ReceiptItemsNotifier() : super([]);

  void setItems(List<ReceiptItem> items) {
    state = items;
  }

  /// Toggle a participant for a specific item
  void toggleParticipant(String itemId, String participantId) {
    state = [
      for (final item in state)
        if (item.id == itemId) item.toggleParticipant(participantId) else item,
    ];
  }

  /// Assign all items to a specific participant only
  void setAllToParticipant(String participantId) {
    state = [
      for (final item in state)
        item.copyWith(assignedParticipantIds: {participantId}),
    ];
  }

  /// Reset all items to split among all (no specific assignment)
  void setAllSplit() {
    state = [
      for (final item in state) item.copyWith(assignedParticipantIds: {}),
    ];
  }
}

/// Result returned when itemized split is confirmed
class ItemizedSplitResult {
  final double totalAmount;
  final String description;
  final Map<String, int> summary; // participant ID -> amount in paise
  final String? vendor;
  final String? orderId;
  final List<ItemizedSplitItem> itemizedDetails; // detailed items per person

  const ItemizedSplitResult({
    required this.totalAmount,
    required this.description,
    required this.summary,
    this.vendor,
    this.orderId,
    this.itemizedDetails = const [],
  });

  /// Generate WhatsApp-shareable message with full item details
  ///
  /// [participants] - List of participants to include in the message
  /// [currencySymbol] - Currency symbol to use (e.g., '₹', '$', '€')
  String generateWhatsAppMessage(
    List<ItemParticipant> participants, {
    String currencySymbol = '₹',
  }) {
    final buffer = StringBuffer();

    buffer.writeln('🧾 *Bill Split - ${vendor ?? "Receipt"}*');
    if (orderId != null) buffer.writeln('Order #$orderId');
    buffer.writeln('');
    buffer.writeln(
      '💰 *Total: $currencySymbol${totalAmount.toStringAsFixed(2)}*',
    );
    buffer.writeln('');

    // Group items by participant
    final itemsByParticipant = <String, List<ItemizedSplitItem>>{};
    for (final item in itemizedDetails) {
      for (final pId in item.participantIds) {
        itemsByParticipant.putIfAbsent(pId, () => []).add(item);
      }
    }

    buffer.writeln('📋 *Breakdown:*');
    for (final p in participants) {
      final amount = summary[p.id] ?? 0;
      final name = p.isMe ? 'You' : p.name;
      buffer.writeln('');
      buffer.writeln(
        '👤 *$name: $currencySymbol${(amount / 100).toStringAsFixed(2)}*',
      );

      final items = itemsByParticipant[p.id] ?? [];
      for (final item in items) {
        final splitCount = item.participantIds.length;
        final itemShare = item.pricePaise ~/ splitCount;
        if (splitCount > 1) {
          buffer.writeln(
            '  • ${item.name} (split ÷$splitCount) $currencySymbol${(itemShare / 100).toStringAsFixed(2)}',
          );
        } else {
          buffer.writeln(
            '  • ${item.name} $currencySymbol${(item.pricePaise / 100).toStringAsFixed(2)}',
          );
        }
      }
    }

    buffer.writeln('');
    buffer.writeln('---');
    buffer.writeln('_Shared via Airo_');

    return buffer.toString();
  }
}

/// Represents a single item in the itemized split
class ItemizedSplitItem {
  final String name;
  final int pricePaise;
  final Set<String> participantIds;

  const ItemizedSplitItem({
    required this.name,
    required this.pricePaise,
    required this.participantIds,
  });
}

/// Screen for itemized bill splitting with multiple participants
class ItemizedSplitScreen extends ConsumerStatefulWidget {
  final List<String> participantNames;
  final String? imagePath;

  const ItemizedSplitScreen({
    super.key,
    this.participantNames = const ['Roommate'],
    this.imagePath,
  });

  @override
  ConsumerState<ItemizedSplitScreen> createState() =>
      _ItemizedSplitScreenState();
}

class _ItemizedSplitScreenState extends ConsumerState<ItemizedSplitScreen> {
  bool _isLoading = false;
  bool _hasReceipt = false;
  ParsedReceipt? _receipt;
  final _imagePicker = ImagePicker();
  late final List<ItemParticipant> _participants;

  @override
  void initState() {
    super.initState();
    _initParticipants();
    if (widget.imagePath != null) {
      // Delay loading to avoid modifying state during build
      Future.microtask(() => _loadReceiptFromPath(widget.imagePath!));
    }
  }

  void _initParticipants() {
    // Always add "Me" as first participant - use local state only
    _participants = [ItemParticipant.me];
    // Add other participants from names
    for (var i = 0; i < widget.participantNames.length; i++) {
      _participants.add(
        ItemParticipant(id: 'p$i', name: widget.participantNames[i]),
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        await _loadReceiptFromPath(image.path);
      }
    } catch (e, stack) {
      debugPrint('Image picker error: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  Future<void> _loadReceiptFromPath(String imagePath) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final parser = ref.read(receiptParserProvider);
      final file = File(imagePath);

      if (!await file.exists()) {
        throw Exception('Image file not found at: $imagePath');
      }

      final receipt = await parser.parseReceipt(file);

      if (!mounted) return;
      ref.read(receiptItemsProvider.notifier).setItems(receipt.items);

      setState(() {
        _receipt = receipt;
        _hasReceipt = true;
        _isLoading = false;
      });
    } catch (e, stack) {
      debugPrint('Receipt parse error: $e\n$stack');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to parse receipt: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      key: const Key(ItemizedSplitTestIds.screen),
      appBar: AppBar(
        title: const Text('Split Items'),
        actions: [
          if (_hasReceipt)
            TextButton(
              key: const Key(ItemizedSplitTestIds.quickAssignButton),
              onPressed: _showQuickAssignMenu,
              child: const Text('Quick Assign'),
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              key: const Key(ItemizedSplitTestIds.loadingIndicator),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Scanning receipt...'),
                ],
              ),
            )
          : _hasReceipt
          ? Column(
              children: [
                if (_receipt != null) _buildVendorHeader(theme),
                Expanded(child: _buildItemsList(theme)),
                _buildSummaryFooter(theme),
              ],
            )
          : _buildImagePickerView(theme),
    );
  }

  Widget _buildImagePickerView(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              size: 80,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text('Upload Receipt', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Take a photo or choose from gallery',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.icon(
                  key: const Key(ItemizedSplitTestIds.cameraButton),
                  onPressed: kIsWeb
                      ? null
                      : () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  key: const Key(ItemizedSplitTestIds.galleryButton),
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVendorHeader(ThemeData theme) {
    return Container(
      key: const Key(ItemizedSplitTestIds.vendorHeader),
      padding: const EdgeInsets.all(16),
      color: theme.colorScheme.primaryContainer,
      child: Row(
        children: [
          Icon(Icons.store, color: theme.colorScheme.onPrimaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _receipt!.vendor ?? 'Receipt',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                if (_receipt!.orderId != null)
                  Text(
                    'Order #${_receipt!.orderId}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer.withValues(
                        alpha: 0.7,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            _receipt!.formattedGrandTotal,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(ThemeData theme) {
    final items = ref.watch(receiptItemsProvider);

    return ListView.builder(
      key: const Key(ItemizedSplitTestIds.itemsList),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length + (_receipt?.fees.isNotEmpty == true ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < items.length) {
          return _MultiParticipantItemTile(
            item: items[index],
            participants: _participants,
            onParticipantToggled: (participantId) {
              ref
                  .read(receiptItemsProvider.notifier)
                  .toggleParticipant(items[index].id, participantId);
            },
          );
        } else {
          return _buildFeesSection(theme);
        }
      },
    );
  }

  Widget _buildFeesSection(ThemeData theme) {
    if (_receipt?.fees.isEmpty ?? true) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Fees (split proportionally)',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        ...(_receipt?.fees ?? []).map(
          (fee) => ListTile(
            dense: true,
            leading: Icon(
              fee.type == FeeType.delivery
                  ? Icons.delivery_dining
                  : Icons.receipt_long,
              size: 20,
              color: theme.colorScheme.outline,
            ),
            title: Text(fee.type.displayName),
            trailing: Text(
              fee.formattedAmount,
              style: TextStyle(
                color: fee.isFree ? Colors.green : null,
                fontWeight: fee.isFree ? FontWeight.bold : null,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryFooter(ThemeData theme) {
    final items = ref.watch(receiptItemsProvider);
    final summary = _calculateSummary(items);
    final currencySymbol = ref.watch(currencyFormatterProvider).currency.symbol;

    return Container(
      key: const Key(ItemizedSplitTestIds.summaryFooter),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Summary cards for all participants
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _participants.map((p) {
                  final amount = summary[p.id] ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _SummaryCard(
                      label: p.isMe ? 'You pay' : '${p.name} pays',
                      amount: amount,
                      color: p.isMe
                          ? theme.colorScheme.primary
                          : theme.colorScheme.secondary,
                      currencySymbol: currencySymbol,
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key(ItemizedSplitTestIds.confirmButton),
              onPressed: () => _confirmSplit(summary),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('Confirm Split'),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, int> _calculateSummary(List<ReceiptItem> items) {
    // Use the receipt's built-in calculation
    if (_receipt != null) {
      return _receipt!.calculateParticipantTotals(_participants);
    }
    return {};
  }

  void _confirmSplit(Map<String, int> summary) {
    // Get currency symbol from locale settings
    final currencySymbol = ref.read(currencyFormatterProvider).currency.symbol;

    // Get items from receipt
    final items = _receipt?.items ?? [];

    // Calculate total amount from all items
    final totalPaise =
        _receipt?.grandTotalPaise ??
        items.fold<int>(0, (sum, item) => sum + item.totalPricePaise);
    final totalAmount = totalPaise / 100;

    // Build description from vendor and item count
    final vendor = _receipt?.vendor ?? 'Receipt';
    final itemCount = items.length;
    final description = '$vendor ($itemCount items)';

    // Build itemized details for WhatsApp sharing
    final itemizedDetails = items
        .map(
          (item) => ItemizedSplitItem(
            name: item.name,
            pricePaise: item.totalPricePaise,
            participantIds: item.assignedParticipantIds.isEmpty
                ? _participants
                      .map((p) => p.id)
                      .toSet() // Split among all
                : item.assignedParticipantIds,
          ),
        )
        .toList();

    // Create the result object for sharing
    final result = ItemizedSplitResult(
      totalAmount: totalAmount,
      description: description,
      summary: summary,
      vendor: _receipt?.vendor,
      orderId: _receipt?.orderId,
      itemizedDetails: itemizedDetails,
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Split Confirmed!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _participants.map((p) {
            final amount = summary[p.id] ?? 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '${p.isMe ? "You" : p.name}: $currencySymbol${(amount / 100).toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: p.isMe ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            );
          }).toList(),
        ),
        actions: [
          // Copy to clipboard button
          TextButton.icon(
            onPressed: () {
              final message = result.generateWhatsAppMessage(
                _participants,
                currencySymbol: currencySymbol,
              );
              Clipboard.setData(ClipboardData(text: message));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Summary copied! Paste in WhatsApp'),
                ),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy'),
          ),
          FilledButton(
            onPressed: () {
              // Close dialog
              Navigator.of(dialogContext).pop();
              // Return the split result to parent screen
              if (mounted && Navigator.of(context).canPop()) {
                Navigator.of(context).pop(result);
              }
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showQuickAssignMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.call_split),
              title: const Text('Split all equally'),
              subtitle: const Text('Everyone pays their share'),
              onTap: () {
                ref.read(receiptItemsProvider.notifier).setAllSplit();
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ..._participants.map(
              (p) => ListTile(
                leading: Icon(p.isMe ? Icons.person : Icons.people),
                title: Text('All items for ${p.isMe ? "me" : p.name}'),
                onTap: () {
                  ref
                      .read(receiptItemsProvider.notifier)
                      .setAllToParticipant(p.id);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Item tile with multi-participant toggle chips
class _MultiParticipantItemTile extends StatelessWidget {
  final ReceiptItem item;
  final List<ItemParticipant> participants;
  final ValueChanged<String> onParticipantToggled;

  const _MultiParticipantItemTile({
    required this.item,
    required this.participants,
    required this.onParticipantToggled,
  });

  Color _getParticipantColor(int index, ThemeData theme) {
    final colors = [
      theme.colorScheme.primary,
      theme.colorScheme.secondary,
      theme.colorScheme.tertiary,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      key: Key(ItemizedSplitTestIds.itemCardId(item.id)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item name and price
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (item.quantity > 1)
                        Text(
                          '${item.quantity} × ${item.formattedUnitPrice}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  item.formattedPrice,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Split status indicator
            if (item.isSplitAmongAll)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '↔ Split among all',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.tertiary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            // Participant toggle chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < participants.length; i++)
                  _ParticipantChip(
                    participant: participants[i],
                    isSelected: item.isAssignedTo(participants[i].id),
                    color: _getParticipantColor(i, theme),
                    onTap: () => onParticipantToggled(participants[i].id),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Chip for toggling participant assignment
class _ParticipantChip extends StatelessWidget {
  final ItemParticipant participant;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _ParticipantChip({
    required this.participant,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key(ItemizedSplitTestIds.participantChipId(participant.id)),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade400,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(Icons.check, size: 14, color: Colors.white),
              ),
            Text(
              participant.isMe ? 'Me' : participant.name,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Summary card showing total for each person
class _SummaryCard extends StatelessWidget {
  final String label;
  final int amount;
  final Color color;
  final String currencySymbol;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.color,
    this.currencySymbol = '₹',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$currencySymbol${(amount / 100).toStringAsFixed(2)}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}
