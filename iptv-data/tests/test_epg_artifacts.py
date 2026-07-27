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
