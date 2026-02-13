"""Tests for channel normalizer."""

import pytest

from src.models import RawChannel, SourceType
from src.processors.normalizer import Normalizer
from src.utils.config import NormalizationConfig


class TestNormalizer:
    """Tests for Normalizer class."""

    @pytest.fixture
    def normalizer(self) -> Normalizer:
        """Create normalizer with default config."""
        config = NormalizationConfig(
            lowercase=True,
            strip_symbols=True,
            collapse_whitespace=True,
            remove_suffixes={
                "quality": ["hd", "fhd", "uhd", "4k", "1080p", "720p"],
                "region": ["india", "us", "uk"],
                "feed": ["live", "stream", "tv", "channel"],
            },
        )
        return Normalizer(config, default_country="IN")

    def test_normalize_name_lowercase(self, normalizer: Normalizer) -> None:
        """Test lowercase normalization."""
        result = normalizer._normalize_name("Star Plus HD")
        assert result == "star plus"

    def test_normalize_name_strip_symbols(self, normalizer: Normalizer) -> None:
        """Test symbol stripping."""
        result = normalizer._normalize_name("MTV@India!")
        assert "mtv" in result
        assert "@" not in result
        assert "!" not in result

    def test_normalize_name_collapse_whitespace(self, normalizer: Normalizer) -> None:
        """Test whitespace collapsing."""
        result = normalizer._normalize_name("Star   Plus    HD")
        assert "   " not in result
        assert result == "star plus"

    def test_normalize_name_remove_quality_suffix(self, normalizer: Normalizer) -> None:
        """Test quality suffix removal."""
        assert normalizer._normalize_name("Star Plus HD") == "star plus"
        assert normalizer._normalize_name("Zee TV 4K") == "zee"
        assert normalizer._normalize_name("Colors FHD") == "colors"

    def test_normalize_name_remove_region_suffix(self, normalizer: Normalizer) -> None:
        """Test region suffix removal."""
        assert "india" not in normalizer._normalize_name("MTV India")
        assert "us" not in normalizer._normalize_name("ESPN US")

    def test_normalize_channel(self, normalizer: Normalizer) -> None:
        """Test normalizing a full channel."""
        raw = RawChannel(
            name="Star Plus HD",
            stream_url="http://example.com/stream.m3u8",
            source=SourceType.M3U,
            tvg_id="star.plus",
            tvg_name="Star Plus",
            tvg_logo="https://logo.com/star.png",
            group_title="Entertainment",
            country="IN",
            language="hi",
        )

        result = normalizer._normalize_channel(raw)

        assert result.name == "Star Plus HD"
        assert result.normalized_name == "star plus"
        assert result.stream_url == "http://example.com/stream.m3u8"
        assert result.logo_url == "https://logo.com/star.png"
        assert result.country == "IN"
        assert result.language == "hi"
        assert result.group == "Entertainment"

    def test_normalize_multiple_channels(self, normalizer: Normalizer) -> None:
        """Test normalizing multiple channels."""
        raw_channels = [
            RawChannel(name="Channel 1", stream_url="http://1.m3u8", source=SourceType.M3U),
            RawChannel(name="Channel 2", stream_url="http://2.m3u8", source=SourceType.M3U),
            RawChannel(name="Channel 3", stream_url="http://3.m3u8", source=SourceType.M3U),
        ]

        result = normalizer.normalize(raw_channels)

        assert len(result) == 3
        assert all(c.normalized_name for c in result)

    def test_generate_id_from_tvg_id(self, normalizer: Normalizer) -> None:
        """Test ID generation uses tvg_id when available."""
        raw = RawChannel(
            name="Test",
            stream_url="http://test.m3u8",
            source=SourceType.M3U,
            tvg_id="custom.id",
        )

        result = normalizer._normalize_channel(raw)
        assert result.id == "custom.id"

    def test_generate_id_from_name(self, normalizer: Normalizer) -> None:
        """Test ID generation from name when tvg_id not available."""
        raw = RawChannel(
            name="Test Channel",
            stream_url="http://test.m3u8",
            source=SourceType.M3U,
        )

        result = normalizer._normalize_channel(raw)
        assert result.id  # Should have generated ID
        assert len(result.id) == 12  # MD5 hash truncated to 12 chars

    def test_composite_key(self, normalizer: Normalizer) -> None:
        """Test composite key generation."""
        raw = RawChannel(
            name="Star Plus",
            stream_url="http://test.m3u8",
            source=SourceType.M3U,
            country="IN",
            language="hi",
        )

        result = normalizer._normalize_channel(raw)
        key = result.composite_key()

        assert "star plus" in key
        assert "in" in key
        assert "hi" in key

    def test_extract_language_from_list(self, normalizer: Normalizer) -> None:
        """Test language extraction from list format."""
        raw = RawChannel(
            name="Test",
            stream_url="http://test.m3u8",
            source=SourceType.IPTV_ORG,
            extra_attrs={"languages": ["hin", "eng"]},
        )

        result = normalizer._normalize_channel(raw)
        assert result.language == "hi"  # First 2 chars of "hin"

    def test_default_country(self, normalizer: Normalizer) -> None:
        """Test default country is used when not specified."""
        raw = RawChannel(
            name="Test",
            stream_url="http://test.m3u8",
            source=SourceType.M3U,
        )

        result = normalizer._normalize_channel(raw)
        assert result.country == "IN"

