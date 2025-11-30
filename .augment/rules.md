# Airo Super App - Project Rules & Conventions

## Project Overview
- **Name**: Airo - On-device AI platform for PDF/image/audio processing
- **Target Platforms**: Pixel 9 (Android), iOS 26, Chrome (PWA)
- **AI Model**: Gemma 1B (int4 quantized), LiteRT/AI Edge SDKs
- **Core Functions**: `fill_form()`, `schedule_notifications()`, `split_bill()`

## Architecture

### State Management
- **Use Riverpod** for all state management (StateProvider, StateNotifierProvider, FutureProvider)
- Domain-Driven Design: domain (models, services) → application (providers) → presentation (screens, widgets)

### AI/ML Strategy (Hybrid Approach)
1. **On-device first**: ML Kit OCR + Gemini Nano for privacy/offline
2. **Cloud fallback**: Gemini API (Flash/Pro) for complex tasks
3. **Limits**: Gemini Nano has 1024 prompt tokens, 4096 context
4. Look for `TODO: OPTIMIZATION` comments for on-device replacement opportunities

### Storage Strategy
- **Current MVP**: SharedPreferences + JSON (fast to implement)
- **Target**: SQLCipher for encrypted storage of financial data
- **Backup**: Firebase Firestore for cloud sync (future)

### Navigation
- Layer-based modular navigation using bottom sheets/overlays with stack-based history
- Use GoRouter for route management

## Code Conventions

### Testing
1. **Playwright** for browser E2E tests (Flutter Web with HTML renderer)
2. **Patrol** for iOS/Android device testing
3. **Unit Tests**: Write tests first (TDD approach)
4. Add test IDs using `Semantics` or `Key` for selectors

### Package Management
- Always use `flutter pub add/remove` - never manually edit pubspec.yaml
- Use existing dependencies (Dio, not http package)

### Git Workflow
- Conventional commits: `feat:`, `fix:`, `chore:`, `docs:`
- Push to both `master` and `main` branches for GitHub Pages
- Keep `.vscode/` local only (in .gitignore)

### File Organization
```
app/
├── lib/
│   ├── core/services/         # Shared services (AI, auth, storage)
│   ├── features/{feature}/
│   │   ├── application/       # Providers, controllers
│   │   ├── domain/            # Models, services
│   │   └── presentation/      # Screens, widgets
├── integration_test/          # Patrol E2E tests
├── test/                      # Unit tests
docs/                          # GitHub Pages documentation
.vscode/                       # Local config (not in git)
  ├── secrets/                 # API keys, credentials
  └── .augment/                # Augment context (pending tasks)
```

## Key Dependencies
- `google_mlkit_text_recognition`: OCR
- `image_picker`: Camera/gallery
- `dio`: HTTP client
- `shared_preferences`: Local storage (MVP)
- `patrol`: E2E device testing
- `flutter_riverpod`: State management

## API Keys & Secrets
- Store in `.vscode/secrets/` (gitignored)
- Gemini API key required for cloud-based parsing
- Structure: `.vscode/secrets/google.json`

## Success Metrics
- 90% offline accuracy
- <3s PDF extraction
- <1.2GB footprint
- F1≥0.9 extraction accuracy
- <5% battery per workflow

