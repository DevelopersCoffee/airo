const String geminiNanoAssistantModelId = 'gemini-nano';
const String litertGemmaAssistantModelId = 'litert-gemma-mobile';
const String geminiCloudAssistantModelId = 'gemini-cloud';

const String noAssistantModelSelectedMessage =
    'Choose a model from the Model Library before starting chat.';
const String geminiNanoUnavailableMessage =
    'Gemini Nano is not available on this device. Open Model Library and choose a runnable model.';
const String geminiNanoInitializationFailedMessage =
    'Gemini Nano did not initialize on this device. Open Model Library and choose another model.';
const String litertGemmaUnavailableMessage =
    'LiteRT-LM is not configured. Install a local model or set LITERT_LM_MODEL_PATH/LITERT_LM_MODEL_URL.';
const String geminiCloudUnavailableMessage =
    'Gemini Cloud is not configured. Launch with --dart-define=GEMINI_API_KEY=... to use this real API path.';
const String geminiCloudEmptyResponseMessage = 'Gemini Cloud returned no text.';
const String unsupportedAssistantRuntimeMessage =
    'This downloaded model is selected, but chat inference is not wired to it yet. Use Gemini Nano or LiteRT-LM for chat, or open AI Models to manage downloads.';
