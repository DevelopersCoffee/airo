import 'package:airo_app/core/product/tv_sibling_apps.dart';
import 'package:core_product_shell/core_product_shell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('applyFireTvStoreLinks swaps only Aika Stream on Fire builds', () {
    const variant = String.fromEnvironment('APP_VARIANT', defaultValue: 'tv');
    final input = siblingAppsFor(ShellId.mobile);
    final aika = input.firstWhere((app) => app.id == ShellId.tv);
    final mapped = applyFireTvStoreLinks(input);
    final mappedAika = mapped.firstWhere((app) => app.id == ShellId.tv);

    if (variant == 'fireTv') {
      expect(mappedAika.androidStoreUrl.host, 'www.amazon.com');
    } else {
      expect(mappedAika.androidStoreUrl, aika.androidStoreUrl);
    }
  });
}
