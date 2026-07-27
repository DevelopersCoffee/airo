"""Bounded ffprobe-backed stream health enrichment."""

import asyncio
import json
import re
from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from typing import Any

from ..models import ProcessedChannel
from ..utils.config import StreamHealthConfig

ProbeRunner = Callable[[str, dict[str, str], float], Awaitable[dict[str, Any]]]


@dataclass(frozen=True)
class StreamHealthSummary:
    """Low-cardinality stage outcome used by CI logs and tests."""

    available: int = 0
    restricted: int = 0
    unavailable: int = 0
    unchecked: int = 0


class StreamHealthProcessor:
    """Adds authoritative media facts without dropping any source."""

    def __init__(
        self,
        config: StreamHealthConfig,
        runner: ProbeRunner | None = None,
    ) -> None:
        self.config = config
        self._runner = runner or self._run_ffprobe

    async def enrich(
        self, channels: list[ProcessedChannel]
    ) -> tuple[list[ProcessedChannel], StreamHealthSummary]:
        """Probe sources within concurrency and global time budgets."""
        semaphore = asyncio.Semaphore(max(1, self.config.max_concurrent))
        sources = [
            (channel, source)
            for channel in channels
            for source in channel.stream_sources
        ]

        async def inspect(
            channel: ProcessedChannel, source: dict[str, Any]
        ) -> None:
            async with semaphore:
                await self._inspect(channel, source)

        tasks = [
            asyncio.create_task(inspect(channel, source))
            for channel, source in sources
        ]
        try:
            async with asyncio.timeout(self.config.global_budget_seconds):
                await asyncio.gather(*tasks)
        except TimeoutError:
            for task in tasks:
                if not task.done():
                    task.cancel()
            await asyncio.gather(*tasks, return_exceptions=True)

        for channel in channels:
            channel.stream_sources.sort(key=self._rank)
            if channel.stream_sources:
                primary = channel.stream_sources[0]
                channel.stream_url = str(primary["url"])
                channel.is_working = primary.get("health") != "unavailable"

        counts = {"available": 0, "restricted": 0, "unavailable": 0, "unchecked": 0}
        for _, source in sources:
            status = str(source.get("health", "unchecked"))
            normalized_status = status if status in counts else "unchecked"
            source.setdefault("healthDetails", {"status": normalized_status})
            counts[normalized_status] += 1
        return channels, StreamHealthSummary(**counts)

    async def _inspect(
        self, channel: ProcessedChannel, source: dict[str, Any]
    ) -> None:
        status = str(source.get("health", "unchecked"))
        if status in {"restricted", "unavailable"}:
            source.setdefault("healthDetails", {"status": status})
            return
        headers = channel.headers.to_dict() if channel.headers else {}
        try:
            payload = await asyncio.wait_for(
                self._runner(
                    str(source["url"]),
                    headers,
                    self.config.timeout_seconds,
                ),
                timeout=self.config.timeout_seconds,
            )
            facts = self._media_facts(payload)
        except (TimeoutError, OSError, ValueError, json.JSONDecodeError):
            source["health"] = "unchecked"
            source["healthDetails"] = {"status": "unchecked"}
            return

        if facts["width"] is None or facts["height"] is None:
            source["health"] = "unchecked"
            source["healthDetails"] = {"status": "unchecked"}
            return
        advertised = self._advertised_height(source)
        actual_height = int(facts["height"])
        mislabeled = advertised is not None and advertised != actual_height
        source.update(
            {
                "health": "available",
                "videoCodec": facts["video_codec"],
                "width": facts["width"],
                "height": actual_height,
                "framesPerSecond": facts["fps"],
                "lowFramerate": (
                    facts["fps"] is not None
                    and facts["fps"] < self.config.low_framerate_threshold
                ),
                "mislabeled": mislabeled,
                "labelCorrect": not mislabeled,
                "audioCodec": facts["audio_codec"],
                "audioBitrate": facts["audio_bitrate"],
                "audioChannels": facts["audio_channels"],
                "bitrate": facts["bitrate"] if self.config.sample_bitrate else None,
                "actualQuality": f"{actual_height}p",
            }
        )
        source["healthDetails"] = {
            "status": "available",
            "video": {
                "codec": facts["video_codec"],
                "width": facts["width"],
                "height": actual_height,
                "framesPerSecond": facts["fps"],
            },
            "audio": {
                "codec": facts["audio_codec"],
                "bitrate": facts["audio_bitrate"],
                "channels": facts["audio_channels"],
            },
            "lowFramerate": source["lowFramerate"],
            "mislabeled": mislabeled,
            "actualQuality": source["actualQuality"],
            **(
                {"averageBitrate": facts["bitrate"]}
                if self.config.sample_bitrate and facts["bitrate"] is not None
                else {}
            ),
        }

    @staticmethod
    def _rank(source: dict[str, Any]) -> tuple[Any, ...]:
        status_rank = {
            "available": 0,
            "restricted": 2,
            "unchecked": 3,
            "unavailable": 4,
        }
        return (
            status_rank.get(str(source.get("health")), 3),
            source.get("mislabeled") is True,
            source.get("lowFramerate") is True,
            -float(source.get("framesPerSecond") or -1),
            -int(source.get("height") or -1),
            str(source.get("url", "")),
        )

    @staticmethod
    def _advertised_height(source: dict[str, Any]) -> int | None:
        for value in (source.get("quality"), source.get("advertisedQuality")):
            match = re.search(r"(\d{3,4})p?", str(value or ""), re.IGNORECASE)
            if match:
                return int(match.group(1))
        return None

    @staticmethod
    def _media_facts(payload: dict[str, Any]) -> dict[str, Any]:
        streams = payload.get("streams")
        if not isinstance(streams, list):
            raise ValueError("ffprobe streams missing")
        video: dict[str, Any] = next(
            (row for row in streams if row.get("codec_type") == "video"), {}
        )
        audio: dict[str, Any] = next(
            (row for row in streams if row.get("codec_type") == "audio"), {}
        )
        rate = video.get("avg_frame_rate") or video.get("r_frame_rate")
        fps = None
        if rate and str(rate) != "0/0":
            numerator, denominator = str(rate).split("/", maxsplit=1)
            if float(denominator):
                fps = float(numerator) / float(denominator)
        return {
            "video_codec": video.get("codec_name"),
            "width": video.get("width"),
            "height": video.get("height"),
            "fps": fps,
            "audio_codec": audio.get("codec_name"),
            "audio_bitrate": _optional_int(audio.get("bit_rate")),
            "audio_channels": _optional_int(audio.get("channels")),
            "bitrate": _optional_int(payload.get("format", {}).get("bit_rate")),
        }

    async def _run_ffprobe(
        self, url: str, headers: dict[str, str], timeout: float
    ) -> dict[str, Any]:
        header_value = "".join(f"{key}: {value}\r\n" for key, value in headers.items())
        command = [
            self.config.ffprobe_path,
            "-v",
            "error",
            "-show_streams",
            "-show_format",
            "-of",
            "json",
        ]
        if header_value:
            command.extend(["-headers", header_value])
        command.append(url)
        process = await asyncio.create_subprocess_exec(
            *command,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.DEVNULL,
        )
        try:
            stdout, _ = await asyncio.wait_for(
                process.communicate(), timeout=timeout
            )
        except BaseException:
            if process.returncode is None:
                process.kill()
                await process.wait()
            raise
        if process.returncode:
            raise OSError("ffprobe_failed")
        decoded = json.loads(stdout)
        if not isinstance(decoded, dict):
            raise ValueError("ffprobe root must be an object")
        return dict(decoded)


def _optional_int(value: object) -> int | None:
    try:
        if isinstance(value, int):
            return value
        if isinstance(value, (str, bytes, bytearray)):
            return int(value)
        return None
    except (TypeError, ValueError):
        return None
