import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../application/providers/bill_split_providers.dart';
import '../../domain/models/bill_split_models.dart';
import '../../domain/models/split_result.dart';
import '../../../money/application/providers/money_provider.dart';
import '../../../money/application/services/expense_service.dart';
import 'itemized_split_screen.dart';

/// Test IDs for Playwright/Patrol testing
class BillSplitTestIds {
  static const String screen = 'bill-split-screen';
  static const String descriptionInput = 'bill-description-input';
  static const String amountInput = 'bill-amount-input';
  static const String saveButton = 'bill-save-button';
  static const String newButton = 'bill-new-button';
  static const String participantsSection = 'bill-participants-section';
  static const String paidBySection = 'bill-paid-by-section';
  static const String splitOptionSection = 'bill-split-option-section';
  static const String splitByItemsButton = 'bill-split-by-items-button';
  static const String shareButton = 'bill-share-button';
  static const String copyButton = 'bill-copy-button';
  static const String resultView = 'bill-result-view';
}

/// Splitwise-style bill splitting screen
class BillSplitScreen extends ConsumerStatefulWidget {
  const BillSplitScreen({super.key});

  @override
  ConsumerState<BillSplitScreen> createState() => _BillSplitScreenState();
}

class _BillSplitScreenState extends ConsumerState<BillSplitScreen> {
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  bool _showResult = false;
  bool _isSaving = false;
  PaidBy _paidBy = PaidBy.you;
  SplitOption _splitOption = SplitOption.equalSplit;

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _calculateAndSave() async {
    if (_amountController.text.isEmpty) return;

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) return;

