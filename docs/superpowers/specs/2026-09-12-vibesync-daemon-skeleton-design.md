# VibeSync daemon skeleton

**Date:** 2026-09-12
**Status:** Approved for implementation
**Product:** VibeSync — local AI command layer for text and desktop workflows
**Slice:** 1 — Rust daemon runtime (no llama.cpp, no real OS paste)

## Objective

Build the desktop intelligence *runtime*, not a grammar-checker app. In-place
replacement is one execution mode. The first shippable engineering increment is
a long-running Rust daemon that accepts the same commands from CLI, Flutter, and
tests, runs a typed pipeline, and emits events. Flutter is a control plane and
overlay. It is not on the critical path.

## Frozen decisions

| Decision | Choice |
|---|---|
| Product home | New GitHub repo `DevelopersCoffee/vibesync`, not an Airo flavor |
| SDK housing | Library crates inside that repo; extract `airo_desktop` (and later `vibesync_core`) when the public API is stable |
| Process model | Two processes + local IPC. Not in-process FRB. Flutter crash must not kill the daemon |
| First slice | Daemon skeleton with a fixture inference engine |
| Interaction | Keep `ZeroClick` and `Interactive` permanently; they are not the same as execution mode |
| Execution | `InPlace`, `Clipboard`, `Overlay` — configurable per operation |
| Inspiration | Espanso’s daemon/OS/config shape, not its `:trigger` expansion model |
| Inference | Local only. Cloud inference is out of product scope |

## Non-goals (this slice)

- llama.cpp / GGUF / model download
- Real global hotkeys, clipboard capture, input simulation, tray
- Accessibility / Input Monitoring permission UI
- Dynamic Notch visual polish (overlay may exist as an event log window)
- Installers, start-on-login, codesigning
- Custom YAML actions, launcher picker, text triggers
- Publishing crates to crates.io
- Extracting `airo_mind_llama` or adding desktop APIs to `airo_core`
- An Airo worktree or `main_vibesync.dart` flavor

## Product architecture (frozen beyond this slice)

```
triggers (hotkey, tray, launcher, CLI, future API)
        → command router
        → operation registry
        → context builder
        → model router
        → local AI runtime
        → output validator
        → delivery (InPlace | Clipboard | Overlay)
```

Slice 1 implements every box with a real type and a stub or fixture behind it.
Later slices replace stubs. They do not rename the boxes to `Grammar*`.

### Interaction vs execution

These are independent:

- `InteractionMode`: `ZeroClick` | `Interactive`
- `ExecutionMode`: `InPlace` | `Clipboard` | `Overlay`

Example: Interactive + Summarize + Clipboard is valid. ZeroClick + Correct +
InPlace is the flagship path, not the product boundary.

### Dynamic Notch (later slice)

The notch is the visual execution surface. Idle state is a small intentional
capsule, not a 120×4 broken bar. It follows the display of the active app, not
always the primary monitor. Mouse-through when idle; interactive when invoked.
Slice 1 only requires that overlay clients can subscribe to events.

## Repository shape

Create `DevelopersCoffee/vibesync` (public, MIT, same org as Airo).

```
vibesync/
├── crates/
│   ├── airo_desktop/       OS traits (hotkey, clipboard, input, display, tray, permissions)
│   ├── vibesync_core/      config, commands, events, operations, pipeline, IPC protocol
│   └── vibesyncd/          daemon binary
├── app/                    Flutter control-plane client
├── crates/vibesync_cli/    same IPC as Flutter
├── docs/
│   ├── architecture/
│   ├── platform/
│   └── security/
└── scripts/
```

`airo_desktop` and `vibesync_core` use their public crate names from day one
(`publish = false` until extraction). Extraction is a repo move, not a rewrite.

No Airo worktree for this product. Airo remains the super-app monorepo.

## Crate responsibilities

### `airo_desktop`

Platform capabilities as traits. Slice 1: every method returns `Unsupported`
on macOS, Windows, and Linux so all three targets compile.

Traits (names frozen):

- `Hotkey`
- `Clipboard`
- `Input`
- `DisplayManager` (`primary_display`, `displays`, `display_at_cursor`, `display_for_active_app`)
- `Tray`
- `Permissions`

