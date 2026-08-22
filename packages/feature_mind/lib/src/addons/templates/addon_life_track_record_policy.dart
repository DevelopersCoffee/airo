import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';

import 'addon_template_catalog.dart';

/// Resolves LifeTrack save copy and dedupe policy from add-on template metadata.
class AddonLifeTrackRecordPolicy {
  AddonLifeTrackRecordPolicy(this._catalog);

  final AddonTemplateCatalog _catalog;

  static const defaultClaimFollowUp =
      'Ask what is pending on this claim whenever you want a status check.';
  static const defaultStudyFollowUp =
      'Ask what is pending on this study track whenever you want a status check.';
  static const defaultDedupeFields = [
    'Claim ID',
    'Policy Number',
    'Intermediary Reference',
    'Subject',
  ];

  String followUpHint(String templateId) {
    final meta = _catalog.metadataFor(templateId);
    if (meta != null && meta.recordFollowUpHint.trim().isNotEmpty) {
      return meta.recordFollowUpHint.trim();
    }
    if (templateId == 'study_progress_v1') return defaultStudyFollowUp;
    return defaultClaimFollowUp;
  }

  List<String> dedupeFieldLabels(String templateId) {
    final meta = _catalog.metadataFor(templateId);
    if (meta != null && meta.dedupeFieldLabels.isNotEmpty) {
      return meta.dedupeFieldLabels;
    }
    if (templateId == 'study_progress_v1') {
      return const ['Subject', 'Last Topic', 'Exam Date'];
    }
    return defaultDedupeFields;
  }
}

Map<String, List<String>> fallbackKeywordsFromCatalog(
  AddonTemplateCatalog catalog,
) {
  return {
    for (final entry in catalog.metadataByTemplateId.entries)
      if (entry.value.fallbackKeywords.isNotEmpty)
        entry.key: entry.value.fallbackKeywords,
  };
}
