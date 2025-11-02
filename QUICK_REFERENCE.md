# Airo Quick Reference Guide

## 🎯 Project Overview

**Airo** = On-device AI + RAG + Function Calling for PDF/image/audio processing

**Platforms**: Android (Pixel 9), iOS (iPhone 13 Pro Max), Chrome (Web)

**Core Functions**:
1. `fill_form()` - Extract & populate healthcare/diet forms
2. `schedule_notifications()` - Create recurring reminders
3. `split_bill()` - Extract bills & compute expense splits

---

## 📊 Success Metrics

| Metric | Target |
|--------|--------|
| Offline Success | 90% |
| Latency | <3s per PDF |
| Accuracy (F1) | ≥0.9 |
| Battery | <5% per workflow |
| Footprint | <1.2GB |

---

## 🏗️ Architecture at a Glance

```
Flutter UI
    ↓ (Platform Channels)
Android/iOS/Web Native Layer
    ↓
AI Edge SDK (Gemma 1B int4)
    ↓
Local Storage (SQLCipher + HNSW)
```

---

## 📋 Phase Breakdown

| Phase | Duration | What | Status |
|-------|----------|------|--------|
| 0 | ✅ | Foundation | DONE |
| 1 | 2-3w | PoC AI | STARTING |
| 2 | 2w | Ingestion | QUEUED |
| 3 | 2w | RAG | QUEUED |
| 4 | 1-2w | Functions | QUEUED |
| 5 | 2-3w | iOS/Web | QUEUED |
| 6 | 1w | Privacy | QUEUED |
| 7 | 1w | Performance | QUEUED |
| 8 | 2w | Testing | QUEUED |
| 9 | 2w | Beta | QUEUED |
| 10 | ∞ | Production | QUEUED |

---

## 🚀 Phase 1 Checklist (Next 2-3 Weeks)

### Week 1: Model Setup
- [ ] Download Gemma 3 1B from Hugging Face
- [ ] Quantize to int4 using LiteRT
- [ ] Verify <500MB size
- [ ] Test on Pixel 9 emulator

### Week 2: Android Native
- [ ] Add AI Edge SDK to build.gradle
- [ ] Create `GemmaInferenceEngine.kt`
- [ ] Create `FunctionCallingManager.kt`
- [ ] Test basic inference

### Week 3: Flutter Bridge
- [ ] Create `ai_edge_bridge` plugin
- [ ] Implement platform channels
- [ ] Build chat UI
- [ ] Test end-to-end on Pixel 9

---

## 🛠️ Tech Stack

| Component | Tech | Size |
|-----------|------|------|
| Model | Gemma 1B int4 | <500MB |
| Inference | LiteRT | - |
| RAG | AI Edge RAG | - |
| Functions | AI Edge FC | - |
| OCR | ML Kit | - |
| Storage | SQLCipher | - |
| UI | Flutter | - |

---

## 📁 Project Structure

```
airo_super_app/
├── app/                          # Main Flutter app
│   ├── lib/src/
│   │   ├── features/
│   │   │   ├── auth/            # Authentication
│   │   │   ├── ai/              # AI chat interface
│   │   │   ├── documents/       # File upload
│   │   │   ├── results/         # Display results
│   │   │   ├── notifications/   # Schedule reminders
│   │   │   └── payments/        # Bill splitting
│   │   └── core/                # Shared utilities
│   ├── android/
│   │   └── app/src/main/kotlin/com/airo/superapp/
│   │       └── ai/              # Native AI layer
│   ├── ios/
│   │   └── Runner/              # iOS native layer
│   └── web/                      # Web assets
├── packages/
│   ├── airo/                     # Airo package
│   ├── airomoney/               # AiroMoney package
│   └── ai_edge_bridge/          # Platform channel plugin
└── docs/
    ├── PRODUCT_STRATEGY.md
    ├── TECHNICAL_ARCHITECTURE.md
    ├── ENGINEERING_CHECKLIST.md
    └── EXECUTIVE_SUMMARY.md
```

---

## 🔑 Key Files to Know

