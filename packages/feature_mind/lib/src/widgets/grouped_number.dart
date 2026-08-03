/// Thousands separators.
///
/// 12481 is a number a person has to parse; 12,481 is one they can read at a
/// glance, and every surface that shows an op count is read at a glance.
String groupedNumber(int value) {
  final negative = value < 0;
  final digits = value.abs().toString();
  final buffer = StringBuffer(negative ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
