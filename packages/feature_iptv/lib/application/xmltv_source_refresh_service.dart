import 'dart:io';

import 'package:dio/dio.dart';
import 'package:platform_epg/platform_epg.dart';

import 'mutable_xmltv_compact_epg_repository.dart';
import 'xmltv_source_store.dart';

/// Downloads and parses a user-configured XMLTV URL, then swaps the result
/// into [MutableXmltvCompactEpgRepository] — the user-triggerable
/// counterpart to `main_tv.dart`'s existing debug-only
/// `warmTvDebugDefaultEpgCache`, but producing a full-timetable
/// [XmltvCompactEpgRepository] (via the native parse binding) rather than a
/// current/next-only snapshot.
class XmltvSourceRefreshService {
  XmltvSourceRefreshService({
    required Dio dio,
    required this.sourceStore,
    required this.repository,
    required this.downloadDirectoryProvider,
  }) : _dio = dio;

  final Dio _dio;
  final XmltvSourceStore sourceStore;
  final MutableXmltvCompactEpgRepository repository;
  final Future<Directory> Function() downloadDirectoryProvider;

  /// Downloads [url], parses it, and updates [repository]. Throws
  /// [ArgumentError] for an invalid URL (after recording the error to
  /// [sourceStore] so the UI can show it) and rethrows any download/parse
  /// failure after recording it — the caller decides how to surface it.
  Future<void> refresh(String url) async {
    final trimmedUrl = url.trim();
    final uri = Uri.tryParse(trimmedUrl);
    if (uri == null ||
        uri.host.isEmpty ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      const message = 'Enter a valid HTTP(S) XMLTV URL.';
      // The store's recordRefreshError() is an update-only no-op when no
      // config has been saved yet, so an invalid first-ever URL needs to be
      // persisted directly (with the error attached) rather than relying on
      // recordRefreshError to create it.
      final existing = await sourceStore.load();
      if (existing == null) {
        await sourceStore.save(
          XmltvSourceConfig(url: trimmedUrl, lastError: message),
        );
      } else {
        await sourceStore.recordRefreshError(message);
      }
      throw ArgumentError.value(url, 'url', message);
    }

    final existing = await sourceStore.load();
    if (existing == null || existing.url != trimmedUrl) {
      await sourceStore.save(XmltvSourceConfig(url: trimmedUrl));
    }

    final downloadDirectory = await downloadDirectoryProvider();
    await downloadDirectory.create(recursive: true);
    final guideFile = File(
      '${downloadDirectory.path}/xmltv_source_${DateTime.now().microsecondsSinceEpoch}.xml',
    );

    try {
      await _dio.download(
        trimmedUrl,
        guideFile.path,
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: const Duration(seconds: 30),
          validateStatus: (status) =>
              status != null && status >= 200 && status < 300,
        ),
      );

      if (!await guideFile.exists() || await guideFile.length() == 0) {
        throw StateError('Downloaded XMLTV file was empty.');
      }

      final parsed = await XmltvCompactEpgRepository.fromXmltvFileNative(
        path: guideFile.path,
        ingestedAt: DateTime.now().toUtc(),
      );

      repository.updateSource(parsed);
      await sourceStore.recordRefreshSuccess(DateTime.now().toUtc());
    } catch (e) {
      await sourceStore.recordRefreshError(e.toString());
      rethrow;
    } finally {
      if (await guideFile.exists()) {
        await guideFile.delete();
      }
    }
  }

  /// Refreshes whatever source is already saved in [sourceStore]. No-op if
  /// nothing is configured yet.
  Future<void> refreshConfiguredSource() async {
    final config = await sourceStore.load();
    if (config == null) return;
    await refresh(config.url);
  }
}
