# Airo: Implementation Timeline & Milestones

**Total Duration**: ~18-20 sprints (~4-5 months) to production  
**Sprint Duration**: 2 weeks  
**Start Date**: Week of 2025-11-03  
**Target Production**: ~2025-03-15

---

## 📅 Detailed Timeline

### **Phase 1: PoC - On-Device AI (Weeks 1-3)**

**Sprint 1.1: Model Setup & Android Native**
- Week 1: Download Gemma 1B, quantize to int4, test on emulator
- Week 2: Integrate AI Edge SDK, create GemmaInferenceEngine, test inference
- **Deliverable**: Model loads, basic inference works on Pixel 9

**Sprint 1.2: Platform Bridge & Function Calling**
- Week 3: Create Flutter plugin, implement platform channels, register fill_form
- **Deliverable**: fill_form function callable from Flutter

**Sprint 1.3: Flutter UI**
- Week 3: Build chat screen, display responses, test end-to-end
- **Deliverable**: Working chat UI on Pixel 9

**Milestone 1**: ✅ PoC complete - Model inference + function calling working

---

### **Phase 2: Document Ingestion (Weeks 4-5)**

**Sprint 2.1: File Selection & PDF Extraction**
- Week 4: File picker, PDF text extraction, preprocessing
- **Deliverable**: PDF text extraction working

**Sprint 2.2: OCR & Rule-Based Extraction**
- Week 5: ML Kit OCR, Tesseract fallback, rule-based parsers
- **Deliverable**: Extraction pipeline with >0.85 precision

**Milestone 2**: ✅ Document ingestion complete - PDF/image/audio processing working

---

### **Phase 3: RAG & Vector Store (Weeks 6-7)**

**Sprint 3.1: Chunking & Embeddings**
- Week 6: Document chunker, embedding model, vector index setup
- **Deliverable**: Chunking + embedding pipeline working

**Sprint 3.2: Retrieval & End-to-End RAG**
- Week 7: Retrieval pipeline, RAG integration, prompt templates
- **Deliverable**: End-to-end RAG working on Pixel 9

**Milestone 3**: ✅ RAG complete - Semantic search + context retrieval working

---

### **Phase 4: Function Calling & Actions (Weeks 8-9)**

**Sprint 4.1: Function Handlers**
- Week 8: Implement all three function handlers (fill_form, schedule_notifications, split_bill)
- **Deliverable**: All functions executing locally

**Sprint 4.2: Flutter UI for Results**
- Week 9: Display function results, notifications preview, bill splits
- **Deliverable**: Results UI working

**Milestone 4**: ✅ Function calling complete - All three functions working end-to-end

---

### **Phase 5: iOS & Web Parity (Weeks 10-12)**

**Sprint 5.1: iOS Model Conversion & Native Layer**
- Week 10: Convert model to CoreML, implement iOS native layer
- **Deliverable**: iOS model loading + inference working

**Sprint 5.2: iOS Platform Channels & Functions**
- Week 11: Implement iOS method channels, function handlers
- **Deliverable**: iOS feature parity with Android

**Sprint 5.3: Web (Chrome) LiteRT/WASM**
- Week 12: LiteRT Web runtime, JavaScript RAG, function calling
- **Deliverable**: Web feature parity with native platforms

**Milestone 5**: ✅ Cross-platform complete - Android, iOS, Web all working

---

### **Phase 6: Privacy & Security (Week 13)**

**Sprint 6.1: Encryption & Consent**
- Week 13: SQLCipher integration, consent flows, data purge, export
- **Deliverable**: Encrypted storage + privacy controls working

**Milestone 6**: ✅ Privacy complete - All data encrypted, consent flows implemented

---

### **Phase 7: Performance Optimization (Week 14)**

**Sprint 7.1: Latency, Memory, Battery**
- Week 14: Profile and optimize latency (<3s), memory (OOM handling), battery (<5%)
- **Deliverable**: All performance targets met

**Milestone 7**: ✅ Performance complete - All metrics within targets

---

### **Phase 8: Testing & Evaluation (Weeks 15-16)**

**Sprint 8.1: Test Dataset & Metrics**
- Week 15: Create 500 bills, 200 diet PDFs, 100 receipts; implement evaluation
- **Deliverable**: Test dataset + evaluation framework ready

**Sprint 8.2: Accuracy & Function Testing**
- Week 16: Run extraction accuracy tests (target F1 ≥0.9), function call tests
- **Deliverable**: Accuracy metrics validated, 90% offline success rate confirmed

**Milestone 8**: ✅ Testing complete - All success metrics validated

---

### **Phase 9: Beta & Field Testing (Weeks 17-18)**

**Sprint 9.1: Beta Build & Distribution**
- Week 17: Build release APK/IPA/Web, set up Firebase App Distribution
- **Deliverable**: Beta builds available to testers

**Sprint 9.2: User Feedback & Iteration**
- Week 18: Collect feedback, fix critical bugs, iterate on UX
- **Deliverable**: Production-ready build

**Milestone 9**: ✅ Beta complete - User feedback incorporated, production ready

---

### **Phase 10: Production Launch (Week 19+)**

**Sprint 10.1: Production Deployment**
- Week 19: Release to Play Store, App Store, web
- **Deliverable**: Live on all platforms

