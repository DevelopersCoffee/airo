# Airo Technical Architecture

## System Overview

```
User Device (Offline-First)
├── Flutter UI Layer
│   ├── Authentication (GoRouter)
│   ├── File Upload Screen
│   ├── Chat/Query Screen
│   ├── Results Display
│   └── Notifications/Payments UI
│
├── Platform Channel Layer
│   ├── Android Method Channel
│   ├── iOS Method Channel
│   └── Web JavaScript Bridge
│
├── Native AI Layer (Per Platform)
│   ├── Model Loading & Inference
│   ├── RAG Pipeline
│   ├── Function Calling
│   └── OCR/PDF Processing
│
└── Local Storage Layer
    ├── SQLCipher (Encrypted DB)
    ├── Vector Index (HNSW)
    ├── Notification Schedule
    └── Payment Requests
```

---

## Component Details

### 1. Flutter UI Layer

**Location**: `app/lib/src/features/`

**Key Screens**:
- `auth/screens/login_screen.dart` - Authentication
- `ai/screens/chat_screen.dart` - Query interface
- `documents/screens/upload_screen.dart` - File upload
- `results/screens/results_screen.dart` - Display extraction results
- `notifications/screens/schedule_screen.dart` - Notification scheduling
- `payments/screens/split_bill_screen.dart` - Bill splitting

**State Management**: GoRouter for navigation, SharedPreferences for auth state

---

### 2. Platform Channel Bridge

**Plugin**: `packages/ai_edge_bridge/`

**Android Implementation** (`android/src/main/kotlin/com/airo/ai_edge_bridge/`):
```kotlin
class AiEdgeBridgePlugin : FlutterPlugin {
  private lateinit var channel: MethodChannel
  private lateinit var gemmaEngine: GemmaInferenceEngine
  private lateinit var functionCaller: FunctionCallingManager
  
  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "init" -> initModel(call.arguments, result)
      "query" -> query(call.arguments, result)
      "executeFunction" -> executeFunction(call.arguments, result)
      "indexDocument" -> indexDocument(call.arguments, result)
    }
  }
}
```

**iOS Implementation** (`ios/Runner/AiEdgeBridge.swift`):
- Mirror Android interface in Swift
- Use LiteRT/CoreML for inference
- Same method signatures

**Web Implementation** (`web/ai_edge_bridge.js`):
- LiteRT Web / WASM runtime
- WebWorkers for indexing
- IndexedDB for vector storage

---

### 3. Native AI Layer

#### Android (`app/android/app/src/main/kotlin/com/airo/superapp/ai/`)

**GemmaInferenceEngine.kt**:
- Load Gemma 1B int4 model
- Manage model lifecycle
- Implement streaming token generation
- Handle GPU delegate

**FunctionCallingManager.kt**:
- Register function schemas
- Parse model output
- Validate function args
- Execute native handlers

**RagPipeline.kt**:
- Chunking logic
- Embedding inference
- Vector retrieval
- Context concatenation

**OcrProcessor.kt**:
- ML Kit integration
- Tesseract fallback
- Image preprocessing

**FieldExtractor.kt**:
- Regex-based parsing
- Heuristic rules
- Confidence scoring

#### iOS (`ios/Runner/`)

**GemmaInferenceEngine.swift**:
- CoreML model loading
- LiteRT runtime setup
- Inference pipeline

**FunctionCallingManager.swift**:
- Function schema registration
- Output parsing
- Native handler execution

**RagPipeline.swift**:
- Chunking, embedding, retrieval

**OcrProcessor.swift**:
- Vision framework integration
- Tesseract wrapper

#### Web (`web/ai_edge_bridge.js`)

**GemmaInferenceEngine.js**:
- LiteRT Web runtime
- WASM model loading
- Streaming inference

**RagPipeline.js**:
- WebWorker for indexing
- IndexedDB for vectors
- Retrieval logic

---

### 4. Local Storage Layer

#### SQLCipher Database Schema

