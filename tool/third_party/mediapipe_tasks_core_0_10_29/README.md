# MediaPipe Tasks Core 0.10.29 — telemetry-free derivation

This directory derives a narrowly modified AAR from the pinned Google Maven
artifact. It restores MediaPipe's public-source default
`TasksStatsDummyLogger`, removes the dedicated remote usage-logging classes and
protos, and embeds the upstream license plus the modification notice.

The source artifact, license, and source-code commit are pinned in `derive.sh`.
The published artifact is never used without SHA-256 verification.

Run:

```sh
bash derive.sh \
  --android-jar /path/to/android.jar \
  --javac /path/to/javac \
  --output /path/to/tasks-core-0.10.29-airo-no-telemetry.aar

bash audit.sh /path/to/tasks-core-0.10.29-airo-no-telemetry.aar
```

The consuming Gradle module must use the derived local AAR, exclude
`com.google.mediapipe:tasks-core` from `tasks-text:0.10.29`, and fail if any
`com.google.android.datatransport` dependency resolves.
