/// Core AI package for Airo
///
/// Contains LLM client abstractions, prompt management, and AI utilities.
library;

// AI Provider
export 'src/provider/ai_provider.dart';

// Device Capabilities
export 'src/device/device_capability_service.dart';
export 'src/device/memory_budget_manager.dart';
export 'src/device/memory_severity.dart';

// LLM Client
export 'src/llm/llm_client.dart';
export 'src/llm/llm_response.dart';
export 'src/llm/llm_config.dart';
export 'src/llm/gemini_nano_client.dart';
export 'src/llm/gemini_api_client.dart';
export 'src/llm/llm_router_impl.dart';

// GGUF Model Support
export 'src/llm/gguf_model_config.dart';
export 'src/llm/gguf_model_client.dart';
export 'src/llm/active_model_service.dart';

// Model Registry
export 'src/models/model_credibility.dart';
export 'src/models/offline_model_info.dart';
export 'src/registry/model_registry.dart';
export 'src/registry/model_catalog.dart';

// Model Download
export 'src/download/model_download_progress.dart';
export 'src/download/model_download_service.dart';

// Agent Skill Schemas
export 'src/skills/routine_dag_executor.dart';
export 'src/skills/skill_permission_engine.dart';
export 'src/skills/skill_schema.dart';

// Prompt Management
export 'src/prompts/prompt.dart';
export 'src/prompts/prompt_template.dart';

// Parsing
export 'src/parsing/json_parser.dart';

// Utilities
export 'src/utils/token_counter.dart';
