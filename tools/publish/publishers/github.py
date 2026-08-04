"""GitHub Releases publisher.

Attaches the manifest-described artifacts (plus `SHA256SUMS` and the manifest
itself) to the release tag. Idempotent: re-running uploads with `--clobber` only
when `--force` is passed, otherwise existing assets are left alone.
"""

from __future__ import annotations

from typing import ClassVar

from ..errors import RemoteError
from ..models import PublishResult, PublishStatus
from .base import Publisher, PublishContext

SIDECAR_FILENAMES = ("SHA256SUMS",)


class GitHubPublisher(Publisher):
    name: ClassVar[str] = "github"
    description: ClassVar[str] = "GitHub Release assets for the release tag"
    required_env: ClassVar[tuple[str, ...]] = ("GITHUB_TOKEN",)
    required_binaries: ClassVar[tuple[str, ...]] = ("gh",)

    def publish(self, ctx: PublishContext) -> PublishResult:
        repository = ctx.config.option("repository") or ctx.env.get(
            "GITHUB_REPOSITORY", "DevelopersCoffee/airo"
        )
        tag = str(ctx.config.option("tag", "{version}")).format(
            version=ctx.version, buildNumber=ctx.release.build_number, profileId=ctx.profile_id
        )

        uploads = [artifact.path for artifact in ctx.artifacts]
        for sidecar in SIDECAR_FILENAMES:
            path = ctx.release.artifacts_dir / sidecar
            if path.is_file():
                uploads.append(path)
            else:
                ctx.evidence.warn(f"{sidecar} not found next to the manifest; not attaching")
        uploads.append(ctx.release.manifest_path)

        existing = self._existing_assets(ctx, repository, tag)
        pending = [path for path in uploads if ctx.options.force or path.name not in existing]
        skipped = [path.name for path in uploads if path.name in existing]
        if skipped and not ctx.options.force:
            ctx.evidence.log(f"already attached, skipping: {', '.join(skipped)}")

        if not pending:
            return self.result(
                ctx,
                PublishStatus.SKIPPED,
                f"All {len(uploads)} asset(s) already attached to {tag}",
                {"tag": tag, "repository": repository, "skipped": skipped},
            )

        if ctx.options.dry_run:
            ctx.evidence.log(f"dry-run: would upload {len(pending)} asset(s) to {repository}@{tag}")
            return self.result(
                ctx,
                PublishStatus.DRY_RUN,
                f"Would upload {len(pending)} asset(s) to {repository}@{tag}",
                {"tag": tag, "repository": repository, "pending": [p.name for p in pending]},
            )

        command = ["gh", "release", "upload", tag, *[str(path) for path in pending],
                   "--repo", repository]
        if ctx.options.force:
            command.append("--clobber")
        self.run(ctx, command)

        ctx.evidence.write_json(
            "github-upload.json",
            {"tag": tag, "repository": repository, "uploaded": [p.name for p in pending]},
        )
        return self.result(
            ctx,
            PublishStatus.SUCCEEDED,
            f"Uploaded {len(pending)} asset(s) to {repository}@{tag}",
            {"tag": tag, "repository": repository, "uploaded": [p.name for p in pending]},
        )

    def _existing_assets(self, ctx: PublishContext, repository: str, tag: str) -> set[str]:
        if ctx.options.dry_run:
            return set()
        try:
            completed = self.run(
                ctx,
                [
                    "gh", "release", "view", tag,
                    "--repo", repository,
                    "--json", "assets",
                    "--jq", ".assets[].name",
                ],
            )
        except RemoteError as exc:
            raise RemoteError(
                f"GitHub Release {tag!r} not found in {repository}. "
                "Create the release before attaching assets."
            ) from exc
        return {line.strip() for line in completed.stdout.splitlines() if line.strip()}
