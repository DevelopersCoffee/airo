# Airo Engineering Checklist

## Phase 1: PoC - On-Device AI Integration (2-3 sprints)

### 1.1: Model Setup & Quantization
- [ ] Download Gemma 3 1B model from Hugging Face
- [ ] Install LiteRT conversion tools
- [ ] Quantize model to int4 format
- [ ] Verify model size <500MB
- [ ] Test inference on Pixel 9 emulator
- [ ] Document model loading time and memory usage
- **Deliverable**: `gemma-1b-int4.tflite` ready for deployment

### 1.2: Android Native AI Bridge
- [ ] Add AI Edge SDK to `app/android/app/build.gradle.kts`
- [ ] Create Kotlin module: `android/app/src/main/kotlin/com/airo/superapp/ai/`
- [ ] Implement `GemmaInferenceEngine.kt` with model loading
- [ ] Implement `FunctionCallingManager.kt` for function registration
- [ ] Test basic inference with sample prompt
- [ ] Measure inference latency and memory
- **Deliverable**: Working model inference on Pixel 9

### 1.3: Flutter Platform Channel Bridge
- [ ] Create Flutter plugin: `packages/ai_edge_bridge/`
- [ ] Implement platform channel methods:
  - `init(modelConfigJson)` → loads model
  - `query(prompt, optsJson)` → returns response + function call
  - `executeFunction(functionName, argsJson)` → executes and returns result
- [ ] Add Android method channel implementation
- [ ] Test platform channel communication
- **Deliverable**: Flutter plugin with working platform channels

### 1.4: Basic Function Calling - fill_form()
- [ ] Define fill_form JSON schema (name, dob, weight, height, diet_plan)
- [ ] Register schema with AI Edge Function Calling SDK
- [ ] Implement native handler in `FunctionCallingManager.kt`
- [ ] Parse model output and validate required fields
- [ ] Test with sample healthcare form
- **Deliverable**: fill_form function working end-to-end

### 1.5: Flutter UI for Model Interaction
- [ ] Create `lib/src/features/ai/screens/chat_screen.dart`
- [ ] Add text input field + send button
- [ ] Add progress indicator during inference
- [ ] Display model response in scrollable list
- [ ] Integrate with platform channel bridge
- [ ] Test on Pixel 9 device
- **Deliverable**: Working Flutter UI for AI interaction

---

## Phase 2: Document Ingestion & Extraction (2 sprints)

### 2.1: File Selection & Preprocessing
- [ ] Add `file_picker` plugin to pubspec.yaml
- [ ] Create file picker UI in Flutter
- [ ] Support: PDF, JPG, PNG, HEIC, M4A, WAV
- [ ] Implement image preprocessing (auto-orient, crop)
- [ ] Test on Pixel 9
- **Deliverable**: File picker + preprocessing working

### 2.2: PDF Text Extraction
- [ ] Add PDF parsing library (pdfbox or mupdf)
- [ ] Implement text layer extraction
- [ ] Handle scanned PDFs (fallback to OCR)
- [ ] Store extracted text with page/coordinate metadata
- [ ] Test with sample PDFs
- **Deliverable**: PDF text extraction working

### 2.3: OCR Pipeline
- [ ] Integrate ML Kit Text Recognition
- [ ] Add Tesseract fallback
- [ ] Process images locally
- [ ] Return OCR text + confidence scores
- [ ] Test on scanned documents
- **Deliverable**: OCR pipeline working

### 2.4: Rule-Based Field Extraction
- [ ] Build regex parsers for dates, amounts, line items
- [ ] Implement heuristics for bill structure
- [ ] Implement heuristics for diet plan structure
- [ ] Combine OCR + rule output
- [ ] Test on 50 sample bills and diet plans
- **Deliverable**: Rule-based extraction with >0.85 precision

