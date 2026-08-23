# Live scribe — desktop preview qualification

Status: **QA gate** for the limited desktop preview (not general production).
Date: 2026-08-22
Companion: [LIVE_CAPTURE_FAN_OUT.md](./LIVE_CAPTURE_FAN_OUT.md),
[2026-08-22-live-transcript-ux-vocabulary-design.md](../../superpowers/specs/2026-08-22-live-transcript-ux-vocabulary-design.md)

## Verdict template (LLM / release judge)

| Audience | Ship? | Default mode |
|----------|-------|--------------|
| Internal dogfood (desktop) | Yes | Live + refine |
| Public beta (desktop) | Yes, labeled **Preview** | After recording |
| Public production (all users) | **No** for live-default | After recording |
| Android / iOS production | **No** | After recording |
| Web | **No** (live gated off) | After recording |

**Qualified:** desktop preview with explicit copy and After recording as safe default.
**Not qualified:** broad production live scribe across all platforms.

## Preconditions

- Branch: `main` at or after live-transcript + preview-gate merges.
- Host: macOS, Linux, or Windows (not web, not phone/tablet).
- Airo Mind initialized; whisper speech model installed.
- Settings → Meeting transcription timing: test each mode on desktop.

## Manual test script — YouTube podcast

Use an external audio source so the mic captures system/room audio (user runs this manually):

**URL:** https://www.youtube.com/watch?v=gml71dXrRO0

1. Play the podcast at comfortable volume (speakers or headphones leak to mic).
2. Open Airo Mind → Meeting capture.
3. Grant recording consent (jurisdiction + all-parties if required).
4. For each mode below, record **~2–3 minutes**, then stop.

### Mode A — After recording (baseline)

- Setting: **After recording**
- Expect: no live transcript while recording; processing status after stop; full file transcribe.
- Pass: transcript appears after stop; no LIVE badge during capture.

### Mode B — Live + refine (recommended preview)

- Setting: **Live + refine**
- Expect while recording:
  - Live transcript-first layout, LIVE badge, follow-live scroll.
  - Provisional speaker lanes (`Speaker 1` / `Speaker 2` turn-taking).
  - Amplitude meter (separate from speaker lanes).
  - Partial text updates; stable lines do not rewrite.
- Expect after stop:
  - Refine pass runs on file; speaker labels may change vs live.
- Pass: live text appears within ~seconds; refine completes without error.

### Mode C — Live only

- Setting: **Live**
- Expect: live transcript as in B; **no** second ASR pass (file diarization reconciles speakers on stop when audio path is available).
- Pass: transcript ready at stop without long post-processing transcribe.

### Stress checks (optional)

- **Pause / resume:** pause mid-recording; live transcript pauses; resume continues; no duplicate flood.
- **DEGRADED:** long session or CPU pressure may show degradation banner (ring overflow); recording file still saved.
- **Admission refusal:** on low-memory device, live may refuse before mic — warning copy, file-only recording continues.

## Platform gates (automated / UI)

| Host | Live modes in settings | Live pipeline at capture |
|------|------------------------|---------------------------|
| Desktop | Yes + preview disclaimer | Yes |
| Web | Hidden; After recording only | No |
| Android / iOS | Hidden; After recording only | No |

## CI evidence (dev)

- `packages/feature_mind/test/capture/` — capture coordinator, vocabulary, speaker UI, fan-out recorder, admission warning, live IR rail.
- `rust/airo_mind_audio` — ring overflow → degraded; fan-out crash isolation; governor; Linux probes; latency harness.
- `rust/airo_mind_whisper` — diarization label assignment tests; live IR emit on stable.
- `rust/airo_mind_meeting` — incremental Conversation IR (stable-sentence extractor).

## Open for Stage 2 (not blocking preview sign-off)

- In-process native capture (cpal / AudioRecord / AVAudioEngine) so `push_live_pcm` leaves the FRB surface.
- Crash-during-live → file transcribes (per-platform process kill; host fan-out test is done).
- Live RTF / time-to-first-partial SLO in release gates on real weights.
- Persona mapping / voice enrollment (P2).
