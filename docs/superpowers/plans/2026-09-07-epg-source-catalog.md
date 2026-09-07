# EPG Source Catalog + Guide Picker + Viewer Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Widen the R2 EPG pipeline beyond `epg.pw`, replace the raw-URL-paste-only guide source UI with a browsable catalog, and add favorites/category filtering to the Guide's shared header.

**Architecture:** Three independent slices. (M1) `iptv-data`'s Python pipeline fetches two more static XMLTV mirrors (`iptv-epg.org`, `epgshare01.online`) alongside the existing `epg.pw` fetch in `iptv_guide_r2.yml`, remaps every candidate onto catalog ids with the existing `epg_pw_remap` module, picks the best-covered one per country, and publishes it under the unchanged `guide_XX.xml.gz` key plus a new `epg_catalog.json` side-file. (M2) `feature_iptv` gains a small provider that reads that catalog and a "Browse guides" list in `XmltvSourceSheet`, calling the already-shipped `refreshSystemGuidesForCountries`. (M3) `guide_providers.dart` gains two guide-local filter providers (favorites-only, category) composed into the existing `guideFilteredChannelsProvider`, surfaced as chips in `iptv_guide_screen.dart`'s one shared header (used by both the TV and touch grids).

**Tech Stack:** Python 3.11 + pytest (iptv-data), Dart/Flutter + Riverpod + flutter_test (feature_iptv), GitHub Actions (bash + embedded Python).

**Spec:** [docs/superpowers/specs/2026-09-07-epg-source-catalog-design.md](../specs/2026-09-07-epg-source-catalog-design.md)

## Global Constraints

