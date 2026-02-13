"""Channel name normalization."""

import hashlib
import re
from typing import Any

from ..models import NormalizedChannel, RawChannel
from ..utils import get_logger
from ..utils.config import NormalizationConfig

logger = get_logger(__name__)


class Normalizer:
    """Normalizes channel names and generates stable IDs."""

    def __init__(self, config: NormalizationConfig, default_country: str = "IN") -> None:
        """Initialize normalizer with configuration."""
        self.config = config
        self.default_country = default_country
        self._suffix_patterns: list[re.Pattern[str]] = self._build_suffix_patterns()

    def _build_suffix_patterns(self) -> list[re.Pattern[str]]:
        """Build regex patterns for suffix removal."""
        patterns = []
        for suffix_list in self.config.remove_suffixes.values():
            for suffix in suffix_list:
                # Match suffix at end of string, must be preceded by space/underscore/dash
                # (not just any character to avoid matching partial words like "Plus" -> "Pl")
                pattern = re.compile(rf"(?:^|[\s_-]){re.escape(suffix)}$", re.IGNORECASE)
                patterns.append(pattern)
        return patterns

    def normalize(self, channels: list[RawChannel]) -> list[NormalizedChannel]:
        """Normalize a list of raw channels."""
        normalized = []
        for channel in channels:
            try:
                normalized_channel = self._normalize_channel(channel)
                normalized.append(normalized_channel)
            except Exception as e:
                logger.warning(f"Failed to normalize channel {channel.name}: {e}")
        return normalized

    def _normalize_channel(self, channel: RawChannel) -> NormalizedChannel:
        """Normalize a single channel."""
        # Normalize the name
        normalized_name = self._normalize_name(channel.tvg_name or channel.name)

        # Generate stable ID
        channel_id = self._generate_id(normalized_name, channel)

        # Extract country
        country = self._extract_country(channel)

        # Extract language
        language = self._extract_language(channel)

        return NormalizedChannel(
            id=channel_id,
            name=channel.name,
            normalized_name=normalized_name,
            stream_url=channel.stream_url,
            source=channel.source,
            logo_url=channel.tvg_logo,
            category=self._extract_category(channel),
            country=country,
            language=language,
            group=channel.group_title or "Uncategorized",
            headers=channel.headers,
            extra_attrs=channel.extra_attrs,
        )

    def _normalize_name(self, name: str) -> str:
        """Normalize a channel name for comparison."""
        result = name

        # Lowercase
        if self.config.lowercase:
            result = result.lower()

        # Strip symbols (keep alphanumeric and spaces)
        if self.config.strip_symbols:
            result = re.sub(r"[^\w\s]", "", result)

        # Collapse whitespace
        if self.config.collapse_whitespace:
            result = re.sub(r"\s+", " ", result).strip()

        # Remove suffixes
        for pattern in self._suffix_patterns:
            result = pattern.sub("", result)

        return result.strip()

    def _generate_id(self, normalized_name: str, channel: RawChannel) -> str:
        """Generate a stable ID for the channel."""
        # Use tvg_id if available
        if channel.tvg_id:
            return channel.tvg_id

        # Otherwise, generate from normalized name + source
        id_source = f"{normalized_name}:{channel.source.value}"
        return hashlib.md5(id_source.encode()).hexdigest()[:12]

    def _extract_country(self, channel: RawChannel) -> str:
        """Extract country code from channel."""
        if channel.country:
            return channel.country.upper()[:2]

        # Try to extract from extra attrs
        if "tvg_country" in channel.extra_attrs:
            return str(channel.extra_attrs["tvg_country"]).upper()[:2]

        return self.default_country

    def _extract_language(self, channel: RawChannel) -> str:
        """Extract language code from channel."""
        if channel.language:
            # Take first language if multiple
            lang = channel.language.split(",")[0].strip()
            return lang[:2].lower() if lang else "en"

        # Try to extract from extra attrs
        languages = channel.extra_attrs.get("languages", [])
        if languages and isinstance(languages, list) and languages[0]:
            return languages[0][:2].lower()

        return "en"

    def _extract_category(self, channel: RawChannel) -> str:
        """Extract category from channel."""
        # Try to extract from extra attrs (IPTV-org format)
        categories = channel.extra_attrs.get("categories", [])
        if categories and isinstance(categories, list) and categories[0]:
            return categories[0].lower()

        # Use group_title as fallback
        if channel.group_title:
            return channel.group_title.lower()

        return "general"

