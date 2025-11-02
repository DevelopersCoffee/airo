# Airo: Executive Summary for Engineering Team

## What is Airo?

**Airo** is an AI-powered super app that extracts structured data from PDFs, images, and audio using on-device AI (Gemma 1B). It then uses function calling to automate three key workflows:

1. **fill_form()** - Extract healthcare/diet data and populate forms
2. **schedule_notifications()** - Create recurring reminders for diet plans
3. **split_bill()** - Extract bill data and compute expense splits

**Key Promise**: Everything happens on your device. No data leaves unless you explicitly opt in.

---

## Why This Matters

- **Privacy**: PHI (Protected Health Information) stays local
- **Speed**: No network latency; works offline
- **Reliability**: No cloud dependency
- **Cost**: No API calls; one-time model download

---

## Current Status

✅ **Phase 0 Complete**:
- Project structure ready (Flutter + Android + iOS + Web)
- Authentication system working (admin:admin login)
- App name: "Airo" with modern AI+Air icon
- Cross-platform setup: Pixel 9 (Android), Chrome (Web), iOS config ready

🚀 **Phase 1 Starting**: On-Device AI Integration

---

## What We're Building (10 Phases)

| Phase | Duration | Focus | Status |
|-------|----------|-------|--------|
| 0 | ✅ Done | Foundation & Setup | COMPLETE |
| 1 | 2-3 sprints | PoC: Load Gemma 1B, basic inference | STARTING |
| 2 | 2 sprints | Document ingestion & OCR | QUEUED |
| 3 | 2 sprints | RAG & vector search | QUEUED |
| 4 | 1-2 sprints | Function calling & actions | QUEUED |
| 5 | 2-3 sprints | iOS & Web parity | QUEUED |
| 6 | 1 sprint | Privacy & encryption | QUEUED |
| 7 | 1 sprint | Performance optimization | QUEUED |
| 8 | 2 sprints | Testing & evaluation | QUEUED |
| 9 | 2 sprints | Beta & user feedback | QUEUED |
| 10 | Ongoing | Production & monitoring | QUEUED |

**Total**: ~18-20 sprints (~4-5 months) to production

---

## Success Metrics

We measure success by:

1. **Offline Success Rate**: 90% of workflows complete with zero network
2. **Latency**: PDF → structured data in <3 seconds (Pixel 9)
3. **Accuracy**: Field extraction F1 score ≥ 0.9 (bills, diet plans)
4. **Battery**: Single workflow uses <5% battery
5. **Footprint**: App + model < 1.2GB

---

## Technology Stack

| Layer | Technology | Why |
|-------|-----------|-----|
| **Model** | Gemma 3 1B (int4) | Small, fast, accurate |
| **Inference** | AI Edge SDK / LiteRT | On-device, cross-platform |
| **RAG** | AI Edge RAG SDK | Semantic search, local |
| **Function Calling** | AI Edge Function Calling | Structured outputs |
| **OCR** | ML Kit + Tesseract | Local, no cloud |
| **Storage** | SQLCipher + HNSW | Encrypted, searchable |
| **UI** | Flutter | Single codebase |

---

## Phase 1 Deliverables (Next 2-3 Weeks)

### Week 1: Model & Android Setup
- [ ] Download & quantize Gemma 1B to int4 (<500MB)
- [ ] Integrate AI Edge SDK on Android
- [ ] Load model, run basic inference
- [ ] Measure latency & memory

### Week 2: Platform Bridge & Function Calling
- [ ] Create Flutter plugin (ai_edge_bridge)
- [ ] Implement platform channels (Android)
- [ ] Register fill_form function schema
- [ ] Test end-to-end: prompt → model → function call

### Week 3: Flutter UI
- [ ] Build chat screen (text input, send button)
- [ ] Display model responses
- [ ] Show function execution results
- [ ] Test on Pixel 9 device

**Success Criteria**: Model loads, inference works, fill_form function callable from Flutter

---

## Key Decisions Made

1. **Gemma 1B int4**: Balances speed, accuracy, and footprint
2. **AI Edge SDK**: Google's official on-device AI stack
3. **SQLCipher**: Encrypted local storage for PHI
4. **Function Calling**: Structured outputs for reliable automation
5. **Flutter**: Single codebase for Android, iOS, Web

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Model too slow | Use GPU delegate, streaming tokens, smaller model fallback |
| OOM on older devices | Lazy loading, cloud fallback, memory profiling |
| Function hallucination | Strict JSON schema, deterministic validators, human confirmation |
| Accuracy not meeting 0.9 F1 | Hybrid approach: rule-based + LLM, continuous evaluation |
| Privacy concerns | Encryption, consent flows, data purge, no telemetry by default |

---

## Next Steps for Engineering

1. **Read**: PRODUCT_STRATEGY.md, TECHNICAL_ARCHITECTURE.md
2. **Review**: ENGINEERING_CHECKLIST.md for Phase 1 tasks
3. **Setup**: Clone repo, review task list in this conversation
4. **Start**: Phase 1.1 (Model quantization)

---

## Questions?

- **Product**: What are the use cases? → See PRODUCT_STRATEGY.md
- **Architecture**: How do components connect? → See TECHNICAL_ARCHITECTURE.md
- **Implementation**: What's the checklist? → See ENGINEERING_CHECKLIST.md
- **Timeline**: When is each phase done? → See task list in conversation

---

**Product Manager**: Airo Team  
**CTO**: Architecture & Technology Lead  
**Date**: 2025-10-30

---

## Quick Links

- **Task List**: View in conversation (10 phases, 60+ tasks)
- **Product Strategy**: PRODUCT_STRATEGY.md
- **Engineering Checklist**: ENGINEERING_CHECKLIST.md
- **Technical Architecture**: TECHNICAL_ARCHITECTURE.md
- **Repository**: Current workspace

