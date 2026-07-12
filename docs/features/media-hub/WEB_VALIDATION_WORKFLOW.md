# V2 IPTV web validation workflow

Use this workflow to validate the standalone IPTV surface in a local browser
before repeating the same fixes on APK targets.

## Scope

This validates:

- IPTV first-run playlist seeding from `DEBUG_IPTV_PLAYLIST_URL`
- channel parsing and category rendering
- player/list layout at desktop browser sizes
- browser startup errors, page errors, request failures, and console errors

This does not validate:

- real Google Cast receiver discovery or playback
- Android TV focus behavior
- native video decoder behavior on edge devices

Real Cast validation still requires a native Android or iOS sender and a Google
Cast receiver. See [Google Cast V1 QA](GOOGLE_CAST_V1_QA.md).

## Local data server

Browser fetches require CORS when the playlist is served from a different local
port than the Flutter web app. Use a CORS-enabled static server for the current
debug artifacts:

```bash
python3 - <<'PY'
from functools import partial
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler

class CorsHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(204)
        self.end_headers()

handler = partial(CorsHandler, directory='/Users/udaychauhan/Downloads/current')
server = ThreadingHTTPServer(('127.0.0.1', 8787), handler)
print('Serving CORS HTTP on 127.0.0.1 port 8787')
server.serve_forever()
PY
```

Expected playlist URL:

```text
http://127.0.0.1:8787/iptv_channels.m3u
```

## Repeatable browser smoke

Use a profile web build for automated browser checks. `flutter run -d
web-server` serves a debug bundle that requires the Dart Debug Chrome extension
client before the app starts; the profile build is static and works with
headless browser automation.

```bash
cd app
flutter build web --profile --no-wasm-dry-run \
  --target=lib/main_airo_iptv.dart \
  --dart-define=APP_VARIANT=iptv \
  --dart-define=APP_PLATFORM=webIptv \
  --dart-define=DEBUG_IPTV_PLAYLIST_URL=http://127.0.0.1:8787/iptv_channels.m3u
python3 -m http.server 8788 --bind 127.0.0.1 --directory build/web
```

Open:

```text
http://127.0.0.1:8788
```

Passing smoke criteria:

- page returns HTTP 200
- console has no `error` entries
- browser has a seeded `flutter.iptv_user_playlist_url`
- browser has a non-empty `flutter.iptv_playlist_cache`
- screenshot shows the Stream page with channel categories and playlist rows

## Known web-specific constraints

- `app/web/index.html` must load the PDF.js runtime required by `pdfx`, because
  Flutter registers web plugins globally even when the IPTV route does not show
  PDFs.
- The Cast provider must not install the native Chrome Cast controller on web.
  Browser builds use the unavailable Cast controller so UI validation can run
  without `dart:io` or native Cast sender APIs.
- `--no-wasm-dry-run` is used for the current JS smoke. The full app dependency
  graph still reports wasm dry-run findings in `pdfx` and `flutter_tts`; those
  should be handled separately before claiming wasm support.
