#!/bin/bash
# G0.1 — fence-aware extraction from the specification, plus the two documented
# artifact compensations (mod.rs declaration ordering, vendored wordlist).
#
# Since #1731 the crate is COMMITTED at `rust/airo_mind`, so this script's job
# changed: it no longer bootstraps a scratch crate, it proves the committed
# source still matches the specification. Re-run it after editing either the
# plan doc or the crate — a diff means one of them drifted, and the doc is the
# reviewed artifact.
#
# Usage:
#   bash docs/superpowers/plans/extract-phase-1-vault.sh          # verify
#   bash docs/superpowers/plans/extract-phase-1-vault.sh --emit   # print outdir
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
DOC="$HERE/2026-07-27-airo-mind-phase-1-vault.md"
CRATE="$REPO/rust/airo_mind"
OUT="${TMPDIR:-/tmp}/airo-mind-g01"

rm -rf "$OUT"
mkdir -p "$OUT/src/vault"

DOC="$DOC" OUT="$OUT" CRATE="$CRATE" python3 - <<'PY'
import os, re

doc, out, crate = os.environ["DOC"], os.environ["OUT"], os.environ["CRATE"]
lines = open(doc).read().split("\n")

# Fenced ```rust blocks, keyed to the nearest `rust/airo_mind/src/....rs` path
# comment above them. A block with no such header within 40 lines is prose —
# an illustrative fragment or a must-not-compile probe — and is skipped.
blocks, i = [], 0
while i < len(lines):
    if lines[i].startswith("```rust"):
        j = i + 1
        while j < len(lines) and lines[j].rstrip() != "```":
            j += 1
        blocks.append((i, "\n".join(lines[i + 1:j])))
        i = j + 1
    else:
        i += 1

byfile = {}
for start, code in blocks:
    for k in range(start, max(0, start - 40), -1):
        m = re.search(r'`(rust/airo_mind/src/[a-z_0-9/]+\.rs)`', lines[k])
        if m:
            byfile.setdefault(m.group(1), []).append(code)
            break

for path, chunks in byfile.items():
    dest = os.path.join(out, "src", path.replace("rust/airo_mind/src/", ""))
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    open(dest, "w").write("\n\n".join(chunks) + "\n")

# ARTIFACT 1 — mod.rs is emitted once per task as an incremental "add this
# line" block, so the concatenation repeats declarations in document order.
p = os.path.join(out, "src/vault/mod.rs")
s = open(p).read()
decls = []
s = re.sub(r'^(mod [a-z_]+;|pub use [^\n]+)\n',
           lambda m: decls.append(m.group(0)) or "", s, flags=re.M)
seen = set()
mods = [d for d in decls if d.startswith("mod ") and not (d in seen or seen.add(d))]
uses = [d for d in decls if d.startswith("pub use") and not (d in seen or seen.add(d))]
docs = [l for l in s.split("\n") if l.startswith("//!")]
open(p, "w").write("\n".join(docs) + "\n\n" + "".join(sorted(mods)) + "\n" + "".join(sorted(uses)))

# ARTIFACT 2 — aggregate.rs arrives in document order, so Task 7's `mod tests`
# precedes the impl blocks Tasks 8 and 9 add. In a real file it is last.
p = os.path.join(out, "src/vault/aggregate.rs")
s = open(p).read()
i = s.find("#[cfg(test)]\nmod tests {")
if i != -1:
    depth, k = 0, s.index("{", i)
    while k < len(s):
        if s[k] == "{":
            depth += 1
        elif s[k] == "}":
            depth -= 1
            if depth == 0:
                break
        k += 1
    block = s[i:k + 1]
    open(p, "w").write((s[:i] + s[k + 1:]).rstrip() + "\n\n" + block + "\n")

# ARTIFACT 3 — the wordlist is a 2048-entry elision in the doc. Regenerate it
# from the vendored, digest-verified fixture rather than from the doc.
words = [w.strip() for w in
         open(os.path.join(crate, "tests/fixtures/bip39/english.txt")) if w.strip()]
assert len(words) == 2048, len(words)
rows = ["    " + ", ".join(f'"{w}"' for w in words[i:i + 8]) + "," for i in range(0, 2048, 8)]
p = os.path.join(out, "src/vault/wordlist.rs")
s = open(p).read()
open(p, "w").write(re.sub(r'pub static WORDS: \[&str; 2048\] = \[.*?\];',
                          "pub static WORDS: [&str; 2048] = [\n" + "\n".join(rows) + "\n];",
                          s, flags=re.S))
PY

if [ "${1:-}" = "--emit" ]; then
  echo "$OUT"
  exit 0
fi

# The committed crate is rustfmt-normalised and the doc is not, so compare
# after normalising both. rustfmt needs a package to work on.
cp "$CRATE/Cargo.toml" "$OUT/Cargo.toml"
cargo fmt --manifest-path "$OUT/Cargo.toml" >/dev/null 2>&1 || true

if diff -ru "$CRATE/src" "$OUT/src"; then
  echo "G0.1: PASS -- committed crate matches the specification"
else
  echo "G0.1: FAILED -- committed source has drifted from the plan doc" >&2
  exit 1
fi
