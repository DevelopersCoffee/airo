# AIRO QA & Regression Suite

Every bug fix in AIRO becomes a permanent regression test. All features must pass these edge-case verifications before release.

## Download Architecture
- [ ] Cancel download at 1%
- [ ] Cancel download at 50%
- [ ] Cancel download at 99%
- [ ] Resume download after app restart
- [ ] Cancel download after app is backgrounded
- [ ] Handle multiple simultaneous downloads
- [ ] Verify behavior when Wi-Fi is interrupted
- [ ] Verify behavior when switching to mobile data
- [ ] Verify behavior when device reboots during download
- [ ] Handle insufficient storage gracefully
- [ ] Verify file hash/integrity after download completes

## Whisper & Audio
- [ ] Process long meetings (2+ hours) without crashing
- [ ] Handle extended periods of silence
- [ ] Handle excessive background noise
- [ ] Rapid speaker changes
- [ ] Memory leak checks on large audio files
- [ ] Handle recording interruptions (phone call, alarm)
- [ ] Behavior on low RAM devices
- [ ] Device rotation during recording

## Speaker Diarization
- [ ] Distinguish similar voices
- [ ] Overlapping speech handling
- [ ] Speaker persistence across meeting continuation

## LLM Stability
- [ ] Model loading failure handling
- [ ] Context overflow protection
- [ ] Memory exhaustion safety
- [ ] Cancellation mid-generation
- [ ] Extremely large prompts/meetings

## Background Processing
- [ ] App killed by OS
- [ ] Device reboot behavior
- [ ] Battery optimization restrictions
- [ ] Work rescheduling and duplicate worker prevention
