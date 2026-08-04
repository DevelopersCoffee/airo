"""The Publisher contract every store implementation satisfies.

One interface, one manifest, one evidence trail. A publisher may not read the
build tree, re-hash artifacts, or invent version strings: everything it needs
arrives in `PublishContext`.
"""

from __future__ import annotations

import os
import shutil
import subprocess
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from pathlib import Path
from typing import ClassVar, Sequence

from ..config import TargetProfileConfig
from ..errors import CredentialError, PreflightError, RemoteError
from ..evidence import EvidenceRecorder
from ..models import Artifact, PublishResult, PublishStatus, ReleaseMetadata


@dataclass(frozen=True)
class PublishOptions:
    """Caller-supplied switches shared by every publisher."""

    dry_run: bool = False
    # Browser-driven and store publishers stop before the irreversible final
    # submit unless the caller explicitly opts in.
    submit: bool = False
    force: bool = False
    timeout_seconds: int = 600

    @property
    def may_submit(self) -> bool:
        return self.submit and not self.dry_run


@dataclass
class PublishContext:
    """Everything one publisher needs for one profile."""

    release: ReleaseMetadata
    config: TargetProfileConfig
    artifacts: list[Artifact]
    options: PublishOptions
    evidence: EvidenceRecorder
    release_notes: str
    env: dict[str, str] = field(default_factory=lambda: dict(os.environ))

    @property
    def profile_id(self) -> str:
        return self.config.profile_id

    @property
    def version(self) -> str:
        return self.release.version

    def require_env(self, name: str, hint: str) -> str:
        value = self.env.get(name, "").strip()
        if not value:
            raise CredentialError(f"{name} is not set. {hint}")
        return value

    def sole_artifact(self) -> Artifact:
        if len(self.artifacts) != 1:
            raise PreflightError(
                f"{self.config.context}: expected exactly one artifact, got "
                f"{len(self.artifacts)}: {', '.join(a.filename for a in self.artifacts)}. "
                "Tighten artifactSelector."
            )
        return self.artifacts[0]


class Publisher(ABC):
    """Base class for every store publisher."""

    name: ClassVar[str]
    #: Human-readable description used by `publish targets`.
    description: ClassVar[str] = ""
    #: Env vars that must be present before this publisher will run for real.
    required_env: ClassVar[tuple[str, ...]] = ()
    #: External binaries this publisher shells out to.
    required_binaries: ClassVar[tuple[str, ...]] = ()
    #: True when the publisher drives a browser and needs a logged-in session.
    needs_browser_session: ClassVar[bool] = False

    def preflight(self, ctx: PublishContext) -> list[str]:
        """Return blocking reasons. Empty list means good to go."""
        blockers: list[str] = []
        # A dry run contacts nothing and executes nothing, so missing tools and
        # credentials must not block it — that is the whole point of planning
        # a release from a machine that cannot publish one.
        if ctx.options.dry_run:
            return blockers
        for binary in self.required_binaries:
            if shutil.which(binary) is None:
                blockers.append(f"required binary {binary!r} is not on PATH")
        for name in self.required_env:
            if not ctx.env.get(name, "").strip():
                blockers.append(f"required environment variable {name} is not set")
        return blockers

    @abstractmethod
    def publish(self, ctx: PublishContext) -> PublishResult:
        """Do the upload. Must be safe to call twice for the same version."""

    # ---- helpers shared by concrete publishers -------------------------------

    def result(
        self,
        ctx: PublishContext,
        status: PublishStatus,
        message: str,
        details: dict | None = None,
    ) -> PublishResult:
        return PublishResult(
            target=self.name,
            profile_id=ctx.profile_id,
            status=status,
            message=message,
            artifacts=[artifact.filename for artifact in ctx.artifacts],
            evidence=ctx.evidence.artifacts(),
            details=details or {},
        )

    def run(
        self,
        ctx: PublishContext,
        command: Sequence[str],
        *,
        cwd: Path | None = None,
        env: dict[str, str] | None = None,
        redact: Sequence[str] = (),
    ) -> subprocess.CompletedProcess[str]:
        """Run a subprocess, log a redacted command line, and fail loudly."""
        printable = " ".join(_redact(part, redact) for part in command)
        ctx.evidence.log(f"$ {printable}")
        if ctx.options.dry_run:
            ctx.evidence.log("dry-run: command not executed")
            return subprocess.CompletedProcess(list(command), 0, "", "")
        completed = subprocess.run(
            list(command),
            cwd=str(cwd) if cwd else None,
            env={**ctx.env, **(env or {})},
            capture_output=True,
            text=True,
            timeout=ctx.options.timeout_seconds,
            check=False,
        )
        if completed.stdout:
            ctx.evidence.log(completed.stdout.rstrip())
        if completed.stderr:
            ctx.evidence.log(completed.stderr.rstrip(), level="warn")
        if completed.returncode != 0:
            raise RemoteError(
                f"{printable} exited {completed.returncode}: "
                f"{(completed.stderr or completed.stdout).strip()[:2000]}"
            )
        return completed


def _redact(value: str, secrets: Sequence[str]) -> str:
    for secret in secrets:
        if secret and secret in value:
            value = value.replace(secret, "***")
    return value


class ManualPublisher(Publisher):
    """A store with no automatable upload path yet.

    Rather than pretend, this emits the exact checklist a human must follow and
    reports BLOCKED so a release run never claims a store was published.
    """

    #: Ordered human steps, rendered into the evidence directory.
    checklist: ClassVar[tuple[str, ...]] = ()
    console_url: ClassVar[str] = ""

    def publish(self, ctx: PublishContext) -> PublishResult:
        lines = [
            f"# Manual publish checklist — {self.name} / {ctx.profile_id} / {ctx.version}",
            "",
            f"Console: {self.console_url or '<not configured>'}",
            "",
            "## Artifacts",
        ]
        lines += [f"- `{a.filename}` (sha256 `{a.sha256}`)" for a in ctx.artifacts]
        lines += ["", "## Steps"]
        lines += [f"{index}. {step}" for index, step in enumerate(self.checklist, start=1)]
        lines += ["", "## Release notes", "", "```text", ctx.release_notes, "```", ""]
        path = ctx.evidence.write_text("MANUAL_CHECKLIST.md", "\n".join(lines))
        ctx.evidence.warn(
            f"{self.name} has no supported automation. Wrote manual checklist to {path}"
        )
        return self.result(
            ctx,
            PublishStatus.BLOCKED,
            f"{self.name} requires a manual upload; checklist written to {path}",
            {"checklist": str(path), "consoleUrl": self.console_url},
        )
