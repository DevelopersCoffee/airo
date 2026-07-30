import 'package:flutter/services.dart';

/// Small platform boundary for safe, user-visible device actions.
class DeviceActionsService {
  DeviceActionsService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.airo/device_info');

  final MethodChannel _channel;

  Future<bool> openWifiSettings() async {
    try {
      final result = await _channel.invokeMethod<Object?>('openWifiSettings');
      return result is Map && result['opened'] == true;
    } on Object {
      return false;
    }
  }

  Future<bool> setFlashlight({required bool enabled}) async {
    try {
      final result = await _channel.invokeMethod<Object?>('setFlashlight', {
        'enabled': enabled,
      });
      return result is Map && result['changed'] == true;
    } on Object {
      return false;
    }
  }

  Future<bool> composeEmail({String? to, String? subject, String? body}) async {
    try {
      final result = await _channel.invokeMethod<Object?>('composeEmail', {
        if (to != null && to.isNotEmpty) 'to': to,
        if (subject != null && subject.isNotEmpty) 'subject': subject,
        if (body != null && body.isNotEmpty) 'body': body,
      });
      return result is Map && result['opened'] == true;
    } on Object {
      return false;
    }
  }

  Future<bool> createContact({
    String? name,
    String? phone,
    String? email,
  }) async {
    try {
      final result = await _channel.invokeMethod<Object?>('createContact', {
        if (name != null && name.isNotEmpty) 'name': name,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (email != null && email.isNotEmpty) 'email': email,
      });
      return result is Map && result['opened'] == true;
    } on Object {
      return false;
    }
  }

  Future<bool> openMap({String? query}) async {
    try {
      final result = await _channel.invokeMethod<Object?>('openMap', {
        if (query != null && query.isNotEmpty) 'query': query,
      });
      return result is Map && result['opened'] == true;
    } on Object {
      return false;
    }
  }
}
