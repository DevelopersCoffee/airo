"""Configuration loader and validation."""

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import yaml


@dataclass
class SourceConfig:
    """Configuration for a data source."""

    enabled: bool = True
    priority: int = 1
    urls: list[dict[str, Any]] = field(default_factory=list)
    base_url: str = ""
    endpoints: dict[str, str] = field(default_factory=dict)
    cache_hours: int = 24
    retry: dict[str, Any] = field(default_factory=dict)


@dataclass
class ValidationConfig:
    """Stream validation configuration."""

    enabled: bool = True
    timeout_seconds: int = 5
    max_concurrent: int = 50
    retry_once: bool = True
    accept_status_codes: list[int] = field(default_factory=lambda: [200, 302, 303, 307, 308])
    conditional_accept: list[int] = field(default_factory=lambda: [403])
    skip_patterns: list[str] = field(default_factory=list)


@dataclass
class DeduplicationConfig:
    """Deduplication configuration."""

    enabled: bool = True
    strategy: str = "composite_key"
    priority_order: list[str] = field(default_factory=lambda: ["m3u", "iptv_org", "custom"])
    prefer_criteria: list[str] = field(default_factory=list)


@dataclass
class NormalizationConfig:
    """Name normalization configuration."""

    lowercase: bool = True
    strip_symbols: bool = True
    collapse_whitespace: bool = True
    remove_suffixes: dict[str, list[str]] = field(default_factory=dict)


@dataclass
class OutputConfig:
    """Output configuration."""

    primary_format: str = "json"
    secondary_formats: list[str] = field(default_factory=list)
    directory: str = "output"
    filenames: dict[str, str] = field(default_factory=dict)
    versioning: dict[str, Any] = field(default_factory=dict)
    guarantees: dict[str, Any] = field(default_factory=dict)
    thresholds: dict[str, int] = field(default_factory=dict)


@dataclass
class Config:
    """Main configuration object."""

    version: str = "1.0"
    environment: str = "production"
    sources: dict[str, SourceConfig] = field(default_factory=dict)
    processing: dict[str, Any] = field(default_factory=dict)
    enrichment: dict[str, Any] = field(default_factory=dict)
    output: OutputConfig = field(default_factory=OutputConfig)
    failure_handling: dict[str, Any] = field(default_factory=dict)
    logging: dict[str, Any] = field(default_factory=dict)

    @property
    def validation(self) -> ValidationConfig:
        """Get validation configuration."""
        val_config = self.processing.get("validation", {})
        return ValidationConfig(**val_config) if val_config else ValidationConfig()

    @property
    def deduplication(self) -> DeduplicationConfig:
        """Get deduplication configuration."""
        dedup_config = self.processing.get("deduplication", {})
        return DeduplicationConfig(**dedup_config) if dedup_config else DeduplicationConfig()

    @property
    def normalization(self) -> NormalizationConfig:
        """Get normalization configuration."""
        norm_config = self.processing.get("normalization", {})
        return NormalizationConfig(**norm_config) if norm_config else NormalizationConfig()

    @property
    def target_countries(self) -> list[str]:
        """Get target countries."""
        return self.processing.get("target_countries", ["IN", "US", "GB"])

    @property
    def default_country(self) -> str:
        """Get default country."""
        return self.processing.get("default_country", "IN")


def load_config(config_path: str | Path) -> Config:
    """Load configuration from YAML file."""
    config_path = Path(config_path)
    if not config_path.exists():
        raise FileNotFoundError(f"Configuration file not found: {config_path}")

    with open(config_path, encoding="utf-8") as f:
        raw_config = yaml.safe_load(f)

    # Parse sources
    sources = {}
    for source_name, source_data in raw_config.get("sources", {}).items():
        sources[source_name] = SourceConfig(**source_data) if source_data else SourceConfig()

    # Parse output
    output_data = raw_config.get("output", {})
    output = OutputConfig(**output_data) if output_data else OutputConfig()

    return Config(
        version=raw_config.get("version", "1.0"),
        environment=raw_config.get("environment", "production"),
        sources=sources,
        processing=raw_config.get("processing", {}),
        enrichment=raw_config.get("enrichment", {}),
        output=output,
        failure_handling=raw_config.get("failure_handling", {}),
        logging=raw_config.get("logging", {}),
    )

