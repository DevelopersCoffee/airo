# Airo Wiki User Guide Plan

**Date:** 2026-06-20

**Goal:** Create a Google AI Edge Gallery-style public wiki for Airo so users
can quickly understand what the app can do, how to get started, and which
capabilities are current versus planned.

## Source Pattern Reviewed

The Google AI Edge Gallery wiki uses a concise user-guide structure:

- Home introduction.
- Overview and key features.
- Getting started and installation.
- Navigation guide.
- Core AI capability walkthroughs.
- Model management.
- Optional local model import.
- Troubleshooting and FAQ.
- Feedback and useful links.

The useful pattern is not the exact content. The reusable structure is a short
wiki that is capability-led, task-oriented, and easy to update as the app
changes.

Source pages reviewed:

- https://github.com/google-ai-edge/gallery/wiki
- https://raw.githubusercontent.com/wiki/google-ai-edge/gallery/Home.md
- https://raw.githubusercontent.com/wiki/google-ai-edge/gallery/1.-Overview.md
- https://raw.githubusercontent.com/wiki/google-ai-edge/gallery/2.-Getting-Started.md
- https://raw.githubusercontent.com/wiki/google-ai-edge/gallery/3.-Navigating-the-App.md
- https://raw.githubusercontent.com/wiki/google-ai-edge/gallery/4.-Using-Core-AI-Capabilities.md
- https://raw.githubusercontent.com/wiki/google-ai-edge/gallery/5.-Model-Management.md
- https://raw.githubusercontent.com/wiki/google-ai-edge/gallery/6.-Importing-Local-Models-%28optional%29.md
- https://raw.githubusercontent.com/wiki/google-ai-edge/gallery/7.-Troubleshooting-%26-FAQ.md
- https://raw.githubusercontent.com/wiki/google-ai-edge/gallery/8.-Feedback.md
- https://raw.githubusercontent.com/wiki/google-ai-edge/gallery/9.-Useful-Links.md

## Airo Adaptation

Use `docs/wiki` as the repository source for GitHub Wiki pages.

Recommended public wiki page order:

1. `Home.md`
2. `1.-Overview.md`
3. `2.-Getting-Started.md`
4. `3.-Navigating-Airo.md`
5. `4.-Using-Core-Capabilities.md`
6. `5.-AI-and-Model-Management.md`
7. `6.-Privacy-and-Local-Data.md`
8. `7.-Troubleshooting-and-FAQ.md`
9. `8.-Feedback.md`
10. `9.-Useful-Links.md`

## Brainstormed Capability Buckets

### Ship as current

- Assistant chat.
- Gallery-style prompt cards.
- Deterministic app command routing.
- Split bill quick calculation and Split Bill route.
- Money dashboard, add expense, budgets, groups, and group splits.
- Quest file upload for PDF, image, text, and document workflows.
- Model-management access through Assistant profile.
- Music and TV tabs.
- Arena games with Chess and Blackjack documented as available.

### Mention as planned or future only

- Full Audio Scribe offline transcription.
- Agent Skills runtime with manifests, connectors, action traces, and calendar.
- Remote/community skill import.
- Additional games marked as coming soon.

### Do not claim until implemented

- Calendar read/create execution.
- Raw local model import UI.
- Full offline transcription.
- Full offline document RAG accuracy guarantees.
- Payment sends or external account operations.

## Documentation Rule

Every PR must check whether it changes user-visible capability documentation.
If it changes any of the following, the PR must update `docs/wiki`:

- User-facing features, tabs, routes, or prompt cards.
- Install, download, or platform-support behavior.
- AI model behavior, fallback behavior, or model-management screens.
- Supported file types, media types, games, or finance workflows.
- Privacy, storage, sync, permissions, or sensitive-action confirmations.
- Troubleshooting or FAQ details.

If no wiki update is needed, the PR description must say why.

## Publishing Flow

Keep `docs/wiki` as source of truth. Publish to GitHub Wiki by syncing the files
into `https://github.com/DevelopersCoffee/airo.wiki.git`.

## Follow-Up Tasks

- Add a lightweight script that checks whether PRs touching `app/lib/features`,
  `app/lib/core/routing`, or `README.md` also touch `docs/wiki` or explicitly
  include a docs-not-needed label.
- Add screenshots after the app screens stabilize.
- Decide whether GitHub Pages should render the same pages alongside GitHub Wiki.
