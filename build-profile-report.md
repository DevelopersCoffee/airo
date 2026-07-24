## Airo Build Profile Contract

| Profile | Release line | Pubspec | Status | Notes |
|---------|--------------|---------|--------|-------|
| `mobile-full` | v1 | `app/pubspec.yaml` | OK | report only |
| `iptv-standalone` | v2 | `app/pubspec_iptv.yaml` | OK | release <= 120 MiB; debug tracked <= 650 MiB; 5 heavy deps guarded |
| `mobile-streaming` | v2 | `app/pubspec_streaming.yaml` | OK | release <= 35 MiB; debug tracked <= 650 MiB; 13 heavy deps guarded |
| `tv` | v2 | `app/pubspec_tv.yaml` | OK | release <= 35 MiB; debug tracked <= 650 MiB; 16 heavy deps guarded; 5 KGP-risk deps guarded |
| `ios-spm` | v2 | `app/pubspec_ios_spm.yaml` | OK | report only |
| `web-validation` | v2 | `app/pubspec.yaml` | OK | report only |
