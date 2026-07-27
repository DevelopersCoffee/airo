# core_ai

Reusable AI contracts and runtime services shared by Airo products. The package
contains no Airo application widgets and can be consumed by Airo Mind without a
dependency on the super-app host.

## Intelligent model manager v1

`IntelligentModelManager` combines the model catalog, device compatibility,
verified install state, the shared progressive-download queue, storage totals,
activation, runtime warm-up, and frequent-preload preferences behind injected
interfaces.

```dart
final manager = IntelligentModelManager(
  storageManager,
  registry,
  downloadService,
  activationGateway: appActivationAdapter,
  warmupGateway: runtimeAdapter,
  preloadPreferences: appPreferenceAdapter,
);

final snapshot = await manager.snapshot(activeModelId: selectedModelId);
await manager.pauseDownload(modelId);
await manager.warmModel(modelId);
await manager.setPreloadFrequentlyUsed(modelId, true);
```

Manager snapshots intentionally omit sandbox paths. Install receipts record a
catalog fingerprint, optional version and digest, and installation time. A
legacy artifact without a receipt reports `ModelUpdateState.unknown`; it is
never guessed to be current or stale.

## Download boundary

AI downloads adapt the product-neutral
`platform_downloads/background-download-contract/v1`. Transfer mechanics,
background execution, pause/resume/retry, integrity checks, and queue
persistence remain in `platform_downloads`, allowing Coin and other products to
reuse them without importing AI concepts.

Large artifact transfer and hashing run in native background workers rather
than Flutter presentation code. JSON used for the small local install receipt
and preload-ID preference remains well below the repository's 50 KB worker
threshold.
