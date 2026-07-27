import gzip
import hashlib
import json
import xml.etree.ElementTree as ET
from pathlib import Path

import pytest

from src.epg_artifacts import build_channels_xml, publish_country_guides


def _channels() -> dict[str, object]:
    return {
        "channels": [
            {
                "id": "News.in",
                "name": "News & More",
                "country": "IN",
                "languages": ["hi"],
                "streamSources": [{"feedId": "HD"}],
            },
            {
                "id": "World.us",
                "name": "World",
                "country": "US",
                "languages": ["en"],
                "streamSources": [],
            },
        ]
    }


def test_channels_xml_prefers_main_feed_then_language() -> None:
    xml, report = build_channels_xml(
        _channels(),
        [
            {
                "channel": "News.in",
                "feed": "SD",
                "site": "a.example",
                "site_id": "sd",
                "lang": "hi",
            },
            {
                "channel": "News.in",
                "feed": "HD",
                "site": "b.example",
                "site_id": "hd",
                "lang": "en",
            },
            {
                "channel": "World.us",
                "feed": None,
                "site": "z.example",
                "site_id": "es",
                "lang": "es",
            },
            {
                "channel": "World.us",
                "feed": None,
                "site": "y.example",
                "site_id": "en",
                "lang": "en",
            },
        ],
    )

    root = ET.fromstring(xml)
    rows = {row.get("xmltv_id"): row for row in root.findall("channel")}
    assert rows["News.in"].get("site_id") == "hd"
    assert rows["World.us"].get("site_id") == "en"
    assert rows["News.in"].text == "News & More"
    assert report == {"IN": 1, "US": 1}


def test_channels_xml_can_emit_bounded_fallback_guides() -> None:
    xml, report = build_channels_xml(
        _channels(),
        [
            {
                "channel": "News.in",
                "feed": "HD",
                "site": "b.example",
                "site_id": "preferred",
                "lang": "hi",
            },
            {
                "channel": "News.in",
                "feed": "SD",
                "site": "a.example",
                "site_id": "fallback",
                "lang": "hi",
            },
            {
                "channel": "News.in",
                "feed": "SD",
                "site": "c.example",
                "site_id": "excluded",
                "lang": "hi",
            },
        ],
        max_guides_per_channel=2,
    )

    rows = ET.fromstring(xml).findall("channel")
    assert [row.get("site_id") for row in rows] == ["preferred", "fallback"]
    assert [row.get("xmltv_id") for row in rows] == ["News.in", "News.in"]
    assert report == {"IN": 1}


def test_channels_xml_rejects_empty_guide_limit() -> None:
    with pytest.raises(ValueError, match="at least 1"):
        build_channels_xml(_channels(), [], max_guides_per_channel=0)


def test_channels_xml_can_limit_only_fallback_sites() -> None:
    xml, _ = build_channels_xml(
        _channels(),
        [
            {
                "channel": "News.in",
                "feed": "HD",
                "site": "primary.example",
                "site_id": "primary",
                "lang": "hi",
            },
            {
                "channel": "News.in",
                "feed": "SD",
                "site": "cross-region.example",
                "site_id": "excluded",
                "lang": "hi",
            },
            {
                "channel": "News.in",
                "feed": "SD",
                "site": "domestic.in",
                "site_id": "fallback",
                "lang": "hi",
            },
        ],
        max_guides_per_channel=2,
        fallback_site_suffixes=(".in",),
    )

    rows = ET.fromstring(xml).findall("channel")
    assert [row.get("site_id") for row in rows] == ["primary", "fallback"]


def test_country_filter_bounds_grab_input_and_coverage_gate(tmp_path: Path) -> None:
    guides = [
        {
            "channel": "News.in",
            "feed": "HD",
            "site": "india.example",
            "site_id": "news",
            "lang": "hi",
        },
        {
            "channel": "World.us",
            "feed": None,
            "site": "world.example",
            "site_id": "world",
            "lang": "en",
        },
    ]
    xml, report = build_channels_xml(_channels(), guides, {"IN"})

    rows = ET.fromstring(xml).findall("channel")
    assert [row.get("xmltv_id") for row in rows] == ["News.in"]
    assert report == {"IN": 1}

    grabbed = tmp_path / "guide.xml"
    grabbed.write_text(
        """<tv>
<channel id="News.in"><display-name>News</display-name></channel>
<programme channel="News.in" start="20260727000000 +0000" stop="20260727010000 +0000"><title>India</title></programme>
</tv>""",
        encoding="utf-8",
    )
    manifest = tmp_path / "manifest.json"
    manifest.write_text('{"files": {}, "fileChecksums": {}}', encoding="utf-8")

    result = publish_country_guides(
        channels_payload=_channels(),
        grabbed_xml=grabbed,
        output_directory=tmp_path,
        manifest_path=manifest,
        minimum_coverage_percent=70,
        countries={"IN"},
    )

    assert result["countries"]["IN"]["coveragePercent"] == 100
    assert "US" not in result["countries"]
    assert not (tmp_path / "guide_US.xml.gz").exists()


