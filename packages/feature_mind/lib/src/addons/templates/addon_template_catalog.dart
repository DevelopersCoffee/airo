import 'dart:convert';

import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/services.dart';

/// Add-on-owned LifeTrack template metadata (keywords, save copy, dedupe).
class LifeTrackTemplateAddonMetadata {
  const LifeTrackTemplateAddonMetadata({
    required this.templateId,
    required this.addonId,
    this.fallbackKeywords = const [],
    this.recordFollowUpHint = '',
    this.dedupeFieldLabels = const [],
  });

  final String templateId;
  final String addonId;
  final List<String> fallbackKeywords;
  final String recordFollowUpHint;
  final List<String> dedupeFieldLabels;
}

/// Loads workflow templates and metadata from Mind add-on bundles.
class AddonTemplateCatalog {
  AddonTemplateCatalog._({
    required this.templates,
    required this.metadataByTemplateId,
  });

  final List<LifeTrackTemplate> templates;
  final Map<String, LifeTrackTemplateAddonMetadata> metadataByTemplateId;

  static const bundledJsonlAsset =
      'packages/feature_mind/addons/bundled_workflow_templates.jsonl';

  static const bundledManifestAssets = <String>[
    'packages/feature_mind/addons/insurance-planner/addon.json',
    'packages/feature_mind/addons/hospital-recovery-planner/addon.json',
    'packages/feature_mind/addons/property-purchase-planner/addon.json',
  ];

  static Future<AddonTemplateCatalog> loadBundled({AssetBundle? bundle}) async {
    final assetBundle = bundle ?? rootBundle;
    final rawJsonl = await assetBundle.loadString(bundledJsonlAsset);
    final templates = <LifeTrackTemplate>[];
    for (final row in CompactJsonl.parse(rawJsonl)) {
      final result = TemplateRegistry.validate(row);
      if (result case Ok(value: final template)) {
        templates.add(template);
      } else if (result case Err(error: final error, stack: final stack)) {
        throw ParseError(
          'Add-on workflow template failed validation',
          originalError: error,
          originalStack: stack,
        );
      }
    }

    final metadataByTemplateId = <String, LifeTrackTemplateAddonMetadata>{};
    for (final assetPath in bundledManifestAssets) {
      final rawManifest = await assetBundle.loadString(assetPath);
      final decoded = jsonDecode(rawManifest);
      if (decoded is! Map<String, dynamic>) continue;
      final manifest = AddonManifest.fromJson(decoded);
      final workflow = decoded['workflow'] as Map<String, dynamic>?;
      if (workflow == null) continue;
      final templateId = workflow['template_id'] as String?;
      if (templateId == null || templateId.trim().isEmpty) continue;
      metadataByTemplateId[templateId] = LifeTrackTemplateAddonMetadata(
        templateId: templateId,
        addonId: manifest.id.value,
        fallbackKeywords: _stringList(workflow['fallback_keywords']),
        recordFollowUpHint: workflow['record_follow_up_hint'] as String? ?? '',
        dedupeFieldLabels: _stringList(workflow['dedupe_field_labels']),
      );
    }

    return AddonTemplateCatalog._(
      templates: List.unmodifiable(templates),
      metadataByTemplateId: metadataByTemplateId,
    );
  }

  LifeTrackTemplateAddonMetadata? metadataFor(String templateId) =>
      metadataByTemplateId[templateId];

  static List<String> _stringList(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
}

/// Merges framework bundled templates with add-on workflow templates.
class MindTemplateRegistryLoader {
  const MindTemplateRegistryLoader();

  Future<TemplateRegistry> load({AssetBundle? bundle}) async {
    final core = await TemplateRegistry.loadBundled(bundle: bundle);
    final addonCatalog = await AddonTemplateCatalog.loadBundled(bundle: bundle);
    return TemplateRegistry.fromTemplates([
      ...core.getAll(),
      ...addonCatalog.templates,
    ]);
  }

  Future<AddonTemplateCatalog> loadAddonCatalog({AssetBundle? bundle}) =>
      AddonTemplateCatalog.loadBundled(bundle: bundle);
}
