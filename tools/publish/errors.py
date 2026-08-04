"""Error types for the Airo publishing framework.

Every failure path in this package raises one of these so the CLI can map a
failure to an exit code without string-matching exception messages.
"""

from __future__ import annotations


class PublishError(Exception):
    """Base class for every publishing failure."""

    exit_code = 1


class ManifestError(PublishError):
    """The release manifest is missing, malformed, or an unsupported schema."""

    exit_code = 2


class ArtifactIntegrityError(PublishError):
    """An artifact is missing, the wrong size, or fails its recorded checksum."""

    exit_code = 3


class ConfigError(PublishError):
    """The publish-targets configuration is missing, malformed, or incomplete."""

    exit_code = 4


class PreflightError(PublishError):
    """A publisher refused to run because a precondition was not met."""

    exit_code = 5


class CredentialError(PreflightError):
    """A required credential or session state is absent or unusable."""

    exit_code = 6


class RemoteError(PublishError):
    """The remote store rejected the release or the automation lost its way."""

    exit_code = 7
