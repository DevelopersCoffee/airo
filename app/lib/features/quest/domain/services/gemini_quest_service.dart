import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart'
    as ml_label;
import 'package:core_ai/core_ai.dart';

import '../models/quest_models.dart';
import 'quest_service.dart';

class QuestProcessingUnavailableException implements Exception {
  const QuestProcessingUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Quest service implementation using Gemini Nano for AI processing
class GeminiQuestService implements QuestService {
  final Map<String, Quest> _quests = {};
  final GeminiNanoService _geminiNano = GeminiNanoService();
  final Future<String> Function(File image)? _imageTextExtractor;
  static const uuid = Uuid();

  GeminiQuestService({this._imageTextExtractor});

  Future<String> _extractImageText(File image) async {
    final extractor = _imageTextExtractor;
    if (extractor != null) return extractor(image);
    if (!(Platform.isAndroid || Platform.isIOS)) {
      throw const QuestProcessingUnavailableException(
        'On-device image understanding is available on Android and iOS only.',
      );
    }

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final labeler = ml_label.ImageLabeler(
      options: ml_label.ImageLabelerOptions(confidenceThreshold: 0.5),
    );
    try {
      final result = await recognizer.processImage(InputImage.fromFile(image));
      var labels = const <ml_label.ImageLabel>[];
      try {
        labels = await labeler.processImage(
          ml_label.InputImage.fromFile(image),
        );
      } catch (error) {
        debugPrint('Local image labeling failed: $error');
      }
      final labelText = labels
          .map(
            (label) =>
                '${label.label} (${(label.confidence * 100).round()}% confidence)',
          )
          .join(', ');
      return [
        result.text.trim(),
        if (labelText.isNotEmpty) 'Objects: $labelText',
      ].where((part) => part.isNotEmpty).join('\n');
    } catch (error) {
      debugPrint('Local image text extraction failed: $error');
      return '';
    } finally {
      await recognizer.close();
      await labeler.close();
    }
  }

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
    final source = File(file.path);
    if (!await source.exists()) {
      throw const QuestProcessingUnavailableException(
        'The selected file is no longer available. Re-select it and try again.',
      );
    }
    if (file.mimeType == 'text/plain') {
      return source.readAsString();
    }
    throw QuestProcessingUnavailableException(
      'Text extraction is not available for ${file.name} yet. '
      'Use a supported text file or choose a runtime with document/vision support.',
    );
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
      final imageAttachments = quest.files
          .where((file) => file.mimeType.startsWith('image/'))
          .toList();
      final recognizedImageText = <String>[];
      for (final image in imageAttachments) {
        final text = await _extractImageText(File(image.path));
        if (text.isNotEmpty) {
          recognizedImageText.add('${image.name}:\n$text');
        }
      }
      if (!await _geminiNano.isSupported()) {
        throw const QuestProcessingUnavailableException(
          'No on-device inference runtime is available for this request. '
          'Enable Gemini Nano or install a compatible local model before asking Airo to analyze it.',
        );
      }
      if (!_geminiNano.isInitialized && !await _geminiNano.initialize()) {
        throw const QuestProcessingUnavailableException(
          'Gemini Nano could not initialize. Retry the local runtime or choose another supported model.',
        );
      }

      // Build context from uploaded files.
      String context = '';
      if (quest.files.isNotEmpty) {
        context = 'Files in this quest:\n';
        for (final file in quest.files) {
          context +=
              '- ${file.name} (${file.mimeType}, ${file.sizeBytes} bytes)\n';
        }
        context += '\n';
      }

      if (fileContext != null) {
        context += 'File content:\n$fileContext\n\n';
      } else if (quest.files.length == 1 &&
          quest.files.single.mimeType == 'text/plain') {
        context +=
            'File content:\n${await extractTextFromFile(quest.files.single)}\n\n';
      }

      if (imageAttachments.isNotEmpty) {
        if (recognizedImageText.isEmpty) {
          throw const QuestProcessingUnavailableException(
            'No readable text was found in the image. Local object understanding '
            'is not available in the selected runtime yet.',
          );
        }
        context +=
            'Text recognized locally from the attached image(s):\n'
            '${recognizedImageText.join('\n\n')}\n\n';
      }

      if (context.isNotEmpty) {
        context = ContextCompiler.wrapAsData(context);
      }

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
      if (response == null || response.trim().isEmpty) {
        throw const QuestProcessingUnavailableException(
          'The selected local runtime returned no answer. Retry or choose another supported model.',
        );
      }
      return response;
    } catch (e) {
      if (e is QuestProcessingUnavailableException) rethrow;
      throw QuestProcessingUnavailableException(
        'Local inference failed without producing an answer. Retry the runtime and try again. ($e)',
      );
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

  /// Dispose Gemini Nano resources
  Future<void> dispose() async {
    await _geminiNano.dispose();
  }
}
