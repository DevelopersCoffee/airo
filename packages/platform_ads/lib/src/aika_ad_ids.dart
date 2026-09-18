/// AdMob identifiers for Aika Stream & Airo apps.
///
/// Production unit IDs ship by default. Pass
/// `--dart-define=AIKA_ADS_USE_TEST_UNITS=true` only on local debug builds.
/// Never put Google sample IDs in a Play AAB.
// ignore: do_not_use_environment
const bool aikaAdsUseTestUnits = bool.fromEnvironment(
  'AIKA_ADS_USE_TEST_UNITS',
);

const String aikaAdMobAppId = 'ca-app-pub-7741544685082785~7502136325';

const String aikaNativeAdUnitId = aikaAdsUseTestUnits
    ? 'ca-app-pub-3940256099942544/2247696110'
    : 'ca-app-pub-7741544685082785/9923898490';
