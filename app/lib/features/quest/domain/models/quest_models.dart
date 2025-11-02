import 'package:equatable/equatable.dart';

/// Quest file model - represents uploaded file
class QuestFile extends Equatable {
  final String id;
  final String name;
  final String path;
  final String mimeType;
  final int sizeBytes;
  final DateTime uploadedAt;
  final String? extractedText;

  const QuestFile({
    required this.id,
    required this.name,
    required this.path,
    required this.mimeType,
    required this.sizeBytes,
    required this.uploadedAt,
    this.extractedText,
  });

  QuestFile copyWith({
    String? id,
    String? name,
    String? path,
    String? mimeType,
    int? sizeBytes,
    DateTime? uploadedAt,
    String? extractedText,
  }) {
    return QuestFile(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      mimeType: mimeType ?? this.mimeType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      extractedText: extractedText ?? this.extractedText,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    path,
    mimeType,
    sizeBytes,
    uploadedAt,
    extractedText,
  ];
}

/// Quest message model - chat between user and AI
class QuestMessage extends Equatable {
  final String id;
  final String questId;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? fileId;
  final bool isError;

  const QuestMessage({
    required this.id,
    required this.questId,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.fileId,
    this.isError = false,
  });

  QuestMessage copyWith({
    String? id,
    String? questId,
    String? text,
    bool? isUser,
    DateTime? timestamp,
    String? fileId,
    bool? isError,
  }) {
    return QuestMessage(
      id: id ?? this.id,
      questId: questId ?? this.questId,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      fileId: fileId ?? this.fileId,
      isError: isError ?? this.isError,
    );
  }

  @override
  List<Object?> get props => [
    id,
    questId,
    text,
    isUser,
    timestamp,
    fileId,
    isError,
  ];
}

/// Quest reminder model - scheduled notification
class QuestReminder extends Equatable {
  final String id;
  final String questId;
  final String title;
  final String description;
  final DateTime scheduledTime;
  final bool isRecurring;
  final String? recurringPattern; // 'daily', 'weekly', 'monthly'
  final bool isActive;
  final DateTime createdAt;

  const QuestReminder({
    required this.id,
    required this.questId,
    required this.title,
    required this.description,
    required this.scheduledTime,
    this.isRecurring = false,
    this.recurringPattern,
    this.isActive = true,
    required this.createdAt,
  });

  QuestReminder copyWith({
    String? id,
    String? questId,
    String? title,
    String? description,
    DateTime? scheduledTime,
    bool? isRecurring,
    String? recurringPattern,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return QuestReminder(
      id: id ?? this.id,
      questId: questId ?? this.questId,
      title: title ?? this.title,
      description: description ?? this.description,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringPattern: recurringPattern ?? this.recurringPattern,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    questId,
    title,
    description,
    scheduledTime,
    isRecurring,
    recurringPattern,
    isActive,
    createdAt,
  ];
}

/// Quest session model - represents a quest conversation
class Quest extends Equatable {
  final String id;
  final String title;
  final String? description;
  final List<QuestFile> files;
  final List<QuestMessage> messages;
  final List<QuestReminder> reminders;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String status; // 'active', 'completed', 'archived'

  const Quest({
    required this.id,
    required this.title,
    this.description,
    this.files = const [],
    this.messages = const [],
    this.reminders = const [],
    required this.createdAt,
    this.updatedAt,
    this.status = 'active',
  });

  Quest copyWith({
    String? id,
    String? title,
    String? description,
    List<QuestFile>? files,
    List<QuestMessage>? messages,
    List<QuestReminder>? reminders,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? status,
  }) {
    return Quest(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      files: files ?? this.files,
      messages: messages ?? this.messages,
      reminders: reminders ?? this.reminders,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    files,
    messages,
    reminders,
    createdAt,
    updatedAt,
    status,
  ];
}
