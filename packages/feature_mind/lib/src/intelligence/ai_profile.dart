import 'package:core_ai/core_ai.dart';
import 'package:flutter/foundation.dart';

/// User-facing pipeline. Slots name capabilities, never model ids.
enum AiProfileId {
  generalChat,
  meetingAssistant,
  documentAssistant,
  voiceTranscription,
  imageAssistant,
}

@immutable
class AiProfileSlot {
  const AiProfileSlot({
    required this.id,
    required this.label,
    required this.capability,
    this.modality,
    this.required = true,
    this.sizeBias = IntelligenceSizeBias.balanced,
    this.languages = const <String>[],
  });

  final String id;
  final String label;
  final ModelCapability capability;
  final ModelModality? modality;
  final bool required;
  final IntelligenceSizeBias sizeBias;
  final List<String> languages;
}

@immutable
class AiProfile {
  const AiProfile({
    required this.id,
    required this.title,
    required this.jobLine,
    required this.destinationPath,
    required this.slots,
  });

  final AiProfileId id;
  final String title;
  final String jobLine;
  final String destinationPath;
  final List<AiProfileSlot> slots;

  static const generalChat = AiProfile(
    id: AiProfileId.generalChat,
    title: 'Chat',
    jobLine: 'General conversation',
    destinationPath: '/mind/chat',
    slots: [
      AiProfileSlot(
        id: 'chat',
        label: 'Conversation',
        capability: ModelCapability.chat,
      ),
    ],
  );

  static const meetingAssistant = AiProfile(
    id: AiProfileId.meetingAssistant,
    title: 'Scribe',
    jobLine: 'Meetings and transcription',
    destinationPath: '/',
    slots: [
      AiProfileSlot(
        id: 'speech',
        label: 'Speech recognition',
        capability: ModelCapability.audioUnderstanding,
        modality: ModelModality.audio,
        sizeBias: IntelligenceSizeBias.compact,
        languages: ['en', 'hi', 'mr'],
      ),
      AiProfileSlot(
        id: 'minutes',
        label: 'Meeting intelligence',
        capability: ModelCapability.meetingSummarization,
      ),
    ],
  );

  static const documentAssistant = AiProfile(
    id: AiProfileId.documentAssistant,
    title: 'Documents',
    jobLine: 'Read and understand files',
    destinationPath: '/mind',
    slots: [
      AiProfileSlot(
        id: 'documents',
        label: 'Documents',
        capability: ModelCapability.documents,
      ),
    ],
  );

  static const voiceTranscription = AiProfile(
    id: AiProfileId.voiceTranscription,
    title: 'Voice',
    jobLine: 'Transcribe recordings',
    destinationPath: '/',
    slots: [
      AiProfileSlot(
        id: 'speech',
        label: 'Speech recognition',
        capability: ModelCapability.audioUnderstanding,
        modality: ModelModality.audio,
        languages: ['en', 'hi', 'mr'],
      ),
    ],
  );

  static const imageAssistant = AiProfile(
    id: AiProfileId.imageAssistant,
    title: 'Vision',
    jobLine: 'Understand images',
    destinationPath: '/mind',
    slots: [
      AiProfileSlot(
        id: 'vision',
        label: 'Image understanding',
        capability: ModelCapability.imageUnderstanding,
        modality: ModelModality.image,
      ),
    ],
  );

  static const List<AiProfile> catalog = [
    generalChat,
    meetingAssistant,
    documentAssistant,
    voiceTranscription,
    imageAssistant,
  ];
}

@immutable
class AiProfileSlotState {
  const AiProfileSlotState({required this.slot, required this.selection});

  final AiProfileSlot slot;
  final IntelligenceSelection selection;
}

@immutable
class AiProfileReadiness {
  const AiProfileReadiness({required this.profile, required this.slots});

  final AiProfile profile;
  final List<AiProfileSlotState> slots;

  bool get ready => profile.slots
      .where((slot) => slot.required)
      .every(
        (slot) => slots
            .firstWhere((state) => state.slot.id == slot.id)
            .selection
            .ready,
      );

  bool get canInstall => slots.any((state) => state.selection.canInstall);

