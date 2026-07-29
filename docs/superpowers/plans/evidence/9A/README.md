# Revision 9A — first-execution evidence

**These files are immutable once written, and this directory is append-only.**
They hold raw, unedited output from each execution of a Revision 9A gate.
Nothing here is reformatted, trimmed, re-run in place, or corrected.

Append-only means a second execution never overwrites the first:
`g0.7-first.txt`, then `g0.7-second.txt`, then `g0.7-third.txt`. The summary may
point at whichever run is most relevant; the raw captures accumulate as a
chronological log and are never displaced.

The three tiers, in order of mutability:

| | Mutability |
|---|---|
| Interpretations and verdicts | may be revised freely |
| Summary documents | may be revised, must cite a capture |
| **Raw captures** | **accumulate only** |

A rerun that replaces its predecessor destroys the one thing that makes a later
green run meaningful.

Interpretation lives in `../../g0-first-execution.md`, which references these
files rather than embedding excerpts of them. That separation is deliberate:

- raw output stays untouched, so it remains checkable
- summaries may evolve as understanding does
- a reviewer can compare any later claim against exactly what the gate produced

## Why the raw output matters more than the summary

Revision 9A's gates were written against an implementation that Rust
Architecture and Chief Security Officer had already **rejected**, so they are
expected to fail. After Revision 9B repairs the implementation they will pass.

At that point the only thing distinguishing *"the gate works and the code was
fixed"* from *"the gate was adjusted until it agreed with the code"* is a
preserved record of the gate failing, in its original wording, against code
independently verified to violate it.

A summary can be revised. A committed raw capture cannot be revised without the
revision being visible.

## Expected contents

| File | Holds |
|---|---|
| `g0.7-first.txt` | claim assertions, first run |
| `g0.8-first.txt` | external-consumer probe, first run |
| `g0.3-g0.5-first.txt` | check / test / clippy after the 9A test additions |
| `mut-real.txt` | the four `mut_*` tests against the unmodified crate |
| `mut-frame-aad.txt` | mutant: header AAD removed from every frame |
| `mut-trailer-aad.txt` | mutant: header AAD removed from the trailer |
| `mut-nonce-pinning.txt` | mutant: `frame_nonce` collapsed to a constant |
| `mut-position.txt` | mutant: `frame.index == position` removed |
| `truncation-path-correct.txt` | the path-correct test, un-ignored once |

## Status

**Empty.** No gate has been executed. `Bash` is unavailable, so no evidence
exists yet; the directory and its contract were created first so that the
structure could not be shaped by the outcome it records.
