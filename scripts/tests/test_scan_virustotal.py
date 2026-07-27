import hashlib
import io
import json
import sys
import tempfile
import unittest
import urllib.parse
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import scan_virustotal as vt


class FakeResponse:
    def __init__(self, payload):
        self._body = json.dumps(payload).encode()

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return False

    def read(self):
        return self._body


class RecordingOpener:
    def __init__(self, payloads):
        self.payloads = iter(payloads)
        self.requests = []

    def __call__(self, request, timeout):
        self.requests.append((request, timeout))
        return FakeResponse(next(self.payloads))


CLEAN_STATS = {
    "harmless": 62,
    "malicious": 0,
    "suspicious": 0,
    "undetected": 8,
}


class VirusTotalScanTests(unittest.TestCase):
    def test_clean_apk_submission_and_certificate(self):
        opener = RecordingOpener(
            [
                {"data": {"id": "analysis-1"}},
                {"data": {"attributes": {"status": "completed", "stats": CLEAN_STATS}}},
            ]
        )
        client = vt.VirusTotalClient("secret", opener=opener)
        with tempfile.TemporaryDirectory() as directory:
            apk = Path(directory) / "Airo-TV-0.0.5.apk"
            apk.write_bytes(b"test apk bytes")
            result = vt.scan_apk(client, apk, timeout_seconds=300)

        expected_hash = hashlib.sha256(b"test apk bytes").hexdigest()
        self.assertEqual(result.report_url, f"{vt.GUI_BASE}/file/{expected_hash}")
        self.assertEqual(
            result.badge_url,
            "https://img.shields.io/badge/"
            "VirusTotal-Clean%20(0%2F70)-brightgreen?logo=virustotal",
        )
        self.assertIn("### VirusTotal Release Trust Certificate", result.certificate)
        self.assertIn("harmless 62, malicious 0, suspicious 0, undetected 8", result.certificate)
        upload = opener.requests[0][0]
        self.assertEqual(upload.full_url, f"{vt.API_BASE}/files")
        self.assertTrue(upload.headers["Content-type"].startswith("multipart/form-data;"))
        self.assertNotIn("secret", result.certificate)

    def test_url_submission_uses_form_encoding_and_url_report(self):
        url = "https://github.com/DevelopersCoffee/airo/releases/download/v0.0.5/Airo-TV-0.0.5.apk"
        opener = RecordingOpener(
            [
                {"data": {"id": "analysis-url"}},
                {"data": {"attributes": {"status": "completed", "stats": CLEAN_STATS}}},
            ]
        )
        result = vt.scan_url(
            vt.VirusTotalClient("secret", opener=opener), url, timeout_seconds=300
        )
        request = opener.requests[0][0]
        self.assertEqual(request.full_url, f"{vt.API_BASE}/urls")
        self.assertEqual(urllib.parse.parse_qs(request.data.decode()), {"url": [url]})
        self.assertIn("/gui/url/", result.report_url)

    def test_large_apk_uses_one_time_upload_url(self):
        upload_url = "https://www.virustotal.com/_ah/upload/one-time"
        opener = RecordingOpener(
            [
                {"data": upload_url},
                {"data": {"id": "analysis-large"}},
            ]
        )
        client = vt.VirusTotalClient("secret", opener=opener)
        with tempfile.TemporaryDirectory() as directory:
            apk = Path(directory) / "large.apk"
            apk.write_bytes(b"larger than test threshold")
            with mock.patch.object(vt, "DIRECT_UPLOAD_LIMIT_BYTES", 1):
                self.assertEqual(client.submit_file(apk), "analysis-large")
        self.assertEqual(opener.requests[0][0].full_url, f"{vt.API_BASE}/files/upload_url")
        self.assertEqual(opener.requests[1][0].full_url, upload_url)

    def test_malicious_or_suspicious_result_fails(self):
        stats = dict(CLEAN_STATS, suspicious=1)
        with self.assertRaisesRegex(vt.ScanError, "malicious=0, suspicious=1"):
            vt._build_result(stats, "https://example.test/report", "artifact.apk")

    def test_polling_times_out(self):
        opener = RecordingOpener(
            [
                {"data": {"attributes": {"status": "queued"}}},
                {"data": {"attributes": {"status": "in-progress"}}},
            ]
        )
        ticks = iter([0, 0, 1, 1, 2])
        client = vt.VirusTotalClient(
            "secret",
            opener=opener,
            sleep=lambda _seconds: None,
            monotonic=lambda: next(ticks),
            poll_interval=1,
        )
        with self.assertRaisesRegex(vt.ScanError, "within 2 seconds"):
            client.wait_for_analysis("analysis-1", timeout_seconds=2)

    def test_parser_requires_exactly_one_source(self):
        parser = vt.build_parser()
        with mock.patch("sys.stderr", new=io.StringIO()):
            with self.assertRaises(SystemExit):
                parser.parse_args([])
            with self.assertRaises(SystemExit):
                parser.parse_args(
                    ["--apk-path", "a.apk", "--url", "https://example.test/a.apk"]
                )

    def test_github_output_contains_multiline_certificate(self):
        result = vt._build_result(CLEAN_STATS, "https://example.test/report", "`airo.apk`")
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "github-output"
            vt._write_github_output(output, result)
            content = output.read_text()
        self.assertIn("report_url=https://example.test/report\n", content)
        self.assertIn("badge_url=https://img.shields.io/", content)
        self.assertIn("certificate<<AIRO_VT_", content)
        self.assertIn(result.certificate, content)


if __name__ == "__main__":
    unittest.main()
