#!/usr/bin/env python3
"""Scan an APK file or URL with the VirusTotal API v3."""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Mapping

API_BASE = "https://www.virustotal.com/api/v3"
GUI_BASE = "https://www.virustotal.com/gui"
DEFAULT_TIMEOUT_SECONDS = 300
DEFAULT_POLL_INTERVAL_SECONDS = 10
DIRECT_UPLOAD_LIMIT_BYTES = 32 * 1024 * 1024
STAT_NAMES = ("harmless", "malicious", "suspicious", "undetected")


class ScanError(RuntimeError):
    """A user-facing VirusTotal scan failure."""


@dataclass(frozen=True)
class ScanResult:
    report_url: str
    badge_url: str
    certificate: str
    stats: Mapping[str, int]


class VirusTotalClient:
    def __init__(
        self,
        api_key: str,
        *,
        opener: Callable[..., object] = urllib.request.urlopen,
        sleep: Callable[[float], None] = time.sleep,
        monotonic: Callable[[], float] = time.monotonic,
        poll_interval: float = DEFAULT_POLL_INTERVAL_SECONDS,
    ) -> None:
        self._api_key = api_key
        self._opener = opener
        self._sleep = sleep
        self._monotonic = monotonic
        self._poll_interval = poll_interval

    def submit_file(self, apk_path: Path) -> str:
        upload_url = f"{API_BASE}/files"
        if apk_path.stat().st_size > DIRECT_UPLOAD_LIMIT_BYTES:
            upload_url = self._large_file_upload_url()
        boundary = f"----AiroVirusTotal{uuid.uuid4().hex}"
        content = apk_path.read_bytes()
        body = (
            f"--{boundary}\r\n"
            f'Content-Disposition: form-data; name="file"; filename="{apk_path.name}"\r\n'
            "Content-Type: application/vnd.android.package-archive\r\n\r\n"
        ).encode("utf-8") + content + f"\r\n--{boundary}--\r\n".encode("ascii")
        payload = self._request_json(
            upload_url,
            data=body,
            headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
        )
        return _analysis_id(payload)

    def _large_file_upload_url(self) -> str:
        payload = self._request_json(f"{API_BASE}/files/upload_url")
        upload_url = payload.get("data")
        if not isinstance(upload_url, str) or not upload_url.startswith("https://"):
            raise ScanError("VirusTotal did not return a valid large-file upload URL")
        return upload_url

    def submit_url(self, url: str) -> str:
        body = urllib.parse.urlencode({"url": url}).encode("ascii")
        payload = self._request_json(
            f"{API_BASE}/urls",
            data=body,
            headers={"Content-Type": "application/x-www-form-urlencoded"},
        )
        return _analysis_id(payload)

    def wait_for_analysis(
        self, analysis_id: str, *, timeout_seconds: float = DEFAULT_TIMEOUT_SECONDS
    ) -> Mapping[str, int]:
        deadline = self._monotonic() + timeout_seconds
        first_poll = True
        while True:
            if not first_poll and self._monotonic() >= deadline:
                raise ScanError(
                    f"VirusTotal analysis did not complete within {timeout_seconds:g} seconds"
                )
            first_poll = False
            payload = self._request_json(f"{API_BASE}/analyses/{analysis_id}")
            data = payload.get("data")
            if not isinstance(data, dict):
                raise ScanError("VirusTotal returned an invalid analysis object")
            attributes = data.get("attributes")
            if not isinstance(attributes, dict):
                raise ScanError("VirusTotal analysis did not include attributes")
            status = attributes.get("status")
            if status == "completed":
                raw_stats = attributes.get("stats")
                if not isinstance(raw_stats, dict):
                    raise ScanError("VirusTotal completed the analysis without detection stats")
                return {name: _stat_value(raw_stats, name) for name in STAT_NAMES}
            self._sleep(min(self._poll_interval, max(0, deadline - self._monotonic())))

    def _request_json(
        self,
        url: str,
        *,
        data: bytes | None = None,
        headers: Mapping[str, str] | None = None,
    ) -> dict:
        request_headers = {"x-apikey": self._api_key, "Accept": "application/json"}
        request_headers.update(headers or {})
        request = urllib.request.Request(
            url, data=data, headers=request_headers, method="POST" if data is not None else "GET"
        )
        try:
            with self._opener(request, timeout=30) as response:
                payload = json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as error:
            detail = error.read(1000).decode("utf-8", errors="replace")
            raise ScanError(f"VirusTotal API returned HTTP {error.code}: {detail}") from error
        except (urllib.error.URLError, TimeoutError) as error:
            raise ScanError(f"VirusTotal API request failed: {error}") from error
        except (UnicodeDecodeError, json.JSONDecodeError) as error:
            raise ScanError("VirusTotal API returned invalid JSON") from error
        if not isinstance(payload, dict):
            raise ScanError("VirusTotal API returned an unexpected response")
        return payload


