# Airo Coin — Product Roadmap

**Date:** 2026-07-19
**Status:** Draft for review
**Related:** Issue #927 (secure vault), `docs/superpowers/plans/2026-07-19-airo-coin-vault.md`, `packages/platform_coin_vault`

## Vision

Airo Coin is the finance module of the Airo super app: a **local-first, privacy-first personal finance manager**. All data lives on-device, encrypted at rest, biometric-locked. An **on-device LLM** (tool-calling over local data) powers categorization, insights, and a natural-language finance assistant — no financial data ever leaves the phone by default.

Like Airo TV, Airo Coin is **modular**: shippable standalone (its own entrypoint) and embeddable as a module inside the super app shell, following module.yaml governance.

## Product pillars

1. **Vault** — secure storage of financial records (PAN, bank accounts, documents). *Issue #927, in progress.*
2. **Spending** — expense tracking, budgets, recurring bills.
3. **Splits** — Splitwise-style shared expenses with friends/family.
4. **Investments** — portfolio tracking across asset classes.
5. **Airo Intelligence** — on-device LLM assistant with tool calling over the local finance database.

## Phase 0 — Foundation (Vault) ✅ started

- `platform_coin_vault`: AES-256-GCM at rest, Keystore/Secure Enclave keys, biometric-bound decryption (Issue #927).
- `feature_coin` module skeleton + entrypoint (`main_coin.dart` pattern, mirroring `main_tv.dart`).
- Record types: bank account, PAN, generic secure document.
- This phase establishes the crypto + storage substrate every later phase reuses.

## Phase 1 — Spending (personal finance core)

**Goal:** daily-driver expense tracker.

- Accounts & balances: cash, bank, credit card, wallet (manual entry; no bank linking).
- Transactions: add/edit, categories (system + custom), tags, notes, attachments (receipts into vault storage).
- **SMS transaction capture (Android)**: parse bank debit/credit SMS locally to auto-log transactions — the killer input method in India; fully on-device parsing, no SMS content leaves the phone.
- Recurring transactions & bill reminders (rent, SIP, subscriptions) with local notifications.
- Budgets: per-category monthly budgets, progress, overspend alerts.
- Reports: monthly cash flow, category breakdown, trends; export CSV.
- Multi-currency with manual/periodic rate updates.

## Phase 2 — Splits (Splitwise-like)

**Goal:** shared expenses with friends/family, still local-first.

- Groups (trip, flat, family) and friends (from contacts, local only).
- Expense splitting: equal, exact amounts, percentages, shares; payer vs. participants.
- Balances & **debt simplification** (minimize settlement transactions).
- Settle-up recording; deep-link into UPI apps for actual payment (no money movement inside Airo Coin — records only).
- Sync strategy (the hard problem): start with **share-sheet export/import of signed group ledgers** (offline-friendly, no backend); later optional E2E-encrypted relay via airo-pro backend for real-time group sync. Reuse `core_device_merge`/`core_sessions` patterns where applicable.
- Activity feed per group, itemized bills (split by line item).

## Phase 3 — Investments

**Goal:** single view of net worth.

- Asset classes: stocks (NSE/BSE), mutual funds, FD/RD, gold, crypto, EPF/PPF/NPS, real estate (manual valuation).
- Manual holdings entry + CSV/CAS import (CAMS/KFintech consolidated account statement parsing — on-device).
- Price refresh: pluggable quote providers (opt-in network fetch for prices only; holdings never uploaded).
- Portfolio views: allocation, XIRR/absolute returns, gain/loss, dividend log.
- Goals: target-based investing (retirement, house), progress projection.
- Net worth dashboard combining Phases 1–3.

## Phase 4 — Airo Intelligence (on-device LLM)

**Goal:** natural-language finance assistant, 100% local.

- Runtime: on-device model via existing Rust core (llama.cpp/MLC-style backend in `rust/`, served over FFI) or platform APIs (Gemini Nano / Apple Intelligence) behind a capability-profile abstraction — mirrors the TV capability-profile design decision.
- **Tool calling** over local data: `query_transactions`, `get_budget_status`, `get_balances`, `get_portfolio`, `add_transaction`, `split_expense` — LLM never sees raw DB, only tool results; vault items (PAN, account numbers) are **never exposed as tools**.
- Features:
  - Ask anything: "how much did I spend on food in June?", "who owes me?"
  - Auto-categorization of transactions (SMS-parsed ones especially).
  - Receipt OCR → structured transaction (on-device vision model).
  - Monthly insight digests ("subscriptions up 18%"), anomaly flags.
  - Voice input via AiroVoice message catalog integration.
- Hardware gating: model tier by device profile (`platform_device_profile`); graceful rule-based fallback (regex categorizer, canned reports) on low-end devices.

## Phase 5 — Sync & Pro (later)

- E2E-encrypted backup/restore (user passphrase, zero-knowledge) — airo-pro entitlement.
- Multi-device sync via encrypted blobs.
- Household mode: shared budgets between family members.
- Account Aggregator (India AA framework) integration for real bank feeds — pro, opt-in, heavy compliance review.

## Explicit non-goals

- Moving money (no UPI PSP, no payments execution) — deep-link out only.
- Selling or transmitting financial data; no ads; analytics never touch finance records.
- Personalized investment advice from the LLM (informational reporting only, with disclaimer).

## Sequencing rationale

Vault first (crypto substrate) → Spending (daily engagement, data accumulation) → Splits (network effect) → Investments (depth) → LLM (differentiator, needs accumulated data to be useful) → Sync/Pro (monetization). Each phase ships independently behind the modular entrypoint; council review gates per module.yaml.
