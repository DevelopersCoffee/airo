import hashlib
import json
from datetime import UTC, datetime

from src.exporters.json_exporter import JsonExporter
from src.models import PipelineMetadata, ProcessedChannel
from src.utils.config import OutputConfig


def test_taxonomy_artifact_is_filtered_deterministic_and_manifested(tmp_path) -> None:
    exporter = JsonExporter(
        OutputConfig(
            directory="output",
            filenames={"json": "iptv_channels.json", "m3u": "channels.m3u"},
        ),
        tmp_path,
    )
    channel = ProcessedChannel(
        id="News.in",
        name="News",
        stream_url="https://example.com/live.m3u8",
        logo_url=None,
        category="news",
        country="IN",
        language="hi",
        flavor="general",
        group="News",
        quality_urls={},
        alt_names=[],
        headers=None,
        sources=["iptv_org"],
    )
    metadata = PipelineMetadata(
        version="2026.07.27",
        generated_at=datetime(2026, 7, 27, tzinfo=UTC),
        checksum="",
        total_channels=1,
        channels_by_country={"IN": 1},
        channels_by_category={"news": 1},
        channels_by_flavor={"general": 1},
        sources_used=["iptv_org"],
        dead_streams_removed=0,
        duplicates_merged=0,
        processing_time_seconds=1,
    )
    exporter.export(
        [channel],
        metadata,
        taxonomies={
            "categories": [
                {"id": "sports", "name": "Sports", "description": "Sports"},
                {"id": "news", "name": "News", "description": "News"},
            ],
            "countries": [
                {"code": "US", "name": "United States", "languages": ["eng"], "flag": "🇺🇸"},
                {"code": "IN", "name": "India", "languages": ["hin"], "flag": "🇮🇳"},
            ],
            "regions": [{"code": "ASIA", "name": "Asia", "countries": ["IN"]}],
            "languages": [{"code": "hin", "name": "Hindi"}],
        },
    )

    taxonomy = json.loads((tmp_path / "output/current/taxonomies.json").read_text(encoding="utf-8"))
    manifest = json.loads((tmp_path / "output/current/manifest.json").read_text(encoding="utf-8"))
    assert [row["id"] for row in taxonomy["categories"]] == ["news", "sports"]
    assert [row["code"] for row in taxonomy["countries"]] == ["IN"]
    canonical = json.dumps(
        {key: taxonomy[key] for key in ("categories", "countries", "regions", "languages")},
        sort_keys=True,
        ensure_ascii=False,
        separators=(",", ":"),
    )
    assert taxonomy["checksum"] == hashlib.sha256(canonical.encode()).hexdigest()
    assert manifest["files"]["taxonomies"] == "taxonomies.json"
    assert manifest["fileChecksums"]["taxonomies"] == taxonomy["checksum"]
