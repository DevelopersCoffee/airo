import 'package:platform_contracts/platform_contracts.dart';

abstract interface class ExtensionManifest implements ExtensionComponent {
  @override
  String get identifier;
  @override
  String get version;
  List<String> get dependencies;
  @override
  List<String> get capabilities;
  List<String> get permissions;
  List<String> get bootstrapTasks;
  Map<String, dynamic> get settings;
  String get minPlatformVersion;
}
