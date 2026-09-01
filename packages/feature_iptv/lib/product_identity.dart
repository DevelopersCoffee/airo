/// Canonical Play Store identity for the Android TV product.
///
/// Gradle `applicationId`, store listing copy, and user-visible chrome must
/// stay aligned with these constants. Historical GitHub APKs published as
/// `io.airo.app.tv` / "Airo TV" are a different listing and must not be
/// described as this package.
abstract final class TvStoreProduct {
  static const displayName = 'Midas Stream';
  static const androidPackageId = 'com.developerscoffee.tv.midas';
  static const publisher = 'DevelopersCoffee';
}
