import 'package:airo_app/core/config/tv_distribution.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Amazon Appstore URL targets Aika Stream package id', () {
    expect(
      aikaStreamAmazonAppstoreUrl.toString(),
      contains('com.developerscoffee.tv.midas'),
    );
  });

  test('isFireTvAppVariant reflects APP_VARIANT compile flag', () {
    const variant = String.fromEnvironment('APP_VARIANT', defaultValue: 'tv');
    expect(isFireTvAppVariant, variant == 'fireTv');
  });
}
