/// Core AI package for Airo
///
/// Contains LLM client abstractions, prompt management, and AI utilities.
library core_ai;

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

// Prompt Management
export 'src/prompts/prompt.dart';
export 'src/prompts/prompt_template.dart';

// Parsing
export 'src/parsing/json_parser.dart';

// Utilities
export 'src/utils/token_counter.dart';
