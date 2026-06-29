# AIRO Engineering Playbook

# Part 11B — AI Coding Agent Governance & Autonomous Development

Version: 1.0 (Draft)

---

# 1. Objective

AIRO is designed to be developed by both human engineers and autonomous coding agents.

This document defines how AI coding agents (Codex, Augment, Claude Code, Cursor, Gemini CLI, etc.) participate in software development while maintaining architectural consistency.

The objective is not simply AI-assisted coding, but AI-governed engineering.

---

# 2. Core Philosophy

AI agents are treated as engineering team members.

They must follow the same standards as human developers.

Agents may generate code, documentation, tests, migrations, and refactorings, but they never bypass architecture, quality gates, or review workflows.

---

# 3. Engineering Workflow

Every task follows

```text id="2e8m4f"
Understand

↓

Analyze

↓

Design

↓

Plan

↓

Implement

↓

Test

↓

Validate

↓

Document

↓

Review

↓

Merge
```

No implementation begins before architecture analysis.

---

# 4. Required Task Lifecycle

Every engineering task must contain

## Problem Statement

What problem is being solved?

---

## Existing Architecture

Which platform components already exist?

---

## Reuse Analysis

Can an existing component be extended?

---

## ADR Impact

Does architecture change?

---

## Test Strategy

How will correctness be verified?

---

## Migration Strategy

Does existing behavior change?

---

## Rollback Strategy

Can the change be safely reverted?

---

# 5. Mandatory Repository Analysis

Before writing code, every agent must inspect

* Existing services
* Existing repositories
* Existing widgets
* Existing models
* Existing workflows
* Existing plugin APIs
* Existing tests

Creating duplicate infrastructure is prohibited.

---

# 6. Code Generation Rules

Generated code must

* Compile
* Pass lint
* Follow architecture
* Include documentation
* Include tests
* Preserve compatibility

Generated code is never considered complete without validation.

---

# 7. Refactoring Policy

Agents should prefer

Refactor

over

Rewrite

Preserve APIs whenever practical.

Large rewrites require ADR approval.

---

# 8. Architecture Protection

Agents must never

Create

* Another download manager
* Another search engine
* Another plugin system
* Another workflow engine
* Another settings platform
* Another event bus

Instead

Extend

existing platforms.

---

# 9. Feature Development Rules

Every feature should answer

Which existing platform provides

* Storage?
* Search?
* Settings?
* Jobs?
* Plugins?
* Logging?
* Security?
* Diagnostics?

If no answer exists

Design the platform first.

---

# 10. UI Development Rules

Agents must

Reuse components.

Extend components.

Parameterize components.

Avoid creating visually similar duplicates.

---

# 11. Design System Compliance

Every new screen

Uses

* Typography tokens
* Spacing tokens
* Color tokens
* Shared widgets
* Shared navigation

No hardcoded design values.

---

# 12. Performance Rules

Before merge

Verify

* Startup impact
* Memory impact
* Build size
* Runtime allocations
* Battery impact

Performance regressions require justification.

---

# 13. Testing Rules

Every change requires

Unit tests

Widget tests

Integration tests

Regression tests

Feature completeness is impossible without tests.

---

# 14. Documentation Rules

Agents update

* README
* Architecture
* ADR
* Public API
* Migration guide

Documentation changes are mandatory.

---

# 15. Pull Request Template

Every PR includes

Problem

Solution

Architecture

Alternatives

Testing

Performance

Security

Migration

Rollback

Documentation

---

# 16. Code Review Checklist

Review verifies

No duplicated logic

No architectural violations

No hidden state

No unnecessary abstraction

No feature-specific infrastructure

No dead code

No undocumented APIs

---

# 17. AI Review Pipeline

Recommended review order

Agent A

↓

Agent B

↓

Static Analysis

↓

Tests

↓

Human Review

↓

Merge

Independent AI reviews improve defect detection.

---

# 18. Automatic Architecture Checks

CI verifies

* Layering violations
* Dependency cycles
* Duplicate implementations
* API compatibility
* Plugin compatibility
* Documentation presence

Architecture drift is detected automatically.

---

# 19. Knowledge Capture

After completion

Capture

* Lessons learned
* New ADRs
* Migration notes
* Common pitfalls
* Reusable patterns

Knowledge compounds over time.

---

# 20. Autonomous Refactoring

Agents may propose

* API simplification
* Dead code removal
* Dependency reduction
* Performance optimization
* Component extraction
* Test improvements

Large refactors remain reviewable.

---

# 21. Repository Organization

Agents respect

```text id="m6v1hj"
apps/

packages/

platform/

plugins/

docs/

tools/

scripts/

benchmarks/

examples/
```

Repository layout remains predictable.

---

# 22. Multi-Agent Collaboration

Recommended specialization

### Architect

Creates ADRs

Defines architecture

---

### Planner

Creates implementation plans

Breaks work into tasks

---

### Builder

Implements features

---

### Reviewer

Finds defects

Suggests improvements

---

### QA Agent

Writes tests

Executes validation

---

### Documentation Agent

Updates docs

Creates migration guides

---

### Performance Agent

Benchmarks

Optimizes runtime

---

### Security Agent

Reviews permissions

Threat modeling

Audits dependencies

---

# 23. Engineering Metrics

Track

Average implementation time

Review iterations

Architecture violations

Test coverage

Regression rate

Documentation completeness

Component reuse

Technical debt

---

# 24. Anti-Patterns

Never allow

Generate code first

Design later

Copy existing modules

Create similar widgets

Ignore existing abstractions

Skip documentation

Skip testing

Skip architecture review

Duplicate infrastructure

Large undocumented rewrites

---

# 25. Architecture Decision Records

## ADR-156 — AI-First Engineering

**Status**

Accepted

**Decision**

The engineering workflow is designed to support autonomous coding agents from the beginning.

---

## ADR-157 — Repository Analysis Before Coding

**Status**

Accepted

**Decision**

Agents analyze existing architecture before implementation.

---

## ADR-158 — Multi-Agent Development

**Status**

Accepted

**Decision**

Different AI agents specialize in planning, implementation, testing, documentation, and review.

---

## ADR-159 — Architecture Preservation

**Status**

Accepted

**Decision**

Agents extend platform capabilities instead of introducing parallel implementations.

---

## ADR-160 — Documentation Is Code

**Status**

Accepted

**Decision**

Architecture documents evolve alongside source code.

---

# 26. Future Evolution

Phase 1

AI-assisted coding

↓

Phase 2

Multi-agent collaboration

↓

Phase 3

Architecture-aware agents

↓

Phase 4

Self-reviewing engineering teams

↓

Phase 5

Autonomous software organization

Future capabilities:

* Automatic ADR generation
* Continuous architecture conformance checking
* AI-generated migration plans
* Automatic dependency modernization
* Self-optimizing test suites
* Autonomous code health improvements
* Predictive technical debt analysis
* AI-assisted release management

The AI Coding Agent Governance model ensures that autonomous development strengthens the architecture rather than fragmenting it. By enforcing repository analysis, platform reuse, design system compliance, documentation, testing, and multi-agent collaboration, AIRO becomes a codebase that scales effectively with both human engineers and AI-driven development workflows.
