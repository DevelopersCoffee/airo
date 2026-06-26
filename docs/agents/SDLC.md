# 📋 Airo SDLC Process

> Software Development Life Cycle for Agent-Based Development

## 🔄 Development Workflow

### 0. Spec Gate

Every implementation issue must complete the agent policy gates before code
starts. This is the default entry requirement for feature, bug, framework,
security, QA, and automation work.

Required artifacts:
- Critical Agent Gate
- Feature Packet
- Cross-Agent Contract when more than one module or owner is involved
- Deterministic Use Cases
- Automation Flow
- Verification environment: host-only, physical device, simulator, or explicit
  emulator opt-in
- Security/privacy posture for data, tools, memory, model, network, file,
  finance, health, location, notification, and background work

See:
- [Agent Policy](./AGENT_POLICY.md)
- [Kaggle Vibe-Coding Adoption Plan](./KAGGLE_VIBE_CODING_ADOPTION.md)
- [Deterministic use-case tracker](https://github.com/DevelopersCoffee/airo/issues/323)

### 1. Issue Assignment
```
Issue Created → Backlog → Ready (when dependencies met) → Assigned
```

### 2. Development Flow
```mermaid
graph LR
    A[Pick Issue] --> B[Complete Spec Gate]
    B --> C[Create Branch]
    C --> D[Implement]
    D --> E[Local CI: act]
    E --> F{Passes?}
    F -->|No| D
    F -->|Yes| G[Create PR]
    G --> H[Code Review]
    H --> I{Approved?}
    I -->|No| D
    I -->|Yes| J[Merge]
    J --> K[Close Issue]
```

### 3. Branch Naming
```
agent/<agent-name>/<issue-number>-<short-description>

Examples:
- agent/core-architecture/5-normalize-packages
- agent/finance/8-save-expense-flow
- agent/ai-llm/7-gemini-nano-adapter
```

### 4. Commit Messages
```
<type>(<agent>): <description>

Types: feat, fix, refactor, test, docs, chore, ci, security

Examples:
- feat(finance): add save expense to transaction flow
- fix(ai): handle Gemini Nano initialization timeout
- test(qa): add OCR price parsing regression tests
- docs(docs): create ADR-001 package structure
```

### 5. PR Requirements
- [ ] Branch is up-to-date with main
- [ ] `act` local CI passes
- [ ] `flutter analyze` clean
- [ ] `flutter test` passes
- [ ] Android Emulator was not used unless explicitly approved with
      `AIRO_ALLOW_ANDROID_EMULATOR=true`
- [ ] Issue linked in PR description
- [ ] Acceptance criteria met
- [ ] No merge conflicts

### 6. Device Verification Policy

Android Emulator/QEMU crashes on macOS are treated as infrastructure failures.
They do not prove an Airo app regression. If a run produces
`qemu-system-aarch64 EXC_BAD_ACCESS / KERN_INVALID_ADDRESS`, agents must stop
the emulator path, preserve the report, and continue with host-only tests or a
physical Android device.

Default local verification must stay host-only:
- `flutter analyze`
- `flutter test`
- package tests
- Playwright/web checks
- APK build checks

Device-only tests must name the environment in the issue and PR. Android
Emulator verification requires explicit risk acceptance by setting
`AIRO_ALLOW_ANDROID_EMULATOR=true`; otherwise agents should use a connected
physical Android device via `AIRO_JOURNEY_ANDROID_DEVICE=<adb-serial>`.

---

## 📊 GitHub Project Board Columns

| Column | Description | Entry Criteria |
|--------|-------------|----------------|
| **Backlog** | All unstarted issues | Issue created |
| **Ready** | Dependencies met, can start | Blocking issues closed |
| **In Progress** | Actively being worked on | Branch created |
| **Blocked** | Waiting on external | Document blocker in comment |
| **Review** | PR open, awaiting review | PR created |
| **QA** | Testing in progress | PR approved |
| **Done** | Complete | PR merged |

---

## 🏷️ Label Usage

### Required Labels (Every Issue)
- `agent/<name>` - Which agent owns this
- `priority/P0|P1|P2` - Priority level
- `type/task|bug|feature` - Type of work

### Optional Labels
- `blocked` - Waiting on something
- `needs-design` - Requires design decision
- `needs-qa` - Extra testing needed
- `breaking` - Breaking change

---

## 📝 Issue Updates

### When to Comment
- Starting work: "Starting work on this"
- Progress update: "Completed X, working on Y"
- Blocked: "Blocked by #N because..."
- Completed subtask: Check off in issue body
- Lessons learned: Document what you discovered

### Comment Format
```markdown
## Status Update - YYYY-MM-DD

**Progress:**
- [x] Completed task 1
- [ ] Working on task 2

**Blockers:** None / Blocked by #N

**Next Steps:**
- Task 3
- Task 4

**Lessons Learned:**
- Discovery or pattern to remember
```

---

## 🔐 Security Rules

1. **No secrets in code** - Use `.vscode/secrets/` (gitignored)
2. **No secrets in issues** - Reference by name only
3. **Scan before commit** - `git secrets --scan`
4. **Report vulnerabilities** - Create security issue privately

---

## 🚀 Release Process

1. All P0-P2 issues for milestone closed
2. QA Agent completes smoke tests
3. Release Agent creates release PR
4. Changelog auto-generated
5. Tag created: `v1.x.x`
6. CI builds and uploads artifacts
7. Store submission (if applicable)

---

## 📈 Metrics We Track

| Metric | Target | Measured By |
|--------|--------|-------------|
| Cycle Time | <3 days | Issue open → closed |
| PR Review Time | <24h | PR open → approved |
| CI Pass Rate | >95% | GitHub Actions |
| Test Coverage | Core ≥80%, Features ≥60% | Coverage report |
| Bug Escape Rate | <5% | Bugs found post-release |

---

## 🔄 Continuous Improvement

### Weekly Review
1. What issues were completed?
2. What blocked us?
3. What can we automate?
4. What rules need updating?

### Rule Change Process
1. Identify improvement
2. Propose in Issue comment or Discussion
3. Create PR to update RULES.md or SDLC.md
4. Get approval
5. Merge and announce
