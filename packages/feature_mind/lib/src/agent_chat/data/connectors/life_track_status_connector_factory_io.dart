import 'package:core_data/core_data.dart';
import 'package:flutter/foundation.dart';

import '../../../addons/templates/addon_life_track_record_policy.dart';
import '../../../addons/templates/addon_template_catalog.dart';
import '../../domain/services/agent_connector.dart';
import 'life_track_record_connector.dart';
import 'life_track_status_connector.dart';

final LifeTrackLocalDataSource _lifeTrackDataSource =
    LifeTrackLocalDataSource();
final LifeTrackRepositoryImpl _lifeTrackRepository = LifeTrackRepositoryImpl(
  localDataSource: _lifeTrackDataSource,
);

final MindTemplateRegistryLoader _templateLoader =
    MindTemplateRegistryLoader();

TemplateRegistry? _templateRegistry;
AddonTemplateCatalog? _addonTemplateCatalog;
AddonLifeTrackRecordPolicy? _recordPolicy;

Future<void> _ensureTemplateCatalog() async {
  if (_templateRegistry != null && _recordPolicy != null) return;
  _addonTemplateCatalog ??= await _templateLoader.loadAddonCatalog();
  _recordPolicy ??= AddonLifeTrackRecordPolicy(_addonTemplateCatalog!);
  _templateRegistry ??= await _templateLoader.load();
}

AgentConnector createLifeTrackStatusConnector() {
  return LifeTrackStatusConnector(
    repository: _lifeTrackRepository,
    ensureInitialized: initializeLifeTrackStatusConnector,
  );
}

AgentConnector createLifeTrackRecordConnector() {
  return LifeTrackRecordConnector(
    repository: _lifeTrackRepository,
    resolveTemplate: (templateId) async {
      await _ensureTemplateCatalog();
      return _templateRegistry!.getById(templateId);
    },
    followUpHint: (templateId) {
      return _recordPolicy?.followUpHint(templateId) ??
          AddonLifeTrackRecordPolicy.defaultClaimFollowUp;
    },
    dedupeFieldLabels: (templateId) {
      return _recordPolicy?.dedupeFieldLabels(templateId) ??
          AddonLifeTrackRecordPolicy.defaultDedupeFields;
    },
    ensureInitialized: initializeLifeTrackStatusConnector,
  );
}

Future<void> initializeLifeTrackStatusConnector() async {
  try {
    await _ensureTemplateCatalog();
    await _lifeTrackDataSource.initialize();
  } catch (error) {
    debugPrint('LifeTrack local data source unavailable: $error');
  }
}

Future<void> closeLifeTrackStatusConnector() => _lifeTrackDataSource.close();

Future<TemplateRegistry> loadMindTemplateRegistry() async {
  await _ensureTemplateCatalog();
  return _templateRegistry!;
}

Future<Map<String, List<String>>> loadMindTemplateFallbackKeywords() async {
  await _ensureTemplateCatalog();
  return {
    ...fallbackKeywordsFromCatalog(_addonTemplateCatalog!),
  };
}

Future<LifeTrackTemplateFallbackResolver> createMindTemplateFallbackResolver(
  ConnectivityService connectivityService,
) async {
  await _ensureTemplateCatalog();
  return LifeTrackTemplateFallbackResolver(
    registry: _templateRegistry!,
    connectivityService: connectivityService,
    templateKeywords: await loadMindTemplateFallbackKeywords(),
  );
}
