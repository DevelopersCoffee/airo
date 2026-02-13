"""IPTV-org API loader."""

from typing import Any

import aiohttp

from ..models import RawChannel, SourceType
from ..utils import get_logger
from ..utils.config import SourceConfig
from .base_loader import BaseLoader, LoaderError

logger = get_logger(__name__)


class IptvOrgLoader(BaseLoader):
    """Loader for IPTV-org API data."""

    def __init__(self, config: SourceConfig, target_countries: list[str] | None = None) -> None:
        """Initialize IPTV-org loader."""
        super().__init__(config)
        self.base_url = config.base_url or "https://iptv-org.github.io/api"
        self.endpoints = config.endpoints or {
            "channels": "/channels.json",
            "streams": "/streams.json",
            "blocklist": "/blocklist.json",
        }
        self.target_countries = target_countries or ["IN", "US", "GB"]
        self._channels_data: list[dict[str, Any]] = []
        self._streams_data: list[dict[str, Any]] = []
        self._blocklist: set[str] = set()

    def get_source_name(self) -> str:
        """Get source name."""
        return "IPTV-org API"

    async def load(self) -> list[RawChannel]:
        """Load channels from IPTV-org API."""
        if not self.is_enabled:
            logger.info("IPTV-org loader is disabled")
            return []

        try:
            # Fetch all data
            await self._fetch_all_data()

            # Filter and process channels
            channels = self._process_channels()
            logger.info(f"Loaded {len(channels)} channels from IPTV-org API")
            return channels

        except Exception as e:
            logger.error(f"Failed to load from IPTV-org: {e}")
            raise LoaderError(f"Failed to load from IPTV-org: {e}", "iptv_org", e) from e

    async def _fetch_all_data(self) -> None:
        """Fetch channels, streams, and blocklist data."""
        async with aiohttp.ClientSession() as session:
            # Fetch channels
            channels_url = f"{self.base_url}{self.endpoints['channels']}"
            self._channels_data = await self._fetch_json(session, channels_url)
            logger.info(f"Fetched {len(self._channels_data)} channels from IPTV-org")

            # Fetch streams
            streams_url = f"{self.base_url}{self.endpoints['streams']}"
            self._streams_data = await self._fetch_json(session, streams_url)
            logger.info(f"Fetched {len(self._streams_data)} streams from IPTV-org")

            # Fetch blocklist
            blocklist_url = f"{self.base_url}{self.endpoints['blocklist']}"
            blocklist_data = await self._fetch_json(session, blocklist_url)
            self._blocklist = {item.get("channel", "") for item in blocklist_data}
            logger.info(f"Fetched {len(self._blocklist)} blocked channels from IPTV-org")

    async def _fetch_json(
        self, session: aiohttp.ClientSession, url: str
    ) -> list[dict[str, Any]]:
        """Fetch JSON data from URL."""
        async with session.get(
            url,
            timeout=aiohttp.ClientTimeout(total=60),
            headers={"User-Agent": "IPTV-Sanity-Agent/1.0"},
        ) as response:
            response.raise_for_status()
            return await response.json()

    def _process_channels(self) -> list[RawChannel]:
        """Process and filter channels."""
        # Build stream lookup by channel ID
        stream_lookup: dict[str, list[dict[str, Any]]] = {}
        for stream in self._streams_data:
            channel_id = stream.get("channel", "")
            if channel_id:
                if channel_id not in stream_lookup:
                    stream_lookup[channel_id] = []
                stream_lookup[channel_id].append(stream)

        channels: list[RawChannel] = []

        for channel_data in self._channels_data:
            channel_id = channel_data.get("id", "")

            # Skip blocked channels
            if channel_id in self._blocklist:
                continue

            # Filter by country
            country = channel_data.get("country", "")
            if country and country.upper() not in self.target_countries:
                continue

            # Get streams for this channel
            streams = stream_lookup.get(channel_id, [])
            if not streams:
                continue  # Skip channels without streams

            # Use first available stream
            stream = streams[0]
            stream_url = stream.get("url", "")
            if not stream_url:
                continue

            channel = RawChannel(
                name=channel_data.get("name", ""),
                stream_url=stream_url,
                source=SourceType.IPTV_ORG,
                tvg_id=channel_id,
                tvg_name=channel_data.get("name"),
                tvg_logo=channel_data.get("logo"),
                group_title=", ".join(channel_data.get("categories", [])),
                country=country,
                language=", ".join(channel_data.get("languages", [])),
                extra_attrs={
                    "iptv_org_id": channel_id,
                    "categories": channel_data.get("categories", []),
                    "languages": channel_data.get("languages", []),
                    "is_nsfw": channel_data.get("is_nsfw", False),
                },
            )
            channels.append(channel)

        return channels

