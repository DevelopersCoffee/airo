# AIRO Architecture Specification

# Part 3 — Meeting Intelligence Platform

Version: 1.0 (Draft)

---

# 1. Objective

Meetings are AIRO's primary source of knowledge.

The Meeting Intelligence Platform is responsible for transforming raw audio into structured, searchable, and reusable knowledge.

A meeting is **not** treated as a recording.

A meeting becomes a continuously evolving knowledge object.

---

# 2. Vision

Traditional meeting applications produce:

```
Recording

↓

Transcript

↓

Summary
```

AIRO should produce:

```
Recording

↓

Speech Segmentation

↓

Speaker Diarization

↓

Streaming Transcript

↓

Meeting Timeline

↓

Topic Detection

↓

Action Items

↓

Decision Detection

↓

Entity Extraction

↓

Knowledge Graph

↓

Embeddings

↓

Workspace Knowledge
```

---

# 3. Core Principles

Meeting intelligence must be:

* Offline-first
* Incremental
* Streaming
* Recoverable
* Searchable
* Extensible
* Hardware aware

---

# 4. Meeting Lifecycle

```
User starts meeting

↓

Audio Pipeline Initialized

↓

Microphone Capture

↓

Voice Activity Detection

↓

Audio Buffering

↓

Streaming STT

↓

Speaker Identification

↓

Timeline Construction

↓

Incremental Transcript

↓

Meeting Intelligence Pipeline

↓

Knowledge Storage

↓

Search Index

↓

Background Refinement
```

---

# 5. Recording Pipeline

Recording service responsibilities

* Microphone management
* Background recording
* Audio buffering
* Audio segmentation
* Audio recovery
* Sample-rate normalization
* Storage

The recording layer should never know anything about AI.

---

# 6. Audio Pipeline

Pipeline stages

```
Microphone

↓

Noise Reduction

↓

Voice Activity Detection

↓

Silence Detection

↓

Chunk Builder

↓

Streaming Queue
```

The audio pipeline outputs normalized chunks.

---

# 7. Streaming Speech Recognition

Use Whisper or equivalent.

Requirements

* Streaming transcription
* Partial hypotheses
* Incremental refinement
* Offline execution
* Language detection
* Timestamp generation

Transcript should continuously improve instead of waiting for the end.

---

# 8. Speaker Intelligence

Speaker intelligence should evolve over time.

Stage 1

Anonymous speakers

```
Speaker A

Speaker B
```

Stage 2

User assigns names

```
Alice

Bob
```

Stage 3

Voice profile learned

Future meetings automatically identify speakers.

---

# 9. Speaker Profile

Each speaker stores

* Name
* Voice embedding
* Confidence
* Speaking rate
* Speaking duration
* Language preference
* Meeting participation
* Interaction history

Profiles improve continuously.

---

# 10. Conversation Timeline

Instead of plain transcript.

Represent conversations as a timeline.

```
09:01

Alice

Discusses architecture

↓

09:04

Bob

Questions deployment

↓

09:06

Decision recorded

↓

09:09

Action item assigned
```

Timeline becomes the primary navigation model.

---

# 11. Transcript Model

Each transcript segment stores

```yaml id="j9l2u7"
speaker

start_time

end_time

text

confidence

language

emotion

topics

entities

embedding

audio_reference
```

The transcript becomes structured data.

---

# 12. Meeting Intelligence Pipeline

After every transcript update

```
Transcript

↓

Topic Detection

↓

Action Item Extraction

↓

Decision Detection

↓

Risk Detection

↓

Entity Extraction

↓

Task Suggestions

↓

Knowledge Graph Update

↓

Embedding Generation
```

Everything runs asynchronously.

---

# 13. Topic Detection

Meeting topics evolve continuously.

Example

Authentication

↓

Architecture

↓

Database

↓

Deployment

↓

Testing

↓

Performance

Users can jump directly to any topic.

---

# 14. Action Item Extraction

Automatically detect

* Tasks
* Owners
* Due dates
* Dependencies
* Follow-ups

Example

```
Bob will update the deployment pipeline by Friday.
```

↓

Owner

Bob

↓

Task

Update deployment pipeline

↓

Due

Friday

