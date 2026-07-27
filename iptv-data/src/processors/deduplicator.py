"""Channel deduplication logic."""

import re

from ..models import (
    NormalizedChannel,
    ProcessedChannel,
    SourceType,
    ValidationStatus,
)
from ..utils import get_logger
from ..utils.config import DeduplicationConfig

logger = get_logger(__name__)


def canonical_channel_name(value: str) -> str:
    """Canonical identity spelling shared with the Dart golden fixture."""
    value = value.strip().lower()
    value = re.sub(r"\(\s*(?:\d{3,4}p|hd|fhd|uhd|4k|sd)\s*\)\s*$", "", value)
    value = re.sub(r"[\s._-]+(?:\d{3,4}p|hd|fhd|uhd|4k|sd)$", "", value)
    return re.sub(r"[^a-z0-9]+", "", value)


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
            left_channel = channels[left]
            right_channel = channels[right]
            if (
                left_channel.source is SourceType.IPTV_ORG
                and right_channel.source is SourceType.IPTV_ORG
                and left_channel.id != right_channel.id
            ):
                return
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
        sorted_group = sorted(group, key=self._source_rank)

        # Use highest priority channel as base
        base = sorted_group[0]

        # Collect alternative names and sources
        alt_names = set()
        sources = set()
        quality_urls: dict[str, str] = {}
        network = base.extra_attrs.get("network")
        owners = set(base.extra_attrs.get("owners", []))
        website = base.extra_attrs.get("website")
        stream_sources: list[dict[str, object]] = []
        categories = set()

        for channel in sorted_group:
            sources.add(channel.source.value)

            # Collect alternative names
            if channel.name != base.name:
                alt_names.add(channel.name)
            alt_names.update(channel.alt_names)
            network = network or channel.extra_attrs.get("network")
            owners.update(channel.extra_attrs.get("owners", []))
            website = website or channel.extra_attrs.get("website")
            stream_sources.append(self._stream_source(channel))
            categories.add(channel.category)
            categories.update(channel.extra_attrs.get("categories", []))

            # Prefer logo from higher priority source
            if not base.logo_url and channel.logo_url:
                base.logo_url = channel.logo_url

            # Collect quality variants
            for quality, url in channel.quality_urls.items():
                if quality not in quality_urls:
                    quality_urls[quality] = url
        ordered_stream_sources = self._unique_stream_sources(stream_sources)
        stable_id = next(
            (
                channel.id
                for channel in sorted(group, key=lambda item: item.id)
                if not channel.id.startswith("unmatched-")
            ),
            base.id,
        )
        for index, source in enumerate(ordered_stream_sources[1:], start=1):
            quality_urls.setdefault(f"source-{index}", str(source["url"]))

        # Create merged channel
        return ProcessedChannel(
            id=stable_id,
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
            provenance=(
                "matched"
                if any(channel.source is SourceType.IPTV_ORG for channel in group)
                else "unmatched"
            ),
            stream_sources=ordered_stream_sources,
            is_working=ordered_stream_sources[0]["health"] != "unavailable",
            categories=sorted(categories),
        )

    def _get_priority(self, source: SourceType) -> int:
        """Get priority for a source type."""
        return self.priority_map.get(source.value, 999)

    def _source_rank(self, channel: NormalizedChannel) -> tuple[object, ...]:
        health_rank = {
            ValidationStatus.VALID: 0,
            ValidationStatus.SKIPPED: 2,
            ValidationStatus.UNKNOWN: 2,
            ValidationStatus.TIMEOUT: 3,
            ValidationStatus.INVALID: 3,
        }
        attrs = channel.extra_attrs
        status = str(attrs.get("status") or "").lower()
        explicit_rank = {
            "live": 0,
            "available": 0,
            "geoblocked": 1,
            "restricted": 1,
            "dead": 3,
            "unavailable": 3,
        }.get(status, health_rank[channel.validation_status])
        return (
            explicit_rank,
            0 if attrs.get("label_correct") is True else 1,
            -float(attrs.get("fps") or -1),
            -int(attrs.get("height") or -1),
            -int(attrs.get("bitrate") or -1),
            self._get_priority(channel.source),
            channel.stream_url,
        )

    def _stream_source(self, channel: NormalizedChannel) -> dict[str, object]:
        rank = self._source_rank(channel)[0]
        health = {0: "available", 1: "restricted", 3: "unavailable"}.get(
            rank, "unchecked"
        )
        attrs = channel.extra_attrs
        return {
            "url": channel.stream_url,
            "health": health,
            "feedId": attrs.get("feed_id"),
            "advertisedQuality": attrs.get("quality"),
            "labelCorrect": attrs.get("label_correct") is True,
            "framesPerSecond": attrs.get("fps"),
            "height": attrs.get("height"),
            "bitrate": attrs.get("bitrate"),
        }

    def _unique_stream_sources(
        self, sources: list[dict[str, object]]
    ) -> list[dict[str, object]]:
        by_url: dict[str, dict[str, object]] = {}
        for source in sources:
            by_url.setdefault(str(source["url"]), source)
        return list(by_url.values())

    def _dedup_keys(self, channel: NormalizedChannel) -> set[str]:
        """Build conservative alias keys scoped to country and language."""
        names = [channel.normalized_name, *channel.alt_names]
        keys = set()
        for name in names:
            normalized = canonical_channel_name(name)
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
            provenance=(
                "matched" if channel.source is SourceType.IPTV_ORG else "unmatched"
            ),
            stream_sources=[self._stream_source(channel)],
            is_working=self._source_rank(channel)[0] != 3,
            categories=sorted(
                {
                    channel.category,
                    *channel.extra_attrs.get("categories", []),
                }
            ),
        )

    def _convert_all(self, channels: list[NormalizedChannel]) -> list[ProcessedChannel]:
        """Convert all channels without deduplication."""
        return [self._to_processed(c) for c in channels]
