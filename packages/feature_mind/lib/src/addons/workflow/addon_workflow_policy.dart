import '../templates/addon_template_catalog.dart';

/// Per-template workflow policy owned by add-on bundles (keywords, pending copy).
class AddonWorkflowTemplatePolicy {
  const AddonWorkflowTemplatePolicy({
    required this.templateId,
    this.recordClarificationHint = '',
    this.pendingKeywords = const [],
    this.pendingUsualOptionalFields = const [],
    this.pendingEmptyMessage = '',
    this.pendingSubjectLabel = 'journey',
  });

  final String templateId;
  final String recordClarificationHint;
  final List<String> pendingKeywords;
  final List<String> pendingUsualOptionalFields;
  final String pendingEmptyMessage;
  final String pendingSubjectLabel;

  factory AddonWorkflowTemplatePolicy.fromMetadata(
    LifeTrackTemplateAddonMetadata metadata,
    Map<String, dynamic> workflow,
  ) {
    final pendingKeywords = _stringList(workflow['pending_keywords']);
    final fallbackKeywords = _stringList(workflow['fallback_keywords']);
    return AddonWorkflowTemplatePolicy(
      templateId: metadata.templateId,
      recordClarificationHint:
          workflow['record_clarification_hint'] as String? ??
          metadata.recordFollowUpHint,
      pendingKeywords: pendingKeywords.isNotEmpty
          ? pendingKeywords
          : fallbackKeywords,
      pendingUsualOptionalFields:
          _stringList(workflow['pending_usual_optional_fields']),
      pendingEmptyMessage: workflow['pending_empty_message'] as String? ?? '',
      pendingSubjectLabel:
          workflow['pending_subject_label'] as String? ?? 'journey',
    );
  }

  static List<String> _stringList(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
}

/// Resolves add-on-owned workflow policy for templates and personas.
class AddonWorkflowPolicy {
  AddonWorkflowPolicy._(this._byTemplateId);

  final Map<String, AddonWorkflowTemplatePolicy> _byTemplateId;

  AddonWorkflowTemplatePolicy? forTemplate(String templateId) =>
      _byTemplateId[templateId];

  Iterable<AddonWorkflowTemplatePolicy> get templatePolicies =>
      _byTemplateId.values;

  bool queryMatchesTemplate(String lowerQuery, String templateId) {
    final policy = forTemplate(templateId);
    if (policy == null || policy.pendingKeywords.isEmpty) return false;
    return policy.pendingKeywords.any(lowerQuery.contains);
  }

  factory AddonWorkflowPolicy.fromCatalog(AddonTemplateCatalog catalog) {
    final byTemplateId = <String, AddonWorkflowTemplatePolicy>{};
    for (final template in catalog.templates) {
      final metadata = catalog.metadataFor(template.templateId);
      if (metadata == null) continue;
      final workflow = _workflowForAddon(catalog, metadata.addonId);
      byTemplateId[template.templateId] = AddonWorkflowTemplatePolicy.fromMetadata(
        metadata,
        workflow,
      );
    }
    return AddonWorkflowPolicy._(byTemplateId);
  }

  static Map<String, dynamic> _workflowForAddon(
    AddonTemplateCatalog catalog,
    String addonId,
  ) {
    // Metadata is keyed by template; workflow extras are loaded with manifests.
    return catalog.workflowBlocksByAddonId[addonId] ?? const {};
  }

