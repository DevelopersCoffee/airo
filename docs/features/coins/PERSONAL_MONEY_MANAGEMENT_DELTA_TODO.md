# Coins Personal Money Management Delta TODO

Last updated: 2026-06-22

## Current Delta

The Coins base now has the first local-first money-management pieces in place:

- Manual Coins ledger and split workflows with budget-aware expense entry.
- Dashboard-level finance insights for current spending awareness.
- Quick-add parsing for human expense text.
- Chat-to-ledger ingestion for pasted finance SMS text.
- Chat/SMS imports now enter a local transaction review queue instead of being silently final.
- Imported transaction review supports edit, approve, reject, and duplicate marking while keeping source hash/parser/raw text metadata local for audit.
- Android SMS/notification import now has a local permission-gated service boundary and dashboard education card; imports remain disabled until explicit user action.
- OTP and authentication-style finance messages are filtered before parser ingestion.
- Agent skill plumbing so the Brain/agent chat can route tool-like requests.
- Local LLM service scaffolding for on-device extraction and private finance reasoning.
- Receipt and invoice parsing pipeline hooks for bill split and imported documents.
- Android integration coverage for chat-ingested finance SMS.

This is enough for a first private financial inbox loop: user pastes or enters financial text, the app parses it locally, stores a normalized transaction, refreshes Coins, and exposes the result in tests.

## Gap Analysis

### Data Capture

- [ ] Android SMS inbox permission flow is not implemented end-to-end; education and disabled-state service guard exist.
- [ ] Android notification listener for bank, UPI, and card alerts is not implemented; local text import boundary exists for future listeners.
- [ ] Email statement ingestion is not implemented.
- [ ] User-forwarded statement mailbox is not implemented.
- [ ] PhonePe, GPay, Paytm, and bank-export PDF/CSV imports need parser-specific fixtures.
- [ ] Credit card statement PDF summary extraction needs issuer-specific parsers.
- [ ] Account Aggregator consent and data ingestion are not implemented.

### Ledger Correctness

- [ ] Raw financial record vault is not implemented yet.
- [x] Source hashing exists for chat/SMS imports; full reparse support remains pending.
- [ ] Transaction dedupe across UPI export, card statement, and bank statement is not implemented; chat/SMS duplicate marking exists as a manual review action.
- [x] Confidence scoring and review queue are implemented for chat/SMS imports.
- [ ] Merchant alias learning is not implemented.
- [ ] Refund, reversal, failed-payment, and duplicate-charge handling needs deterministic rules.

### Liability Management

- [ ] Credit card total due, minimum due, due date, and statement-cycle storage are not implemented.
- [ ] EMI, BNPL, loan, and recurring bill liability models are not implemented.
- [ ] Upcoming liability dashboard is not implemented.
- [ ] Hidden fee, interest charge, late fee, and duplicate spend alerts are not implemented.
- [ ] Minimum-due versus full-due warning logic is not implemented.

### Privacy And Consent

- [ ] Consent ledger for permissions, imports, retention, and revocation is not implemented.
- [ ] Raw SMS/PDF/email minimization policy needs enforcement in code.
- [ ] Local encryption boundary for raw financial records needs implementation and tests.
- [ ] Redaction for account numbers, card numbers, OTPs, and personal identifiers needs centralized tests.
- [ ] Cloud sync policy for finance data must remain opt-in and encrypted before release.

### Local LLM Boundary

- [ ] LLM prompts must only receive minimized structured finance context, not raw inboxes or statements.
- [ ] Accounting math must remain deterministic; LLM output should not be source of truth.
- [ ] Local model availability, download, fallback, and performance behavior need productized UX.
- [ ] Model trace/audit output needs to show which tool or parser produced each finance update.

### Product UX

- [ ] Awareness dashboard needs today/week/month spend cards with clear budget-left numbers.
- [ ] Category breakdown needs drill-down to transactions.
- [x] Review queue is implemented for chat/SMS imported transactions.
- [x] Edit/reject/duplicate/approve flow is implemented for chat/SMS imported transactions; broader undo across all parser-ingested sources remains pending.
- [ ] First-run education is needed for broader privacy, permissions, and supported data sources; Coins dashboard now explains disabled Android SMS/notification import.
- [ ] India-first examples and copy are needed for UPI, cards, wallets, EMI, and bills.

### Testing And Release

- [ ] Add parser fixture packs for major Indian bank/card/UPI SMS patterns; initial spend/credit/OTP fixtures exist.
- [ ] Add golden fixtures for PhonePe/GPay/Paytm exports.
- [ ] Add issuer fixtures for credit card statement summaries.
- [ ] Add dedupe and reconciliation property tests.
- [ ] Add privacy redaction tests for OTPs, card numbers, account numbers, and raw message leakage.
- [ ] Add Android permission-flow integration tests once SMS/notification listeners exist.
- [ ] iOS simulator verification remains blocked by current ML Kit/LiteRT native dependency limitations on Apple Silicon iOS 26+ simulators.

## Recommended Next Milestones

### Milestone 1: Transaction Review Loop

- [ ] Add first-class `raw_financial_records` and `financial_sources` tables beyond the current local tag-backed metadata.
- [x] Store source hash, parser name, parser version, confidence, and local raw record reference for chat/SMS imports.
- [x] Add review queue UI for imported chat/SMS transactions.
- [x] Add edit/reject/duplicate/approve flow for chat-ingested transactions.
- [x] Add tests for duplicate paste prevention and manual duplicate marking.

### Milestone 2: Android SMS And Notification Import

- [x] Add permission education screen/card.
- [ ] Add sender allowlist and financial keyword filters.
- [x] Exclude OTP and authentication messages.
- [x] Add local permission-gated import boundary that writes normalized finance records into the review queue only when enabled.
- [ ] Add Android integration tests with seeded SMS/notification fixtures.

### Milestone 3: Credit Card Liability Manager

- [ ] Add statement-cycle and liability tables.
- [ ] Parse due date, total due, minimum due, statement period, fees, interest, and payments.
- [ ] Show current-month liabilities on Coins dashboard.
- [ ] Add reminders and warning states for minimum-due-only behavior.

### Milestone 4: Statement Import Inbox

- [ ] Import PDF, CSV, image, and email attachments through a local inbox.
- [ ] Build issuer/payment-app parser registry.
- [ ] Add reconciliation view for unmatched rows.
- [ ] Persist imported file metadata and source hashes locally.

### Milestone 5: Account Aggregator Path

- [ ] Select AA/TSP integration route.
- [ ] Model consent creation, renewal, revocation, and audit trail.
- [ ] Ingest deposit account data first.
- [ ] Expand to investments and liabilities only after schema/provider coverage is verified.

## Done Criteria For The Next Closeout

- [ ] `flutter analyze` passes.
- [ ] `flutter test` passes.
- [ ] Android integration test covers at least one finance ingestion path.
- [ ] No raw financial content is sent to cloud LLM APIs by default.
- [ ] No local generated artifacts or secrets are staged.
- [ ] The TODO above is updated with completed items and newly discovered gaps.