def scan_apk(
    client: VirusTotalClient, apk_path: Path, *, timeout_seconds: float
) -> ScanResult:
    if not apk_path.is_file():
        raise ScanError(f"APK file does not exist: {apk_path}")
    if apk_path.suffix.lower() != ".apk":
        raise ScanError(f"Expected an .apk file: {apk_path}")
    sha256 = _sha256(apk_path)
    analysis_id = client.submit_file(apk_path)
    stats = client.wait_for_analysis(analysis_id, timeout_seconds=timeout_seconds)
    return _build_result(stats, f"{GUI_BASE}/file/{sha256}", f"`{apk_path.name}`")


def scan_url(client: VirusTotalClient, url: str, *, timeout_seconds: float) -> ScanResult:
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise ScanError("--url must be an absolute HTTP(S) URL")
    analysis_id = client.submit_url(url)
    stats = client.wait_for_analysis(analysis_id, timeout_seconds=timeout_seconds)
    url_id = base64.urlsafe_b64encode(url.encode("utf-8")).decode("ascii").rstrip("=")
    return _build_result(stats, f"{GUI_BASE}/url/{url_id}", f"[release URL]({url})")


def _build_result(stats: Mapping[str, int], report_url: str, subject: str) -> ScanResult:
    malicious = stats["malicious"]
    suspicious = stats["suspicious"]
    if malicious or suspicious:
        raise ScanError(
            "VirusTotal detected unsafe results: "
            f"malicious={malicious}, suspicious={suspicious}"
        )
    total = sum(stats.values())
    if total == 0:
        raise ScanError("VirusTotal returned no engine detection results")
    badge_url = (
        "https://img.shields.io/badge/"
        f"VirusTotal-Clean%20(0%2F{total})-brightgreen?logo=virustotal"
    )
    certificate = "\n".join(
        [
            "### VirusTotal Release Trust Certificate",
            "",
            f"[![VirusTotal: Clean (0/{total})]({badge_url})]({report_url})",
            "",
            f"- **Artifact:** {subject}",
            f"- **VirusTotal report:** [View scan certificate]({report_url})",
            f"- **Detections:** 0/{total} malicious or suspicious",
            f"- **Stats:** harmless {stats['harmless']}, malicious {malicious}, "
            f"suspicious {suspicious}, undetected {stats['undetected']}",
        ]
    )
    return ScanResult(report_url, badge_url, certificate, stats)


def _analysis_id(payload: Mapping[str, object]) -> str:
    data = payload.get("data")
    analysis_id = data.get("id") if isinstance(data, dict) else None
    if not isinstance(analysis_id, str) or not analysis_id:
        raise ScanError("VirusTotal submission response did not include an analysis id")
    return analysis_id


def _stat_value(stats: Mapping[str, object], name: str) -> int:
    value = stats.get(name, 0)
    if not isinstance(value, int) or isinstance(value, bool) or value < 0:
        raise ScanError(f"VirusTotal returned an invalid {name!r} detection count")
    return value


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as apk:
        for chunk in iter(lambda: apk.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _write_github_output(path: Path, result: ScanResult) -> None:
    delimiter = f"AIRO_VT_{uuid.uuid4().hex}"
    with path.open("a", encoding="utf-8") as output:
        output.write(f"report_url={result.report_url}\n")
        output.write(f"badge_url={result.badge_url}\n")
        output.write(f"certificate<<{delimiter}\n{result.certificate}\n{delimiter}\n")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--apk-path", type=Path, help="Local APK file to upload and scan")
    source.add_argument("--url", help="HTTP(S) URL to submit for URL reputation analysis")
    parser.add_argument(
        "--timeout-seconds",
        type=float,
        default=DEFAULT_TIMEOUT_SECONDS,
        help=argparse.SUPPRESS,
    )
    parser.add_argument(
        "--certificate-output",
        type=Path,
        help="Write the Markdown trust certificate to this file",
    )
    parser.add_argument(
        "--github-output",
        type=Path,
        help="Append report_url, badge_url, and certificate to a GitHub output file",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    api_key = os.environ.get("VIRUSTOTAL_API_KEY")
    if not api_key:
        print("error: VIRUSTOTAL_API_KEY is not set", file=sys.stderr)
        return 2

    try:
        client = VirusTotalClient(api_key)
        if args.apk_path is not None:
            result = scan_apk(client, args.apk_path, timeout_seconds=args.timeout_seconds)
        else:
            result = scan_url(client, args.url, timeout_seconds=args.timeout_seconds)
        if args.certificate_output:
            args.certificate_output.write_text(result.certificate + "\n", encoding="utf-8")
        if args.github_output:
            _write_github_output(args.github_output, result)
    except (OSError, ScanError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

    print(
        "Detection stats: "
        + ", ".join(f"{name}={result.stats[name]}" for name in STAT_NAMES)
    )
    print(f"VirusTotal report: {result.report_url}")
    print(f"Shields.io badge: {result.badge_url}")
    print()
    print(result.certificate)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
