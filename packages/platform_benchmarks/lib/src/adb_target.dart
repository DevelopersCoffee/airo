List<String> airoAdbArguments(String? deviceSerial, List<String> arguments) {
  final normalizedSerial = deviceSerial?.trim();
  if (normalizedSerial == null || normalizedSerial.isEmpty) {
    return arguments;
  }
  return ['-s', normalizedSerial, ...arguments];
}
