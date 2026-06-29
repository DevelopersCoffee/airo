# AIRO Architecture Specification

# Part 8D — AI Chat Platform

Version: 1.0 (Draft)

---

# 1. Objective

The AI Chat Platform is the primary interaction surface of AIRO.

It is not a traditional chatbot. It is a workspace-aware AI operating environment capable of reasoning over local knowledge, memory, meetings, documents, tools, and workflows.

Every conversation is contextual, persistent, explainable, and fully offline by default.

---

# 2. Product Vision

Traditional chat

```text id="b7r0hg"
User

↓

Prompt

↓

LLM

↓

Answer
```

AIRO

```text id="2t4s8d"
User

↓

Planner

↓

Workspace Context

↓

Knowledge

↓

Memory

↓

Tools

↓

Workflow

↓

LLM

↓

Cited Response
```

The model is one component in a larger reasoning pipeline.

---

# 3. Design Principles

The Chat Platform must be:

* Offline-first
* Workspace-aware
* Model-agnostic
* Streaming
* Explainable
* Interruptible
* Tool-enabled
* Extensible

---

# 4. Conversation Model

Each conversation contains

```text id="m2xp91"
Conversation

├── Messages
├── Attachments
├── Citations
├── Tool Calls
├── Workflow History
├── AI Context
├── Memory References
├── Knowledge References
└── Metadata
```

---

# 5. Conversation Lifecycle

```text id="8m4h6j"
Create

↓

First Message

↓

Streaming Response

↓

Tool Execution

↓

Knowledge Update

↓

Archive
```

Empty conversations are not persisted until the first user message.

---

# 6. Context Assembly

Before inference AIRO assembles

* Workspace context
* Recent conversation
* Relevant memories
* Knowledge search results
* Meeting references
* User preferences
* Active workflow state
* Tool capabilities

Only relevant context is included.

---

# 7. Multi-Model Routing

Different requests may use different models.

Examples

| Task               | Preferred Model           |
| ------------------ | ------------------------- |
| General reasoning  | Text LLM                  |
| OCR                | Vision model              |
| Meeting summary    | Small summarization model |
| Translation        | Language model            |
| Embeddings         | Embedding model           |
| Speech recognition | Whisper                   |
| Speech synthesis   | TTS model                 |

Routing is automatic but configurable.

---

# 8. Streaming Responses

Responses stream incrementally.

Display includes

* Token streaming
* Tool execution status
* Citation updates
* Thinking indicator
* Cancellation support

Streaming remains responsive even during tool execution.

---

# 9. Thinking Mode

Supported modes

* Auto
* Fast
* Balanced
* Deep Reasoning

UI indicates active reasoning mode.

Reasoning traces remain optional and model-dependent.

---

# 10. Voice Mode

Capabilities

* Push-to-talk
* Continuous conversation
* Streaming STT
* Streaming TTS
* Interruptible playback
* Wake word (future)

Voice mode integrates with Meeting Intelligence.

---

# 11. Attachments

Supported

* PDF
* Images
* Audio
* Video
* Markdown
* ZIP
* Code
* CSV
* JSON

Attachments become part of the reasoning context.

---

# 12. Tool Calling

The planner may invoke

* Calculator
* Search
* OCR
* URL Reader
* Code Interpreter
* Knowledge Search
* Workflow Runner
* Plugin Tools

Tool execution is visible to the user.

---

# 13. Citations

Every answer may reference

* Documents
* Meetings
* Notes
* Tasks
* Knowledge Objects
* URLs
* Transcript timestamps

Users can navigate directly to the source.

---

# 14. Prompt Templates

Templates include

* Meeting summary
* Architecture review
* Code explanation
* Research
* Brainstorming
* Translation
* Writing
* Learning

Templates are extensible through plugins.

---

# 15. Chat Memory

Conversation uses

* Working memory
* Workspace memory
* Long-term memory
* Session context

Users can inspect memory usage.

---

# 16. Conversation Organization

Users organize chats by

* Workspace
* Project
* Tags
* Pinned
* Recent
* Archived

Search works across conversations.

---

# 17. Regeneration

Supported

