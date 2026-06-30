import 'package:platform_delegates/platform_delegates.dart';

abstract interface class DelegateAttachment {
  Future<void> attachDelegate(DelegateSelection delegate);
  Future<void> detachDelegate();
}
