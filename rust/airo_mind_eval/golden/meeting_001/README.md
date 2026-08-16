# meeting_001 golden set

Hand-authored transcript, IR, and MoM for a small multilingual (Hindi +
English) standup-style meeting. Used by `airo_mind_eval --meeting meeting_001`
and by `airo_mind_cli --golden-meeting meeting_001`.

This fixture is **domain-agnostic** — it exercises the pipeline shape (WER,
term accuracy, IR/MoM consistency) without encoding a specific customer meeting.

## Optional local audio (not in repo)

For real ASR runs, symlink or copy any Apple Voice Memo / `.m4a` export:

```sh
ln -sf /path/to/your/recording.m4a rust/fixtures/meeting_001.m4a
```

Or pass the file path as the first CLI argument. The hand-authored
`transcript.json` is the reference for eval gates; whisper output on unrelated
audio will fail WER until you align goldens with a real pass or use
`--skip-eval`.

```sh
cd rust
cargo run -p airo_mind_cli -- /path/to/your/recording.m4a \
  --models-dir models \
  --out ./out/meeting_001/ \
  --golden-meeting meeting_001
```

Preprocess-only smoke (no models):

```sh
cargo test -p airo_mind_audio --test meeting_001_m4a
```
