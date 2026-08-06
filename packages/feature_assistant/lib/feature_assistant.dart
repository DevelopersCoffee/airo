/// Airo Mind tab - AI assistant, models, prompt lab, and wellbeing.
library;

// Assistant hub + tools
export 'src/assistant/presentation/screens/assistant_screen.dart';
export 'src/assistant/presentation/screens/audio_scribe_screen.dart';
export 'src/assistant/presentation/screens/mobile_actions_screen.dart';
export 'src/assistant/presentation/screens/prompt_lab_screen.dart';

// Agent chat + model management
export 'src/agent_chat/application/assistant_model_preferences.dart';
export 'src/agent_chat/data/services/agent_notification_scheduler.dart';
export 'src/agent_chat/data/services/assistant_runtime_service.dart';
export 'src/agent_chat/data/services/chat_history_store.dart';
export 'src/agent_chat/data/services/notification_navigation_service.dart';
export 'src/agent_chat/domain/models/agent_skill.dart';
export 'src/agent_chat/domain/models/assistant_model_selection.dart';
export 'src/agent_chat/domain/models/assistant_runtime_ids.dart';
export 'src/agent_chat/domain/models/chat_models.dart';
export 'src/agent_chat/domain/models/chat_response_metadata.dart';
export 'src/agent_chat/domain/services/agent_skill_registry.dart';
export 'src/agent_chat/presentation/screens/agent_skills_screen.dart';
export 'src/agent_chat/presentation/screens/chat_screen.dart' hide ChatMessage;
export 'src/agent_chat/presentation/screens/device_capability_report_screen.dart';
export 'src/agent_chat/presentation/screens/model_advisor_screen.dart';
export 'src/agent_chat/presentation/screens/model_health_center_screen.dart';
export 'src/agent_chat/presentation/screens/model_library_screen.dart';
export 'src/agent_chat/presentation/screens/notifications_screen.dart';
export 'src/agent_chat/presentation/screens/profile_screen.dart';

// Wellbeing
export 'src/wellbeing/presentation/screens/wellbeing_screen.dart';

// Quotes
export 'src/quotes/presentation/widgets/daily_quote_card.dart';
export 'src/quotes/domain/models/quote_model.dart';
export 'src/quotes/domain/models/quote_preferences.dart';
export 'src/quotes/domain/services/quote_service.dart';
export 'src/quotes/application/providers/quote_provider.dart';

// Assistant-only services
export 'src/services/local_runtime_preloader_service.dart';
export 'src/services/model_preload_preferences.dart';
export 'src/services/voice_search_service.dart';
export 'src/services/device_actions_service.dart';
export 'src/services/llama_gguf_service.dart';
