# Airo: On-Device AI + RAG + Function Calling Product Strategy

**Status**: Phase 0 Complete ✅ | Phase 1 Starting 🚀

---

## Executive Summary

**Airo** is an AI-powered super app that processes PDFs, images, and audio on-device using Gemma 1B (quantized int4) with RAG and function calling. Zero network required for core workflows. Target platforms: Android (Pixel 9), iOS (iPhone 13 Pro Max), Chrome (desktop).

**Key Differentiator**: All data processing happens locally. No PHI leaves the device unless explicitly opted in.

---

## Success Metrics (Implementable)

| Metric | Target | Rationale |
|--------|--------|-----------|
| **Offline Success Rate** | 90% of workflows | PDF→extraction→action with no network |
| **Latency** | <3s for 1-page PDF | Pixel 9 + Gemma 1B int4 |
| **App Footprint** | <1.2GB | Model + app minimal install |
| **Extraction F1** | ≥0.9 | Bills, diet plans held-out test set |
| **Battery** | <5% per workflow | Single full run on Pixel 9 |

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter UI (Cross-Platform)              │
│  (Login, File Upload, Results, Notifications, Payments)    │
└────────────────────┬────────────────────────────────────────┘
                     │ Platform Channels
        ┌────────────┼────────────┐
        │            │            │
    ┌───▼──┐    ┌───▼──┐    ┌───▼──┐
    │Android│   │ iOS  │   │Chrome │
    │Native │   │Swift │   │WASM   │
    └───┬──┘    └───┬──┘    └───┬──┘
        │           │           │
    ┌───▼───────────▼───────────▼──────────────────┐
    │  AI Edge SDK / LiteRT Runtime                │
    │  ├─ Gemma 1B int4 (Inference)               │
    │  ├─ Embedding Model (RAG)                   │
    │  ├─ Function Calling SDK                    │
    │  └─ OCR / PDF Parser                        │
    └───┬──────────────────────────────────────────┘
        │
    ┌───▼──────────────────────────────────────────┐
    │  Local Storage (Encrypted)                   │
    │  ├─ SQLCipher (Extracted Data)              │
    │  ├─ Vector Index (HNSW / AI Edge RAG)       │
    │  └─ Notification Schedule / Payment Requests│
    └────────────────────────────────────────────┘
```

---

## Core Use Cases & Functions

### 1. **fill_form(patient)** - Healthcare/Diet Forms
- Extract: name, DOB, weight, height, diet plan (day→meals→times→notes)
- Output: Structured form data ready for submission
- Validation: Required fields enforced

### 2. **schedule_notifications(plan_id)** - Recurring Reminders
- Input: plan_id, start_date, recurrence (daily/weekly/custom), times
- Action: Create local notification schedule (Android WorkManager / iOS UserNotifications)
- Persistence: Store in local DB

### 3. **split_bill(bill_id)** - Expense Sharing
- Input: bill_id, participants (user_id, share_pct), items (name, price, assigned_to)
- Output: Per-person shares, payment requests
- Action: Store in local DB, optionally sync when online

---

## Implementation Roadmap (10 Phases)

### Phase 0: Foundation ✅ COMPLETE
- Project structure, authentication, cross-platform setup
- App name: "Airo" with AI+Air icon
- Platforms: Android (Pixel 9), Web (Chrome), iOS config ready

### Phase 1: PoC - On-Device AI (2-3 sprints)
- Load Gemma 1B int4 on Android
- Basic inference + fill_form function
- Flutter platform channel bridge

### Phase 2: Document Ingestion (2 sprints)
- File picker, PDF/image/audio preprocessing
- OCR (ML Kit + Tesseract fallback)
- Rule-based field extraction

### Phase 3: RAG & Vector Store (2 sprints)
- Chunking, on-device embeddings, HNSW index
- Retrieval pipeline, end-to-end RAG

### Phase 4: Function Calling (1-2 sprints)
- All three functions: fill_form, schedule_notifications, split_bill
- Native handlers, local actions

### Phase 5: iOS & Web Parity (2-3 sprints)
- iOS: LiteRT/CoreML conversion, Swift native layer
- Web: LiteRT Web/WASM, JavaScript RAG

### Phase 6: Privacy & Security (1 sprint)
- SQLCipher encryption, consent flows, data purge

### Phase 7: Performance (1 sprint)
- Latency, memory, battery optimization

### Phase 8: Testing & Eval (2 sprints)
- 500 bills, 200 diet PDFs, 100 receipts
- F1 ≥0.9 extraction accuracy

### Phase 9: Beta (2 sprints)
- Firebase App Distribution, user feedback, iteration

### Phase 10: Production (Ongoing)
- Play Store, App Store, web release
- Monitoring, model updates, A/B testing

---

## Technology Stack

| Component | Technology | Notes |
|-----------|-----------|-------|
| **Model** | Gemma 3 1B int4 | LiteRT quantized, <500MB |
| **Inference** | AI Edge SDK / LiteRT | Android native, iOS CoreML, Web WASM |
| **RAG** | AI Edge RAG SDK | On-device retrieval + chunking |
| **Function Calling** | AI Edge Function Calling | JSON schema-based |
| **OCR** | ML Kit + Tesseract | Local, no cloud |
| **Storage** | SQLCipher + HNSW | Encrypted vectors + metadata |
| **Notifications** | WorkManager (Android) / UserNotifications (iOS) | Local scheduling |
| **UI** | Flutter | Single codebase, platform channels |

---

## Risk Mitigations

| Risk | Mitigation |
|------|-----------|
| OOM on older devices | Smaller model, streaming tokens, cloud fallback |
| Function hallucination | Strict JSON schema, deterministic validators, human confirmation for payments |
| Multimodal sync issues | Prefer deterministic OCR for numeric/date data |
| Model accuracy drift | A/B testing, continuous evaluation, model updates |

---

## Next Steps (Week 1)

1. **Download & quantize Gemma 1B** → int4 LiteRT model
2. **Set up Android native module** → Load model, basic inference
3. **Create Flutter plugin** → Platform channel bridge
4. **Register fill_form function** → Test with sample form
5. **Build Flutter UI** → Text input, model response display

---

## References

- [Google AI Edge Announcement](https://developers.google.com/ai-edge)
- [AI Edge Function Calling Guide](https://developers.google.com/ai-edge/function-calling)
- [AI Edge RAG Guide](https://developers.google.com/ai-edge/rag)
- [google-ai-edge GitHub](https://github.com/google-ai-edge)
- [LiteRT Hugging Face](https://huggingface.co/collections/google/litert-models)

---

**Product Manager**: Airo Team  
**CTO**: Architecture & Technology Lead  
**Last Updated**: 2025-10-30

