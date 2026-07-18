import '../models/model_credibility.dart';
import '../models/offline_model_info.dart';
import '../provider/ai_provider.dart';

/// Catalog of known offline LLM models.
///
/// Provides a curated list of popular GGUF models that can be used
/// with the model registry. Models can be from bundled sources or
/// discovered from external catalogs like HuggingFace.
class ModelCatalog {
  ModelCatalog._();

  /// Gets the default/bundled model catalog.
  static List<OfflineModelInfo> get bundledModels => [
    // Google AI Edge Gallery style LiteRT-LM packages.
    const OfflineModelInfo(
      id: 'gemma-4-e2b-it-litertlm',
      name: 'Gemma-4-E2B-it',
      family: ModelFamily.gemma,
      fileSizeBytes: 2583085056,
      downloadUrl:
          'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm',
      quantization: ModelQuantization.q4,
      parameterCount: 2000000000,
      contextLength: 32000,
      supportsVision: true,
      credibility: ModelCredibility.official,
      provider: AIProvider.gemma,
      description:
          'Gallery Android allowlist package for chat, Prompt Lab, Agent Chat, image, and audio tasks.',
      author: 'Google',
      license: 'Apache-2.0',
      huggingFaceId: 'litert-community/gemma-4-E2B-it-litert-lm',
      modalities: [
        ModelModality.text,
        ModelModality.image,
        ModelModality.audio,
      ],
      capabilities: [
        ModelCapability.chat,
        ModelCapability.reasoning,
        ModelCapability.promptLab,
        ModelCapability.documents,
        ModelCapability.imageUnderstanding,
        ModelCapability.audioUnderstanding,
        ModelCapability.agentSkills,
        ModelCapability.benchmark,
      ],
      backendPreference: ModelBackendPreference.gpu,
      tags: ['gallery', 'litert-lm', 'chat', 'reasoning', 'prompt-lab'],
      minMemoryBytes: 3500000000,
      recommendedMemoryBytes: 4500000000,
      supportsWebRuntime: true,
      webAssetUrl:
          'https://storage.googleapis.com/mediapipe-models/llm_inference/gemma-4-e2b-it/float16/latest/gemma-4-e2b-it.task',
    ),
    const OfflineModelInfo(
      id: 'gemma-4-e4b-it-litertlm',
      name: 'Gemma-4-E4B-it',
      family: ModelFamily.gemma,
      fileSizeBytes: 3654467584,
      downloadUrl:
          'https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/resolve/main/gemma-4-E4B-it.litertlm',
      quantization: ModelQuantization.q4,
      parameterCount: 4000000000,
      contextLength: 32000,
      supportsVision: true,
      credibility: ModelCredibility.official,
      provider: AIProvider.gemma,
      description:
          'Higher-capability Gallery Android allowlist package for stronger devices.',
      author: 'Google',
      license: 'Apache-2.0',
      huggingFaceId: 'litert-community/gemma-4-E4B-it-litert-lm',
      modalities: [
        ModelModality.text,
        ModelModality.image,
        ModelModality.audio,
      ],
      capabilities: [
        ModelCapability.chat,
        ModelCapability.reasoning,
        ModelCapability.promptLab,
        ModelCapability.documents,
        ModelCapability.imageUnderstanding,
        ModelCapability.audioUnderstanding,
        ModelCapability.agentSkills,
        ModelCapability.benchmark,
      ],
      backendPreference: ModelBackendPreference.gpu,
      tags: ['gallery', 'litert-lm', 'high-capability', 'thinking'],
      minMemoryBytes: 5500000000,
      recommendedMemoryBytes: 7000000000,
      supportsWebRuntime: true,
      webAssetUrl:
          'https://storage.googleapis.com/mediapipe-models/llm_inference/gemma-4-e4b-it/float16/latest/gemma-4-e4b-it.task',
    ),
    const OfflineModelInfo(
      id: 'qwen2.5-1.5b-it-litert',
      name: 'Qwen2.5-1.5B-Instruct',
      family: ModelFamily.qwen,
      fileSizeBytes: 1597913616,
      downloadUrl:
          'https://huggingface.co/litert-community/Qwen2.5-1.5B-Instruct/resolve/main/Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv1280.task',
      quantization: ModelQuantization.q8,
      parameterCount: 1500000000,
      contextLength: 1280,
      credibility: ModelCredibility.official,
      provider: AIProvider.gguf,
      description:
          'LiteRT-community Qwen2.5-1.5B package with a confirmed MediaPipe '
          '.task bundle for on-device chat.',
      author: 'Alibaba / LiteRT Community',
      license: 'Apache-2.0',
      huggingFaceId: 'litert-community/Qwen2.5-1.5B-Instruct',
      languages: ['en', 'zh'],
      modalities: [ModelModality.text],
      capabilities: [
        ModelCapability.chat,
        ModelCapability.reasoning,
        ModelCapability.promptLab,
      ],
      backendPreference: ModelBackendPreference.cpu,
      tags: ['litert', 'chat', 'multilingual', 'web-capable'],
      minMemoryBytes: 2200000000,
      recommendedMemoryBytes: 3000000000,
      supportsWebRuntime: true,
      webAssetUrl:
          'https://huggingface.co/litert-community/Qwen2.5-1.5B-Instruct/resolve/main/Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv1280.task',
    ),
    const OfflineModelInfo(
      id: 'gemma-3n-e2b-it-litertlm',
      name: 'Gemma-3n-E2B-it',
      family: ModelFamily.gemma,
      fileSizeBytes: 3655827456,
      downloadUrl:
          'https://huggingface.co/google/gemma-3n-E2B-it-litert-lm/resolve/main/gemma-3n-E2B-it-int4.litertlm',
      quantization: ModelQuantization.q4,
      parameterCount: 2000000000,
      contextLength: 4096,
      supportsVision: true,
      credibility: ModelCredibility.official,
      provider: AIProvider.gemma,
      description:
          'Gallery Android allowlist package best suited for Ask Image and Audio Scribe workflows.',
      author: 'Google',
      license: 'Gemma',
      huggingFaceId: 'google/gemma-3n-E2B-it-litert-lm',
      modalities: [
        ModelModality.text,
        ModelModality.image,
        ModelModality.audio,
      ],
      capabilities: [
        ModelCapability.chat,
        ModelCapability.imageUnderstanding,
        ModelCapability.audioUnderstanding,
        ModelCapability.promptLab,
        ModelCapability.benchmark,
      ],
      backendPreference: ModelBackendPreference.gpu,
      tags: ['gallery', 'litert-lm', 'multimodal', 'image', 'audio'],
      licenseState: ModelLicenseState.gated,
      minMemoryBytes: 4200000000,
      recommendedMemoryBytes: 5500000000,
    ),
    const OfflineModelInfo(
      id: 'mobile-actions-270m-litertlm',
      name: 'MobileActions-270M',
      family: ModelFamily.gemma,
      fileSizeBytes: 288964608,
      downloadUrl:
          'https://huggingface.co/litert-community/functiongemma-270m-ft-mobile-actions/resolve/main/mobile_actions_q8_ekv1024.litertlm',
      quantization: ModelQuantization.q8,
      parameterCount: 270000000,
      contextLength: 1024,
      supportsFunctionCalling: true,
      credibility: ModelCredibility.official,
      provider: AIProvider.gemma,
      description:
          'Gallery Android allowlist package fine-tuned for offline mobile actions.',
      author: 'Google',
      license: 'Apache-2.0',
      huggingFaceId: 'litert-community/functiongemma-270m-ft-mobile-actions',
      modalities: [ModelModality.text, ModelModality.toolCall],
      capabilities: [ModelCapability.mobileActions, ModelCapability.benchmark],
      backendPreference: ModelBackendPreference.cpu,
      tags: ['gallery', 'function-calling', 'actions', 'small'],
      minMemoryBytes: 700000000,
      recommendedMemoryBytes: 1000000000,
    ),

    // Gemma 2B models (small, mobile-friendly)
    const OfflineModelInfo(
      id: 'gemma-2b-it-q4',
      name: 'Gemma 2B Instruct',
      family: ModelFamily.gemma,
      fileSizeBytes: 1500000000, // ~1.5 GB
      downloadUrl:
          'https://huggingface.co/google/gemma-2b-it-GGUF/resolve/main/gemma-2b-it-q4_k_m.gguf',
      quantization: ModelQuantization.q4,
      parameterCount: 2000000000,
      contextLength: 8192,
      credibility: ModelCredibility.official,
      provider: AIProvider.gemma,
      description:
          'Google Gemma 2B instruction-tuned model. '
          'Compact and efficient for mobile devices.',
      author: 'Google',
      license: 'Apache-2.0',
      huggingFaceId: 'google/gemma-2b-it-GGUF',
      modalities: [ModelModality.text],
      capabilities: [
        ModelCapability.chat,
        ModelCapability.promptLab,
        ModelCapability.documents,
      ],
      tags: ['chat', 'instruction', 'small', 'mobile-friendly'],
    ),

    // Phi-3 Mini (Microsoft's small model)
    const OfflineModelInfo(
      id: 'phi-3-mini-4k-q4',
      name: 'Phi-3 Mini 4K',
      family: ModelFamily.phi,
      fileSizeBytes: 2300000000, // ~2.3 GB
      downloadUrl:
          'https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf/resolve/main/Phi-3-mini-4k-instruct-q4.gguf',
      quantization: ModelQuantization.q4,
      parameterCount: 3800000000,
      contextLength: 4096,
      credibility: ModelCredibility.official,
      provider: AIProvider.phi,
      description:
          'Microsoft Phi-3 Mini with 4K context. '
          'Excellent reasoning for its size.',
      author: 'Microsoft',
      license: 'MIT',
      huggingFaceId: 'microsoft/Phi-3-mini-4k-instruct-gguf',
      modalities: [ModelModality.text],
      capabilities: [
        ModelCapability.chat,
        ModelCapability.reasoning,
        ModelCapability.promptLab,
      ],
      tags: ['chat', 'instruction', 'reasoning', 'mobile-friendly'],
    ),

    // Llama 3.2 1B (Meta's smallest Llama)
    const OfflineModelInfo(
      id: 'llama-3.2-1b-q4',
      name: 'Llama 3.2 1B',
      family: ModelFamily.llama,
      fileSizeBytes: 700000000, // ~700 MB
      downloadUrl:
          'https://huggingface.co/meta-llama/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf',
      quantization: ModelQuantization.q4,
      parameterCount: 1000000000,
      contextLength: 8192,
      credibility: ModelCredibility.official,
      provider: AIProvider.llama,
      description: 'Meta Llama 3.2 1B. Ultra-compact for mobile.',
      author: 'Meta',
      license: 'Llama 3.2 Community',
      huggingFaceId: 'meta-llama/Llama-3.2-1B-Instruct-GGUF',
      modalities: [ModelModality.text],
      capabilities: [ModelCapability.chat, ModelCapability.promptLab],
      tags: ['chat', 'instruction', 'ultra-small', 'mobile-friendly'],
    ),

    // Llama 3.2 3B (balanced option)
    const OfflineModelInfo(
      id: 'llama-3.2-3b-q4',
      name: 'Llama 3.2 3B',
      family: ModelFamily.llama,
      fileSizeBytes: 2000000000, // ~2 GB
      downloadUrl:
          'https://huggingface.co/meta-llama/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf',
      quantization: ModelQuantization.q4,
      parameterCount: 3000000000,
      contextLength: 8192,
      credibility: ModelCredibility.official,
      provider: AIProvider.llama,
      description: 'Meta Llama 3.2 3B. Good balance of size and capability.',
      author: 'Meta',
      license: 'Llama 3.2 Community',
      huggingFaceId: 'meta-llama/Llama-3.2-3B-Instruct-GGUF',
      modalities: [ModelModality.text],
      capabilities: [
        ModelCapability.chat,
        ModelCapability.reasoning,
        ModelCapability.promptLab,
      ],
      tags: ['chat', 'instruction', 'balanced', 'mobile-friendly'],
    ),

    // Qwen2 1.5B (Alibaba's compact model)
    const OfflineModelInfo(
      id: 'qwen2-1.5b-q4',
      name: 'Qwen2 1.5B',
      family: ModelFamily.qwen,
      fileSizeBytes: 1100000000, // ~1.1 GB
      downloadUrl:
          'https://huggingface.co/Qwen/Qwen2-1.5B-Instruct-GGUF/resolve/main/qwen2-1_5b-instruct-q4_k_m.gguf',
      quantization: ModelQuantization.q4,
      parameterCount: 1500000000,
      contextLength: 32768,
      credibility: ModelCredibility.official,
      provider: AIProvider.gguf,
      description: 'Alibaba Qwen2 1.5B. Long context support.',
      author: 'Alibaba',
      license: 'Apache-2.0',
      huggingFaceId: 'Qwen/Qwen2-1.5B-Instruct-GGUF',
      languages: ['en', 'zh'],
      modalities: [ModelModality.text],
      capabilities: [
        ModelCapability.chat,
        ModelCapability.reasoning,
        ModelCapability.promptLab,
        ModelCapability.documents,
      ],
      tags: ['chat', 'instruction', 'long-context', 'multilingual'],
    ),

    // Mistral 7B (higher capability, needs more RAM)
    const OfflineModelInfo(
      id: 'mistral-7b-q4',
      name: 'Mistral 7B Instruct',
      family: ModelFamily.mistral,
      fileSizeBytes: 4100000000, // ~4.1 GB
      downloadUrl:
          'https://huggingface.co/mistralai/Mistral-7B-Instruct-v0.3-GGUF/resolve/main/mistral-7b-instruct-v0.3.Q4_K_M.gguf',
      quantization: ModelQuantization.q4,
      parameterCount: 7000000000,
      contextLength: 32768,
      credibility: ModelCredibility.official,
      provider: AIProvider.gguf,
      description: 'Mistral 7B Instruct v0.3. High capability, needs 6GB+ RAM.',
      author: 'Mistral AI',
      license: 'Apache-2.0',
      huggingFaceId: 'mistralai/Mistral-7B-Instruct-v0.3-GGUF',
      modalities: [ModelModality.text],
      capabilities: [
        ModelCapability.chat,
        ModelCapability.reasoning,
        ModelCapability.promptLab,
        ModelCapability.documents,
      ],
      tags: ['chat', 'instruction', 'high-capability', 'long-context'],
      minMemoryBytes: 5000000000,
      recommendedMemoryBytes: 6000000000,
    ),

    // SmolLM2 web (.task) bundle: litert-community publishes SmolLM2-135M
    // and SmolLM2-360M as .litertlm only (no .task file), and does not
    // publish a 1.7B variant at all, as of 2026-07-19. Re-check before
    // adding a web catalog entry for SmolLM2.
  ];

  /// Gets recommended models for mobile devices (< 3GB).
  static List<OfflineModelInfo> get mobileRecommended =>
      bundledModels.where((m) => m.fileSizeBytes < 3000000000).toList();

  /// Gets Gallery-style packages by capability.
  static List<OfflineModelInfo> byCapability(ModelCapability capability) =>
      bundledModels
          .where((model) => model.capabilities.contains(capability))
          .toList();

  /// Gets Gallery-style packages by modality.
  static List<OfflineModelInfo> byModality(ModelModality modality) =>
      bundledModels
          .where((model) => model.modalities.contains(modality))
          .toList();

  /// Gets models by family.
  static List<OfflineModelInfo> byFamily(ModelFamily family) =>
      bundledModels.where((m) => m.family == family).toList();

  /// Gets only official models.
  static List<OfflineModelInfo> get officialModels => bundledModels
      .where((m) => m.credibility == ModelCredibility.official)
      .toList();

  /// Gets only models with a confirmed MediaPipe web (.task) bundle.
  static List<OfflineModelInfo> get webRuntimeSupported => bundledModels
      .where((m) => m.supportsWebRuntime)
      .toList();
}
