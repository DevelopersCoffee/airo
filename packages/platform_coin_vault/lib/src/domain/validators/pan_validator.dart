final RegExp _panPattern = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$');

/// Validates an Indian PAN number: 5 letters, 4 digits, 1 letter
/// (e.g. `ABCDE1234F`).
bool isValidPan(String value) => _panPattern.hasMatch(value);
