# Quest real-file and truthful-inference boundary

Status: **Ready for implementation**  
Date: 2026-07-30  
Owner: Flutter Architect / Airo Mind application layer  
Reviewers: Chief QA Officer, Chief Security Officer, Chief Performance Officer

## Critical Agent Gate

**Problem:** Ask Image and Quest uploads currently pass a synthetic file object
with a fabricated size, and `GeminiQuestService` returns canned responses when
Gemini Nano is unavailable or errors. Users can therefore receive an apparent
analysis that did not inspect their file.

**User / actor:** Airo Mind users uploading images, documents, or audio for
analysis.

**Framework or application layer:** Application-layer Quest workflow. Native
multimodal inference remains a separate runtime capability and is not invented
by this change.

**Owning agent:** Flutter Architect / Airo Mind application owner.

**Reviewing agents:** QA, Security, and Performance reviewers.

**Base branch/worktree:** Confirmed from `origin/main`.

**Open questions:** Gemini Nano's currently exposed contract accepts text/file
context only; true image-byte inference requires a future multimodal backend.

**Decision:** Use `dart:io File` for uploaded paths and return a structured,
actionable unavailable error when no supported inference runtime completes the
request. Never fabricate a file size, extracted content, or model answer.

## Contract and deterministic use cases

1. Upload metadata reflects the selected file's real path and byte length.
2. Missing files fail with an actionable error rather than a fake upload.
3. Text files can be read as context; unsupported extraction is explicit.
4. Nano success is returned unchanged.
5. Nano unavailable/failure never produces a canned answer.

## Automation flow

Run Quest provider/service tests, focused Airo Mind tests, app analyzer/tests,
worker-policy checks, `git diff --check`, APK build, and a Pixel 9 smoke test
covering the Ask Image upload entry point.
