import 'package:equatable/equatable.dart';

import '../models/agent_skill.dart';

class ConnectorResult extends Equatable {
  final Map<String, dynamic> data;
  final bool isError;
  final String? errorCode;
  final String? message;

  const ConnectorResult({
    required this.data,
    this.isError = false,
    this.errorCode,
    this.message,
  });

  const ConnectorResult.error({
    required String code,
    required String message,
    Map<String, dynamic> data = const {},
  }) : this(data: data, isError: true, errorCode: code, message: message);

  @override
  List<Object?> get props => [data, isError, errorCode, message];
}

abstract interface class AgentConnector {
  String get name;
  Set<SkillCapability> get requiredCapabilities;

  Future<ConnectorResult> execute(Map<String, dynamic> arguments);
}
