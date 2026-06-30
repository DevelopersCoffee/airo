import 'package:platform_contracts/platform_contracts.dart';

abstract interface class ActivationManager {
  ExtensionLifecycle activate(String featureId);
  ExtensionLifecycle suspend(String featureId);
  ExtensionLifecycle deactivate(String featureId);
}