    final participants = ref.read(selectedParticipantsProvider);
    if (participants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one person to split with')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final controller = ref.read(billSplitControllerProvider);
      controller.createSimpleBill(
        vendor: _descriptionController.text.isNotEmpty
            ? _descriptionController.text
            : null,
        date: DateTime.now(),
        totalAmount: amount,
      );
      final splitResult = controller.calculateSplitWithOptions(
        paidBy: _paidBy,
        splitOption: _splitOption,
      );

      // Persist to database as a transaction
      if (splitResult != null) {
        await _persistExpenseToDb(amount, splitResult);

        // Save to split history for reference
        await controller.saveSplitToHistory(splitResult);
      }

      setState(() => _showResult = true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Persist the bill split as an expense transaction to the database
  Future<void> _persistExpenseToDb(
    double amount,
    SplitResult splitResult,
  ) async {
    final moneyController = ref.read(moneyControllerProvider);
    final amountCents = (amount * 100).round();
    final description = _descriptionController.text.isNotEmpty
        ? _descriptionController.text
        : 'Bill Split';

    // Determine if current user owes money (expense) or is owed (they pay you)
    final bool isExpense = _splitOption != SplitOption.theyOweAll;

    if (isExpense) {
      // Save as expense - user paid or owes
      final result = await moneyController.addExpense(
        accountId: 'acc1', // Default account
        timestamp: DateTime.now(),
        amountCents: amountCents,
        description:
            '$description (Split with ${splitResult.participantCount} people)',
        category: 'Food & Drink', // Default category for bill splits
        tags: ['bill-split'],
      );

      if (result != null && mounted) {
        _showBudgetFeedback(result);
      }
    }
  }

  void _showBudgetFeedback(SaveExpenseResult result) {
    if (result.isBudgetExceeded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⚠️ Budget for ${result.budget?.tag ?? 'category'} exceeded!',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    } else if (result.hasBudget && result.budget != null) {
      final percentUsed = result.budget!.percentageUsed * 100;
      if (percentUsed >= 80) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '⚠️ ${percentUsed.toStringAsFixed(0)}% of ${result.budget!.tag} budget used',
            ),
            backgroundColor: Colors.amber,
          ),
        );
      }
    }
  }

  void _resetSplit() {
    ref.read(billSplitControllerProvider).reset();
    _descriptionController.clear();
    _amountController.clear();
    setState(() {
      _showResult = false;
      _paidBy = PaidBy.you;
      _splitOption = SplitOption.equalSplit;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      key: const Key(BillSplitTestIds.screen),
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Add expense'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (!_showResult)
            _isSaving
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : TextButton(
                    key: const Key(BillSplitTestIds.saveButton),
                    onPressed: _calculateAndSave,
                    child: Text(
                      'Save',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
          else
            TextButton(
              key: const Key(BillSplitTestIds.newButton),
              onPressed: _resetSplit,
              child: const Text('New'),
            ),
        ],
      ),
      body: _showResult ? _buildResultView() : _buildInputView(),
    );
  }

  Widget _buildInputView() {
    final theme = Theme.of(context);
    final selectedParticipants = ref.watch(selectedParticipantsProvider);

    return SingleChildScrollView(
      child: Column(
        children: [
          // Amount input section (Splitwise style - large centered)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            child: Column(
              children: [
                // Description input
                TextField(
                  key: const Key(BillSplitTestIds.descriptionInput),
                  controller: _descriptionController,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                  decoration: InputDecoration(
                    hintText: 'Enter a description',
                    hintStyle: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                    border: InputBorder.none,
                    prefixIcon: Icon(
                      Icons.receipt_long,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Amount input - large prominent display
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '₹',
                      style: theme.textTheme.displayMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IntrinsicWidth(
                      child: TextField(
                        key: const Key(BillSplitTestIds.amountInput),
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}'),
                          ),
                        ],
                        textAlign: TextAlign.center,
                        style: theme.textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          hintText: '0.00',
                          hintStyle: theme.textTheme.displayMedium?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                          border: InputBorder.none,
                          constraints: const BoxConstraints(minWidth: 100),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // "With you and:" section (Splitwise style)
          _buildParticipantsSection(theme, selectedParticipants),

          const Divider(height: 1),

          // "Paid by" section
          _buildPaidBySection(theme, selectedParticipants),

          const Divider(height: 1),

          // Split option section
          _buildSplitOptionSection(theme, selectedParticipants),

          const Divider(height: 1),

          // Upload receipt for itemized split
          _buildUploadReceiptSection(theme, selectedParticipants),
        ],
      ),
    );
  }

  Widget _buildUploadReceiptSection(
    ThemeData theme,
    List<Participant> selectedParticipants,
  ) {
    return InkWell(
      key: const Key(BillSplitTestIds.splitByItemsButton),
      onTap: selectedParticipants.isNotEmpty
          ? () => _openItemizedSplit(
              selectedParticipants.map((p) => p.name).toList(),
            )
          : () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Add a participant first to split items'),
                ),
              );
            },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.receipt_long,
                color: theme.colorScheme.tertiary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Split by items',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'Upload receipt & assign items to people',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.camera_alt, color: theme.colorScheme.tertiary),
          ],
        ),
      ),
    );
  }

  void _openItemizedSplit(List<String> participantNames) async {
    final result = await Navigator.of(context).push<ItemizedSplitResult>(
      MaterialPageRoute(
        builder: (context) =>
            ItemizedSplitScreen(participantNames: participantNames),
      ),
    );

    // Auto-fill amount and description if split was confirmed
    if (result != null && mounted) {
      setState(() {
        _descriptionController.text = result.description;
        _amountController.text = result.totalAmount.toStringAsFixed(2);
      });
    }
  }

  Widget _buildPaidBySection(
    ThemeData theme,
    List<Participant> selectedParticipants,
  ) {
    return InkWell(
      key: const Key(BillSplitTestIds.paidBySection),
      onTap: () => _showPaidByPicker(context, selectedParticipants),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.account_balance_wallet,
                color: theme.colorScheme.secondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Paid by',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    _paidBy == PaidBy.you
                        ? 'You'
                        : selectedParticipants.isNotEmpty
                        ? selectedParticipants.first.name
                        : 'Select a friend',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: theme.colorScheme.outline),
          ],
        ),
      ),
    );
  }

  void _showPaidByPicker(BuildContext context, List<Participant> participants) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Who paid?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: const Icon(Icons.person, color: Colors.white),
              ),
              title: const Text('You'),
              trailing: _paidBy == PaidBy.you
                  ? Icon(
                      Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () {
                setState(() => _paidBy = PaidBy.you);
                Navigator.pop(context);
              },
            ),
            if (participants.isNotEmpty) ...[
              const Divider(),
              ...participants.map(
                (p) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    child: Text(p.initials),
                  ),
                  title: Text(p.name),
                  trailing: _paidBy == PaidBy.friend
                      ? Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () {
                    setState(() => _paidBy = PaidBy.friend);
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSplitOptionSection(
    ThemeData theme,
    List<Participant> selectedParticipants,
  ) {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final participantCount = selectedParticipants.length + 1; // +1 for "you"

    String getAmountText() {
      if (amount <= 0 || selectedParticipants.isEmpty) return '';
      switch (_splitOption) {
        case SplitOption.equalSplit:
          return '₹${(amount / participantCount).toStringAsFixed(2)}/person';
        case SplitOption.youOweAll:
          return 'You owe ₹${amount.toStringAsFixed(2)}';
        case SplitOption.theyOweAll:
          return 'They owe ₹${amount.toStringAsFixed(2)}';
      }
    }

    return InkWell(
      key: const Key(BillSplitTestIds.splitOptionSection),
      onTap: () => _showSplitOptionPicker(context),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.call_split,
                color: theme.colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _splitOption.displayName,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (getAmountText().isNotEmpty)
                    Text(
                      getAmountText(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: theme.colorScheme.outline),
          ],
        ),
      ),
    );
  }

  void _showSplitOptionPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'How to split?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            ...SplitOption.values.map(
              (option) => ListTile(
                leading: Icon(
                  option == SplitOption.equalSplit
                      ? Icons.balance
                      : option == SplitOption.youOweAll
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(option.displayName),
                subtitle: Text(_getOptionDescription(option)),
                trailing: _splitOption == option
                    ? Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  setState(() => _splitOption = option);
                  Navigator.pop(context);
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _getOptionDescription(SplitOption option) {
    switch (option) {
      case SplitOption.equalSplit:
        return 'Everyone pays their fair share';
      case SplitOption.youOweAll:
        return 'You owe the entire amount';
      case SplitOption.theyOweAll:
        return 'They owe you the entire amount';
    }
  }

  String _getResultSectionTitle(SplitResult result) {
    switch (result.splitOption) {
      case SplitOption.equalSplit:
        return 'Each person owes';
      case SplitOption.youOweAll:
        return result.paidBy == PaidBy.friend ? 'Paid by' : 'Summary';
      case SplitOption.theyOweAll:
        return result.splits.length == 1 ? 'Owes you' : 'They owe you';
    }
  }

  String _getResultSubtitle(SplitResult result) {
    final paidByText = result.paidBy == PaidBy.you ? 'You paid' : 'Friend paid';
    switch (result.splitOption) {
      case SplitOption.equalSplit:
        return '$paidByText • Split among ${result.participantCount + 1} people';
      case SplitOption.youOweAll:
        return '$paidByText • You owe full amount';
      case SplitOption.theyOweAll:
        return '$paidByText • They owe full amount';
    }
  }

  Widget _buildParticipantsSection(
    ThemeData theme,
    List<Participant> selectedParticipants,
  ) {
    return InkWell(
      key: const Key(BillSplitTestIds.participantsSection),
      onTap: () => _showParticipantPicker(context),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // "With you and:" label
            Text(
              'With you and:',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            // Participant avatars
            Expanded(
              child: selectedParticipants.isEmpty
                  ? Text(
                      'Add people',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  : _buildParticipantAvatars(theme, selectedParticipants),
            ),
            Icon(Icons.chevron_right, color: theme.colorScheme.outline),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantAvatars(
    ThemeData theme,
    List<Participant> participants,
  ) {
    const maxVisible = 4;
    final visibleParticipants = participants.take(maxVisible).toList();
    final overflow = participants.length - maxVisible;

    return Row(
      children: [
        ...visibleParticipants.map(
          (p) => Padding(
            padding: const EdgeInsets.only(right: 4),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                p.initials,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        if (overflow > 0)
          CircleAvatar(
            radius: 16,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            child: Text(
              '+$overflow',
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        const SizedBox(width: 8),
        Text(
          participants.length == 1
              ? participants.first.name
              : '${participants.length} people',
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }

  void _showParticipantPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const _ParticipantPickerSheet(),
    );
  }

  Widget _buildResultView() {
    final theme = Theme.of(context);
    final splitResult = ref.watch(currentSplitResultProvider);

    if (splitResult == null) {
      return const Center(child: Text('No split calculated'));
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // Success header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            color: theme.colorScheme.primaryContainer,
            child: Column(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  splitResult.bill.formattedTotal,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                Text(
                  splitResult.bill.vendor ?? 'Expense',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getResultSubtitle(splitResult),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer.withValues(
                      alpha: 0.7,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Individual splits
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getResultSectionTitle(splitResult),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (splitResult.splitOption == SplitOption.youOweAll)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 12),
                    child: Card(
                      color: theme.colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.arrow_upward,
                              color: theme.colorScheme.onErrorContainer,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'You owe ${splitResult.bill.formattedTotal}',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.onErrorContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 12),
                ...splitResult.splits.map(
                  (split) =>
                      _SplitResultTile(split: split, splitResult: splitResult),
                ),
              ],
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                FilledButton.icon(
                  onPressed: () => _shareAll(splitResult),
                  icon: const Icon(Icons.share),
                  label: const Text('Share with everyone'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _copySummary(splitResult),
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy summary'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _shareAll(SplitResult splitResult) {
    final message = splitResult.generateSummaryMessage();
    Share.share(
      message,
      subject: 'Bill Split - ${splitResult.bill.vendor ?? "Expense"}',
    );
  }

  void _copySummary(SplitResult splitResult) {
    final message = splitResult.generateSummaryMessage();
    Clipboard.setData(ClipboardData(text: message));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
  }
}

/// Bottom sheet for selecting participants
class _ParticipantPickerSheet extends ConsumerStatefulWidget {
  const _ParticipantPickerSheet();

  @override
  ConsumerState<_ParticipantPickerSheet> createState() =>
      _ParticipantPickerSheetState();
}

class _ParticipantPickerSheetState
    extends ConsumerState<_ParticipantPickerSheet> {
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

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'Add people',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),

          // Selected chips
          if (selectedParticipants.isNotEmpty)
            SizedBox(
              height: 50,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: selectedParticipants.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final p = selectedParticipants[index];
                  return Chip(
                    avatar: CircleAvatar(
                      backgroundColor: theme.colorScheme.primary,
                      child: Text(
                        p.initials,
                        style: TextStyle(
                          color: theme.colorScheme.onPrimary,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    label: Text(p.name),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () {
                      ref
                          .read(billSplitControllerProvider)
                          .removeParticipant(p.id);
                    },
                  );
                },
              ),
            ),

          // Search
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),

          // Contact list
          Expanded(
            child: contactsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (contacts) => ListView.builder(
                controller: scrollController,
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
                    subtitle: Text(contact.phone ?? ''),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle,
                            color: theme.colorScheme.primary,
                          )
                        : Icon(
                            Icons.circle_outlined,
                            color: theme.colorScheme.outline,
                          ),
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Result tile for each participant
class _SplitResultTile extends StatelessWidget {
  final ParticipantSplit split;
  final SplitResult splitResult;

  const _SplitResultTile({required this.split, required this.splitResult});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            split.participant.initials,
            style: TextStyle(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          split.participant.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              split.formattedAmount,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.send, color: theme.colorScheme.primary),
              onPressed: () => _remind(context),
              tooltip: 'Send reminder',
            ),
          ],
        ),
      ),
    );
  }

  void _remind(BuildContext context) {
    final message = splitResult.generateShareMessage(split);
    Share.share(message, subject: 'Payment reminder');
  }
}
