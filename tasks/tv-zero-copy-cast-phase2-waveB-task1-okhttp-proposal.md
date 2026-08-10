# Wave B Task 1 Proposal: OkHttp + media3-datasource-okhttp

Status: awaiting explicit user confirmation before Task 3 touches
`app/android/app/build.gradle.kts` (plan's AD-P2B.1, same gate as Wave A's
Media3 proposal).

## Proposed artifacts

```kotlin
// app/android/app/build.gradle.kts, inside dependencies { }, isTvVariant-gated
if (isTvVariant) {
    implementation("com.squareup.okhttp3:okhttp:5.4.0")
    implementation("androidx.media3:media3-datasource-okhttp:1.11.0")
}
```

Same gating pattern as Wave A's Media3 additions — added to the existing
`if (isTvVariant) { ... }` block Task 4 (Wave A) already created, not a
new conditional.

## Versions

- **OkHttp 5.4.0** — current latest stable, confirmed via web search
  against Maven Central, not training data:
  [Maven Repository: com.squareup.okhttp3](https://mvnrepository.com/artifact/com.squareup.okhttp3/okhttp),
  [okhttp — GitHub](https://github.com/square/okhttp)
- **media3-datasource-okhttp 1.11.0** — pinned to match the Media3 core
  modules Wave A already added (`media3-exoplayer`, `media3-common`,
  `media3-datasource`, `media3-exoplayer-hls`, all 1.11.0). Android
  Developers' own docs are explicit that this module's version "must
  match the version of the other media modules being used" —
  [Media3 | Jetpack | Android Developers](https://developer.android.com/jetpack/androidx/releases/media3)

## Why OkHttp instead of raw sockets

F4.2 needs connection pooling (up to 6/host, 45s idle timeout), keepalive,
`TCP_NODELAY`, and custom DNS resolution. OkHttp gives all of that
correctly and is exactly what Media3's own `media3-datasource-okhttp`
module is built to wrap — the alternative is hand-rolling pooling/
keepalive on raw `Socket`/`SSLSocket`, which is a lot more surface area to
get right and review for a Wave B slice. `okhttp3.Dns` is the exact
interface point Task 2's resolver cache needs to plug into.

## Compatibility

- **minSdk:** OkHttp 5.x requires API 21+; this project's `minSdk = 26` —
  no conflict.
- **compileSdk/AGP/JVM target:** no known incompatibility with this
  project's compileSdk 36 / AGP 9.3.1 / JVM 17 (same checks as the Media3
  proposal, nothing OkHttp-specific flags differently here).

## License

Apache License 2.0 — both artifacts. Same license family as the rest of
this project's dependency set, including Media3 itself.

## APK size — honest estimate

OkHttp itself is a small-to-mid library (core `okhttp` jar is roughly in
the low hundreds of KB uncompressed; exact number depends on which
optional features get shrunk). `media3-datasource-okhttp` is a thin
adapter, not a significant addition on its own. Same honesty as the
Media3 proposal: I have not measured this against *this* project's actual
build, and won't claim a precise number I haven't verified. Recommend
measuring via APK size diff once Task 3 actually wires it in, same as
the Media3 proposal's own recommendation.

## Confirmation needed

Per plan AD-P2B.1, Task 3 does not touch `build.gradle.kts` until this is
explicitly confirmed.
