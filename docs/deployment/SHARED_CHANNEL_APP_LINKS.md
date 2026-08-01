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
- `io.airo.app.tv`

Each entry uses
`delegate_permission/common.handle_all_urls` and the real SHA-256 fingerprint
of the corresponding release signing certificate. Do not use a debug
fingerprint or a guessed value.

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
