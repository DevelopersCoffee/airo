abstract interface class SettingsValidator<T> {
  bool isValid(T value);
  String? get errorMessage;
}
