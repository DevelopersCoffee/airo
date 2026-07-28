# MediaPipe Text Embedder Dependency Audit — 2026-07-28

## Decision

Do not consume the published MediaPipe `tasks-core` AAR unchanged. Use
`tasks-text:0.10.29` only with a reproducibly patched, locally vendored
`tasks-core:0.10.29` that restores the open-source no-op usage logger and
removes Google DataTransport.

The dependency stays full-profile-only. Static dependency, symbol, and size
checks pass; release remains blocked on physical offline inference plus
network/log inspection.

## Evidence

| Artifact | Size | SHA-256 | Finding |
| --- | ---: | --- | --- |
| `tasks-text:0.10.29` AAR | about 11 MB | `50f466bdc034fd32213cccdbf229b9b106909d6c4d6c89210ba322bbbd0af727` | Official sample version; arm64 JNI is 6,592,712 bytes. |
| `tasks-core:0.10.29` AAR | about 1.2 MB | `7c9f935c6e60f2d612ba3240991863fc12a48a25d67dc4373a52ce8c3b0c2232` | Contains forced remote stats logger and DataTransport dependencies. |
| Airo telemetry-free `tasks-core:0.10.29` derivation | 1,305,866 bytes uncompressed AAR entries | `36366b6b3ee7cb8279e3b3dd608774f4f30298296e56d6ff23f7f083d4bc0416` | Byte-identical across two derivations; dummy logger only, dedicated usage-logging classes/protos removed, license and modification notice embedded. |
| `tasks-text:1.0.0` AAR | about 27 MB | `300c3ed4669ef76d48633b8a5f236b71f26c94a4f5717b79d3f999af95f0b3a6` | Larger combined text/gen-AI native surface; arm64 JNI is 14,444,480 bytes. |
| `tasks-core:1.0.0` AAR | about 21 MB | `609c6fcfe59f58c9739194f65ae5882281c327710e1a616aa7f533a4d9238ca3` | Adds 11,015,096-byte arm64 core JNI and the same remote logger path. |

Both POMs declare Apache-2.0. Both text artifacts declare Android minimum API
24 and ship arm64-v8a, armeabi-v7a, x86, and x86_64.

## Hidden Network Path

Bytecode inspection proved:

1. `TaskRunner.create` always calls `TasksStatsLoggerFactory.create`.
2. The published factory returns `TasksStatsProtoLogger`.
3. `TasksStatsProtoLogger` constructs `RemoteLoggingClient`.
4. `RemoteLoggingClient` initializes Google DataTransport CCT and sends
   `COREML_ON_DEVICE_SOLUTIONS` events.
5. The logged system info includes app ID and app version; event protos include
   session, invocation count, latency, and initialization error statistics.

No raw input text or vector values were observed in this logger, but the
network behavior is still hidden telemetry and violates the Airo boundary.

## Upstream Source Comparison

The current open-source MediaPipe BUILD file says usage logging is enabled only
with the internal `ENABLE_TASKS_USAGE_LOGGING=1` define. Its default generated
factory returns `TasksStatsDummyLogger`, whose methods are no-ops.

The planned patch restores that public-source default. It must not change
inference code or native libraries.

The replacement factory is pinned to the public BUILD contract at MediaPipe
commit `8317ba78778738ba90a521e7e4580a2ba0129c81`. Two clean derivations using
JDK 17 and Android API 36 produced the same AAR SHA-256. The fail-closed audit
also proves the factory invokes `TasksStatsDummyLogger` and that the artifact
contains no remote logger, dedicated usage-logging proto, DataTransport symbol,
or `COREML_ON_DEVICE_SOLUTIONS` string.

The replacement is consumed through the repository-local Maven coordinate
`io.airo.thirdparty:mediapipe-tasks-core-no-telemetry:0.10.29-airo.1`.
Its POM declares no transitive dependencies. The provider's resolved Android
runtime graph contains that local module and `tasks-text:0.10.29`; it contains
neither published `com.google.mediapipe:tasks-core` nor any
`com.google.android.datatransport` module. Gradle also rejects either forbidden
dependency if it enters the provider graph later.

## APK Composition Evidence

The full-profile arm64 debug APK includes only
`lib/arm64-v8a/libmediapipe_tasks_text_jni.so` from the MediaPipe text runtime
and includes no embedding model. Against a same-commit full-profile baseline,
the final APK is 157,363,402 bytes with SHA-256
`2b197a0220f84334f4ef62ad263acea426af532c0ad192f11582006e6a879719`.
The baseline is 149,878,382 bytes, making the delta 7,485,020 bytes
(7.138 MiB).

The full APK scan contains no `COREML_ON_DEVICE_SOLUTIONS`,
`RemoteLoggingClient`, or `TasksStatsProtoLogger` marker. The full application
does contain DataTransport for unrelated Firebase dependencies, so
DataTransport absence is asserted only for the isolated provider dependency
graph, not for the whole application.

## Required Gates

- Verify upstream AAR SHA-256 before patching.
- Compile the replacement factory from checked-in source.
- Remove `TasksStatsProtoLogger`, `RemoteLoggingClient`, and logging proto
  classes from the derived core AAR.
- Resolve no `com.google.android.datatransport` dependency.
- Preserve and ship Apache-2.0 license/NOTICE plus a modification notice.
- Scan the full APK for the remote logger class and log-source string.
- Verify TV and Coins APK/dependency graphs contain no MediaPipe text runtime.
- Measure full-profile APK delta and physical Pixel 9 memory/latency.
- Inspect airplane-mode and network-stat evidence with redacted diagnostics.

## Model Supply Chain

The selected candidate is `sentence-transformers/all-MiniLM-L6-v2`, pinned to
revision `1110a243fdf4706b3f48f1d95db1a4f5529b4d41`, Apache-2.0.

The conversion proof generated a 384-dimensional, L2-normalized MediaPipe model
but the model is not approved for upload or distribution yet. A future model
artifact must include:

- reproducible conversion inputs and commands;
- source revision, model and vocabulary hashes;
- license and attribution;
- semantic fixture/evaluation evidence;
- physical-device latency and memory evidence;
- a signed download manifest and rollback/delete lifecycle.
