"""Decide which epg.pw-remapped country shards are worth republishing.

The iptv-org `epg` grabber (see `.github/workflows/iptv_sanity.yml`) already
produces a bounded, curated `guide_IN.xml.gz`. The epg.pw global remap (see
`epg_pw_remap.py`) is a second, independent source that can cover more
countries but must never silently regress a country CI already has a good
guide for. This module's only job is that comparison: for a country the
grab pipeline already published, prefer the epg.pw remap only when it has at
least as many programmes; for every other country, epg.pw is the only
source, so publish it unconditionally.
"""

from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import os
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path


def programme_count(xml_bytes: bytes) -> int:
    """Number of `<programme>` elements in an (uncompressed) XMLTV payload."""
    return len(ET.fromstring(xml_bytes).findall("programme"))


def programme_count_in_file(path: Path) -> int:
    """`programme_count` for a plain (not gzipped) XMLTV file on disk."""
    if not path.exists():
        return 0
    return programme_count(path.read_bytes())


def programme_count_in_gzip(path: Path) -> int:
    """`programme_count` for a `.xml.gz` XMLTV file on disk."""
    if not path.exists():
        return 0
    return programme_count(gzip.decompress(path.read_bytes()))


def select_countries_to_publish(
    *,
    remap_dir: Path,
    published_directory: Path,
    prefer_existing_over_remap: tuple[str, ...] = ("IN",),
) -> list[str]:
    """Countries from `remap_dir` (one `<CC>.xml` per country, plus `ALL.xml`)
    that should be (re)published from the epg.pw remap.

    Countries in [prefer_existing_over_remap] (the ones the iptv-org grab
    pipeline already curates) are only included when the remap's programme
    count is greater than or equal to the existing `guide_<CC>.xml.gz`'s.
    Every other remapped country has no existing artifact to protect, so it
    is always included.
    """
    countries = sorted(
        path.stem for path in remap_dir.glob("*.xml") if path.stem != "ALL"
    )
    selected: list[str] = []
    for country in countries:
        if country not in prefer_existing_over_remap:
            selected.append(country)
            continue
        remap_count = programme_count_in_file(remap_dir / f"{country}.xml")
        if remap_count == 0:
            continue
        existing_count = programme_count_in_gzip(
            published_directory / f"guide_{country}.xml.gz"
        )
        if remap_count >= existing_count:
            selected.append(country)
    return selected


def publish_all_guide(
    *,
    all_xml_bytes: bytes,
    output_directory: Path,
    manifest_path: Path,
) -> str:
    """Gzips the epg.pw remap's `ALL` union and records it in the manifest
    as `guide_ALL`. This is a CDN/tooling artifact only -- never fetched by
    a device on boot (see spec: "Do not download guide_ALL.xml.gz on
    Android TV / iOS as the default"). Reuses the same gzip mtime=0 +
    atomic-replace approach as `epg_artifacts.publish_country_guides`.
    """
    output_directory.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        dir=output_directory, suffix=".xml.gz.tmp", delete=False
    ) as temporary:
        with gzip.GzipFile(filename="", fileobj=temporary, mode="wb", mtime=0) as archive:
            archive.write(all_xml_bytes)
        temporary_path = Path(temporary.name)
    checksum = hashlib.sha256(temporary_path.read_bytes()).hexdigest()
    try:
        os.replace(temporary_path, output_directory / "guide_ALL.xml.gz")
    except OSError:
        temporary_path.unlink(missing_ok=True)
        raise

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest.setdefault("files", {})["guide_ALL"] = "guide_ALL.xml.gz"
    manifest.setdefault("fileChecksums", {})["guide_ALL"] = checksum
    with tempfile.NamedTemporaryFile(
        dir=manifest_path.parent,
        suffix=".json.tmp",
        mode="w",
        encoding="utf-8",
        delete=False,
    ) as temporary:
        json.dump(manifest, temporary, indent=2, ensure_ascii=False)
        temporary.write("\n")
        manifest_temp_path = Path(temporary.name)
    os.replace(manifest_temp_path, manifest_path)
    return checksum


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    select = subparsers.add_parser(
        "select-countries",
        help="Print, one per line, the remapped countries worth publishing.",
    )
    select.add_argument("--remap-dir", type=Path, required=True)
    select.add_argument("--published-directory", type=Path, required=True)
    select.add_argument("--prefer-existing", nargs="*", default=["IN"])

    publish_all = subparsers.add_parser(
        "publish-all",
        help="Gzip the remap's ALL.xml union and record it as guide_ALL.",
    )
    publish_all.add_argument("--all-xml", type=Path, required=True)
    publish_all.add_argument("--output-directory", type=Path, required=True)
    publish_all.add_argument("--manifest", type=Path, required=True)

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


if __name__ == "__main__":
    main()
