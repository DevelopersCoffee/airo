import 'package:flutter/material.dart';
import 'package:design_system/core_ui.dart';

class ErrorScreen extends StatelessWidget {
  final String error;
  final VoidCallback onRestart;

  const ErrorScreen({
    super.key,
    required this.error,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.error.withValues(alpha: 0.1),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 24),
              Text(
                'Fatal Error',
                style: AppTypography.headlineLarge.copyWith(color: AppColors.error),
              ),
              const SizedBox(height: 16),
              Text(
                'The platform failed to initialize.',
                style: AppTypography.bodyLarge,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error),
                ),
                child: Text(
                  error,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: onRestart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(56),
                ),
                child: const Text('Restart Initialization'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
