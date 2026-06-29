# AIRO Architecture Specification

# Part 5B — Retrieval-Augmented Generation (RAG) & Retrieval Engine

Version: 1.0 (Draft)

---

# 1. Objective

The Retrieval Engine is responsible for providing the LLM with only the most relevant knowledge instead of the entire knowledge base.

The objective is not search.

The objective is **context construction**.

A good Retrieval Engine makes a small model behave like it has a perfect memory.

---

# 2. Why RAG?

Without Retrieval

```text
User Question

↓

Entire Meeting History

↓

Entire Knowledge Base

↓

LLM

↓

Hallucinations
```

With Retrieval

```text
User Question

↓

Intent Detection

↓

Hybrid Retrieval

↓

Context Assembly

↓

Prompt Builder

↓

LLM

↓

Grounded Answer
```

---

# 3. Design Principles

The retrieval system must be:

* Offline-first
* Incremental
* Explainable
* Deterministic
* Fast
* Multi-stage
* Model independent
* Hardware aware

---

# 4. Retrieval Architecture

```text
User Query

↓

Query Analyzer

↓

Intent Detection

↓

Hybrid Search

├── Keyword Search
├── Semantic Search
├── Knowledge Graph Search
└── Metadata Search

↓

Candidate Ranking

↓

Context Optimizer

↓

Prompt Builder

↓

LLM
```

---

# 5. Retrieval Pipeline

Every query follows the same lifecycle.

```text
Question

↓

Normalize

↓

Rewrite

↓

Expand

↓

Retrieve

↓

Rank

↓

Compress

↓

Assemble Context

↓

Generate Response
```

---

# 6. Query Understanding

Extract

* Intent
* Topics
* Entities
* Workspace
* Time range
* Participants
* Filters

Example

> "What did Alice decide about Yugabyte last month?"

Extracted

```
Intent:
Decision Search

Entity:
Yugabyte

Person:
Alice

Time:
Last Month
```

---

# 7. Query Rewriting

Rewrite vague queries.

Example

```
"What did we decide?"
```

↓

```
"What decisions were made in the current workspace during the active meeting?"
```

---

# 8. Knowledge Sources

Search simultaneously across

* Meetings
* Documents
* PDFs
* Notes
* OCR
* URLs
* Tasks
* Decisions
* Knowledge Graph
* Attachments

Retrieval is source agnostic.

---

# 9. Hybrid Search

Combine four search methods.

## Keyword Search

Fast exact matching.

---

## Semantic Search

Embedding similarity.

---

## Graph Search

Relationship traversal.

---

## Metadata Search

Date

Workspace

Speaker

Tags

Language

Owner

---

Results are merged before ranking.

---

# 10. Embedding Strategy

Every Knowledge Object receives an embedding.

Supported embedding targets

Meeting

Transcript Chunk

Summary

Decision

Task

Document

Paragraph

Image Caption

OCR Text

URL

Future models can replace embedding engines without changing storage.

---

# 11. Chunking Strategy

Different content requires different chunking.

Meetings

Speaker-aware chunks.

Documents

Paragraph chunks.

PDF

Logical section chunks.

OCR

Region-based chunks.

Images

Caption + OCR.

Never use fixed-size chunks everywhere.

---

# 12. Candidate Retrieval

Initial retrieval may return

50–200 candidates.

Only the best candidates proceed to reranking.

---

# 13. Reranking

Rank using

Semantic similarity

Recency

Workspace relevance

Speaker relevance

Topic relevance

Relationship strength

User interaction history

Ranking is explainable.

---

# 14. Context Budget

The LLM has limited context.

Allocate budget.

Example

```
System Prompt

10%

Conversation

20%

Retrieved Knowledge

55%

Tool Results

10%

Reserved Tokens

5%
```

Budget adapts by model.

---

# 15. Context Compression

Large retrieved documents are compressed.

Techniques

Extractive summary

Semantic compression

Duplicate removal

Citation preservation

The original knowledge remains untouched.

---

# 16. Prompt Assembly

