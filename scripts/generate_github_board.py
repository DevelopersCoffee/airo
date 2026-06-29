import subprocess
import json
import time

REPO = "DevelopersCoffee/airo"
PROJECT = "Airo – Engineering Board"

MILESTONES = [
    "Phase 1 — Core Platform",
    "Phase 2 — Reliability",
    "Phase 3 — Intelligence",
    "Phase 4 — Polish"
]

# Title, Label, Milestone, Body
FEATURES = [
    ("Intelligent Model Manager", "enhancement", "Phase 1 — Core Platform", """## Intelligent Model Manager (Highest Priority)
Current AIRO
* Download model
* Use model

Target
* Installed models
* Active model
* Recommended models
* Download queue
* Storage usage
* Update available
* Delete model
* Warm model into memory
* Preload frequently used models"""),

    ("Model Routing", "enhancement", "Phase 4 — Polish", """## Model Routing
Instead of selecting one model globally.
Support dedicated models for
* Chat
* Meeting summarization
* STT
* TTS
* OCR
* Embeddings
* Translation

Allow automatic routing."""),

    ("Model Warm-up", "enhancement", "Phase 3 — Intelligence", """## Model Warm-up
Before starting a meeting
* Load Whisper
* Load Speaker Diarization
* Load Embedding model
* Warm LLM

Meeting should begin immediately."""),

    ("Progressive Download System", "enhancement", "Phase 1 — Core Platform", """## Progressive Download System
Downloads should support
* Resume
* Pause
* Retry
* Cancel
* Background download
* Queue
* Integrity verification
* Hash validation

Never restart from zero unless required."""),

    ("Live Download Progress", "enhancement", "Phase 4 — Polish", """## Live Download Progress
Display
* Current speed
* Remaining time
* Percentage
* Current stage

Example
Downloading Whisper Large
67%
124 MB / 185 MB
2m remaining"""),

    ("Audio Mode", "enhancement", "Phase 4 — Polish", """## Audio Mode
Meeting mode should support
* Live transcription
* Speaker detection
* Voice playback
* AI interruption
* Push-to-talk
* Continuous listening"""),

    ("Semantic Memory", "enhancement", "Phase 3 — Intelligence", """## Semantic Memory
Every meeting becomes searchable.

Examples
"What did Rahul say about Kubernetes?"
"Meetings discussing Flutter"
"Database migration decisions\""""),

    ("AI Timeline", "enhancement", "Phase 3 — Intelligence", """## AI Timeline
Instead of a plain transcript.
Generate
Meeting ↓ Topic ↓ Discussion ↓ Decision ↓ Action Item ↓ Owner ↓ Deadline"""),

    ("Meeting Intelligence", "enhancement", "Phase 3 — Intelligence", """## Meeting Intelligence
Generate automatically
* Summary
* Decisions
* Risks
* Open Questions
* Follow-ups
* Blockers
* Dependencies"""),

    ("Speaker Learning", "enhancement", "Phase 3 — Intelligence", """## Speaker Learning
Every meeting improves recognition.
Unknown Speaker 1 ↓ John ↓ Recognized automatically in future meetings"""),

    ("Local Knowledge Graph", "enhancement", "Phase 3 — Intelligence", """## Local Knowledge Graph
Generate relationships
People, Projects, Topics, Documents, Meetings, Tasks
Everything stored locally."""),

    ("Background AI Processing", "enhancement", "Phase 2 — Reliability", """## Background AI Processing
Never block UI.
Run independently
* Embedding generation
* Speaker clustering
* Meeting indexing
* Summaries
* Memory updates"""),

    ("Storage Dashboard", "enhancement", "Phase 1 — Core Platform", """## Storage Dashboard
Show
Installed models, Meeting storage, Embedding storage, Database size, Audio cache, Available space"""),

    ("AI Search", "enhancement", "Phase 4 — Polish", """## AI Search
Search
Transcript, Summary, Participants, Topics, Projects, Tasks
Using semantic embeddings."""),

    ("Conversation Replay", "enhancement", "Phase 4 — Polish", """## Conversation Replay
Replay
Audio, Transcript, Highlighted words, Current speaker, Timeline""")
]

