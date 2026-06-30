import 'package:flutter/material.dart';
import 'app_host.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Global error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    // Future: report to platform_logging
  };

  runApp(const ApplicationHost());
}
