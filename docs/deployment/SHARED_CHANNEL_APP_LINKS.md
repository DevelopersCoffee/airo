# Shared Channel App-Link Deployment

The app declares the Airo channel URL on Android and iOS, but both operating
systems require association documents at the **domain root**:

- `https://developerscoffee.github.io/.well-known/assetlinks.json`
- `https://developerscoffee.github.io/.well-known/apple-app-site-association`

This repository is served below `/airo`, so publishing files from its `docs/`
directory cannot satisfy that root-domain requirement. The owner of the
`DevelopersCoffee.github.io` organization Pages repository must deploy them.

## Android targets

Publish Digital Asset Links entries for:

- `io.airo.app`
- `com.developerscoffee.tv.midas`

Each entry uses
`delegate_permission/common.handle_all_urls` and the real SHA-256 fingerprint
of the corresponding release signing certificate. Do not use a debug
fingerprint or a guessed value.

For `com.developerscoffee.tv.midas` publish **both** fingerprints from
[midas-stream-play-app-signing.json](../release/midas-stream-play-app-signing.json):

- Play App Signing deployment cert (Play-installed builds):
  `A3:D1:19:3D:7D:B3:00:65:E1:BD:47:85:2D:31:7B:86:3E:51:97:32:7B:13:5E:C6:50:E0:DC:60:42:DB:2D:FB`
- Upload / sideload cert (`app/android/release.keystore`):
  `78:D9:A4:1D:A5:97:0F:B0:B8:9C:1D:D7:96:60:BF:5E:97:F0:63:70:23:C4:14:B5:01:ED:D0:87:84:84:1A:B9`

## Apple target

Publish an Apple App Site Association `applinks.details` entry for:

```text
DR4Z2C2LSW.com.developerscoffee.airo
```

Allow the path `/airo/iptv*`. Serve the document as JSON without a redirect or
filename extension.

## Qualification

Do not mark shared channel app links as available until:

1. both root documents return HTTP 200;
2. Android domain verification reports success for both package ids;
3. a release-signed Pixel 9 opens the Airo import preview from the HTTPS link;
4. an iPad build with the Associated Domains entitlement opens the same link;
5. the browser fallback at `/airo/iptv` returns HTTP 200 when Airo is absent.
