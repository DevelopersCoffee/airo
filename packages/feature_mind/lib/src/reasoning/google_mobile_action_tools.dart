import 'package:core_ai/core_ai.dart';

import '../agent_chat/domain/services/agent_connector_registry.dart';
import '../services/device_actions_service.dart';
import 'reasoning_tool_loop.dart';

/// Catalog id of Google's published Mobile Actions fine-tune.
const kGoogleMobileActionsModelId = 'mobile-actions-270m-litertlm';

/// The seven tools in Google's Mobile Actions dataset.
///
/// Names and arguments match the published FunctionGemma fine-tune so that
/// package can call them. Each one opens a system screen or toggles the
/// torch. Airo-only actions stay out of this list.
const List<LiteRtLmToolSpec> kGoogleMobileActionToolSpecs = [
  LiteRtLmToolSpec(
    name: 'turn_on_flashlight',
    description: 'Turns the device flashlight on.',
    parameters: {'type': 'object', 'properties': <String, Object?>{}},
  ),
  LiteRtLmToolSpec(
    name: 'turn_off_flashlight',
    description: 'Turns the device flashlight off.',
    parameters: {'type': 'object', 'properties': <String, Object?>{}},
  ),
  LiteRtLmToolSpec(
    name: 'create_contact',
    description: 'Opens a new contact form.',
    parameters: {
      'type': 'object',
      'properties': {
        'first_name': {'type': 'string'},
        'last_name': {'type': 'string'},
        'phone_number': {'type': 'string'},
        'email': {'type': 'string'},
      },
      'required': ['first_name', 'last_name'],
    },
  ),
  LiteRtLmToolSpec(
    name: 'send_email',
    description: 'Opens an email composer.',
    parameters: {
      'type': 'object',
      'properties': {
        'to': {'type': 'string'},
        'subject': {'type': 'string'},
        'body': {'type': 'string'},
      },
      'required': ['to', 'subject'],
    },
  ),
  LiteRtLmToolSpec(
    name: 'show_map',
    description: 'Shows a location on the map.',
    parameters: {
      'type': 'object',
      'properties': {
        'query': {
          'type': 'string',
          'description': 'A place name, business, or address.',
        },
      },
      'required': ['query'],
    },
  ),
  LiteRtLmToolSpec(
    name: 'open_wifi_settings',
    description: 'Opens the Wi-Fi settings screen.',
    parameters: {'type': 'object', 'properties': <String, Object?>{}},
  ),
  LiteRtLmToolSpec(
    name: 'create_calendar_event',
    description: 'Creates a calendar event.',
    parameters: {
      'type': 'object',
      'properties': {
        'title': {'type': 'string'},
        'datetime': {
          'type': 'string',
          'description': 'Local date and time, YYYY-MM-DDTHH:MM:SS.',
        },
      },
      'required': ['title', 'datetime'],
    },
  ),
];

/// Maps Google's `datetime` onto the calendar connector's date and clock fields.
Map<String, Object?> googleCalendarArguments(Map<String, Object?> arguments) {
  final title = arguments['title']?.toString().trim() ?? '';
  final datetime = arguments['datetime']?.toString().trim() ?? '';
  final match = RegExp(
    r'^(\d{4}-\d{2}-\d{2})[T ](\d{2}):(\d{2})',
  ).firstMatch(datetime);
  if (match == null) {
    return {'title': title, 'datetime': datetime};
  }
  return {
    'title': title,
    'date': match.group(1),
    'hour': int.parse(match.group(2)!),
    'minute': int.parse(match.group(3)!),
  };
}

Future<String> executeGoogleMobileAction({
  required DeviceActionsService actions,
  required AgentConnectorRegistry registry,
  required String name,
  required Map<String, Object?> arguments,
}) async {
  final opened = switch (name) {
    'turn_on_flashlight' => await actions.setFlashlight(enabled: true),
    'turn_off_flashlight' => await actions.setFlashlight(enabled: false),
    'open_wifi_settings' => await actions.openWifiSettings(),
    'send_email' => await actions.composeEmail(
      to: arguments['to']?.toString(),
      subject: arguments['subject']?.toString(),
      body: arguments['body']?.toString(),
    ),
    'create_contact' => await actions.createContact(
      name: [
        arguments['first_name']?.toString().trim() ?? '',
        arguments['last_name']?.toString().trim() ?? '',
      ].where((part) => part.isNotEmpty).join(' '),
      phone: arguments['phone_number']?.toString(),
      email: arguments['email']?.toString(),
    ),
    'show_map' => await actions.openMap(query: arguments['query']?.toString()),
    'create_calendar_event' => null,
    _ => throw StateError('Tool $name is not a Google mobile action.'),
  };
  if (name == 'create_calendar_event') {
    return executeLiteRtLookupTool(
      registry: registry,
      name: name,
      arguments: googleCalendarArguments(arguments),
    );
  }
  if (opened == true) {
    return switch (name) {
      'turn_on_flashlight' => 'Turned the flashlight on.',
      'turn_off_flashlight' => 'Turned the flashlight off.',
      'open_wifi_settings' => 'Opened Wi-Fi settings.',
      'send_email' => 'Opened the email composer.',
      'create_contact' => 'Opened the contact form.',
      'show_map' => 'Opened the map.',
      _ => 'Completed the device action.',
    };
  }
  return 'Airo could not complete $name on this device.';
}
