# Airo TV Media Location And Access Model

This contract defines the v2.0.0.1 platform boundary for representing where
media can be reached and how a receiver is granted scoped playback access
without leaking source values.

Implementation contract:

- Package: `packages/core_media_routing`
- Schema: `kAiroMediaLocationSchemaVersion`
- Location model: `AiroMediaLocation`
- Access model: `AiroRouteAccessGrant`
- Release-line base: `origin/v2`

## Location Kinds

`AiroMediaLocation` supports:

- public internet and IPTV streams;
- authenticated internet streams;
- LAN HTTP sources;
- NAS share items;
- media server items;
- local files;
- phone-local files;
- TV removable-storage files;
- desktop files;
- temporary HTTP access paths.

Locations are classified by locality: internet, local network, device-local,
removable storage, or relay. A location can require local-network scope,
trusted-device scope, expiry, range reads, and probe reads.

## Access Grants

`AiroRouteAccessGrant` is receiver-bound and expiring. It declares:

- grant id;
- location id;
- audience node id;
- issued and expiry times;
- playback, range, metadata, and probe scopes;
- trusted-device requirement;
- redacted access handle.

Grants validate against the requesting receiver, required scopes, trusted-device
state, and both grant and location expiry.

## Privacy Rule

Locations and grants use redacted handles. They must not expose raw URLs, local
paths, local IP addresses, provider auth material, playlist contents, or
credential-like diagnostics in logs, analytics, UI, or route decisions.

## Consumer Rule

Media routing, playback engines, local discovery adapters, companion
controllers, and Airo TV screens should consume location ids, locality, kind,
scope, and validation results. Product code should not pass raw source values
through navigation arguments, analytics events, diagnostics, or route decisions.

## Out Of Scope

This issue does not implement a temporary HTTP server, NAS adapter, cloud
storage backend, DRM license flow, playback-ticket service, weighted route
scoring, playback ownership, or playback execution.
