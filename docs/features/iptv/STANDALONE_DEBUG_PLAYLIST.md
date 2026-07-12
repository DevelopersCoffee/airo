# Airo IPTV standalone debug playlist

The standalone Airo IPTV APK uses `app/lib/main_airo_iptv.dart`.

Debug builds can seed a default playlist URL by passing
`DEBUG_IPTV_PLAYLIST_URL`:

```bash
flutter build apk --debug \
  --target=lib/main_airo_iptv.dart \
  --dart-define=APP_VARIANT=iptv \
  --dart-define=APP_PLATFORM=mobileIptv \
  --dart-define=DEBUG_IPTV_PLAYLIST_URL=https://example.com/iptv_channels.m3u
```

This is intentionally debug-only. `main_airo_iptv.dart` checks `kDebugMode`
before writing the playlist URL, so release and production builds stay
bring-your-own-content even if the define is accidentally present.

Use the existing `DEBUG_IPTV_PLAYLIST_URL` hook for generated playlist sources
from GitHub Actions. Do not add production defaults or framework-level playlist
changes for this behavior.

