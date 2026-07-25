import 'package:airo_app/core/pro/pro_bootstrap_runner.dart';
import 'package:airo_app/core/startup/app_startup_tasks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('open-source seam initializes zero pro modules without error', () async {
    final logs = <String>[];
    final initialized = await runProBootstrap(log: logs.add);

    // The upstream airo_pro_bootstrap registers nothing; the overlay build
    // swaps in a same-named package that does. Either way this must not
    // throw, and the GA build must come back empty.
    expect(initialized, isEmpty);
    expect(logs, isEmpty);
  });

  test(
    'scheduleDeferredProBootstrap runs the seam after first frame',
    () async {
      final callbacks = <void Function(Duration)>[];
      final logs = <String>[];

      scheduleDeferredProBootstrap(
        addPostFrameCallback: callbacks.add,
        log: logs.add,
      );

      expect(callbacks, hasLength(1));
      callbacks.single(Duration.zero);
      // The deferred task completes (and logs) asynchronously.
      await Future<void>.delayed(Duration.zero);
      expect(logs.any((line) => line.contains('pro_bootstrap')), isTrue);
    },
  );
}
