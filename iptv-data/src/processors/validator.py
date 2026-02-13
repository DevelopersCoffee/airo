"""Stream URL validation."""

import asyncio
import fnmatch
from typing import Any

import aiohttp

from ..models import NormalizedChannel, ValidationStatus
from ..utils import get_logger
from ..utils.config import ValidationConfig

logger = get_logger(__name__)


class StreamValidator:
    """Validates stream URLs by making HTTP HEAD requests."""

    def __init__(self, config: ValidationConfig) -> None:
        """Initialize validator with configuration."""
        self.config = config
        self.timeout = aiohttp.ClientTimeout(total=config.timeout_seconds)
        self.semaphore = asyncio.Semaphore(config.max_concurrent)

    async def validate(
        self, channels: list[NormalizedChannel]
    ) -> tuple[list[NormalizedChannel], int]:
        """Validate all channels and return valid ones.

        Args:
            channels: List of channels to validate.

        Returns:
            Tuple of (valid channels, count of dead streams removed).
        """
        if not self.config.enabled:
            logger.info("Stream validation is disabled")
            return channels, 0

        logger.info(f"Validating {len(channels)} streams...")

        # Validate all channels concurrently
        tasks = [self._validate_channel(channel) for channel in channels]
        results = await asyncio.gather(*tasks, return_exceptions=True)

        valid_channels = []
        dead_count = 0

        for channel, result in zip(channels, results, strict=True):
            if isinstance(result, Exception):
                logger.warning(f"Validation error for {channel.name}: {result}")
                channel.validation_status = ValidationStatus.INVALID
                dead_count += 1
            elif result:
                valid_channels.append(channel)
            else:
                dead_count += 1

        logger.info(
            f"Validation complete: {len(valid_channels)} valid, {dead_count} dead"
        )
        return valid_channels, dead_count

    async def _validate_channel(self, channel: NormalizedChannel) -> bool:
        """Validate a single channel."""
        # Check skip patterns
        if self._should_skip(channel.stream_url):
            channel.validation_status = ValidationStatus.SKIPPED
            return True

        async with self.semaphore:
            return await self._check_stream(channel)

    def _should_skip(self, url: str) -> bool:
        """Check if URL matches skip patterns."""
        for pattern in self.config.skip_patterns:
            if fnmatch.fnmatch(url, pattern):
                return True
        return False

    async def _check_stream(self, channel: NormalizedChannel) -> bool:
        """Make HTTP HEAD request to check stream."""
        try:
            async with aiohttp.ClientSession() as session:
                headers: dict[str, Any] = {"User-Agent": "IPTV-Sanity-Agent/1.0"}

                # Add custom headers if present
                if channel.headers:
                    if channel.headers.user_agent:
                        headers["User-Agent"] = channel.headers.user_agent
                    if channel.headers.referrer:
                        headers["Referer"] = channel.headers.referrer

                async with session.head(
                    channel.stream_url,
                    timeout=self.timeout,
                    headers=headers,
                    allow_redirects=True,
                ) as response:
                    status = response.status

                    if status in self.config.accept_status_codes:
                        channel.validation_status = ValidationStatus.VALID
                        return True

                    if status in self.config.conditional_accept:
                        # 403 might be blocked for HEAD but work for GET
                        channel.validation_status = ValidationStatus.VALID
                        return True

                    channel.validation_status = ValidationStatus.INVALID
                    return False

        except TimeoutError:
            channel.validation_status = ValidationStatus.TIMEOUT
            logger.debug(f"Timeout validating {channel.name}")

            # Retry once if configured
            if self.config.retry_once:
                return await self._retry_check(channel)
            return False

        except Exception as e:
            channel.validation_status = ValidationStatus.INVALID
            logger.debug(f"Error validating {channel.name}: {e}")
            return False

    async def _retry_check(self, channel: NormalizedChannel) -> bool:
        """Retry validation once."""
        try:
            async with aiohttp.ClientSession() as session:
                async with session.head(
                    channel.stream_url,
                    timeout=self.timeout,
                    headers={"User-Agent": "IPTV-Sanity-Agent/1.0"},
                    allow_redirects=True,
                ) as response:
                    if response.status in self.config.accept_status_codes:
                        channel.validation_status = ValidationStatus.VALID
                        return True
                    return False
        except Exception:
            return False

