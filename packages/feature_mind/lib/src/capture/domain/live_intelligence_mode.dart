/// How live intelligence (Conversation IR + thermal/battery governor) behaves.
enum LiveIntelligenceMode {
  automatic(
    storageValue: 'automatic',
    menuLabel: 'Automatic',
    settingsSubtitle:
        'Follow device heat and battery. Insights pause only when the '
        'governor collapses to capture + STT.',
  ),
  preferFull(
    storageValue: 'prefer_full',
    menuLabel: 'Prefer full insights',
    settingsSubtitle:
        'Keep live insights on Warm/Low battery. Capture + STT still wins '
        'on critical heat or battery.',
  ),
  insightsOff(
    storageValue: 'insights_off',
    menuLabel: 'Transcript only',
    settingsSubtitle:
        'Live transcript without Conversation IR. Recording is unchanged.',
  );

  const LiveIntelligenceMode({
    required this.storageValue,
    required this.menuLabel,
    required this.settingsSubtitle,
  });

  final String storageValue;
  final String menuLabel;
  final String settingsSubtitle;

  static const LiveIntelligenceMode fallback = automatic;

  bool get collectInsights => this != insightsOff;

  static LiveIntelligenceMode fromStorageValue(String? value) {
    return LiveIntelligenceMode.values.firstWhere(
      (mode) => mode.storageValue == value,
      orElse: () => fallback,
    );
  }
}
