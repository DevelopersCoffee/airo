import 'log_context.dart';

abstract interface class LogContextProvider {
  LogContext get currentContext;
}
