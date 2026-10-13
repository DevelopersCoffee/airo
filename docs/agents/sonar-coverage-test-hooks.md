# Sonar new-code coverage test hooks

Widget tests for Aika native ad cards and the ads gate inject managers through
`app/lib/aika_ads/aika_ad_manager_binding.dart` (`bindAikaAdManagerForTests`).
Cards also accept an optional `debugBodyOverride` to render without Mobile Ads
SDK load during tests.
