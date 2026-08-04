"""Orchestration: manifest + config + publisher -> results.

The runner owns everything that must happen the same way for every store:
artifact integrity verification, release-note resolution, preflight gating,
evidence directories, and result aggregation. Publishers only implement the
part that is genuinely store-specific.
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path
from typing import Sequence

from .config import PublishConfig, TargetProfileConfig
from .errors import PublishError
from .evidence import EvidenceRecorder
from .models import PublishResult, PublishStatus, ReleaseMetadata
from .publishers import PublishContext, PublishOptions, get_publisher


@dataclass
class RunRequest:
    release: ReleaseMetadata
    config: PublishConfig
    targets: Sequence[str]
    profiles: Sequence[str] | None
    options: PublishOptions
    evidence_dir: Path
    quiet: bool = False
    #: Targets the caller named on the command line. `enabled: false` keeps a
    #: target out of the default sweep, but naming it explicitly *is* the
    #: deliberate opt-in, so it runs. Anything not named here still obeys the
    #: config flag.
    explicit_targets: frozenset[str] = frozenset()


@dataclass
class Plan:
    """What the runner resolved, and what it deliberately left out.

    A release leg builds one profile at a time, so a config that also declares
    other profiles must not fail the run — but a profile the caller asked for by
    name and the manifest does not contain is a genuine error, raised by
    `profiles_for`/`select_artifacts` rather than silently dropped here.
    """

    contexts: list[tuple[TargetProfileConfig, PublishContext]]
    not_in_manifest: list[tuple[TargetProfileConfig, str]]


def plan(request: RunRequest) -> Plan:
    """Resolve every (target, profile) pair into a fully-populated context."""
    contexts: list[tuple[TargetProfileConfig, PublishContext]] = []
    absent: list[tuple[TargetProfileConfig, str]] = []
    manifest_profiles = set(request.release.profile_ids())
    for target in request.targets:
        for profile_config in request.config.profiles_for(target, request.profiles):
            if request.profiles is None and profile_config.profile_id not in manifest_profiles:
                absent.append(
                    (
                        profile_config,
                        f"release manifest has no {profile_config.profile_id!r} artifacts "
                        f"(manifest profiles: {', '.join(sorted(manifest_profiles)) or 'none'})",
                    )
                )
                continue
            evidence = EvidenceRecorder.for_attempt(
                request.evidence_dir,
                target,
                profile_config.profile_id,
                request.release.version,
                quiet=request.quiet,
            )
            artifacts = profile_config.select_artifacts(request.release)
            request.release.verify_artifacts(artifacts)
            notes = profile_config.release_notes.resolve(
                request.release, profile_config.profile_id
            )
            contexts.append(
                (
                    profile_config,
                    PublishContext(
                        release=request.release,
                        config=profile_config,
                        artifacts=artifacts,
                        options=request.options,
                        evidence=evidence,
                        release_notes=notes,
                        env=dict(os.environ),
                    ),
                )
            )
    return Plan(contexts=contexts, not_in_manifest=absent)


def run(request: RunRequest) -> list[PublishResult]:
    resolved = plan(request)
    results: list[PublishResult] = []
    for profile_config, reason in resolved.not_in_manifest:
        if not request.quiet:
            print(f"[info] {profile_config.context}: skipped — {reason}")
    for profile_config, ctx in resolved.contexts:
        publisher = get_publisher(profile_config.target)

        explicitly_requested = profile_config.target in request.explicit_targets
        if not request.config.is_target_enabled(profile_config.target) and not explicitly_requested:
            results.append(
                _skipped(
                    publisher.name,
                    ctx,
                    f"target {profile_config.target!r} is disabled in config "
                    "(name it with --target to run it anyway)",
                )
            )
            continue
        if explicitly_requested and not request.config.is_target_enabled(profile_config.target):
            ctx.evidence.warn(
                f"target {profile_config.target!r} is disabled in config but was named "
                "explicitly — running it"
            )
        if not profile_config.enabled:
            results.append(
                _skipped(publisher.name, ctx, f"profile {ctx.profile_id!r} is disabled in config")
            )
            continue

        ctx.evidence.log(
            f"=== {publisher.name} / {ctx.profile_id} / {ctx.version} "
            f"(dry_run={request.options.dry_run}, submit={request.options.submit}) ==="
        )
        for artifact in ctx.artifacts:
            ctx.evidence.log(f"artifact {artifact.filename} sha256={artifact.sha256} verified")

        blockers = publisher.preflight(ctx)
        if blockers:
            for blocker in blockers:
                ctx.evidence.error(blocker)
            results.append(
                PublishResult(
                    target=publisher.name,
                    profile_id=ctx.profile_id,
                    status=PublishStatus.BLOCKED,
                    message="preflight failed: " + "; ".join(blockers),
                    artifacts=[a.filename for a in ctx.artifacts],
                    evidence=ctx.evidence.artifacts(),
                    details={"blockers": blockers},
                )
            )
            continue

        try:
            result = publisher.publish(ctx)
        except PublishError as exc:
            ctx.evidence.error(f"{type(exc).__name__}: {exc}")
            result = PublishResult(
                target=publisher.name,
                profile_id=ctx.profile_id,
                status=PublishStatus.FAILED,
                message=f"{type(exc).__name__}: {exc}",
                artifacts=[a.filename for a in ctx.artifacts],
                evidence=ctx.evidence.artifacts(),
                details={"errorType": type(exc).__name__},
            )
        except Exception as exc:  # noqa: BLE001 - never lose the evidence trail
            ctx.evidence.error(f"unexpected {type(exc).__name__}: {exc}")
            result = PublishResult(
                target=publisher.name,
                profile_id=ctx.profile_id,
                status=PublishStatus.FAILED,
                message=f"unexpected {type(exc).__name__}: {exc}",
                artifacts=[a.filename for a in ctx.artifacts],
                evidence=ctx.evidence.artifacts(),
                details={"errorType": type(exc).__name__},
            )

        result.evidence = ctx.evidence.artifacts()
        ctx.evidence.log(f"result: {result.status.value} — {result.message}")
        results.append(result)
    return results


def _skipped(target: str, ctx: PublishContext, reason: str) -> PublishResult:
    ctx.evidence.log(f"skipped: {reason}")
    return PublishResult(
        target=target,
        profile_id=ctx.profile_id,
        status=PublishStatus.SKIPPED,
        message=reason,
        artifacts=[a.filename for a in ctx.artifacts],
        evidence=ctx.evidence.artifacts(),
    )


def summarise(results: Sequence[PublishResult], release: ReleaseMetadata) -> str:
    """Markdown table suitable for `$GITHUB_STEP_SUMMARY`."""
    lines = [
        f"# Publish summary — {release.version} (build {release.build_number})",
        "",
        "| Target | Profile | Status | Artifacts | Detail |",
        "| --- | --- | --- | --- | --- |",
    ]
    icons = {
        PublishStatus.SUCCEEDED: "✅",
        PublishStatus.SKIPPED: "⏭️",
        PublishStatus.DRY_RUN: "🧪",
        PublishStatus.STAGED: "🅿️",
        PublishStatus.BLOCKED: "🚧",
        PublishStatus.FAILED: "❌",
    }
    for result in results:
        artifacts = ", ".join(f"`{name}`" for name in result.artifacts) or "—"
        detail = result.message.replace("|", "\\|")
        lines.append(
            f"| {result.target} | {result.profile_id} | "
            f"{icons[result.status]} {result.status.value} | {artifacts} | {detail} |"
        )
    lines.append("")
    return "\n".join(lines)


def exit_code_for(results: Sequence[PublishResult]) -> int:
    if any(result.status is PublishStatus.FAILED for result in results):
        return 1
    if any(result.status is PublishStatus.BLOCKED for result in results):
        return 2
    return 0
