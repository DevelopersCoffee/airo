import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:product_capabilities/product_capabilities.dart';

final airoTvProductProfileProvider = Provider<ProductProfileManifest>((ref) {
  return AiroTvProductProfiles.liteReceiver();
});
