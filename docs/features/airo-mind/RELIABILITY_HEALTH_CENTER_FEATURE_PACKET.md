# Airo / Airo Mind Reliability Health Center — Feature Packet

Status: Proposed implementation slice
Base: `origin/main` (2026-07-30)
Owner: Framework Agent (runtime, model routing, download contracts)
Application reviewers: Brain / AI Agent, Flutter Architect, Product Manager
Required reviewers: Chief Architect, Chief Performance Officer, Chief QA Officer,
Chief Security Officer, Chief Documentation Officer

## Problem

Reviews show that users cannot tell whether a model is downloaded, valid,
compatible, ready, warmed, or running. Failures are especially damaging during
large-model loading, downloads, and accelerator selection on flagship phones.

## User outcome

In both Airo and Airo Mind, a user can open a model's Health Center and see a
truthful, structured status timeline, the measured memory/runtime decision, the
failure reason, and a deterministic recovery action. The UI never guesses from
exception strings.

## Ownership and boundary

- `packages/core_ai`: framework contracts, model health, planner diagnostics,
  recovery semantics, and model/download status composition.
- `packages/platform_downloads`: resumable download state and integrity facts;
  no product copy or model-selection policy.
- `app/lib/features/agent_chat` and the Airo Mind surface: presentation and
  user actions only; consume typed framework models.
- Android/iOS platform adapters: measured device/runtime facts only.

This is mixed framework/application work. The cross-boundary contract is the
versioned `ModelHealthReport` and `RuntimeDecisionTrace` DTOs below.

## Contract (v1)

The health report must expose:

- model identity and capability;
- download state, bytes, resumability, and integrity state;
- compatibility state and measured device memory;
- selected runtime/accelerator/context when a plan exists;
- ordered lifecycle stages: downloaded, verified, compatible, runtime-ready,
  warmed-up, running;
- typed failure code, user-safe explanation, and recovery actions.

The planner remains pure: no I/O, platform calls, or hidden state. Download and
device services populate facts before report composition.

## Deterministic use cases

1. Verified model with sufficient memory reports `Running` and GPU/CPU choice.
2. Verified model below transient-memory budget reports `Recoverable`, explains
   the deficit, and offers reduced context before model switching.
3. Interrupted download resumes from the saved byte offset and never reports
   `Verified` until checksum validation succeeds.
4. Corrupt model reports `RepairRequired`; retry does not delete unrelated
   models.
5. Missing runtime reports `RuntimeUnavailable` with installed compatible
   alternatives.
6. Airo Mind renders the same report as Airo without importing LiteRT or
   Android-specific APIs.

## Automation flows

- Rust/Dart unit tests cover report composition and planner determinism.
- Download-manager contract tests cover pause/resume/retry/checksum/repair.
- Widget tests assert the Health Center timeline, Why panel, and accessibility
  labels for success and each failure code.
- Android smoke flow installs a debug build, launches Airo, opens the model
  Health Center, and captures the structured trace; no real model download is
  required for the deterministic path.

## Security and privacy

Health reports contain local device/runtime facts only. They must not include
tokens, model contents, prompts, chat text, or raw filesystem paths. Exported
diagnostics are opt-in and redact identifiers. Download URLs are treated as
untrusted input and integrity verification is mandatory before installation.

## Rollback

The Health Center is additive. If the new surface fails, the existing model
library remains usable; report composition can be disabled behind the existing
model-management feature gate without changing model files.

## Phase boundary

This slice implements the typed health/diagnostic contract, deterministic
composition, and presentation seam. The application now also exposes a
capability-driven Model Advisor, encrypted Airo Mind backup verification,
expiring encrypted LAN backup transfer, read-aloud actions for assistant
responses, resilient download controls, and OpenAI-compatible GGUF routing for
LM Studio, Ollama, and llama.cpp servers. Cloud sync and additional native
backends remain follow-up slices using these contracts; local chat history is
now versioned, bounded, restored on-device, and included in encrypted backup
exports. Chat responses also render fenced code with language labels and
one-tap code copying. The chat surface applies a persisted SafetyProfile
(strict, balanced, or permissive) while retaining harmful-content blocking and
maximum-input protection for every profile; blocked input and output are
reported as user-safe assistant messages.

## Airo Mind use-case catalog

The Airo Mind shell now exposes the product use cases represented by the
approved reference designs: AI Chat (including a supported-model thinking
toggle), Agent Skills, Ask Image, Audio Scribe, Prompt Lab, Mobile Actions,
Tiny Garden, and Model Management/Benchmark. These tiles are intentionally
thin entry points into the model library and runtime health surface; they do
not duplicate runtime policy in the application layer. Local-model copy makes
the privacy boundary explicit: prompts and inference stay on-device when a
local runtime is selected, while cloud models remain clearly labeled.
