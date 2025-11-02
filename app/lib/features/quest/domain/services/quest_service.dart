import 'dart:io';
import 'package:uuid/uuid.dart';
import '../models/quest_models.dart';

/// Quest service interface
abstract interface class QuestService {
  /// Create a new quest session
  Future<Quest> createQuest(String title, {String? description});

  /// Upload file to quest
  Future<QuestFile> uploadFile(String questId, File file);

  /// Extract text from file (PDF, image, etc.)
  Future<String> extractTextFromFile(QuestFile file);

  /// Process user query with AI
  Future<String> processQuery(String questId, String query, {String? fileContext});

  /// Create reminder from AI response
  Future<QuestReminder> createReminder(
    String questId,
    String title,
    String description,
    DateTime scheduledTime, {
    bool isRecurring = false,
    String? recurringPattern,
  });

  /// Get quest by ID
  Future<Quest?> getQuest(String questId);

  /// List all quests
  Future<List<Quest>> listQuests({int limit = 20});

  /// Delete quest
  Future<void> deleteQuest(String questId);
}

/// Fake implementation for development
class FakeQuestService implements QuestService {
  final Map<String, Quest> _quests = {};
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
    // Simulate text extraction
    await Future.delayed(const Duration(milliseconds: 500));
    return 'Extracted text from ${file.name}:\n\nThis is sample extracted content from your file.';
  }

  @override
  Future<String> processQuery(String questId, String query, {String? fileContext}) async {
    final quest = _quests[questId];
    if (quest == null) throw Exception('Quest not found');

    // Simulate AI processing
    await Future.delayed(const Duration(seconds: 1));

    // Generate sample response based on query
    String response = 'Based on your query: "$query"\n\n';

    if (query.toLowerCase().contains('diet')) {
      response += '''
**7-Day Anti-Inflammatory Diet Plan**

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
- Exercise 30 minutes daily
''';
    } else if (query.toLowerCase().contains('plan')) {
      response += '''
**Action Plan Created**

1. Review uploaded document
2. Extract key information
3. Create personalized recommendations
4. Set up daily reminders
5. Track progress

Next steps: Would you like me to create reminders for this plan?
''';
    } else {
      response += 'I\'ve processed your request. How can I help you further?';
    }

    return response;
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

    // Update quest with new reminder
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
      default:
        return 'application/octet-stream';
    }
  }
}

