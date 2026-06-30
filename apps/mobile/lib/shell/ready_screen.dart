import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_core/platform_core.dart';
import 'package:design_system/core_ui.dart';
import '../version/app_version.dart';

class ReadyScreen extends ConsumerWidget {
  const ReadyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(bootstrapReportProvider);
    final tasks = report?.metrics.taskDurations.keys.toList() ?? [];
    
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AIRO', style: AppTypography.headlineLarge),
              Text('Platform Ready', style: AppTypography.headlineMedium.copyWith(color: AppColors.success)),
              
              const SizedBox(height: 32),
              
              _buildSection('Environment:', kDebugMode ? 'Debug' : (kProfileMode ? 'Profile' : 'Release')),
              _buildSection('Bootstrap:', '${tasks.length}/${tasks.length} Complete'),
              
              const SizedBox(height: 24),
              Text('Platform Packages', style: AppTypography.headlineSmall),
              const SizedBox(height: 12),
              
              // Hardcoded Core, Logging, Events, Settings since they might not be registered as separate Tasks
              // but we want to show them as requested by the user. Let's merge them with the dynamic list.
              ...['Core', 'Events', 'Settings', ...tasks.map(_capitalize)].map((pkg) => 
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                      const SizedBox(width: 12),
                      Text(pkg, style: AppTypography.bodyLarge),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),
              Text('Version', style: AppTypography.headlineSmall),
              const SizedBox(height: 8),
              _buildSection('Platform', AppVersion.platformVersion),
              _buildSection('Application', AppVersion.applicationVersion),
              _buildSection('Build', AppVersion.buildNumber),
            ],
          ),
        ),
      ),
    );
  }
  
  String _capitalize(String s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : s;

  Widget _buildSection(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.labelLarge.copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(value, style: AppTypography.bodyLarge),
        ],
      ),
    );
  }
}
