import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_playlist_export/platform_playlist_export.dart';

import '../iptv_backup_state_store.dart';
import '../platform_backup_document_gateway.dart';
import 'content_source_management_providers.dart';
import 'guide_providers.dart';
import 'iptv_providers.dart';

final iptvBackupSettingsStoreProvider = Provider<IptvBackupSettingsStore>((
  ref,
) {
  return SharedPreferencesIptvBackupSettingsStore(
    ref.watch(sharedPreferencesProvider),
  );
});

final iptvBackupStateStoreProvider = Provider<IptvBackupStateStore>((ref) {
  return IptvBackupStateStore(
    contentSources: ref.watch(contentSourceStoreProvider),
    favorites: ref.watch(favoriteChannelsStorageProvider),
    xmltv: ref.watch(xmltvSourceStoreProvider),
    settings: ref.watch(iptvBackupSettingsStoreProvider),
    resolveFavoriteChannels: (ids) async {
      final channels = await ref.read(iptvChannelsProvider.future);
      return channels
          .where((channel) => ids.contains(channel.id))
          .toList(growable: false);
    },
  );
});

final iptvBackupServiceProvider = Provider<AiroBackupService>((ref) {
  return AiroBackupService(
    store: ref.watch(iptvBackupStateStoreProvider),
    recognizedSettingKeys:
        SharedPreferencesIptvBackupSettingsStore.defaultRecognizedKeys,
  );
});

final iptvBackupDocumentGatewayProvider = Provider<AiroBackupDocumentGateway>((
  ref,
) {
  return const PlatformBackupDocumentGateway();
});

final iptvBackupDocumentControllerProvider =
    Provider<AiroBackupDocumentController>((ref) {
      return AiroBackupDocumentController(
        service: ref.watch(iptvBackupServiceProvider),
        documents: ref.watch(iptvBackupDocumentGatewayProvider),
      );
    });
