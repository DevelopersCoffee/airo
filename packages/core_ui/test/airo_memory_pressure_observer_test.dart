import 'package:core_ui/core_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('registers once, evicts on pressure, and unregisters once', () {
    var registerCalls = 0;
    var unregisterCalls = 0;
    var pressureCalls = 0;
    final observer = AiroMemoryPressureObserver(
      onMemoryPressure: () => pressureCalls++,
      register: (_) => registerCalls++,
      unregister: (_) => unregisterCalls++,
    );

    observer.didHaveMemoryPressure();
    observer.didHaveMemoryPressure();
    observer.dispose();
    observer.dispose();
    observer.didHaveMemoryPressure();

    expect(registerCalls, 1);
    expect(pressureCalls, 2);
    expect(unregisterCalls, 1);
  });
}
