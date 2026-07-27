"""JSON output exporter."""

import hashlib
import json
from pathlib import Path
from typing import Any

from ..models import PipelineMetadata, ProcessedChannel
from ..utils import get_logger
from ..utils.config import OutputConfig

logger = get_logger(__name__)


class JsonExporter:
    """Exports processed channels to JSON format."""

    def __init__(self, config: OutputConfig, base_dir: Path) -> None:
        """Initialize JSON exporter."""
        self.config = config
        self.base_dir = base_dir
        self.output_dir = base_dir / config.directory / "current"
        self.previous_dir = base_dir / config.directory / "previous"

    def export(
        self,
        channels: list[ProcessedChannel],
        metadata: PipelineMetadata,
        taxonomies: dict[str, list[dict[str, Any]]] | None = None,
    ) -> Path:
        """Export channels to JSON file.

        Args:
            channels: List of processed channels.
            metadata: Pipeline metadata.

        Returns:
            Path to the exported JSON file.
        """
        # Ensure directories exist
        self.output_dir.mkdir(parents=True, exist_ok=True)

        # Sort channels if configured
        if self.config.guarantees.get("sorted_output", True):
            channels = self._sort_channels(channels)

        # Build output data
        output_data = self._build_output(channels, metadata)

        # Generate checksum
        content_json = json.dumps(output_data["channels"], sort_keys=True)
        checksum = hashlib.sha256(content_json.encode()).hexdigest()
        output_data["checksum"] = checksum

        # Update metadata checksum
        metadata.checksum = checksum

        # Write JSON file
        filename = self.config.filenames.get("json", "iptv_channels.json")
        output_path = self.output_dir / filename

        minify = self.config.guarantees.get("minify_json", False)
        with open(output_path, "w", encoding="utf-8") as f:
            if minify:
                json.dump(output_data, f, ensure_ascii=False)
            else:
                json.dump(output_data, f, indent=2, ensure_ascii=False)

        logger.info(f"Exported {len(channels)} channels to {output_path}")

        taxonomy_checksum = self._write_taxonomies(channels, taxonomies or {})

        # Write manifest
        self._write_manifest(metadata, taxonomy_checksum)

        return output_path

    def _sort_channels(self, channels: list[ProcessedChannel]) -> list[ProcessedChannel]:
        """Sort channels based on configuration."""
        sort_by = self.config.guarantees.get("sort_by", ["country", "category", "name"])

        def sort_key(channel: ProcessedChannel) -> tuple[Any, ...]:
            return tuple(getattr(channel, field, "") for field in sort_by)

        return sorted(channels, key=sort_key)

    def _build_output(
        self,
        channels: list[ProcessedChannel],
        metadata: PipelineMetadata,
    ) -> dict[str, Any]:
        """Build the output JSON structure."""
        return {
            "version": metadata.version,
            "generatedAt": metadata.generated_at.isoformat() + "Z",
            "checksum": "",  # Will be filled later
            "metadata": metadata.to_dict(),
            "channels": [channel.to_dict() for channel in channels],
        }

    def _write_taxonomies(
        self,
        channels: list[ProcessedChannel],
        taxonomies: dict[str, list[dict[str, Any]]],
    ) -> str | None:
        """Write the small app-consumable taxonomy artifact deterministically."""
        if not taxonomies:
            return None
        represented_countries = {channel.country.upper() for channel in channels}
        output = {
            "categories": sorted(
                taxonomies.get("categories", []), key=lambda row: row.get("id", "")
            ),
            "countries": sorted(
                (
                    row
                    for row in taxonomies.get("countries", [])
                    if str(row.get("code", "")).upper() in represented_countries
                ),
                key=lambda row: row.get("code", ""),
            ),
            "regions": sorted(taxonomies.get("regions", []), key=lambda row: row.get("code", "")),
            "languages": sorted(
                taxonomies.get("languages", []), key=lambda row: row.get("code", "")
            ),
        }
        canonical = json.dumps(output, sort_keys=True, ensure_ascii=False, separators=(",", ":"))
        checksum = hashlib.sha256(canonical.encode()).hexdigest()
        payload = {"checksum": checksum, **output}
        path = self.output_dir / "taxonomies.json"
        with open(path, "w", encoding="utf-8") as f:
            json.dump(payload, f, indent=2, ensure_ascii=False)
        return checksum

    def _write_manifest(
        self, metadata: PipelineMetadata, taxonomy_checksum: str | None = None
    ) -> None:
        """Write manifest.json with version info."""
        manifest = {
            "version": metadata.version,
            "generatedAt": metadata.generated_at.isoformat() + "Z",
            "checksum": metadata.checksum,
            "totalChannels": metadata.total_channels,
            "files": {
                "channels": self.config.filenames.get("json", "iptv_channels.json"),
                "m3u": self.config.filenames.get("m3u", "iptv_channels.m3u"),
                **({"taxonomies": "taxonomies.json"} if taxonomy_checksum else {}),
            },
            "fileChecksums": {
                "channels": metadata.checksum,
                **({"taxonomies": taxonomy_checksum} if taxonomy_checksum is not None else {}),
            },
        }

        manifest_path = self.output_dir / "manifest.json"
        with open(manifest_path, "w", encoding="utf-8") as f:
            json.dump(manifest, f, indent=2, ensure_ascii=False)

        logger.info(f"Wrote manifest to {manifest_path}")

    def backup_previous(self) -> None:
        """Backup current output to previous directory."""
        if not self.output_dir.exists():
            return

        # Ensure previous directory exists
        self.previous_dir.mkdir(parents=True, exist_ok=True)

        # Copy current files to previous
        for file in self.output_dir.iterdir():
            if file.is_file():
                dest = self.previous_dir / file.name
                dest.write_bytes(file.read_bytes())

        logger.info(f"Backed up current output to {self.previous_dir}")
