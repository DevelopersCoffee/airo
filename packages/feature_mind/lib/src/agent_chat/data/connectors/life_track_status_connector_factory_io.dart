import 'package:core_data/core_data.dart';
import 'package:flutter/foundation.dart';

import '../../../addons/templates/addon_life_track_record_policy.dart';
import '../../../addons/templates/addon_template_catalog.dart';
import '../../domain/services/agent_connector.dart';
import 'life_track_record_connector.dart';
import 'life_track_repository_holder.dart';
import 'life_track_status_connector.dart';

final LifeTrackLocalDataSource _lifeTrackPlaintextDataSource =
    LifeTrackLocalDataSource();
final _lifeTrackRepositoryHolder = DelegatingLifeTrackRepository(
  LifeTrackRepositoryImpl(localDataSource: _lifeTrackPlaintextDataSource),
);
final _idempotencyPortHolder = DelegatingIdempotentEffectPort();

LifeTrackSecureStack? _secureStack;
Future<void>? _secureStackFuture;

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

Future<void> _ensureSecureStack() {
  _secureStackFuture ??= _openSecureStack();
  return _secureStackFuture!;
}

Future<void> _openSecureStack() async {
  try {
    final stack = await LifeTrackSecureStack.open(
      plaintext: _lifeTrackPlaintextDataSource,
    );
    _secureStack = stack;
    _lifeTrackRepositoryHolder.adopt(stack.repository);
    if (stack.idempotencyPort != null) {
      _idempotencyPortHolder.adopt(stack.idempotencyPort!);
    }
  } catch (error, stack) {
    debugPrint('LifeTrack secure stack unavailable: $error\n$stack');
    await _lifeTrackPlaintextDataSource.initialize();
  }
}

AgentConnector createLifeTrackStatusConnector() {
  return LifeTrackStatusConnector(
    repository: _lifeTrackRepositoryHolder,
    ensureInitialized: initializeLifeTrackStatusConnector,
  );
}

AgentConnector createLifeTrackRecordConnector() {
  return LifeTrackRecordConnector(
    repository: _lifeTrackRepositoryHolder,
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
    writeGate: () async {
      await _ensureSecureStack();
      final stack = _secureStack;
      if (stack == null) return false;
      return await stack.canWrite();
    },
    idempotencyPort: _idempotencyPortHolder,
  );
}

Future<void> initializeLifeTrackStatusConnector() async {
  try {
    await _ensureTemplateCatalog();
    await _ensureSecureStack();
  } catch (error) {
    debugPrint('LifeTrack connector initialization failed: $error');
  }
}

Future<void> closeLifeTrackStatusConnector() async {
  if (_secureStack != null) {
    await _secureStack!.close();
    _secureStack = null;
    _secureStackFuture = null;
  } else {
    await _lifeTrackPlaintextDataSource.close();
  }
}

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
