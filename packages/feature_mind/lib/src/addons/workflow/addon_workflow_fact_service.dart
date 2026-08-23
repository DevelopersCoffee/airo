import '../../agent_chat/domain/services/life_track_fact_extractor.dart';
import 'addon_workflow_policy.dart';

/// Add-on-owned fact extraction and clarification copy for LifeTrack records.
class AddonWorkflowFactService {
  AddonWorkflowFactService({
    this.facts = const LifeTrackFactExtractor(),
    AddonWorkflowPolicy? policy,
  }) : policy = policy ?? AddonWorkflowPolicy.defaults();

  final LifeTrackFactExtractor facts;
  final AddonWorkflowPolicy policy;

  ExtractedLifeTrackFacts extract(String templateId, String prompt) {
    switch (templateId) {
      case 'study_progress_v1':
        return facts.extractStudyProgress(prompt);
      case 'medical_surgery_v1':
        return facts.extractMedicalSurgery(prompt);
      case 'real_estate_under_construction_v1':
        return facts.extractPropertyPurchase(prompt);
      case 'insurance_claim_v1':
        return facts.extractInsuranceClaim(prompt);
      default:
        return facts.extractInsuranceClaim(prompt);
    }
  }

  String clarificationHint(String templateId) {
    final configured = policy.forTemplate(templateId)?.recordClarificationHint;
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    return 'I can store this journey on this device. Paste the key facts you '
        'already have and I will keep them locally.';
  }

  bool wantsRecord(AgentSkillRecordContext context) {
    if (context.skillId == 'record-study-progress') return true;
    if (!context.skillTools.contains('record_lifetrack_facts')) return false;
    return facts.wantsRecord(context.prompt) ||
        facts.wantsStudyRecord(context.prompt);
  }
}

/// Minimal skill context for record routing without host template switches.
class AgentSkillRecordContext {
  const AgentSkillRecordContext({
    required this.skillId,
    required this.skillTools,
    required this.templateId,
    required this.prompt,
  });

  final String skillId;
  final List<String> skillTools;
  final String templateId;
  final String prompt;
}
