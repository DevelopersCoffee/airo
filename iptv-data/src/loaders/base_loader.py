"""Base loader abstract class."""

from abc import ABC, abstractmethod

from ..models import RawChannel
from ..utils.config import SourceConfig


class BaseLoader(ABC):
    """Abstract base class for source loaders."""

    def __init__(self, config: SourceConfig) -> None:
        """Initialize loader with configuration."""
        self.config = config
        self._channels: list[RawChannel] = []

    @property
    def is_enabled(self) -> bool:
        """Check if loader is enabled."""
        return self.config.enabled

    @property
    def priority(self) -> int:
        """Get loader priority."""
        return self.config.priority

    @abstractmethod
    async def load(self) -> list[RawChannel]:
        """Load channels from source.

        Returns:
            List of raw channels from this source.

        Raises:
            LoaderError: If loading fails.
        """
        ...

    @abstractmethod
    def get_source_name(self) -> str:
        """Get human-readable source name."""
        ...


class LoaderError(Exception):
    """Exception raised when loader fails."""

    def __init__(self, message: str, source: str, cause: Exception | None = None) -> None:
        """Initialize loader error."""
        super().__init__(message)
        self.source = source
        self.cause = cause

