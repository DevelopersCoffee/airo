"""Website publisher.

Writes the download metadata the public docs site reads, so the site's download
links, versions, and checksums come from the same manifest the binaries were
hashed with instead of from a hand-edited page.
"""

from __future__ import annotations

import json
from typing import ClassVar

from ..config import REPO_ROOT
from ..errors import ConfigError
from ..models import PublishResult, PublishStatus
from .base import Publisher, PublishContext


class WebsitePublisher(Publisher):
    name: ClassVar[str] = "website"
    description: ClassVar[str] = "Download metadata JSON for the public docs site"

    def publish(self, ctx: PublishContext) -> PublishResult:
        raw_output = ctx.config.require_option("outputPath")
        repo_root = REPO_ROOT.resolve()
        output = (repo_root / str(raw_output)).resolve()
        try:
            output.relative_to(repo_root)
        except ValueError as exc:
            raise ConfigError(
                f"{ctx.config.context}.options.outputPath must stay inside the repository: {output}"
            ) from exc

        base_url = str(ctx.config.option("downloadBaseUrl", "")).format(
            version=ctx.version, profileId=ctx.profile_id
        )
        payload = {
            "schemaVersion": 1,
            "profileId": ctx.profile_id,
            "version": ctx.version,
            "buildNumber": ctx.release.build_number,
            "sourceSha": ctx.release.source_sha,
            "releaseNotes": ctx.release_notes,
            "downloads": [
                {
                    "filename": artifact.filename,
                    "url": f"{base_url.rstrip('/')}/{artifact.filename}" if base_url else "",
                    "packageId": artifact.package_id,
                    "artifactType": artifact.artifact_type,
                    "abi": artifact.abi,
                    "sizeBytes": artifact.size_bytes,
                    "sha256": artifact.sha256,
                }
                for artifact in ctx.artifacts
            ],
        }

        if ctx.options.dry_run:
            ctx.evidence.write_json("website-plan.json", payload)
            return self.result(
                ctx, PublishStatus.DRY_RUN, f"Would write {output}", {"outputPath": str(output)}
            )

        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        ctx.evidence.log(f"wrote {output}")
        ctx.evidence.write_json("website-result.json", payload)
        return self.result(
            ctx,
            PublishStatus.SUCCEEDED,
            f"Wrote download metadata for {len(ctx.artifacts)} artifact(s) to {output}",
            {"outputPath": str(output)},
        )
