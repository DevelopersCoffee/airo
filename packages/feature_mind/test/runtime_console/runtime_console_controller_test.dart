import 'package:feature_mind/src/runtime/models/log_models.dart';
import 'package:feature_mind/src/runtime_console/runtime_console_controller.dart';
import 'package:feature_mind/src/runtime_console/runtime_console_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_operation_log_port.dart';

void main() {
  group('paging', () {
    test('loadInitial fetches count and exactly one page, never the whole log', () async {
      final port = FakeOperationLogPort(opCount: 12481);
      final controller = RuntimeConsoleController(log: port, pageSize: 50);

      await controller.loadInitial();

      expect(controller.totalCount, 12481);
      expect(controller.loadedCount, 50);
      expect(port.rangeCalls, [(offset: 0, limit: 50)]);
      // The whole point of `range`: a page, never the 12,481-row log.
      for (final call in port.rangeCalls) {
        expect(call.limit, lessThan(200));
      }
    });

    test('loadMore fetches the next page and appends, without re-fetching what is loaded', () async {
      final port = FakeOperationLogPort(opCount: 12481);
      final controller = RuntimeConsoleController(log: port, pageSize: 50);
      await controller.loadInitial();

      await controller.loadMore();

      expect(controller.loadedCount, 100);
      expect(port.rangeCalls, [
        (offset: 0, limit: 50),
        (offset: 50, limit: 50),
      ]);
    });

    test('hasMore is false once every row up to totalCount is loaded', () async {
      final port = FakeOperationLogPort(opCount: 120);
      final controller = RuntimeConsoleController(log: port, pageSize: 50);
      await controller.loadInitial();
      expect(controller.hasMore, isTrue);

      await controller.loadMore();
      expect(controller.hasMore, isTrue);
      expect(controller.loadedCount, 100);

      await controller.loadMore();
      expect(controller.hasMore, isFalse);
      expect(controller.loadedCount, 120);
    });

    test('loadMore is a no-op once hasMore is false', () async {
      final port = FakeOperationLogPort(opCount: 10);
      final controller = RuntimeConsoleController(log: port, pageSize: 50);
      await controller.loadInitial();
      expect(controller.hasMore, isFalse);

      await controller.loadMore();

      expect(port.rangeCalls.length, 1);
    });

    test('loadInitial only does anything on the first call', () async {
      final port = FakeOperationLogPort(opCount: 200);
      final controller = RuntimeConsoleController(log: port, pageSize: 50);

      await controller.loadInitial();
      await controller.loadInitial();

      expect(port.rangeCalls.length, 1);
    });
  });

  group('sorting', () {
    test('sortBy sequence ascending reorders the loaded page without a re-fetch', () async {
      final port = FakeOperationLogPort(opCount: 500);
      final controller = RuntimeConsoleController(log: port, pageSize: 20);
      await controller.loadInitial();
      expect(controller.rows.first.sequence, 500); // descending by default

      controller.sortBy(RuntimeConsoleSortField.sequence); // flip to ascending

      expect(controller.rows.first.sequence, lessThan(controller.rows.last.sequence));
      expect(port.rangeCalls.length, 1, reason: 'sorting must not trigger a fetch');
    });

    test('sortBy a new field defaults to descending', () async {
      final port = FakeOperationLogPort(opCount: 200);
      final controller = RuntimeConsoleController(log: port, pageSize: 20);
      await controller.loadInitial();

      controller.sortBy(RuntimeConsoleSortField.device);

      expect(controller.sortField, RuntimeConsoleSortField.device);
      expect(controller.sortDirection, RuntimeConsoleSortDirection.descending);
      final devices = controller.rows.map((op) => op.deviceName).toList();
      expect(devices, orderedEquals([...devices]..sort((a, b) => b.compareTo(a))));
    });

    test('sortBy kind groups rows by op type', () async {
      final port = FakeOperationLogPort(opCount: 200);
      final controller = RuntimeConsoleController(log: port, pageSize: 100);
      await controller.loadInitial();

      controller.sortBy(RuntimeConsoleSortField.kind);

      final kinds = controller.rows.map((op) => op.kind.name).toList();
      expect(kinds, orderedEquals([...kinds]..sort((a, b) => b.compareTo(a))));
    });

    test('filterByKind narrows rows to a single op type', () async {
      final port = FakeOperationLogPort(opCount: 200);
      final controller = RuntimeConsoleController(log: port, pageSize: 200);
      await controller.loadInitial();

      controller.filterByKind(MindOpKind.scan);

      expect(controller.rows, isNotEmpty);
      expect(controller.rows.every((op) => op.kind == MindOpKind.scan), isTrue);
    });
  });

  group('non-happy: runtime unavailable', () {
    test('a count() failure surfaces as loadError, not a crash', () async {
      final port = FakeOperationLogPort(opCount: 100)
        ..countError = StateError('runtime unavailable');
      final controller = RuntimeConsoleController(log: port);

      await controller.loadInitial();

      expect(controller.loadError, isA<StateError>());
      expect(controller.loadedCount, 0);
      expect(controller.isLoadingPage, isFalse);
    });

    test('a range() failure surfaces as loadError', () async {
      final port = FakeOperationLogPort(opCount: 100)
        ..rangeError = StateError('port unavailable');
      final controller = RuntimeConsoleController(log: port);

      await controller.loadInitial();

      expect(controller.loadError, isA<StateError>());
      expect(controller.isLoadingPage, isFalse);
    });
  });

  group('per-row signature verification', () {
    test('verifyRow updates the signature the row renders', () async {
      final port = FakeOperationLogPort(opCount: 50);
      final controller = RuntimeConsoleController(log: port);
      await controller.loadInitial();
      final op = controller.rows.first;
      port.verifyResults[op.sequence] = SignatureState.unverified;

      expect(controller.isVerifying(op.sequence), isFalse);
      final future = controller.verifyRow(op.sequence);
      expect(controller.isVerifying(op.sequence), isTrue);
      await future;

      expect(controller.isVerifying(op.sequence), isFalse);
      expect(controller.signatureFor(op), SignatureState.unverified);
    });

    test('a signature that fails to verify renders as unverified, not "assumed"', () async {
      final port = FakeOperationLogPort(opCount: 50);
      final controller = RuntimeConsoleController(log: port);
      await controller.loadInitial();
      final op = controller.rows.firstWhere((o) => o.signature == SignatureState.verified);
      port.verifyResults[op.sequence] = SignatureState.unverified;

      await controller.verifyRow(op.sequence);

      expect(controller.signatureFor(op), isNot(SignatureState.verified));
      expect(controller.signatureFor(op), SignatureState.unverified);
    });

    test('a verify() port error is captured, not thrown out of the controller', () async {
      final port = FakeOperationLogPort(opCount: 50);
      final controller = RuntimeConsoleController(log: port);
      await controller.loadInitial();
      final op = controller.rows.first;
      // No verifyResults entry stubbed -> the fake throws.

      await controller.verifyRow(op.sequence);

      expect(controller.didVerifyFail(op.sequence), isTrue);
      expect(controller.isVerifying(op.sequence), isFalse);
    });

    test('signatureFor falls back to the log-stored state before any verify', () async {
      final port = FakeOperationLogPort(opCount: 50);
      final controller = RuntimeConsoleController(log: port);
      await controller.loadInitial();
      final op = controller.rows.first;

      expect(controller.signatureFor(op), op.signature);
    });
  });

  group('replay from a row', () {
    test('replayFrom drives progress from the port as a number, not a spinner flag', () async {
      final port = FakeOperationLogPort(opCount: 50);
      final controller = RuntimeConsoleController(log: port);
      await controller.loadInitial();
      final op = controller.rows.first;
      port.replaySteps[op.sequence] = [0.0, 0.25, 0.5, 0.75, 1.0];

      await controller.replayFrom(op.sequence);

      expect(port.replayFromCalls, [op.sequence]);
      expect(controller.replayProgressFor(op.sequence), 1.0);
      expect(controller.isReplaying(op.sequence), isFalse); // done, not in-progress
    });

    test('mid-replay, isReplaying is true and progress reflects the latest fraction', () async {
      final port = FakeOperationLogPort(opCount: 50);
      final controller = RuntimeConsoleController(log: port);
      await controller.loadInitial();
      final op = controller.rows.first;
      port.replaySteps[op.sequence] = [0.0, 0.5];

      await controller.replayFrom(op.sequence);

      // The stream never reaches 1.0, so the row still reads "in progress"
      // after the last emitted fraction — this is the state a real replay
      // sits in for however long it takes to walk the log.
      expect(controller.isReplaying(op.sequence), isTrue);
      expect(controller.replayProgressFor(op.sequence), 0.5);
    });

    test('replayFrom(sequence) is the sequence right-clicked, not sequence 0 or the top row', () async {
      final port = FakeOperationLogPort(opCount: 500);
      final controller = RuntimeConsoleController(log: port);
      await controller.loadInitial();
      final middleRow = controller.rows[10];
      port.replaySteps[middleRow.sequence] = [0.0, 1.0];

      await controller.replayFrom(middleRow.sequence);

      expect(port.replayFromCalls, [middleRow.sequence]);
    });

    test('a replay that fails is captured, not thrown, and clears progress', () async {
      final port = FakeOperationLogPort(opCount: 50);
      final controller = RuntimeConsoleController(log: port);
      await controller.loadInitial();
      final op = controller.rows.first;
      // No replaySteps entry stubbed -> the fake throws.

      await controller.replayFrom(op.sequence);

      expect(controller.didReplayFail(op.sequence), isTrue);
      expect(controller.replayProgressFor(op.sequence), isNull);
    });

    test('dismissReplay clears a finished replay back to resting state', () async {
      final port = FakeOperationLogPort(opCount: 50);
      final controller = RuntimeConsoleController(log: port);
      await controller.loadInitial();
      final op = controller.rows.first;
      port.replaySteps[op.sequence] = [1.0];
      await controller.replayFrom(op.sequence);

      controller.dismissReplay(op.sequence);

      expect(controller.replayProgressFor(op.sequence), isNull);
    });
  });
}
