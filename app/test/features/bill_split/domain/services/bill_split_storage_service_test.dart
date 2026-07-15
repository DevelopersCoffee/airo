import 'package:airo_app/features/bill_split/domain/models/bill_split_models.dart';
import 'package:airo_app/features/bill_split/domain/models/split_result.dart';
import 'package:airo_app/features/bill_split/domain/services/bill_split_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('persists and loads split history', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = LocalBillSplitStorage(preferences: prefs);
    final split = _splitResult('split-1');

    await storage.saveSplitHistory(split);

    expect(prefs.getString('bill_split_history'), isNotNull);
    final history = await storage.getSplitHistory();
    expect(history, hasLength(1));
    expect(history.single.id, 'split-1');
    expect(history.single.bill.vendor, 'Cafe 1');
    expect(history.single.splits.single.participant.name, 'Friend 1');
  });

  test('trims split history to 100 most recent entries', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = LocalBillSplitStorage(preferences: prefs);

    for (var i = 0; i < 105; i++) {
      await storage.saveSplitHistory(_splitResult('split-$i', index: i));
    }

    final history = await storage.getSplitHistory();
    expect(history, hasLength(100));
    expect(history.first.id, 'split-104');
    expect(history.last.id, 'split-5');
  });

  test('persists and trims bill history to 50 most recent entries', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = LocalBillSplitStorage(preferences: prefs);

    for (var i = 0; i < 55; i++) {
      await storage.saveBill(_bill('bill-$i', index: i));
    }

    expect(prefs.getString('bill_history'), isNotNull);
    final history = await storage.getBillHistory();
    expect(history, hasLength(50));
    expect(history.first.id, 'bill-54');
    expect(history.last.id, 'bill-5');
  });

  test('drops oversized split history before persisting raw JSON', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = LocalBillSplitStorage(
      preferences: prefs,
      maxPreferenceValueBytes: 1024,
    );

    await storage.saveSplitHistory(_splitResult('split-small'));
    expect(prefs.getString('bill_split_history'), isNotNull);
    await storage.saveSplitHistory(
      _splitResult(
        'split-large',
        note: 'split ${List.filled(2048, 'x').join()}',
      ),
    );

    expect(prefs.getString('bill_split_history'), isNull);
    expect(await storage.getSplitHistory(), isEmpty);
  });

  test('drops oversized bill history before persisting raw JSON', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = LocalBillSplitStorage(
      preferences: prefs,
      maxPreferenceValueBytes: 256,
    );

    await storage.saveBill(_bill('bill-small'));
    expect(prefs.getString('bill_history'), isNotNull);
    await storage.saveBill(
      _bill('bill-large', vendor: 'Vendor ${List.filled(256, 'x').join()}'),
    );

    expect(prefs.getString('bill_history'), isNull);
    expect(await storage.getBillHistory(), isEmpty);
  });

  test('clears both guarded history keys', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = LocalBillSplitStorage(preferences: prefs);

    await storage.saveSplitHistory(_splitResult('split-1'));
    await storage.saveBill(_bill('bill-1'));
    await storage.clearHistory();

    expect(prefs.getString('bill_split_history'), isNull);
    expect(prefs.getString('bill_history'), isNull);
  });
}

SplitResult _splitResult(String id, {int index = 1, String? note}) {
  final participant = Participant(id: 'friend-$index', name: 'Friend $index');
  return SplitResult(
    id: id,
    bill: _bill('bill-$index', index: index),
    splits: [
      ParticipantSplit(participant: participant, amountPaise: 1200 + index),
    ],
    createdAt: DateTime.utc(2026, 1, 1).add(Duration(days: index)),
    note: note,
  );
}

Bill _bill(String id, {int index = 1, String? vendor}) {
  return Bill(
    id: id,
    vendor: vendor ?? 'Cafe $index',
    date: DateTime.utc(2026, 1, 1).add(Duration(days: index)),
    items: const [],
    subtotalPaise: 1200 + index,
    totalPaise: 1200 + index,
    createdAt: DateTime.utc(2026, 1, 1).add(Duration(days: index)),
  );
}
