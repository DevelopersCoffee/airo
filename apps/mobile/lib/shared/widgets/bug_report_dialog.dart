import 'package:core_data/core_data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/platform/platform_config.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/screenshot_service.dart';

/// A dialog for submitting bug reports to GitHub.
///
/// Usage:
/// ```dart
/// BugReportDialog.show(context);
/// ```
class BugReportDialog extends StatefulWidget {
  /// Optional pre-filled error message (e.g., from error handler).
  final String? initialError;

  /// Optional pre-filled stack trace.
  final String? initialStackTrace;

  const BugReportDialog({super.key, this.initialError, this.initialStackTrace});

  /// Shows the bug report dialog.
  static Future<void> show(
    BuildContext context, {
    String? initialError,
    String? initialStackTrace,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BugReportDialog(
        initialError: initialError,
        initialStackTrace: initialStackTrace,
      ),
    );
  }

  @override
  State<BugReportDialog> createState() => _BugReportDialogState();
}

class _BugReportDialogState extends State<BugReportDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _stepsController = TextEditingController();

  BugSeverity _severity = BugSeverity.medium;
  BugCategory _category = BugCategory.other;
  bool _includeLogs = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  late final GitHubIssueService _issueService;
  PackageInfo? _packageInfo;

  // Screenshot capture
  Uint8List? _screenshotBytes;
  bool _isCompressingScreenshot = false;
  bool _wasCompressed = false;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _issueService = GitHubIssueService(
      config: GitHubIssueConfig.fromEnvironment(),
    );

    // Load package info for app version
    _loadPackageInfo();

    // Pre-fill error if provided
    if (widget.initialError != null) {
      _descriptionController.text =
          'Error encountered:\n${widget.initialError}';
      _category = BugCategory.crash;
      _severity = BugSeverity.high;
    }
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _packageInfo = info;
        });
      }
    } catch (e) {
      AppLogger.warning('Failed to load package info: $e', tag: 'BUG_REPORT');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _stepsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.bug_report, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          const Text('Report a Bug'),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_issueService.isConfigured) ...[
                  _buildConfigWarning(theme),
                  const SizedBox(height: 16),
                ],
                _buildTitleField(),
                const SizedBox(height: 16),
                _buildDescriptionField(),
                const SizedBox(height: 16),
                _buildStepsField(),
                const SizedBox(height: 16),
                _buildSeverityDropdown(),
                const SizedBox(height: 16),
                _buildCategoryDropdown(),
                const SizedBox(height: 16),
                _buildIncludeLogsSwitch(),
                const SizedBox(height: 16),
                _buildScreenshotSection(theme),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  _buildErrorMessage(theme),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isSubmitting ? null : _submitReport,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send),
          label: Text(_isSubmitting ? 'Submitting...' : 'Submit'),
        ),
      ],
    );
  }

  Widget _buildConfigWarning(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Bug reporting is not configured. Contact support.',
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleField() {
    return TextFormField(
      controller: _titleController,
      decoration: const InputDecoration(
        labelText: 'Title *',
        hintText: 'Brief summary of the issue',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.title),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter a title';
        }
        if (value.length < 5) {
          return 'Title must be at least 5 characters';
        }
        return null;
      },
      textInputAction: TextInputAction.next,
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      decoration: const InputDecoration(
        labelText: 'Description *',
        hintText: 'What happened? What did you expect?',
        border: OutlineInputBorder(),
        alignLabelWithHint: true,
      ),
      maxLines: 4,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please describe the issue';
        }
        return null;
      },
    );
  }

  Widget _buildStepsField() {
    return TextFormField(
      controller: _stepsController,
      decoration: const InputDecoration(
        labelText: 'Steps to Reproduce (optional)',
        hintText: '1. Go to...\n2. Tap on...\n3. See error',
        border: OutlineInputBorder(),
        alignLabelWithHint: true,
      ),
      maxLines: 3,
    );
  }

  Widget _buildSeverityDropdown() {
    return DropdownButtonFormField<BugSeverity>(
      initialValue: _severity,
      decoration: const InputDecoration(
        labelText: 'Severity',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.priority_high),
      ),
      items: BugSeverity.values.map((severity) {
        return DropdownMenuItem(
          value: severity,
          child: Text('${severity.label} - ${severity.description}'),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) setState(() => _severity = value);
      },
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<BugCategory>(
      initialValue: _category,
      decoration: const InputDecoration(
        labelText: 'Category',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.category),
      ),
      items: BugCategory.values.map((category) {
        return DropdownMenuItem(
          value: category,
          child: Text('${category.label} - ${category.description}'),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) setState(() => _category = value);
      },
    );
  }

  Widget _buildIncludeLogsSwitch() {
    return SwitchListTile(
      title: const Text('Include app logs'),
      subtitle: const Text('Helps us diagnose the issue faster'),
      value: _includeLogs,
      onChanged: (value) => setState(() => _includeLogs = value),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildErrorMessage(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScreenshotSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Screenshot (optional)', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        if (_screenshotBytes != null) ...[
          // Screenshot preview
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  _screenshotBytes!,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton.filled(
                  onPressed: _removeScreenshot,
                  icon: const Icon(Icons.close, size: 18),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                    padding: const EdgeInsets.all(4),
                    minimumSize: const Size(28, 28),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildScreenshotSizeInfo(theme),
        ] else if (_isCompressingScreenshot) ...[
          // Compression progress
          const Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text('Compressing screenshot...'),
            ],
          ),
        ] else ...[
          // Capture buttons - camera and gallery
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _captureScreenshot(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _captureScreenshot(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildScreenshotSizeInfo(ThemeData theme) {
    if (_screenshotBytes == null) return const SizedBox.shrink();

    final sizeKb = (_screenshotBytes!.length / 1024).toStringAsFixed(1);
    final isTooLarge = _screenshotBytes!.length > 30 * 1024;

    String statusText;
    if (isTooLarge) {
      statusText = 'Screenshot is large ($sizeKb KB) - will be compressed';
    } else if (_wasCompressed) {
      statusText = 'Screenshot: $sizeKb KB (compressed)';
    } else {
      statusText = 'Screenshot: $sizeKb KB';
    }

    return Row(
      children: [
        Icon(
          isTooLarge ? Icons.warning : Icons.check_circle,
          size: 14,
          color: isTooLarge
              ? theme.colorScheme.error
              : theme.colorScheme.primary,
        ),
        const SizedBox(width: 4),
        Text(
          statusText,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isTooLarge
                ? theme.colorScheme.error
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Future<void> _captureScreenshot(ImageSource source) async {
    setState(() {
      _isCompressingScreenshot = true;
      _wasCompressed = false;
    });

    try {
      final image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );

      if (image != null) {
        var bytes = await image.readAsBytes();
        final originalSize = bytes.length;

        // Auto-compress if needed (not on web)
        if (!kIsWeb && !ScreenshotService.isWithinGitHubLimit(bytes)) {
          AppLogger.info(
            'Screenshot needs compression: ${(bytes.length / 1024).toStringAsFixed(1)} KB',
            tag: 'BUG_REPORT',
          );

          final compressed = await ScreenshotService.compressIfNeeded(bytes);
          if (compressed != null) {
            bytes = compressed;
            if (mounted) {
              setState(() {
                _wasCompressed = bytes.length < originalSize;
              });
            }
          }
        }

        if (mounted) {
          setState(() {
            _screenshotBytes = bytes;
            _isCompressingScreenshot = false;
          });
        }
      } else {
        // User cancelled
        if (mounted) {
          setState(() {
            _isCompressingScreenshot = false;
          });
        }
      }
    } catch (e) {
      AppLogger.warning('Failed to capture screenshot: $e', tag: 'BUG_REPORT');
      if (mounted) {
        setState(() {
          _isCompressingScreenshot = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add screenshot')),
        );
      }
    }
  }

  void _removeScreenshot() {
    setState(() {
      _screenshotBytes = null;
      _wasCompressed = false;
    });
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      // Use package info if available, otherwise use fallback values
      final appVersion = _packageInfo?.version ?? 'Unknown';
      final buildNumber = _packageInfo?.buildNumber ?? 'Unknown';

      final deviceInfo = BugReportDeviceInfo.current(
        appVersion: appVersion,
        buildNumber: buildNumber,
        additionalInfo: {
          'platformName': PlatformConfig.platformName,
          if (_packageInfo != null) ...{
            'appName': _packageInfo!.appName,
            'packageName': _packageInfo!.packageName,
          },
        },
      );

      final report = BugReport(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        severity: _severity,
        category: _category,
        deviceInfo: deviceInfo,
        stepsToReproduce: _stepsController.text.trim().isNotEmpty
            ? _stepsController.text.trim()
            : null,
        errorLogs: _includeLogs
            ? AppLogger.getRecentLogsAsString(count: 50)
            : null,
        stackTrace: widget.initialStackTrace,
        screenshotBytes: _screenshotBytes,
      );

      final result = await _issueService.submitBugReport(report);

      if (result.isSuccess) {
        if (mounted) {
          Navigator.of(context).pop();
          _showSuccessSnackbar(result.value);
        }
      } else {
        setState(() {
          _errorMessage = result.failure.message;
          _isSubmitting = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Unexpected error: $e';
        _isSubmitting = false;
      });
    }
  }

  void _showSuccessSnackbar(GitHubIssueResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Bug report #${response.issueNumber} submitted!'),
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () {
            // TODO: Open URL in browser using url_launcher
          },
        ),
      ),
    );
  }
}
