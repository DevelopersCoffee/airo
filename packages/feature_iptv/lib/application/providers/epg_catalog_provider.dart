import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'iptv_providers.dart';

/// Same compile-time R2 manifest URL `main_tv.dart` seeds the system guide
/// with (`IPTV_DATA_MANIFEST_URL`) -- read directly here too, via an
/// overridable provider, so the guide picker works without new plumbing
/// through every app entrypoint. Empty on a build that doesn't define it;
/// [epgCatalogProvider] degrades to an empty catalog in that case.
final epgCatalogManifestUrlProvider = Provider<String>((ref) {
  return const String.fromEnvironment('IPTV_DATA_MANIFEST_URL');
});

class EpgCatalogEntry extends Equatable {
  const EpgCatalogEntry({
    required this.countryCode,
    required this.sourceId,
    required this.programmeCount,
    required this.channelCount,
    required this.updatedAt,
  });

  final String countryCode;
  final String sourceId;
  final int programmeCount;
  final int channelCount;
  final DateTime updatedAt;

  factory EpgCatalogEntry.fromJson(Map<String, dynamic> json) {
    return EpgCatalogEntry(
      countryCode: json['countryCode'] as String,
      sourceId: json['sourceId'] as String,
      programmeCount: json['programmeCount'] as int,
      channelCount: json['channelCount'] as int,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  @override
  List<Object?> get props => [
    countryCode,
    sourceId,
    programmeCount,
    channelCount,
    updatedAt,
  ];
}

/// The published guide catalog (one row per country, whichever source won
/// M1's per-country scoring) sitting alongside `manifest.json` in the same
/// R2 bucket. Never throws: a missing manifest URL, a network failure, a
/// non-200 response, or malformed JSON all resolve to an empty list so
/// [XmltvSourceSheet]'s custom-URL section stays fully usable regardless.
final epgCatalogProvider = FutureProvider<List<EpgCatalogEntry>>((ref) async {
  final manifestUrl = ref.watch(epgCatalogManifestUrlProvider);
  final manifestUri = Uri.tryParse(manifestUrl);
  if (manifestUrl.isEmpty || manifestUri == null) return const [];

  try {
    final catalogUri = manifestUri.resolve('epg_catalog.json');
    final dio = ref.watch(dioProvider);
    final response = await dio.get<dynamic>(
      catalogUri.toString(),
      options: Options(
        receiveTimeout: const Duration(seconds: 15),
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300,
      ),
    );
    final rows = (response.data as List<dynamic>).cast<Map<String, dynamic>>();
    return rows.map(EpgCatalogEntry.fromJson).toList(growable: false);
  } on Object {
    return const [];
  }
});
