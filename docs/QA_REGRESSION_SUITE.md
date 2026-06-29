# AIRO QA & Regression Suite

Every bug fix in AIRO becomes a permanent regression test. All features must pass these edge-case verifications before release.

## Model Installation & Download Architecture
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
- [ ] HTTP redirects
- [ ] Corrupted file
- [ ] Missing dependency
- [ ] Duplicate model
- [ ] Invalid manifest
- [ ] Corrupted archive
- [ ] Cancel during verification
- [ ] Stalled transfer
- [ ] Slow network
- [ ] Partial download
- [ ] Hash mismatch
- [ ] Retry exhaustion
- [ ] App kill recovery

## Local Import
- [ ] Missing mmproj
- [ ] Wrong tokenizer
- [ ] Unsupported format
- [ ] Duplicate filenames
- [ ] Nested folders
- [ ] External storage removal
- [ ] USB disconnect

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

## LLM Stability & Runtime Independence
- [ ] Model loading failure handling
- [ ] Context overflow protection
- [ ] Memory exhaustion safety
- [ ] Cancellation mid-generation
- [ ] Extremely large prompts/meetings
- [ ] Runtime selection
- [ ] Incorrect model metadata
- [ ] Unsupported runtime
- [ ] Model initialization failure
- [ ] Switching between model families
- [ ] Remove chat model
- [ ] Image generation only
- [ ] Speech only
- [ ] OCR only
- [ ] Embedding only
- [ ] Mixed runtime failures

## Background Processing & Job Scheduler
- [ ] App killed by OS (termination during execution)
- [ ] Device reboot behavior
- [ ] Battery optimization enabled/restrictions
- [ ] Work rescheduling and duplicate worker prevention
- [ ] Job retry
- [ ] Job cancellation
- [ ] Dependency ordering
- [ ] Crash during installation
- [ ] Process kill
- [ ] Foreground service restart
- [ ] Queue persistence

## Keyboard Handling
- [ ] Tap outside to dismiss keyboard
- [ ] Verify no transcript overlap (auto-scroll)
- [ ] Safe area handling
- [ ] Split-screen mode
- [ ] Landscape mode
- [ ] Foldable posture changes
- [ ] Hardware/Bluetooth keyboard attach/detach
- [ ] Floating keyboard support
- [ ] Open keyboard while recording
- [ ] Keyboard animation interruption

## Theme System
- [ ] Switch theme during active inference
- [ ] Restart persistence (theme saves correctly)
- [ ] System theme changes properly reflected in-app
- [ ] High contrast mode / AMOLED mode compatibility

## Model Selection & Hardware Compatibility
- [ ] Load unsupported model (should gracefully fail/reject)
- [ ] Switch execution backend (e.g. GPU to CPU)
- [ ] Low-memory startup behavior
- [ ] Unsupported NPU fallback
- [ ] GPU unavailable fallback
- [ ] Missing runtime libraries
- [ ] Hardware recommendation changes on different devices
- [ ] Model metadata rendering correctly
- [ ] Template switching handles parsing correctly

## Platform Behavior & Compliance
- [ ] Android notification behavior (expanding, dismissing)
- [ ] iOS modal transitions
- [ ] Deep linking execution & recovery
- [ ] Background recording restrictions
- [ ] Notification permission denied
- [ ] Foreground service interruption
- [ ] Storage permission changes
- [ ] Platform-specific permission revocation

## Persistence
- [ ] Upgrade database schema safely
- [ ] Restore user preferences after app restart
- [ ] Recover interrupted database writes
- [ ] Handle extremely large meeting histories
- [ ] Handle massive embedding databases without slowing down
- [ ] Corrupted preference recovery

## Privacy
- [ ] Delete all AI data correctly removes files and DB entries
- [ ] Export user data creates valid zip/archive
- [ ] Clear knowledge base completely purges RAG data
- [ ] Remove speaker profiles securely
- [ ] Remove downloaded models frees disk space properly

