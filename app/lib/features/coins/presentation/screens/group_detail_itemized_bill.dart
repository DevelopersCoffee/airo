import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bill_split/domain/models/receipt_item.dart';
import '../../../bill_split/presentation/screens/itemized_split_screen.dart';
import '../../../../core/utils/locale_settings.dart';
import '../../application/providers/group_providers.dart';
import '../../application/providers/settlement_providers.dart';
import '../../application/providers/split_providers.dart';
import '../../application/use_cases/add_split_use_case.dart';
import '../../domain/entities/split_entry.dart';

/// Opens receipt OCR itemized split for the super-app Coins profile only.
/// Not linked from the standalone Airo Coin shell (`pubspec_coins.yaml`).
Future<void> openGroupItemizedBillSplit(
  BuildContext context,
  WidgetRef ref,
  String groupId,
) async {
  try {
    final members = await ref.read(groupMembersProvider(groupId).future);
    if (!context.mounted) return;
    if (members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add group members before splitting')),
      );
      return;
    }

    final participants = members
        .map(
          (member) => ItemParticipant(
            id: member.userId,
            name: member.displayName,
            avatarUrl: member.avatarUrl,
          ),
        )
        .toList();

    final result = await Navigator.push<ItemizedSplitResult>(
      context,
      MaterialPageRoute(
        builder: (_) => ItemizedSplitScreen(initialParticipants: participants),
      ),
    );
    if (!context.mounted || result == null) return;

    await _saveItemizedSplit(context, ref, groupId, result);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Failed to open bill upload: $e')));
  }
}

Future<void> _saveItemizedSplit(
  BuildContext context,
  WidgetRef ref,
  String groupId,
  ItemizedSplitResult result,
) async {
  final summary = result.summary;
  final totalAmountCents = summary.values.fold<int>(
    0,
    (sum, amount) => sum + amount,
  );
  if (summary.isEmpty || totalAmountCents <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No split amounts found in this bill')),
    );
    return;
  }

  final payerId = summary.keys.first;
  final itemizedItems = _buildItemizedInputs(result, totalAmountCents);

  final saveResult = await ref
      .read(addSplitUseCaseProvider)
      .execute(
        AddSplitParams(
          groupId: groupId,
          description: result.description,
          totalAmountCents: totalAmountCents,
          currencyCode: ref.read(currencyFormatterProvider).currency.code,
          paidByUserId: payerId,
          splitType: SplitType.itemized,
          participantIds: summary.keys.toList(growable: false),
          itemizedItems: itemizedItems,
        ),
      );

  if (!context.mounted) return;
  if (saveResult.error != null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(saveResult.error!)));
    return;
  }

  ref.invalidate(groupExpensesProvider(groupId));
  ref.invalidate(groupBalanceSummaryProvider(groupId));
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Itemized bill saved to Coins')));
}

List<ItemizedSplitInput> _buildItemizedInputs(
  ItemizedSplitResult result,
  int totalAmountCents,
) {
  final inputs = <ItemizedSplitInput>[];
  final itemOnlyTotals = <String, int>{
    for (final id in result.summary.keys) id: 0,
  };

  for (var i = 0; i < result.itemizedDetails.length; i++) {
    final item = result.itemizedDetails[i];
    final itemId = 'item_${i}_${_slugForItemId(item.name)}';
    inputs.add(
      ItemizedSplitInput(
        itemId: itemId,
        name: item.name,
        amountCents: item.pricePaise,
        participantIds: item.participantIds.toList(growable: false),
      ),
    );

    final participantIds = item.participantIds.toList(growable: false);
    if (participantIds.isEmpty) continue;
    final share = item.pricePaise ~/ participantIds.length;
    final remainder = item.pricePaise % participantIds.length;
    for (var index = 0; index < participantIds.length; index++) {
      itemOnlyTotals[participantIds[index]] =
          (itemOnlyTotals[participantIds[index]] ?? 0) +
          share +
          (index < remainder ? 1 : 0);
    }
  }

  var currentTotal = inputs.fold<int>(0, (sum, item) => sum + item.amountCents);
  if (currentTotal < totalAmountCents) {
    for (final entry in result.summary.entries) {
      final adjustment = entry.value - (itemOnlyTotals[entry.key] ?? 0);
      if (adjustment <= 0) continue;
      inputs.add(
        ItemizedSplitInput(
          itemId: 'fees_${entry.key}',
          name: 'Fees and adjustments',
          amountCents: adjustment,
          participantIds: [entry.key],
        ),
      );
      currentTotal += adjustment;
    }
  }

  return inputs;
}

String _slugForItemId(String name) {
  final slug = name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return slug.isEmpty ? 'line' : slug;
}
