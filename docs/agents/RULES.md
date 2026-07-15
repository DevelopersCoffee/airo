# 🤖 Airo Agent Operating Rules

> **Last Updated:** 2026-07-15
> **Version:** 1.2.1
> **Project Board:** https://github.com/orgs/DevelopersCoffee/projects/2

## 📋 Rule Updates

When updating these rules:
1. Create a PR with changes to this file
2. Tag with `docs` label
3. Get approval from project maintainer
4. Update version number and date

---

## 🎯 Core Principles

### 1. GitHub is the Single Source of Truth
- ❌ NO local task tracking (`.vscode/agents/` is reference only)
- ✅ All tasks tracked as GitHub Issues
- ✅ All progress updated on GitHub Project Board
- ✅ All discussions in Issue comments
- ✅ All decisions documented in PRs or ADRs

### 2. Agents are On-Demand, Not Always-On
- Agents are activated only when their phase begins
- Agents complete their tasks and go dormant
- Multiple agents can run in parallel if no dependencies

### 3. Continuous Learning
- Each agent documents lessons learned in Issue comments
- Rules are updated via PRs when patterns emerge
- Failed approaches are documented to prevent repetition

---

## 📊 Agent Priority & Sequencing

### Phase 0: Foundation (Must Complete First)
| Priority | Agent | Issue | Blocks | Duration |
|----------|-------|-------|--------|----------|
| 🔴 P0-0 | DevEx / QA Host Stability | P0 emulator guardrail | All device E2E | Immediate |
| 🔴 P0-1 | Core Architecture | #5 | All others | Week 1 |
| 🔴 P0-2 | CI/CD (remaining) | #10 | Releases | Week 1 |
| 🔴 P0-3 | Security (remaining) | #9 | All data work | Week 1 |

### Phase 1: Infrastructure (After Phase 0)
| Priority | Agent | Issue | Blocks | Duration |
|----------|-------|-------|--------|----------|
| 🟠 P1-1 | Offline & Sync | #6 | Finance, AI | Week 2 |
| 🟠 P1-2 | DevEx | #13 | Onboarding | Week 2 |

### Phase 2: Features (After Phase 1)
| Priority | Agent | Issue | Blocks | Duration |
|----------|-------|-------|--------|----------|
| 🟡 P2-1 | AI / LLM | #7 | Finance AI | Week 3 |
| 🟡 P2-2 | Finance | #8 | None | Week 3 |
| 🟡 P2-3 | Mobile UI | #11 | None | Week 3 |

### Phase 3: Quality (After Phase 2)
| Priority | Agent | Issue | Blocks | Duration |
|----------|-------|-------|--------|----------|
| 🟢 P3-1 | QA Testing | #12 | Release | Week 4 |
| 🟢 P3-2 | Release | #14 | None | Week 4 |

### Phase 4: Polish (After Phase 3)
| Priority | Agent | Issue | Blocks | Duration |
|----------|-------|-------|--------|----------|
| 🔵 P4-1 | Observability | #15 | None | Week 5 |
| 🔵 P4-2 | Docs | #16 | None | Week 5 |

---

## 🔄 Agent Lifecycle

```
DORMANT → ACTIVATED → IN_PROGRESS → REVIEW → COMPLETE → DORMANT
```

### State Transitions

1. **DORMANT → ACTIVATED**
   - Trigger: Phase begins OR dependency completed
   - Action: Move issue to "Ready" column

2. **ACTIVATED → IN_PROGRESS**
   - Trigger: Agent starts work
   - Action: Move issue to "In Progress", create branch

3. **IN_PROGRESS → REVIEW**
   - Trigger: PR created
   - Action: Move issue to "Review" column

4. **REVIEW → COMPLETE**
   - Trigger: PR merged, CI green
   - Action: Move issue to "Done", close issue

---

## ✅ Agent Work Rules

### Before Starting Work
1. Check issue is in "Ready" column
2. Check all blocking issues are closed
3. Self-assign or get assigned
4. Move issue to "In Progress"
5. Create branch: `agent/<name>/<issue>-<desc>`

### During Work
1. Update issue with progress comments (daily minimum)
2. Check off completed subtasks in issue body
3. Run focused local validation for the touched module before each push
4. Add `[skip ci]` to iterative issue commits and merge commits unless remote
   CI is explicitly required
5. Keep commits small and focused
6. Document blockers immediately

### CI Cost Guardrail
GitHub Actions minutes are a costed resource. Agents should avoid unnecessary
remote builds during iterative issue work.

- Prefer local validation first: formatting, analyzer/lint, targeted tests, and
  `git diff --check` as applicable.
- Use `[skip ci]` on iterative issue commits and integration merge commits.
- For current v2.0.0.0 development, remote CI is opt-in during issue iteration
  unless a maintainer explicitly asks for it or the change is a release
  verification step.
- Do not push directly to release-line branches such as `main` or `v2` just to
  validate work in progress.
- Avoid empty commits, no-op pushes, repeated metadata-only pushes, or branch
  churn that can trigger workflows without changing reviewable behavior.
- Close issues as soon as acceptance criteria and focused local validation
  evidence are recorded. Do not keep an accepted issue open just to wait for
  remote CI unless CI was explicitly required.
