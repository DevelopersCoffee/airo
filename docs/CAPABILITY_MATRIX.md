# AIRO Capability Matrix

## Master Platform Capability Inventory

Version: 1.0

---

# 1. Purpose

The Capability Matrix is the authoritative inventory of every reusable capability provided by AIRO.

Before introducing any new feature, engineers and AI coding agents must consult this matrix to determine whether an equivalent capability already exists.

The matrix prevents architectural duplication and ensures that new work extends existing platforms whenever possible.

---

# 2. Capability Classification

Capabilities are grouped into six layers:

```text id="cap-matrix-layers"
Product Layer
        │
Intelligence Layer
        │
Platform Layer
        │
Infrastructure Layer
        │
Developer Layer
        │
Operations Layer
```

Each capability has one owner and one implementation.

---

# 3. Capability Record Format

Every capability is documented using the following structure:

| Field            | Description                                                                 |
| ---------------- | --------------------------------------------------------------------------- |
| Capability       | Unique capability name                                                      |
| Layer            | Product / Intelligence / Platform / Infrastructure / Developer / Operations |
| Owner            | Responsible module                                                          |
| Status           | Planned / In Progress / Production / Deprecated                             |
| Public API       | Yes / No                                                                    |
| Plugin Extension | Yes / No                                                                    |
| Workspace Aware  | Yes / No                                                                    |
| Offline          | Required / Optional                                                         |
| Reusable         | Yes / No                                                                    |
| Dependencies     | Required platform capabilities                                              |

---

# 4. Product Layer

| Capability          | Owner                |
| ------------------- | -------------------- |
| Chat                | Chat Platform        |
| Meetings            | Meeting Intelligence |
| Notes               | Knowledge Platform   |
| Tasks               | Workflow Engine      |
| Documents           | Knowledge Platform   |
| Automation          | Automation Center    |
| Search              | Universal Search     |
| Memory Browser      | Memory Platform      |
| Workspace Dashboard | Workspace Platform   |

---

# 5. Intelligence Layer

| Capability          | Owner              |
| ------------------- | ------------------ |
| Prompt Planning     | Planner            |
| Context Assembly    | Context Engine     |
| Memory Retrieval    | Memory Platform    |
| Knowledge Retrieval | Search Platform    |
| Model Routing       | Runtime Platform   |
| Tool Planning       | Workflow Engine    |
| Citation Generation | Knowledge Platform |
| Response Streaming  | Runtime Platform   |
| Summarization       | AI Runtime         |
| Entity Extraction   | Knowledge Platform |

---

# 6. Platform Layer

| Capability      | Owner                 |
| --------------- | --------------------- |
| Storage         | Storage Platform      |
| Search          | Search Platform       |
| Event Bus       | Platform Core         |
| Settings        | Settings Platform     |
| Plugin SDK      | Plugin Platform       |
| Background Jobs | Job Scheduler         |
| Downloads       | Download Manager      |
| Notifications   | Notification Platform |
| Security        | Security Platform     |
| Diagnostics     | Diagnostics Platform  |

---

# 7. Infrastructure Layer

| Capability       | Owner            |
| ---------------- | ---------------- |
| SQLite           | Storage Platform |
| Vector Store     | Search Platform  |
| Embedding Engine | Runtime          |
| Whisper Runtime  | Runtime          |
| LLM Runtime      | Runtime          |
| TTS Runtime      | Runtime          |
| OCR Runtime      | Runtime          |
| Benchmark Engine | Diagnostics      |

---

# 8. Developer Layer

| Capability              | Owner               |
| ----------------------- | ------------------- |
| ADR Repository          | Architecture        |
| Documentation Generator | Documentation       |
| CI/CD                   | Platform Operations |
| Benchmark Suite         | Diagnostics         |
| Plugin SDK              | Platform            |
| Migration Framework     | Platform            |
| Quality Gates           | Engineering         |
| Static Analysis         | Engineering         |

---

# 9. Operations Layer

| Capability            | Owner       |
| --------------------- | ----------- |
| Release Pipeline      | Operations  |
| Dependency Governance | Maintenance |
| Repository Health     | Maintenance |
| Crash Recovery        | Runtime     |
| Model Verification    | Runtime     |
| Plugin Validation     | Platform    |
| Update Center         | Operations  |
| Backup & Restore      | Storage     |

---

# 10. Ownership Rules

Every capability has:

* One implementation
* One owner
* One public API
* One lifecycle
* One documentation source

Parallel implementations are prohibited.

---

# 11. Extension Rules

A capability may expose extension points for:

* Plugins
* AI agents
* Workflows
* UI components
* External model providers

Extensions must not replace the capability itself.

---

# 12. Lifecycle States

Every capability progresses through:

```text id="capability-lifecycle"
Proposed
   ↓
Planned
   ↓
In Development
   ↓
Experimental
   ↓
Production
   ↓
Deprecated
   ↓
Removed
```

Transitions require architecture review.

---

# 13. Capability Discovery

Before implementing new functionality, contributors must answer:

1. Does this capability already exist?
2. Can an existing capability be extended?
3. Does this belong in a platform rather than a feature?
4. Is an ADR required?
5. Will another feature reuse this?

If the answer to (2) is yes, extension is mandatory.

---

# 14. Cross-Cutting Concerns

Every capability should integrate with:

* Logging
* Diagnostics
* Settings
* Security
* Plugin SDK
* Background Jobs
* Documentation
* Accessibility

These concerns are never reimplemented locally.

---

# 15. Architectural Constraints

Capabilities must not:

* Own duplicate storage
* Maintain independent search indexes
* Introduce separate event buses
* Bypass the workflow engine
* Implement custom permission systems
* Create parallel settings screens

Violations require architectural approval.

---

# 16. Review Process

The Capability Matrix is reviewed:

* Before major feature work
* During architecture reviews
* Before introducing new platform modules
* During quarterly roadmap planning

It evolves alongside the platform.

---

# 17. Success Criteria

A mature AIRO platform exhibits:

* High capability reuse
* Minimal duplication
* Stable extension points
* Clear ownership
* Predictable evolution
* Low architectural drift

The Capability Matrix serves as the long-term architectural map of AIRO. It ensures that every future feature strengthens the platform by building upon existing capabilities rather than creating competing implementations, enabling sustainable growth over many years.
