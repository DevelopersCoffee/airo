import 'package:meta/meta.dart';

/// Represents a prompt message for LLM interaction
@immutable
class Prompt {
  const Prompt({
    required this.role,
    required this.content,
    this.name,
  });

  /// Creates a system prompt
  const Prompt.system(this.content)
      : role = PromptRole.system,
        name = null;

  /// Creates a user prompt
  const Prompt.user(this.content)
      : role = PromptRole.user,
        name = null;

  /// Creates an assistant prompt
  const Prompt.assistant(this.content)
      : role = PromptRole.assistant,
        name = null;

  /// Role of this message
  final PromptRole role;

  /// Content of the message
  final String content;

  /// Optional name for the message author
  final String? name;

  /// Converts to a map for API calls
  Map<String, dynamic> toMap() => {
        'role': role.name,
        'content': content,
        if (name != null) 'name': name,
      };

  @override
  String toString() => '${role.name}: $content';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Prompt &&
          other.role == role &&
          other.content == content &&
          other.name == name;

  @override
  int get hashCode => Object.hash(role, content, name);
}

/// Role of a prompt message
enum PromptRole {
  /// System instructions
  system,

  /// User input
  user,

  /// Assistant response
  assistant,
}

