"""Channel deduplication logic."""

from ..models import NormalizedChannel, ProcessedChannel, SourceType
from ..utils import get_logger
from ..utils.config import DeduplicationConfig

logger = get_logger(__name__)


class Deduplicator:
    """Deduplicates channels based on composite key matching."""

    def __init__(self, config: DeduplicationConfig) -> None:
        """Initialize deduplicator with configuration."""
        self.config = config
        self.priority_map = {
            source: idx for idx, source in enumerate(config.priority_order)
        }

    def deduplicate(
        self, channels: list[NormalizedChannel]
    ) -> tuple[list[ProcessedChannel], int]:
        """Deduplicate channels and return merged list.

        Args:
            channels: List of normalized channels.

        Returns:
            Tuple of (deduplicated channels, count of duplicates merged).
        """
        if not self.config.enabled:
            logger.info("Deduplication is disabled")
            return self._convert_all(channels), 0

        # Group by composite key
        groups: dict[str, list[NormalizedChannel]] = {}
        for channel in channels:
            key = channel.composite_key()
            if key not in groups:
                groups[key] = []
            groups[key].append(channel)

        # Merge each group
        result: list[ProcessedChannel] = []
        duplicates_merged = 0

        for _key, group in groups.items():
            if len(group) == 1:
                result.append(self._to_processed(group[0]))
            else:
                merged = self._merge_group(group)
                result.append(merged)
                duplicates_merged += len(group) - 1

        logger.info(
            f"Deduplication complete: {len(result)} unique channels, "
            f"{duplicates_merged} duplicates merged"
        )
        return result, duplicates_merged

    def _merge_group(self, group: list[NormalizedChannel]) -> ProcessedChannel:
        """Merge a group of duplicate channels into one."""
        # Sort by priority (lower is better)
        sorted_group = sorted(
            group, key=lambda c: self._get_priority(c.source)
        )

        # Use highest priority channel as base
        base = sorted_group[0]

        # Collect alternative names and sources
        alt_names = set()
        sources = set()
        quality_urls: dict[str, str] = {}

        for channel in sorted_group:
            sources.add(channel.source.value)

            # Collect alternative names
            if channel.name != base.name:
                alt_names.add(channel.name)

            # Prefer logo from higher priority source
            if not base.logo_url and channel.logo_url:
                base.logo_url = channel.logo_url

            # Collect quality variants
            for quality, url in channel.quality_urls.items():
                if quality not in quality_urls:
                    quality_urls[quality] = url

        # Create merged channel
        return ProcessedChannel(
            id=base.id,
            name=base.name,
            stream_url=base.stream_url,
            logo_url=base.logo_url,
            category=base.category,
            country=base.country,
            language=base.language,
            flavor=base.flavor,
            group=base.group,
            quality_urls=quality_urls or base.quality_urls,
            alt_names=list(alt_names) + base.alt_names,
            headers=base.headers,
            sources=list(sources),
        )

    def _get_priority(self, source: SourceType) -> int:
        """Get priority for a source type."""
        return self.priority_map.get(source.value, 999)

    def _to_processed(self, channel: NormalizedChannel) -> ProcessedChannel:
        """Convert a single normalized channel to processed."""
        return ProcessedChannel(
            id=channel.id,
            name=channel.name,
            stream_url=channel.stream_url,
            logo_url=channel.logo_url,
            category=channel.category,
            country=channel.country,
            language=channel.language,
            flavor=channel.flavor,
            group=channel.group,
            quality_urls=channel.quality_urls,
            alt_names=channel.alt_names,
            headers=channel.headers,
            sources=[channel.source.value],
        )

    def _convert_all(
        self, channels: list[NormalizedChannel]
    ) -> list[ProcessedChannel]:
        """Convert all channels without deduplication."""
        return [self._to_processed(c) for c in channels]

