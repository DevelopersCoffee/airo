"""IPTV Sanity Agent - Main entry point."""

import argparse
import asyncio
import sys
import time
from collections import Counter
from datetime import UTC, datetime
from pathlib import Path

from .exporters import JsonExporter, M3UExporter
from .loaders import IptvOrgLoader, M3ULoader
from .models import PipelineMetadata, RawChannel
from .processors import Deduplicator, Enricher, Normalizer, StreamValidator
from .utils import get_logger, load_config, setup_logging

logger = get_logger(__name__)


async def run_pipeline(
    config_path: str,
    skip_validation: bool = False,
) -> int:
    """Run the IPTV sanity pipeline.

    Args:
        config_path: Path to configuration file.
        skip_validation: Skip stream validation for faster testing.

    Returns:
        Exit code (0 for success, 1 for failure).
    """
    start_time = time.time()

    # Load configuration
    config = load_config(config_path)
    setup_logging(config.logging)

    base_dir = Path(config_path).parent.parent
    logger.info(f"Starting IPTV Sanity Agent (env: {config.environment})")

    # Step 1: Load from all sources
    logger.info("Step 1: Loading channels from sources...")
    all_channels: list[RawChannel] = []

    # Load M3U sources
    if config.sources.get("m3u") and config.sources["m3u"].enabled:
        m3u_loader = M3ULoader(config.sources["m3u"])
        try:
            m3u_channels = await m3u_loader.load()
            all_channels.extend(m3u_channels)
        except Exception as e:
            logger.error(f"Failed to load M3U: {e}")
            if "primary_source_fetch_failed" in config.failure_handling.get("hard_fail", []):
                return 1

    # Load IPTV-org sources
    if config.sources.get("iptv_org") and config.sources["iptv_org"].enabled:
        iptv_org_loader = IptvOrgLoader(
            config.sources["iptv_org"],
            target_countries=config.target_countries,
        )
        try:
            iptv_org_channels = await iptv_org_loader.load()
            all_channels.extend(iptv_org_channels)
        except Exception as e:
            logger.warning(f"Failed to load IPTV-org: {e}")

    logger.info(f"Loaded {len(all_channels)} channels from all sources")

    if not all_channels:
        logger.error("No channels loaded from any source")
        return 1

    # Step 2: Normalize channels
    logger.info("Step 2: Normalizing channels...")
    normalizer = Normalizer(config.normalization, config.default_country)
    normalized_channels = normalizer.normalize(all_channels)
    logger.info(f"Normalized {len(normalized_channels)} channels")

    # Step 3: Validate streams (optional)
    dead_streams_removed = 0
    if not skip_validation and config.validation.enabled:
        logger.info("Step 3: Validating streams...")
        validator = StreamValidator(config.validation)
        normalized_channels, dead_streams_removed = await validator.validate(
            normalized_channels
        )
    else:
        logger.info("Step 3: Skipping stream validation")

    # Step 4: Deduplicate
    logger.info("Step 4: Deduplicating channels...")
    deduplicator = Deduplicator(config.deduplication)
    processed_channels, duplicates_merged = deduplicator.deduplicate(normalized_channels)

    # Step 5: Enrich
    logger.info("Step 5: Enriching channels...")
    enricher = Enricher(
        base_dir / config.enrichment.get("flavor_rules_file", "rules/flavor_rules.json"),
        base_dir / config.enrichment.get("category_rules_file", "rules/category_rules.json"),
        base_dir / config.enrichment.get("language_rules_file", "rules/language_rules.json"),
    )
    processed_channels = enricher.enrich(processed_channels)

    # Check thresholds
    thresholds = config.output.thresholds
    if len(processed_channels) < thresholds.get("min_channels", 100):
        logger.error(
            f"Channel count {len(processed_channels)} below threshold "
            f"{thresholds.get('min_channels', 100)}"
        )
        if "threshold_not_met" in config.failure_handling.get("hard_fail", []):
            return 1

    # Build metadata
    processing_time = time.time() - start_time
    version = datetime.now(UTC).strftime("%Y.%m.%d")

    metadata = PipelineMetadata(
        version=version,
        generated_at=datetime.now(UTC),
        checksum="",  # Will be filled by exporter
        total_channels=len(processed_channels),
        channels_by_country=dict(Counter(c.country for c in processed_channels)),
        channels_by_category=dict(Counter(c.category for c in processed_channels)),
        channels_by_flavor=dict(Counter(c.flavor for c in processed_channels)),
        sources_used=list({s for c in processed_channels for s in c.sources}),
        dead_streams_removed=dead_streams_removed,
        duplicates_merged=duplicates_merged,
        processing_time_seconds=round(processing_time, 2),
    )

    # Step 6: Export
    logger.info("Step 6: Exporting results...")
    json_exporter = JsonExporter(config.output, base_dir)
    json_exporter.backup_previous()
    json_exporter.export(processed_channels, metadata)

    if "m3u" in config.output.secondary_formats:
        m3u_exporter = M3UExporter(config.output, base_dir)
        m3u_exporter.export(processed_channels)

    logger.info(f"Pipeline completed in {processing_time:.2f}s")
    logger.info(f"Output: {len(processed_channels)} channels, {duplicates_merged} merged")
    return 0


def main() -> None:
    """Main entry point."""
    parser = argparse.ArgumentParser(description="IPTV Sanity Agent")
    parser.add_argument(
        "--config",
        "-c",
        default="config/default.yaml",
        help="Path to configuration file",
    )
    parser.add_argument(
        "--skip-validation",
        action="store_true",
        help="Skip stream validation for faster testing",
    )
    args = parser.parse_args()

    exit_code = asyncio.run(run_pipeline(args.config, args.skip_validation))
    sys.exit(exit_code)


if __name__ == "__main__":
    main()

