const String geminiNanoAssistantModelId = 'gemini-nano';
const String litertGemmaAssistantModelId = 'litert-gemma-mobile';
const String geminiCloudAssistantModelId = 'gemini-cloud';
const String assistantOfflineModelPrefix = 'offline-';

const String noAssistantModelSelectedMessage =
    'Choose a model from the Model Library before starting chat.';
const String geminiNanoUnavailableMessage =
    'Gemini Nano is not available on this device. Open Model Library and choose a runnable model.';
const String geminiNanoInitializationFailedMessage =
    'Gemini Nano did not initialize on this device. Open Model Library and choose another model.';
const String litertGemmaUnavailableMessage =
    'LiteRT-LM is not configured. Install a local model or set LITERT_LM_MODEL_PATH/LITERT_LM_MODEL_URL.';
const String litertWebRuntimeInitFailedMessage =
    'The browser local model runtime failed to start (WebGPU and WASM both unavailable). '
    'Try a different browser or use Gemini Cloud for this session.';
const String geminiCloudUnavailableMessage =
    'Gemini Cloud is not configured. Launch with --dart-define=GEMINI_API_KEY=... to use this real API path.';
const String geminiCloudEmptyResponseMessage = 'Gemini Cloud returned no text.';
const String unsupportedAssistantRuntimeMessage =
    'This assistant runtime is not available. Open Project setup and choose another model.';
const String offlinePackageUnavailableMessage =
    'This offline package is not installed on this device yet. Open Profile > AI Models to download it or choose another runtime.';
const String offlinePackageCatalogMissingMessage =
    'The selected offline package is no longer in the catalog. Open Project setup and choose another model.';

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
