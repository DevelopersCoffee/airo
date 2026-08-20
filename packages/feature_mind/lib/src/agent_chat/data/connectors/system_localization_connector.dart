import 'dart:ui';

import '../../domain/models/agent_skill.dart';
import '../../domain/services/agent_connector.dart';

class SystemLocalizationConnector implements AgentConnector {
  SystemLocalizationConnector({Locale Function()? locale})
    : _locale = locale ?? (() => PlatformDispatcher.instance.locale);

  final Locale Function() _locale;

  @override
  String get name => 'read_system_localization';

  @override
  Set<SkillCapability> get requiredCapabilities => const {};

  @override
  Future<ConnectorResult> execute(Map<String, dynamic> arguments) async {
    final value = _locale();
    return ConnectorResult(
      data: {
        'language': value.languageCode,
        'country': value.countryCode ?? '',
        'locale': value.toLanguageTag(),
      },
    );
  }
}
