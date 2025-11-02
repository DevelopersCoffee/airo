# Meeting Minutes Feature - WIP

## Status: Work In Progress

This document outlines the Meeting Minutes feature architecture. Implementation is deferred to a future iteration.

## Overview

On-device meeting recording, transcription, diarization, and minutes generation. No server required.

## Scope

- Voice capture with VAD (Voice Activity Detection)
- Speech-to-Text (Whisper.cpp)
- Speaker diarization
- Meeting Minutes synthesis
- Retrieval from past meetings
- Export (Markdown, PDF, TXT)

## Data Model

```dart
class Meeting {
  final String id;
  final String rawAudioPath;
  final String transcriptPath;
  final List<Word> words;
  final List<Speaker> speakers;
  final DateTime startTime;
  final DateTime endTime;
  final Duration duration;
}

class Word {
  final String text;
  final double startTime;
  final double endTime;
  final int speakerId;
}

class Speaker {
  final int id;
  final String? name;
  final List<double> embedding;
}

class MeetingMinutes {
  final String id;
  final String meetingId;
  final String title;
  final DateTime date;
  final List<String> attendees;
  final List<String> agenda;
  final List<Decision> decisions;
  final List<ActionItem> actionItems;
  final List<String> risks;
  final List<String> blockers;
  final List<String> nextSteps;
  final String summary;
  final List<Quote> sources;
}

class Decision {
  final String text;
  final int speakerId;
  final double timestamp;
}

class ActionItem {
  final String task;
  final int? ownerId;
  final DateTime? dueDate;
  final double timestamp;
}

class Quote {
  final String text;
  final double timestamp;
}
```

## Pipeline (On-Device)

### 1. Audio Capture
- 16 kHz mono PCM
- Rolling file chunks (30s)
- Web: MediaRecorder + AudioWorklet
- VAD gate: WebRTC VAD to drop silence

### 2. Speech-to-Text (Local)
- **Default**: Whisper.cpp int8 models
- **Android**: ggml whisper-tiny/base int8 via JNI
- **iOS**: Core ML Whisper small-en or base
- **Web**: whisper.cpp WASM+SIMD; WebGPU when available
- **Target**: <800ms segment delay; WER ≤ 12% for Hindi-English code-mix

### 3. Speaker Diarization (Local)
- VAD + speaker change detection
- Lightweight speaker embeddings: ECAPA-TDNN tiny (ONNX int8)
- Online clustering (AHC) per 10s window
- Output: word-level timestamps + speaker_id

### 4. Redaction (Optional, Local)
- PII tagger (regex + small NER ONNX int8)
- Mask emails, phone, IDs when exporting

### 5. Summarization (Local)

#### Tier A (Fast)
- Rule templates + classifiers
- Extract agenda from repeated nouns/headers
- Decisions: sentences with "decide/agree/approve/ship/ETA"
- Action items: imperative sentences with assignee and date

#### Tier B (Rich)
- Small LLM local (3B quant Q4_K_M)
- Android/iOS: Llama-family or Phi-3-mini
- Web: 1.1–3B Q4 via WebGPU; fallback to Tier A on low VRAM
- Deterministic prompts; temperature 0; token cap 512

### 6. Retrieval from Past MoMs (Local)
- Embed MoM sections with MiniLM-L6 or instructor-xl-int8
- Store in SQLite with FTS5 + vector (sqlite-vss) on mobile
- IndexedDB + hnswlib-wasm on Web
- Query: top-k similar agenda/team/keywords
- Inject "standard decisions" and phrasing

### 7. Export
- Markdown canonical
- Render PDF on device
- Include trace: timestamps linking to transcript segments

## Performance Budgets

- **RAM**: ≤400 MB peak with base Whisper; ≤1 GB with 3B LLM
- **CPU/GPU**: average <45% big cores
- **Thermal guard**: auto drop to Tier A if hot
- **Battery**: 60-minute meeting <12% on flagship; <20% on mid-range

## Privacy & Security

- All processing local by default
- AES-256 file encryption at rest
- OS secure storage for keys
- Opt-in cloud sync later (not in v1)
- Microphone permission; background recording forbidden

## Accessibility

- Live captions adjustable font
- Color-blind safe speaker colors
- Keyboard support on Web

## Agent Integration

### Intents
- "listen and make minutes" → start capture
- "generate minutes" → synthesize MoM
- "fetch past decisions" → retrieval

### Tools
- `meeting.start` - Start recording
- `meeting.stop` - Stop recording
- `meeting.generate_mom` - Generate minutes
- `meeting.fetch_past(template_of: agenda|team|project)` - Retrieve similar meetings
- `meeting.export(format: md|pdf|txt)` - Export minutes

### Agent Response
- MoM draft with deep-link to edit screen
- Suggestions for action items and owners

## QA Matrix (WIP)

- [ ] Code-mix speech (Hindi-English)
- [ ] Accents and crosstalk
- [ ] Multi-speaker overlap
- [ ] Airplane mode (offline)
- [ ] Web throttling tabs
- [ ] Heat throttling → Tier A fallback
- [ ] Far-field mic vs headset
- [ ] Long meetings (>60 min)

## Release Plan

### v1
- STT base model
- VAD
- Simple diarization
- Rule-based MoM
- Markdown export

### v1.1
- Retrieval from past MoMs
- PDF export

### v1.2
- Local 3B LLM MoM enhancement
- Redaction
- Template library

### v1.3
- Speaker name labeling (user tags speakers)
- Recurring meeting templates

## Assets to Prepare

- On-device models:
  - whisper-base-int8
  - ecapa-tiny-int8
  - MiniLM-int8
- Prompt templates for MoM sections
- Test audio corpora (Hindi, English, Hinglish, 2–6 speakers)

## Dev Tasks (WIP)

- [ ] Audio engine with VAD and timestamped chunks
- [ ] STT wrapper per platform (Android/iOS/Web)
- [ ] Diarization module with online clustering
- [ ] Rule extractors (decisions, actions, dates, owners)
- [ ] LLM runner (optional) with quantized 3B
- [ ] Embedding + vector store local
- [ ] MoM schema + renderer
- [ ] Agent tool plumbing + UI screens
- [ ] Exporters (MD, PDF)
- [ ] Thermal and battery guards
- [ ] QA testing

## Non-Goals v1

- Cloud STT/LLM
- Real-time translation
- Meeting invite parsing from calendars
- Automatic speaker name detection
- Integration with calendar apps

## Notes

- Whisper.cpp provides excellent accuracy for code-mixed speech
- ECAPA-TDNN is lightweight and suitable for on-device diarization
- Tier A (rule-based) is sufficient for most meetings; Tier B for complex synthesis
- Vector store enables semantic search across past meetings
- Thermal management critical on mid-range devices