* Regenerate response
* Edit prompt
* Branch conversation
* Compare responses
* Switch model
* Retry failed tool calls

Conversation history remains intact.

---

# 18. Conversation Branching

Users may fork a conversation.

```text id="x5jz4n"
Original

├── Branch A
├── Branch B
└── Branch C
```

Useful for experimentation.

---

# 19. AI Actions

AI may suggest

* Create task
* Save note
* Start workflow
* Remember information
* Schedule automation
* Open document

Suggestions require user confirmation.

---

# 20. Chat Search

Search supports

* Prompt text
* AI responses
* Attachments
* Tool usage
* Citations
* Semantic similarity

---

# 21. Conversation Insights

Automatically generated

* Main topics
* Decisions
* Frequently asked questions
* Action items
* Referenced documents
* Suggested follow-ups

---

# 22. Error Handling

Gracefully recover from

* Model unload
* OOM
* Tool failure
* Download interruption
* Context overflow
* Plugin failure

Users receive actionable guidance.

---

# 23. Offline Behavior

Without internet

* Local models continue
* Local search continue
* Local tools continue
* Knowledge remains available

Remote providers are clearly marked unavailable.

---

# 24. Performance

Optimize

* Streaming latency
* First-token latency
* Context assembly
* Token throughput
* Model switching
* Conversation loading

Use model residency where appropriate.

---

# 25. Plugin Integration

Plugins may contribute

* Prompt templates
* Chat actions
* Tool providers
* Conversation panels
* Context providers
* Response renderers

---

# 26. Developer Features

Developer mode exposes

* Prompt assembly
* Retrieved context
* Tool execution trace
* Token usage
* Model routing decision
* Latency breakdown

---

# 27. Platform Components

ConversationManager

PromptPlanner

ContextAssembler

ModelRouter

StreamingEngine

CitationManager

ToolExecutor

ConversationSearch

ChatMemoryCoordinator

ConversationInsights

---

# 28. Non-Functional Requirements

The Chat Platform must

* Operate fully offline
* Support multiple concurrent conversations
* Stream responses with low latency
* Recover from interruptions
* Support plugin extensions
* Maintain explainable reasoning through citations

---

# 29. Architecture Decision Records

## ADR-111 — Context Assembly Pipeline

**Status**

Accepted

**Decision**

Context is assembled dynamically from workspace knowledge, memory, and conversation history rather than relying solely on chat history.

**Reason**

Improves answer quality while minimizing prompt size.

---

## ADR-112 — Multi-Model Routing

**Status**

Accepted

**Decision**

The planner selects specialized models based on task type.

**Reason**

Improves performance, quality, and battery efficiency.

---

## ADR-113 — Deferred Conversation Creation

**Status**

Accepted

**Decision**

A conversation is created only after the first user message.

**Reason**

Avoids empty conversations and simplifies lifecycle management.

---

## ADR-114 — Explainable AI Responses

**Status**

Accepted

**Decision**

Responses referencing stored knowledge include citations and navigation links.

**Reason**

Improves transparency and user trust.

---

## ADR-115 — Tool-Oriented Reasoning

**Status**

Accepted

**Decision**

The planner may invoke tools and workflows as part of response generation instead of relying solely on model inference.

**Reason**

Extends capabilities beyond the limits of the language model.

---

# 30. Future Evolution

Phase 1

Offline Chat

↓

Phase 2

Knowledge-Aware Chat

↓

Phase 3

Tool Calling & Workflows

↓

Phase 4

Collaborative AI Sessions

↓

Phase 5

Autonomous Workspace Assistant

Future capabilities:

* Multi-agent conversations
* Shared conversations
* Live collaborative reasoning
* Visual prompt construction
* Interactive code execution
* AI-generated conversation summaries
* Cross-workspace reasoning
* Adaptive conversation memory
* Personalized response styles

The AI Chat Platform is the central interaction layer of AIRO. By combining workspace-aware context assembly, multi-model routing, tool execution, citations, memory integration, and streaming responses, it evolves beyond a conventional chatbot into an intelligent operating environment capable of reasoning over the user's complete offline knowledge ecosystem.