**Sprint 10.2: Monitoring & Support**
- Week 19+: Monitor metrics, fix issues, plan model updates
- **Deliverable**: Production monitoring + support infrastructure

**Milestone 10**: ✅ Production complete - Live and monitored

---

## 📊 Timeline Summary

| Phase | Duration | Start | End | Status |
|-------|----------|-------|-----|--------|
| 0 | ✅ Done | - | 2025-10-30 | COMPLETE |
| 1 | 3w | 2025-11-03 | 2025-11-21 | STARTING |
| 2 | 2w | 2025-11-24 | 2025-12-05 | QUEUED |
| 3 | 2w | 2025-12-08 | 2025-12-19 | QUEUED |
| 4 | 2w | 2025-12-22 | 2026-01-02 | QUEUED |
| 5 | 3w | 2026-01-05 | 2026-01-23 | QUEUED |
| 6 | 1w | 2026-01-26 | 2026-02-02 | QUEUED |
| 7 | 1w | 2026-02-05 | 2026-02-12 | QUEUED |
| 8 | 2w | 2026-02-15 | 2026-02-26 | QUEUED |
| 9 | 2w | 2026-03-01 | 2026-03-12 | QUEUED |
| 10 | ∞ | 2026-03-15 | - | QUEUED |

**Total**: ~19 weeks (~4.5 months) to production

---

## 🎯 Key Milestones

| Milestone | Date | Deliverable |
|-----------|------|-------------|
| **M1** | 2025-11-21 | PoC: Model inference + function calling |
| **M2** | 2025-12-05 | Document ingestion pipeline |
| **M3** | 2025-12-19 | RAG + semantic search |
| **M4** | 2026-01-02 | All functions working end-to-end |
| **M5** | 2026-01-23 | iOS + Web feature parity |
| **M6** | 2026-02-02 | Privacy & encryption |
| **M7** | 2026-02-12 | Performance targets met |
| **M8** | 2026-02-26 | Testing complete, metrics validated |
| **M9** | 2026-03-12 | Beta feedback incorporated |
| **M10** | 2026-03-15 | 🚀 Production launch |

---

## 📈 Success Criteria by Phase

### Phase 1 ✅
- [ ] Model loads in <2s
- [ ] Inference latency <1s for short prompts
- [ ] fill_form function callable
- [ ] No crashes on Pixel 9

### Phase 2 ✅
- [ ] PDF text extraction working
- [ ] OCR accuracy >0.8
- [ ] Rule-based extraction >0.85 precision
- [ ] Supports PDF, JPG, PNG, HEIC, M4A, WAV

### Phase 3 ✅
- [ ] Chunking working correctly
- [ ] Embedding inference <500ms
- [ ] Vector retrieval <100ms
- [ ] RAG context quality validated

### Phase 4 ✅
- [ ] All three functions executing
- [ ] Function args validated
- [ ] Local actions working (notifications, payments)
- [ ] Results displayed in Flutter UI

### Phase 5 ✅
- [ ] iOS model conversion successful
- [ ] iOS inference working
- [ ] Web WASM runtime working
- [ ] Feature parity across platforms

### Phase 6 ✅
- [ ] SQLCipher encryption working
- [ ] Consent flows implemented
- [ ] Data purge working
- [ ] No unencrypted PHI on device

### Phase 7 ✅
- [ ] Latency <3s per PDF
- [ ] Memory peak <500MB
- [ ] Battery <5% per workflow
- [ ] Footprint <1.2GB

### Phase 8 ✅
- [ ] Test dataset created (500+200+100)
- [ ] Extraction F1 ≥0.9
- [ ] Function call accuracy ≥0.95
- [ ] 90% offline success rate

### Phase 9 ✅
- [ ] Beta builds distributed
- [ ] User feedback collected
- [ ] Critical bugs fixed
- [ ] Production ready

### Phase 10 ✅
- [ ] Live on Play Store
- [ ] Live on App Store
- [ ] Live on web
- [ ] Monitoring active

---

## 🚨 Risk Timeline

| Risk | When | Mitigation |
|------|------|-----------|
| Model too slow | Phase 1 | Use GPU delegate, streaming tokens |
| OOM on devices | Phase 7 | Smaller model, lazy loading |
| Accuracy not 0.9 F1 | Phase 8 | Hybrid rule+LLM, continuous eval |
| iOS conversion issues | Phase 5 | Early testing, fallback to cloud |
| Web WASM performance | Phase 5 | Streaming, worker threads |

---

## 📞 Weekly Sync Points

**Every Monday 10 AM**:
- Review previous week's progress
- Identify blockers
- Adjust timeline if needed
- Plan next week's tasks

**Every Friday 4 PM**:
- Demo completed features
- Collect feedback
- Plan next sprint

---

## 🎓 Team Capacity Planning

**Recommended Team Size**: 6-8 engineers

| Role | Count | Allocation |
|------|-------|-----------|
| Android Lead | 1 | 100% |
| iOS Lead | 1 | 100% |
| Web Lead | 1 | 100% |
| Flutter Lead | 1 | 100% |
| ML Engineer | 1 | 50% (model selection, quantization, eval) |
| QA/Testing | 1 | 100% |
| DevOps/Infra | 1 | 50% (CI/CD, monitoring) |

---

**Last Updated**: 2025-10-30  
**Status**: Ready for execution 🚀

