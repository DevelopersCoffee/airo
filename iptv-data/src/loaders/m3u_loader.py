"""M3U playlist loader and parser."""

import re
from typing import Any

import aiohttp

from ..models import ChannelHeaders, RawChannel, SourceType
from ..utils import get_logger
from ..utils.config import SourceConfig
from .base_loader import BaseLoader, LoaderError

logger = get_logger(__name__)

# M3U parsing patterns
EXTINF_PATTERN = re.compile(
    r'#EXTINF:(-?\d+)\s*'
    r'(?:([^,]*?))?,\s*'
    r'(.+?)$',
    re.MULTILINE
)
ATTR_PATTERN = re.compile(r'(\w+[-\w]*)="([^"]*)"')


class M3ULoader(BaseLoader):
    """Loader for M3U playlists."""

    def __init__(self, config: SourceConfig) -> None:
        """Initialize M3U loader."""
        super().__init__(config)
        self.urls = config.urls or []
        self.retry_config = config.retry or {}

    def get_source_name(self) -> str:
        """Get source name."""
        return "M3U Playlist"

    async def load(self) -> list[RawChannel]:
        """Load channels from all configured M3U sources."""
        if not self.is_enabled:
            logger.info("M3U loader is disabled")
            return []

        all_channels: list[RawChannel] = []

        for url_config in self.urls:
            url = url_config.get("url", "")
            name = url_config.get("name", url)
            timeout = url_config.get("timeout_seconds", 30)

            try:
                content = await self._fetch_m3u(url, timeout)
                channels = self._parse_m3u(content)
                logger.info(f"Loaded {len(channels)} channels from {name}")
                all_channels.extend(channels)
            except Exception as e:
                logger.error(f"Failed to load M3U from {name}: {e}")
                raise LoaderError(f"Failed to load M3U: {e}", "m3u", e) from e

        return all_channels

    async def _fetch_m3u(self, url: str, timeout: int) -> str:
        """Fetch M3U content from URL."""
        async with aiohttp.ClientSession() as session:
            async with session.get(
                url,
                timeout=aiohttp.ClientTimeout(total=timeout),
                headers={"User-Agent": "IPTV-Sanity-Agent/1.0"},
            ) as response:
                response.raise_for_status()
                return await response.text()

    def _parse_m3u(self, content: str) -> list[RawChannel]:
        """Parse M3U content into RawChannel objects."""
        channels: list[RawChannel] = []
        lines = content.strip().split("\n")

        current_attrs: dict[str, Any] = {}
        current_name = ""

        for line in lines:
            line = line.strip()

            if line.startswith("#EXTINF:"):
                # Parse EXTINF line
                current_attrs, current_name = self._parse_extinf(line)

            elif line and not line.startswith("#"):
                # This is the URL line
                if current_name:
                    channel = self._create_channel(current_name, line, current_attrs)
                    channels.append(channel)

                # Reset for next channel
                current_attrs = {}
                current_name = ""

        return channels

    def _parse_extinf(self, line: str) -> tuple[dict[str, Any], str]:
        """Parse EXTINF line and extract attributes and name."""
        attrs: dict[str, Any] = {}
        name = ""

        # Extract attributes like tvg-id="...", tvg-name="...", etc.
        for match in ATTR_PATTERN.finditer(line):
            key = match.group(1).lower().replace("-", "_")
            value = match.group(2)
            attrs[key] = value

        # Extract channel name (after the comma)
        comma_idx = line.rfind(",")
        if comma_idx != -1:
            name = line[comma_idx + 1:].strip()

        return attrs, name

    def _create_channel(
        self, name: str, url: str, attrs: dict[str, Any]
    ) -> RawChannel:
        """Create RawChannel from parsed data."""
        headers = None
        if attrs.get("http_user_agent") or attrs.get("http_referrer"):
            headers = ChannelHeaders(
                user_agent=attrs.get("http_user_agent"),
                referrer=attrs.get("http_referrer"),
            )

        return RawChannel(
            name=name,
            stream_url=url,
            source=SourceType.M3U,
            tvg_id=attrs.get("tvg_id"),
            tvg_name=attrs.get("tvg_name"),
            tvg_logo=attrs.get("tvg_logo"),
            group_title=attrs.get("group_title"),
            country=attrs.get("tvg_country"),
            language=attrs.get("tvg_language"),
            headers=headers,
            extra_attrs=attrs,
        )