## Tool Calling & Execution
- [ ] Unknown tool
- [ ] Invalid parameters
- [ ] Tool timeout
- [ ] Consecutive tool calls
- [ ] Tool failure recovery
- [ ] Circular tool requests
- [ ] Parallel tool execution
- [ ] Blocked URL
- [ ] Invalid domain
- [ ] Recursive tool calls
- [ ] Streaming interruption
- [ ] Large responses
- [ ] Permission denial
- [ ] Unsupported tools
- [ ] Tool cancellation
- [ ] Tool dependency failures

## Runtime Configuration & Adaptation
- [ ] Change KV cache during runtime
- [ ] Switch inference backend
- [ ] Large context
- [ ] Low memory (Memory pressure during inference)
- [ ] GPU unavailable
- [ ] Flash Attention unavailable
- [ ] Context scaling
- [ ] Thermal throttling
- [ ] Background task suspension

## URL Processing
- [ ] Redirect loops
- [ ] SSRF attempts
- [ ] Unsupported content types
- [ ] Large documents
- [ ] Malformed HTML
- [ ] Network interruption

## Vision
- [ ] Large images
- [ ] Corrupted images
- [ ] Multiple concurrent OCR jobs
- [ ] Unsupported formats
- [ ] Low-memory image processing

## Onboarding & Navigation
- [ ] Skip onboarding
- [ ] Interrupted setup/onboarding
- [ ] Permission denied
- [ ] First model download failure
- [ ] Resume onboarding after restart
- [ ] Unsupported hardware
- [ ] Back navigation consistency
- [ ] Rotation during navigation
- [ ] Multi-window mode
- [ ] State restoration after process death

## Capability Detection
- [ ] Missing metadata
- [ ] Incorrect capability flags
- [ ] Runtime capability changes
- [ ] Unsupported feature requests
- [ ] Model upgrade changing capabilities
- [ ] New model family

## Knowledge Base & Workspaces (Isolation)
- [ ] Large document collections
- [ ] Corrupted embeddings
- [ ] Duplicate documents
- [ ] Deleted documents
- [ ] Re-index after crash
- [ ] Workspace isolation boundary
- [ ] Delete workspace
- [ ] Import/export workspace
- [ ] Concurrent updates
- [ ] Large meeting history
- [ ] Workspace migration
- [ ] New workspace starts strictly clean
- [ ] Workspace switching state leak prevention
- [ ] Conversation reset

## Search Architecture
- [ ] Empty index
- [ ] Large vector database
- [ ] Mixed keyword and semantic queries
- [ ] Ranking correctness
- [ ] Permission filtering

## Thinking Mode
- [ ] Toggle during conversation
- [ ] Model without reasoning support
- [ ] Switching profiles
- [ ] Persistence across sessions
- [ ] Mixed reasoning workloads

## Startup & Discovery (Lazy Initialization)
- [ ] Slow initialization
- [ ] Missing model registry
- [ ] Corrupted settings
- [ ] Delayed provider discovery
- [ ] Interrupted startup
- [ ] No network
- [ ] Slow LAN
- [ ] Multiple providers
- [ ] Duplicate providers
- [ ] Network change during discovery
- [ ] Open app without recording (zero AI startup overhead)
- [ ] Exit immediately
- [ ] Create first meeting lazy init
- [ ] Cancel first meeting
- [ ] Startup timing

## Context & Streaming
- [ ] Context truncation
- [ ] Attachment persistence
- [ ] Regenerate with attachments
- [ ] Large knowledge injection
- [ ] Context overflow
- [ ] SSE interruption
- [ ] NDJSON parsing
- [ ] Partial responses
- [ ] Tool response streaming
- [ ] Stream cancellation

## Native Runtime Stability & Backend Selection
- [ ] Context destroyed during inference
- [ ] Thread race
- [ ] GPU initialization failure
- [ ] Runtime restart
- [ ] Bridge shutdown during generation
- [ ] GPU unavailable fallback (Backend Selection)
- [ ] NPU unavailable fallback (Backend Selection)
- [ ] Backend failure
- [ ] Manual override testing

## Recommendations
- [ ] Low-memory device (Fallback recommend)
- [ ] Unsupported backend check
- [ ] Missing metadata handling
- [ ] Corrupted recommendation cache
- [ ] Recommendation refresh
