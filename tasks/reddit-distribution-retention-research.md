# Reddit research — distribution & retention for Airo / Airo TV / Airo Mind / Airo Coins

Date: 2026-08-15
Method: `rdt-cli` (agent-reach Reddit backend) over r/AndroidTV, r/firetvstick,
r/IPTV_Help_Desk, r/LocalLLaMA, r/LocalLLM, r/androidapps, r/personalfinance,
r/ynab, r/privacy. ~250 posts scanned, comments read on 8 high-signal threads.
Raw data: `/tmp/airo-reddit/`.

Note: r/IPTV returns `not_found` (private/banned). r/IPTV_Help_Desk is the live
support community.

---

## 1. Airo TV — the IPTV player market

### Discovery channel is proven and cheap

r/AndroidTV is an active launch channel for indie IPTV players. Observed:

| Post | Score | Comments |
|---|---|---|
| StreamVault — free, open source, no IAP, GitHub + APK (`1sf5mhi`) | 204 | 247 |
| ChannelDeck — 2 years' work, premium tier gates favorites (`1v6lc9v`) | 28 | 44 — **removed by mods** |
| Sidstuga — deep TV engineering writeup, €0.99/mo cloud sync only (`1tmctlg`) | 2 | 1 |
| POWTV (`1sztk8y`) | 2 | 10 |
| MakoMiniPlayer — "free, no ads, no accounts, no tracking" (`1tqnl5r`) | 7 | 2 |

**The pattern that separates 204 from 2 is not quality — it's shape of the offer.**
StreamVault led with: open source, completely free, no in-app purchases, works
with user-provided playlists only. ChannelDeck led with a premium tier and got
"Why would anyone use this vibe coded app", "Stop lieing. You vibe coded this",
and a Rule 8 mod removal.

### Rules that will get Airo TV removed if ignored

- **r/AndroidTV Rule 8: 10:1 self-promotion ratio.** Must participate before
  posting. ChannelDeck was removed for exactly this.
- **r/androidapps has moved all showcase posts to r/droidappshowcase** (`1q4m6ha`,
  `1rrkvcp`). Posting a launch in r/androidapps now is a removal.
- **"Vibe coded" is an active slur in these communities.** Multiple commenters
  used it as the reason to dismiss an app outright. Airo TV must lead with
  concrete engineering specifics (surface recovery, watchdog ladder, FTS EPG
  search), not feature bullet lists.

### What users say IPTV players get wrong (thread `1v2h4fl`, 19 comments)

Ranked by how often it appeared:

1. **"Everything. Tivimate is the best out there... just copy a well-established
   TV Guide from Sky, Virgin. Stop making them boxy, and panel based, with
   icons."** (25 upvotes) — users want a *cable TV guide*, not a modern app grid.
2. **Speed.** "Most of them are too slow. I really wanted to like StreamVault as
   it's open-source... but it's sluggish and clunky." Being free/open doesn't
   save you from a perf-based uninstall.
3. **Back button inconsistency.**
4. **Channel/category management**: hiding, reordering, custom groups, renaming,
   per-channel EPG assignment when EPG names don't match stream names.
5. **Text truncation** — program and channel names cut off.
6. **Multi-device sync of favorites/categories.** Repeated complaint against
   Tivimate; iMPlayer wins users specifically on cloud sync + web management.
7. **Crashes on real hardware.** StreamVault's top complaints were crashes on
   Android 16 boxes and fullscreen crashes — i.e. the free/open app still bleeds
   users to stability.

### Price sentiment

- "Charging 40 bucks for an app like tivimate is bullshit" (10 upvotes).
- "You can't really test it if you have to pay just to watch your movies and series."
- ValerieAnne84 on ChannelDeck: **favorites behind the paywall is what killed
  the trial** — "favorites seems odd, as it would mean I'm in front of the
  app/homescreen much longer than needed."

**Implication for Airo TV Pro:** navigation-essential features (favorites,
recents, hiding) must be free. Paywall sync, multiview, advanced EPG tooling.

### Live competitive gap Airo already fits

- iMPlayer **stopped supporting rooted Android boxes** — commenter says whoever
  ships remote playlist management "will have a huge opportunity" (`1v6lc9v`).
- Tivimate is single-platform with no sync; iMPlayer has sync but weak playlist
  customization and a clunky sports hub. Nobody owns *both*.
