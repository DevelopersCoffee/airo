import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/quest_models.dart';
import '../../domain/services/quest_service.dart';
import '../../domain/services/gemini_quest_service.dart';

/// Quest service provider - uses Gemini Nano when available, falls back to Fake
final questServiceProvider = Provider<QuestService>((ref) {
  // Try to use Gemini Nano service, fallback to Fake if not supported
  return GeminiQuestService();
});

/// Current quest provider
final currentQuestProvider = StateProvider<Quest?>((ref) {
  return null;
});

/// Quest list provider
final questListProvider = FutureProvider<List<Quest>>((ref) async {
  final service = ref.watch(questServiceProvider);
  return await service.listQuests();
});

/// Quest details provider
final questDetailsProvider = FutureProvider.family<Quest?, String>((
  ref,
  questId,
) async {
  final service = ref.watch(questServiceProvider);
  return await service.getQuest(questId);
});

/// Quest messages provider
final questMessagesProvider = StateProvider.family<List<QuestMessage>, String>((
  ref,
  questId,
) {
  return [];
});

/// Quest files provider
final questFilesProvider = StateProvider.family<List<QuestFile>, String>((
  ref,
  questId,
) {
  return [];
});

/// Quest reminders provider
final questRemindersProvider =
    StateProvider.family<List<QuestReminder>, String>((ref, questId) {
      return [];
    });

/// Create new quest
final createQuestProvider = FutureProvider.family<Quest, String>((
  ref,
  title,
) async {
  final service = ref.watch(questServiceProvider);
  final quest = await service.createQuest(title);
  ref.read(currentQuestProvider.notifier).state = quest;
  return quest;
});

/// Upload file to quest
final uploadFileProvider = FutureProvider.family<QuestFile, (String, String)>((
  ref,
  args,
) async {
  final (questId, filePath) = args;
  final service = ref.watch(questServiceProvider);

  // Create File object from path
  final file = await _getFileFromPath(filePath);
  final questFile = await service.uploadFile(questId, file);

  // Update files list
  final files = ref.read(questFilesProvider(questId));
  ref.read(questFilesProvider(questId).notifier).state = [...files, questFile];

  return questFile;
});

/// Process query with AI
final processQueryProvider = FutureProvider.family<String, (String, String)>((
  ref,
  args,
) async {
  final (questId, query) = args;
  final service = ref.watch(questServiceProvider);

  // Get file context if available
  final files = ref.read(questFilesProvider(questId));
  String? fileContext;
  if (files.isNotEmpty) {
    fileContext = files.first.extractedText;
  }

  final response = await service.processQuery(
    questId,
    query,
    fileContext: fileContext,
  );

  // Add user message
  final userMsg = QuestMessage(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    questId: questId,
    text: query,
    isUser: true,
    timestamp: DateTime.now(),
  );

  // Add AI response
  final aiMsg = QuestMessage(
    id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
    questId: questId,
    text: response,
    isUser: false,
    timestamp: DateTime.now(),
  );

  final messages = ref.read(questMessagesProvider(questId));
  ref.read(questMessagesProvider(questId).notifier).state = [
    ...messages,
    userMsg,
    aiMsg,
  ];

  return response;
});

/// Create reminder from AI response
final createReminderProvider =
    FutureProvider.family<QuestReminder, (String, String, String, DateTime)>((
      ref,
      args,
    ) async {
      final (questId, title, description, scheduledTime) = args;
      final service = ref.watch(questServiceProvider);

      final reminder = await service.createReminder(
        questId,
        title,
        description,
        scheduledTime,
      );

      // Update reminders list
      final reminders = ref.read(questRemindersProvider(questId));
      ref.read(questRemindersProvider(questId).notifier).state = [
        ...reminders,
        reminder,
      ];

      return reminder;
    });

/// Helper to get File from path
Future<dynamic> _getFileFromPath(String filePath) async {
  // This is a placeholder - in real implementation, use file_picker
  // For now, return a mock file object
  return _MockFile(filePath);
}

class _MockFile {
  final String path;
  _MockFile(this.path);

  Future<int> length() async => 1024 * 100; // 100KB mock size
}
