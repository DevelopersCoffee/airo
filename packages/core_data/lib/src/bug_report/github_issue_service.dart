import 'dart:convert';

import 'package:core_domain/core_domain.dart';
import 'package:dio/dio.dart';

import 'bug_report_model.dart';

/// Configuration for GitHub issue submission.
///
/// Supports two modes:
/// 1. **Direct GitHub API** - Uses token directly (for development/testing)
/// 2. **Backend Proxy** - Routes through your backend (recommended for production)
///
/// The backend proxy approach is more secure as the GitHub token is never
/// exposed in the app. Your backend handles authentication and can add
/// rate limiting, spam protection, and content sanitization.
class GitHubIssueConfig {
  /// GitHub repository owner (e.g., 'DevelopersCoffee')
  final String owner;

  /// GitHub repository name (e.g., 'airo_super_app')
  final String repo;

  /// GitHub Personal Access Token with `issues:write` permission.
  /// Only used when [proxyUrl] is not set.
  final String token;

  /// Optional backend proxy URL for secure token handling.
  /// When set, requests are sent to this endpoint instead of GitHub directly.
  /// The proxy should forward to GitHub API with proper authentication.
  ///
  /// Example: `https://api.yourbackend.com/create-github-issue`
  ///
  /// Expected proxy request body:
  /// ```json
  /// {
  ///   "title": "Issue title",
  ///   "body": "Issue body markdown",
  ///   "labels": ["bug", "user-reported"]
  /// }
  /// ```
  ///
  /// Expected proxy response (same as GitHub API):
  /// ```json
  /// {
  ///   "number": 123,
  ///   "html_url": "https://github.com/owner/repo/issues/123",
  ///   "title": "Issue title"
  /// }
  /// ```
  final String? proxyUrl;

  /// Optional API key for backend proxy authentication.
  /// Sent as `X-API-Key` header when using proxy mode.
  final String? proxyApiKey;

  /// Default labels to apply to all issues
  final List<String> defaultLabels;

  const GitHubIssueConfig({
    required this.owner,
    required this.repo,
    this.token = '',
    this.proxyUrl,
    this.proxyApiKey,
    this.defaultLabels = const ['user-reported', 'bug'],
  });

  /// Creates config from environment variables.
  /// Use --dart-define to inject at build time.
  ///
  /// Environment variables:
  /// - `GITHUB_ISSUE_OWNER` - Repository owner (default: 'DevelopersCoffee')
  /// - `GITHUB_ISSUE_REPO` - Repository name (default: 'airo_super_app')
  /// - `GITHUB_ISSUE_TOKEN` - GitHub PAT (for direct mode)
  /// - `GITHUB_ISSUE_PROXY_URL` - Backend proxy URL (for proxy mode)
  /// - `GITHUB_ISSUE_PROXY_API_KEY` - API key for proxy authentication
  factory GitHubIssueConfig.fromEnvironment() {
    return GitHubIssueConfig(
      owner: const String.fromEnvironment(
        'GITHUB_ISSUE_OWNER',
        defaultValue: 'DevelopersCoffee',
      ),
      repo: const String.fromEnvironment(
        'GITHUB_ISSUE_REPO',
        defaultValue: 'airo_super_app',
      ),
      token: const String.fromEnvironment('GITHUB_ISSUE_TOKEN'),
      proxyUrl: const String.fromEnvironment('GITHUB_ISSUE_PROXY_URL'),
      proxyApiKey: const String.fromEnvironment('GITHUB_ISSUE_PROXY_API_KEY'),
      defaultLabels: const ['user-reported', 'bug'],
    );
  }

  /// Direct GitHub API URL
  String get githubApiUrl => 'https://api.github.com/repos/$owner/$repo/issues';

  /// Whether to use backend proxy mode
  bool get useProxy => proxyUrl != null && proxyUrl!.isNotEmpty;

  /// The URL to use for API calls (proxy or direct GitHub)
  String get apiUrl => useProxy ? proxyUrl! : githubApiUrl;

  /// Whether the service is properly configured.
  /// Either direct mode (with token) or proxy mode (with proxy URL) must be set.
  bool get isConfigured => token.isNotEmpty || useProxy;
}

/// Response from GitHub issue creation.
class GitHubIssueResponse {
  final int issueNumber;
  final String htmlUrl;
  final String title;

