final RegExp _ifscPattern = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');

/// Validates an Indian bank IFSC code: 4 letters, a literal '0', then 6
/// alphanumeric characters (e.g. `HDFC0001234`).
bool isValidIfsc(String value) => _ifscPattern.hasMatch(value);
