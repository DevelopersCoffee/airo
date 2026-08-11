# Milestone 27 — Coins On-Device Intelligence — TODO

Plan: [coins-on-device-llm-plan.md](coins-on-device-llm-plan.md) · Epic #1643

## Phase 0 (parallel, start now)
- [ ] #257 receipt OCR hardening — delegated
- [ ] #1649 detector half — delegated
- [ ] #1648 embeddings half — delegated
- [ ] #1650 datasets + mock harness — delegated, Claude reviews datasets
- [ ] #1653 design doc (Claude) → UI shells (delegated)
- [ ] Checkpoint: mocks green, baselines beaten, design approved

## Phase 1 (gated on Mind #1628/#1638)
- [ ] #1644 contract ADR (Claude) → seam impl (delegated)
- [ ] #1652 flavor wiring + entitlement gate — delegated
- [ ] Checkpoint: on-device round-trip, dual-build green, web green

## Phase 2 (one feature at a time, dogfood each)
- [ ] #1645 NL bill-split entry
- [ ] #1646 receipt LLM layer
- [ ] #1647 NL search DSL
- [ ] #1648 LLM fallback + cache
- [ ] #1649 narration layer

## Phase 3 (exit gate)
- [ ] #1650 full model-tier eval on rig
- [ ] #1651 egress + disclosure + store-claim doc (Claude)
- [ ] #1654 rig dogfood + perf budgets signed
