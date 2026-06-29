# AIRO Architecture Map

This document maps the major subsystems required for AIRO to function as an offline-first AI productivity platform.

| Subsystem | Introduced in Release | Current Maturity | Dependencies | AIRO Priority | Planned Implementation Phase |
| :--- | :--- | :--- | :--- | :--- | :--- |
| UI Framework | *TBD* | Stable | None | Critical | MVP |
| Navigation | *TBD* | Stable | UI Framework | Critical | MVP |
| Model Manager | *TBD* | Experimental | Download Manager, Storage | Critical | MVP |
| Download Manager | *TBD* | Stable | Storage Layer | Critical | MVP |
| AI Runtime | *TBD* | Experimental | Model Manager | High | v1 |
| STT Pipeline | *TBD* | Experimental | AI Runtime, Audio Service | High | v1 |
| TTS Pipeline | *TBD* | Experimental | AI Runtime | Medium | v2 |
| Embedding Service | *TBD* | Experimental | AI Runtime | Medium | v1 |
| Vector Database | *TBD* | Experimental | Storage Layer | Medium | v1 |
| Search Engine | *TBD* | Experimental | Vector Database | High | v1 |
| Knowledge Base | *TBD* | Experimental | Vector Database, Storage | High | v2 |
| Conversation Memory | *TBD* | Experimental | Vector Database | High | v2 |
| Background Worker | *TBD* | Production | Sync Layer | Critical | v1 |
| Storage Layer | *TBD* | Production | None | Critical | MVP |
| Sync Layer | *TBD* | Experimental | Storage Layer, Auth | High | v2 |
| Analytics | *TBD* | Experimental | Storage Layer | Low | Future |
| Settings | *TBD* | Stable | Storage Layer | Medium | MVP |
| Plugin System | *TBD* | Experimental | AI Runtime | Low | Future |
