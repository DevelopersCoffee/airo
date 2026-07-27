"""Tests for source loaders."""

from pathlib import Path

import pytest

from src.loaders.iptv_org_loader import IptvOrgLoader, UpstreamSchemaError
from src.loaders.m3u_loader import M3ULoader
from src.models import SourceType
from src.utils.config import SourceConfig


class TestM3ULoader:
    """Tests for M3U loader."""

    def test_parse_m3u_basic(self) -> None:
        """Test parsing basic M3U content."""
        loader = M3ULoader(SourceConfig(enabled=True))

        content = """#EXTM3U
#EXTINF:-1 tvg-id="test.channel" tvg-name="Test Channel",Test Channel
http://example.com/stream.m3u8
"""
        channels = loader._parse_m3u(content)

        assert len(channels) == 1
        assert channels[0].name == "Test Channel"
        assert channels[0].stream_url == "http://example.com/stream.m3u8"
        assert channels[0].tvg_id == "test.channel"
        assert channels[0].tvg_name == "Test Channel"
        assert channels[0].source == SourceType.M3U

    def test_parse_m3u_with_attributes(self) -> None:
        """Test parsing M3U with all attributes."""
        loader = M3ULoader(SourceConfig(enabled=True))

        content = """#EXTM3U
#EXTINF:-1 tvg-id="star.plus" tvg-name="Star Plus" tvg-logo="https://logo.com/star.png" group-title="Entertainment" tvg-country="IN" tvg-language="hi",Star Plus HD
http://example.com/star-plus.m3u8
"""
        channels = loader._parse_m3u(content)

        assert len(channels) == 1
        channel = channels[0]
        assert channel.name == "Star Plus HD"
        assert channel.tvg_id == "star.plus"
        assert channel.tvg_name == "Star Plus"
        assert channel.tvg_logo == "https://logo.com/star.png"
        assert channel.group_title == "Entertainment"
        assert channel.country == "IN"
        assert channel.language == "hi"

    def test_parse_m3u_multiple_channels(self) -> None:
        """Test parsing M3U with multiple channels."""
        loader = M3ULoader(SourceConfig(enabled=True))

        content = """#EXTM3U
#EXTINF:-1 tvg-id="ch1",Channel 1
http://example.com/ch1.m3u8
#EXTINF:-1 tvg-id="ch2",Channel 2
http://example.com/ch2.m3u8
#EXTINF:-1 tvg-id="ch3",Channel 3
http://example.com/ch3.m3u8
"""
        channels = loader._parse_m3u(content)

        assert len(channels) == 3
        assert channels[0].name == "Channel 1"
        assert channels[1].name == "Channel 2"
        assert channels[2].name == "Channel 3"

    def test_parse_m3u_with_http_headers(self) -> None:
        """Test parsing M3U with HTTP headers."""
        loader = M3ULoader(SourceConfig(enabled=True))

        content = """#EXTM3U
#EXTINF:-1 tvg-id="secure" http-user-agent="CustomAgent/1.0" http-referrer="https://refer.com",Secure Channel
http://example.com/secure.m3u8
"""
        channels = loader._parse_m3u(content)

        assert len(channels) == 1
        assert channels[0].headers is not None
        assert channels[0].headers.user_agent == "CustomAgent/1.0"
        assert channels[0].headers.referrer == "https://refer.com"

    def test_parse_sample_fixture(self) -> None:
        """Test parsing the sample M3U fixture."""
        loader = M3ULoader(SourceConfig(enabled=True))

        fixture_path = Path(__file__).parent / "fixtures" / "sample_m3u.m3u"
        with open(fixture_path, encoding="utf-8") as f:
            content = f.read()

        channels = loader._parse_m3u(content)

        assert len(channels) == 8
        assert any(c.name == "Star Plus HD" for c in channels)
        assert any(c.name == "9XM" for c in channels)
        assert any(c.name == "Sun TV" for c in channels)

    def test_parse_extinf_attributes(self) -> None:
        """Test parsing EXTINF line attributes."""
        loader = M3ULoader(SourceConfig(enabled=True))

        line = '#EXTINF:-1 tvg-id="test" tvg-name="Test" group-title="Group",Channel Name'
        attrs, name = loader._parse_extinf(line)

        assert name == "Channel Name"
        assert attrs["tvg_id"] == "test"
        assert attrs["tvg_name"] == "Test"
        assert attrs["group_title"] == "Group"

    def test_loader_disabled(self) -> None:
        """Test that disabled loader returns empty list."""
        loader = M3ULoader(SourceConfig(enabled=False))
        assert not loader.is_enabled

    def test_loader_priority(self) -> None:
        """Test loader priority."""
        loader = M3ULoader(SourceConfig(enabled=True, priority=5))
        assert loader.priority == 5


