"""Tests for channel enricher."""

from pathlib import Path

import pytest

from src.models import ProcessedChannel
from src.processors.enricher import Enricher


class TestEnricher:
    """Tests for Enricher class."""

    @pytest.fixture
    def enricher(self) -> Enricher:
        """Create enricher with test rules."""
        rules_dir = Path(__file__).parent.parent / "rules"
        return Enricher(
            rules_dir / "flavor_rules.json",
            rules_dir / "category_rules.json",
            rules_dir / "language_rules.json",
        )

    def _make_channel(
        self,
        name: str,
        category: str = "general",
        language: str = "en",
    ) -> ProcessedChannel:
        """Helper to create a processed channel."""
        return ProcessedChannel(
            id=name.lower().replace(" ", "."),
            name=name,
            stream_url=f"http://example.com/{name.lower()}.m3u8",
            logo_url=None,
            category=category,
            country="IN",
            language=language,
            flavor="general",
            group="Uncategorized",
            quality_urls={},
            alt_names=[],
            headers=None,
            sources=["m3u"],
        )

    def test_flavor_hindi_music(self, enricher: Enricher) -> None:
        """Test flavor detection for Hindi music channels."""
        channel = self._make_channel("9XM")
        enricher._enrich_channel(channel)
        assert channel.flavor == "hindiMusic"

    def test_flavor_hindi_news(self, enricher: Enricher) -> None:
        """Test flavor detection for Hindi news channels."""
        channel = self._make_channel("Aaj Tak")
        enricher._enrich_channel(channel)
        assert channel.flavor == "hindiNews"

    def test_flavor_english_news(self, enricher: Enricher) -> None:
        """Test flavor detection for English news channels."""
        channel = self._make_channel("Times Now")
        enricher._enrich_channel(channel)
        assert channel.flavor == "englishNews"

    def test_flavor_sports(self, enricher: Enricher) -> None:
        """Test flavor detection for sports channels."""
        channel = self._make_channel("Star Sports 1")
        enricher._enrich_channel(channel)
        assert channel.flavor == "sports"

    def test_flavor_kids(self, enricher: Enricher) -> None:
        """Test flavor detection for kids channels."""
        channel = self._make_channel("Cartoon Network")
        enricher._enrich_channel(channel)
        assert channel.flavor == "kids"

    def test_flavor_hindi_entertainment(self, enricher: Enricher) -> None:
        """Test flavor detection for Hindi entertainment channels."""
        channel = self._make_channel("Star Plus")
        enricher._enrich_channel(channel)
        assert channel.flavor == "hindiEntertainment"

    def test_flavor_regional(self, enricher: Enricher) -> None:
        """Test flavor detection for regional channels."""
        channel = self._make_channel("Sun TV")
        enricher._enrich_channel(channel)
        assert channel.flavor == "regionalEntertainment"

    def test_flavor_default(self, enricher: Enricher) -> None:
        """Test default flavor for unknown channels."""
        channel = self._make_channel("Unknown Channel XYZ")
        enricher._enrich_channel(channel)
        assert channel.flavor == "general"

    def test_category_news(self, enricher: Enricher) -> None:
        """Test category detection for news channels."""
        channel = self._make_channel("Some News Channel", category="general")
        enricher._enrich_channel(channel)
        assert channel.category == "news"

    def test_category_sports(self, enricher: Enricher) -> None:
        """Test category detection for sports channels."""
        channel = self._make_channel("ESPN", category="general")
        enricher._enrich_channel(channel)
        assert channel.category == "sports"

    def test_category_preserved_if_valid(self, enricher: Enricher) -> None:
        """Test that valid category is preserved."""
        channel = self._make_channel("Some Channel", category="entertainment")
        enricher._enrich_channel(channel)
        assert channel.category == "entertainment"

    def test_language_hindi(self, enricher: Enricher) -> None:
        """Test language detection for Hindi channels."""
        channel = self._make_channel("Zee TV", language="en")
        enricher._enrich_channel(channel)
        assert channel.language == "hi"

    def test_language_tamil(self, enricher: Enricher) -> None:
        """Test language detection for Tamil channels."""
        channel = self._make_channel("Sun TV", language="en")
        enricher._enrich_channel(channel)
        assert channel.language == "ta"

    def test_language_preserved_if_valid(self, enricher: Enricher) -> None:
        """Test that valid language is preserved."""
        channel = self._make_channel("Some Channel", language="hi")
        enricher._enrich_channel(channel)
        assert channel.language == "hi"

    def test_enrich_multiple(self, enricher: Enricher) -> None:
        """Test enriching multiple channels."""
        channels = [
            self._make_channel("9XM"),
            self._make_channel("Aaj Tak"),
            self._make_channel("Star Sports 1"),
        ]

        enricher.enrich(channels)

        assert channels[0].flavor == "hindiMusic"
        assert channels[1].flavor == "hindiNews"
        assert channels[2].flavor == "sports"