---

# 15. Decision Detection

Capture important decisions.

Example

```
We will migrate to LiteRT.
```

Store

* Decision
* Participants
* Timestamp
* Confidence

Decision history becomes searchable.

---

# 16. Entity Extraction

Recognize

* APIs
* Products
* Libraries
* Companies
* Services
* Files
* URLs
* Jira IDs
* GitHub repositories

Entities connect meetings to knowledge.

---

# 17. Knowledge Graph

Instead of isolated meetings.

Connect

Meeting

↓

People

↓

Projects

↓

Documents

↓

Tasks

↓

Repositories

↓

Technologies

↓

Future meetings

Knowledge grows organically.

---

# 18. Meeting Memory

Every meeting contributes to workspace memory.

Store

* Summary
* Decisions
* Tasks
* Topics
* Participants
* Entities
* Embeddings

This memory becomes searchable.

---

# 19. Incremental Summarization

Instead of waiting until recording stops.

Continuously generate

* Running summary
* Key decisions
* Open questions
* Risks
* Action items

Meeting end requires minimal processing.

---

# 20. Search Integration

Meeting search should support

Keyword

Semantic

Speaker

Topic

Date

Workspace

Decision

Task

Example

```
Meetings where Alice discussed PostgreSQL.
```

---

# 21. Workspace Integration

Meetings belong to workspaces.

Workspace owns

* Meeting history
* Shared memory
* Documents
* Knowledge graph
* Tasks
* Search index

Meetings inherit workspace context.

---

# 22. Background Intelligence

When recording ends

Run background jobs

* Better transcription
* Better diarization
* Improved summaries
* Better embeddings
* OCR attachments
* Topic refinement

Immediate results remain available.

---

# 23. Storage Architecture

Meeting package

```
Meeting

├── Metadata

├── Audio

├── Transcript

├── Speakers

├── Summary

├── Embeddings

├── Knowledge Links

├── Tasks

├── Decisions

└── Attachments
```

Everything remains independently recoverable.

---

# 24. Failure Recovery

Recover from

* Recording interruption
* Application restart
* Battery optimization
* Low storage
* OOM
* Partial transcript

Recording should never be lost.

---

# 25. Platform Components

MeetingPlatform

RecordingService

AudioPipeline

SpeechRecognitionService

SpeakerManager

TranscriptService

TimelineService

MeetingIntelligenceEngine

TopicDetector

DecisionDetector

ActionExtractor

KnowledgeUpdater

MeetingSearchIndexer

---

# 26. Architecture Decision Records

## ADR-011 — Meetings Are Knowledge Objects

Status

Accepted

Decision

Meetings are stored as structured knowledge rather than recordings.

Reason

Supports search, AI reasoning, and long-term memory.

---

## ADR-012 — Streaming Intelligence

Status

Accepted

Decision

Every AI capability runs incrementally during recording.

Reason

Users receive immediate value while reducing end-of-meeting processing.

---

## ADR-013 — Speaker Profiles

Status

Accepted

Decision

Speaker identities evolve through continuous learning.

Reason

Improves diarization accuracy without requiring enrollment before first use.

---

## ADR-014 — Background Refinement

Status

Accepted

Decision

Fast models produce immediate output while background refinement improves quality later.

Reason

Balances responsiveness and accuracy.

---

## ADR-015 — Timeline-Centric Navigation

Status

Accepted

Decision

The meeting timeline becomes the primary navigation model instead of a plain transcript.

Reason

Users think in events, decisions, and discussions rather than raw text.

---

# 27. Future Evolution

Phase 1

Transcription

↓

Phase 2

Speaker intelligence

↓

Phase 3

Knowledge extraction

↓

Phase 4

Meeting graph

↓

Phase 5

Autonomous meeting assistant

Future capabilities include:

* Live coaching during meetings
* Real-time fact lookup from workspace knowledge
* Conflict detection between meetings
* Automatic follow-up generation
* Meeting quality analytics
* Cross-meeting trend analysis
* Personalized speaking insights
* AI-generated meeting briefs before recurring meetings

The Meeting Intelligence Platform is designed to evolve from a transcription engine into a continuously learning organizational memory while remaining entirely offline by default.
