# V2 Third-Party Notices

This document records third-party notice obligations for the current v2 Android
release profiles:

- `full`
- `tv`

The profile matrix is maintained in `docs/release/V2_DISTRIBUTION_MATRIX.md`
and `.github/airo-build-profiles.json`.

## Project License

Airo-owned source code is licensed under the root MIT `LICENSE`.

## Vendored Source

### flutter_chrome_cast

- Path: `packages/platform_player/third_party/flutter_chrome_cast`
- Declared license: BSD-3-Clause
- Repository: `https://github.com/felnanuke2/flutter_google_cast`
- Used by: Cast discovery/session/control support in v2 Android profiles

BSD-3-Clause notice:

```text
Copyright 2023 felnanuke2

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors
   may be used to endorse or promote products derived from this software
   without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```

### media_kit (mpv playback backend)

- Package: `media_kit` (MIT) + `media_kit_libs_video` (MIT wrapper) bundling
  `libmpv` per-platform native builds. Pulled into `packages/platform_media`
  for the CV-030 mpv playback engine.
- Repository: `https://github.com/media-kit/media-kit`
- Shipping matrix (per
  `docs/superpowers/specs/2026-07-17-device-aware-playback-engine-design.md`):
  bundled on Android mobile, iOS, macOS, Windows, Linux. **Excluded** from the
  `tv` Android flavor via `app/android/app/build.gradle.kts`
  (`packaging.jniLibs.excludes`) — storage-starved TV boxes cannot absorb the
  per-arch libmpv + FFmpeg binaries.
- Underlying `libmpv` is LGPL-2.1+; used as a dynamic library via media_kit's
  native binding, satisfying LGPL dynamic-linking terms. FFmpeg components
  bundled with libmpv are LGPL-2.1+ builds (no GPL codec plugins).
- Version pins in `packages/platform_media/pubspec.yaml` are EXACT (no `^`)
  per open-source council review — a bump requires re-review of license,
  binary size, and per-arch native-lib impact.

## Direct Release Dependency Surface

The current v2 release-profile pubspecs include these direct dependency names.
Transitive dependency notices should be regenerated if the lockfile or profile
pubspecs change before a public release.

```text
audio_service
audioplayers
cached_network_image
connectivity_plus
core_ai
core_auth
core_data
core_domain
core_ui
cupertino_icons
dio
drift
equatable
feature_iptv
file_picker
firebase_auth
firebase_core
flame
flutter
flutter_chrome_cast
flutter_contacts
flutter_image_compress
flutter_local_notifications
flutter_riverpod
flutter_tts
go_router
google_mlkit_text_recognition
google_sign_in
hive
hive_flutter
image_picker
intl
just_audio
package_info_plus
path
path_provider
pdfx
permission_handler
riverpod
rxdart
share_plus
shared_preferences
sqlite3_flutter_libs
stockfish
timezone
url_launcher
uuid
video_player
wakelock_plus
```

## Release Gate

Before public distribution, maintainers must confirm whether any private,
commercial, gated, or restricted-license dependency is bundled in the final
APK/AAB artifacts.