BUGS = [
    ("Validation: Downloads Edge Cases", "bug", "Phase 2 — Reliability", """## Downloads Verification
Verify
* Cancel during download
* Resume after restart
* Pause
* Retry
* Duplicate downloads
* Corrupted downloads
* Interrupted Wi-Fi
* Switching to mobile data
* Device reboot during download
* Insufficient storage
* Download verification
* Progress synchronization
* Queue ordering"""),

    ("Validation: Whisper Robustness", "bug", "Phase 2 — Reliability", """## Whisper Verification
Verify
* Long meetings (2+ hours)
* Silence handling
* Background noise
* Speaker changes
* Model switching
* Large audio files
* Memory leaks
* Recording interruption
* Low RAM devices
* Rotation during recording"""),

    ("Validation: Speaker Diarization", "bug", "Phase 2 — Reliability", """## Speaker Diarization Verification
Verify
* Similar voices
* Fast speaker switching
* Overlapping speech
* Unknown speakers
* Speaker rename
* Speaker merge
* Speaker persistence
* Meeting continuation"""),

    ("Validation: LLM Stability", "bug", "Phase 2 — Reliability", """## LLM Verification
Verify
* Model loading failure
* Context overflow
* Memory exhaustion
* Model switching
* Cancellation
* Summary generation
* Very long meetings
* Large prompts
* Offline mode
* Low battery mode"""),

    ("Validation: Audio Playback", "bug", "Phase 2 — Reliability", """## Audio Playback Verification
Verify
* Seek bar accuracy
* Playback speed
* Background playback
* Headphones
* Bluetooth
* Incoming call interruption
* Resume playback
* Audio focus changes"""),

    ("Validation: Notifications", "bug", "Phase 2 — Reliability", """## Notifications Verification
Verify
* Recording notification
* Download notification
* Progress updates
* Completion
* Failure
* Deep links
* Duplicate notifications
* Foreground suppression"""),

    ("Validation: Database Reliability", "bug", "Phase 2 — Reliability", """## Database Verification
Verify
* Migration
* Crash recovery
* Corrupted database
* Large meeting history
* Search indexing
* Backup
* Restore"""),

    ("Validation: Search Edge Cases", "bug", "Phase 2 — Reliability", """## Search Verification
Verify
* Misspelled queries
* Synonyms
* Speaker search
* Project search
* Mixed-language meetings
* Very large datasets"""),

    ("Validation: Background Processing", "bug", "Phase 2 — Reliability", """## Background Processing Verification
Verify
* App killed
* Device reboot
* Battery optimization
* Background restrictions
* Work rescheduling
* Duplicate workers
* Progress persistence"""),

    ("Validation: UI Responsiveness", "bug", "Phase 2 — Reliability", """## UI Verification
Verify
* Orientation changes
* Split screen
* Foldables
* Tablets
* Dynamic font scaling
* Dark mode
* Accessibility
* Keyboard handling
* Offline state
* Empty state
* Error state
* Loading state"""),

    ("Validation: Performance Benchmarks", "bug", "Phase 2 — Reliability", """## Performance Verification
Benchmark
Cold start, Warm start, Model loading time, First transcript latency, Summary generation time, Embedding speed, Speaker detection latency, Memory usage, CPU usage, GPU/NPU utilization, Battery consumption, Storage growth

## Engineering Practices to Adopt
* Every feature must include telemetry (stored locally if offline).
* Every background task must be resumable.
* Every download must be recoverable.
* Every expensive operation must expose progress.
* Every AI task must be cancellable.
* Every model must support integrity verification.
* Every database schema change must include migrations.
* Every release must include performance benchmarks.
* Every release must include battery impact measurements.
* Every release must include regression tests for recording, downloads, transcription, and search.""")
]

def run(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True)

def create_milestones():
    print("Creating Milestones...")
    # First get existing milestones
    res = run(f'gh api repos/{REPO}/milestones')
    existing = []
    if res.returncode == 0:
        existing = [m['title'] for m in json.loads(res.stdout)]
        
    for m in MILESTONES:
        if m in existing:
            print(f"Milestone already exists: {m}")
        else:
            print(f"Creating milestone: {m}")
            # state defaults to open
            run(f'gh api repos/{REPO}/milestones -f title="{m}"')

def create_issue(title, label, milestone, body):
    print(f"Creating issue: {title}")
    
    # We must escape double quotes in body if we pass it directly, 
    # but using a temporary file is safer.
    with open('/tmp/issue_body.md', 'w') as f:
        f.write(body)
    
    cmd = f'gh issue create --repo {REPO} --title "{title}" --label "{label}" --milestone "{milestone}" --project "{PROJECT}" --body-file /tmp/issue_body.md'
    res = run(cmd)
    if res.returncode != 0:
        print(f"Failed to create issue '{title}': {res.stderr}")
    else:
        print(f"Success: {res.stdout.strip()}")
    time.sleep(1) # sleep to avoid rate limits

def main():
    create_milestones()
    print("\\n--- Creating Feature Issues ---")
    for title, label, milestone, body in FEATURES:
        create_issue(title, label, milestone, body)
        
    print("\\n--- Creating Bug/Validation Issues ---")
    for title, label, milestone, body in BUGS:
        create_issue(title, label, milestone, body)
        
    print("\\nDone!")

if __name__ == "__main__":
    main()
