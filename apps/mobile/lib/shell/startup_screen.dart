import 'package:flutter/material.dart';
import 'package:design_system/core_ui.dart';
import '../version/app_version.dart';

class StartupScreen extends StatelessWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Fake logo since assets aren't all wired for Program 0 yet
            const Icon(Icons.rocket_launch, size: 80, color: AppColors.primary),
            const SizedBox(height: 32),
            Text(
              'AIRO',
              style: AppTypography.headlineLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Platform ${AppVersion.platformVersion}',
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: 64),
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'Initializing Platform...',
              style: AppTypography.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
