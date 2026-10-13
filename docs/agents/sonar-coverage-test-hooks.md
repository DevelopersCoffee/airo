# Sonar new-code coverage test hooks

Widget tests for Aika native ad cards and the ads gate inject managers through
`app/lib/aika_ads/aika_ad_manager_binding.dart` (`bindAikaAdManagerForTests`).
Both the binding and `debugBodyOverride` are honored only when `kDebugMode` is
true; release builds ignore them. Debug bodies still run through
`shouldShowAd` before render, and dismiss continues to call
`recordAdImpression`.
