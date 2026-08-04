"""Airo multi-store publishing framework.

One release manifest in, one `Publisher` interface out. Store-specific quirks —
Play's fastlane lane, APKPure's browser-only console, AppGallery's two-step
commit — stay inside their publisher and never leak into workflow YAML.
"""

from .config import PublishConfig, TargetProfileConfig
from .models import Artifact, PublishResult, PublishStatus, ReleaseMetadata
from .publishers import Publisher, PublishContext, PublishOptions, get_publisher

__all__ = [
    "Artifact",
    "PublishConfig",
    "PublishContext",
    "PublishOptions",
    "PublishResult",
    "PublishStatus",
    "Publisher",
    "ReleaseMetadata",
    "TargetProfileConfig",
    "get_publisher",
]
