"""Remap epg.pw's numeric XMLTV channel ids onto our curated catalog ids.

epg.pw publishes real XMLTV (``<channel id="543480">`` /
``<display-name>MTV</display-name>``), but its numeric ids don't match the
iptv-org-style ``xmltv_id`` values (``MTV.in``) our playlists carry as
``tvg-id``. This module rewrites a grabbed epg.pw file so every
``channel``/``programme`` uses the catalog id instead, and splits the result
by the catalog's ``country`` field so CI can publish one ``guide_XX.xml.gz``
shard per country (plus the ``ALL`` union) without ever shipping a numeric id
to a device.

Channels epg.pw has no catalog match for are dropped entirely -- they must
never be published under their epg.pw numeric id, which would defeat the
whole point of aligning ids with the playlist.
"""

from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import os
import re
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any

#: Bucket used for a catalog channel with no (or an unrecognized) country.
_UNKNOWN_COUNTRY = "ZZ"

#: Trailing quality/language qualifiers epg.pw and iptv-org both sometimes
#: append to a display name (`MTV HD`, `MTV (SD)`) that must not affect
#: name-based matching.
_QUALITY_SUFFIXES = re.compile(
    r"\s*[\(\[]?\b(HD|SD|FHD|UHD|4K|HEVC|H265|FEED)\b[\)\]]?\s*$",
    re.IGNORECASE,
)
_PUNCTUATION = re.compile(r"[^a-z0-9]+")


def normalize_name(name: str) -> str:
    """Casefold a channel display name for matching, stripping quality
    suffixes (`MTV HD` -> `mtv`) and punctuation/whitespace differences
    (`B4U Music` / `b4u-music` -> `b4umusic`) so epg.pw and catalog naming
    conventions line up.
    """
    stripped = name.strip()
    previous = None
    # Multiple qualifiers can stack ("MTV HD (Feed)"); strip repeatedly
    # until nothing more matches.
    while previous != stripped:
        previous = stripped
        stripped = _QUALITY_SUFFIXES.sub("", stripped)
    return _PUNCTUATION.sub("", stripped.casefold())


def _catalog_index(channels_payload: dict[str, Any]) -> dict[str, list[dict[str, Any]]]:
    """Groups catalog channels by normalized display name, so multiple
    catalog rows can share one epg.pw display name (collision handling).
    """
    index: dict[str, list[dict[str, Any]]] = {}
    for channel in channels_payload.get("channels", []):
        channel_id = channel.get("id")
        name = channel.get("name")
        if not channel_id or not name:
            continue
        key = normalize_name(str(name))
        if not key:
            continue
        index.setdefault(key, []).append(channel)
    return index


def _pick_catalog_channel(
    candidates: list[dict[str, Any]],
    *,
    epg_pw_id: str,
) -> dict[str, Any]:
    """Deterministic collision pick when more than one catalog row shares a
    normalized name: prefer an id whose ``.<cc>`` suffix appears in the
    epg.pw numeric id's own catalog entry (rare, name collisions across
    countries are the common case) -- in practice we have no such signal
    from a bare numeric id, so this falls back to the lexicographically
    smaller catalog id for a stable, reproducible pick across runs.
    """
    if len(candidates) == 1:
        return candidates[0]
    return min(candidates, key=lambda channel: str(channel["id"]))


def _channel_country(channel: dict[str, Any]) -> str:
    country = channel.get("country")
    if not country:
        return _UNKNOWN_COUNTRY
    return str(country).upper()