def test_coverage_gate_uses_guide_eligible_denominator(tmp_path: Path) -> None:
    channels = _channels()
    channels["channels"].append(
        {
            "id": "NoGuide.in",
            "name": "No Guide",
            "country": "IN",
            "languages": ["en"],
            "streamSources": [],
        }
    )
    eligible = tmp_path / "channels.xml"
    eligible.write_text(
        '<channels><channel xmltv_id="News.in"/></channels>',
        encoding="utf-8",
    )
    grabbed = tmp_path / "guide.xml"
    grabbed.write_text(
        """<tv>
<channel id="News.in"><display-name>News</display-name></channel>
<programme channel="News.in" start="20260727000000 +0000" stop="20260727010000 +0000"><title>India</title></programme>
</tv>""",
        encoding="utf-8",
    )
    manifest = tmp_path / "manifest.json"
    manifest.write_text('{"files": {}, "fileChecksums": {}}', encoding="utf-8")

    result = publish_country_guides(
        channels_payload=channels,
        grabbed_xml=grabbed,
        output_directory=tmp_path,
        manifest_path=manifest,
        minimum_coverage_percent=70,
        countries={"IN"},
        eligible_channels_xml=eligible,
    )

    report = result["countries"]["IN"]
    assert report["coveragePercent"] == 100
    assert report["curatedCoveragePercent"] == 50
    assert report["guideEligibilityPercent"] == 50
    assert report["eligibleChannels"] == 1
    assert report["curatedChannels"] == 2


def test_publish_splits_gzip_and_updates_manifest(tmp_path: Path) -> None:
    grabbed = tmp_path / "guide.xml"
    grabbed.write_text(
        """<tv>
<channel id="News.in"><display-name>News</display-name></channel>
<channel id="World.us"><display-name>World</display-name></channel>
<programme channel="News.in" start="20260727000000 +0000" stop="20260727010000 +0000"><title>India</title></programme>
<programme channel="World.us" start="20260727000000 +0000" stop="20260727010000 +0000"><title>World</title></programme>
</tv>""",
        encoding="utf-8",
    )
    manifest = tmp_path / "manifest.json"
    manifest.write_text('{"files": {}, "fileChecksums": {}}', encoding="utf-8")

    report = publish_country_guides(
        channels_payload=_channels(),
        grabbed_xml=grabbed,
        output_directory=tmp_path,
        manifest_path=manifest,
    )

    for country, channel_id in (("IN", "News.in"), ("US", "World.us")):
        path = tmp_path / f"guide_{country}.xml.gz"
        root = ET.fromstring(gzip.decompress(path.read_bytes()))
        assert root.find(f"./programme[@channel='{channel_id}']") is not None
        payload = json.loads(manifest.read_text(encoding="utf-8"))
        assert (
            payload["fileChecksums"][f"guide_{country}"]
            == hashlib.sha256(path.read_bytes()).hexdigest()
        )
    assert report["totalProgrammes"] == 2


def test_zero_programmes_keeps_existing_artifact_and_manifest(tmp_path: Path) -> None:
    grabbed = tmp_path / "empty.xml"
    grabbed.write_text("<tv/>", encoding="utf-8")
    guide = tmp_path / "guide_IN.xml.gz"
    guide.write_bytes(b"existing")
    manifest = tmp_path / "manifest.json"
    manifest.write_text('{"version": "existing"}', encoding="utf-8")

    with pytest.raises(ValueError, match="programme gate failed"):
        publish_country_guides(
            channels_payload=_channels(),
            grabbed_xml=grabbed,
            output_directory=tmp_path,
            manifest_path=manifest,
        )

    assert guide.read_bytes() == b"existing"
    assert json.loads(manifest.read_text(encoding="utf-8")) == {"version": "existing"}
