#!/bin/bash
# G0.1 — fence-aware extraction from the specification, plus the two
# documented artifact compensations (mod.rs ordering, vendored wordlist).
set -e
SP=/private/tmp/claude-501/-Users-udaychauhan-workspace-airo/e1fc7091-9136-4c43-b3e5-8187b71864a4/scratchpad
cd /Users/udaychauhan/workspace/airo/.claude/worktrees/airo-mind
rm -rf "$SP/rev7/src/vault"; mkdir -p "$SP/rev7/src/vault"
python3 - <<'PY'
import re, os
lines=open("docs/superpowers/plans/2026-07-27-airo-mind-phase-1-vault.md").read().split("\n")
SP="/private/tmp/claude-501/-Users-udaychauhan-workspace-airo/e1fc7091-9136-4c43-b3e5-8187b71864a4/scratchpad/rev7"
blocks=[]; i=0
while i<len(lines):
    if lines[i].startswith("```rust"):
        j=i+1
        while j<len(lines) and lines[j].rstrip()!="```": j+=1
        blocks.append((i,"\n".join(lines[i+1:j]))); i=j+1
    else: i+=1
byfile={}
for start,code in blocks:
    path=None
    for k in range(start,max(0,start-40),-1):
        m=re.search(r'`(rust/airo_mind/src/[a-z_/]+\.rs)`',lines[k])
        if m: path=m.group(1); break
    if path: byfile.setdefault(path,[]).append(code)
for path,chunks in byfile.items():
    rel=path.replace("rust/airo_mind/src/","")
    d=os.path.join(SP,"src",rel); os.makedirs(os.path.dirname(d),exist_ok=True)
    open(d,"w").write("\n\n".join(chunks))
# artifact 1: hoist mod.rs declarations + doc comments
p=SP+"/src/vault/mod.rs"; s=open(p).read(); decls=[]
s=re.sub(r'^(mod [a-z_]+;|pub use [^\n]+)\n', lambda m: decls.append(m.group(0)) or "", s, flags=re.M)
seen=set(); ordered=[d for d in decls if not (d in seen or seen.add(d))]
L=s.split("\n"); docs=[l for l in L if l.startswith("//!")]; rest=[l for l in L if not l.startswith("//!")]
open(p,"w").write("\n".join(docs)+"\n\n"+"".join(ordered)+"\n"+"\n".join(rest))
# artifact 3: aggregate.rs is many blocks in document order, so Task 7's
# `mod tests` precedes Task 8/9's impl blocks. In the real file it is last.
p=SP+"/src/vault/aggregate.rs"; s=open(p).read()
i=s.find("#[cfg(test)]\nmod tests {")
if i!=-1:
    depth=0; j=s.index("{", i)
    k=j
    while k < len(s):
        if s[k]=="{": depth+=1
        elif s[k]=="}":
            depth-=1
            if depth==0: break
        k+=1
    block=s[i:k+1]
    s=(s[:i]+s[k+1:]).rstrip()+"\n\n"+block+"\n"
    open(p,"w").write(s)

# artifact 2: vendored wordlist
w=[x.strip() for x in open(SP+"/tests/fixtures/bip39/english.txt") if x.strip()]
rows=["    "+", ".join(f'"{x}"' for x in w[i:i+8])+"," for i in range(0,2048,8)]
p=SP+"/src/vault/wordlist.rs"; s=open(p).read()
s=re.sub(r'pub static WORDS: \[&str; 2048\] = \[.*?\];',"pub static WORDS: [&str; 2048] = [\n"+"\n".join(rows)+"\n];",s,flags=re.S)
open(p,"w").write(s)
PY
