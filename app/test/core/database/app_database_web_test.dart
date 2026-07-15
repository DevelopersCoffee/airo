import 'package:airo_app/core/database/app_database_web.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web database store supports deterministic map operations', () async {
    final db = AppDatabase.forTesting(null);
    final transactions = await db.transactionEntriesBox;

    await transactions.put('txn-1', <String, Object?>{
      'amountCents': 1200,
      'description': 'Coffee',
    });

    expect(transactions.name, 'transaction_entries');
    expect(transactions.length, 1);
    expect(transactions.containsKey('txn-1'), isTrue);
    expect(transactions.get('txn-1'), containsPair('description', 'Coffee'));

    final copy = transactions.get('txn-1')!;
    copy['description'] = 'Mutated outside store';

    expect(transactions.get('txn-1'), containsPair('description', 'Coffee'));
  });

  test('deleteAllData clears all named web stores', () async {
    final db = AppDatabase.forTesting(null);
    final transactions = await db.transactionEntriesBox;
    final outbox = await db.outboxEntriesBox;

    await transactions.put('txn-1', <String, Object?>{'amountCents': 1200});
    await outbox.put('op-1', <String, Object?>{'status': 'pending'});

    await db.deleteAllData();

    expect(transactions.length, 0);
    expect(outbox.length, 0);
  });

  test('close clears singleton web database state', () async {
    final db = AppDatabase();
    final metadata = await db.syncMetadataBox;
    await metadata.put('last-sync', <String, Object?>{'status': 'synced'});

    await db.close();

    final reopened = AppDatabase();
    final reopenedMetadata = await reopened.syncMetadataBox;
    expect(reopenedMetadata.length, 0);
  });
}