```sql
-- Extracted Documents
CREATE TABLE documents (
  id TEXT PRIMARY KEY,
  filename TEXT,
  file_type TEXT,
  upload_date TIMESTAMP,
  extracted_data JSON,
  encrypted_key BLOB
);

-- Vector Chunks
CREATE TABLE chunks (
  id TEXT PRIMARY KEY,
  document_id TEXT,
  chunk_text TEXT,
  embedding BLOB,
  metadata JSON,
  FOREIGN KEY(document_id) REFERENCES documents(id)
);

-- Function Execution History
CREATE TABLE function_calls (
  id TEXT PRIMARY KEY,
  function_name TEXT,
  input_args JSON,
  output_result JSON,
  execution_date TIMESTAMP,
  status TEXT
);

-- Notification Schedule
CREATE TABLE notifications (
  id TEXT PRIMARY KEY,
  plan_id TEXT,
  start_date DATE,
  recurrence TEXT,
  times TEXT,
  created_date TIMESTAMP
);

-- Payment Requests
CREATE TABLE payment_requests (
  id TEXT PRIMARY KEY,
  bill_id TEXT,
  participants JSON,
  items JSON,
  splits JSON,
  created_date TIMESTAMP
);
```

#### Vector Index (HNSW)

- Store quantized vectors (int8 or float16)
- Support add/search operations
- Maintain metadata for retrieval
- Persist to SQLite

---

### 5. Function Calling Schemas

#### fill_form
```json
{
  "name": "fill_form",
  "parameters": {
    "type": "object",
    "properties": {
      "name": {"type": "string"},
      "dob": {"type": "string", "format": "date"},
      "weight_kg": {"type": "number"},
      "height_cm": {"type": "number"},
      "diet_plan": {
        "type": "array",
        "items": {
          "type": "object",
          "properties": {
            "day": {"type": "integer"},
            "meals": {"type": "array", "items": {"type": "string"}},
            "times": {"type": "array", "items": {"type": "string"}},
            "notes": {"type": "string"}
          }
        }
      }
    },
    "required": ["name"]
  }
}
```

#### schedule_notifications
```json
{
  "name": "schedule_notifications",
  "parameters": {
    "type": "object",
    "properties": {
      "plan_id": {"type": "string"},
      "start_date": {"type": "string", "format": "date"},
      "recurrence": {"type": "string", "enum": ["daily", "weekly", "custom"]},
      "times": {"type": "array", "items": {"type": "string", "pattern": "^([01]\\d|2[0-3]):([0-5]\\d)$"}}
    },
    "required": ["plan_id", "start_date", "times"]
  }
}
```

#### split_bill
```json
{
  "name": "split_bill",
  "parameters": {
    "type": "object",
    "properties": {
      "bill_id": {"type": "string"},
      "participants": {
        "type": "array",
        "items": {
          "type": "object",
          "properties": {
            "user_id": {"type": "string"},
            "share_pct": {"type": "number"}
          }
        }
      },
      "items": {
        "type": "array",
        "items": {
          "type": "object",
          "properties": {
            "name": {"type": "string"},
            "price": {"type": "number"},
            "assigned_to": {"type": "array", "items": {"type": "string"}}
          }
        }
      }
    },
    "required": ["bill_id", "participants"]
  }
}
```

---

### 6. Data Flow Example: Bill Processing

```
1. User uploads PDF
   ↓
2. File preprocessing (orientation, crop)
   ↓
3. PDF text extraction (text layer or OCR)
   ↓
4. Rule-based field extraction (amounts, dates, items)
   ↓
5. Chunking + embedding (for RAG context)
   ↓
6. LLM inference with RAG context
   ↓
7. Function calling: split_bill()
   ↓
8. Native handler: compute shares, create payment requests
   ↓
9. Store in SQLCipher DB
   ↓
10. Display results in Flutter UI
```

---

### 7. Error Handling & Fallbacks

- **Model Load Failure**: Show error, offer cloud fallback
- **OOM**: Switch to smaller model or stream tokens
- **OCR Failure**: Use rule-based extraction only
- **Function Hallucination**: Validate args, show confirmation UI for payments
- **Network**: All operations work offline; sync when online

---

**Last Updated**: 2025-10-30