Prompt structure

```
System

↓

Workspace Context

↓

Conversation Memory

↓

Retrieved Knowledge

↓

Tool Results

↓

Current Question
```

Prompt assembly is centralized.

---

# 17. Retrieval Explanation

Users should know why knowledge appeared.

Example

```
Included because:

Meeting

Architecture Review

Similarity

0.91

Referenced by

Bob

Last week
```

Improves trust.

---

# 18. Incremental Indexing

New knowledge becomes searchable quickly.

Stages

Metadata

↓

Keyword

↓

Embedding

↓

Relationship

↓

Fully Indexed

Users are never blocked.

---

# 19. Retrieval Cache

Cache

Recent searches

Embeddings

Frequent prompts

Graph traversals

Workspace summaries

Avoid redundant computation.

---

# 20. Background Optimization

Periodically

Recompute embeddings

Improve relationships

Rebuild graph

Detect duplicates

Refresh summaries

The system improves over time.

---

# 21. Search Types

Supported

Keyword

Semantic

Hybrid

Speaker

Topic

Decision

Task

Meeting

Timeline

Relationship

Workspace

Global

---

# 22. Search Filters

Support

Workspace

Date

Speaker

Topic

Tags

Language

Meeting

Project

Knowledge Type

Confidence

---

# 23. Ranking Factors

Final ranking considers

Embedding similarity

Keyword relevance

Graph distance

Recency

Popularity

Confidence

Workspace affinity

Importance score

User behavior

---

# 24. Retrieval Telemetry

Capture

Search latency

Embedding latency

Candidates retrieved

Context size

Compression ratio

Cache hit rate

Prompt size

Ranking confidence

Useful for optimization.

---

# 25. Failure Handling

Recover from

Missing embeddings

Corrupted vector index

Large documents

Unsupported language

Index rebuild

Storage corruption

Fallback to keyword search if necessary.

---

# 26. Platform Components

QueryAnalyzer

IntentDetector

QueryRewriter

HybridSearchEngine

EmbeddingIndex

GraphSearcher

MetadataSearcher

CandidateRanker

ContextOptimizer

PromptAssembler

RetrievalCache

SearchTelemetry

---

# 27. Architecture Decision Records

## ADR-026 — Hybrid Retrieval

Status

Accepted

Decision

Always combine keyword, semantic, graph, and metadata search.

Reason

No single retrieval strategy performs well for every query.

---

## ADR-027 — Central Prompt Builder

Status

Accepted

Decision

All prompts are assembled by a single service.

Reason

Ensures consistency, easier optimization, and avoids duplicated prompt logic.

---

## ADR-028 — Adaptive Context Budget

Status

Accepted

Decision

Context allocation varies by model capability and query type.

Reason

Small models require aggressive budgeting while larger models can consume richer context.

---

## ADR-029 — Explainable Retrieval

Status

Accepted

Decision

Every retrieved item records why it was selected.

Reason

Improves user trust and simplifies debugging of retrieval quality.

---

## ADR-030 — Incremental Indexing

Status

Accepted

Decision

Knowledge becomes searchable progressively instead of waiting for complete indexing.

Reason

Provides fast feedback while background jobs continue improving retrieval quality.

---

# 28. Future Evolution

Phase 1

Keyword Search

↓

Phase 2

Semantic Search

↓

Phase 3

Hybrid Retrieval

↓

Phase 4

Knowledge Graph Reasoning

↓

Phase 5

Autonomous Knowledge Retrieval

Future enhancements

* Cross-workspace retrieval with explicit permissions
* Personalized ranking based on user behavior
* Multi-hop graph reasoning
* Automatic query decomposition
* Temporal retrieval ("what changed since last week?")
* Retrieval quality scoring
* Active learning from user feedback
* Multi-model retrieval strategies

The Retrieval Engine is the intelligence bridge between AIRO's Knowledge Platform and its language models. Its responsibility is not merely finding information but constructing the smallest, highest-quality context that enables accurate, grounded, and explainable AI responses.
