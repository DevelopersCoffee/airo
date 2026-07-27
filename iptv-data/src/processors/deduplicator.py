"""Channel deduplication logic."""

import re

from ..models import NormalizedChannel, ProcessedChannel, SourceType
from ..utils import get_logger
from ..utils.config import DeduplicationConfig

logger = get_logger(__name__)


class Deduplicator:
    """Deduplicates channels based on composite key matching."""

    def __init__(self, config: DeduplicationConfig) -> None:
        """Initialize deduplicator with configuration."""
        self.config = config
        self.priority_map = {source: idx for idx, source in enumerate(config.priority_order)}

    def deduplicate(self, channels: list[NormalizedChannel]) -> tuple[list[ProcessedChannel], int]:
        """Deduplicate channels and return merged list.

        Args:
            channels: List of normalized channels.

        Returns:
            Tuple of (deduplicated channels, count of duplicates merged).
        """
        if not self.config.enabled:
            logger.info("Deduplication is disabled")
            return self._convert_all(channels), 0

        # Union channels that share a canonical name or upstream alias, while
        # retaining country/language in every key so aliases cannot collapse
        # unrelated regional feeds.
        parents = list(range(len(channels)))

        def find(index: int) -> int:
            while parents[index] != index:
                parents[index] = parents[parents[index]]
                index = parents[index]
            return index

        def union(left: int, right: int) -> None:
            left_root = find(left)
            right_root = find(right)
            if left_root != right_root:
                parents[right_root] = left_root

        owner_by_key: dict[str, int] = {}
        for index, channel in enumerate(channels):
            for key in self._dedup_keys(channel):
                owner = owner_by_key.setdefault(key, index)
                union(index, owner)

        groups_by_root: dict[int, list[NormalizedChannel]] = {}
        for index, channel in enumerate(channels):
            groups_by_root.setdefault(find(index), []).append(channel)

        # Merge each group
        result: list[ProcessedChannel] = []
        duplicates_merged = 0

        for group in groups_by_root.values():
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
        sorted_group = sorted(group, key=lambda c: self._get_priority(c.source))

        # Use highest priority channel as base
        base = sorted_group[0]

        # Collect alternative names and sources
        alt_names = set()
        sources = set()
        quality_urls: dict[str, str] = {}
        network = base.extra_attrs.get("network")
        owners = set(base.extra_attrs.get("owners", []))
        website = base.extra_attrs.get("website")

        for channel in sorted_group:
            sources.add(channel.source.value)

            # Collect alternative names
            if channel.name != base.name:
                alt_names.add(channel.name)
            alt_names.update(channel.alt_names)
            network = network or channel.extra_attrs.get("network")
            owners.update(channel.extra_attrs.get("owners", []))
            website = website or channel.extra_attrs.get("website")

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
            alt_names=sorted(name for name in alt_names if name != base.name),
            headers=base.headers,
            sources=sorted(sources),
            network=network,
            owners=sorted(owners),
            website=website,
        )

    def _get_priority(self, source: SourceType) -> int:
        """Get priority for a source type."""
        return self.priority_map.get(source.value, 999)

    def _dedup_keys(self, channel: NormalizedChannel) -> set[str]:
        """Build conservative alias keys scoped to country and language."""
        names = [channel.normalized_name, *channel.alt_names]
        keys = set()
        for name in names:
            normalized = re.sub(r"[^\w]+", "", name.lower())
            normalized = re.sub(r"(?:4k|fhd|uhd|hd|sd|\d{3,4}p)$", "", normalized)
            if normalized:
                keys.add(f"{normalized}:{channel.country}:{channel.language}")
        return keys or {channel.composite_key()}

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
            network=channel.extra_attrs.get("network"),
            owners=list(channel.extra_attrs.get("owners", [])),
            website=channel.extra_attrs.get("website"),
        )

    def _convert_all(self, channels: list[NormalizedChannel]) -> list[ProcessedChannel]:
        """Convert all channels without deduplication."""
        return [self._to_processed(c) for c in channels]
