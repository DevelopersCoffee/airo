import 'package:test/test.dart';
import 'package:core_ai/core_ai.dart';

void main() {
  group('AIProvider', () {
    test('has correct display names', () {
      expect(AIProvider.nano.displayName, 'Gemini Nano');
      expect(AIProvider.cloud.displayName, 'Gemini Cloud');
      expect(AIProvider.auto.displayName, 'Auto');
    });

    test('has correct short names', () {
      expect(AIProvider.nano.shortName, 'On-device AI');
      expect(AIProvider.cloud.shortName, 'Cloud AI');
      expect(AIProvider.auto.shortName, 'Smart Selection');
    });
  });

  group('AICapabilities', () {
    test('unavailable factory creates unavailable capabilities', () {
      final caps = AICapabilities.unavailable('Test reason');
      expect(caps.isAvailable, isFalse);
      expect(caps.errorMessage, 'Test reason');
    });

    test('fromCloud factory creates cloud capabilities', () {
      final caps = AICapabilities.fromCloud();
      expect(caps.isAvailable, isTrue);
      expect(caps.supportsStreaming, isTrue);
      expect(caps.supportsImages, isTrue);
      expect(caps.maxTokens, 8192);
    });

    test('copyWith creates modified copy', () {
      const caps = AICapabilities(isAvailable: true, maxTokens: 1024);
      final modified = caps.copyWith(maxTokens: 2048);
      expect(modified.maxTokens, 2048);
      expect(modified.isAvailable, isTrue);
    });
  });

  group('AIProviderStatus', () {
    test('isAvailable reflects capabilities', () {
      final status = AIProviderStatus(
        provider: AIProvider.nano,
        capabilities: const AICapabilities(isAvailable: true),
      );
      expect(status.isAvailable, isTrue);
    });

    test('copyWith creates modified copy', () {
      final status = AIProviderStatus(
        provider: AIProvider.nano,
        capabilities: const AICapabilities(isAvailable: true),
        isInitialized: false,
      );
      final modified = status.copyWith(isInitialized: true);
      expect(modified.isInitialized, isTrue);
      expect(modified.provider, AIProvider.nano);
    });
  });

  group('GenerationConfig', () {
    test('has sensible defaults', () {
      const config = GenerationConfig();
      expect(config.temperature, 0.7);
      expect(config.topK, 40);
      expect(config.maxOutputTokens, 1024);
    });

    test('copyWith creates modified copy', () {
      const config = GenerationConfig();
      final modified = config.copyWith(temperature: 0.5);
      expect(modified.temperature, 0.5);
      expect(modified.topK, 40);
    });
  });

  group('ChatMessage', () {
    test('user factory creates user message', () {
      final msg = ChatMessage.user('Hello');
      expect(msg.role, 'user');
      expect(msg.content, 'Hello');
    });

    test('assistant factory creates assistant message', () {
      final msg = ChatMessage.assistant('Hi there');
      expect(msg.role, 'assistant');
      expect(msg.content, 'Hi there');
    });

    test('system factory creates system message', () {
      final msg = ChatMessage.system('You are helpful');
      expect(msg.role, 'system');
      expect(msg.content, 'You are helpful');
    });
  });

  group('PromptTemplate', () {
    test('fullId includes version', () {
      const prompt = PromptTemplate(
        id: 'diet.coach',
        version: 1,
        name: 'Diet Coach',
        description: 'Diet coaching prompt',
        template: 'Help with {{goal}}',
      );
      expect(prompt.fullId, 'diet.coach.v1');
    });

    test('render replaces placeholders', () {
      const prompt = PromptTemplate(
        id: 'test',
        version: 1,
        name: 'Test',
        description: 'Test prompt',
        template: 'Hello {{name}}, your goal is {{goal}}',
      );
      final rendered = prompt.render({'name': 'John', 'goal': 'lose weight'});
      expect(rendered, 'Hello John, your goal is lose weight');
    });

    test('toJson and fromJson roundtrip', () {
      const prompt = PromptTemplate(
        id: 'test',
        version: 2,
        name: 'Test Prompt',
        description: 'A test',
        template: 'Template text',
        tags: ['test', 'example'],
      );
      final json = prompt.toJson();
      final restored = PromptTemplate.fromJson(json);
      expect(restored.id, prompt.id);
      expect(restored.version, prompt.version);
      expect(restored.tags, prompt.tags);
    });
  });

  group('PromptRegistry', () {
    test('register and get prompt', () {
      final registry = PromptRegistry();
      const prompt = PromptTemplate(
        id: 'test',
        version: 1,
        name: 'Test',
        description: 'Test',
        template: 'Template',
      );
      registry.register(prompt);
      expect(registry.get('test.v1'), prompt);
    });

    test('getLatest returns highest version', () {
      final registry = PromptRegistry();
      const v1 = PromptTemplate(
        id: 'test',
        version: 1,
        name: 'Test v1',
        description: 'Test',
        template: 'Template v1',
      );
      const v2 = PromptTemplate(
        id: 'test',
        version: 2,
        name: 'Test v2',
        description: 'Test',
        template: 'Template v2',
      );
      registry.register(v1);
      registry.register(v2);
      expect(registry.getLatest('test')?.version, 2);
    });
  });

  group('FakeLLMClient', () {
    test('isAvailable returns true by default', () async {
      final client = FakeLLMClient();
      expect(await client.isAvailable(), isTrue);
    });

    test('isAvailable returns false when simulating unavailable', () async {
      final client = FakeLLMClient(simulateUnavailable: true);
      expect(await client.isAvailable(), isFalse);
    });

    test('generateText returns default response', () async {
      final client = FakeLLMClient(defaultResponse: 'Test response');
      final result = await client.generateText('Hello');
      expect(result.isOk, isTrue);
      expect(result.getOrNull()?.content, 'Test response');
    });

    test('generateText returns prompt-specific response', () async {
      final client = FakeLLMClient(promptResponses: {'Hello': 'Hi there!'});
      final result = await client.generateText('Hello');
      expect(result.isOk, isTrue);
      expect(result.getOrNull()?.content, 'Hi there!');
    });

    test('generateText returns error when simulating error', () async {
      final client = FakeLLMClient(
        simulateError: true,
        errorMessage: 'Test error',
      );
      final result = await client.generateText('Hello');
      expect(result.isErr, isTrue);
    });

    test('tracks generateText calls', () async {
      final client = FakeLLMClient();
      await client.generateText('First');
      await client.generateText('Second');
      expect(client.generateTextCalls, ['First', 'Second']);
    });

    test('classify returns first category by default', () async {
      final client = FakeLLMClient();
      final result = await client.classify('text', ['cat1', 'cat2']);
      expect(result.isOk, isTrue);
      expect(result.getOrNull(), 'cat1');
    });

    test('classify returns configured response', () async {
      final client = FakeLLMClient(
        classificationResponses: {'spam text': 'spam'},
      );
      final result = await client.classify('spam text', ['spam', 'ham']);
      expect(result.isOk, isTrue);
      expect(result.getOrNull(), 'spam');
    });

    test('reset clears tracked calls', () async {
      final client = FakeLLMClient();
      await client.generateText('Test');
      await client.classify('Test', ['a']);
      client.reset();
      expect(client.generateTextCalls, isEmpty);
      expect(client.classifyCalls, isEmpty);
    });
  });

  group('AIRouter', () {
    test('uses onDeviceClient when onDevicePreferred and available', () async {
      final onDevice = FakeLLMClient(defaultResponse: 'On-device');
      final cloud = FakeLLMClient(defaultResponse: 'Cloud');

      final router = AIRouter(
        onDeviceClient: onDevice,
        cloudClient: cloud,
        config: const AIRouterConfig(
          defaultStrategy: AIRoutingStrategy.onDevicePreferred,
        ),
      );

      final result = await router.generateText('Test');
      expect(result.isOk, isTrue);
      expect(result.getOrNull()?.content, 'On-device');
    });

    test('falls back to cloud when onDevice unavailable', () async {
      final onDevice = FakeLLMClient(
        defaultResponse: 'On-device',
        simulateUnavailable: true,
      );
      final cloud = FakeLLMClient(defaultResponse: 'Cloud');

      final router = AIRouter(
        onDeviceClient: onDevice,
        cloudClient: cloud,
        config: const AIRouterConfig(
          defaultStrategy: AIRoutingStrategy.onDevicePreferred,
        ),
      );

      final result = await router.generateText('Test');
      expect(result.isOk, isTrue);
      expect(result.getOrNull()?.content, 'Cloud');
    });

    test('routes to cloud for long prompts', () async {
      final onDevice = FakeLLMClient(defaultResponse: 'On-device');
      final cloud = FakeLLMClient(defaultResponse: 'Cloud');

      final router = AIRouter(
        onDeviceClient: onDevice,
        cloudClient: cloud,
        config: const AIRouterConfig(
          defaultStrategy: AIRoutingStrategy.onDevicePreferred,
          onDeviceMaxPromptLength: 10,
        ),
      );

      final result = await router.generateText('This is a very long prompt');
      expect(result.isOk, isTrue);
      expect(result.getOrNull()?.content, 'Cloud');
    });

    test('cloudOnly strategy uses only cloud', () async {
      final onDevice = FakeLLMClient(defaultResponse: 'On-device');
      final cloud = FakeLLMClient(defaultResponse: 'Cloud');

      final router = AIRouter(
        onDeviceClient: onDevice,
        cloudClient: cloud,
        config: const AIRouterConfig(
          defaultStrategy: AIRoutingStrategy.cloudOnly,
        ),
      );

      final result = await router.generateText('Test');
      expect(result.isOk, isTrue);
      expect(result.getOrNull()?.content, 'Cloud');
    });

    test('returns error when no provider available', () async {
      final router = AIRouter(onDeviceClient: null, cloudClient: null);

      final result = await router.generateText('Test');
      expect(result.isErr, isTrue);
    });
  });

  group('PromptLogger', () {
    test('InMemoryPromptLogger logs entries', () async {
      final logger = InMemoryPromptLogger();

      final entry = PromptExecutionLog(
        executionId: 'test_1',
        promptId: 'diet.meal_analysis',
        promptVersion: 1,
        variables: {'meal': 'salad'},
        renderedPrompt: 'Analyze salad',
        response: 'Healthy choice!',
        success: true,
        durationMs: 100,
        timestamp: DateTime.now(),
        provider: 'nano',
      );

      await logger.log(entry);
      expect(logger.logs.length, 1);
      expect(logger.logs.first.promptId, 'diet.meal_analysis');
    });

    test('getLogsForPrompt filters by prompt ID', () async {
      final logger = InMemoryPromptLogger();
      final now = DateTime.now();

      await logger.log(
        PromptExecutionLog(
          executionId: '1',
          promptId: 'diet.meal_analysis',
          promptVersion: 1,
          variables: {},
          renderedPrompt: 'test',
          success: true,
          durationMs: 100,
          timestamp: now,
          provider: 'nano',
        ),
      );

      await logger.log(
        PromptExecutionLog(
          executionId: '2',
          promptId: 'finance.receipt_parse',
          promptVersion: 1,
          variables: {},
          renderedPrompt: 'test',
          success: true,
          durationMs: 100,
          timestamp: now,
          provider: 'cloud',
        ),
      );

      final dietLogs = await logger.getLogsForPrompt('diet.meal_analysis');
      expect(dietLogs.length, 1);
      expect(dietLogs.first.executionId, '1');
    });

    test('getFailedExecutions returns only failures', () async {
      final logger = InMemoryPromptLogger();
      final now = DateTime.now();

      await logger.log(
        PromptExecutionLog(
          executionId: '1',
          promptId: 'test',
          promptVersion: 1,
          variables: {},
          renderedPrompt: 'test',
          success: true,
          durationMs: 100,
          timestamp: now,
          provider: 'nano',
        ),
      );

      await logger.log(
        PromptExecutionLog(
          executionId: '2',
          promptId: 'test',
          promptVersion: 1,
          variables: {},
          renderedPrompt: 'test',
          success: false,
          errorMessage: 'Failed',
          durationMs: 100,
          timestamp: now,
          provider: 'nano',
        ),
      );

      final failures = await logger.getFailedExecutions();
      expect(failures.length, 1);
      expect(failures.first.executionId, '2');
    });

    test('PromptExecutionLog toJson and fromJson roundtrip', () {
      final now = DateTime.now();
      final entry = PromptExecutionLog(
        executionId: 'test_1',
        promptId: 'diet.meal_analysis',
        promptVersion: 1,
        variables: {'meal': 'salad'},
        renderedPrompt: 'Analyze salad',
        response: 'Healthy!',
        success: true,
        durationMs: 100,
        timestamp: now,
        provider: 'nano',
        metadata: {'key': 'value'},
      );

      final json = entry.toJson();
      final restored = PromptExecutionLog.fromJson(json);

      expect(restored.executionId, entry.executionId);
      expect(restored.promptId, entry.promptId);
      expect(restored.promptVersion, entry.promptVersion);
      expect(restored.success, entry.success);
      expect(restored.provider, entry.provider);
    });
  });

  group('DefaultPrompts', () {
    test('all prompts have valid IDs', () {
      for (final prompt in DefaultPrompts.all) {
        expect(prompt.id, isNotEmpty);
        expect(prompt.version, greaterThan(0));
      }
    });

    test('diet prompts exist', () {
      expect(DefaultPrompts.dietMealAnalysis.id, 'diet.meal_analysis');
      expect(DefaultPrompts.dietDailySummary.id, 'diet.daily_summary');
    });

    test('finance prompts exist', () {
      expect(DefaultPrompts.financeReceiptParse.id, 'finance.receipt_parse');
      expect(
        DefaultPrompts.financeSpendingAnalysis.id,
        'finance.spending_analysis',
      );
    });

    test('registerAll adds all prompts to registry', () {
      final registry = PromptRegistry();
      DefaultPrompts.registerAll(registry);

      expect(registry.getAll().length, DefaultPrompts.all.length);
      expect(registry.get('diet.meal_analysis.v1'), isNotNull);
      expect(registry.get('finance.receipt_parse.v1'), isNotNull);
    });
  });

  group('PromptExecutor', () {
    test('executes prompt and logs result', () async {
      final client = FakeLLMClient(defaultResponse: 'Test response');
      final logger = InMemoryPromptLogger();
      final executor = PromptExecutor(
        client: client,
        logger: logger,
        providerName: 'test',
      );

      const prompt = PromptTemplate(
        id: 'test',
        version: 1,
        name: 'Test',
        description: 'Test prompt',
        template: 'Hello {{name}}!',
      );

      final result = await executor.execute(prompt, {'name': 'World'});

      expect(result.isOk, isTrue);
      expect(result.getOrNull(), 'Test response');
      expect(logger.logs.length, 1);
      expect(logger.logs.first.renderedPrompt, 'Hello World!');
      expect(logger.logs.first.success, isTrue);
    });

    test('logs failures', () async {
      final client = FakeLLMClient(
        defaultResponse: 'Test',
        simulateError: true,
        errorMessage: 'Test error',
      );
      final logger = InMemoryPromptLogger();
      final executor = PromptExecutor(
        client: client,
        logger: logger,
        providerName: 'test',
      );

      const prompt = PromptTemplate(
        id: 'test',
        version: 1,
        name: 'Test',
        description: 'Test prompt',
        template: 'Test',
      );

      final result = await executor.execute(prompt, {});

      expect(result.isErr, isTrue);
      expect(logger.logs.length, 1);
      expect(logger.logs.first.success, isFalse);
    });
  });

  group('SafetyGuardrails', () {
    test('withDefaults creates guardrails with default rules', () {
      final guardrails = SafetyGuardrails.withDefaults();
      expect(guardrails.inputRules.length, greaterThan(0));
      expect(guardrails.outputRules.length, greaterThan(0));
    });

    test('NoMedicalAdviceRule blocks medical queries', () {
      final rule = NoMedicalAdviceRule();
      final result = rule.check('What medicine should I take for headache?');
      expect(result.isAllowed, isFalse);
      expect(result.blockedReason, contains('medical'));
    });

    test('NoMedicalAdviceRule allows non-medical queries', () {
      final rule = NoMedicalAdviceRule();
      final result = rule.check('What is the weather today?');
      expect(result.isAllowed, isTrue);
    });

    test('NoInvestmentAdviceRule blocks investment queries', () {
      final rule = NoInvestmentAdviceRule();
      final result = rule.check('Should I buy Bitcoin?');
      expect(result.isAllowed, isFalse);
      expect(result.blockedReason, contains('investment'));
    });

    test('PIIDetectionRule warns about email', () {
      final rule = PIIDetectionRule();
      final result = rule.check('My email is test@example.com');
      expect(result.isAllowed, isTrue);
      expect(result.warnings, isNotEmpty);
    });

    test('PIIDetectionRule warns about phone numbers', () {
      final rule = PIIDetectionRule();
      final result = rule.check('Call me at 555-123-4567');
      expect(result.isAllowed, isTrue);
      expect(result.warnings, isNotEmpty);
    });

    test('MaxLengthRule blocks long input', () {
      final rule = MaxLengthRule(maxLength: 10);
      final result = rule.check('This is a very long input');
      expect(result.isAllowed, isFalse);
    });

    test('checkInput returns error for blocked content', () {
      final guardrails = SafetyGuardrails.withDefaults();
      final result = guardrails.checkInput('What medicine should I take?');
      expect(result.isErr, isTrue);
    });

    test('checkInput returns Ok for allowed content', () {
      final guardrails = SafetyGuardrails.withDefaults();
      final result = guardrails.checkInput('What is the weather?');
      expect(result.isOk, isTrue);
    });
  });

  group('SafetyFilteredClient', () {
    test('blocks unsafe input', () async {
      final delegate = FakeLLMClient(defaultResponse: 'Response');
      final client = SafetyFilteredClient.withDefaults(delegate);

      final result = await client.generateText('What medicine should I take?');
      expect(result.isErr, isTrue);
      expect(delegate.generateTextCalls, isEmpty);
    });

    test('allows safe input', () async {
      final delegate = FakeLLMClient(defaultResponse: 'Response');
      final client = SafetyFilteredClient.withDefaults(delegate);

      final result = await client.generateText('What is the weather?');
      expect(result.isOk, isTrue);
      expect(delegate.generateTextCalls, hasLength(1));
    });

    test('filters chat messages', () async {
      final delegate = FakeLLMClient(defaultResponse: 'Response');
      final client = SafetyFilteredClient.withDefaults(delegate);

      final result = await client.chat([
        ChatMessage.user('What medicine should I take?'),
      ]);
      expect(result.isErr, isTrue);
    });

    test('allows safe chat messages', () async {
      final delegate = FakeLLMClient(defaultResponse: 'Response');
      final client = SafetyFilteredClient.withDefaults(delegate);

      final result = await client.chat([
        ChatMessage.user('Hello, how are you?'),
      ]);
      expect(result.isOk, isTrue);
    });
  });
}
