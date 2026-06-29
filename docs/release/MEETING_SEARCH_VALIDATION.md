# Meeting Search Validation

Deterministic validation runbook for issue `#517`.

This runbook covers the local in-memory meeting search contract used by the
Meeting Intelligence slice:

- title/project lookup
- speaker-label lookup
- typo-tolerant search for representative terms
- synonym-based lookup for representative meeting concepts
- mixed-language token search
- deterministic ordering under larger repositories

## Automated Checks

Run the validation command from the repository root:

```sh
make test-meeting-search
```

This command currently executes:

- `app/test/features/meeting/meeting_intelligence_local_slice_test.dart`

Automated assertions now cover:

- redacted values are not searchable
- misspelled query recovery for representative terms like `budjet -> budget`
- speaker lookup using transcript speaker labels
- project/title lookup using saved meeting titles
- representative synonym lookup (`finance -> budget`)
- mixed-language searchable tokens
- deterministic ranking across larger repositories

## Acceptance

The automated slice passes when:

- the command succeeds with no failing tests
- representative typo, synonym, speaker, and title queries return the expected meeting
- larger repositories return results in stable deterministic order across repeated runs

## Manual Follow-Up

If the repository implementation changes beyond the in-memory slice, re-run this
command and add additional device or persistence checks only if a non-memory
repository/search index is introduced later.
