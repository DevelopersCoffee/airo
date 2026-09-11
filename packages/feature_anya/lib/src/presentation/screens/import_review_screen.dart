import 'package:core_ui/core_ui.dart';
import 'package:feature_anya_core/feature_anya_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/anya_providers.dart';

class ImportReviewScreen extends ConsumerWidget {
  const ImportReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(anyaSessionProvider);
    final program = session.pendingProgram;
    final validation = session.pendingValidation;
    if (program == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review import')),
        body: const EmptyStateWidget(
          title: 'Nothing to review',
          message: 'Import a PDF first.',
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Review extracted plan')),
      body: ListView(
        padding: AiroSpacing.paddingMd,
        children: [
          if (validation != null)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'We found ${validation.mealDaysDetected} days of meals.',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AiroSpacing.sm),
                  for (final line in validation.summaryLines) Text('· $line'),
                ],
              ),
            ),
          const SizedBox(height: AiroSpacing.md),
          if (program.rules.allowedFoods.isNotEmpty) ...[
            Text(
              'Foods to include',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AiroSpacing.sm),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final food in program.rules.allowedFoods)
                    Text('· $food'),
                ],
              ),
            ),
            const SizedBox(height: AiroSpacing.md),
          ],
          if (program.rules.avoidFoods.isNotEmpty) ...[
            Text(
              'Foods to avoid',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AiroSpacing.sm),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final food in program.rules.avoidFoods) Text('· $food'),
                ],
              ),
            ),
            const SizedBox(height: AiroSpacing.md),
          ],
          if (program.guidelines.isNotEmpty) ...[
            Text('Guidelines', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AiroSpacing.sm),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final line in program.guidelines) Text('· $line'),
                ],
              ),
            ),
            const SizedBox(height: AiroSpacing.md),
          ],
          for (final day in program.allDays) ...[
            Text(
              'Day ${day.dayNumber}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final slot in day.meals)
              AppCard(
                margin: const EdgeInsets.only(top: AiroSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${slot.time ?? ''} ${slot.type.label}'.trim(),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    for (final item in slot.items)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.name),
                        subtitle: Text(
                          item.quantityRaw.isEmpty
                              ? 'quantity missing'
                              : item.quantityRaw,
                        ),
                        trailing: PopupMenuButton<_FoodAction>(
                          tooltip: 'Edit food',
                          onSelected: (action) => _handleAction(
                            context: context,
                            ref: ref,
                            program: program,
                            day: day,
                            slot: slot,
                            item: item,
                            action: action,
                          ),
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: _FoodAction.edit,
                              child: Text('Edit'),
                            ),
                            PopupMenuItem(
                              value: _FoodAction.replace,
                              child: Text('Replace'),
                            ),
                            PopupMenuItem(
                              value: _FoodAction.remove,
                              child: Text('Remove'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: AiroSpacing.md),
          ],
          AppButton(
            label: 'Confirm plan',
            isExpanded: true,
            onPressed: () async {
              await ref
                  .read(anyaSessionProvider.notifier)
                  .confirmPendingProgram();
              if (context.mounted) context.go('/');
            },
          ),
        ],
      ),
    );
  }
}

enum _FoodAction { edit, replace, remove }

Future<void> _handleAction({
  required BuildContext context,
  required WidgetRef ref,
  required DietProgram program,
  required DietDay day,
  required MealSlot slot,
  required FoodItem item,
  required _FoodAction action,
}) async {
  final notifier = ref.read(anyaSessionProvider.notifier);
  switch (action) {
    case _FoodAction.remove:
      notifier.updatePendingProgram(
        _edit(program, day, slot, item, replacement: null),
      );
    case _FoodAction.edit:
      final edited = await _editDialog(context, item);
      if (edited == null) return;
      notifier.updatePendingProgram(
        _edit(program, day, slot, item, replacement: edited),
      );
    case _FoodAction.replace:
      final replacement = await _replaceDialog(context, ref, item);
      if (replacement == null) return;
      notifier.updatePendingProgram(
        _edit(program, day, slot, item, replacement: replacement),
      );
  }
}

DietProgram _edit(
  DietProgram program,
  DietDay day,
  MealSlot slot,
  FoodItem item, {
  FoodItem? replacement,
}) {
  return editProgramFoodItem(
    program: program,
    dayNumber: day.dayNumber,
    mealType: slot.type,
    time: slot.time,
    from: item,
    replacement: replacement,
  );
}

Future<FoodItem?> _editDialog(BuildContext context, FoodItem item) {
  return showDialog<FoodItem>(
    context: context,
    builder: (context) => _EditFoodDialog(item: item),
  );
}

Future<FoodItem?> _replaceDialog(
  BuildContext context,
  WidgetRef ref,
  FoodItem item,
) {
  final catalog = ref.read(anyaCatalogProvider);
  return showDialog<FoodItem>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Replace with catalog meal'),
      content: SizedBox(
        width: double.maxFinite,
        height: 360,
        child: ListView(
          children: [
            for (final meal in catalog)
              ListTile(
                title: Text(meal.name),
                onTap: () => Navigator.pop(
                  context,
                  FoodItem(name: meal.name, quantityRaw: item.quantityRaw),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _EditFoodDialog extends StatefulWidget {
  const _EditFoodDialog({required this.item});

  final FoodItem item;

  @override
  State<_EditFoodDialog> createState() => _EditFoodDialogState();
}

class _EditFoodDialogState extends State<_EditFoodDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.item.name,
  );
  late final TextEditingController _quantity = TextEditingController(
    text: widget.item.quantityRaw,
  );

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit food'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: _quantity,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                helperText: 'Kept as typed. Unclear values like 1k stay 1k.',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(
              context,
              widget.item.copyWith(
                name: _name.text.trim(),
                quantityRaw: _quantity.text.trim(),
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
