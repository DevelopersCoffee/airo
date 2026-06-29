# Search Edge Cases Validation

Use this runbook for issue `#517` and for release candidates that touch local
meeting search, indexing, or search result presentation.

## Deterministic Local Checks

Run the Meeting Intelligence search edge-case suite:

```bash
make test-search-edge-cases
```

Current automated coverage proves:

- project/title terms remain searchable
- speaker labels are indexed for lookup
- simple single-edit misspellings still match relevant meetings
- common meeting-term synonyms such as `plan` and `roadmap` match
- mixed-language content with diacritics remains searchable after normalization
- larger repositories keep deterministic recency ordering and bounded results

## Manual Validation Matrix

The following still require manual validation because they depend on real
meeting data quality, user expectations, or UI behavior:

| Area | What to verify | Preferred environment |
| --- | --- | --- |
| Speaker search | Real diarization labels surface expected meeting hits | Seeded local meeting corpus |
| Project search | Project names from titles and summaries are discoverable in UI | Seeded local meeting corpus |
| Mixed-language meetings | Hindi/English or other bilingual transcripts remain discoverable in UI | Representative local transcripts |
| Very large datasets | Search latency and scrolling remain acceptable with many meetings | Larger seeded local dataset |
| Result snippets | Snippets shown in UI are useful and redacted | Manual QA in app |

## Suggested Local Flow

1. Run `make test-search-edge-cases`.
2. Seed the app with representative local meeting drafts or fixtures.
3. Search by:
   - project/title term
   - speaker name
   - a one-character typo
   - a mixed-language query
4. Confirm the result order remains stable and redacted snippets stay redacted.

## Release Rule

Do not mark search edge-case validation complete until:

1. `make test-search-edge-cases` passes.
2. The relevant manual matrix items have been exercised against the release candidate.
3. Any skipped high-volume or mixed-language validation is explicitly waived in the PR or release notes.
