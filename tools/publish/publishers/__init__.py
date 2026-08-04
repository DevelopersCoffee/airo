"""Store publishers and the registry that resolves them by name."""

from __future__ import annotations

from ..errors import ConfigError
from .apkpure import ApkPurePublisher
from .base import ManualPublisher, PublishContext, Publisher, PublishOptions
from .github import GitHubPublisher
from .manual_stores import AmazonAppstorePublisher, FDroidPublisher, HuaweiAppGalleryPublisher
from .play_store import PlayStorePublisher
from .website import WebsitePublisher

_REGISTRY: dict[str, type[Publisher]] = {
    publisher.name: publisher
    for publisher in (
        GitHubPublisher,
        PlayStorePublisher,
        ApkPurePublisher,
        AmazonAppstorePublisher,
        HuaweiAppGalleryPublisher,
        FDroidPublisher,
        WebsitePublisher,
    )
}


def available_targets() -> tuple[str, ...]:
    return tuple(sorted(_REGISTRY))


def describe_targets() -> list[tuple[str, str]]:
    return [(name, _REGISTRY[name].description) for name in available_targets()]


def get_publisher(name: str) -> Publisher:
    if name not in _REGISTRY:
        raise ConfigError(
            f"No publisher named {name!r}. Available: {', '.join(available_targets())}"
        )
    return _REGISTRY[name]()


__all__ = [
    "ManualPublisher",
    "PublishContext",
    "PublishOptions",
    "Publisher",
    "available_targets",
    "describe_targets",
    "get_publisher",
]
