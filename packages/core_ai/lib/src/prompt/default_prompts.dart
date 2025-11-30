import 'prompt_template.dart';

/// Default prompts for the Airo super app.
///
/// These prompts are versioned and can be overridden by loading
/// from JSON/YAML files at runtime.
class DefaultPrompts {
  DefaultPrompts._();

  // ============================================
  // Diet & Nutrition Prompts
  // ============================================

  /// Diet coach prompt for meal analysis.
  static const dietMealAnalysis = PromptTemplate(
    id: 'diet.meal_analysis',
    version: 1,
    name: 'Meal Analysis',
    description: 'Analyze a meal for nutritional content and health impact',
    template: '''Analyze this meal for nutritional content:

Meal: {{meal_description}}
User goals: {{user_goals}}

Provide:
1. Estimated calories
2. Macronutrient breakdown (protein, carbs, fat)
3. Health assessment (1-10 scale)
4. Suggestions for improvement

Keep response concise and actionable.''',
    systemPrompt: 'You are a helpful nutrition assistant. Provide accurate, '
        'evidence-based nutritional advice. Never provide medical diagnoses.',
    outputFormat: 'text',
    maxTokens: 512,
    temperature: 0.7,
    tags: ['diet', 'nutrition', 'analysis'],
  );

  /// Diet coach prompt for daily summary.
  static const dietDailySummary = PromptTemplate(
    id: 'diet.daily_summary',
    version: 1,
    name: 'Daily Diet Summary',
    description: 'Generate a summary of daily food intake',
    template: '''Summarize today's nutrition:

Meals logged:
{{meals_list}}

Daily targets:
- Calories: {{target_calories}}
- Protein: {{target_protein}}g

Provide a brief summary with:
1. Total calories consumed
2. Progress toward goals
3. One actionable tip for tomorrow''',
    systemPrompt: 'You are a supportive nutrition coach. Be encouraging '
        'while providing honest feedback.',
    outputFormat: 'text',
    maxTokens: 256,
    temperature: 0.6,
    tags: ['diet', 'summary', 'daily'],
  );

  // ============================================
  // Finance Prompts
  // ============================================

  /// Receipt parsing prompt.
  static const financeReceiptParse = PromptTemplate(
    id: 'finance.receipt_parse',
    version: 1,
    name: 'Receipt Parser',
    description: 'Extract items and prices from receipt text',
    template: '''Extract items from this receipt:

{{receipt_text}}

Return a list of items with:
- Item name
- Quantity
- Price

Format as structured data.''',
    systemPrompt: 'You are a precise data extraction assistant. '
        'Extract only what is clearly visible in the receipt.',
    outputFormat: 'json',
    maxTokens: 1024,
    temperature: 0.1,
    tags: ['finance', 'receipt', 'extraction'],
  );

  /// Spending analysis prompt.
  static const financeSpendingAnalysis = PromptTemplate(
    id: 'finance.spending_analysis',
    version: 1,
    name: 'Spending Analysis',
    description: 'Analyze spending patterns and provide insights',
    template: '''Analyze this spending data:

Period: {{period}}
Total spent: {{total_amount}}
Categories:
{{category_breakdown}}

Provide:
1. Top spending categories
2. Unusual patterns
3. One saving suggestion

Keep response brief and actionable.''',
    systemPrompt: 'You are a helpful financial assistant. Provide practical '
        'advice without giving specific investment recommendations.',
    outputFormat: 'text',
    maxTokens: 384,
    temperature: 0.5,
    tags: ['finance', 'analysis', 'spending'],
  );

  // ============================================
  // General Assistant Prompts
  // ============================================

  /// General chat prompt.
  static const generalChat = PromptTemplate(
    id: 'general.chat',
    version: 1,
    name: 'General Chat',
    description: 'General purpose chat assistant',
    template: '{{user_message}}',
    systemPrompt: 'You are Airo, a helpful AI assistant. Be concise, '
        'friendly, and helpful. If asked about medical or financial advice, '
        'recommend consulting a professional.',
    outputFormat: 'text',
    maxTokens: 512,
    temperature: 0.8,
    tags: ['general', 'chat'],
  );

  /// Text summarization prompt.
  static const generalSummarize = PromptTemplate(
    id: 'general.summarize',
    version: 1,
    name: 'Text Summarizer',
    description: 'Summarize text content',
    template: '''Summarize the following text in {{max_sentences}} sentences:

{{text}}''',
    outputFormat: 'text',
    maxTokens: 256,
    temperature: 0.3,
    tags: ['general', 'summarize'],
  );

  /// Get all default prompts.
  static List<PromptTemplate> get all => [
        dietMealAnalysis,
        dietDailySummary,
        financeReceiptParse,
        financeSpendingAnalysis,
        generalChat,
        generalSummarize,
      ];

  /// Register all default prompts in a registry.
  static void registerAll(PromptRegistry registry) {
    for (final prompt in all) {
      registry.register(prompt);
    }
  }
}

