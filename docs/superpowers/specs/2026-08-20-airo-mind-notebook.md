# Airo Mind notebook — multilingual capture, recap, and organisation

## Objective

Make Airo Mind a notebook people can actually run their day on: record or
import speech in many languages, get an accurate transcript plus an AI
summary and key points, combine several notes into one Super Summary, keep
the library searchable with labels and tags, and export / copy / share the
result.

**Target user**: someone who records meetings, lectures, voice memos, or
podcasts on a phone or desktop and wants the notes to stay on-device.

## What already existed

- Live meeting capture (`MeetingCaptureScreen` / `MindService.startRecording`)
  and the whisper.cpp pipeline (`MindService.process`).
- Two transcription modes only: Auto (multilingual) and English-only (#1664).
- Meeting minutes + Meeting IR (decisions, action items, metrics).
- Meeting markdown export and share (#1663).
- Semantic search over *meetings*, not notes.
- Notes capability (`#1338`) as a runtime skeleton: `create` / `edit` /
  `delete` of `id` + `title` + `body`. The Rust twin encodes those three
  strings and nothing else.

## What this spec adds

1. **Multiple languages** — a real transcription-language catalog (Indic +
   major world languages) on top of Auto / English, plus notebook UI copy in
   several locales.
2. **Live voice recording with accurate transcription** — the existing
   whisper pipeline remains the accuracy path; finishing a recording also
   writes a notebook note.
3. **Podcasts and uploaded audio** — file picker and remote URL download
   enqueue the same processing job as a live recording.
4. **AI summary and key points** — derived from minutes, action items, and
   transcript; stored on the note.
5. **Super Summary** — select several notes and fold them into one recap
   note, with an optional generation hook and a deterministic extractive
   fallback when no model is available.
6. **Labels, tags, and search** — first-class on the notebook document;
   library filter is keyword + tag + label + language.
7. **Export, copy, share** — markdown of one note or a Super Summary, via
   clipboard, share sheet, or save-to-folder.

## Architecture

The Notes operation log stays the durability seam (`C5` / `I4`). Product
fields are **opaque payload inside `body`**, so the Rust `note.create` /
`note.edit` encoding does not change:

```
Note.title  → display title
Note.body   → plaintext (legacy / simple notes)
              OR JSON envelope `airo.mind.notebook.v1`
```

```
Audio (live | file | podcast URL)
        │
        ▼
MeetingProcessingQueue  →  MindService.process (whisper + minutes)
        │
        ▼
NotebookIngest  →  NotesCapability.create/edit
        │
        ▼
NotebookDocument (transcript, summary, key points, tags, labels, language)
        │
        ├─ search / tag filter
        ├─ Super Summary (N notes → 1 recap note)
        └─ export / copy / share markdown
```

Simple notes with only a title and body still store plaintext, so the
`#1338` vertical-slice tests and any handwritten notes keep working.

## Non-goals

- Changing the Rust notes wire format or adding `note.tag` operations.
- Shipping a new speech engine. Accuracy still comes from the installed
  whisper weights and the language pin.
- Cloud transcription. Capture stays on-device; a remote podcast URL is
  downloaded then processed locally.
- Replacing meeting search. Meetings keep their own FTS + semantic ranker.

## Ownership

Application work in `feature_mind` (Product Manager). Reviewers already on
`module.yaml`: Chief Architect, Platform Architect, Chief Security Officer,
Chief Cloud Officer, Chief QA Officer.