def remap_epg_pw_xmltv(
    xml_bytes: bytes,
    channels_payload: dict[str, Any],
) -> dict[str, bytes]:
    """Rewrite an epg.pw XMLTV export onto catalog ids and split by country.

    Returns a mapping of ISO country code (upper-cased, or ``ZZ`` when the
    catalog channel declares none) to XMLTV bytes for that country, plus the
    key ``"ALL"`` holding the union of every remapped channel/programme.
    Channels with no catalog match, and programmes referencing them, are
    dropped -- never emitted under a raw epg.pw numeric id.
    """
    source_root = ET.fromstring(xml_bytes)
    catalog_by_name = _catalog_index(channels_payload)

    # epg.pw id -> catalog id, established once from <channel> elements so
    # every <programme channel="..."> reuses the same decision.
    catalog_id_by_source_id: dict[str, str] = {}
    catalog_by_id: dict[str, dict[str, Any]] = {
        str(channel["id"]): channel
        for channel in channels_payload.get("channels", [])
        if channel.get("id")
    }

    for element in source_root.findall("channel"):
        source_id = element.get("id")
        if not source_id:
            continue
        # An epg.pw id that is already a catalog id (an upstream file that
        # already publishes iptv-org-style ids) is kept as-is.
        if source_id in catalog_by_id:
            catalog_id_by_source_id[source_id] = source_id
            continue
        display_name_el = element.find("display-name")
        display_name = (
            display_name_el.text if display_name_el is not None else None
        )
        if not display_name:
            continue
        key = normalize_name(display_name)
        candidates = catalog_by_name.get(key)
        if not candidates:
            continue
        catalog_channel = _pick_catalog_channel(candidates, epg_pw_id=source_id)
        catalog_id_by_source_id[source_id] = str(catalog_channel["id"])

    country_by_catalog_id = {
        catalog_id: _channel_country(catalog_by_id[catalog_id])
        for catalog_id in set(catalog_id_by_source_id.values())
        if catalog_id in catalog_by_id
    }

    roots: dict[str, ET.Element] = {"ALL": ET.Element("tv")}
    emitted_channel_ids: dict[str, set[str]] = {"ALL": set()}

    def _root_for(country: str) -> ET.Element:
        return roots.setdefault(country, ET.Element("tv"))

    for element in source_root.findall("channel"):
        source_id = element.get("id")
        catalog_id = catalog_id_by_source_id.get(source_id or "")
        if catalog_id is None:
            continue
        country = country_by_catalog_id.get(catalog_id, _UNKNOWN_COUNTRY)
        remapped = ET.fromstring(ET.tostring(element, encoding="utf-8"))
        remapped.set("id", catalog_id)
        for target in (country, "ALL"):
            emitted = emitted_channel_ids.setdefault(target, set())
            if catalog_id in emitted:
                continue
            emitted.add(catalog_id)
            _root_for(target).append(
                ET.fromstring(ET.tostring(remapped, encoding="utf-8"))
            )

    for element in source_root.findall("programme"):
        source_channel = element.get("channel")
        catalog_id = catalog_id_by_source_id.get(source_channel or "")
        if catalog_id is None:
            continue
        country = country_by_catalog_id.get(catalog_id, _UNKNOWN_COUNTRY)
        remapped = ET.fromstring(ET.tostring(element, encoding="utf-8"))
        remapped.set("channel", catalog_id)
        for target in (country, "ALL"):
            _root_for(target).append(
                ET.fromstring(ET.tostring(remapped, encoding="utf-8"))
            )

    output: dict[str, bytes] = {}
    for country, root in roots.items():
        ET.indent(root, space="  ")
        output[country] = ET.tostring(root, encoding="utf-8", xml_declaration=True)
    return output


def catalog_from_iptv_org_api(rows: list[dict[str, Any]]) -> dict[str, Any]:
    """Shape iptv-org ``channels.json`` into the remap catalog payload."""
    channels = []
    for row in rows:
        channel_id = row.get("id")
        if not channel_id:
            continue
        channels.append(
            {
                "id": str(channel_id),
                "name": str(row.get("name") or channel_id),
                "country": str(row.get("country") or _UNKNOWN_COUNTRY).upper(),
            }
        )
    return {"channels": channels}


def write_gzip_guides(
    remapped: dict[str, bytes],
    output_directory: Path,
    *,
    skip_all: bool = True,
    countries: set[str] | None = None,
) -> dict[str, str]:
    """Write ``guide_XX.xml.gz`` (mtime=0) and return SHA-256 checksums."""
    output_directory.mkdir(parents=True, exist_ok=True)
    checksums: dict[str, str] = {}
    for country, xml_bytes in remapped.items():
        if skip_all and country == "ALL":
            continue
        if countries is not None and country not in countries:
            continue
        filename = f"guide_{country}.xml.gz"
        destination = output_directory / filename
        with tempfile.NamedTemporaryFile(
            dir=output_directory, suffix=".xml.gz.tmp", delete=False
        ) as temporary:
            with gzip.GzipFile(
                filename="", fileobj=temporary, mode="wb", mtime=0
            ) as archive:
                archive.write(xml_bytes)
            temporary_path = Path(temporary.name)
        checksum = hashlib.sha256(temporary_path.read_bytes()).hexdigest()
        os.replace(temporary_path, destination)
        checksums[f"guide_{country}"] = checksum
    return checksums


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--channels", type=Path)
    parser.add_argument("--iptv-org-channels", type=Path)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument(
        "--gzip-guides",
        action="store_true",
        help="Write guide_XX.xml.gz + manifest.json (skips ALL).",
    )
    parser.add_argument(
        "--countries",
        nargs="*",
        help="When --gzip-guides is set, only write these country shards.",
    )
    args = parser.parse_args()
    if bool(args.channels) == bool(args.iptv_org_channels):
        parser.error("provide exactly one of --channels or --iptv-org-channels")

    if args.iptv_org_channels is not None:
        channels_payload = catalog_from_iptv_org_api(
            json.loads(args.iptv_org_channels.read_text(encoding="utf-8"))
        )
    else:
        channels_payload = json.loads(args.channels.read_text(encoding="utf-8"))

    remapped = remap_epg_pw_xmltv(args.input.read_bytes(), channels_payload)

    args.output_dir.mkdir(parents=True, exist_ok=True)
    if args.gzip_guides:
        wanted = (
            {code.upper() for code in args.countries} if args.countries else None
        )
        if wanted:
            missing = sorted(code for code in wanted if code not in remapped)
            if missing:
                raise SystemExit(
                    "missing remapped guide for: " + ", ".join(missing)
                )
        checksums = write_gzip_guides(
            remapped, args.output_dir, countries=wanted
        )
        if not checksums:
            raise SystemExit("no country guides written")
        files = {key: f"{key}.xml.gz" for key in checksums}
        manifest = {"files": files, "fileChecksums": checksums}
        (args.output_dir / "manifest.json").write_text(
            json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
        )
        return

    for country, xml_bytes in remapped.items():
        (args.output_dir / f"{country}.xml").write_bytes(xml_bytes)


if __name__ == "__main__":
    main()
