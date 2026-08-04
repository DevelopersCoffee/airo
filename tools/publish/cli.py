"""Command line interface for the Airo publishing framework.

    python3 -m tools.publish targets
    python3 -m tools.publish fetch  --tag v0.0.6
    python3 -m tools.publish plan   --tag v0.0.6 --profile tv --target apkpure
    python3 -m tools.publish run    --tag v0.0.6 --profile tv --target apkpure --submit
    python3 -m tools.publish login  apkpure
    python3 -m tools.publish doctor apkpure --package-id io.airo.app.tv

Artifacts always come from a published GitHub Release (`--tag`), never a local
build; `--manifest` exists only for an already-downloaded release directory.
`run` is submit-gated: it uploads and stages, and performs the irreversible
store submission only when `--submit` is passed.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

from .apkpure.console import (
    DEFAULT_CDP_ENDPOINT,
    DEFAULT_PROFILE_DIR,
    BrowserMode,
    console_session,
    interactive_chrome_login,
    interactive_login,
    resolve_browser_mode,
    resolve_browser_path,
)
from .apkpure.selectors import SelectorSet, console_url
from .config import REPO_ROOT, PublishConfig
from .errors import PublishError
from .evidence import EvidenceRecorder
from .fetch import fetch_release
from .models import ReleaseMetadata
from .publishers import PublishOptions, describe_targets
from .publishers.apkpure import DEFAULT_STORAGE_STATE
from .runner import RunRequest, exit_code_for, plan, run, summarise

DEFAULT_EVIDENCE_DIR = REPO_ROOT / "build" / "publish-evidence"
DEFAULT_DOWNLOAD_DIR = REPO_ROOT / "build" / "release-artifacts"
DEFAULT_REPOSITORY = "DevelopersCoffee/airo"


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="python3 -m tools.publish",
        description="Publish Airo release artifacts to configured stores.",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("targets", help="List configured publish targets.")

    fetch = sub.add_parser("fetch", help="Download a GitHub Release's assets and list its manifests.")
    fetch.add_argument("--tag", required=True, help="Release tag, e.g. v0.0.6")
    fetch.add_argument("--repository", default=DEFAULT_REPOSITORY)
    fetch.add_argument("--download-dir", type=Path, default=DEFAULT_DOWNLOAD_DIR)
    fetch.add_argument("--clean", action="store_true", help="Empty the directory first.")

    for name, help_text in (
        ("plan", "Resolve manifest + config and print what would be published."),
        ("run", "Publish to the selected targets."),
    ):
        cmd = sub.add_parser(name, help=help_text)
        source = cmd.add_mutually_exclusive_group(required=True)
        source.add_argument("--tag", help="GitHub Release tag to publish from, e.g. v0.0.6")
        source.add_argument("--manifest", type=Path, help="Path to an already-downloaded Release-Manifest.json")
        cmd.add_argument("--repository", default=DEFAULT_REPOSITORY)
        cmd.add_argument("--download-dir", type=Path, default=DEFAULT_DOWNLOAD_DIR,
                         help="Where --tag assets are downloaded.")
        cmd.add_argument("--config", type=Path, default=None, help="Path to airo-publish-targets.json")
        cmd.add_argument("--target", action="append", dest="targets", default=None,
                         help="Target name; repeat for several. Default: every enabled target.")
        cmd.add_argument("--profile", action="append", dest="profiles", default=None,
                         help="Release profile id; repeat for several. Default: every configured profile.")
        cmd.add_argument("--evidence-dir", type=Path, default=DEFAULT_EVIDENCE_DIR)
        cmd.add_argument("--timeout-seconds", type=int, default=600)
        cmd.add_argument("--quiet", action="store_true")
        if name == "run":
            cmd.add_argument("--dry-run", action="store_true",
                             help="Resolve and log everything, contact no remote service.")
            cmd.add_argument("--submit", action="store_true",
                             help="Perform the irreversible store submission. Off by default.")
            cmd.add_argument("--force", action="store_true",
                             help="Re-upload even when the version already exists remotely.")
            cmd.add_argument("--summary-file", type=Path, default=None,
                             help="Write a markdown summary here (default: $GITHUB_STEP_SUMMARY).")
            cmd.add_argument("--results-json", type=Path, default=None,
                             help="Write machine-readable results here.")

    login = sub.add_parser("login", help="Create or refresh a store browser session, by hand.")
    login.add_argument("target", choices=["apkpure"])
    login.add_argument("--storage-state", type=Path, default=None)
    login.add_argument(
        "--browser",
        choices=[mode.value for mode in BrowserMode],
        default=None,
        help="bundled saves a storage state; chrome signs in to a persistent Chrome profile.",
    )
    login.add_argument("--profile-dir", type=Path, default=None)
    login.add_argument(
        "--browser-path",
        default="default",
        help=(
            "Chromium-family browser for --browser chrome. 'default' (the default) uses "
            "this machine's default browser; or arc|brave|edge|chrome, or a full path."
        ),
    )

    doctor = sub.add_parser("doctor", help="Dump a store console page so selectors can be re-mapped.")
    doctor.add_argument("target", choices=["apkpure"])
    doctor.add_argument("--package-id", default="io.airo.app.tv")
    doctor.add_argument("--storage-state", type=Path, default=None)
    doctor.add_argument("--evidence-dir", type=Path, default=DEFAULT_EVIDENCE_DIR)
    doctor.add_argument("--headed", action="store_true")
    doctor.add_argument(
        "--browser",
        choices=[mode.value for mode in BrowserMode],
        default=None,
        help=(
            "bundled = Playwright Chromium + saved session (default); "
            "chrome = real Chrome with a persistent profile; "
            "cdp = attach to a Chrome you started and signed in yourself."
        ),
    )
    doctor.add_argument("--profile-dir", type=Path, default=None)
    doctor.add_argument("--cdp-endpoint", default=DEFAULT_CDP_ENDPOINT)
    doctor.add_argument(
        "--browser-path",
        default="default",
        help=(
            "Chromium-family browser for --browser chrome. 'default' (the default) uses "
            "this machine's default browser; or arc|brave|edge|chrome, or a full path."
        ),
    )

    return parser


def cmd_targets(_args: argparse.Namespace) -> int:
    print("Registered publishers:\n")
    for name, description in describe_targets():
        print(f"  {name:<10} {description}")
    print(
        "\nWhich of these actually run for a release is decided by "
        ".github/airo-publish-targets.json."
    )
    return 0


def _resolve_release(args: argparse.Namespace) -> ReleaseMetadata:
    """Publishing sources artifacts from a GitHub Release, never a local build."""
    if args.manifest:
        return ReleaseMetadata.from_manifest_file(args.manifest)
    only_profile = args.profiles[0] if args.profiles and len(args.profiles) == 1 else None
    fetched = fetch_release(args.tag, args.download_dir, args.repository)
    manifest = fetched.manifest_for(only_profile)
    print(f"[info] {args.tag}: using {manifest.name} from {fetched.directory}", file=sys.stderr)
    return ReleaseMetadata.from_manifest_file(manifest)


def cmd_fetch(args: argparse.Namespace) -> int:
    fetched = fetch_release(args.tag, args.download_dir, args.repository, clean=args.clean)
    print(f"Downloaded {args.tag} to {fetched.directory}\n")
    if not fetched.manifests:
        print("No release manifest found in the assets.")
        return 2
    print("Manifests by profile:")
    for profile_id, path in sorted(fetched.manifests.items()):
        print(f"  {profile_id:<10} {path.name}")
    return 0


def _resolve_targets(config: PublishConfig, requested: list[str] | None) -> list[str]:
    if requested:
        return requested
    return [name for name in config.target_names() if config.is_target_enabled(name)]


def cmd_plan(args: argparse.Namespace) -> int:
    release = _resolve_release(args)
    config = PublishConfig.load(args.config)
    request = RunRequest(
        release=release,
        config=config,
        targets=_resolve_targets(config, args.targets),
        profiles=args.profiles,
        options=PublishOptions(dry_run=True, timeout_seconds=args.timeout_seconds),
        evidence_dir=args.evidence_dir,
        quiet=True,
    )
    resolved = plan(request)
    entries = []
    for profile_config, ctx in resolved.contexts:
        entries.append(
            {
                "target": profile_config.target,
                "targetEnabled": config.is_target_enabled(profile_config.target),
                "profileId": profile_config.profile_id,
                "profileEnabled": profile_config.enabled,
                "packageId": profile_config.package_id or ctx.artifacts[0].package_id,
                "artifacts": [artifact.to_dict() for artifact in ctx.artifacts],
                "releaseNotesPreview": ctx.release_notes[:280],
                "releaseNotesChars": len(ctx.release_notes),
                "evidenceDir": str(ctx.evidence.root),
            }
        )
    print(
        json.dumps(
            {
                "release": {
                    "version": release.version,
                    "buildNumber": release.build_number,
                    "sourceSha": release.source_sha,
                    "manifest": str(release.manifest_path),
                },
                "plan": entries,
                "notInManifest": [
                    {"target": cfg.target, "profileId": cfg.profile_id, "reason": reason}
                    for cfg, reason in resolved.not_in_manifest
                ],
            },
            indent=2,
        )
    )
    return 0


def cmd_run(args: argparse.Namespace) -> int:
    release = _resolve_release(args)
    config = PublishConfig.load(args.config)
    options = PublishOptions(
        dry_run=args.dry_run,
        submit=args.submit,
        force=args.force,
        timeout_seconds=args.timeout_seconds,
    )
    if options.submit and options.dry_run:
        print("--submit is ignored with --dry-run", file=sys.stderr)

    results = run(
        RunRequest(
            release=release,
            config=config,
            targets=_resolve_targets(config, args.targets),
            profiles=args.profiles,
            options=options,
            evidence_dir=args.evidence_dir,
            quiet=args.quiet,
        )
    )

    summary = summarise(results, release)
    summary_path = args.summary_file or (
        Path(os.environ["GITHUB_STEP_SUMMARY"]) if os.environ.get("GITHUB_STEP_SUMMARY") else None
    )
    if summary_path:
        with summary_path.open("a", encoding="utf-8") as handle:
            handle.write(summary + "\n")
    if not args.quiet:
        print("\n" + summary)

    payload = {
        "version": release.version,
        "buildNumber": release.build_number,
        "results": [result.to_dict() for result in results],
    }
    if args.results_json:
        args.results_json.parent.mkdir(parents=True, exist_ok=True)
        args.results_json.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")

    return exit_code_for(results)


def _storage_state(args: argparse.Namespace) -> Path:
    if args.storage_state:
        return args.storage_state.expanduser()
    configured = os.environ.get("APKPURE_STORAGE_STATE", "")
    return Path(configured).expanduser() if configured else DEFAULT_STORAGE_STATE


def cmd_login(args: argparse.Namespace) -> int:
    mode = resolve_browser_mode(args.browser, dict(os.environ))
    evidence = EvidenceRecorder(root=DEFAULT_EVIDENCE_DIR / "login" / args.target)

    if mode is BrowserMode.CDP:
        print(
            "Nothing to do for --browser cdp: you sign in to APKPure in your own Chrome.\n"
            "Start it with remote debugging, sign in there, then run doctor/run with\n"
            "--browser cdp:\n"
            "  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' \\\n"
            "    --remote-debugging-port=9222 \\\n"
            f"    --user-data-dir=\"{DEFAULT_PROFILE_DIR}\"\n"
        )
        return 0

    if mode is BrowserMode.CHROME:
        profile = (args.profile_dir or DEFAULT_PROFILE_DIR).expanduser()
        executable = resolve_browser_path(args.browser_path)
        # Name the browser actually being launched: --browser-path defaults to
        # this machine's default browser, which is often not Google Chrome.
        browser_name = executable.name if executable else "Google Chrome"
        print(
            f"Launching {browser_name} ({executable or 'via Playwright channel=chrome'}).\n"
            "Sign in to APKPure yourself and clear any Cloudflare check — this tool never\n"
            "reads, types, or stores your password. The session stays inside the browser\n"
            f"profile at:\n  {profile}\n"
        )
        interactive_chrome_login(profile, evidence, executable_path=executable)
        print(f"\nDone. Re-run doctor/run with --browser chrome (profile: {profile}).")
        return 0

    state = _storage_state(args)
    print(
        "A browser window will open. Sign in to APKPure yourself — this tool never\n"
        "reads, types, or stores your password. Only the resulting session cookies\n"
        f"are saved, to:\n  {state}\n"
    )
    interactive_login(state, evidence)
    print(f"\nSaved. Set APKPURE_STORAGE_STATE={state} for non-interactive runs.")
    return 0


def cmd_doctor(args: argparse.Namespace) -> int:
    state = _storage_state(args)
    evidence = EvidenceRecorder(root=args.evidence_dir / "doctor" / args.target)
    selectors = SelectorSet.load()
    evidence.log(f"selector source: {selectors.source}")
    mode = resolve_browser_mode(args.browser, dict(os.environ))
    with console_session(
        storage_state=state,
        evidence=evidence,
        selectors=selectors,
        headless=not args.headed and mode is BrowserMode.BUNDLED,
        mode=mode,
        profile_dir=args.profile_dir,
        cdp_endpoint=args.cdp_endpoint,
        browser_path=resolve_browser_path(args.browser_path),
    ) as session:
        session.open_app(args.package_id)
        report = {
            "url": session.page.url,
            "consoleUrl": console_url(args.package_id),
            "selectorSource": selectors.source,
            "matches": {
                key: [
                    candidate
                    for candidate in selectors.candidates(key)
                    if session.page.locator(candidate).count() > 0
                ]
                for key in selectors.keys()
            },
        }
        session.open_upload_form()
        session.snapshot("doctor-upload-form")
        path = evidence.write_json("selector-report.json", report)
    unmatched = [key for key, hits in report["matches"].items() if not hits]
    print(f"Selector report: {path}")
    if unmatched:
        print("Selector keys with NO match on the live page:")
        for key in unmatched:
            print(f"  - {key}")
        print(
            "\nMap these against the HTML dumps in the evidence directory, write the new\n"
            "selectors into a JSON file, and point APKPURE_SELECTORS_FILE at it."
        )
        return 2
    print("Every selector key matched at least one element.")
    return 0


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    handlers = {
        "targets": cmd_targets,
        "fetch": cmd_fetch,
        "plan": cmd_plan,
        "run": cmd_run,
        "login": cmd_login,
        "doctor": cmd_doctor,
    }
    try:
        return handlers[args.command](args)
    except PublishError as exc:
        print(f"::error::{type(exc).__name__}: {exc}", file=sys.stderr)
        return exc.exit_code
    except KeyboardInterrupt:
        print("interrupted", file=sys.stderr)
        return 130


if __name__ == "__main__":
    sys.exit(main())
