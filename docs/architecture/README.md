# 🏗️ Architecture

Technical architecture and design decisions for Airo Super App.

---

## 📖 Documentation

### [TECHNICAL_ARCHITECTURE.md](./TECHNICAL_ARCHITECTURE.md)
**System architecture overview**:
- High-level design
- Component structure
- Data flow
- Technology stack
- Design patterns

### [GEMINI_NANO_FIX_SUMMARY.md](./GEMINI_NANO_FIX_SUMMARY.md)
**AI integration details**:
- Gemini Nano setup
- On-device inference
- Model optimization
- Integration points

### [MODEL_DELIVERY_AND_SIZE_GUARDRAILS.md](./MODEL_DELIVERY_AND_SIZE_GUARDRAILS.md)
**Release bundle size policy**:
- Runtime delivery for large AI model artifacts
- CI checks that prevent accidental model bundling
- APK size investigation workflow

---

## 🎯 Key Components

### Frontend
- **Flutter** - Cross-platform UI framework
- **Riverpod** - State management
- **Go Router** - Navigation

### Backend
- **Dart** - Programming language
- **Firebase** - Backend services
- **SQLCipher** - Encrypted database

### AI/ML
- **Gemma 1B** - Language model (int4 quantized)
- **LiteRT** - On-device inference
- **MediaPipe** - ML Kit for OCR

### Security
- **SQLCipher** - Database encryption
- **SonarQube** - Code quality
- **Snyk** - Security scanning

---

## 📊 Architecture Diagram

```
┌─────────────────────────────────────┐
│         Flutter UI Layer            │
│  (Screens, Widgets, Navigation)     │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│      Riverpod State Management      │
│  (Providers, Controllers, Services) │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│      Domain Layer (Business Logic)  │
│  (Models, Services, Repositories)   │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│      Data Layer (Persistence)       │
│  (Firebase, SQLCipher, Local Store) │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│      AI/ML Layer (On-Device)        │
│  (Gemini Nano, LiteRT, MediaPipe)   │
└─────────────────────────────────────┘
```

---

## 🔗 Links

- **Flutter**: https://flutter.dev
- **Riverpod**: https://riverpod.dev
- **Firebase**: https://firebase.google.com
- **Gemini**: https://ai.google.dev

---

**Ready?** → [Read Technical Architecture](./TECHNICAL_ARCHITECTURE.md)