- Never fetch epgshare01's `ALL_SOURCES` file or any full-catalog dump (~205MB) — same rule as the existing `guide_ALL` device-fetch ban.
- Both new sources are fetched using the exact same plain two-letter country code the pipeline already uses for `epg.pw` (the workflow's `$COUNTRY`) — no crawling a source's own directory listing, no new allow-list config file.
- A single source's fetch/remap failure must never fail the whole `iptv_guide_r2.yml` job — soft-fail per source, same posture as the existing "missing ffprobe → unchecked" policy elsewhere in this pipeline.
- Do not touch `select_countries_to_publish` or `iptv_sanity.yml` — that is a separate, heavier pipeline with its own regression-guard semantics.
- BYOC (paste-your-own XMLTV URL) in `XmltvSourceSheet` must keep working unchanged; it becomes an "Advanced: custom URL" section, never removed.
- Do not build a second favorites store or a second category-filter store — reuse `favoriteChannelIdsProvider` (`iptv_providers.dart`) and `channelCategoryLabels`/`categoryFilterKey` (`channel_filters_provider.dart`).
- Guide's search/category state stays independent of the main browse screen's `channelFiltersProvider` (see the existing doc comment on `applyChannelScope`) — new Guide filters are new, Guide-scoped providers, not writes into `channelFiltersProvider`.
- No new CI matrix entries; `iptv_guide_r2.yml` keeps its 20-minute job timeout.

---

## Task 1: N-way source scoring + catalog writer (`iptv-data`)

**Files:**
- Modify: `iptv-data/src/epg_publish_prefer.py`
- Test: `iptv-data/tests/test_epg_publish_prefer.py`

**Interfaces:**
- Produces: `channel_count(xml_bytes: bytes) -> int`, `select_best_sources(*, source_dirs: dict[str, Path], output_dir: Path, generated_at: str) -> list[dict[str, object]]` (each dict: `countryCode: str`, `sourceId: str`, `programmeCount: int`, `channelCount: int`, `updatedAt: str`), plus a new `select-best-source` CLI subcommand (`--source NAME=DIR`, repeatable; `--output-dir`; `--catalog-path`; `--generated-at`). Consumed by Task 2's workflow step.

- [ ] **Step 1: Write the failing tests**

Add to `iptv-data/tests/test_epg_publish_prefer.py` (uses the existing `_xml`/`_XML_TEMPLATE`/`_PROGRAMME` helpers already in that file):

```python
from src.epg_publish_prefer import channel_count, select_best_sources


def test_channel_count() -> None:
    assert channel_count(_xml("in", 3)) == 1  # _XML_TEMPLATE emits one <channel>


def test_select_best_sources_picks_highest_programme_count(tmp_path: Path) -> None:
    epg_pw = tmp_path / "epg_pw"
    epg_pw.mkdir()
    (epg_pw / "IN.xml").write_bytes(_xml("in", 2))
    other = tmp_path / "other_source"
    other.mkdir()
    (other / "IN.xml").write_bytes(_xml("in", 5))
    output_dir = tmp_path / "best"

    catalog = select_best_sources(
        source_dirs={"epg_pw": epg_pw, "other_source": other},
        output_dir=output_dir,
        generated_at="2026-09-07T00:00:00Z",
    )

    assert catalog == [
        {
            "countryCode": "IN",
            "sourceId": "other_source",
            "programmeCount": 5,
            "channelCount": 1,
            "updatedAt": "2026-09-07T00:00:00Z",
        }
    ]
    assert (output_dir / "IN.xml").read_bytes() == _xml("in", 5)


def test_select_best_sources_country_present_in_only_one_source(
    tmp_path: Path,
) -> None:
    epg_pw = tmp_path / "epg_pw"
    epg_pw.mkdir()
    (epg_pw / "GB.xml").write_bytes(_xml("gb", 1))
    other = tmp_path / "other_source"
    other.mkdir()
    output_dir = tmp_path / "best"

    catalog = select_best_sources(
        source_dirs={"epg_pw": epg_pw, "other_source": other},
        output_dir=output_dir,
        generated_at="2026-09-07T00:00:00Z",
    )

    assert [entry["countryCode"] for entry in catalog] == ["GB"]
    assert catalog[0]["sourceId"] == "epg_pw"


def test_select_best_sources_skips_empty_and_missing_directories(
    tmp_path: Path,
) -> None:
    epg_pw = tmp_path / "epg_pw"
    epg_pw.mkdir()
    (epg_pw / "QA.xml").write_bytes(_xml("qa", 0))  # zero programmes
    missing = tmp_path / "does_not_exist"  # never created -- fetch was skipped
    output_dir = tmp_path / "best"

    catalog = select_best_sources(
        source_dirs={"epg_pw": epg_pw, "missing_source": missing},
        output_dir=output_dir,
        generated_at="2026-09-07T00:00:00Z",
    )

    assert catalog == []
    assert not (output_dir / "QA.xml").exists()


def test_select_best_sources_ignores_all_xml(tmp_path: Path) -> None:
    epg_pw = tmp_path / "epg_pw"
    epg_pw.mkdir()
    (epg_pw / "IN.xml").write_bytes(_xml("in", 1))
    (epg_pw / "ALL.xml").write_bytes(_xml("in", 1))
    output_dir = tmp_path / "best"

    catalog = select_best_sources(
        source_dirs={"epg_pw": epg_pw},
        output_dir=output_dir,
        generated_at="2026-09-07T00:00:00Z",
    )

    assert [entry["countryCode"] for entry in catalog] == ["IN"]
    assert not (output_dir / "ALL.xml").exists()
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd iptv-data && python -m pytest tests/test_epg_publish_prefer.py -v -k "channel_count or select_best_sources"`
Expected: FAIL with `ImportError: cannot import name 'channel_count'` (and `select_best_sources`).

- [ ] **Step 3: Implement `channel_count` and `select_best_sources`**

In `iptv-data/src/epg_publish_prefer.py`, add after the existing `programme_count_in_gzip` function:

```python
def channel_count(xml_bytes: bytes) -> int:
    """Number of `<channel>` elements in an (uncompressed) XMLTV payload."""
    return len(ET.fromstring(xml_bytes).findall("channel"))


def select_best_sources(
    *,
    source_dirs: dict[str, Path],
    output_dir: Path,
    generated_at: str,
) -> list[dict[str, object]]:
    """For every country present in at least one of `source_dirs` (each a
    directory of already-catalog-id-remapped `<CC>.xml` files -- run
    through `epg_pw_remap.remap_epg_pw_xmltv` first, one directory per
    source, `ALL.xml` ignored), copy the file from whichever source has
    the most `<programme>` elements into `output_dir/<CC>.xml`, and return
    one catalog entry per selected country, sorted by country code. A
    directory that doesn't exist (that source's fetch step was skipped, or
    it 404'd) contributes no candidates, never an error.

    A country present in only one source directory always wins once it has
    at least one programme -- there is no other candidate to lose to.
    `iptv_guide_r2.yml` (the caller) has never guarded against regressing a
    previously-published guide (unlike `select_countries_to_publish`, which
    does, for the unrelated `iptv_sanity.yml` pipeline), so this function
    doesn't either: every run republishes unconditionally.
    """
    countries: set[str] = set()
    for directory in source_dirs.values():
        if not directory.is_dir():
            continue
        countries.update(
            path.stem for path in directory.glob("*.xml") if path.stem != "ALL"
        )

    output_dir.mkdir(parents=True, exist_ok=True)
    catalog: list[dict[str, object]] = []
    for country in sorted(countries):
        scored: list[tuple[int, str, Path]] = []
        for source_id, directory in source_dirs.items():
            candidate = directory / f"{country}.xml"
            count = programme_count_in_file(candidate)
            if count > 0:
                scored.append((count, source_id, candidate))
        if not scored:
            continue
        scored.sort(key=lambda item: (item[0], item[1]))
        programme_count, source_id, winning_path = scored[-1]
        xml_bytes = winning_path.read_bytes()
        (output_dir / f"{country}.xml").write_bytes(xml_bytes)
        catalog.append(
            {
                "countryCode": country,
                "sourceId": source_id,
                "programmeCount": programme_count,
                "channelCount": channel_count(xml_bytes),
                "updatedAt": generated_at,
            }
        )
    return catalog
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd iptv-data && python -m pytest tests/test_epg_publish_prefer.py -v`
Expected: PASS (all tests in the file, old and new).

- [ ] **Step 5: Add the `select-best-source` CLI subcommand**

In `iptv-data/src/epg_publish_prefer.py`'s `main()`, after the existing `publish_all` subparser block (before `args = parser.parse_args()`):

```python
    select_best = subparsers.add_parser(
        "select-best-source",
        help=(
            "Pick the best-covered source per country across --source "
            "directories, write the winners as plain <CC>.xml files into "
            "--output-dir, and write --catalog-path as JSON."
        ),
    )
    select_best.add_argument(
        "--source",
        action="append",
        required=True,
        metavar="NAME=DIR",
        help="Repeatable. A source id and its remapped-xml directory.",
    )
    select_best.add_argument("--output-dir", type=Path, required=True)
    select_best.add_argument("--catalog-path", type=Path, required=True)
    select_best.add_argument("--generated-at", required=True)
```

Then change the dispatch at the bottom of `main()` from:

```python
    args = parser.parse_args()
    if args.command == "select-countries":
        selected = select_countries_to_publish(
            remap_dir=args.remap_dir,
            published_directory=args.published_directory,
            prefer_existing_over_remap=tuple(args.prefer_existing),
        )
        for country in selected:
            print(country)
    else:
        checksum = publish_all_guide(
            all_xml_bytes=args.all_xml.read_bytes(),
            output_directory=args.output_directory,
            manifest_path=args.manifest,
        )
        print(checksum)
```

to:

```python
    args = parser.parse_args()
    if args.command == "select-countries":
        selected = select_countries_to_publish(
            remap_dir=args.remap_dir,
            published_directory=args.published_directory,
            prefer_existing_over_remap=tuple(args.prefer_existing),
        )
        for country in selected:
            print(country)
    elif args.command == "select-best-source":
        source_dirs: dict[str, Path] = {}
        for item in args.source:
            name, _, directory = item.partition("=")
            if not name or not directory:
                parser.error(f"--source must be NAME=DIR, got: {item}")
            source_dirs[name] = Path(directory)
        catalog = select_best_sources(
            source_dirs=source_dirs,
            output_dir=args.output_dir,
            generated_at=args.generated_at,
        )
        args.catalog_path.parent.mkdir(parents=True, exist_ok=True)
        args.catalog_path.write_text(
            json.dumps(catalog, indent=2) + "\n", encoding="utf-8"
        )
        for entry in catalog:
            print(entry["countryCode"])
    else:
        checksum = publish_all_guide(
            all_xml_bytes=args.all_xml.read_bytes(),
            output_directory=args.output_directory,
            manifest_path=args.manifest,
        )
        print(checksum)
```

- [ ] **Step 6: Manually verify the CLI subcommand**

Run:
```bash
cd iptv-data
mkdir -p /tmp/epg_cli_check/epg_pw /tmp/epg_cli_check/other
printf '<tv><channel id="Chan.in"><display-name>Chan</display-name></channel><programme channel="Chan.in" start="20260902090000 +0000" stop="20260902100000 +0000"><title>P0</title></programme></tv>' > /tmp/epg_cli_check/epg_pw/IN.xml
printf '<tv><channel id="Chan.in"><display-name>Chan</display-name></channel><programme channel="Chan.in" start="20260902090000 +0000" stop="20260902100000 +0000"><title>P0</title></programme><programme channel="Chan.in" start="20260902100000 +0000" stop="20260902110000 +0000"><title>P1</title></programme></tv>' > /tmp/epg_cli_check/other/IN.xml
python -m src.epg_publish_prefer select-best-source \
  --source epg_pw=/tmp/epg_cli_check/epg_pw \
  --source other=/tmp/epg_cli_check/other \
  --output-dir /tmp/epg_cli_check/best \
  --catalog-path /tmp/epg_cli_check/best/epg_catalog.json \
  --generated-at "2026-09-07T00:00:00Z"
cat /tmp/epg_cli_check/best/epg_catalog.json
rm -rf /tmp/epg_cli_check
```
Expected: prints `IN`, and the catalog JSON shows `"sourceId": "other"` (2 programmes beats 1).

- [ ] **Step 7: Commit**

```bash
cd iptv-data
git add src/epg_publish_prefer.py tests/test_epg_publish_prefer.py
git commit -m "feat(epg): add N-way per-country source scoring and catalog writer

select_best_sources() picks the best-covered candidate per country
across an arbitrary number of already-remapped source directories and
writes a JSON catalog alongside the winners, for the upcoming
iptv-epg.org/epgshare01 mirrors in iptv_guide_r2.yml. Does not touch
select_countries_to_publish, which belongs to the separate
iptv_sanity.yml pipeline.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 2: Wire the two new sources + catalog into `iptv_guide_r2.yml`

**Files:**
- Modify: `.github/workflows/iptv_guide_r2.yml` (full rewrite of the job body from "Fetch country XMLTV pack..." onward)

**Interfaces:**
- Consumes: `python -m src.epg_pw_remap --input <xml> --iptv-org-channels <json> --output-dir <dir>` (non-gzip mode, existing CLI), `python -m src.epg_publish_prefer select-best-source ...` (Task 1), `write_gzip_guides` from `src/epg_pw_remap.py` (existing).
- Produces: `output/r2/guide_$COUNTRY.xml.gz` + `output/r2/manifest.json` (unchanged shape — Task 3/M2 does not depend on these), `output/best/epg_catalog.json` uploaded to R2 as `iptv-data/epg_catalog.json` (Task 3 depends on this).

- [ ] **Step 1: Replace the workflow body**

Replace `.github/workflows/iptv_guide_r2.yml` in full with:

```yaml
name: IPTV country guide to R2

# Cheap product-default EPG publish. Fetches one country's guide from up to
# three static mirrors (epg.pw, iptv-epg.org, epgshare01.online), remaps
# each onto iptv-org catalog ids, keeps whichever has the most programmes,
# and uploads only guide_XX.xml.gz + manifest.json + epg_catalog.json.
# Never fetches a source's global/ALL export, and never uploads a
# playlist/M3U.

on:
  schedule:
    - cron: '41 3 * * *'
  workflow_dispatch:
    inputs:
      country:
        description: 'ISO country code for the guide mirrors'
        required: false
        default: 'IN'

permissions:
  contents: read

env:
  PYTHON_VERSION: '3.11'
  COUNTRY: ${{ github.event.inputs.country || 'IN' }}

jobs:
  publish:
    name: Publish guide shard
    runs-on: ubuntu-latest
    timeout-minutes: 20
    defaults:
      run:
        working-directory: iptv-data
    steps:
      - name: Checkout repository
        uses: actions/checkout@v7

      - name: Set up Python
        uses: actions/setup-python@v7
        with:
          python-version: ${{ env.PYTHON_VERSION }}

      - name: Normalize country
        id: country
        working-directory: .
        run: |
          set -euo pipefail
          COUNTRY="$(printf '%s' "${{ env.COUNTRY }}" | tr '[:lower:]' '[:upper:]')"
          if [[ ! "$COUNTRY" =~ ^[A-Z]{2}$ ]]; then
            echo "::error::Country must be a two-letter ISO code, got: ${COUNTRY}"
            exit 1
          fi
          echo "code=$COUNTRY" >> "$GITHUB_OUTPUT"

      - name: Fetch iptv-org catalog
        run: |
          set -euo pipefail
          mkdir -p /tmp/guide-r2
          curl --fail --location --retry 3 --max-time 120 \
            https://iptv-org.github.io/api/channels.json \
            --output /tmp/guide-r2/channels.json

      - name: Fetch and remap epg.pw guide
        env:
          COUNTRY: ${{ steps.country.outputs.code }}
        run: |
          set -euo pipefail
          curl --fail --location --retry 3 --max-time 120 \
            "https://epg.pw/xmltv/epg_${COUNTRY}.xml.gz" \
            --output "/tmp/guide-r2/epg_pw_${COUNTRY}.xml.gz"
          gunzip -c "/tmp/guide-r2/epg_pw_${COUNTRY}.xml.gz" > "/tmp/guide-r2/epg_pw_${COUNTRY}.xml"
          python -m src.epg_pw_remap \
            --input "/tmp/guide-r2/epg_pw_${COUNTRY}.xml" \
            --iptv-org-channels /tmp/guide-r2/channels.json \
            --output-dir output/remap_epg_pw

      - name: Fetch and remap iptv-epg.org guide (best-effort)
        id: fetch_iptv_epg_org
        env:
          COUNTRY: ${{ steps.country.outputs.code }}
        run: |
          set -euo pipefail
          LOWER="$(printf '%s' "$COUNTRY" | tr '[:upper:]' '[:lower:]')"
          if curl --fail --location --retry 2 --max-time 60 \
               "https://iptv-epg.org/files/epg-${LOWER}.xml" \
               --output "/tmp/guide-r2/iptv_epg_org_${COUNTRY}.xml"; then
            python -m src.epg_pw_remap \
              --input "/tmp/guide-r2/iptv_epg_org_${COUNTRY}.xml" \
              --iptv-org-channels /tmp/guide-r2/channels.json \
              --output-dir output/remap_iptv_epg_org
          else
            echo "iptv-epg.org has no guide for ${COUNTRY} -- skipping this source."
          fi

      - name: Fetch and remap epgshare01 guide (best-effort)
        id: fetch_epgshare01
        env:
          COUNTRY: ${{ steps.country.outputs.code }}
        run: |
          set -euo pipefail
          if curl --fail --location --retry 2 --max-time 60 \
               "https://epgshare01.online/epgshare01/epg_ripper_${COUNTRY}1.xml.gz" \
               --output "/tmp/guide-r2/epgshare01_${COUNTRY}.xml.gz"; then
            gunzip -c "/tmp/guide-r2/epgshare01_${COUNTRY}.xml.gz" > "/tmp/guide-r2/epgshare01_${COUNTRY}.xml"
            python -m src.epg_pw_remap \
              --input "/tmp/guide-r2/epgshare01_${COUNTRY}.xml" \
              --iptv-org-channels /tmp/guide-r2/channels.json \
              --output-dir output/remap_epgshare01
          else
            echo "epgshare01 has no guide for ${COUNTRY} -- skipping this source."
          fi

      - name: Pick best source per country and build catalog
        env:
          COUNTRY: ${{ steps.country.outputs.code }}
        run: |
          set -euo pipefail
          rm -rf output/best output/r2
          python -m src.epg_publish_prefer select-best-source \
            --source "epg_pw=output/remap_epg_pw" \
            --source "iptv_epg_org=output/remap_iptv_epg_org" \
            --source "epgshare01=output/remap_epgshare01" \
            --output-dir output/best \
            --catalog-path output/best/epg_catalog.json \
            --generated-at "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
          if [ ! -f "output/best/${COUNTRY}.xml" ]; then
            echo "::error::No source produced a guide for ${COUNTRY}"
            exit 1
          fi

      - name: Gzip winning source and write manifest
        env:
          COUNTRY: ${{ steps.country.outputs.code }}
        run: |
          set -euo pipefail
          python - <<'PY'
          import json
          import os
          from pathlib import Path
          from src.epg_pw_remap import write_gzip_guides

          country = os.environ["COUNTRY"]
          xml_bytes = (Path("output/best") / f"{country}.xml").read_bytes()
          output_dir = Path("output/r2")
          checksums = write_gzip_guides({country: xml_bytes}, output_dir)
          manifest = {
              "files": {key: f"{key}.xml.gz" for key in checksums},
              "fileChecksums": checksums,
          }
          (output_dir / "manifest.json").write_text(
              json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
          )
          PY

      - name: Verify remapped shard
        env:
          COUNTRY: ${{ steps.country.outputs.code }}
        run: |
          set -euo pipefail
          python - <<'PY'
          import gzip
          import json
          import os
          from pathlib import Path

          country = os.environ["COUNTRY"]
          output = Path("output/r2")
          key = f"guide_{country}"
          manifest = json.loads((output / "manifest.json").read_text(encoding="utf-8"))
          filename = manifest["files"][key]
          checksum = manifest["fileChecksums"][key]
          raw = (output / filename).read_bytes()
          import hashlib
          actual = hashlib.sha256(raw).hexdigest()
          if actual != checksum:
              raise SystemExit(f"checksum mismatch for {filename}")
          xml = gzip.decompress(raw)
          from xml.etree import ElementTree as ET
          root = ET.fromstring(xml)
          leaked = [
              value
              for value in (
                  [el.get("id") or "" for el in root.findall("channel")]
                  + [el.get("channel") or "" for el in root.findall("programme")]
              )
              if value.isdigit()
          ]
          if leaked:
              raise SystemExit(
                  "raw numeric id leaked into published XMLTV: "
                  + ", ".join(sorted(set(leaked))[:8])
              )
          print(f"{filename} bytes={len(raw)} sha256={checksum}")
          PY

      - name: Upload guide shards and catalog to Cloudflare R2
        env:
          CLOUDFLARE_ACCOUNT_ID: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          AWS_ACCESS_KEY_ID: ${{ secrets.CLOUDFLARE_R2_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.CLOUDFLARE_R2_SECRET_ACCESS_KEY }}
          CLOUDFLARE_R2_BUCKET: ${{ secrets.CLOUDFLARE_R2_BUCKET }}
        run: |
          set -euo pipefail
          if [ -z "${CLOUDFLARE_ACCOUNT_ID:-}" ] || [ -z "${AWS_ACCESS_KEY_ID:-}" ] || \
             [ -z "${AWS_SECRET_ACCESS_KEY:-}" ] || [ -z "${CLOUDFLARE_R2_BUCKET:-}" ]; then
            echo "CLOUDFLARE_R2_* secrets are not configured -- skipping the R2 upload."
            echo "output/r2/ and output/best/ are still available from the workflow logs above."
            exit 0
          fi

          export AWS_ENDPOINT_URL="https://${CLOUDFLARE_ACCOUNT_ID}.r2.cloudflarestorage.com"
          aws s3 cp output/r2/manifest.json \
            "s3://${CLOUDFLARE_R2_BUCKET}/iptv-data/manifest.json" \
            --content-type application/json \
            --cache-control 'public, max-age=300'
          for guide in output/r2/guide_*.xml.gz; do
            [ -e "$guide" ] || continue
            aws s3 cp "$guide" "s3://${CLOUDFLARE_R2_BUCKET}/iptv-data/$(basename "$guide")" \
              --content-type application/gzip \
              --cache-control 'public, max-age=300'
          done
          aws s3 cp output/best/epg_catalog.json \
            "s3://${CLOUDFLARE_R2_BUCKET}/iptv-data/epg_catalog.json" \
            --content-type application/json \
            --cache-control 'public, max-age=300'
```

- [ ] **Step 2: Validate YAML syntax**

Run: `python -c "import yaml; yaml.safe_load(open('.github/workflows/iptv_guide_r2.yml'))"`
Expected: no output (parses cleanly). Run from the repo root, not `iptv-data/`.

- [ ] **Step 3: Manually trace the happy path and the two soft-fail paths**

Read through the file once more checking: (a) a country present on all three mirrors ends with `output/best/<CC>.xml` containing the epgshare01 or iptv-epg.org content if either beats epg.pw's programme count; (b) a country where `fetch_iptv_epg_org` and `fetch_epgshare01` both curl-404 leaves `output/remap_iptv_epg_org` and `output/remap_epgshare01` never created, and `select_best_sources` (Task 1, `directory.is_dir()` guard) treats that as zero candidates from those sources without erroring; (c) if literally no source has the country, the "Pick best source" step's explicit `[ ! -f ... ]` check fails the job loudly instead of silently uploading a stale/missing guide.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/iptv_guide_r2.yml
git commit -m "feat(epg): mirror iptv-epg.org and epgshare01.online into the R2 guide pipeline

Fetches the same \$COUNTRY from two more static XMLTV mirrors
alongside epg.pw, remaps each onto catalog ids, and publishes
whichever has the most programmes under the unchanged guide_XX.xml.gz
key. Either new source can 404 without failing the job. Also
publishes epg_catalog.json (country, winning source, programme/channel
counts) for the in-app guide picker.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 3: `epgCatalogProvider` (Dart)

**Files:**
- Create: `packages/feature_iptv/lib/application/providers/epg_catalog_provider.dart`
- Modify: `packages/feature_iptv/lib/feature_iptv.dart` (export the new file)
- Test: `packages/feature_iptv/test/iptv/application/providers/epg_catalog_provider_test.dart`

**Interfaces:**
- Consumes: `dioProvider` (`iptv_providers.dart`, existing).
- Produces: `class EpgCatalogEntry` (`countryCode`, `sourceId`, `programmeCount`, `channelCount`, `updatedAt` — `Equatable`), `epgCatalogProvider` (`FutureProvider<List<EpgCatalogEntry>>`). Consumed by Task 4.

- [ ] **Step 1: Write the failing test**

Create `packages/feature_iptv/test/iptv/application/providers/epg_catalog_provider_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:feature_iptv/application/providers/epg_catalog_provider.dart';
import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a well-formed catalog response', () async {
    final adapter = _CatalogAdapter(
      jsonEncode([
        {
          'countryCode': 'IN',
          'sourceId': 'epgshare01',
          'programmeCount': 5000,
          'channelCount': 120,
          'updatedAt': '2026-09-07T00:00:00Z',
        },
      ]),
      statusCode: 200,
    );
    final container = ProviderContainer(
      overrides: [
        dioProvider.overrideWithValue(Dio()..httpClientAdapter = adapter),
        epgCatalogManifestUrlProvider.overrideWithValue(
          'https://example.com/iptv-data/manifest.json',
        ),
      ],
    );
    addTearDown(container.dispose);

    final catalog = await container.read(epgCatalogProvider.future);

    expect(catalog, hasLength(1));
    expect(catalog.single.countryCode, 'IN');
    expect(catalog.single.sourceId, 'epgshare01');
    expect(catalog.single.programmeCount, 5000);
    expect(catalog.single.channelCount, 120);
    expect(catalog.single.updatedAt, DateTime.utc(2026, 9, 7));
    expect(
      adapter.requestedPath,
      'https://example.com/iptv-data/epg_catalog.json',
    );
  });

  test('degrades to an empty list on a 404', () async {
    final container = ProviderContainer(
      overrides: [
        dioProvider.overrideWithValue(
          Dio()..httpClientAdapter = _CatalogAdapter('not found', statusCode: 404),
        ),
        epgCatalogManifestUrlProvider.overrideWithValue(
          'https://example.com/iptv-data/manifest.json',
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(epgCatalogProvider.future), isEmpty);
  });

  test('degrades to an empty list when no manifest URL is configured', () async {
    final container = ProviderContainer(
      overrides: [epgCatalogManifestUrlProvider.overrideWithValue('')],
    );
    addTearDown(container.dispose);

    expect(await container.read(epgCatalogProvider.future), isEmpty);
  });
}

class _CatalogAdapter implements HttpClientAdapter {
  _CatalogAdapter(this._body, {required this.statusCode});

  final String _body;
  final int statusCode;
  String? requestedPath;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestedPath = options.uri.toString();
    return ResponseBody.fromBytes(
      utf8.encode(_body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_iptv && flutter test test/iptv/application/providers/epg_catalog_provider_test.dart`
Expected: FAIL — `epg_catalog_provider.dart` does not exist yet.

- [ ] **Step 3: Write the implementation**

Create `packages/feature_iptv/lib/application/providers/epg_catalog_provider.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'iptv_providers.dart';

/// Same compile-time R2 manifest URL `main_tv.dart` seeds the system guide
/// with (`IPTV_DATA_MANIFEST_URL`) -- read directly here too, via an
/// overridable provider, so the guide picker works without new plumbing
/// through every app entrypoint. Empty on a build that doesn't define it;
/// [epgCatalogProvider] degrades to an empty catalog in that case.
final epgCatalogManifestUrlProvider = Provider<String>((ref) {
  return const String.fromEnvironment('IPTV_DATA_MANIFEST_URL');
});

class EpgCatalogEntry extends Equatable {
  const EpgCatalogEntry({
    required this.countryCode,
    required this.sourceId,
    required this.programmeCount,
    required this.channelCount,
    required this.updatedAt,
  });

  final String countryCode;
  final String sourceId;
  final int programmeCount;
  final int channelCount;
  final DateTime updatedAt;

  factory EpgCatalogEntry.fromJson(Map<String, dynamic> json) {
    return EpgCatalogEntry(
      countryCode: json['countryCode'] as String,
      sourceId: json['sourceId'] as String,
      programmeCount: json['programmeCount'] as int,
      channelCount: json['channelCount'] as int,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  @override
  List<Object?> get props => [
    countryCode,
    sourceId,
    programmeCount,
    channelCount,
    updatedAt,
  ];
}

/// The published guide catalog (one row per country, whichever source won
/// M1's per-country scoring) sitting alongside `manifest.json` in the same
/// R2 bucket. Never throws: a missing manifest URL, a network failure, a
/// non-200 response, or malformed JSON all resolve to an empty list so
/// [XmltvSourceSheet]'s custom-URL section stays fully usable regardless.
final epgCatalogProvider = FutureProvider<List<EpgCatalogEntry>>((ref) async {
  final manifestUrl = ref.watch(epgCatalogManifestUrlProvider);
  final manifestUri = Uri.tryParse(manifestUrl);
  if (manifestUrl.isEmpty || manifestUri == null) return const [];

  try {
    final catalogUri = manifestUri.resolve('epg_catalog.json');
    final dio = ref.watch(dioProvider);
    final response = await dio.get<dynamic>(
      catalogUri.toString(),
      options: Options(
        receiveTimeout: const Duration(seconds: 15),
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300,
      ),
    );
    final rows = (response.data as List<dynamic>).cast<Map<String, dynamic>>();
    return rows.map(EpgCatalogEntry.fromJson).toList(growable: false);
  } on Object {
    return const [];
  }
});
```

- [ ] **Step 4: Export the new file**

In `packages/feature_iptv/lib/feature_iptv.dart`, add (alongside the existing `application/providers/guide_providers.dart` export):

```dart
export "application/providers/epg_catalog_provider.dart";
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd packages/feature_iptv && flutter test test/iptv/application/providers/epg_catalog_provider_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 6: Commit**

```bash
git add packages/feature_iptv/lib/application/providers/epg_catalog_provider.dart \
        packages/feature_iptv/lib/feature_iptv.dart \
        packages/feature_iptv/test/iptv/application/providers/epg_catalog_provider_test.dart
git commit -m "feat(epg): add epgCatalogProvider reading the R2-published guide catalog

Fetches epg_catalog.json (same-origin sibling of manifest.json) and
degrades to an empty list on any failure -- missing manifest URL,
network error, non-200, or malformed JSON -- so the upcoming guide
picker never blocks the existing custom-URL path.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 4: Guide picker UI in `XmltvSourceSheet`

**Files:**
- Modify: `packages/feature_iptv/lib/presentation/widgets/xmltv_source_sheet.dart`
- Test: `packages/feature_iptv/test/iptv/presentation/widgets/xmltv_source_sheet_test.dart`

**Interfaces:**
- Consumes: `epgCatalogProvider`, `EpgCatalogEntry` (Task 3), `countryDisplayLabel` (`channel_filters_provider.dart`, existing), `XmltvSourceRefreshService.refreshSystemGuidesForCountries` (existing), `epgCatalogManifestUrlProvider` (Task 3, read for the `manifestUrl:` argument).

- [ ] **Step 1: Write the failing tests**

First, widen the existing `buildContainer()` helper (top of the file) to accept extra overrides, so each test can add exactly the providers it needs without touching every other test — `ProviderContainer.updateOverrides()` cannot add a provider that wasn't already overridden at construction (same length, same providers, values only), so tests that need `epgCatalogProvider` must include it at construction time instead:

```dart
  Future<ProviderContainer> buildContainer({
    List<Override> extraOverrides = const [],
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ...extraOverrides,
      ],
    );
  }
```

(add `import 'package:flutter_riverpod/flutter_riverpod.dart' show Override;` if `Override` isn't already in scope from the existing `flutter_riverpod` import.)

Add to `packages/feature_iptv/test/iptv/presentation/widgets/xmltv_source_sheet_test.dart` (new imports alongside the existing ones: `package:feature_iptv/application/providers/epg_catalog_provider.dart`, `package:feature_iptv/application/xmltv_source_refresh_service.dart`, `package:feature_iptv/application/mutable_xmltv_compact_epg_repository.dart`, `package:feature_iptv/application/xmltv_source_store.dart`, `package:core_data/core_data.dart`, `package:dio/dio.dart`, `dart:io`):

```dart
  testWidgets('lists catalog entries with counts and a country label', (
    tester,
  ) async {
    final container = await buildContainer(
      extraOverrides: [
        epgCatalogProvider.overrideWith(
          (ref) async => const [
            EpgCatalogEntry(
              countryCode: 'IN',
              sourceId: 'epgshare01',
              programmeCount: 5000,
              channelCount: 120,
              updatedAt: DateTime.utc(2026, 9, 7),
            ),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: XmltvSourceSheet())),
      ),
    );
    await tester.pump();

    expect(find.textContaining('India'), findsOneWidget);
    expect(find.textContaining('120'), findsOneWidget);
    expect(find.text('Use'), findsOneWidget);
  });

  testWidgets('search filters the catalog list by country', (tester) async {
    final container = await buildContainer(
      extraOverrides: [
        epgCatalogProvider.overrideWith(
          (ref) async => const [
            EpgCatalogEntry(
              countryCode: 'IN',
              sourceId: 'epgshare01',
              programmeCount: 5000,
              channelCount: 120,
              updatedAt: DateTime.utc(2026, 9, 7),
            ),
            EpgCatalogEntry(
              countryCode: 'GB',
              sourceId: 'epg_pw',
              programmeCount: 3000,
              channelCount: 80,
              updatedAt: DateTime.utc(2026, 9, 7),
            ),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: XmltvSourceSheet())),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, 'united king');
    await tester.pump();

    expect(find.textContaining('United Kingdom'), findsOneWidget);
    expect(find.textContaining('India'), findsNothing);
  });

  testWidgets('tapping Use refreshes the system guide for that country', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final fakeService = _RecordingRefreshService(
      sourceStore: XmltvSourceStore(PreferencesStore(prefs)),
    );
    final container = await buildContainer(
      extraOverrides: [
        epgCatalogProvider.overrideWith(
          (ref) async => const [
            EpgCatalogEntry(
              countryCode: 'IN',
              sourceId: 'epgshare01',
              programmeCount: 5000,
              channelCount: 120,
              updatedAt: DateTime.utc(2026, 9, 7),
            ),
          ],
        ),
        xmltvSourceRefreshServiceProvider.overrideWithValue(fakeService),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: XmltvSourceSheet())),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Use'));
    await tester.pumpAndSettle();

    expect(fakeService.lastCountries, {'IN'});
  });

  testWidgets('custom URL paste box is collapsed under "Advanced"', (
    tester,
  ) async {
    final container = await buildContainer(
      extraOverrides: [epgCatalogProvider.overrideWith((ref) async => const [])],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: XmltvSourceSheet())),
      ),
    );
    await tester.pump();

    expect(find.text('Advanced: custom URL'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'XMLTV URL'), findsNothing);

    await tester.tap(find.text('Advanced: custom URL'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'XMLTV URL'), findsOneWidget);
  });
```

And a fake service class at the bottom of the test file (mirrors `_FailingAdapter`-style fakes already used in `xmltv_source_refresh_service_test.dart`):

```dart
class _RecordingRefreshService extends XmltvSourceRefreshService {
  _RecordingRefreshService({required XmltvSourceStore sourceStore})
    : super(
        dio: Dio(),
        sourceStore: sourceStore,
        repository: MutableXmltvCompactEpgRepository(),
        downloadDirectoryProvider: () async => Directory.systemTemp,
      );

  Set<String>? lastCountries;

  @override
  Future<void> refreshSystemGuidesForCountries({
    required String manifestUrl,
    required Set<String> countries,
  }) async {
    lastCountries = countries;
  }
}
```

(add `import 'dart:io';` and `import 'package:dio/dio.dart';` to the test file's imports for `Directory` and `Dio`.)

`ExpansionTile` (default `maintainState: false`) does not build its `children` at all while collapsed, and "Advanced: custom URL" starts collapsed by design (Step 3, where `configAsync.when(...)` becomes the first child of that `ExpansionTile`) — so all five pre-existing tests, which assert on content that now lives inside that section, must expand it first. Update each of the five existing `testWidgets` bodies in this file to tap the header and settle before their existing assertions:

```dart
await tester.tap(find.text('Advanced: custom URL'));
await tester.pumpAndSettle();
```

- `'shows "no source configured" when nothing is saved'`: insert after its `await tester.pump();`, before `expect(find.textContaining('No XMLTV source configured')...`.
- `'shows the saved source URL and last-refreshed state'`: insert after its `await tester.pump();`, before `expect(find.text('Current source: ...'`.
- `'shows the last error when refresh failed'`: insert after its `await tester.pump();`, before `expect(find.textContaining('Connection timed out')...`.
- `'helper text tells users to paste XMLTV, not HTML'`: insert after its `await tester.pump();`, before `expect(find.textContaining('XMLTV URL or .xml.gz')...`.
- `'Remove source button clears the saved config'`: insert after its `await tester.pump();`, before `await tester.tap(find.text('Remove source'));`.

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/widgets/xmltv_source_sheet_test.dart`
Expected: FAIL — `Advanced: custom URL`, catalog rows, and `Use` don't exist yet in the widget.

- [ ] **Step 3: Rewrite the widget**

Replace `packages/feature_iptv/lib/presentation/widgets/xmltv_source_sheet.dart` in full:

```dart
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/epg_catalog_provider.dart';
import '../../application/providers/channel_filters_provider.dart' show countryDisplayLabel;
import '../../application/providers/guide_providers.dart';
import 'adaptive_iptv_sheet.dart';

/// Lets the user pick a guide from the published catalog, or (under
/// "Advanced") add/refresh/remove a raw XMLTV URL directly. A ready-to-use
/// widget — CV-022 (TV settings screen, not yet built) is expected to
/// present this via `showModalBottomSheet` or embed it directly; this task
/// only builds and tests the widget itself.
class XmltvSourceSheet extends ConsumerStatefulWidget {
  const XmltvSourceSheet({super.key});

  @override
  ConsumerState<XmltvSourceSheet> createState() => _XmltvSourceSheetState();
}

class _XmltvSourceSheetState extends ConsumerState<XmltvSourceSheet> {
  final _urlController = TextEditingController();
  final _catalogSearchController = TextEditingController();
  bool _isRefreshing = false;
  String? _refreshFeedback;
  String? _applyingCountryCode;
  String? _catalogFeedback;

  @override
  void dispose() {
    _urlController.dispose();
    _catalogSearchController.dispose();
    super.dispose();
  }

  Future<void> _saveAndRefresh() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isRefreshing = true;
      _refreshFeedback = null;
    });

    try {
      await ref.read(xmltvSourceRefreshServiceProvider).refresh(url);
      if (!mounted) return;
      setState(() => _refreshFeedback = 'Guide refreshed.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _refreshFeedback = 'Refresh failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
        ref.invalidate(xmltvSourceConfigProvider);
        ref.invalidate(guidePagedWindowProvider);
      }
    }
  }

  Future<void> _removeSource() async {
    await ref.read(xmltvSourceStoreProvider).clear();
    if (!mounted) return;
    ref.invalidate(xmltvSourceConfigProvider);
    ref.invalidate(guidePagedWindowProvider);
  }

  Future<void> _useCatalogEntry(EpgCatalogEntry entry) async {
    setState(() {
      _applyingCountryCode = entry.countryCode;
      _catalogFeedback = null;
    });
    try {
      final manifestUrl = ref.read(epgCatalogManifestUrlProvider);
      await ref
          .read(xmltvSourceRefreshServiceProvider)
          .refreshSystemGuidesForCountries(
            manifestUrl: manifestUrl,
            countries: {entry.countryCode},
          );
      if (!mounted) return;
      setState(
        () => _catalogFeedback = 'Guide applied for ${entry.countryCode}.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _catalogFeedback = 'Could not apply guide: $e');
    } finally {
      if (mounted) {
        setState(() => _applyingCountryCode = null);
        ref.invalidate(xmltvSourceConfigProvider);
        ref.invalidate(guidePagedWindowProvider);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(xmltvSourceConfigProvider);
    final catalogAsync = ref.watch(epgCatalogProvider);
    final query = _catalogSearchController.text.trim().toLowerCase();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Browse guides', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _catalogSearchController,
            decoration: const InputDecoration(
              labelText: 'Search by country',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          catalogAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => const Text('Could not load the guide catalog.'),
            data: (entries) {
              final filtered = query.isEmpty
                  ? entries
                  : entries
                        .where(
                          (entry) => countryDisplayLabel(entry.countryCode)
                              .toLowerCase()
                              .contains(query),
                        )
                        .toList(growable: false);
              if (filtered.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No guides match your search.'),
                );
              }
              return Column(
                children: [
                  for (final entry in filtered)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(countryDisplayLabel(entry.countryCode)),
                      subtitle: Text(
                        '${entry.channelCount} channels · '
                        '${entry.programmeCount} programmes',
                      ),
                      trailing: TvFocusable(
                        onSelect: _applyingCountryCode == null
                            ? () => _useCatalogEntry(entry)
                            : null,
                        semanticLabel: 'Use guide for ${entry.countryCode}',
                        semanticButton: true,
                        child: FilledButton(
                          onPressed: _applyingCountryCode == null
                              ? () => _useCatalogEntry(entry)
                              : null,
                          child: _applyingCountryCode == entry.countryCode
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Use'),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          if (_catalogFeedback != null) ...[
            const SizedBox(height: 8),
            Text(_catalogFeedback!),
          ],
          const SizedBox(height: 16),
          ExpansionTile(
            title: const Text('Advanced: custom URL'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            children: [
              configAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (error, _) =>
                    Text('Could not load source config: $error'),
                data: (config) {
                  if (config == null) {
                    return const Text('No XMLTV source configured yet.');
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Current source: ${config.url}'),
                      const SizedBox(height: 4),
                      Text(
                        config.lastRefreshedAt != null
                            ? 'Last refreshed: ${config.lastRefreshedAt}'
                            : 'Never refreshed successfully.',
                      ),
                      if (config.lastError != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          config.lastError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      TvFocusable(
                        onSelect: _removeSource,
                        semanticLabel: 'Remove source',
                        semanticButton: true,
                        child: TextButton(
                          onPressed: _removeSource,
                          child: const Text('Remove source'),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'XMLTV URL',
                  hintText: 'https://example.com/guide.xml.gz',
                  helperText:
                      'Paste an XMLTV URL or .xml.gz. HTML schedule pages will fail.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TvFocusable(
                onSelect: _isRefreshing ? null : _saveAndRefresh,
                semanticLabel: 'Save & Refresh',
                semanticButton: true,
                child: FilledButton(
                  onPressed: _isRefreshing ? null : _saveAndRefresh,
                  child: _isRefreshing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save & Refresh'),
                ),
              ),
              if (_refreshFeedback != null) ...[
                const SizedBox(height: 8),
                Text(_refreshFeedback!),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Presents [XmltvSourceSheet] as an adaptive sheet — the phone Settings
/// hub entry point ("EPG Guide Source") uses this; the TV variant embeds
/// the sheet widget directly.
Future<void> showXmltvSourceSheet(BuildContext context) async {
  await showAdaptiveIptvSheet<void>(
    context: context,
    maxWidth: 640,
    builder: (_) => const XmltvSourceSheet(),
  );
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/widgets/xmltv_source_sheet_test.dart`
Expected: PASS (all 9 tests — the 5 pre-existing ones with their new expand-tap lines from Step 1, plus the 4 new catalog tests).

- [ ] **Step 5: Commit**

```bash
git add packages/feature_iptv/lib/presentation/widgets/xmltv_source_sheet.dart \
        packages/feature_iptv/test/iptv/presentation/widgets/xmltv_source_sheet_test.dart
git commit -m "feat(epg): add a browsable guide catalog to XmltvSourceSheet

Replaces the raw-URL-paste-only source picker with a searchable list
of published guides (country, channel/programme counts); picking one
calls the existing refreshSystemGuidesForCountries for that country.
The custom-URL paste flow is preserved under an Advanced section.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 5: Guide-local favorites + category filters (providers)

**Files:**
- Modify: `packages/feature_iptv/lib/application/providers/guide_providers.dart`
- Test: `packages/feature_iptv/test/iptv/application/providers/guide_providers_test.dart`

**Interfaces:**
- Consumes: `favoriteChannelIdsProvider` (`iptv_providers.dart`, existing), `channelCategoryLabels`/`categoryFilterKey` (`channel_filters_provider.dart`, already imported in this file).
- Produces: `guideCategoryFilterProvider` (`StateProvider<String?>`), `guideFavoritesOnlyProvider` (`StateProvider<bool>`), `guideAvailableCategoriesProvider` (`Provider<List<String>>`). Consumed by Task 6.

- [ ] **Step 1: Write the failing tests**

Add to `packages/feature_iptv/test/iptv/application/providers/guide_providers_test.dart`:

```dart
  test('guideCategoryFilterProvider narrows guideFilteredChannelsProvider', () async {
    const movies = IPTVChannel(
      id: 'channel-movies',
      name: 'Movie Channel',
      streamUrl: 'https://example.com/movies.m3u8',
      group: 'Movies',
    );
    final container = buildContainer(channels: const [channel, movies]);
    addTearDown(container.dispose);
    await container.read(iptvChannelsProvider.future);

    container.read(guideCategoryFilterProvider.notifier).state = 'Movies';

    expect(
      container.read(guideFilteredChannelsProvider).map((c) => c.id),
      ['channel-movies'],
    );
  });

  test('guideAvailableCategoriesProvider lists every loaded category, sorted', () async {
    const movies = IPTVChannel(
      id: 'channel-movies',
      name: 'Movie Channel',
      streamUrl: 'https://example.com/movies.m3u8',
      group: 'Movies',
    );
    final container = buildContainer(channels: const [channel, movies]);
    addTearDown(container.dispose);
    await container.read(iptvChannelsProvider.future);

    expect(container.read(guideAvailableCategoriesProvider), [
      'Movies',
      'News',
    ]);
  });

  test('guideFavoritesOnlyProvider narrows guideFilteredChannelsProvider to favorites', () async {
    const other = IPTVChannel(
      id: 'channel-2',
      name: 'Second Channel',
      streamUrl: 'https://example.com/2.m3u8',
      group: 'Sports',
    );
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        iptvChannelsProvider.overrideWith((ref) async => [channel, other]),
        favoriteChannelIdsProvider.overrideWith((ref) async => {'channel-2'}),
      ],
    );
    addTearDown(container.dispose);
    await container.read(iptvChannelsProvider.future);

    container.read(guideFavoritesOnlyProvider.notifier).state = true;

    expect(
      container.read(guideFilteredChannelsProvider).map((c) => c.id),
      ['channel-2'],
    );
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd packages/feature_iptv && flutter test test/iptv/application/providers/guide_providers_test.dart`
Expected: FAIL — `guideCategoryFilterProvider`, `guideAvailableCategoriesProvider`, `guideFavoritesOnlyProvider` are undefined.

- [ ] **Step 3: Implement the providers**

In `packages/feature_iptv/lib/application/providers/guide_providers.dart`, add after the existing `guideSearchQueryProvider` declaration:

```dart
/// Guide-local category filter, independent of the main browse screen's
/// `channelFiltersProvider.category` — same isolation rule as
/// [guideSearchQueryProvider] (see [applyChannelScope]'s doc comment: search
/// and category are each surface's own concern).
final guideCategoryFilterProvider = StateProvider<String?>((ref) => null);

/// Guide-local favorites-only toggle.
final guideFavoritesOnlyProvider = StateProvider<bool>((ref) => false);

/// Category labels present across every currently-loaded channel, sorted
/// for a stable chip order. Computed from the full channel list (not the
/// already-filtered one) so a selected chip never disappears because it
/// narrowed itself out of its own source list.
final guideAvailableCategoriesProvider = Provider<List<String>>((ref) {
  final channels = ref.watch(iptvChannelsProvider).value ?? const [];
  final labels = <String>{};
  for (final channel in channels) {
    labels.addAll(channelCategoryLabels(channel.group));
  }
  return labels.toList()..sort();
});
```

Then replace the existing `guideFilteredChannelsProvider` body:

```dart
final guideFilteredChannelsProvider = Provider<List<IPTVChannel>>((ref) {
  final index = ref.watch(channelSearchIndexProvider);
  final query = ref.watch(guideSearchQueryProvider);
  final filters = ref.watch(channelFiltersProvider);
  final hiddenGroupIds =
      ref.watch(hiddenGroupIdsProvider).value ?? const <String>{};
  if (index == null) return const [];

  var channels = applyChannelScope(
    channels: index.filterAndSort(query: query),
    filters: filters,
    metadataByChannelId: const {},
  );
  if (hiddenGroupIds.isNotEmpty) {
    channels = channels
        .where((channel) => !hiddenGroupIds.contains(channel.group))
        .toList(growable: false);
  }

  final category = ref.watch(guideCategoryFilterProvider);
  if (category != null) {
    final key = categoryFilterKey(category);
    channels = channels
        .where(
          (channel) => channelCategoryLabels(
            channel.group,
          ).map(categoryFilterKey).contains(key),
        )
        .toList(growable: false);
  }

  if (ref.watch(guideFavoritesOnlyProvider)) {
    final favoriteIds =
        ref.watch(favoriteChannelIdsProvider).value ?? const <String>{};
    channels = channels
        .where((channel) => favoriteIds.contains(channel.id))
        .toList(growable: false);
  }

  return channels;
});
```

(`favoriteChannelIdsProvider` is already reachable — this file already imports `iptv_providers.dart`, which declares it.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd packages/feature_iptv && flutter test test/iptv/application/providers/guide_providers_test.dart`
Expected: PASS (all tests, old and new).

- [ ] **Step 5: Commit**

```bash
git add packages/feature_iptv/lib/application/providers/guide_providers.dart \
        packages/feature_iptv/test/iptv/application/providers/guide_providers_test.dart
git commit -m "feat(epg): add guide-local category and favorites-only filters

guideCategoryFilterProvider and guideFavoritesOnlyProvider compose
into guideFilteredChannelsProvider alongside the existing search/scope
filtering, independent of the main browse screen's channelFiltersProvider
(same isolation as the existing guide search query). Reuses the
existing favoriteChannelIdsProvider and channelCategoryLabels rather
than a second favorites store or taxonomy.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 6: Filter chips in the Guide's shared header

**Files:**
- Modify: `packages/feature_iptv/lib/presentation/tv/iptv_guide_screen.dart`
- Test: `packages/feature_iptv/test/iptv/presentation/tv/iptv_guide_screen_test.dart`

**Interfaces:**
- Consumes: `guideCategoryFilterProvider`, `guideFavoritesOnlyProvider`, `guideAvailableCategoriesProvider` (Task 5), `favoriteChannelIdsProvider` (existing, for the test override).

- [ ] **Step 1: Write the failing test**

Add to `packages/feature_iptv/test/iptv/presentation/tv/iptv_guide_screen_test.dart` (reuses the file's existing `pumpScreen` helper, `newsChannel` (`group: 'News'`), and `sportsChannel` (`group: 'Sports'`)):

```dart
  testWidgets(
    'category chip narrows the visible channels',
    (tester) async {
      await pumpScreen(tester);

      expect(find.text('City News Live'), findsOneWidget);
      expect(find.text('Stadium Sports'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilterChip, 'Sports'));
      await tester.pump();

      expect(find.text('Stadium Sports'), findsOneWidget);
      expect(find.text('City News Live'), findsNothing);
    },
    experimentalLeakTesting: LeakTesting.settings,
  );

  testWidgets(
    'favorites chip narrows the visible channels to favorites',
    (tester) async {
      await pumpScreen(tester, favoriteChannelIds: {sportsChannel.id});

      expect(find.text('City News Live'), findsOneWidget);
      expect(find.text('Stadium Sports'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilterChip, 'Favorites'));
      await tester.pump();

      expect(find.text('Stadium Sports'), findsOneWidget);
      expect(find.text('City News Live'), findsNothing);
    },
    experimentalLeakTesting: LeakTesting.settings,
  );
```

This needs `pumpScreen` to accept an optional `favoriteChannelIds` parameter. In the same test file, update the `pumpScreen` signature and its `ProviderScope` overrides:

```dart
  Future<void> pumpScreen(
    WidgetTester tester, {
    List<IPTVChannel>? visibleChannels,
    void Function()? onSelectedCallback,
    AiroFormFactor? overrideFormFactor,
    TextScaler textScaler = TextScaler.noScaling,
    CompactEpgProgram? guideProgram,
    RicherContextProvider? richerContextProvider,
    bool remindersAvailable = false,
    Set<String>? favoriteChannelIds,
  }) async {
```

and add one entry to the existing `overrides: [...]` list (alongside `iptvChannelsProvider.overrideWith(...)`):

```dart
          if (favoriteChannelIds != null)
            favoriteChannelIdsProvider.overrideWith(
              (ref) async => favoriteChannelIds,
            ),
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/tv/iptv_guide_screen_test.dart`
Expected: FAIL — no `FilterChip` named 'Sports' or 'Favorites' exists in the screen yet.

- [ ] **Step 3: Add the filter chip row**

In `packages/feature_iptv/lib/presentation/tv/iptv_guide_screen.dart`, insert a new widget in the `Column`'s `children` between the search `Padding` and the `Expanded`:

```dart
            return Column(
              children: [
                const _GuideAvailabilityBanner(),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Search guide',
                      hintText: 'Search the guide',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) =>
                        ref.read(guideSearchQueryProvider.notifier).state =
                            value,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: _GuideFilterChips(),
                ),
                const SizedBox(height: 8),
                Expanded(
```

(the `Expanded(...)` block and everything inside it is unchanged — only its position in the `children` list shifts down by two entries).

Then add the new widget class near the other private widgets at the bottom of the file (after `_GuideAvailabilityBanner`):

```dart
class _GuideFilterChips extends ConsumerWidget {
  const _GuideFilterChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(guideAvailableCategoriesProvider);
    final selectedCategory = ref.watch(guideCategoryFilterProvider);
    final favoritesOnly = ref.watch(guideFavoritesOnlyProvider);

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('Favorites'),
              avatar: const Icon(Icons.star, size: 18),
              selected: favoritesOnly,
              onSelected: (value) =>
                  ref.read(guideFavoritesOnlyProvider.notifier).state = value,
            ),
          ),
          for (final category in categories)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(category),
                selected: selectedCategory == category,
                onSelected: (selected) => ref
                        .read(guideCategoryFilterProvider.notifier)
                        .state =
                    selected ? category : null,
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/tv/iptv_guide_screen_test.dart`
Expected: PASS (all tests, old and new — confirm the pre-existing "lists all channels", "renders the touch timeline grid", "renders the TV timeline grid", and reminder tests still pass unchanged, since the new chip row doesn't affect the grid choice or reminder flow).

- [ ] **Step 5: Commit**

```bash
git add packages/feature_iptv/lib/presentation/tv/iptv_guide_screen.dart \
        packages/feature_iptv/test/iptv/presentation/tv/iptv_guide_screen_test.dart
git commit -m "feat(epg): add favorites and category filter chips to the Guide header

Both the TV and touch grids render from the same
_IptvGuideScreenState header, so one new _GuideFilterChips row gives
both surfaces favorites-only and per-category filtering, composed
into guideFilteredChannelsProvider from the previous commit.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Final verification

- [ ] **Step 1: Run the full Python suite**

Run: `cd iptv-data && python -m pytest tests/ -v`
Expected: all pass, including the untouched `test_epg_pw_remap.py` and `test_epg_artifacts.py`.

- [ ] **Step 2: Run the full feature_iptv suite**

Run: `cd packages/feature_iptv && flutter test`
Expected: all pass.

- [ ] **Step 3: Analyze**

Run: `cd packages/feature_iptv && flutter analyze` and `cd iptv-data && python -m pyflakes src/epg_publish_prefer.py src/epg_pw_remap.py` (or whatever linter `iptv-data`'s own CI step uses — check `.github/workflows/iptv_sanity.yml` for the exact lint command already configured there).
Expected: no new warnings/errors.

- [ ] **Step 4: Web build sanity check**

Per this repo's `CLAUDE.md`: `cd app && flutter build web --release` before landing anything that touches `feature_iptv`, since web has no `dart:ffi` and the guide picker adds a new network call path.
Expected: builds successfully.