### 2.5: Audio Transcription
- [ ] Integrate MediaPipe ASR or platform ASR
- [ ] Transcribe voice notes locally
- [ ] Pass transcript to extraction pipeline
- [ ] Test on sample audio files
- **Deliverable**: Audio transcription working

---

## Phase 3: RAG & Local Vector Store (2 sprints)

### 3.1: Chunking & Metadata
- [ ] Implement document chunker (200-800 tokens)
- [ ] Add overlap between chunks
- [ ] Store chunk metadata (source, page, coords)
- [ ] Test chunking on sample documents
- **Deliverable**: Chunking pipeline working

### 3.2: On-Device Embedding Model
- [ ] Select small embedding model (MiniLM or similar)
- [ ] Convert to LiteRT int4
- [ ] Verify model size <100MB
- [ ] Implement embedding inference
- [ ] Test on Pixel 9
- **Deliverable**: Embedding model working

### 3.3: Local Vector Index
- [ ] Implement HNSW index or use AI Edge RAG
- [ ] Store quantized vectors in SQLite
- [ ] Implement add/search operations
- [ ] Test with 1000+ vectors
- **Deliverable**: Vector index working

### 3.4: Retrieval Pipeline
- [ ] Implement top-k dense retrieval
- [ ] Add lightweight lexical ranking
- [ ] Limit candidate size before LLM
- [ ] Test retrieval quality
- **Deliverable**: Retrieval pipeline working

### 3.5: End-to-End RAG
- [ ] Connect retriever → LLM inference
- [ ] Implement prompt templates locally
- [ ] Test full RAG pipeline on Pixel 9
- **Deliverable**: End-to-end RAG working

---

## Phase 4: Function Calling & Actions (1-2 sprints)

### 4.1: Function Schema Registration
- [ ] Register fill_form schema
- [ ] Register schedule_notifications schema
- [ ] Register split_bill schema
- [ ] Validate JSON schema compliance
- **Deliverable**: All schemas registered

### 4.2: schedule_notifications() Handler
- [ ] Implement native handler
- [ ] Parse function args
- [ ] Create notification schedule (WorkManager)
- [ ] Support daily/weekly/custom recurrence
- [ ] Test on Pixel 9
- **Deliverable**: Notifications working

### 4.3: split_bill() Handler
- [ ] Implement native handler
- [ ] Parse participants and items
- [ ] Compute per-person shares
- [ ] Create payment request objects
- [ ] Store in local DB
- **Deliverable**: Bill splitting working

### 4.4: fill_form() Handler (Enhanced)
- [ ] Support nested structures (diet plans)
- [ ] Validate required fields
- [ ] Return success/failure with errors
- **Deliverable**: Enhanced form filling

### 4.5: Flutter UI for Results
- [ ] Display function results
- [ ] Show notifications preview
- [ ] Show bill splits
- [ ] Add manual override capability
- **Deliverable**: Results UI working

---

## Phase 5-10: iOS, Web, Privacy, Performance, Testing, Beta, Production

See PRODUCT_STRATEGY.md for detailed breakdown.

---

## Success Criteria Checklist

- [ ] Phase 1 complete: Model loads, basic inference works, fill_form function callable
- [ ] Phase 2 complete: PDF/image/audio ingestion working, rule-based extraction >0.85 precision
- [ ] Phase 3 complete: RAG pipeline end-to-end, retrieval quality validated
- [ ] Phase 4 complete: All three functions working, local actions executing
- [ ] Phase 5 complete: iOS and Web feature parity with Android
- [ ] Phase 6 complete: Encryption, consent flows, data purge implemented
- [ ] Phase 7 complete: Latency <3s, battery <5%, footprint <1.2GB
- [ ] Phase 8 complete: F1 ≥0.9 on test set, 90% offline success rate
- [ ] Phase 9 complete: Beta feedback incorporated, production ready
- [ ] Phase 10 complete: Live on Play Store, App Store, web

---

**Last Updated**: 2025-10-30

