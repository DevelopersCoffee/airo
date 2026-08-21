/// Core AI package for Airo
///
/// Contains LLM client abstractions, prompt management, and AI utilities.
library;

// Runtime diagnostics are part of the framework API consumed by app-facing
// health and explainability surfaces. Re-export the backend-neutral trace
// contracts so feature packages do not depend on the native bridge directly.
export 'package:core_native/core_native.dart'
    show ExecutionTrace, ExecutionTraceEntry, ExecutionTraceEvent;

// AI Provider
export 'src/provider/ai_provider.dart';

// Device Capabilities
export 'src/device/device_capability_service.dart';
export 'src/device/device_capability_report.dart';
export 'src/device/memory_budget_manager.dart';
export 'src/device/memory_severity.dart';

// Device-tier gating + local/cloud routing (#1631, MIND-LLM-4)
export 'src/device_tier/llm_cloud_consent.dart';
export 'src/device_tier/llm_device_signals.dart';
export 'src/device_tier/llm_device_tier.dart';
export 'src/device_tier/llm_device_tier_policy.dart';
export 'src/device_tier/llm_local_cloud_router.dart';
export 'src/device_tier/llm_routing_decision.dart';
export 'src/device_tier/llm_routing_log.dart';
export 'src/device_tier/llm_thermal_policy.dart';
export 'src/device_tier/real_llm_device_signals_probe.dart';

export 'src/residency/model_residency_manager.dart';
export 'src/preload/model_preloader.dart';
export 'src/runtime/local_inference_runtime_adapter.dart';
export 'src/runtime/gemini_api_service.dart';
export 'src/runtime/gemini_nano_service.dart';
export 'src/runtime/litert_lm_service.dart';
export 'src/runtime/model_learn_more_launcher.dart';
export 'src/litert/litert_lm_runtime_adapter.dart';
export 'src/embeddings/embedding_client.dart';
export 'src/embeddings/embedding_service.dart';
export 'src/litert/litert_lm_execution_adapter.dart';
export 'src/litert/mediapipe_web_runtime_adapter.dart';

// LLM Client
export 'src/llm/llm_client.dart';
export 'src/llm/llm_response.dart';
export 'src/llm/llm_config.dart';
export 'src/llm/gemini_nano_client.dart';
export 'src/llm/gemini_api_client.dart';
export 'src/llm/llm_router_impl.dart';
export 'src/router/ai_router.dart';
export 'src/router/ai_task.dart';
export 'src/router/fallback_chain.dart';
export 'src/router/model_health_checker.dart';
export 'src/router/task_model_router.dart';

// GGUF Model Support
export 'src/llm/gguf_model_config.dart';
export 'src/llm/gguf_model_client.dart';
export 'src/llm/batch_generation_service.dart';
export 'src/llm/openai_compatible_client.dart';
export 'src/llm/openai_compatible_image_client.dart';
export 'src/llm/active_model_service.dart';
export 'src/client/safety_guardrails.dart';
export 'src/client/safety_filtered_client.dart';

// Model Registry
export 'src/models/model_credibility.dart';
export 'src/models/model_contract.dart';
export 'src/models/model_readiness_service.dart';
export 'src/models/model_runtime_profile.dart';
export 'src/models/offline_model_info.dart';
export 'src/registry/model_registry.dart';
export 'src/registry/model_catalog.dart';
export 'src/huggingface/huggingface_catalog_cache.dart';
export 'src/huggingface/huggingface_catalog_service.dart';

// Model Download
export 'src/download/model_download_progress.dart';
export 'src/download/model_download_service.dart';
export 'src/storage/model_storage_manager.dart';
export 'src/health/model_health_report.dart';

// Agent Skill Schemas
export 'src/skills/ai_trajectory_trace.dart';
export 'src/skills/routine_dag_executor.dart';
export 'src/skills/skill_adversarial_eval_harness.dart';
export 'src/skills/skill_permission_engine.dart';
export 'src/skills/skill_schema.dart';
export 'src/skills/skill_trigger_eval.dart';

// Prompt Management
export 'src/prompts/prompt.dart';
export 'src/prompts/prompt_template.dart';

// Reasoning reliability (Dart mirrors of airo_mind_reliability IDs)
export 'src/reliability/reasoning_reliability.dart';
export 'src/reliability/prompt_reliability.dart';
export 'src/reliability/prompt_registry.dart';

// Parsing
export 'src/parsing/json_parser.dart';

// Utilities
export 'src/utils/token_counter.dart';
export 'src/intelligent_model_manager/model_entry.dart';
export 'src/intelligent_model_manager/model_install_receipt.dart';
export 'src/intelligent_model_manager/intelligent_model_manager.dart';
export 'src/intelligent_model_manager/model_manager_contracts.dart';
export 'src/intelligence/intelligence_query.dart';
export 'src/intelligence/why_selected.dart';
