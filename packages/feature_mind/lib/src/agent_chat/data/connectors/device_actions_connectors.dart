import '../../../services/device_actions_service.dart';
import '../../domain/models/agent_skill.dart';
import '../../domain/services/agent_connector.dart';

class TurnOnFlashlightConnector implements AgentConnector {
  TurnOnFlashlightConnector({DeviceActionsService? service})
    : _service = service ?? DeviceActionsService();

  final DeviceActionsService _service;

  @override
  String get name => 'turn_on_flashlight';

  @override
  Set<SkillCapability> get requiredCapabilities => const {};

  @override
  Future<ConnectorResult> execute(Map<String, dynamic> arguments) async {
    final changed = await _service.setFlashlight(enabled: true);
    return ConnectorResult(
      data: {
        'action': 'turn_on_flashlight',
        'success': changed,
        'message': changed
            ? 'Turned the flashlight on.'
            : 'Could not turn the flashlight on.',
      },
      isError: !changed,
      errorCode: changed ? null : 'flashlight_failed',
      message: changed
          ? 'Turned the flashlight on.'
          : 'Could not turn the flashlight on.',
    );
  }
}

class TurnOffFlashlightConnector implements AgentConnector {
  TurnOffFlashlightConnector({DeviceActionsService? service})
    : _service = service ?? DeviceActionsService();

  final DeviceActionsService _service;

  @override
  String get name => 'turn_off_flashlight';

  @override
  Set<SkillCapability> get requiredCapabilities => const {};

  @override
  Future<ConnectorResult> execute(Map<String, dynamic> arguments) async {
    final changed = await _service.setFlashlight(enabled: false);
    return ConnectorResult(
      data: {
        'action': 'turn_off_flashlight',
        'success': changed,
        'message': changed
            ? 'Turned the flashlight off.'
            : 'Could not turn the flashlight off.',
      },
      isError: !changed,
      errorCode: changed ? null : 'flashlight_failed',
      message: changed
          ? 'Turned the flashlight off.'
          : 'Could not turn the flashlight off.',
    );
  }
}

class CreateContactConnector implements AgentConnector {
  CreateContactConnector({DeviceActionsService? service})
    : _service = service ?? DeviceActionsService();

  final DeviceActionsService _service;

  @override
  String get name => 'create_contact';

  @override
  Set<SkillCapability> get requiredCapabilities => const {};

  @override
  Future<ConnectorResult> execute(Map<String, dynamic> arguments) async {
    final name = (arguments['name'] as String?)?.trim();
    final phone = (arguments['phone'] as String?)?.trim();
    final email = (arguments['email'] as String?)?.trim();
    final opened = await _service.createContact(
      name: name,
      phone: phone,
      email: email,
    );
    return ConnectorResult(
      data: {
        'action': 'create_contact',
        'opened': opened,
        'message': opened
            ? 'Opened the contact form.'
            : 'Could not open the contact form.',
      },
      isError: !opened,
      errorCode: opened ? null : 'contact_form_failed',
      message: opened
          ? 'Opened the contact form.'
          : 'Could not open the contact form.',
    );
  }
}

class SendEmailConnector implements AgentConnector {
  SendEmailConnector({DeviceActionsService? service})
    : _service = service ?? DeviceActionsService();

  final DeviceActionsService _service;

  @override
  String get name => 'send_email';

  @override
  Set<SkillCapability> get requiredCapabilities => const {};

  @override
  Future<ConnectorResult> execute(Map<String, dynamic> arguments) async {
    final to =
        (arguments['to'] as String?)?.trim() ??
        (arguments['recipient'] as String?)?.trim();
    final subject = (arguments['subject'] as String?)?.trim();
    final body =
        (arguments['body'] as String?)?.trim() ??
        (arguments['message'] as String?)?.trim();
    final opened = await _service.composeEmail(
      to: to,
      subject: subject,
      body: body,
    );
    return ConnectorResult(
      data: {
        'action': 'send_email',
        'opened': opened,
        'message': opened
            ? 'Opened the email composer.'
            : 'Could not open the email composer.',
      },
      isError: !opened,
      errorCode: opened ? null : 'compose_email_failed',
      message: opened
          ? 'Opened the email composer.'
          : 'Could not open the email composer.',
    );
  }
}

class ShowMapConnector implements AgentConnector {
  ShowMapConnector({DeviceActionsService? service})
    : _service = service ?? DeviceActionsService();

  final DeviceActionsService _service;

  @override
  String get name => 'show_map';

  @override
  Set<SkillCapability> get requiredCapabilities => const {};

  @override
  Future<ConnectorResult> execute(Map<String, dynamic> arguments) async {
    final query =
        (arguments['query'] as String?)?.trim() ??
        (arguments['location'] as String?)?.trim() ??
        (arguments['address'] as String?)?.trim();
    final opened = await _service.openMap(query: query);
    return ConnectorResult(
      data: {
        'action': 'show_map',
        'opened': opened,
        'message': opened ? 'Opened the map.' : 'Could not open the map.',
      },
      isError: !opened,
      errorCode: opened ? null : 'open_map_failed',
      message: opened ? 'Opened the map.' : 'Could not open the map.',
    );
  }
}

class OpenWifiSettingsConnector implements AgentConnector {
  OpenWifiSettingsConnector({DeviceActionsService? service})
    : _service = service ?? DeviceActionsService();

  final DeviceActionsService _service;

  @override
  String get name => 'open_wifi_settings';

  @override
  Set<SkillCapability> get requiredCapabilities => const {};

  @override
  Future<ConnectorResult> execute(Map<String, dynamic> arguments) async {
    final opened = await _service.openWifiSettings();
    return ConnectorResult(
      data: {
        'action': 'open_wifi_settings',
        'opened': opened,
        'message': opened
            ? 'Opened Wi-Fi settings.'
            : 'Could not open Wi-Fi settings.',
      },
      isError: !opened,
      errorCode: opened ? null : 'open_wifi_settings_failed',
      message: opened
          ? 'Opened Wi-Fi settings.'
          : 'Could not open Wi-Fi settings.',
    );
  }
}

List<AgentConnector> createDeviceActionConnectors({
  DeviceActionsService? service,
}) {
  final svc = service ?? DeviceActionsService();
  return [
    TurnOnFlashlightConnector(service: svc),
    TurnOffFlashlightConnector(service: svc),
    CreateContactConnector(service: svc),
    SendEmailConnector(service: svc),
    ShowMapConnector(service: svc),
    OpenWifiSettingsConnector(service: svc),
  ];
}
