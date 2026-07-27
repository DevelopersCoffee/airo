"""Build bounded iptv-org/epg inputs and publish country guide artifacts."""

import argparse
import gzip
import hashlib
import json
import os
import tempfile
import xml.etree.ElementTree as ET
from collections import defaultdict
from pathlib import Path
from typing import Any


def build_channels_xml(
    channels_payload: dict[str, Any],
    guides: list[dict[str, Any]],
    countries: set[str] | None = None,
    max_guides_per_channel: int = 1,
    fallback_site_suffixes: tuple[str, ...] = (),
) -> tuple[bytes, dict[str, int]]:
    """Join curated channels to a bounded number of deterministic guide rows."""
    if max_guides_per_channel < 1:
        raise ValueError("max_guides_per_channel must be at least 1")
    selected_countries = {country.upper() for country in countries or set()}
    channels = {
        str(channel["id"]): channel
        for channel in channels_payload.get("channels", [])
        if channel.get("id")
        and (
            not selected_countries
            or str(channel.get("country") or "ZZ").upper() in selected_countries
        )
    }
    guides_by_channel: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for guide in guides:
        channel_id = guide.get("channel")
        if channel_id in channels:
            guides_by_channel[str(channel_id)].append(guide)

    root = ET.Element("channels")
    matched_by_country: dict[str, int] = defaultdict(int)
    for channel_id in sorted(channels):
        channel = channels[channel_id]
        candidates = guides_by_channel.get(channel_id, [])
        if not candidates:
            continue
        languages = {str(language).lower() for language in channel.get("languages", [])}
        stream_sources = channel.get("streamSources") or []
        preferred_feed = stream_sources[0].get("feedId") if stream_sources else None
        ranked = sorted(
            candidates,
            key=lambda guide: (
                0 if preferred_feed is not None and guide.get("feed") == preferred_feed else 1,
                0 if str(guide.get("lang", "")).lower() in languages else 1,
                str(guide.get("site", "")),
                str(guide.get("site_id", "")),
            ),
        )
        selected = ranked[:1]
        fallback_candidates = ranked[1:]
        if fallback_site_suffixes:
            fallback_candidates = [
                guide
                for guide in fallback_candidates
                if str(guide.get("site", "")).endswith(fallback_site_suffixes)
            ]
        selected.extend(fallback_candidates[: max_guides_per_channel - 1])
        for guide in selected:
            element = ET.SubElement(
                root,
                "channel",
                {
                    "site": str(guide["site"]),
                    "lang": str(guide.get("lang") or "en"),
                    "xmltv_id": channel_id,
                    "site_id": str(guide["site_id"]),
                },
            )
            element.text = str(channel.get("name") or channel_id)
        matched_by_country[str(channel.get("country") or "ZZ").upper()] += 1
    ET.indent(root, space="  ")
    return (
        ET.tostring(root, encoding="utf-8", xml_declaration=True),
        dict(sorted(matched_by_country.items())),
    )