`PlatformCapabilities` is a struct of booleans / feature flags so Wayland vs
X11 vs macOS vs Windows is explicit. Callers must not assume a capability.

This crate must not depend on `vibesync_core`, Flutter, or llama.cpp.

### `vibesync_core`

Typed config, command bus, event bus, operation registry, pipeline, IPC
message types. No OS syscalls. No Flutter.

### `vibesyncd`

Loads config, binds the local socket, constructs buses, runs until `Shutdown`.
If a client disconnects, the daemon keeps running.

### `app/` (Flutter)

IPC client. Settings may send `ReloadConfiguration`. Overlay subscribes to
events. Must not implement capture, inference, or paste.

## Configuration

YAML on disk, loaded into typed structs. No business logic reads YAML maps
directly.

```yaml
app:
  start_on_login: false
  show_overlay: true

shortcut:
  key: "Alt+Space"
  interaction: zero_click

correction:
  preserve_meaning: true
  preserve_tone: true
  preserve_formatting: true
  spelling: true
  grammar: true
  punctuation: true

engine:
  provider: fixture
  model: grammar-default
  context_size: 1024
  temperature: 0.0

clipboard:
  restore_previous: true

operations:
  correct_grammar:
    mode: inplace
```

Unknown keys are errors. Missing file → daemon writes a default and starts.
Invalid file → process exits non-zero with a typed error; it does not start
half-configured.

## Commands and events

```text
CLI / Flutter / tests
        → VibeSyncCommand
        → CommandBus
        → Pipeline
        → EventBus
        → every connected client
```

### `VibeSyncCommand`

- `ProcessSelection { operation_id }`
- `ReloadConfiguration`
- `ShowOverlay`
- `HideOverlay`
- `Shutdown`

Slice 1 does not implement `InitializeEngine`, `DownloadModel`, or
`RemoveModel`. Add those variants in the slice that first needs them.

### `VibeSyncEvent`

- `Ready`
- `HotkeyTriggered`
- `CommandReceived { command }`
- `SelectionCaptured`
- `InferenceStarted`
- `InferenceCompleted`
- `ValidationPassed`
- `ValidationFailed { reason }`
- `DeliveryRecorded { mode }`
- `Completed`
- `Error { code }`

One event, many consumers (overlay, logger, later tray).

## Operations

```text
TextOperation
  id, interaction, execution, policy, prompt_template
```

Slice 1 registers `correct_grammar` only (`ZeroClick` + `InPlace`). Registry
documents reserved ids that must not be hardcoded as `Grammar*` types:

`rewrite`, `improve`, `shorten`, `expand`, `translate`, `summarize`,
`explain`, `generate_reply`, `custom/*`.

The primitive is `SelectionContext { text, application, captured_at }`, not a
text-expansion match.

## Pipeline (slice 1)

```
ProcessSelection
  → SelectionContext from FixtureSelectionSource (not Ctrl+C)
  → FixtureEngine (deterministic rewrite, not llama.cpp)
  → Validator
  → DeliveryIntent recorded (no OS paste)
```

`FixtureEngine` must be swappable behind `InferenceEngine`. Slice 2+ drops in
llama.cpp without renaming the pipeline.

### Validator (slice 1)

Reject:

- empty output
- output over a configured character cap (default 32 KiB)

Allow:

- output identical to input (no-op is success, not an error)

Do not invent semantic “meaning preserved” checks until a real model exists.

## IPC

Not FRB. Not `airo_protocol` (TV↔phone envelopes).

- macOS / Linux: unix domain socket
- Windows: named pipe
- Framing: newline-delimited JSON, one command or event per line
- Default path: platform user runtime dir / `vibesync.sock` (Windows pipe name
  `\\.\pipe\vibesync`)

Any number of clients. Broadcast events to all. Commands are serialized on one
daemon worker so two `ProcessSelection` calls do not interleave clipboard
later.

## Error handling

| Failure | Behavior |
|---|---|
| Unknown `operation_id` | `Error`, no delivery |
| Empty fixture selection | `ValidationFailed`, no delivery |
| Engine returns empty | `ValidationFailed`, no delivery |
| Engine panics | caught, `Error`, daemon stays up |
| Client disconnect mid-pipeline | pipeline finishes, events go to remaining clients |
| Bind address in use | exit non-zero |
| Invalid config | exit non-zero, do not start |

