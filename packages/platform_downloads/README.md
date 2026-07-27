# platform_downloads

`platform_downloads` is Airo's product-neutral progressive background-download
plugin. Airo, Airo Coin, and Airo Mind can import it without importing each
other or `core_ai`.

## Contract

`background-download-contract/v1` provides:

- HTTPS-only artifact requests with optional expected byte count and SHA-256
- a persistent ordered queue
- pause, resume, retry, and idempotent cancel operations
- structured progress and stable failure codes
- background Android WorkManager and iOS URLSession adapters
- partial-download preservation when the remote server supports resume
- verification before atomic promotion to the final destination

The contract never exposes source URLs or destination paths in progress events.
Destination paths must be inside the application sandbox.

## Usage

```dart
import 'package:platform_downloads/platform_downloads.dart';

final downloads = MethodChannelBackgroundDownloads();

await downloads.enqueue(
  DownloadArtifactRequest(
    artifactId: 'statement-pack-2026-07',
    source: Uri.parse('https://example.test/statement-pack.bin'),
    destinationPath: destinationPath,
    expectedBytes: expectedBytes,
    expectedSha256: expectedSha256,
    displayName: 'Statement pack',
  ),
);

final subscription = downloads.events.listen((progress) {
  // Render typed state; do not parse human-readable failure messages.
});
```

Product packages own their artifact catalogs and user journeys. This package
owns transfer mechanics only.

## Platform behavior

Android uses a persisted WorkManager chain for reliable FIFO background work
and byte-range requests for partial files. iOS uses a background
`URLSessionDownloadTask` and stores opaque resume data in Application Support.
If a server cannot resume, the adapter emits `resumeNotSupported`; it does not
silently discard a valid partial transfer.

Official platform references:

- https://docs.flutter.dev/packages-and-plugins/developing-packages
- https://developer.android.com/develop/background-work/background-tasks/persistent
- https://developer.android.com/develop/background-work/background-tasks/persistent/how-to/long-running
- https://developer.apple.com/documentation/foundation/urlsessiondownloadtask
- https://developer.apple.com/documentation/foundation/pausing-and-resuming-downloads
