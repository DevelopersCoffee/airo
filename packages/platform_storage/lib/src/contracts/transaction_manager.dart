import 'package:platform_core/platform_core.dart';

abstract interface class TransactionManager {
  Future<T> transaction<T>(Future<T> Function() action);
}
