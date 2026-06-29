enum LogLevel {
  trace,
  debug,
  info,
  warning,
  error,
  fatal;
  
  bool operator >=(LogLevel other) => index >= other.index;
}
