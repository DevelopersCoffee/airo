# Intent Engine v1

Issue: [#904](https://github.com/DevelopersCoffee/airo/issues/904)

## Boundary

The IPTV assistant uses the pinned `slm_edge_intelligence` pack only to parse
an utterance. It translates the typed SDK result into the
`core_edge_intelligence` `IntentCommand` v1 wire shape and validates that shape
before execution.

The execution context always declares `NetworkState.offline`. Model output
cannot import or invoke player APIs. The application-owned executor receives a
validated command and queries only:

- the current local playlist index;
- the bounded, already-loaded EPG window represented in that index; and
- local recent-channel history for `resume`.

The executor returns stable channel identifiers. Presentation resolves the
identifier against the user's loaded playlist before entering the existing
playback path.

## Failure and fallback

The default confidence threshold is `0.75`. Low-confidence output,
clarification-required output, unsupported intents, invalid translated fields,
and model exceptions do not execute the proposed command. They run the original
utterance through deterministic local search. A missing local match produces a
stable message and no playback action.

Raw exceptions, model payloads, playlist URLs, and stream URLs do not cross the
intent contract.

## Acceptance

Focused host tests cover:

1. contract-valid high-confidence execution;
2. low-confidence fallback;
3. invalid-output rejection;
4. exception fallback;
5. recent-history resume;
6. EPG programme-to-channel mapping;
7. one-time pack installation; and
8. offline execution context.

The opt-in integration test is:

```sh
flutter test integration_test/edge_intelligence_native_pack_test.dart
```

The test records query latency and enforces the `< 1.5 s` budget. Final issue
acceptance still requires the upstream 50-query pack/eval result and a named
physical-device airplane-mode run; host evidence does not substitute for those
claims.