| File | Purpose |
|------|---------|
| `app/pubspec.yaml` | Flutter dependencies |
| `app/android/app/build.gradle.kts` | Android config + AI Edge SDK |
| `app/lib/main.dart` | App entry point |
| `app/lib/src/features/ai/screens/chat_screen.dart` | Chat UI |
| `packages/ai_edge_bridge/` | Platform channel plugin |
| `app/android/app/src/main/kotlin/com/airo/superapp/ai/` | Android native AI |

---

## 🔄 Data Flow: Bill Processing

```
1. User uploads PDF
   ↓
2. PDF text extraction (text layer or OCR)
   ↓
3. Rule-based field extraction (amounts, dates, items)
   ↓
4. Chunking + embedding (RAG context)
   ↓
5. LLM inference with context
   ↓
6. Function calling: split_bill()
   ↓
7. Compute shares, create payment requests
   ↓
8. Store in encrypted DB
   ↓
9. Display results in Flutter UI
```

---

## 📱 Platform Channels

**Android Method Channel**: `com.airo.ai_edge_bridge`

**Methods**:
- `init(modelConfigJson)` → Initialize model
- `query(prompt, optsJson)` → Get model response
- `executeFunction(functionName, argsJson)` → Execute function
- `indexDocument(filePath, metaJson)` → Index for RAG

---

## 🎯 Function Schemas

### fill_form
```json
{
  "name": "fill_form",
  "parameters": {
    "name": "string",
    "dob": "date",
    "weight_kg": "number",
    "height_cm": "number",
    "diet_plan": [{"day": "int", "meals": ["string"], "times": ["string"]}]
  }
}
```

### schedule_notifications
```json
{
  "name": "schedule_notifications",
  "parameters": {
    "plan_id": "string",
    "start_date": "date",
    "recurrence": "daily|weekly|custom",
    "times": ["HH:MM"]
  }
}
```

### split_bill
```json
{
  "name": "split_bill",
  "parameters": {
    "bill_id": "string",
    "participants": [{"user_id": "string", "share_pct": "number"}],
    "items": [{"name": "string", "price": "number", "assigned_to": ["string"]}]
  }
}
```

---

## 🔐 Privacy & Security

- **Encryption**: SQLCipher for local DB
- **Consent**: Explicit opt-in for cloud fallback
- **Data Purge**: User-initiated deletion
- **No Telemetry**: By default (opt-in only)
- **Keystore**: Device keystore for encryption keys

---

## 📊 Testing Strategy

**Dataset**:
- 500 real-world bills
- 200 diet plan PDFs
- 100 scanned receipts

**Metrics**:
- Extraction F1 ≥ 0.9
- Function call accuracy ≥ 0.95
- Latency <3s per PDF
- 90% offline success rate

---

## 🚨 Common Issues & Fixes

| Issue | Fix |
|-------|-----|
| Model too slow | Use GPU delegate, streaming tokens |
| OOM on device | Smaller model, lazy loading |
| Function hallucination | Strict schema, human confirmation |
| OCR accuracy low | Combine with rule-based extraction |
| Network required | All ops work offline |

---

## 📚 Documentation

- **EXECUTIVE_SUMMARY.md** - High-level overview
- **PRODUCT_STRATEGY.md** - Product vision & roadmap
- **TECHNICAL_ARCHITECTURE.md** - System design & components
- **ENGINEERING_CHECKLIST.md** - Phase-by-phase tasks
- **QUICK_REFERENCE.md** - This file

---

## 🔗 External Resources

- [Google AI Edge](https://developers.google.com/ai-edge)
- [AI Edge Function Calling](https://developers.google.com/ai-edge/function-calling)
- [AI Edge RAG](https://developers.google.com/ai-edge/rag)
- [LiteRT Models](https://huggingface.co/collections/google/litert-models)
- [google-ai-edge GitHub](https://github.com/google-ai-edge)

---

## 👥 Team Roles

| Role | Responsibility |
|------|-----------------|
| **Product Manager** | Vision, roadmap, success metrics |
| **CTO** | Architecture, tech decisions, performance |
| **Android Lead** | Native AI layer, platform channels |
| **iOS Lead** | Model conversion, Swift implementation |
| **Web Lead** | LiteRT Web, WASM, JavaScript |
| **Flutter Lead** | UI, state management, integration |
| **ML Engineer** | Model selection, quantization, evaluation |

---

**Last Updated**: 2025-10-30  
**Version**: 1.0

