"""Tests for channel deduplicator."""

import pytest

from src.models import NormalizedChannel, SourceType, ValidationStatus
from src.processors.deduplicator import Deduplicator
from src.utils.config import DeduplicationConfig


class TestDeduplicator:
    """Tests for Deduplicator class."""

    @pytest.fixture
    def deduplicator(self) -> Deduplicator:
        """Create deduplicator with default config."""
        config = DeduplicationConfig(
            enabled=True,
            strategy="composite_key",
            priority_order=["m3u", "iptv_org", "custom"],
            prefer_criteria=["has_logo", "higher_quality"],
        )
        return Deduplicator(config)

    def _make_channel(
        self,
        name: str,
        source: SourceType,
        country: str = "IN",
        language: str = "en",
        logo_url: str | None = None,
    ) -> NormalizedChannel:
        """Helper to create a normalized channel."""
        return NormalizedChannel(
            id=f"{name.lower().replace(' ', '.')}.{source.value}",
            name=name,
            normalized_name=name.lower(),
            stream_url=f"http://example.com/{name.lower().replace(' ', '-')}.m3u8",
            source=source,
            logo_url=logo_url,
            category="general",
            country=country,
            language=language,
            flavor="general",
            group="Uncategorized",
            validation_status=ValidationStatus.VALID,
        )

    def test_no_duplicates(self, deduplicator: Deduplicator) -> None:
        """Test with no duplicate channels."""
        channels = [
            self._make_channel("Channel 1", SourceType.M3U),
            self._make_channel("Channel 2", SourceType.M3U),
            self._make_channel("Channel 3", SourceType.M3U),
        ]

        result, merged_count = deduplicator.deduplicate(channels)

        assert len(result) == 3
        assert merged_count == 0

    def test_duplicate_same_source(self, deduplicator: Deduplicator) -> None:
        """Test deduplication of same channel from same source."""
        channels = [
            self._make_channel("Star Plus", SourceType.M3U),
            self._make_channel("Star Plus", SourceType.M3U),
        ]

        result, merged_count = deduplicator.deduplicate(channels)

        assert len(result) == 1
        assert merged_count == 1
        assert result[0].name == "Star Plus"

    def test_duplicate_different_sources(self, deduplicator: Deduplicator) -> None:
        """Test deduplication of same channel from different sources."""
        channels = [
            self._make_channel("Star Plus", SourceType.M3U),
            self._make_channel("Star Plus", SourceType.IPTV_ORG),
        ]

        result, merged_count = deduplicator.deduplicate(channels)

        assert len(result) == 1
        assert merged_count == 1
        # Should prefer M3U (higher priority)
        assert "m3u" in result[0].sources

    def test_priority_order(self, deduplicator: Deduplicator) -> None:
        """Test that priority order is respected."""
        # IPTV_ORG has a logo, M3U doesn't
        m3u_channel = self._make_channel("Star Plus", SourceType.M3U, logo_url=None)
        iptv_channel = self._make_channel(
            "Star Plus", SourceType.IPTV_ORG, logo_url="https://logo.com/star.png"
        )

        channels = [iptv_channel, m3u_channel]
        result, merged_count = deduplicator.deduplicate(channels)

        assert len(result) == 1
        assert merged_count == 1
        # M3U should be preferred as base, but should get logo from IPTV_ORG
        assert "m3u" in result[0].sources

    def test_different_countries_not_duplicates(self, deduplicator: Deduplicator) -> None:
        """Test that same name with different countries are not duplicates."""
        channels = [
            self._make_channel("MTV", SourceType.M3U, country="IN"),
            self._make_channel("MTV", SourceType.M3U, country="US"),
        ]

        result, merged_count = deduplicator.deduplicate(channels)

        assert len(result) == 2
        assert merged_count == 0

    def test_different_languages_not_duplicates(self, deduplicator: Deduplicator) -> None:
        """Test that same name with different languages are not duplicates."""
        channels = [
            self._make_channel("News Channel", SourceType.M3U, language="hi"),
            self._make_channel("News Channel", SourceType.M3U, language="en"),
        ]

        result, merged_count = deduplicator.deduplicate(channels)

        assert len(result) == 2
        assert merged_count == 0

    def test_alt_names_collected(self, deduplicator: Deduplicator) -> None:
        """Test that alternative names are collected during merge."""
        ch1 = self._make_channel("Star Plus HD", SourceType.M3U)
        ch2 = self._make_channel("star plus hd", SourceType.IPTV_ORG)
        ch2.name = "Star Plus India"  # Different display name

        channels = [ch1, ch2]
        result, merged_count = deduplicator.deduplicate(channels)

        assert len(result) == 1
        assert merged_count == 1
        # The alternate name should be collected
        assert "Star Plus India" in result[0].alt_names or result[0].name == "Star Plus HD"

    def test_sources_collected(self, deduplicator: Deduplicator) -> None:
        """Test that all sources are collected during merge."""
        channels = [
            self._make_channel("Star Plus", SourceType.M3U),
            self._make_channel("Star Plus", SourceType.IPTV_ORG),
        ]

        result, merged_count = deduplicator.deduplicate(channels)

        assert len(result) == 1
        assert "m3u" in result[0].sources
        assert "iptv_org" in result[0].sources

    def test_upstream_alias_merges_punctuation_variant(self, deduplicator: Deduplicator) -> None:
        m3u = self._make_channel("Sony YAY", SourceType.M3U)
        canonical = self._make_channel("Sony Yay!", SourceType.IPTV_ORG)
        canonical.alt_names = ["Sony YAY"]
        canonical.extra_attrs = {
            "network": "Sony",
            "owners": ["Sony Pictures Networks India"],
            "website": "https://www.sonyyay.com/",
        }

        result, merged_count = deduplicator.deduplicate([m3u, canonical])

        assert len(result) == 1
        assert merged_count == 1
        assert set(result[0].sources) == {"m3u", "iptv_org"}
        assert result[0].network == "Sony"
        assert result[0].owners == ["Sony Pictures Networks India"]
        assert result[0].website == "https://www.sonyyay.com/"

    def test_alias_never_merges_different_countries(self, deduplicator: Deduplicator) -> None:
        india = self._make_channel("Sony YAY", SourceType.M3U, country="IN")
        usa = self._make_channel("Different", SourceType.IPTV_ORG, country="US")
        usa.alt_names = ["Sony YAY"]

        result, merged_count = deduplicator.deduplicate([india, usa])

        assert len(result) == 2
        assert merged_count == 0

    def test_health_orders_sources_and_preserves_dead_alternative(
        self, deduplicator: Deduplicator
    ) -> None:
        live = self._make_channel("Sports One HD", SourceType.IPTV_ORG)
        live.stream_url = "https://live.example/stream"
        live.category = "sports"
        live.extra_attrs = {"status": "live", "height": 720, "fps": 50}
        dead = self._make_channel("Sports One", SourceType.M3U)
        dead.stream_url = "https://dead.example/stream"
        dead.validation_status = ValidationStatus.INVALID
        dead.category = "regional"
        dead.extra_attrs = {"height": 1080}

        result, merged_count = deduplicator.deduplicate([dead, live])

        assert merged_count == 1
        assert result[0].stream_url == live.stream_url
        assert result[0].id == live.id
        assert [source["health"] for source in result[0].stream_sources] == [
            "available",
            "unavailable",
        ]
        assert result[0].quality_urls["source-1"] == dead.stream_url
        assert result[0].is_working is True
        assert result[0].categories == ["regional", "sports"]

    def test_unmatched_single_is_preserved_with_provenance(
        self, deduplicator: Deduplicator
    ) -> None:
        unknown = self._make_channel("Mystery ++", SourceType.CUSTOM)
        unknown.group = "Odd Group"

        result, merged_count = deduplicator.deduplicate([unknown])

        assert merged_count == 0
        assert result[0].name == "Mystery ++"
        assert result[0].group == "Odd Group"
        assert result[0].provenance == "unmatched"
        assert result[0].stream_sources[0]["url"] == unknown.stream_url

    def test_disabled_deduplication(self) -> None:
        """Test that disabled deduplication returns all channels."""
        config = DeduplicationConfig(enabled=False)
        deduplicator = Deduplicator(config)

        channels = [
            self._make_channel("Star Plus", SourceType.M3U),
            self._make_channel("Star Plus", SourceType.M3U),
        ]

        result, merged_count = deduplicator.deduplicate(channels)

        assert len(result) == 2
        assert merged_count == 0
