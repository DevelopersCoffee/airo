import 'package:flutter_test/flutter_test.dart';
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

    test('has correct descriptions', () {
      expect(AIProvider.nano.description, 'Local processing on your Pixel 9');
      expect(AIProvider.cloud.description, 'Powered by Google AI');
      expect(AIProvider.auto.description, 'Automatically choose best option');
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

  group('LLMConfig', () {
    test('has sensible defaults', () {
      const config = LLMConfig(provider: 'test');
      expect(config.temperature, 0.7);
      expect(config.topK, 40);
      expect(config.maxOutputTokens, 1024);
    });

    test('copyWith creates modified copy', () {
      const config = LLMConfig(provider: 'test');
      final modified = config.copyWith(temperature: 0.5);
      expect(modified.temperature, 0.5);
      expect(modified.topK, 40);
    });

    test('geminiNano static config has correct provider', () {
      expect(LLMConfig.geminiNano.provider, 'gemini-nano');
    });

    test('geminiApi factory creates config with API key', () {
      final config = LLMConfig.geminiApi(apiKey: 'test-key');
      expect(config.provider, 'gemini-api');
      expect(config.apiKey, 'test-key');
      expect(config.modelName, 'gemini-1.5-flash');
    });
  });

  group('LLMResponse', () {
    test('creates response with required fields', () {
      const response = LLMResponse(text: 'Hello', provider: 'test');
      expect(response.text, 'Hello');
      expect(response.provider, 'test');
    });

    test('calculates totalTokens when both are provided', () {
      const response = LLMResponse(
        text: 'Hello',
        provider: 'test',
        promptTokens: 10,
        completionTokens: 5,
      );
      expect(response.totalTokens, 15);
    });

    test('totalTokens is null when tokens not provided', () {
      const response = LLMResponse(text: 'Hello', provider: 'test');
      expect(response.totalTokens, isNull);
    });
  });

  group('MemorySeverity', () {
    test('canLoad returns true for safe, warning, and critical', () {
      expect(MemorySeverity.safe.canLoad, isTrue);
      expect(MemorySeverity.warning.canLoad, isTrue);
      expect(MemorySeverity.critical.canLoad, isTrue);
      expect(MemorySeverity.blocked.canLoad, isFalse);
    });

    test('shouldWarn returns true for warning and critical', () {
      expect(MemorySeverity.safe.shouldWarn, isFalse);
      expect(MemorySeverity.warning.shouldWarn, isTrue);
      expect(MemorySeverity.critical.shouldWarn, isTrue);
      expect(MemorySeverity.blocked.shouldWarn, isFalse);
    });

    test('isRisky returns true for critical and blocked', () {
      expect(MemorySeverity.safe.isRisky, isFalse);
      expect(MemorySeverity.warning.isRisky, isFalse);
      expect(MemorySeverity.critical.isRisky, isTrue);
      expect(MemorySeverity.blocked.isRisky, isTrue);
    });
  });

  group('MemoryInfo', () {
    test('calculates usedBytes correctly', () {
      const info = MemoryInfo(totalBytes: 1000, availableBytes: 400);
      expect(info.usedBytes, 600);
    });

    test('calculates usagePercent correctly', () {
      const info = MemoryInfo(totalBytes: 1000, availableBytes: 400);
      expect(info.usagePercent, 0.6);
    });

    test('fromMegabytes creates correct values', () {
      final info = MemoryInfo.fromMegabytes(totalMB: 8192, availableMB: 4096);
      expect(info.totalGB, closeTo(8.0, 0.01));
      expect(info.availableGB, closeTo(4.0, 0.01));
    });

    test('unknown factory creates empty info', () {
      final info = MemoryInfo.unknown();
      expect(info.isAvailable, isFalse);
      expect(info.totalBytes, 0);
    });
  });

  group('PromptTemplate', () {
    test('fill replaces placeholders', () {
      const template = PromptTemplate(
        template: 'Hello {{name}}, your goal is {{goal}}',
        variables: ['name', 'goal'],
      );
      final filled = template.fill({'name': 'John', 'goal': 'lose weight'});
      expect(filled, 'Hello John, your goal is lose weight');
    });

    test('validate returns true when all variables provided', () {
      const template = PromptTemplate(
        template: 'Hello {{name}}',
        variables: ['name'],
      );
      expect(template.validate({'name': 'John'}), isTrue);
    });

    test('validate returns false when variables missing', () {
      const template = PromptTemplate(
        template: 'Hello {{name}}',
        variables: ['name'],
      );
      expect(template.validate({}), isFalse);
    });

    test('getMissingVariables returns list of missing variables', () {
      const template = PromptTemplate(
        template: 'Hello {{name}}, goal: {{goal}}',
        variables: ['name', 'goal'],
      );
      final missing = template.getMissingVariables({'name': 'John'});
      expect(missing, ['goal']);
    });
  });

  group('AiroPrompts', () {
    test('receiptParsing template exists and has correct variables', () {
      expect(AiroPrompts.receiptParsing.variables, contains('receipt_text'));
    });

    test('billSplit template exists and has correct variables', () {
      expect(AiroPrompts.billSplit.variables, contains('items'));
      expect(AiroPrompts.billSplit.variables, contains('participants'));
    });
  });

  group('TokenCounter', () {
    test('estimates token count for text', () {
      final count = TokenCounter.estimate('Hello world');
      expect(count, greaterThan(0));
    });

    test('handles empty string', () {
      final count = TokenCounter.estimate('');
      expect(count, 0);
    });

    test('fitsInLimit returns true when text fits', () {
      expect(TokenCounter.fitsInLimit('Hello', 100), isTrue);
    });

    test('fitsInLimit returns false when text exceeds limit', () {
      expect(TokenCounter.fitsInLimit('Hello world', 1), isFalse);
    });
  });
}
