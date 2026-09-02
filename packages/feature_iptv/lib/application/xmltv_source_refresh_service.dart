import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:platform_epg/platform_epg.dart';
import 'package:platform_worker_jobs/platform_worker_jobs.dart';

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
    required this.dio,
    required this.sourceStore,
    required this.repository,
    required this.downloadDirectoryProvider,
  });

  final Dio dio;
  final XmltvSourceStore sourceStore;
  final MutableXmltvCompactEpgRepository repository;
  final Future<Directory> Function() downloadDirectoryProvider;

  /// Downloads [url], parses it, and updates [repository]. Throws
  /// [ArgumentError] for an invalid URL (after recording the error to
  /// [sourceStore] so the UI can show it) and rethrows any download/parse
  /// failure after recording it — the caller decides how to surface it.
  Future<void> refresh(
    String url, {
    XmltvSourceKind kind = XmltvSourceKind.user,
    String? expectedSha256,
  }) async {
    final trimmedUrl = url.trim();
    final uri = Uri.tryParse(trimmedUrl);
    if (uri == null ||
        uri.host.isEmpty ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      const message = 'Enter a valid HTTP(S) XMLTV URL.';
      await _recordFailureKeepingExistingUrl(
        trimmedUrl,
        message,
        kind: kind,
        expectedSha256: expectedSha256,
      );
      throw ArgumentError.value(url, 'url', message);
    }

    // Note: the new URL is intentionally NOT persisted here. Persisting it
    // before the download succeeds would overwrite a previously-working
    // source's config (wiping its lastRefreshedAt) with an unconfirmed one —
    // if the download below then fails, the working URL would be lost with
    // no way to recover it. The URL only becomes the saved source on success
    // (below) or, in the failure path, if nothing was configured before.

    final downloadDirectory = await downloadDirectoryProvider();
    await downloadDirectory.create(recursive: true);
    final token = DateTime.now().microsecondsSinceEpoch;
    final downloadFile = File(
      '${downloadDirectory.path}/xmltv_source_$token.download',
    );
    final guideFile = File('${downloadDirectory.path}/xmltv_source_$token.xml');

    try {
      await dio.download(
        trimmedUrl,
        downloadFile.path,
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: const Duration(seconds: 30),
          validateStatus: (status) =>
              status != null && status >= 200 && status < 300,
        ),
      );

      if (!await downloadFile.exists() || await downloadFile.length() == 0) {
        throw StateError('Downloaded XMLTV file was empty.');
      }
      if (expectedSha256 != null) {
        final actualSha256 = await const AiroWorkerExecutor().run(
          debugName: 'xmltv_source_checksum',
          kind: AiroWorkerJobKind.epgRefresh,
          computation: () => sha256.bind(downloadFile.openRead()).first,
        );
        if (actualSha256.toString().toLowerCase() !=
            expectedSha256.toLowerCase()) {
          throw StateError('Downloaded XMLTV checksum did not match manifest.');
        }
      }
      if (await _isGzip(downloadFile, trimmedUrl)) {
        await const AiroWorkerExecutor().run<void>(
          debugName: 'xmltv_source_decompress',
          kind: AiroWorkerJobKind.epgRefresh,
          computation: () => gzip.decoder
              .bind(downloadFile.openRead())
              .pipe(guideFile.openWrite()),
        );
      } else {
        await downloadFile.rename(guideFile.path);
      }

      final parsed = await XmltvCompactEpgRepository.fromXmltvFileNative(
        path: guideFile.path,
        ingestedAt: DateTime.now().toUtc(),
      );

      repository.updateNamedSource(
        sourceId: 'xmltv-${kind.name}',
        priority: kind == XmltvSourceKind.user ? 0 : 1,
        repository: parsed,
      );
      // Only now, after a successful download and parse, does the new URL
      // become the saved source.
      await sourceStore.save(
        XmltvSourceConfig(
          url: trimmedUrl,
          kind: kind,
          expectedSha256: expectedSha256,
          lastRefreshedAt: DateTime.now().toUtc(),
        ),
      );
    } catch (e) {
      await _recordFailureKeepingExistingUrl(
        trimmedUrl,
        e.toString(),
        kind: kind,
        expectedSha256: expectedSha256,
      );
      rethrow;
    } finally {
      if (await guideFile.exists()) {
        await guideFile.delete();
      }
      if (await downloadFile.exists()) {
        await downloadFile.delete();
      }
    }
  }

  Future<bool> _isGzip(File file, String url) async {
    if (url.toLowerCase().endsWith('.gz')) return true;
    final input = await file.open();
    try {
      final bytes = await input.read(2);
      return bytes.length == 2 && bytes[0] == 0x1f && bytes[1] == 0x8b;
    } finally {
      await input.close();
    }
  }

  /// Records a failed refresh attempt without discarding a previously
  /// working source. If a source was already configured, its URL and
  /// [XmltvSourceConfig.lastRefreshedAt] are preserved and only [error] is
  /// attached. If nothing was configured yet, [attemptedUrl] is saved
  /// alongside [error] so the UI can show what was tried.
  Future<void> _recordFailureKeepingExistingUrl(
    String attemptedUrl,
    String error, {
    required XmltvSourceKind kind,
    String? expectedSha256,
  }) async {
    final existing = (await sourceStore.loadAll())
        .where((source) => source.kind == kind)
        .firstOrNull;
    if (existing != null) {
      await sourceStore.recordRefreshError(error, kind: kind);
    } else {
      await sourceStore.save(
        XmltvSourceConfig(
          url: attemptedUrl,
          kind: kind,
          expectedSha256: expectedSha256,
          lastError: error,
        ),
      );
    }
  }

  /// Refreshes whatever source is already saved in [sourceStore]. No-op if
  /// nothing is configured yet.
  Future<void> refreshConfiguredSource() async {
    final config = await sourceStore.load();
    if (config == null) return;
    await refresh(
      config.url,
      kind: config.kind,
      expectedSha256: config.expectedSha256,
    );
  }

  Future<void> refreshConfiguredSources() async {
    for (final config in await sourceStore.loadAll()) {
      try {
        await refresh(
          config.url,
          kind: config.kind,
          expectedSha256: config.expectedSha256,
        );
      } on Object {
        // Per-source state already records the error. A failed system guide
        // must not prevent a working user guide from refreshing.
      }
    }
  }

  Future<void> refreshSystemSourceFromManifest({
    required String manifestUrl,
    required String country,
  }) async {
    final manifestUri = _validManifestUri(manifestUrl);
    final manifest = await _loadManifest(manifestUri);
    final normalizedCountry = country.trim().toUpperCase();
    final guideUri = _resolveGuideUri(
      manifest,
      manifestUri: manifestUri,
      country: normalizedCountry,
    );
    if (guideUri == null) {
      throw StateError('System guide is unavailable for $normalizedCountry.');
    }
    final checksum = _checksumFor(manifest, country: normalizedCountry)!;
    await refresh(
      guideUri.toString(),
      kind: XmltvSourceKind.system,
      expectedSha256: checksum,
    );
  }

  /// Fetches only the `guide_$CC` shards present in the manifest for
  /// [countries] — never `guide_ALL` (a CDN/tooling artifact, not a device
  /// boot fetch; see the BYOC XMLTV system guide design doc) and never any
  /// country outside the caller's playlist. A country with no matching
  /// manifest entry is skipped rather than treated as an error, since the
  /// system guide only ever covers a subset of countries. Each fetched
  /// shard becomes its own named source (`xmltv-system-$CC`, priority 1)
  /// so one country's parse failure doesn't drop another's already-merged
  /// data. On success for at least one country, persists a single system
  /// [XmltvSourceConfig] (keyed on [manifestUrl]) recording the refresh —
  /// the store tracks one row per [XmltvSourceKind], matching the existing
  /// single-source system/user model.
  Future<void> refreshSystemGuidesForCountries({
    required String manifestUrl,
    required Set<String> countries,
  }) async {
    if (countries.isEmpty) return;
    final manifestUri = _validManifestUri(manifestUrl);
    final manifest = await _loadManifest(manifestUri);

    var anySucceeded = false;
    for (final country in countries) {
      final normalizedCountry = country.trim().toUpperCase();
      if (normalizedCountry.isEmpty) continue;
      final guideUri = _resolveGuideUri(
        manifest,
        manifestUri: manifestUri,
        country: normalizedCountry,
      );
      if (guideUri == null) continue;
      final checksum = _checksumFor(manifest, country: normalizedCountry)!;
      try {
        final parsed = await _downloadAndParse(
          guideUri.toString(),
          expectedSha256: checksum,
        );
        repository.updateNamedSource(
          sourceId: 'xmltv-system-$normalizedCountry',
          priority: 1,
          repository: parsed,
        );
        anySucceeded = true;
      } on Object {
        // One country's bad shard must not drop guides already merged for
        // other countries, or block the caller's other playlist countries.
      }
    }

    if (anySucceeded) {
      await sourceStore.save(
        XmltvSourceConfig(
          url: manifestUri.toString(),
          kind: XmltvSourceKind.system,
          lastRefreshedAt: DateTime.now().toUtc(),
        ),
      );
    }
  }

  Uri _validManifestUri(String manifestUrl) {
    final manifestUri = Uri.tryParse(manifestUrl.trim());
    if (manifestUri == null ||
        manifestUri.host.isEmpty ||
        manifestUri.scheme != 'https') {
      throw ArgumentError.value(
        manifestUrl,
        'manifestUrl',
        'System guide manifest must use HTTPS.',
      );
    }
    return manifestUri;
  }

  Future<Map<String, dynamic>> _loadManifest(Uri manifestUri) async {
    final response = await dio.get<dynamic>(
      manifestUri.toString(),
      options: Options(
        receiveTimeout: const Duration(seconds: 30),
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300,
      ),
    );
    return response.data as Map<String, dynamic>;
  }

  String? _checksumFor(
    Map<String, dynamic> manifest, {
    required String country,
  }) {
    final key = 'guide_$country';
    final checksum =
        (manifest['fileChecksums'] as Map<String, dynamic>?)?[key] as String?;
    if (checksum == null || !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(checksum)) {
      return null;
    }
    return checksum;
  }

  /// Resolves the same-origin URI for `guide_$country`, or null when the
  /// manifest has no entry (missing filename/checksum) for it.
  Uri? _resolveGuideUri(
    Map<String, dynamic> manifest, {
    required Uri manifestUri,
    required String country,
  }) {
    final key = 'guide_$country';
    final filename =
        (manifest['files'] as Map<String, dynamic>?)?[key] as String?;
    if (filename == null || _checksumFor(manifest, country: country) == null) {
      return null;
    }
    final guideUri = manifestUri.resolve(filename);
    if (guideUri.scheme != manifestUri.scheme ||
        guideUri.host != manifestUri.host ||
        guideUri.port != manifestUri.port) {
      throw StateError('System guide manifest attempted a cross-origin URL.');
    }
    return guideUri;
  }

  /// Downloads, checksum-verifies, ungzips if needed, and natively parses
  /// one XMLTV URL. Shared by [refresh] (single source, records to
  /// [sourceStore]) and [refreshSystemGuidesForCountries] (multiple
  /// per-country sources, records one summary row).
  Future<XmltvCompactEpgRepository> _downloadAndParse(
    String url, {
    String? expectedSha256,
  }) async {
    final downloadDirectory = await downloadDirectoryProvider();
    await downloadDirectory.create(recursive: true);
    final token = DateTime.now().microsecondsSinceEpoch;
    final downloadFile = File(
      '${downloadDirectory.path}/xmltv_source_$token.download',
    );
    final guideFile = File('${downloadDirectory.path}/xmltv_source_$token.xml');
    try {
      await dio.download(
        url,
        downloadFile.path,
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: const Duration(seconds: 30),
          validateStatus: (status) =>
              status != null && status >= 200 && status < 300,
        ),
      );
      if (!await downloadFile.exists() || await downloadFile.length() == 0) {
        throw StateError('Downloaded XMLTV file was empty.');
      }
      if (expectedSha256 != null) {
        final actualSha256 = await const AiroWorkerExecutor().run(
          debugName: 'xmltv_source_checksum',
          kind: AiroWorkerJobKind.epgRefresh,
          computation: () => sha256.bind(downloadFile.openRead()).first,
        );
        if (actualSha256.toString().toLowerCase() !=
            expectedSha256.toLowerCase()) {
          throw StateError('Downloaded XMLTV checksum did not match manifest.');
        }
      }
      if (await _isGzip(downloadFile, url)) {
        await const AiroWorkerExecutor().run<void>(
          debugName: 'xmltv_source_decompress',
          kind: AiroWorkerJobKind.epgRefresh,
          computation: () => gzip.decoder
              .bind(downloadFile.openRead())
              .pipe(guideFile.openWrite()),
        );
      } else {
        await downloadFile.rename(guideFile.path);
      }
      return await XmltvCompactEpgRepository.fromXmltvFileNative(
        path: guideFile.path,
        ingestedAt: DateTime.now().toUtc(),
      );
    } finally {
      if (await guideFile.exists()) {
        await guideFile.delete();
      }
      if (await downloadFile.exists()) {
        await downloadFile.delete();
      }
    }
  }
}