def publish_country_guides(
    *,
    channels_payload: dict[str, Any],
    grabbed_xml: Path,
    output_directory: Path,
    manifest_path: Path,
    minimum_programmes: int = 1,
    minimum_coverage_percent: float = 0,
    countries: set[str] | None = None,
) -> dict[str, Any]:
    """Split one grabbed XMLTV file and atomically publish gzip artifacts."""
    selected_countries = {country.upper() for country in countries or set()}
    channel_country = {
        str(channel["id"]): str(channel.get("country") or "ZZ").upper()
        for channel in channels_payload.get("channels", [])
        if channel.get("id")
        and (
            not selected_countries
            or str(channel.get("country") or "ZZ").upper() in selected_countries
        )
    }
    roots: dict[str, ET.Element] = {}
    covered_channels: dict[str, set[str]] = defaultdict(set)
    programme_counts: dict[str, int] = defaultdict(int)
    parsed_root = ET.parse(grabbed_xml).getroot()
    channel_elements = {
        str(element.get("id")): element
        for element in parsed_root.findall("channel")
        if element.get("id")
    }
    for programme in parsed_root.findall("programme"):
        channel_id = str(programme.get("channel") or "")
        country = channel_country.get(channel_id)
        if country is None:
            continue
        root = roots.setdefault(country, ET.Element("tv"))
        root.append(ET.fromstring(ET.tostring(programme, encoding="utf-8")))
        covered_channels[country].add(channel_id)
        programme_counts[country] += 1
    total_programmes = sum(programme_counts.values())
    if total_programmes < minimum_programmes:
        raise ValueError(f"EPG programme gate failed: {total_programmes} < {minimum_programmes}")
    curated_counts: dict[str, int] = defaultdict(int)
    for country in channel_country.values():
        curated_counts[country] += 1
    for country, curated_count in curated_counts.items():
        coverage = 100 * len(covered_channels[country]) / curated_count if curated_count else 0
        if coverage < minimum_coverage_percent:
            raise ValueError(
                f"EPG coverage gate failed for {country}: "
                f"{coverage:.2f}% < {minimum_coverage_percent:.2f}%"
            )

    output_directory.mkdir(parents=True, exist_ok=True)
    prepared: dict[str, tuple[Path, str]] = {}
    for country, root in sorted(roots.items()):
        for channel_id in sorted(covered_channels[country], reverse=True):
            channel = channel_elements.get(channel_id)
            if channel is not None:
                root.insert(0, ET.fromstring(ET.tostring(channel, encoding="utf-8")))
        xml_bytes = ET.tostring(root, encoding="utf-8", xml_declaration=True)
        with tempfile.NamedTemporaryFile(
            dir=output_directory, suffix=".xml.gz.tmp", delete=False
        ) as temporary:
            with gzip.GzipFile(filename="", fileobj=temporary, mode="wb", mtime=0) as archive:
                archive.write(xml_bytes)
            temporary_path = Path(temporary.name)
        checksum = hashlib.sha256(temporary_path.read_bytes()).hexdigest()
        prepared[country] = (temporary_path, checksum)

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    files = manifest.setdefault("files", {})
    checksums = manifest.setdefault("fileChecksums", {})
    try:
        for country, (temporary_path, checksum) in prepared.items():
            filename = f"guide_{country}.xml.gz"
            os.replace(temporary_path, output_directory / filename)
            files[f"guide_{country}"] = filename
            checksums[f"guide_{country}"] = checksum
        _atomic_write_json(manifest_path, manifest)
    finally:
        for temporary_path, _ in prepared.values():
            temporary_path.unlink(missing_ok=True)

    return {
        "totalProgrammes": total_programmes,
        "countries": {
            country: {
                "programmes": programme_counts[country],
                "coveredChannels": len(covered_channels[country]),
                "curatedChannels": curated_counts[country],
                "coveragePercent": round(
                    100 * len(covered_channels[country]) / curated_counts[country],
                    2,
                )
                if curated_counts[country]
                else 0,
            }
            for country in sorted(programme_counts)
        },
    }


def _atomic_write_json(path: Path, payload: dict[str, Any]) -> None:
    with tempfile.NamedTemporaryFile(
        dir=path.parent, suffix=".json.tmp", mode="w", encoding="utf-8", delete=False
    ) as temporary:
        json.dump(payload, temporary, indent=2, ensure_ascii=False)
        temporary.write("\n")
        temporary_path = Path(temporary.name)
    os.replace(temporary_path, path)


def _load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> None:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    generate = subparsers.add_parser("generate")
    generate.add_argument("--channels", type=Path, required=True)
    generate.add_argument("--guides", type=Path, required=True)
    generate.add_argument("--output", type=Path, required=True)
    generate.add_argument("--countries", nargs="+")
    generate.add_argument("--max-guides-per-channel", type=int, default=1)
    generate.add_argument("--fallback-site-suffixes", nargs="+")
    publish = subparsers.add_parser("publish")
    publish.add_argument("--channels", type=Path, required=True)
    publish.add_argument("--grabbed", type=Path, required=True)
    publish.add_argument("--output-directory", type=Path, required=True)
    publish.add_argument("--manifest", type=Path, required=True)
    publish.add_argument("--minimum-programmes", type=int, default=1)
    publish.add_argument("--minimum-coverage-percent", type=float, default=0)
    publish.add_argument("--countries", nargs="+")
    args = parser.parse_args()
    channels_payload = _load_json(args.channels)
    if args.command == "generate":
        xml, report = build_channels_xml(
            channels_payload,
            _load_json(args.guides),
            set(args.countries or []),
            args.max_guides_per_channel,
            tuple(args.fallback_site_suffixes or []),
        )
        args.output.write_bytes(xml)
        print(json.dumps(report, sort_keys=True))
    else:
        report = publish_country_guides(
            channels_payload=channels_payload,
            grabbed_xml=args.grabbed,
            output_directory=args.output_directory,
            manifest_path=args.manifest,
            minimum_programmes=args.minimum_programmes,
            minimum_coverage_percent=args.minimum_coverage_percent,
            countries=set(args.countries or []),
        )
        print(json.dumps(report, sort_keys=True))


if __name__ == "__main__":
    main()
