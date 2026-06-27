const String geminiNanoAssistantModelId = 'gemini-nano';
const String litertGemmaAssistantModelId = 'litert-gemma-mobile';
const String geminiCloudAssistantModelId = 'gemini-cloud';

const String assistantOfflineModelPrefix = 'offline-';

String assistantModelIdForOfflineModel(String modelId) {
  return '$assistantOfflineModelPrefix$modelId';
}

String? offlineModelIdFromAssistantModelId(String assistantModelId) {
  if (!assistantModelId.startsWith(assistantOfflineModelPrefix)) {
    return null;
  }
  final modelId = assistantModelId.substring(
    assistantOfflineModelPrefix.length,
  );
  return modelId.isEmpty ? null : modelId;
}

bool isOfflineAssistantModelId(String assistantModelId) {
  return offlineModelIdFromAssistantModelId(assistantModelId) != null;
}
