import 'package:feature_coins_core/feature_coins_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers/dashboard_providers.dart';
import '../../application/providers/expense_providers.dart';

enum _CaptureStep { amount, category, note }

/// Three-step frictionless capture: amount → category → optional note.
class NfcQuickExpenseCaptureScreen extends ConsumerStatefulWidget {
  const NfcQuickExpenseCaptureScreen({super.key});

  @override
  ConsumerState<NfcQuickExpenseCaptureScreen> createState() =>
      _NfcQuickExpenseCaptureScreenState();
}

class _NfcQuickExpenseCaptureScreenState
    extends ConsumerState<NfcQuickExpenseCaptureScreen> {
  _CaptureStep _step = _CaptureStep.amount;
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _amountError;
  String? _categoryId;
  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _cancel() async {
    if (_isSaving) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  void _continueFromAmount() {
    final service = ref.read(nfcQuickExpenseCaptureServiceProvider);
    final cents = service.parseAmountCents(_amountController.text);
    if (cents == null) {
      setState(() => _amountError = 'Enter a valid amount');
      return;
    }
    setState(() {
      _amountError = null;
      _step = _CaptureStep.category;
    });
  }

  void _selectCategory(String id) {
    setState(() {
      _categoryId = id;
      _step = _CaptureStep.note;
    });
  }

  Future<void> _finish({required bool save}) async {
    if (_isSaving) return;
    if (!save) {
      await _cancel();
      return;
    }

    final service = ref.read(nfcQuickExpenseCaptureServiceProvider);
    final amountCents = service.parseAmountCents(_amountController.text);
    final draft = NfcQuickExpenseCaptureDraft(
      amountCents: amountCents,
      categoryId: _categoryId,
      note: _noteController.text,
    );

    final accounts = await ref.read(expenseAccountOptionsProvider.future);
    final accountId = accounts.firstWhere((a) => a.isDefault, orElse: () => accounts.first).id;

    setState(() => _isSaving = true);
    final useCase = ref.read(completeNfcQuickExpenseCaptureUseCaseProvider);
    final result = await useCase.execute(
      draft: draft,
      accountId: accountId,
      userConfirmed: true,
    );

    if (!mounted) return;

    if (result?.error != null) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result!.error!)),
      );
      return;
    }

    ref.invalidate(recentExpensesProvider);
    ref.invalidate(allExpensesProvider);
    ref.invalidate(spentTodayProvider);
    ref.invalidate(spentThisMonthProvider);
    ref.invalidate(dashboardDataProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense saved')),
      );
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSaving,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _cancel();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _isSaving ? null : _cancel,
          ),
          title: const Text('Quick capture'),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: switch (_step) {
              _CaptureStep.amount => _AmountStep(
                  controller: _amountController,
                  errorText: _amountError,
                  onContinue: _continueFromAmount,
                ),
              _CaptureStep.category => _CategoryStep(
                  selectedId: _categoryId,
                  onSelected: _selectCategory,
                ),
              _CaptureStep.note => _NoteStep(
                  controller: _noteController,
                  isSaving: _isSaving,
                  onDone: () => _finish(save: true),
                ),
            },
          ),
        ),
      ),
    );
  }
}

class _AmountStep extends StatelessWidget {
  const _AmountStep({
    required this.controller,
    required this.errorText,
    required this.onContinue,
  });

  final TextEditingController controller;
  final String? errorText;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'How much did you spend?',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        TextField(
          key: const ValueKey('nfc_capture_amount_field'),
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,₹]')),
          ],
          decoration: InputDecoration(
            hintText: '0',
            errorText: errorText,
            border: const OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onContinue(),
        ),
        const Spacer(),
        FilledButton(
          onPressed: onContinue,
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

class _CategoryStep extends StatelessWidget {
  const _CategoryStep({
    required this.selectedId,
    required this.onSelected,
  });

  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final options = NfcQuickExpenseCategories.options;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Choose a category',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            itemCount: options.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final option = options[index];
              return ListTile(
                key: ValueKey('nfc_capture_category_${option.id}'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: selectedId == option.id
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                title: Text(option.label),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onSelected(option.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _NoteStep extends StatelessWidget {
  const _NoteStep({
    required this.controller,
    required this.isSaving,
    required this.onDone,
  });

  final TextEditingController controller;
  final bool isSaving;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Add a note (optional)',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        TextField(
          key: const ValueKey('nfc_capture_note_field'),
          controller: controller,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Optional',
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onDone(),
        ),
        const Spacer(),
        FilledButton(
          onPressed: isSaving ? null : onDone,
          child: isSaving
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Done'),
        ),
      ],
    );
  }
}
