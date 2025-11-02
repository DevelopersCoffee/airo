import 'dart:io';
import 'package:uuid/uuid.dart';
import '../models/quest_models.dart';
import 'quest_service.dart';
import '../../../../core/services/gemini_nano_service.dart';

/// Quest service implementation using Gemini Nano for AI processing
class GeminiQuestService implements QuestService {
  final Map<String, Quest> _quests = {};
  final GeminiNanoService _geminiNano = GeminiNanoService();
  static const uuid = Uuid();

  @override
  Future<Quest> createQuest(String title, {String? description}) async {
    final questId = uuid.v4();
    final quest = Quest(
      id: questId,
      title: title,
      description: description,
      createdAt: DateTime.now(),
    );
    _quests[questId] = quest;
    return quest;
  }

  @override
  Future<QuestFile> uploadFile(String questId, File file) async {
    final quest = _quests[questId];
    if (quest == null) throw Exception('Quest not found');

    final fileId = uuid.v4();
    final questFile = QuestFile(
      id: fileId,
      name: file.path.split('/').last,
      path: file.path,
      mimeType: _getMimeType(file.path),
      sizeBytes: await file.length(),
      uploadedAt: DateTime.now(),
    );

    // Update quest with new file
    final updatedFiles = [...quest.files, questFile];
    _quests[questId] = quest.copyWith(files: updatedFiles);

    return questFile;
  }

  @override
  Future<String> extractTextFromFile(QuestFile file) async {
    try {
      // For now, return file info
      // In production, use pdf_text or similar for PDF extraction
      return 'File: ${file.name}\nSize: ${file.sizeBytes} bytes\nType: ${file.mimeType}';
    } catch (e) {
      print('Error extracting text: $e');
      return '';
    }
  }

  @override
  Future<String> processQuery(
    String questId,
    String query, {
    String? fileContext,
  }) async {
    final quest = _quests[questId];
    if (quest == null) throw Exception('Quest not found');

    try {
      // Check if Gemini Nano is available
      if (await _geminiNano.isSupported()) {
        // Initialize if not already done
        if (!_geminiNano.isInitialized) {
          await _geminiNano.initialize();
        }

        // Build context from uploaded files
        String context = '';
        if (quest.files.isNotEmpty) {
          context = 'Files in this quest:\n';
          for (final file in quest.files) {
            context += '- ${file.name} (${file.mimeType})\n';
          }
          context += '\n';
        }

        if (fileContext != null) {
          context += 'File content:\n$fileContext\n\n';
        }

        // Process with Gemini Nano
        final systemPrompt = '''You are a helpful AI assistant. 
You help users with:
- Creating personalized diet plans
- Splitting bills fairly
- Filling out forms
- Answering questions about uploaded documents

Be concise, practical, and actionable in your responses.''';

        final response = await _geminiNano.processQuery(
          query,
          fileContext: context,
          systemPrompt: systemPrompt,
        );

        return response;
      } else {
        // Fallback to mock response if Gemini Nano not available
        return _generateMockResponse(query, fileContext);
      }
    } catch (e) {
      print('Error processing query with Gemini Nano: $e');
      // Fallback to mock response on error
      return _generateMockResponse(query, fileContext);
    }
  }

  @override
  Future<QuestReminder> createReminder(
    String questId,
    String title,
    String description,
    DateTime scheduledTime, {
    bool isRecurring = false,
    String? recurringPattern,
  }) async {
    final quest = _quests[questId];
    if (quest == null) throw Exception('Quest not found');

    final reminderId = uuid.v4();
    final reminder = QuestReminder(
      id: reminderId,
      questId: questId,
      title: title,
      description: description,
      scheduledTime: scheduledTime,
      isRecurring: isRecurring,
      recurringPattern: recurringPattern,
      createdAt: DateTime.now(),
    );

    final updatedReminders = [...quest.reminders, reminder];
    _quests[questId] = quest.copyWith(reminders: updatedReminders);

    return reminder;
  }

  @override
  Future<Quest?> getQuest(String questId) async {
    return _quests[questId];
  }

  @override
  Future<List<Quest>> listQuests({int limit = 20}) async {
    return _quests.values.toList().take(limit).toList();
  }

  @override
  Future<void> deleteQuest(String questId) async {
    _quests.remove(questId);
  }

  String _getMimeType(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'txt':
        return 'text/plain';
      case 'doc':
      case 'docx':
        return 'application/msword';
      default:
        return 'application/octet-stream';
    }
  }

  String _generateMockResponse(String query, String? fileContext) {
    String response = 'Based on your query: "$query"\n\n';

    if (query.toLowerCase().contains('diet')) {
      response += '''**7-Day Anti-Inflammatory Diet Plan**

**Monday:**
- Breakfast: Oatmeal with berries and almonds
- Lunch: Grilled salmon with quinoa and vegetables
- Dinner: Vegetable stir-fry with tofu

**Tuesday:**
- Breakfast: Greek yogurt with honey and walnuts
- Lunch: Chicken breast with sweet potato
- Dinner: Lentil soup with whole grain bread

**Reminders:**
- Drink 8 glasses of water daily
- Take omega-3 supplements
- Avoid processed foods
- Exercise 30 minutes daily''';
    } else {
      response += 'I\'ve processed your request. How can I help you further?';
    }

    return response;
  }

  /// Dispose Gemini Nano resources
  Future<void> dispose() async {
    await _geminiNano.dispose();
  }
}
