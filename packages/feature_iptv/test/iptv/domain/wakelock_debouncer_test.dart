import 'package:feature_iptv/domain/wakelock_debouncer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a transient flip back to current before settling never fires', () {
    final debouncer = WakelockDebouncer(
      settleDelay: const Duration(milliseconds: 20),
    );
    addTearDown(debouncer.cancel);
    var settledCalls = 0;

    // Already enabled; a one-tick "false" blip that reverts to "true"
    // before the settle delay elapses.
    debouncer.update(
      current: true,
      target: false,
      onSettled: (_) => settledCalls++,
    );
    debouncer.update(
      current: true,
      target: true,
      onSettled: (_) => settledCalls++,
    );

    expect(settledCalls, 0);
  });

  test('a target that holds past the settle delay fires once', () async {
    final debouncer = WakelockDebouncer(
      settleDelay: const Duration(milliseconds: 20),
    );
    addTearDown(debouncer.cancel);
    final settled = <bool>[];

    debouncer.update(
      current: false,
      target: true,
      onSettled: settled.add,
    );

    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(settled, [true]);
  });

  test('repeated calls with the same pending target do not restart the '
      'timer', () async {
    final debouncer = WakelockDebouncer(
      settleDelay: const Duration(milliseconds: 30),
    );
    addTearDown(debouncer.cancel);
    final settled = <bool>[];

    debouncer.update(current: false, target: true, onSettled: settled.add);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    // Same target repeated (as would happen on every rebuild while
    // playing) must not push the settle point further out.
    debouncer.update(current: false, target: true, onSettled: settled.add);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(settled, [true]);
  });

  test('once current catches up to target, no further callback fires', () {
    final debouncer = WakelockDebouncer(
      settleDelay: const Duration(milliseconds: 20),
    );
    addTearDown(debouncer.cancel);
    var settledCalls = 0;

    debouncer.update(
      current: true,
      target: true,
      onSettled: (_) => settledCalls++,
    );

    expect(settledCalls, 0);
  });

  test('cancel prevents a pending settle from firing', () async {
    final debouncer = WakelockDebouncer(
      settleDelay: const Duration(milliseconds: 20),
    );
    var settledCalls = 0;

    debouncer.update(
      current: false,
      target: true,
      onSettled: (_) => settledCalls++,
    );
    debouncer.cancel();

    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(settledCalls, 0);
  });
}
