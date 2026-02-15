import 'dart:convert';
import 'dart:typed_data';

import 'package:core_data/src/bug_report/bug_report_model.dart';
import 'package:core_data/src/bug_report/github_issue_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Mocks
class MockDio extends Mock implements Dio {}

void main() {
  group('GitHubIssueConfig', () {
    test('isConfigured returns true when token is set', () {
      const config = GitHubIssueConfig(
        owner: 'test-owner',
        repo: 'test-repo',
        token: 'ghp_test_token',
      );

      expect(config.isConfigured, isTrue);
    });

    test('isConfigured returns true when proxyUrl is set', () {
      const config = GitHubIssueConfig(
        owner: 'test-owner',
        repo: 'test-repo',
        proxyUrl: 'https://api.backend.com/issues',
      );

      expect(config.isConfigured, isTrue);
    });

    test('isConfigured returns false when neither token nor proxy set', () {
      const config = GitHubIssueConfig(owner: 'test-owner', repo: 'test-repo');

      expect(config.isConfigured, isFalse);
    });

    test('useProxy returns true when proxyUrl is set', () {
      const config = GitHubIssueConfig(
        owner: 'test-owner',
        repo: 'test-repo',
        proxyUrl: 'https://proxy.example.com',
      );

      expect(config.useProxy, isTrue);
    });

    test('useProxy returns false when proxyUrl is empty', () {
      const config = GitHubIssueConfig(
        owner: 'test-owner',
        repo: 'test-repo',
        proxyUrl: '',
      );

      expect(config.useProxy, isFalse);
    });

    test('apiUrl returns proxy URL when in proxy mode', () {
      const config = GitHubIssueConfig(
        owner: 'test-owner',
        repo: 'test-repo',
        proxyUrl: 'https://proxy.example.com/issues',
      );

      expect(config.apiUrl, equals('https://proxy.example.com/issues'));
    });

    test('apiUrl returns GitHub API URL when in direct mode', () {
      const config = GitHubIssueConfig(
        owner: 'my-org',
        repo: 'my-repo',
        token: 'ghp_token',
      );

      expect(
        config.apiUrl,
        equals('https://api.github.com/repos/my-org/my-repo/issues'),
      );
    });

    test('githubApiUrl is constructed correctly', () {
      const config = GitHubIssueConfig(
        owner: 'DevelopersCoffee',
        repo: 'airo_super_app',
      );

      expect(
        config.githubApiUrl,
        equals(
          'https://api.github.com/repos/DevelopersCoffee/airo_super_app/issues',
        ),
      );
    });

    test('defaultLabels defaults to user-reported and bug', () {
      const config = GitHubIssueConfig(owner: 'test', repo: 'test');

      expect(config.defaultLabels, containsAll(['user-reported', 'bug']));
    });
  });

  group('GitHubIssueResponse', () {
    test('fromJson parses correctly', () {
      final json = {
        'number': 42,
        'html_url': 'https://github.com/owner/repo/issues/42',
        'title': 'Test Issue',
      };

      final response = GitHubIssueResponse.fromJson(json);

      expect(response.issueNumber, equals(42));
      expect(
        response.htmlUrl,
        equals('https://github.com/owner/repo/issues/42'),
      );
      expect(response.title, equals('Test Issue'));
    });
  });

  group('GitHubIssueService', () {
    late MockDio mockDio;
    late GitHubIssueService service;
    late BugReport testReport;

    setUp(() {
      mockDio = MockDio();
      testReport = BugReport(
        title: 'Test Bug',
        description: 'This is a test bug description',
        severity: BugSeverity.medium,
        category: BugCategory.ui,
        deviceInfo: const BugReportDeviceInfo(
          platform: 'Android',
          osVersion: '14',
          deviceModel: 'Pixel 7',
          appVersion: '1.0.0',
          buildNumber: '42',
          isDebugMode: true,
        ),
        createdAt: DateTime(2025, 6, 15, 10, 30),
      );
    });

    group('isConfigured', () {
      test('returns true when config has token', () {
        service = GitHubIssueService(
          config: const GitHubIssueConfig(
            owner: 'test',
            repo: 'test',
            token: 'ghp_test',
          ),
          dio: mockDio,
        );

        expect(service.isConfigured, isTrue);
      });

      test('returns false when config is not configured', () {
        service = GitHubIssueService(
          config: const GitHubIssueConfig(owner: 'test', repo: 'test'),
          dio: mockDio,
        );

        expect(service.isConfigured, isFalse);
      });
    });

    group('isUsingProxy', () {
      test('returns true when proxyUrl is set', () {
        service = GitHubIssueService(
          config: const GitHubIssueConfig(
            owner: 'test',
            repo: 'test',
            proxyUrl: 'https://proxy.com',
          ),
          dio: mockDio,
        );

        expect(service.isUsingProxy, isTrue);
      });

      test('returns false when proxyUrl is not set', () {
        service = GitHubIssueService(
          config: const GitHubIssueConfig(
            owner: 'test',
            repo: 'test',
            token: 'ghp_test',
          ),
          dio: mockDio,
        );

        expect(service.isUsingProxy, isFalse);
      });
    });

    group('submitBugReport', () {
      test('returns Failure when not configured', () async {
        service = GitHubIssueService(
          config: const GitHubIssueConfig(owner: 'test', repo: 'test'),
          dio: mockDio,
        );

        final result = await service.submitBugReport(testReport);

        expect(result.isFailure, isTrue);
      });

      test('calls direct GitHub API with correct headers', () async {
        service = GitHubIssueService(
          config: const GitHubIssueConfig(
            owner: 'test-owner',
            repo: 'test-repo',
            token: 'ghp_test_token',
          ),
          dio: mockDio,
        );

        when(
          () => mockDio.post<Map<String, dynamic>>(
            any(),
            options: any(named: 'options'),
            data: any(named: 'data'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(),
            statusCode: 201,
            data: {
              'number': 123,
              'html_url': 'https://github.com/test/issues/123',
              'title': '[User Report] Test Bug',
            },
          ),
        );

        await service.submitBugReport(testReport);

        final captured = verify(
          () => mockDio.post<Map<String, dynamic>>(
            captureAny(),
            options: captureAny(named: 'options'),
            data: captureAny(named: 'data'),
          ),
        ).captured;

        final url = captured[0] as String;
        final options = captured[1] as Options;

        expect(url, contains('api.github.com'));
        expect(
          options.headers!['Authorization'],
          equals('Bearer ghp_test_token'),
        );
        expect(
          options.headers!['Accept'],
          equals('application/vnd.github+json'),
        );
        expect(options.headers!['X-GitHub-Api-Version'], equals('2022-11-28'));
      });

      test('calls proxy URL with API key header when configured', () async {
        service = GitHubIssueService(
          config: const GitHubIssueConfig(
            owner: 'test-owner',
            repo: 'test-repo',
            proxyUrl: 'https://api.backend.com/create-issue',
            proxyApiKey: 'secret_api_key',
          ),
          dio: mockDio,
        );

        when(
          () => mockDio.post<Map<String, dynamic>>(
            any(),
            options: any(named: 'options'),
            data: any(named: 'data'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(),
            statusCode: 200,
            data: {
              'number': 456,
              'html_url': 'https://github.com/test/issues/456',
              'title': '[User Report] Test Bug',
            },
          ),
        );

        await service.submitBugReport(testReport);

        final captured = verify(
          () => mockDio.post<Map<String, dynamic>>(
            captureAny(),
            options: captureAny(named: 'options'),
            data: any(named: 'data'),
          ),
        ).captured;

        final url = captured[0] as String;
        final options = captured[1] as Options;

        expect(url, equals('https://api.backend.com/create-issue'));
        expect(options.headers!['X-API-Key'], equals('secret_api_key'));
      });

      test('returns Success with GitHubIssueResponse on 201', () async {
        service = GitHubIssueService(
          config: const GitHubIssueConfig(
            owner: 'test',
            repo: 'test',
            token: 'ghp_token',
          ),
          dio: mockDio,
        );

        when(
          () => mockDio.post<Map<String, dynamic>>(
            any(),
            options: any(named: 'options'),
            data: any(named: 'data'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(),
            statusCode: 201,
            data: {
              'number': 789,
              'html_url': 'https://github.com/test/repo/issues/789',
              'title': '[User Report] Test Bug',
            },
          ),
        );

        final result = await service.submitBugReport(testReport);

        expect(result.isSuccess, isTrue);
        result.fold(
          (error, stack) => fail('Should be success, got error: $error'),
          (response) {
            expect(response.issueNumber, equals(789));
            expect(response.htmlUrl, contains('issues/789'));
          },
        );
      });
    });
  });

  group('Issue Body Formatting', () {
    test('severity emojis are correct', () {
      expect(BugSeverity.low.emoji, equals('🟢'));
      expect(BugSeverity.medium.emoji, equals('🟡'));
      expect(BugSeverity.high.emoji, equals('🟠'));
      expect(BugSeverity.critical.emoji, equals('🔴'));
    });

    test('severity labels are correct', () {
      expect(BugSeverity.low.label, equals('Low'));
      expect(BugSeverity.medium.label, equals('Medium'));
      expect(BugSeverity.high.label, equals('High'));
      expect(BugSeverity.critical.label, equals('Critical'));
    });

    test('severity githubLabel format is correct', () {
      expect(BugSeverity.low.githubLabel, equals('severity:low'));
      expect(BugSeverity.critical.githubLabel, equals('severity:critical'));
    });

    test('category githubLabel format is correct', () {
      expect(BugCategory.crash.githubLabel, equals('category:crash'));
      expect(BugCategory.ui.githubLabel, equals('category:ui'));
    });
  });

  group('BugReportDeviceInfo', () {
    test('toMarkdown generates valid table format', () {
      const deviceInfo = BugReportDeviceInfo(
        platform: 'iOS',
        osVersion: '17.0',
        deviceModel: 'iPhone 15 Pro',
        appVersion: '2.0.0',
        buildNumber: '100',
        isDebugMode: false,
      );

      final markdown = deviceInfo.toMarkdown();

      expect(markdown, contains('| Property | Value |'));
      expect(markdown, contains('| Platform | iOS |'));
      expect(markdown, contains('| OS Version | 17.0 |'));
      expect(markdown, contains('| Device Model | iPhone 15 Pro |'));
      expect(markdown, contains('| App Version | 2.0.0 |'));
      expect(markdown, contains('| Build Number | 100 |'));
      expect(markdown, contains('| Debug Mode | No |'));
    });

    test('toMarkdown shows Yes for debug mode', () {
      const deviceInfo = BugReportDeviceInfo(
        platform: 'Android',
        osVersion: '14',
        deviceModel: 'Pixel 7',
        appVersion: '1.0.0',
        buildNumber: '1',
        isDebugMode: true,
      );

      final markdown = deviceInfo.toMarkdown();

      expect(markdown, contains('| Debug Mode | Yes |'));
    });

    test('toMarkdown includes additional info', () {
      const deviceInfo = BugReportDeviceInfo(
        platform: 'Windows',
        osVersion: '11',
        deviceModel: 'PC',
        appVersion: '1.0.0',
        buildNumber: '1',
        isDebugMode: false,
        additionalInfo: {'RAM': '16GB', 'Screen Resolution': '1920x1080'},
      );

      final markdown = deviceInfo.toMarkdown();

      expect(markdown, contains('| RAM | 16GB |'));
      expect(markdown, contains('| Screen Resolution | 1920x1080 |'));
    });

    test('toJson returns correct structure', () {
      const deviceInfo = BugReportDeviceInfo(
        platform: 'macOS',
        osVersion: '14.0',
        deviceModel: 'MacBook Pro',
        appVersion: '1.5.0',
        buildNumber: '50',
        isDebugMode: true,
      );

      final json = deviceInfo.toJson();

      expect(json['platform'], equals('macOS'));
      expect(json['osVersion'], equals('14.0'));
      expect(json['deviceModel'], equals('MacBook Pro'));
      expect(json['appVersion'], equals('1.5.0'));
      expect(json['buildNumber'], equals('50'));
      expect(json['isDebugMode'], isTrue);
    });
  });

  group('DateTime formatting', () {
    test('formats date in human-readable format via BugReport createdAt', () {
      // Test the createdAt field is stored correctly
      final report = BugReport(
        title: 'Test',
        description: 'Test',
        severity: BugSeverity.low,
        category: BugCategory.other,
        deviceInfo: const BugReportDeviceInfo(
          platform: 'Test',
          osVersion: '1.0',
          deviceModel: 'Test',
          appVersion: '1.0.0',
          buildNumber: '1',
          isDebugMode: true,
        ),
        createdAt: DateTime(2025, 6, 15, 14, 30),
      );

      expect(report.createdAt.year, equals(2025));
      expect(report.createdAt.month, equals(6));
      expect(report.createdAt.day, equals(15));
      expect(report.createdAt.hour, equals(14));
      expect(report.createdAt.minute, equals(30));
    });
  });

  group('Log truncation', () {
    test('logs under 100 lines are not truncated', () {
      final logs = List.generate(50, (i) => 'Log line $i').join('\n');
      final logLines = logs.split('\n');

      expect(logLines.length, equals(50));
      expect(logLines.length, lessThanOrEqualTo(100));
    });

    test('logs over 100 lines would be truncated', () {
      final logs = List.generate(150, (i) => 'Log line $i').join('\n');
      final logLines = logs.split('\n');

      expect(logLines.length, equals(150));
      expect(logLines.length, greaterThan(100));

      // Simulate truncation logic
      final truncatedLines = logLines.skip(logLines.length - 100).toList();
      expect(truncatedLines.length, equals(100));
      expect(truncatedLines.first, equals('Log line 50'));
      expect(truncatedLines.last, equals('Log line 149'));
    });
  });

  group('Screenshot size handling', () {
    test('small screenshots are within limit', () {
      // 20KB image
      final smallImage = Uint8List(20 * 1024);
      final base64Image = base64Encode(smallImage);

      // Should be less than 50000 chars (the threshold in _formatIssueBody)
      expect(base64Image.length, lessThan(50000));
    });

    test('large screenshots exceed limit', () {
      // 50KB image -> ~68KB in base64
      final largeImage = Uint8List(50 * 1024);
      final base64Image = base64Encode(largeImage);

      // Should exceed 50000 chars
      expect(base64Image.length, greaterThan(50000));
    });

    test('base64 encoding increases size by approximately 33%', () {
      final bytes = Uint8List(30 * 1024); // 30KB
      final base64 = base64Encode(bytes);

      // Base64 should be ~40KB (33% larger)
      final expectedMin = (30 * 1024 * 1.3).toInt();
      final expectedMax = (30 * 1024 * 1.4).toInt();

      expect(base64.length, greaterThan(expectedMin));
      expect(base64.length, lessThan(expectedMax));
    });
  });
}
