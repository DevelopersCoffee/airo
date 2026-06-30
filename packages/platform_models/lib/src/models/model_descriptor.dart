import 'package:platform_downloads/platform_downloads.dart';
import 'package:platform_models/src/capabilities/model_capabilities.dart';

class ModelDescriptor {

  const ModelDescriptor({
    required this.identifier,
    required this.family,
    required this.modality,
    required this.version,
    required this.parameterCount,
    required this.quantization,
    required this.contextWindow,
    required this.capabilities,
    required this.minimumRamMb,
    required this.downloadManifest,
  });
  final String identifier;
  final String family;
  final ModelModality modality;
  final String version;
  
  final int parameterCount;
  final String quantization;
  final int contextWindow;

  final ModelCapabilities capabilities;
  final int minimumRamMb;
  final DownloadManifest downloadManifest;
}