  List<OfflineModelInfo> get recommendedInstalls => [
    for (final state in slots)
      if (!state.selection.ready && state.selection.model != null)
        state.selection.model!,
  ];
}

/// Resolves [AiProfile] slots through [IntelligenceQuery]. Application copy
/// lives here; ranking stays in core_ai.
class AiProfileResolver {
  const AiProfileResolver({this.query = const IntelligenceQuery()});

  final IntelligenceQuery query;

  List<AiProfile> visibleProfiles(
    List<OfflineModelInfo> catalog, {
    IntelligenceConstraints constraints = const IntelligenceConstraints(),
  }) {
    return AiProfile.catalog
        .where(
          (profile) => profile.slots.any(
            (slot) => query
                .select(
                  capability: slot.capability,
                  catalog: catalog,
                  constraints: _slotConstraints(slot, constraints),
                )
                .candidates
                .isNotEmpty,
          ),
        )
        .toList(growable: false);
  }

  /// Overview cards: drop Voice when Scribe already covers speech so the
  /// grid stays task-first instead of duplicating transcription.
  List<AiProfile> overviewProfiles(
    List<OfflineModelInfo> catalog, {
    IntelligenceConstraints constraints = const IntelligenceConstraints(),
  }) {
    final visible = visibleProfiles(catalog, constraints: constraints);
    final hasScribe = visible.any(
      (profile) => profile.id == AiProfileId.meetingAssistant,
    );
    if (!hasScribe) return visible;
    return visible
        .where((profile) => profile.id != AiProfileId.voiceTranscription)
        .toList(growable: false);
  }

  static String jobLineFor(ModelCapability capability) {
    return switch (capability) {
      ModelCapability.chat => 'General conversation',
      ModelCapability.audioUnderstanding => 'Speech to text',
      ModelCapability.meetingSummarization => 'Meeting minutes',
      ModelCapability.documents => 'Read and understand files',
      ModelCapability.imageUnderstanding => 'Understand images',
      ModelCapability.translation => 'Translate text',
      ModelCapability.ocr => 'Read text in images',
      ModelCapability.embeddings => 'Search on-device memory',
      ModelCapability.reasoning => 'Longer reasoning',
      ModelCapability.agentSkills => 'Tools and skills',
      ModelCapability.mobileActions => 'Device actions',
      ModelCapability.promptLab => 'Prompt experiments',
      ModelCapability.benchmark => 'Runtime timing',
    };
  }

  AiProfileReadiness resolve(
    AiProfile profile,
    List<OfflineModelInfo> catalog, {
    IntelligenceConstraints constraints = const IntelligenceConstraints(),
    Map<String, String> overrides = const {},
  }) {
    return AiProfileReadiness(
      profile: profile,
      slots: [
        for (final slot in profile.slots)
          AiProfileSlotState(
            slot: slot,
            selection: query.select(
              capability: slot.capability,
              catalog: catalog,
              constraints: _slotConstraints(slot, constraints),
              overrideModelId: overrides['${profile.id.name}.${slot.id}'],
            ),
          ),
      ],
    );
  }

  List<String> usedBy(
    OfflineModelInfo model,
    List<OfflineModelInfo> catalog, {
    IntelligenceConstraints constraints = const IntelligenceConstraints(),
    Map<String, String> overrides = const {},
  }) {
    final titles = <String>[];
    for (final profile in visibleProfiles(catalog, constraints: constraints)) {
      final readiness = resolve(
        profile,
        catalog,
        constraints: constraints,
        overrides: overrides,
      );
      if (readiness.slots.any((slot) => slot.selection.model?.id == model.id)) {
        titles.add(profile.title);
      }
    }
    return titles;
  }

  IntelligenceConstraints _slotConstraints(
    AiProfileSlot slot,
    IntelligenceConstraints base,
  ) {
    return IntelligenceConstraints(
      memory: base.memory,
      languages: slot.languages.isEmpty ? base.languages : slot.languages,
      modality: slot.modality ?? base.modality,
      sizeBias: slot.sizeBias,
      preferInstalled: base.preferInstalled,
      requireCurrentPlatform: base.requireCurrentPlatform,
    );
  }
}
