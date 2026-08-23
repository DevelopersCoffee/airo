# Evaluation results

Status: **Incomplete.** Date: 2026-08-23
Verdict: [NOT PRODUCTION QUALIFIED](./production-qualification.md)

## Automated (this pass)

| Suite | Result |
|---|---|
| `airo_mind_audio` fan-out + isolation + governor + latency harness | Run locally in this change |
| `airo_mind_meeting` incremental Conversation IR | Run locally in this change |
| `airo_mind_core` `check_speech_admission` | Run locally in this change |
| `feature_mind` fan-out port, live admission, capture screen warning | Run locally in this change |

## Golden conversations (not collected)

The production spec requires English / Hindi / Hinglish, technical, 2- and
4-speaker, overlap, noise, and proper-noun fixtures with WER, speaker error,
entity/action/decision accuracy. **None of those golden scores are claimed
here.** Existing `airo_mind_meeting` IR goldens remain post-recording only.

## Remaining blockers

See [production-qualification.md](./production-qualification.md) §Still open.