class TestIptvOrgLoader:
    def test_preserves_aliases_categories_and_organization_metadata(self) -> None:
        loader = IptvOrgLoader(
            SourceConfig(enabled=True),
            target_countries=["IN"],
        )
        loader._channels_data = [
            {
                "id": "SonyYay.in",
                "name": "Sony Yay!",
                "alt_names": ["Sony YAY"],
                "network": "Sony",
                "owners": ["Sony Pictures Networks India"],
                "country": "IN",
                "categories": ["kids"],
                "is_nsfw": False,
                "website": "https://www.sonyyay.com/",
            }
        ]
        loader._streams_data = [
            {
                "channel": "SonyYay.in",
                "url": "https://example.com/sony-yay.m3u8",
                "feed": "main",
            },
            {
                "channel": "SonyYay.in",
                "url": "https://example.com/sony-yay-backup.m3u8",
                "feed": "backup",
            },
        ]

        channels = loader._process_channels()
        channel = channels[0]

        assert len(channels) == 2
        assert [item.extra_attrs["feed_id"] for item in channels] == [
            "main",
            "backup",
        ]
        assert channel.group_title == "kids"
        assert channel.extra_attrs["categories"] == ["kids"]
        assert channel.extra_attrs["alt_names"] == ["Sony YAY"]
        assert channel.extra_attrs["network"] == "Sony"
        assert channel.extra_attrs["owners"] == ["Sony Pictures Networks India"]
        assert channel.extra_attrs["website"] == "https://www.sonyyay.com/"

    def test_joins_logo_feed_and_ranks_all_streams(self) -> None:
        loader = IptvOrgLoader(SourceConfig(enabled=True), target_countries=["IN"])
        loader._channels_data = [
            {
                "id": "News.in",
                "name": "News",
                "country": "IN",
                "categories": ["news"],
                "is_nsfw": False,
                "closed": None,
                "replaced_by": None,
            }
        ]
        loader._feeds_data = [
            {
                "channel": "News.in",
                "id": "SD",
                "is_main": False,
                "languages": ["eng"],
                "format": "480i",
                "timezones": ["Asia/Kolkata"],
            },
            {
                "channel": "News.in",
                "id": "HD",
                "is_main": True,
                "languages": ["hin"],
                "format": "1080i",
                "timezones": ["Asia/Kolkata"],
            },
        ]
        loader._logos_data = [
            {
                "channel": "News.in",
                "feed": "HD",
                "in_use": True,
                "width": 2000,
                "height": 1000,
                "format": "SVG",
                "url": "https://feed.example/logo.svg",
            },
            {
                "channel": "News.in",
                "feed": None,
                "in_use": True,
                "width": 100,
                "height": 100,
                "format": "PNG",
                "url": "https://channel.example/logo.png",
            },
        ]
        loader._streams_data = [
            {
                "channel": "News.in",
                "feed": "SD",
                "url": "https://sd.example/live",
                "quality": "2160p",
                "user_agent": None,
                "referrer": None,
            },
            {
                "channel": "News.in",
                "feed": "HD",
                "url": "https://hd.example/live",
                "quality": "1080p",
                "user_agent": "HD-Agent",
                "referrer": "https://news.example",
            },
            {
                "channel": None,
                "feed": None,
                "url": "https://orphan.example/live",
                "quality": None,
                "user_agent": None,
                "referrer": None,
            },
        ]

        channels = loader._process_channels()

        assert [channel.stream_url for channel in channels] == [
            "https://hd.example/live",
            "https://sd.example/live",
        ]
        assert channels[0].tvg_logo == "https://channel.example/logo.png"
        assert channels[0].language == "hin"
        assert channels[0].extra_attrs["format"] == "1080i"
        assert channels[0].extra_attrs["timezones"] == ["Asia/Kolkata"]
        assert channels[0].headers is not None
        assert channels[0].headers.user_agent == "HD-Agent"
        assert channels[0].headers.referrer == "https://news.example"

    @pytest.mark.parametrize(
        ("filter_nsfw", "reason", "is_nsfw", "expected"),
        [
            (False, "dmca", False, 0),
            (False, "nsfw", True, 1),
            (True, "nsfw", False, 0),
        ],
    )
    def test_block_policy(
        self,
        filter_nsfw: bool,
        reason: str,
        is_nsfw: bool,
        expected: int,
    ) -> None:
        loader = IptvOrgLoader(
            SourceConfig(enabled=True),
            target_countries=["IN"],
            filter_nsfw=filter_nsfw,
        )
        loader._channels_data = [
            {
                "id": "Policy.in",
                "name": "Policy",
                "country": "IN",
                "categories": [],
                "is_nsfw": is_nsfw,
                "closed": None,
                "replaced_by": None,
            }
        ]
        loader._streams_data = [{"channel": "Policy.in", "url": "https://live"}]
        loader._blocklist = {"Policy.in": reason}

        assert len(loader._process_channels()) == expected

    def test_closed_and_replaced_channels_are_counted_and_dropped(self) -> None:
        loader = IptvOrgLoader(SourceConfig(enabled=True), target_countries=["IN"])
        loader._channels_data = [
            {
                "id": "Closed.in",
                "name": "Closed",
                "country": "IN",
                "categories": [],
                "is_nsfw": False,
                "closed": "2025-01-01",
                "replaced_by": None,
            },
            {
                "id": "Old.in",
                "name": "Old",
                "country": "IN",
                "categories": [],
                "is_nsfw": False,
                "closed": None,
                "replaced_by": "New.in",
            },
            {
                "id": "New.in",
                "name": "New",
                "country": "IN",
                "categories": [],
                "is_nsfw": False,
                "closed": None,
                "replaced_by": None,
            },
        ]
        loader._streams_data = [
            {"channel": channel_id, "url": f"https://{channel_id}"}
            for channel_id in ("Closed.in", "Old.in", "New.in")
        ]

        channels = loader._process_channels()

        assert [channel.tvg_id for channel in channels] == ["New.in"]
        assert loader.drop_counts["closed"] == 1
        assert loader.drop_counts["replaced"] == 1

    def test_schema_guard_rejects_missing_and_wrong_types(self) -> None:
        loader = IptvOrgLoader(SourceConfig(enabled=True))
        valid = {
            "channel": "News.in",
            "feed": None,
            "url": "https://live",
            "quality": None,
            "user_agent": None,
            "referrer": None,
        }

        with pytest.raises(UpstreamSchemaError, match=r"streams.json.*missing.*url"):
            loader._validate_schema(
                "streams", [{key: value for key, value in valid.items() if key != "url"}]
            )
        with pytest.raises(UpstreamSchemaError, match=r"streams.json.*wrong_type.*url"):
            loader._validate_schema("streams", [{**valid, "url": 42}])

        loader._validate_schema("streams", [{**valid, "new_field": "allowed"}])
