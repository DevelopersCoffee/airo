"""M3U playlist exporter."""

from pathlib import Path

from ..models import ProcessedChannel
from ..utils import get_logger
from ..utils.config import OutputConfig

logger = get_logger(__name__)


class M3UExporter:
    """Exports processed channels to M3U format."""

    def __init__(self, config: OutputConfig, base_dir: Path) -> None:
        """Initialize M3U exporter."""
        self.config = config
        self.base_dir = base_dir
        self.output_dir = base_dir / config.directory / "current"

    def export(self, channels: list[ProcessedChannel]) -> Path:
        """Export channels to M3U file.

        Args:
            channels: List of processed channels.

        Returns:
            Path to the exported M3U file.
        """
        # Ensure directory exists
        self.output_dir.mkdir(parents=True, exist_ok=True)

        # Build M3U content
        lines = ["#EXTM3U"]

        for channel in channels:
            # Build EXTINF line with attributes
            attrs = self._build_attributes(channel)
            extinf = f'#EXTINF:-1 {attrs},{channel.name}'
            lines.append(extinf)

            # Add custom headers if present
            if channel.headers:
                if channel.headers.user_agent:
                    lines.append(f'#EXTVLCOPT:http-user-agent={channel.headers.user_agent}')
                if channel.headers.referrer:
                    lines.append(f'#EXTVLCOPT:http-referrer={channel.headers.referrer}')

            # Add stream URL
            lines.append(channel.stream_url)

        # Write to file
        filename = self.config.filenames.get("m3u", "iptv_channels.m3u")
        output_path = self.output_dir / filename

        with open(output_path, "w", encoding="utf-8") as f:
            f.write("\n".join(lines))
            f.write("\n")

        logger.info(f"Exported {len(channels)} channels to {output_path}")
        return output_path

    def _build_attributes(self, channel: ProcessedChannel) -> str:
        """Build M3U EXTINF attributes string."""
        attrs = []

        # tvg-id
        attrs.append(f'tvg-id="{channel.id}"')

        # tvg-name
        attrs.append(f'tvg-name="{channel.name}"')

        # tvg-logo
        if channel.logo_url:
            attrs.append(f'tvg-logo="{channel.logo_url}"')

        # group-title
        if channel.group:
            attrs.append(f'group-title="{channel.group}"')

        # tvg-country
        if channel.country:
            attrs.append(f'tvg-country="{channel.country}"')

        # tvg-language
        if channel.language:
            attrs.append(f'tvg-language="{channel.language}"')

        return " ".join(attrs)

