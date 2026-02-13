"""Tests for source loaders."""

from pathlib import Path

import pytest

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

