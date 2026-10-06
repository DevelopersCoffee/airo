import 'package:core_product_shell/core_product_shell.dart';
import 'package:flutter/foundation.dart';

import '../config/tv_distribution.dart';

/// Cross-app promotion list for TV shells, with Fire distribution store links.
List<SiblingApp> publishedTvSiblingAppsFor(ShellId current) {
  return applyFireTvStoreLinks(publishedSiblingAppsFor(current));
}

@visibleForTesting
List<SiblingApp> applyFireTvStoreLinks(Iterable<SiblingApp> apps) {
  if (!isFireTvAppVariant) {
    return apps.toList(growable: false);
  }
  return apps
      .map(
        (app) => app.id == ShellId.tv
            ? SiblingApp(
                id: app.id,
                name: app.name,
                pitch: app.pitch,
                iconAsset: app.iconAsset,
                androidStoreUrl: aikaStreamAmazonAppstoreUrl,
                iosStoreUrl: app.iosStoreUrl,
                isPublishedAndroid: app.isPublishedAndroid,
                isPublishedIos: app.isPublishedIos,
                deepLinkScheme: app.deepLinkScheme,
              )
            : app,
      )
      .toList(growable: false);
}
