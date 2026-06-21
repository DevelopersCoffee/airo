# Airo Agent Skills Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port the useful Google AI Edge Gallery and Off Grid architecture patterns into Airo chat so common routines can be launched or completed from chat.

**Architecture:** Add an Airo-native agent skill layer with structured intents, tool cards, deterministic local tool handlers, and route targets. Keep existing Flutter routes and feature domains; chat becomes the control surface instead of replacing feature screens. Replace Gallery's Tiny Garden pattern with Airo's Arena games.

**Tech Stack:** Flutter, Dart, GoRouter, `flutter_test`, existing Airo feature routes and Gemini Nano service.

**Follow-up:** For Google AI Edge Gallery style skill packages, connector permissions, tool-call traces, and calendar read/create support, continue with `docs/superpowers/plans/2026-06-20-airo-agent-skills-connectors.md`. This first plan only covers deterministic Airo routing tools and prompt cards.

---

### Task 1: Agent Intent Coverage

**Files:**
- Modify: `app/lib/features/agent_chat/domain/services/intent_parser.dart`
- Test: `app/test/features/agent_chat/domain/services/intent_parser_test.dart`

- [x] **Step 1: Write failing tests**
- [x] **Step 2: Run test to verify it fails**
- [x] **Step 3: Implement parser changes**
- [x] **Step 4: Run test to verify it passes**

### Task 2: Agent Tool Registry

**Files:**
- Modify: `app/lib/features/agent_chat/domain/services/tool_registry.dart`
- Test: `app/test/features/agent_chat/domain/services/tool_registry_test.dart`

- [x] **Step 1: Write failing tests**
- [x] **Step 2: Run test to verify it fails**
- [x] **Step 3: Implement minimal tool layer**
- [x] **Step 4: Run test to verify it passes**

### Task 3: Chat Screen Adoption

**Files:**
- Modify: `app/lib/features/agent_chat/presentation/screens/chat_screen.dart`

- [x] **Step 1: Update chat dispatch**
- [x] **Step 2: Update prompt cards**
- [x] **Step 3: Verify analyzer and focused tests**
