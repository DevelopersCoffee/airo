import 'package:core_product_shell/core_product_shell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('siblingAppsFor', () {
    test('excludes the current shell from its own sibling list', () {
      final result = siblingAppsFor(ShellId.mobile);

      expect(result.any((app) => app.id == ShellId.mobile), isFalse);
    });

    test('returns the other three shipped apps for a known shell', () {
      final result = siblingAppsFor(ShellId.tv);

      expect(result.map((app) => app.id), containsAll(const [
        ShellId.mobile,
        ShellId.coins,
        ShellId.mind,
      ]));
      expect(result, hasLength(3));
    });

    test('returns all shipped apps for a shell not in the registry', () {
      final result = siblingAppsFor(const ShellId('unregistered'));

      expect(result, hasLength(4));
    });
  });

  group('siblingApps', () {
    test('covers every shipped shell exactly once', () {
      final ids = siblingApps.map((app) => app.id).toSet();

      expect(ids, {ShellId.mobile, ShellId.tv, ShellId.coins, ShellId.mind});
      expect(siblingApps, hasLength(4));
    });
  });
}
