import asyncio

import pytest

from src.models import ProcessedChannel
from src.processors.stream_health import StreamHealthProcessor
from src.utils.config import StreamHealthConfig


def _channel(sources: list[dict[str, object]]) -> ProcessedChannel:
    return ProcessedChannel(
        id="sports.in",
        name="Sports",
        stream_url=str(sources[0]["url"]),
        logo_url=None,
        category="sports",
        country="IN",
        language="en",
        flavor="general",
        group="Sports",
        quality_urls={},
        alt_names=[],
        headers=None,
        sources=["iptv_org"],
        stream_sources=sources,
    )


def _probe(height: int, rate: str = "30000/1001") -> dict[str, object]:
    return {
        "streams": [
            {
                "codec_type": "video",
                "codec_name": "h264",
                "width": 1920 if height == 1080 else 1280,
                "height": height,
                "avg_frame_rate": rate,
            },
            {
                "codec_type": "audio",
                "codec_name": "aac",
                "bit_rate": "128000",
                "channels": 2,
            },
        ],
        "format": {"bit_rate": "2500000"},
    }


@pytest.mark.asyncio
async def test_actual_media_facts_flag_and_deprioritize_bad_label_and_fps() -> None:
    payloads = {
        "https://example.test/mislabeled": _probe(1080, "25/1"),
        "https://example.test/healthy": _probe(720),
    }

    async def runner(
        url: str, _headers: dict[str, str], _timeout: float
    ) -> dict[str, object]:
        return payloads[url]

    channel = _channel(
        [
            {
                "url": "https://example.test/mislabeled",
                "health": "unchecked",
                "advertisedQuality": "720p",
            },
            {
                "url": "https://example.test/healthy",
                "health": "unchecked",
                "advertisedQuality": "720p",
            },
        ]
    )
    channels, summary = await StreamHealthProcessor(
        StreamHealthConfig(enabled=True), runner
    ).enrich([channel])

    healthy, mislabeled = channels[0].stream_sources
    assert healthy["url"] == "https://example.test/healthy"
    assert healthy["healthDetails"]["status"] == "available"
    assert mislabeled["actualQuality"] == "1080p"
    assert mislabeled["mislabeled"] is True
    assert mislabeled["lowFramerate"] is True
    assert summary.available == 2


@pytest.mark.asyncio
async def test_restricted_is_retained_and_probe_failure_is_unchecked() -> None:
    async def runner(
        _url: str, _headers: dict[str, str], _timeout: float
    ) -> dict[str, object]:
        raise OSError("fixture failure")

    channel = _channel(
        [
            {"url": "https://example.test/geo", "health": "restricted"},
            {"url": "https://example.test/error", "health": "unchecked"},
        ]
    )
    channels, summary = await StreamHealthProcessor(
        StreamHealthConfig(enabled=True), runner
    ).enrich([channel])

    assert len(channels[0].stream_sources) == 2
    assert {row["health"] for row in channels[0].stream_sources} == {
        "restricted",
        "unchecked",
    }
    assert summary.restricted == 1
    assert summary.unchecked == 1


@pytest.mark.asyncio
async def test_global_budget_cancels_work_and_leaves_unchecked() -> None:
    async def runner(
        _url: str, _headers: dict[str, str], _timeout: float
    ) -> dict[str, object]:
        await asyncio.sleep(1)
        return _probe(720)

    channel = _channel(
        [{"url": "https://example.test/slow", "health": "unchecked"}]
    )
    _, summary = await StreamHealthProcessor(
        StreamHealthConfig(
            enabled=True,
            timeout_seconds=1,
            global_budget_seconds=0.01,
        ),
        runner,
    ).enrich([channel])

    assert summary.unchecked == 1
