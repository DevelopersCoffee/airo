import 'package:meta/meta.dart';

/// Template for generating prompts with variable substitution
@immutable
class PromptTemplate {
  const PromptTemplate({
    required this.template,
    required this.variables,
    this.version = '1.0',
    this.description,
  });

  /// The template string with {{variable}} placeholders
  final String template;

  /// List of expected variable names
  final List<String> variables;

  /// Version of this template for A/B testing
  final String version;

  /// Description of what this template does
  final String? description;

  /// Fills the template with the given values
  String fill(Map<String, String> values) {
    var result = template;
    for (final variable in variables) {
      final value = values[variable];
      if (value == null) {
        throw ArgumentError('Missing required variable: $variable');
      }
      result = result.replaceAll('{{$variable}}', value);
    }
    return result;
  }

  /// Validates that all required variables are provided
  bool validate(Map<String, String> values) =>
      variables.every((v) => values.containsKey(v));

  /// Gets missing variables from the provided values
  List<String> getMissingVariables(Map<String, String> values) =>
      variables.where((v) => !values.containsKey(v)).toList();

  @override
  String toString() => 'PromptTemplate(v$version, vars: $variables)';
}

/// Common prompt templates for Airo
abstract final class AiroPrompts {
  /// Receipt parsing prompt
  static const receiptParsing = PromptTemplate(
    template: '''
Extract the following information from this receipt text:
- Store name
- Date
- Items with prices
- Subtotal
- Tax
- Total

Receipt text:
{{receipt_text}}

Respond in JSON format.
''',
    variables: ['receipt_text'],
    version: '1.0',
    description: 'Parses receipt text to extract structured data',
  );

  /// Bill splitting prompt
  static const billSplit = PromptTemplate(
    template: '''
Given the following receipt items and participants, suggest a fair split:

Items: {{items}}
Participants: {{participants}}

Consider:
- Shared items should be split evenly
- Individual items assigned to specific people
- Tax and tip should be distributed proportionally

Respond in JSON format with each person's share.
''',
    variables: ['items', 'participants'],
    version: '1.0',
    description: 'Suggests bill split among participants',
  );
}

