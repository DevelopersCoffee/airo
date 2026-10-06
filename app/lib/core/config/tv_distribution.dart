/// Compile-time distribution flags for Aika Stream Android builds.
///
/// Play TV builds use `--dart-define=APP_VARIANT=tv`. Amazon Appstore /
/// Fire OS builds use `--dart-define=APP_VARIANT=fireTv` with the same
/// [lib/main_tv.dart] entrypoint and [pubspec_tv.yaml] dependency graph.
library;

const _appVariant = String.fromEnvironment('APP_VARIANT', defaultValue: 'tv');

/// True when this binary targets Fire OS via the Amazon Appstore line.
bool get isFireTvAppVariant => _appVariant == 'fireTv';

/// Amazon Appstore listing URL for [com.developerscoffee.tv.midas].
///
/// Uses the standard `mas/dl/android` deep link so it works before a public
/// ASIN is assigned; replace with the product page URL after listing approval.
Uri get aikaStreamAmazonAppstoreUrl => Uri.parse(
  'https://www.amazon.com/gp/mas/dl/android?p=com.developerscoffee.tv.midas',
);