  /// Built-in fallbacks when catalog assets are not loaded (unit tests).
  factory AddonWorkflowPolicy.defaults() {
    return AddonWorkflowPolicy._({
      'insurance_claim_v1': const AddonWorkflowTemplatePolicy(
        templateId: 'insurance_claim_v1',
        recordClarificationHint:
            'I can store this claim on this device. Paste the insurer, claim '
            'ID or broker reference, policy number if you have it, and whether '
            'documents were received. I will not file the claim or read your email.',
        pendingKeywords: [
          'claim',
          'insurance',
          'insurer',
          'document',
          'reimbursement',
          'policy',
        ],
        pendingUsualOptionalFields: [
          'Insurer',
          'Broker / Intermediary',
          'Policy Number',
          'Follow-up Log',
          'Settlement Notes',
        ],
        pendingEmptyMessage:
            'I have no stored claim entities yet. Paste the insurer, claim ID, '
            'and whether documents were received — I will extract them from this chat.',
        pendingSubjectLabel: 'claim',
      ),
      'medical_surgery_v1': const AddonWorkflowTemplatePolicy(
        templateId: 'medical_surgery_v1',
        recordClarificationHint:
            'I can store this hospital stay on this device. Paste the hospital, '
            'date, pre-op tests, and authorization reference if you have them. '
            'I will not diagnose or change a care plan.',
        pendingKeywords: [
          'hospital',
          'surgery',
          'recovery',
          'pre-op',
          'operation',
          'medical',
        ],
        pendingUsualOptionalFields: [
          'Required Tests List',
          'Insurance Authorization Reference',
          'Hospital Checklist',
          'Recovery Notes',
        ],
        pendingEmptyMessage:
            'I have no stored hospital or surgery entities yet. Paste the '
            'hospital, surgery date, required tests, and authorization reference '
            '— I will extract them from this chat.',
        pendingSubjectLabel: 'hospital',
      ),
      'real_estate_under_construction_v1': const AddonWorkflowTemplatePolicy(
        templateId: 'real_estate_under_construction_v1',
        recordClarificationHint:
            'I can store this purchase on this device. Paste the builder, '
            'project, floor, and RERA number if you have them. I will not '
            'give legal advice.',
        pendingKeywords: [
          'flat',
          'rera',
          'property',
          'builder',
          'tower',
          'apartment',
        ],
        pendingUsualOptionalFields: [
          'RERA Registration Number',
          'Builder Track Record Notes',
          'Your Target Floor',
          'Promised Amenities List',
        ],
        pendingEmptyMessage:
            'I have no stored property entities yet. Paste the RERA number, '
            'builder, project, and floor — I will extract them from this chat.',
        pendingSubjectLabel: 'property',
      ),
      'study_progress_v1': const AddonWorkflowTemplatePolicy(
        templateId: 'study_progress_v1',
        recordClarificationHint:
            'I store study progress as a local LifeTrack — not a notes app. '
            'Tell me the subject, last topic, and exam date if you have one.',
        pendingKeywords: ['study', 'subject', 'exam', 'topic', 'course'],
        pendingUsualOptionalFields: [
          'Current Topic',
          'Exam or Goal Date',
          'Next Session Plan',
        ],
        pendingEmptyMessage:
            'I have no stored study entities yet. Paste the subject and what '
            'you are working on — I will extract them from this chat.',
        pendingSubjectLabel: 'study track',
      ),
      'car_purchase_v1': const AddonWorkflowTemplatePolicy(
        templateId: 'car_purchase_v1',
        recordClarificationHint:
            'I can store a car purchase decision on this device. Paste the '
            'vehicle, budget, and test-drive notes if you have them.',
        pendingKeywords: ['car', 'vehicle', 'budget', 'test drive', 'parking'],
        pendingUsualOptionalFields: [
          'Shortlisted Cars',
          'Test Drive Notes',
          'Budget Range',
          'Loan Offers',
        ],
        pendingEmptyMessage:
            'I have no stored vehicle purchase entities yet.',
        pendingSubjectLabel: 'car purchase',
      ),
      'university_admission_v1': const AddonWorkflowTemplatePolicy(
        templateId: 'university_admission_v1',
        recordClarificationHint:
            'I can store an admission cycle on this device. Paste the '
            'university, program, and intake term if you have them.',
        pendingKeywords: [
          'university',
          'admission',
          'apply',
          'application',
          'program',
        ],
        pendingUsualOptionalFields: [
          'University Shortlist',
          'Document Checklist',
          'Submitted Programs',
        ],
        pendingEmptyMessage:
            'I have no stored admission entities yet.',
        pendingSubjectLabel: 'admission cycle',
      ),
    });
  }
}