The daemon never treats a missing Flutter UI as a fatal error.

## Testing

- Unit: config parse, command router, registry, fixture engine, validator
- Integration: start `vibesyncd`, CLI `ProcessSelection`, assert event order
  `CommandReceived → SelectionCaptured → InferenceStarted → InferenceCompleted → ValidationPassed → DeliveryRecorded → Completed`
- Isolation: connect a dummy client, kill it, send another command, daemon
  still completes
- Compile: `airo_desktop` stubs build for macOS, Windows, Linux

No on-device Accessibility test in this slice.

## Airo relationship

VibeSync does **not** live in the Airo monorepo. It consumes published Airo
libraries only when a later slice needs them.

### Consume later (not slice 1)

| Package | Why later |
|---|---|
| `airo_background_downloads` | GGUF model transfer |
| `airo_job_scheduler` | download / warmup queue |
| `airo_analytics` | local privacy-first telemetry of `VibeSyncEvent` |
| `run_off_main` | Flutter-side JSON/config off the UI isolate |

### Do not use

| Package | Why |
|---|---|
| `airo_core` | M3U/XMLTV/search. Desktop hotkeys and clipboard do not belong there |
| `airo_pairing` / `airo_protocol` | TV↔phone, wrong IPC |
| `iptv_org_api` / `dpad_qualification` / `airo_calendar` | unrelated |
| `feature_mind` Dart `GlobalHotkeyPort` | Dart contract; OS backend unimplemented; VibeSync hotkeys are Rust in `airo_desktop` |
| `airo_mind_llama` | welded to Mind (ggml, meeting crates). VibeSync gets its own inference worker in a later slice |

### Issues to file on Airo when implementation starts (no code)

1. **`airo_core`**: do not add desktop OS integration to the parser crate.
   VibeSync’s `airo_desktop` is the future home. Tracking note so a later
   agent does not “helpfully” extend `airo_core`.
2. **`airo_mind_llama`**: enhancement — a standalone `GenerationEngine` crate
   without meeting/whisper deps, for reuse by VibeSync. Not blocking slice 1.
3. **`airo_background_downloads`**: confirm large GGUF + digest resume is
   enough for model files; file gaps only if the README contract is missing
   them.
4. Mind hotkey issue (#1592 class): leave it. VibeSync will not wait on the
   Dart port.

## Security and privacy (slice 1)

- Local socket, not TCP. No cloud.
- Selection text stays in-process; tests use fixtures, not user documents.
- Logs must not print full selection text by default (length + hash only).
- No accessibility grab in this slice, so no extra TCC prompt.

## Success criteria

- `cargo test` in `vibesync_core` and `airo_desktop` passes
- `vibesyncd` starts, loads YAML, binds IPC, emits `Ready`
- CLI `ProcessSelection` for `correct_grammar` produces the event sequence above
- Killing the Flutter client does not stop a subsequent CLI command
- Invalid YAML refuses start
- Flutter app can connect, show last events, and send `Shutdown`
- No dependency on Airo path packages or llama.cpp

## Later slices (out of this spec’s implementation plan)

2. Real macOS hotkey + clipboard + input behind `airo_desktop`, still fixture engine
3. llama.cpp worker + model registry + validator tightening
4. Dynamic Notch overlay (idle capsule, follow active display)
5. Remaining operations, custom YAML actions, Interactive launcher
6. Windows + Linux real backends with `PlatformCapabilities` gates
7. Extract `airo_desktop` to its own GitHub repo and crates.io

## Commands (once the repo exists)

```
cargo test -p vibesync_core -p airo_desktop
cargo run -p vibesyncd
cargo run -p vibesync-cli -- process-selection correct_grammar
cd app && flutter test
```

## Boundaries

- Always: daemon stays up if UI dies; operations stay generic names; tests
  before treating a slice as done
- Ask first: adding a published dependency, creating extra GitHub repos,
  enabling real OS paste, adding llama.cpp
- Never: cloud inference; stuffing desktop APIs into `airo_core`; in-process
  FRB as the daemon; copying Espanso’s `:trigger` matcher as the core primitive