- If remote CI is intentionally required, explain why in the issue or PR before
  pushing without `[skip ci]`.

### Host Stability Guardrail
LLM agents must not use the Android Emulator as the default verification path.
The attached crash signature `qemu-system-aarch64 EXC_BAD_ACCESS /
KERN_INVALID_ADDRESS` is an infrastructure failure, not an app failure. When it
appears, stop device testing, preserve the crash report, and switch to
host-only checks or a physical device.

Allowed verification order:
1. Host-only deterministic checks: `flutter test`, `flutter analyze`, package
   tests, web/Playwright checks, and APK builds.
2. Physical Android device when Android-only behavior must be verified.
3. iOS simulator for iOS/macOS-local smoke coverage when the issue requires it.
4. Android Emulator only with explicit opt-in:
   `AIRO_ALLOW_ANDROID_EMULATOR=true`.

Agent rules:
- Do not run `make boot-pixel9`, `make run-pixel9`, or Android Patrol emulator
  tests unless the issue or maintainer explicitly accepts emulator risk.
- If Android E2E is required, prefer `AIRO_JOURNEY_ANDROID_DEVICE=<adb-serial>`
  with a physical device.
- If the emulator crashes, do not retry in a loop. Mark the emulator path
  blocked, attach the crash report, and continue with host/physical-device
  verification.
- PRs must say which environment was used: host-only, physical Android, iOS
  simulator, or explicit Android Emulator opt-in.

### Completing Work
1. Ensure all acceptance criteria met
2. Create PR with issue link
3. Move issue to "Review"
4. Address review feedback promptly
5. After merge, verify issue auto-closes

### If Blocked
1. Move issue to "Blocked" column
2. Comment with blocker details
3. Tag blocking issue/person
4. Switch to another ready task if possible

---

## 🚫 Anti-Patterns (Don't Do These)

| ❌ Don't | ✅ Do Instead |
|----------|---------------|
| Work without issue | Create issue first |
| Trigger unnecessary Actions builds | Run focused local validation and use `[skip ci]` for iterative pushes |
| Skip issue updates | Comment daily progress |
| Ignore blockers | Document and escalate |
| Large PRs (>500 lines) | Split into smaller PRs |
| Direct push to main | Always use PR |
| Hardcode secrets | Use environment/secrets |
| Skip tests | Add tests for new code |
| Retry Android Emulator after QEMU crash | Stop, preserve report, use host checks or physical device |

---

## 📞 Communication Channels

| Purpose | Channel |
|---------|---------|
| Task discussion | Issue comments |
| Code discussion | PR comments |
| Architecture decisions | ADR in `docs/adr/` |
| Questions | GitHub Discussions |
| Urgent issues | Tag maintainer in issue |
| Rule changes | PR to this file |

---

## 🏆 Definition of Done

An agent task is DONE when:
- [ ] All acceptance criteria checked
- [ ] Tests pass (`flutter test`)
- [ ] Linting clean (`flutter analyze`)
- [ ] Focused local validation passes, with remote CI reserved for explicit release or PR gates
- [ ] PR approved and merged
- [ ] Issue closed
- [ ] No regressions in related features

---

## 🌐 Web Platform Rules

### Web Build Compatibility
When adding new features, ensure web platform compatibility:

1. **No dart:ffi on Web** - Native SQLite/Drift won't work on web
2. **Create stub files** for platform-specific code:
   - `*_stub.dart` - Web-compatible no-op implementations
   - Use conditional imports: `if (dart.library.html)`
3. **Test web build** before committing: `cd app && flutter build web --release`

### Stub File Pattern
```dart
// file.dart (main)
import 'file_stub.dart' if (dart.library.io) 'file_native.dart';

// file_stub.dart (web - no-op)
class MyService {
  Future<void> doThing() async {} // No-op for web
}

// file_native.dart (mobile/desktop)
class MyService {
  Future<void> doThing() async { /* actual impl */ }
}
```

### Web Platform Files Created
- `app/lib/core/database/app_database_stub.dart`
- `app/lib/features/money/data/repositories/local_*_repository_stub.dart`
- `app/lib/features/money/application/services/*_service_stub.dart`

---

## 🔥 Firebase Integration Rules

### Firebase Project Details
- **Project Name**: Airo
- **Android SHA-1**: `8A:07:B9:45:21:18:F6:D7:7E:C5:77:2F:34:DE:A5:14:4D:03:E0:53`
- **Android Package**: `com.example.airo`

### Firebase Setup Checklist
- [x] Firebase project created
- [x] Google Sign-In enabled in Authentication
- [x] Firestore database created (production mode)
- [x] SHA-1 fingerprint added for Android
- [ ] Firebase packages added (see Issue #53)
- [ ] Web config added to `web/index.html`
- [ ] `google-services.json` for Android
- [ ] `GoogleService-Info.plist` for iOS

### Pending Firebase Tasks
See **Issue #53**: [Add Firebase Authentication with Google Sign-In](https://github.com/DevelopersCoffee/airo/issues/53)

---

## 📚 Related Documents

- [SDLC Process](./SDLC.md) - Development workflow
- [Agent Sequence](./SEQUENCE.md) - When agents activate
- [Project Board](https://github.com/orgs/DevelopersCoffee/projects/2) - Live status
