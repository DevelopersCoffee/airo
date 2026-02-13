"""Channel enrichment with flavor, category, and language tags."""

import json
from pathlib import Path
from typing import Any

from ..models import ProcessedChannel
from ..utils import get_logger

logger = get_logger(__name__)


class Enricher:
    """Enriches channels with flavor, category, and language tags."""

    def __init__(
        self,
        flavor_rules_path: str | Path,
        category_rules_path: str | Path,
        language_rules_path: str | Path,
    ) -> None:
        """Initialize enricher with rule files."""
        self.flavor_rules = self._load_rules(flavor_rules_path)
        self.category_rules = self._load_rules(category_rules_path)
        self.language_rules = self._load_rules(language_rules_path)

    def _load_rules(self, path: str | Path) -> dict[str, Any]:
        """Load rules from JSON file."""
        path = Path(path)
        if not path.exists():
            logger.warning(f"Rules file not found: {path}")
            return {}

        with open(path, encoding="utf-8") as f:
            return json.load(f)

    def enrich(self, channels: list[ProcessedChannel]) -> list[ProcessedChannel]:
        """Enrich all channels with tags."""
        for channel in channels:
            self._enrich_channel(channel)
        return channels

    def _enrich_channel(self, channel: ProcessedChannel) -> None:
        """Enrich a single channel."""
        # Determine flavor
        channel.flavor = self._determine_flavor(channel)

        # Enhance category
        channel.category = self._determine_category(channel)

        # Enhance language
        channel.language = self._determine_language(channel)

    def _determine_flavor(self, channel: ProcessedChannel) -> str:
        """Determine channel flavor based on rules."""
        name_lower = channel.name.lower()
        flavors = self.flavor_rules.get("flavors", {})

        for flavor_id, flavor_config in flavors.items():
            # Check patterns
            patterns = flavor_config.get("patterns", [])
            for pattern in patterns:
                if pattern.lower() in name_lower:
                    # Check exclusions
                    exclude_patterns = flavor_config.get("exclude_patterns", [])
                    excluded = any(
                        ex.lower() in name_lower for ex in exclude_patterns
                    )
                    if not excluded:
                        return flavor_id

            # Check keywords
            keywords = flavor_config.get("keywords", [])
            for keyword in keywords:
                if keyword.lower() in name_lower:
                    # Check exclusions
                    exclude_keywords = flavor_config.get("exclude_keywords", [])
                    excluded = any(
                        ex.lower() in name_lower for ex in exclude_keywords
                    )
                    if not excluded:
                        return flavor_id

        return "general"

    def _determine_category(self, channel: ProcessedChannel) -> str:
        """Determine channel category based on rules."""
        # If already has a valid category, keep it
        if channel.category and channel.category != "general":
            return channel.category

        name_lower = channel.name.lower()
        categories = self.category_rules.get("categories", {})

        best_match = None
        best_priority = float("inf")

        for category_id, category_config in categories.items():
            patterns = category_config.get("patterns", [])
            priority = category_config.get("priority", 100)

            for pattern in patterns:
                if pattern.lower() in name_lower:
                    if priority < best_priority:
                        best_match = category_id
                        best_priority = priority
                    break

        return best_match or channel.category or "general"

    def _determine_language(self, channel: ProcessedChannel) -> str:
        """Determine channel language based on rules."""
        # If already has a valid language, keep it
        if channel.language and channel.language != "en":
            return channel.language

        name_lower = channel.name.lower()
        languages = self.language_rules.get("languages", {})

        for lang_code, lang_config in languages.items():
            patterns = lang_config.get("patterns", [])
            for pattern in patterns:
                if pattern.lower() in name_lower:
                    return lang_code

            keywords = lang_config.get("keywords", [])
            for keyword in keywords:
                if keyword.lower() in name_lower:
                    return lang_code

        return channel.language or self.language_rules.get("default_language", "en")

