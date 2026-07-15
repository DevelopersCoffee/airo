# Airo TV Push Wake And Notification Fallback Contract

This contract defines the v2.0.0.1 platform boundary for push wake,
notification fallback, reconnect fallback, and user-action-required states.

Implementation contract:

- Package: `packages/core_push_wake`
- Schema: `kAiroPushWakeSchemaVersion`
- Primary policy: `AiroPushWakePolicy`
- Dispatcher boundary: `AiroPushWakeDispatcher`

## Ownership Boundary

Push wake is platform/framework behavior. Airo TV app code may render copy for
unavailable wake, visible notification prompts, or local reconnect guidance, but
must consume platform decision codes. Product code must not assume remote wake
works on every Android TV, Fire TV, mobile, desktop, or home-node environment.

The contract composes:

- `core_protocol` platform categories and receiver lifecycle states;
- `core_cloud_orchestration` mode/service vocabulary.

## Non-Goals

This package does not:

- import FCM, APNs, local notification, Android alarm, or vendor SDKs;
- open sockets;
- persist push registration handles;
- send notifications;
- wake a real device;
- store provider payloads;
- render UI.

Provider adapters can implement this contract later.

## Fallback Rules

`AiroPushWakePolicy` returns deterministic actions:

- `send`: provider wake can be attempted;
- `visibleNotification`: wake requires a visible notification;
- `localReconnect`: use LAN/reconnect fallback instead of push;
- `userActionRequired`: the user must open/resume the receiver manually;
- `deny`: invalid or unsafe request;
- `noOp`: dispatcher/provider unavailable.

Local-only mode blocks cloud push wake. Provider-unavailable and unsupported
platforms fall back instead of pretending remote wake is available.

## Privacy

Wake requests and diagnostics expose only stable IDs, platform category,
lifecycle, reason, action, codes, size, and timestamps. They must not include
media titles, raw URLs, local paths, local addresses, provider credentials,
analytics payloads, notification body text, or diagnostics dumps.

## Required Use Cases

- Android TV and Fire TV can require visible notification or user action.
- Mobile and desktop profiles may support data push if the provider is
  available and the request is unexpired.
- Home-node profiles can prefer local reconnect fallback.
- Local-only mode blocks cloud push wake.
- Expired, unsafe, or oversized requests are denied.
- Fake dispatcher records sendable wake attempts; no-op dispatcher fails closed.
