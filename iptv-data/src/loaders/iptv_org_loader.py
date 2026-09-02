"""IPTV-org API loader."""

from typing import Any, cast

import aiohttp

from ..models import ChannelHeaders, RawChannel, SourceType
from ..utils import get_logger
from ..utils.config import SourceConfig
from .base_loader import BaseLoader, LoaderError

logger = get_logger(__name__)


class UpstreamSchemaError(ValueError):
    """Consumed IPTV-org payload no longer matches the expected contract."""


class IptvOrgLoader(BaseLoader):
    """Loader for IPTV-org API data."""

    def __init__(
        self,
        config: SourceConfig,
        target_countries: list[str] | None = None,
        *,
        filter_nsfw: bool = True,
    ) -> None:
        """Initialize IPTV-org loader."""
        super().__init__(config)
        self.base_url = config.base_url or "https://iptv-org.github.io/api"
        self.endpoints = config.endpoints or {
            "channels": "/channels.json",
            "streams": "/streams.json",
            "blocklist": "/blocklist.json",
            "logos": "/logos.json",
            "feeds": "/feeds.json",
        }
        self.target_countries = target_countries or ["IN", "US", "GB"]
        self.filter_nsfw = filter_nsfw
        self._channels_data: list[dict[str, Any]] = []
        self._streams_data: list[dict[str, Any]] = []
        self._logos_data: list[dict[str, Any]] = []
        self._feeds_data: list[dict[str, Any]] = []
        self._blocklist: dict[str, str] = {}
        self.drop_counts = {"dmca": 0, "nsfw": 0, "closed": 0, "replaced": 0}
        self.taxonomies: dict[str, list[dict[str, Any]]] = {}

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
        """Fetch and validate one coherent upstream snapshot."""
        async with aiohttp.ClientSession() as session:
            payloads = {}
            for endpoint in ("channels", "streams", "blocklist", "logos", "feeds"):
                payloads[endpoint] = await self._fetch_json(
                    session, f"{self.base_url}{self.endpoints[endpoint]}"
                )
                self._validate_schema(endpoint, payloads[endpoint])
                logger.info(f"Fetched {len(payloads[endpoint])} {endpoint} from IPTV-org")
            self._channels_data = payloads["channels"]
            self._streams_data = payloads["streams"]
            self._logos_data = payloads["logos"]
            self._feeds_data = payloads["feeds"]
            self._blocklist = {
                str(item["channel"]): str(item["reason"]).lower() for item in payloads["blocklist"]
            }

            for endpoint in (
                "categories",
                "countries",
                "regions",
                "languages",
            ):
                path = self.endpoints.get(endpoint, f"/{endpoint}.json")
                self.taxonomies[endpoint] = await self._fetch_json(
                    session, f"{self.base_url}{path}"
                )

    async def _fetch_json(self, session: aiohttp.ClientSession, url: str) -> list[dict[str, Any]]:
        """Fetch JSON data from URL."""
        async with session.get(
            url,
            timeout=aiohttp.ClientTimeout(total=60),
            headers={"User-Agent": "IPTV-Sanity-Agent/1.0"},
        ) as response:
            response.raise_for_status()
            return cast(list[dict[str, Any]], await response.json())

    def _validate_schema(
        self, endpoint: str, rows: list[dict[str, Any]], sample_size: int = 100
    ) -> None:
        specs: dict[str, dict[str, tuple[type, ...]]] = {
            "channels": {
                "id": (str,),
                "name": (str,),
                "country": (str,),
                "categories": (list,),
                "is_nsfw": (bool,),
                "closed": (str, type(None)),
                "replaced_by": (str, type(None)),
            },
            "streams": {
                "channel": (str, type(None)),
                "feed": (str, type(None)),
                "url": (str,),
                "quality": (str, type(None)),
                "user_agent": (str, type(None)),
                "referrer": (str, type(None)),
            },
            "blocklist": {"channel": (str,), "reason": (str,)},
            "logos": {
                "channel": (str,),
                "feed": (str, type(None)),
                "in_use": (bool,),
                "width": (int,),
                "height": (int,),
                "format": (str, type(None)),
                "url": (str,),
            },
            "feeds": {
                "channel": (str,),
                "id": (str,),
                "is_main": (bool,),
                "languages": (list,),
                "format": (str, type(None)),
                "timezones": (list,),
            },
        }
        expected = specs[endpoint]
        for index, row in enumerate(rows[:sample_size]):
            missing = sorted(set(expected) - set(row))
            wrong = sorted(
                key
                for key, types in expected.items()
                if key in row and not isinstance(row[key], types)
            )
            if missing or wrong:
                details = []
                if missing:
                    details.append(f"missing {missing}")
                if wrong:
                    details.append(f"wrong_type {wrong}")
                raise UpstreamSchemaError(
                    f"{endpoint}.json schema drift at row {index}: " + ", ".join(details)
                )
            unexpected = sorted(set(row) - set(expected))
            if unexpected:
                logger.info(
                    f"{endpoint}.json schema additions at row {index}: unexpected {unexpected}"
                )

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
        feed_lookup: dict[str, list[dict[str, Any]]] = {}
        for feed in self._feeds_data:
            feed_lookup.setdefault(str(feed["channel"]), []).append(feed)
        logo_lookup: dict[str, list[dict[str, Any]]] = {}
        for logo in self._logos_data:
            if logo["in_use"]:
                logo_lookup.setdefault(str(logo["channel"]), []).append(logo)
        channel_ids = {str(channel["id"]) for channel in self._channels_data}
        replacement_ids = {
            str(channel["replaced_by"])
            for channel in self._channels_data
            if channel.get("replaced_by") in channel_ids
        }

        channels: list[RawChannel] = []
        self.drop_counts = {"dmca": 0, "nsfw": 0, "closed": 0, "replaced": 0}

        for channel_data in self._channels_data:
            channel_id = channel_data.get("id", "")

            block_reason = self._blocklist.get(channel_id)
            if block_reason == "dmca":
                self.drop_counts["dmca"] += 1
                continue
            if self.filter_nsfw and (block_reason == "nsfw" or channel_data.get("is_nsfw") is True):
                self.drop_counts["nsfw"] += 1
                continue
            if channel_data.get("closed") is not None:
                self.drop_counts["closed"] += 1
                continue
            replacement = channel_data.get("replaced_by")
            if replacement and replacement in channel_ids:
                self.drop_counts["replaced"] += 1
                logger.info(f"Redirecting closed channel {channel_id} to {replacement}")
                continue

            # Filter by country
            country = channel_data.get("country", "")
            if (
                channel_id not in replacement_ids
                and country
                and country.upper() not in self.target_countries
            ):
                continue

            # Get streams for this channel
            feeds = feed_lookup.get(channel_id, [])
            main_feed = next((feed for feed in feeds if feed["is_main"]), None)
            selected_feed = main_feed or (feeds[0] if feeds else None)
            streams = sorted(
                stream_lookup.get(channel_id, []),
                key=lambda stream: self._stream_rank(stream, main_feed),
            )
            if not streams:
                continue  # Skip channels without streams

            selected_logo = self._select_logo(logo_lookup.get(channel_id, []))
            for stream in streams:
                stream_url = stream.get("url", "")
                if not stream_url:
                    continue
                channel = RawChannel(
                    name=channel_data.get("name", ""),
                    stream_url=stream_url,
                    source=SourceType.IPTV_ORG,
                    tvg_id=channel_id,
                    tvg_name=channel_data.get("name"),
                    tvg_logo=selected_logo,
                    group_title=", ".join(channel_data.get("categories", [])),
                    country=country,
                    language=", ".join(selected_feed.get("languages", []) if selected_feed else []),
                    headers=(
                        ChannelHeaders(
                            user_agent=stream.get("user_agent"),
                            referrer=stream.get("referrer"),
                        )
                        if stream.get("user_agent") or stream.get("referrer")
                        else None
                    ),
                    extra_attrs={
                        "iptv_org_id": channel_id,
                        "feed_id": stream.get("feed"),
                        "is_main_feed": (
                            main_feed is not None and stream.get("feed") == main_feed.get("id")
                        ),
                        "alt_names": channel_data.get("alt_names", []),
                        "categories": channel_data.get("categories", []),
                        "is_nsfw": channel_data.get("is_nsfw", False),
                        "network": channel_data.get("network"),
                        "owners": channel_data.get("owners", []),
                        "website": channel_data.get("website"),
                        "status": stream.get("status"),
                        "quality": stream.get("quality"),
                        "format": selected_feed.get("format") if selected_feed else None,
                        "timezones": (selected_feed.get("timezones", []) if selected_feed else []),
                        "width": stream.get("width"),
                        "height": stream.get("height")
                        or self._quality_height(stream.get("quality")),
                        "bitrate": stream.get("bitrate"),
                        "fps": stream.get("fps"),
                    },
                )
                channels.append(channel)

        logger.info(
            "IPTV-org policy drops: "
            + ", ".join(f"{reason}={count}" for reason, count in self.drop_counts.items())
        )
        return channels

    def _stream_rank(
        self, stream: dict[str, Any], main_feed: dict[str, Any] | None
    ) -> tuple[int, int]:
        main_feed_id = main_feed.get("id") if main_feed else None
        return (
            0 if main_feed_id and stream.get("feed") == main_feed_id else 1,
            -self._quality_height(stream.get("quality")),
        )

    def _quality_height(self, value: object) -> int:
        if not isinstance(value, str):
            return 0
        digits = "".join(character for character in value if character.isdigit())
        return int(digits) if digits else (2160 if value.lower() == "4k" else 0)

    def _select_logo(self, logos: list[dict[str, Any]]) -> str | None:
        format_rank = {"svg": 0, "png": 1, "webp": 2, "jpeg": 3, "jpg": 3}
        if not logos:
            return None
        selected = min(
            logos,
            key=lambda logo: (
                0 if logo["feed"] is None else 1,
                format_rank.get(str(logo["format"]).lower(), 99),
                -(int(logo["width"]) * int(logo["height"])),
                str(logo["url"]),
            ),
        )
        return str(selected["url"])
