"""Data models for IPTV channel processing."""

from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Any


class SourceType(Enum):
    """Source type enumeration."""

    M3U = "m3u"
    IPTV_ORG = "iptv_org"
    CUSTOM = "custom"


class ValidationStatus(Enum):
    """Stream validation status."""

    VALID = "valid"
    INVALID = "invalid"
    TIMEOUT = "timeout"
    SKIPPED = "skipped"
    UNKNOWN = "unknown"


@dataclass
class ChannelHeaders:
    """HTTP headers for stream access."""

    user_agent: str | None = None
    referrer: str | None = None

    def to_dict(self) -> dict[str, str]:
        """Convert to dictionary, excluding None values."""
        result = {}
        if self.user_agent:
            result["userAgent"] = self.user_agent
        if self.referrer:
            result["referrer"] = self.referrer
        return result


@dataclass
class RawChannel:
    """Raw channel data from source (before normalization)."""

    name: str
    stream_url: str
    source: SourceType
    tvg_id: str | None = None
    tvg_name: str | None = None
    tvg_logo: str | None = None
    group_title: str | None = None
    country: str | None = None
    language: str | None = None
    headers: ChannelHeaders | None = None
    extra_attrs: dict[str, Any] = field(default_factory=dict)


@dataclass
class NormalizedChannel:
    """Channel after normalization (before deduplication)."""

    id: str
    name: str
    normalized_name: str
    stream_url: str
    source: SourceType
    logo_url: str | None = None
    category: str = "general"
    country: str = "IN"
    language: str = "en"
    flavor: str = "general"
    group: str = "Uncategorized"
    quality_urls: dict[str, str] = field(default_factory=dict)
    alt_names: list[str] = field(default_factory=list)
    headers: ChannelHeaders | None = None
    validation_status: ValidationStatus = ValidationStatus.UNKNOWN
    extra_attrs: dict[str, Any] = field(default_factory=dict)

    def composite_key(self) -> str:
        """Generate composite key for deduplication."""
        return f"{self.normalized_name}:{self.country}:{self.language}".lower()


@dataclass
class ProcessedChannel:
    """Final processed channel ready for export."""

    id: str
    name: str
    stream_url: str
    logo_url: str | None
    category: str
    country: str
    language: str  # Primary language code
    flavor: str
    group: str
    quality_urls: dict[str, str]
    alt_names: list[str]
    headers: ChannelHeaders | None
    sources: list[str]  # Source types that contributed to this channel

    def to_dict(self) -> dict[str, Any]:
        """Convert to dictionary for JSON export."""
        result = {
            "id": self.id,
            "name": self.name,
            "streamUrl": self.stream_url,
            "logoUrl": self.logo_url,
            "category": self.category,
            "country": self.country,
            "languages": [self.language] if self.language else ["en"],  # Flutter expects array
            "flavor": self.flavor,
            "group": self.group,
            "qualityUrls": self.quality_urls,
            "altNames": self.alt_names,
            "sources": self.sources,
        }
        if self.headers:
            result["headers"] = self.headers.to_dict()
        return result


@dataclass
class PipelineMetadata:
    """Metadata about the pipeline run."""

    version: str
    generated_at: datetime
    checksum: str
    total_channels: int
    channels_by_country: dict[str, int]
    channels_by_category: dict[str, int]
    channels_by_flavor: dict[str, int]
    sources_used: list[str]
    dead_streams_removed: int
    duplicates_merged: int
    processing_time_seconds: float

    def to_dict(self) -> dict[str, Any]:
        """Convert to dictionary for JSON export."""
        return {
            "totalChannels": self.total_channels,
            "channelsByCountry": self.channels_by_country,
            "channelsByCategory": self.channels_by_category,
            "channelsByFlavor": self.channels_by_flavor,
            "sourcesUsed": self.sources_used,
            "deadStreamsRemoved": self.dead_streams_removed,
            "duplicatesMerged": self.duplicates_merged,
            "processingTimeSeconds": self.processing_time_seconds,
        }