  const GitHubIssueResponse({
    required this.issueNumber,
    required this.htmlUrl,
    required this.title,
  });

  factory GitHubIssueResponse.fromJson(Map<String, dynamic> json) {
    return GitHubIssueResponse(
      issueNumber: json['number'] as int,
      htmlUrl: json['html_url'] as String,
      title: json['title'] as String,
    );
  }
}

/// Service for submitting bug reports as GitHub issues.
///
/// Supports two modes:
/// 1. **Direct Mode** - Calls GitHub API directly with token
/// 2. **Proxy Mode** - Routes through backend proxy for secure token handling
class GitHubIssueService {
  final GitHubIssueConfig _config;
  final Dio _dio;

  GitHubIssueService({required GitHubIssueConfig config, Dio? dio})
    : _config = config,
      _dio = dio ?? Dio();

  /// Checks if the service is properly configured.
  bool get isConfigured => _config.isConfigured;

  /// Whether the service is using proxy mode.
  bool get isUsingProxy => _config.useProxy;

  /// Submits a bug report as a GitHub issue.
  Future<Result<GitHubIssueResponse>> submitBugReport(BugReport report) async {
    if (!isConfigured) {
      return const Failure(
        ServerFailure(
          message:
              'GitHub issue reporting is not configured. '
              'Set GITHUB_ISSUE_TOKEN or GITHUB_ISSUE_PROXY_URL.',
        ),
      );
    }

    try {
      final body = _formatIssueBody(report);
      final labels = _buildLabels(report);

      final requestData = {
        'title': '[User Report] ${report.title}',
        'body': body,
        'labels': labels,
      };

      final Response<Map<String, dynamic>> response;

      if (_config.useProxy) {
        // Proxy mode - send to backend proxy
        response = await _submitViaProxy(requestData);
      } else {
        // Direct mode - send to GitHub API
        response = await _submitDirectToGitHub(requestData);
      }

      // GitHub returns 201 for created, proxy might return 200 or 201
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          response.data != null) {
        return Success(GitHubIssueResponse.fromJson(response.data!));
      }

      return Failure(
        ServerFailure(
          message: 'Failed to create issue: ${response.statusCode}',
          statusCode: response.statusCode,
        ),
      );
    } on DioException catch (e) {
      return Failure(_mapDioException(e));
    } catch (e) {
      return Failure(UnexpectedFailure(message: e.toString(), cause: e));
    }
  }

  /// Submits issue directly to GitHub API.
  Future<Response<Map<String, dynamic>>> _submitDirectToGitHub(
    Map<String, dynamic> data,
  ) {
    return _dio.post<Map<String, dynamic>>(
      _config.githubApiUrl,
      options: Options(
        headers: {
          'Authorization': 'Bearer ${_config.token}',
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
          'Content-Type': 'application/json',
        },
      ),
      data: jsonEncode(data),
    );
  }

  /// Submits issue via backend proxy.
  Future<Response<Map<String, dynamic>>> _submitViaProxy(
    Map<String, dynamic> data,
  ) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    // Add API key if configured
    if (_config.proxyApiKey != null && _config.proxyApiKey!.isNotEmpty) {
      headers['X-API-Key'] = _config.proxyApiKey!;
    }

    return _dio.post<Map<String, dynamic>>(
      _config.proxyUrl!,
      options: Options(headers: headers),
      data: jsonEncode(data),
    );
  }

  String _formatIssueBody(BugReport report) {
    final buffer = StringBuffer();

    // Header with quick summary
    buffer.writeln('## 📋 Summary');
    buffer.writeln();
    buffer.writeln('| | |');
    buffer.writeln('|---|---|');
    buffer.writeln(
      '| **Severity** | ${report.severity.emoji} ${report.severity.label} |',
    );
    buffer.writeln('| **Category** | ${report.category.label} |');
    buffer.writeln('| **Platform** | ${report.deviceInfo.platform} |');
    buffer.writeln(
      '| **App Version** | ${report.deviceInfo.appVersion} (${report.deviceInfo.buildNumber}) |',
    );
    buffer.writeln();

    // User description
    buffer.writeln('## 📝 Description');
    buffer.writeln();
    buffer.writeln(report.description);
    buffer.writeln();

    // Steps to reproduce
    if (report.stepsToReproduce != null &&
        report.stepsToReproduce!.isNotEmpty) {
      buffer.writeln('## 🔄 Steps to Reproduce');
      buffer.writeln();
      buffer.writeln(report.stepsToReproduce);
      buffer.writeln();
    }

    // Screenshot (embedded as base64)
    if (report.screenshotBytes != null && report.screenshotBytes!.isNotEmpty) {
      buffer.writeln('## 📸 Screenshot');
      buffer.writeln();
      final base64Image = base64Encode(report.screenshotBytes!);
      // Check if the image is within reasonable size limits (~37KB base64 limit)
      if (base64Image.length < 50000) {
        buffer.writeln('![Screenshot](data:image/png;base64,$base64Image)');
      } else {
        buffer.writeln(
          '> ⚠️ Screenshot was too large to embed '
          '(${(report.screenshotBytes!.length / 1024).toStringAsFixed(1)} KB)',
        );
      }
      buffer.writeln();
    }

    // Device info in collapsible section
    buffer.writeln('<details>');
    buffer.writeln('<summary>📱 Device Information</summary>');
    buffer.writeln();
    buffer.writeln(report.deviceInfo.toMarkdown());
    buffer.writeln('</details>');
    buffer.writeln();

    // Stack trace in collapsible section
    if (report.stackTrace != null && report.stackTrace!.isNotEmpty) {
      buffer.writeln('<details>');
      buffer.writeln('<summary>🔍 Stack Trace</summary>');
      buffer.writeln();
      buffer.writeln('```log');
      buffer.writeln(report.stackTrace);
      buffer.writeln('```');
      buffer.writeln('</details>');
      buffer.writeln();
    }

    // Error logs in collapsible section
    if (report.errorLogs != null && report.errorLogs!.isNotEmpty) {
      buffer.writeln('<details>');
      buffer.writeln('<summary>📋 Application Logs</summary>');
      buffer.writeln();
      buffer.writeln('```log');
      // Limit logs to last 100 lines to avoid huge issues
      final logLines = report.errorLogs!.split('\n');
      if (logLines.length > 100) {
        buffer.writeln('... (${logLines.length - 100} earlier lines omitted)');
        buffer.writeln(logLines.skip(logLines.length - 100).join('\n'));
      } else {
        buffer.writeln(report.errorLogs);
      }
      buffer.writeln('```');
      buffer.writeln('</details>');
      buffer.writeln();
    }

    // Environment info
    buffer.writeln('## 🌍 Environment');
    buffer.writeln();
    buffer.writeln(
      '- **Build Type:** ${report.deviceInfo.isDebugMode ? '🔧 Debug' : '🚀 Release'}',
    );
    buffer.writeln('- **Submitted:** ${_formatDateTime(report.createdAt)}');
    buffer.writeln();

    // Footer
    buffer.writeln('---');
    buffer.writeln();
    buffer.writeln('*🤖 Auto-generated by Airo Super App Bug Reporter*');

    return buffer.toString();
  }

  /// Formats DateTime in a human-readable format.
  String _formatDateTime(DateTime dt) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} at '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')} UTC';
  }

  List<String> _buildLabels(BugReport report) {
    return [
      ..._config.defaultLabels,
      report.severity.githubLabel,
      report.category.githubLabel,
      'platform:${report.deviceInfo.platform.toLowerCase()}',
    ];
  }

  BaseFailure _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const NetworkFailure(message: 'Connection timeout');
      case DioExceptionType.connectionError:
        return const NetworkFailure(message: 'No internet connection');
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        if (statusCode == 401) {
          return const AuthFailure(message: 'Invalid GitHub token');
        }
        if (statusCode == 403) {
          return const PermissionFailure(
            message: 'GitHub token lacks required permissions',
          );
        }
        if (statusCode == 404) {
          return const NotFoundFailure(message: 'Repository not found');
        }
        if (statusCode == 422) {
          return ServerFailure(
            message: 'Invalid issue data: ${e.response?.data}',
            statusCode: statusCode,
          );
        }
        return ServerFailure(
          message: 'GitHub API error: $statusCode',
          statusCode: statusCode,
        );
      default:
        return UnexpectedFailure(message: e.message ?? 'Unknown error');
    }
  }
}
