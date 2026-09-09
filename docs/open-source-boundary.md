# Airo Intellectual Property & Open-Source Boundary

> **Principle**: Public open-source infrastructure must never depend on private Airo application code or expose proprietary commercial assets.

---

## 1. Dependency Architecture Rule

```text
               ┌───────────────────────────────────────┐
               │    Airo Application (Private App)     │
               │  - Commercial Entitlements            │
               │  - Proprietary AI Prompts & Engines   │
               │  - User Experience & Product Shells   │
               └───────────────────┬───────────────────┘
                                   │
                    consumes published libraries
                                   │
               ┌───────────────────┴───────────────────┐
               │                                       │
       ┌───────▼────────┐                     ┌────────▼────────┐
       │ Public Flutter │                     │  Public Rust    │
       │ & Dart Pubs    │                     │  Crates.io      │
       └────────────────┘                     └─────────────────┘
```

> **STRICT CONTRACT**: Public packages (`DevelopersCoffee/*`) must NEVER import, reference, or depend on Airo application internals.

---

## 2. Public vs. Private Classification Matrix

### 🌐 PUBLIC (Open Source)
The following categories are safe and recommended for global publication:
* **Platform Utility & Tooling**: Viewport resolution simulators, D-Pad remote control emulators (`dpad_qualification`), device test reporters.
* **Pure Parsing & Processing**: M3U/M3U8 parsers, XMLTV EPG parsers, JSON stream decoders, text normalizers.
* **Low-Level Native Engine Crates**: Rust data structures, binary parsers, FFI primitives.
* **Security Primitives**: Field-level AES encryption, key rotation managers, platform keychain wrappers (without Airo business models).
* **Native Platform Adapters**: OS Calendar service abstractions, background file download progress engines.
* **Concurrency & Isolate Utilities**: `runOffMain<T>()` isolate execution wrappers, timeline performance tracing, CPU task schedulers.

### 🔒 PRIVATE (Airo Application Only)
The following components must ALWAYS remain confidential and internal to Airo:
* **Commercial Entitlement Logic**: `airo_pro_bootstrap` seam, Pro feature licensing, subscription validation.
* **Proprietary Prompts & Fine-Tuning**: Meeting summary system prompts, AI persona instructions, proprietary RAG workflows.
* **User Data & Credentials**: Private production database schemas, OAuth client secrets, internal server URLs.
* **Airo Application Journeys**: Product onboarding, user profile management, commercial checkout flows, branded theme tokens.
* **Unreleased Features**: Experimental product roadmap implementations, internal benchmark telemetry sinks.

---

## 3. Pre-Release Security & Supply Chain Checklist

Before releasing any package to `DevelopersCoffee`:

1. **Secret Scanning**: Audit source code and full Git history using `trufflehog` or `git-leaks` to confirm 0 credentials, tokens, or private infrastructure URLs are present.
2. **License Compliance**: Verify all third-party dependencies carry compatible open-source licenses (MIT, Apache-2.0, BSD-3-Clause).
3. **No Airo Leakage**: Search imports for `package:airo` or `package:core_domain` to ensure complete decoupling.
4. **Independent Build Verification**: Build and test the repository in an isolated workspace without any local path references to Airo.
