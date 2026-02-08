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
      tags: ['chat', 'instruction', 'high-capability', 'long-context'],
      minMemoryBytes: 5000000000,
      recommendedMemoryBytes: 6000000000,
    ),
  ];

  /// Gets recommended models for mobile devices (< 3GB).
  static List<OfflineModelInfo> get mobileRecommended =>
      bundledModels.where((m) => m.fileSizeBytes < 3000000000).toList();

  /// Gets models by family.
  static List<OfflineModelInfo> byFamily(ModelFamily family) =>
      bundledModels.where((m) => m.family == family).toList();

  /// Gets only official models.
  static List<OfflineModelInfo> get officialModels => bundledModels
      .where((m) => m.credibility == ModelCredibility.official)
      .toList();
}