- Airo's local-first + zero-copy cast spec is differentiated, but note
  ChannelDeck's dev refused cloud sync on privacy grounds and users read that as
  a missing feature. Sidstuga's answer — E2EE sync — is the defensible position.

---

## 2. Airo Mind — on-device LLM

### r/LocalLLaMA is the channel, and it rewards depth over product

Highest engagement posts are *engineering artifacts*, not launches:

| Post | Score | Comments |
|---|---|---|
| PokeClaw — Gemma 4 autonomously driving Android, fully on-device (`1sdv3lo`) | 346 | 224 |
| "Anyone running llm on their 16GB android phone?" (`1nxqxtl`) | 17 | 49 |
| Found + fixed llama.cpp Vulkan bug on 32-bit ARM (`1sb5jmv`) | 22 | 4 |
| "Everything I learned building on-device AI into a React Native app" (`1renuky`) | 20 | 8 |
| NPU vs CPU stress test, S25 Ultra, LFM2-1.2B (`1ottfbi`) | 12 | 2 |
| Privacy-first offline mobile app launch (`1r6jhd6`) | 19 | 19 |

**Airo already owns publishable artifacts of exactly this type** and has never
published them: Metal acceleration wiring for llama/whisper (#1724), the
multilingual whisper + transcript persistence work (#1727), the model manager
disk-eviction design (#1725), and the Rust-to-Flutter build wiring (#1655) —
which per the repo is the *first* crate wired end to end. A "what it took to
ship llama.cpp + whisper through Flutter on iOS and Android" writeup is a
high-value post in this sub, and it converts to installs sideways.

### Airo Mind's exact product already exists on Reddit

Direct competitors posting in r/LocalLLM right now:

- STT + LLM real-time transcription and AI notes, fully offline (`1rvhiwx`)
- "fully local AI app for real-time transcription and live insights on mobile"
- Local-AI journaling app with reflection prompts, no accounts, no cloud (`1ox4dzp`)

None have traction (0–11 upvotes). The category is unclaimed. Airo Mind's
advantage is that it sits in a super app with three other reasons to open it.

### Retention/churn reality for on-device LLM

- Bottleneck is **RAM bandwidth**, not compute — 7 t/s for a 9B on an iPhone 15
  Pro Max (`1ttyzpi`). Users measure in tokens/sec and will benchmark you.
- Quality was the historic churn cause: "Previously when I tried using offline
  LLMs the quality of output was really poor, but with qwen3 there is a massive
  boost" (`1r6jhd6`). The window just opened; model choice is a retention
  decision, not a config detail.
- Model download is the cold-start wall. Multiple threads are people asking
  which model even fits their phone. **Airo Mind should pick the model for the
  user from device RAM/NPU detection, not present a model picker.**

---

## 3. Airo Coins — offline personal finance

### The single biggest opening found in this research

r/ynab, `1tx8296`: **752 upvotes, 370 comments**, titled around
"en-shitification". Users are actively leaving a paid budgeting app. From the
comments:

- "maintaining loyalty to a brand is a sucker's game" (169 upvotes)
- "If they start showing ads, then I'm deffo going to jump ship... I've been with
  YNAB since 2011" (96 upvotes)
- "I can't believe I have to show more to mark a transaction as cleared.
  Absolute morons on the design team" (279 upvotes)
- "I may just go back to excel" (82 upvotes)
- Users suspect added friction is an engagement KPI ahead of ads (85 upvotes)

Where they are going: **Actual Budget** (open source, self-hosted) is named
repeatedly, plus Liquid Budget. The OP switched to Actual specifically *because*
it's open source.

**This is a churn event that maps 1:1 onto Airo's open-core positioning.** The
stated reasons for leaving — ads, price increases, added friction, closed
source — are the four things Airo structurally does not do. Note the honest
caveat: Actual has no native app, only a PWA (`1vn9yur`), and requires server
setup. A polished local-first native app is the unmet need in that migration.

### The r/androidapps expense tracker market

Thread `1vn9yur` (24u/132c) — what people actually use: **Cashew** dominates
("goated", multiple 2-year users, "does everything and for free without ads").
Also named: AndroMoney, MoneyManagerEX, Paisa, Fudget, pebble, MoneySplit.

Critical detail (`1t7l78k`, 28u/14c): **Cashew's Play Store build has drifted
ahead of its GitHub releases and users noticed and are asking whether it's still
open source.** Open-source trust is actively audited in this community — which
cuts both ways for Airo's public/`airo-pro` overlay split. Be explicit about
what the overlay contains before someone else frames it.

### Demand signals repeatedly stated, unmet

1. **Free or one-time purchase, never subscription.** Stated as a hard filter in
   nearly every request thread.
2. **Local storage, no account, no data collection** — now a *headline* feature
   in indie launches (Wallez `1prona3`, BudgetHive `1pmibet`, MoneySplit).
3. **Automatic capture without cloud.** Huge unmet demand for SMS/UPI-based
   auto-logging (`1url6zm`, `1s08waz`, `1su6g5z`, `1tay08u`) with specific
   complaints about misclassification and missed SMS formats — especially Indian
   bank/UPI SMS. One commenter asserted offline auto-logging is impossible
   (`1vn9yur`). **On-device LLM SMS parsing is a direct, demonstrable rebuttal
   and is exactly the extract-don't-compute pattern from epic #1643.**
4. **Voice entry.** Qrosh (voice expense tracker) got 77u/343c on a $1 lifetime
   offer — biggest engagement in the finance set. Airo Mind's on-device ASR
   already does this; Coins + Mind is a shipped combination nobody else has.
5. **Import/migration.** YNAB leavers need to bring 12 years of history. CSV
   import is a conversion feature, not a nice-to-have.

---

## 4. Cross-cutting findings

### Discovery channels, ranked by observed evidence

1. **r/AndroidTV launch post** — proven 200+ upvote ceiling for a free,
   open-source, TV-first IPTV player. Highest-yield single action available.
   Requires 10:1 participation ratio first.
2. **r/LocalLLaMA engineering writeup** — 20–350 upvote range for genuine
   on-device work. Airo has unpublished material that qualifies today.
3. **r/ynab / budgeting migration threads** — a live, self-organizing audience
   asking for alternatives. Participation, not promotion.
4. **r/droidappshowcase** — the sanctioned showcase venue now that r/androidapps
   rejects launches. Lower reach, zero removal risk.
5. **Promo-code giveaways** — reliably generate 90–343 comments (`1ner0nt`,
   `1or5jjt`, `1ngiov1`, `1n2kl9c`). High volume, unknown retention quality;
   cheap to test since Airo Pro is free at launch anyway.

### Retention/churn causes observed, ranked

| Cause | Evidence |
|---|---|
| Perf/sluggishness | StreamVault dismissed despite being free + open source |
| Crashes on real hardware | Top comments on every TV launch thread |
| Essential feature behind paywall | ChannelDeck favorites — trial abandoned |
| Added friction / ads in a paid app | YNAB, 752 upvotes |
| Abandonment by dev | "developers have vanished, last updated 2023" (`1utjowd`) |
| No cross-device sync | Tivimate's most-cited weakness |
| Cold-start wall | Model choice paralysis (Mind), setup burden (Actual Budget) |

**"Developers have vanished" is a churn cause Airo can convert into a moat.**
Users in r/IPTV_Help_Desk explicitly fear buying into abandoned apps. A public
repo with visible commit activity is proof of life no closed competitor can
offer. Say so directly.

---

## 5. Recommended actions

**Do first (highest evidence-to-effort):**

1. Make Airo TV favorites/recents/category-hiding permanently free. Move Pro to
   E2EE sync + multiview + advanced EPG. Directly de-risks the ChannelDeck
   failure mode.
2. Ship the cable-style EPG grid as the default surface, not a panel/card home.
   The single most-upvoted UX opinion in the category.
3. Build the on-device LLM SMS/UPI expense parser for Coins. Unmet demand,
   widely believed impossible, and Airo's existing architecture makes it a
   demonstrable claim.
4. Publish the llama.cpp + whisper through Flutter writeup to r/LocalLLaMA. Zero
   new engineering; the work is already merged.
5. CSV import + YNAB/Actual migration path in Coins, before any r/ynab
   participation.

**Do before any launch post:**

6. Build participation history in r/AndroidTV and r/LocalLLaMA. Rule 8 is
   enforced.
7. Prepare an explicit, public statement of what `airo-pro` contains vs the
   public repo. The Cashew thread proves this community audits it.

**Measure:**

8. Time-to-first-value in all four apps. Every churn cause above compounds on
   cold-start friction, and Airo has three separate cold-start walls (playlist,
   model download, data import).
