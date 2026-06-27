# Google AI Edge Gallery Adaptation Plan

**Date:** 2026-06-22

**Goal:** Adapt Google AI Edge Gallery's capability-first on-device AI pattern into Airo before adding Airo-specific specialization.

## Research Sources

- Google AI Edge Gallery README: https://github.com/google-ai-edge/gallery
- Gallery navigation wiki: https://github.com/google-ai-edge/gallery/wiki/3.-Navigating-the-App
- Gallery core capabilities wiki: https://github.com/google-ai-edge/gallery/wiki/4.-Using-Core-AI-Capabilities
- Gallery model management wiki: https://github.com/google-ai-edge/gallery/wiki/5.-Model-Management
- Gallery local model import wiki: https://github.com/google-ai-edge/gallery/wiki/6.-Importing-Local-Models-(optional)
- Gallery Android 1.0.12 model allowlist: https://raw.githubusercontent.com/google-ai-edge/gallery/main/model_allowlists/1_0_12.json
- LLM Inference Android guide: https://developers.google.com/edge/mediapipe/solutions/genai/llm_inference/android
- LiteRT-LM: https://github.com/google-ai-edge/LiteRT-LM
- MCP, notifications, and session continuity update: https://developers.googleblog.com/a-smarter-google-ai-edge-gallery-mcp-integration-notifications-and-session-continuity/
- Function calling update: https://developers.googleblog.com/on-device-function-calling-in-google-ai-edge-gallery/

## Gallery Pattern To Copy First

Google AI Edge Gallery uses this product flow:

1. Home screen shows a grid of AI capabilities.
2. User selects a capability.
3. App shows compatible models only for that capability.
4. User downloads a model if needed, then tries it.
5. Task screen exposes only controls relevant to that capability.
6. Advanced knobs remain available but secondary.

Airo should keep the same mental model:

```text
Project category
  -> compatible default package
  -> download/setup prompt if missing
  -> task-specific project/chat workspace
  -> advanced model management in Profile
```

## Capability Mapping

| Gallery capability | Gallery behavior | Airo v1 equivalent | Default package direction |
|---|---|---|---|
| AI Chat | Multi-turn local chat, optional thinking mode on supported models | Assistant Chat Project | Gemini Nano on supported Pixel; Gemma 4 E2B/E4B LiteRT-LM package otherwise |
| Ask Image | Image + prompt, up to supported image limit, local multimodal response | Image Help Project / Quest upload | Gemma 3n/Gemma 4 multimodal LiteRT-LM package |
| Audio Scribe | Record or select short audio, transcribe/translate locally | Audio Notes / Meeting Intelligence | Gallery-compatible Gemma 3n multimodal path first; Whisper-style pipeline later if needed |
| Prompt Lab | Single-turn templates: freeform, summarize, rewrite, code | Prompt/Docs Project | Gemma 4 E2B for default; E4B for higher-capability devices |
| Agent Skills | On-device multi-step skills with tools/resources | Airo Agent Skills | Gemma 4 for planning/tool selection, app-owned connectors for execution |
| Mobile Actions | Offline function calls via FunctionGemma 270M | Airo Mobile Actions | FunctionGemma-style 270M action model, not a general chat model |
| Model Management & Benchmark | Download, try, delete, stats, import local models | Profile > AI Packages | Keep advanced and developer-facing |

## Required Airo UX Changes

- [x] Rename Assistant setup surface from model library to project/category setup in the main Assistant entry.
- [x] Show category cards first: Chat, Docs, Image, Audio, Actions.
- [x] For each category, show the default package instead of a long model list.
- [x] If package is absent, ask: "Download this package?" before opening model management.
- [x] Keep model filters, custom imports, and active-model overrides in Profile.
- [ ] Add per-turn stats behind a compact "Stats" affordance: TTFT, prefill speed, decode speed, latency.
- [ ] Keep inference parameters behind an advanced sheet per project, not visible by default.

## Required Runtime Changes

- [x] Add LiteRT-LM package metadata for Gemma 4 E2B/E4B and Gemma 3n multimodal packages.
- [x] Add MobileActions-270M package metadata for action routing.
- [x] Add package compatibility fields:
  - supported capabilities
  - supported modalities
  - backend preference: CPU/GPU/NPU/AICore
  - min memory and storage
  - gated license/Hugging Face login state
  - download URL and checksum
- [x] Filter packages by category before showing options.
- [ ] Add background download state and completion notification.
- [ ] Add package readiness states:
  - ready
  - downloadable
  - downloading
  - gated login needed
  - unsupported device
  - insufficient storage/memory

## Required Task Surfaces

### Chat Project

- Multi-turn chat with persistent project/session state.
- Thinking mode only for supported Gemma 4 packages.
- Gemini Nano remains fast private default on Pixel when available.

### Image Project

- Image picker/camera entry.
- Prompt input attached to image context.
- Use multimodal package only; do not route image to text-only model.
- Show setup prompt if multimodal package is missing.

### Audio Project

- Record or import short clip first.
- Start with Gallery-compatible audio + prompt multimodal flow.
- Meeting Intelligence can specialize later with diarization, long recordings, and redaction.

### Prompt/Docs Project

- Single-turn template mode for summarize, rewrite, code, freeform.
- Template selection happens before model details.
- Advanced temperature/top-k only in a sheet.

### Mobile Actions

- Use a small specialized function-calling package.
- Never let the general chat model execute OS/app actions directly.
- App-owned connectors validate capability and confirmation requirements.

### Agent Skills

- Keep skill manifests and connector registry.
- Add MCP only after security review.
- Keep tool descriptions short to fit on-device context.

## Implementation Order

### Phase 1: Product Shell

- [x] Convert Assistant setup to Gallery-style category grid.
- [x] Keep Profile as advanced package manager.
- [x] Add package setup confirmation dialog.
- [x] Add "Project > Session > Artifact" hierarchy in UI copy.

### Phase 2: Package Catalog

- [x] Extend `ModelCatalog` with Gallery-style packages:
  - Gemma 4 E2B text/reasoning
  - Gemma 4 E4B high capability
  - Gemma 3n/Gemma 4 multimodal for image/audio
  - FunctionGemma 270M for actions
- [x] Add compatibility metadata and category filtering.

### Phase 3: Downloads

- [ ] Move package download into the category flow.
- [ ] Add explicit license/login state for gated models.
- [ ] Add background progress and completion notification.

### Phase 4: Task Workspaces

- [ ] Chat: persistent sessions and optional thinking mode.
- [ ] Image: picker + prompt + multimodal runtime.
- [ ] Audio: record/import + short transcription/translation flow.
- [ ] Prompt Lab: templates and advanced parameters.
- [ ] Mobile Actions: FunctionGemma-style tool call routing.

### Phase 5: Benchmark And Observability

- [ ] Store per-response performance stats locally.
- [ ] Show stats behind an optional affordance.
- [ ] Use stats to refine default package selection per device.

## Decisions

- Do not expose raw model choice in the main user journey.
- Do not make cloud fallback look on-device.
- Do not execute actions from a general chat model.
- Do not add MCP/community skills until local built-in skills are safe.
- Copy Gallery's capability-first structure first; specialize Airo after the foundation works.
