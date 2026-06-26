import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT = REPO_ROOT / "scripts" / "quantize_model.py"


class QuantizeModelScriptTests(unittest.TestCase):
    def run_script(self, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(SCRIPT), *args],
            cwd=REPO_ROOT,
            text=True,
            capture_output=True,
            check=False,
        )

    def test_help_succeeds(self) -> None:
        result = self.run_script("--help")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("quantize-tflite", result.stdout)
        self.assertIn("export-hf", result.stdout)

    def test_quantize_tflite_requires_existing_input(self) -> None:
        with tempfile.TemporaryDirectory() as tempdir:
            output = Path(tempdir) / "output.tflite"
            result = self.run_script(
                "quantize-tflite",
                "--input-tflite",
                str(Path(tempdir) / "missing.tflite"),
                "--output-tflite",
                str(output),
            )

        self.assertEqual(result.returncode, 2)
        self.assertIn("--input-tflite file does not exist", result.stderr)

    def test_export_hf_dry_run_requires_exporter_binary(self) -> None:
        with tempfile.TemporaryDirectory() as tempdir:
            result = self.run_script(
                "export-hf",
                "--model",
                "google/gemma-3-270m-it",
                "--output-dir",
                tempdir,
                "--litert-torch-bin",
                "definitely-not-a-real-binary",
                "--dry-run",
            )

        self.assertEqual(result.returncode, 2)
        self.assertIn("Could not find `definitely-not-a-real-binary`", result.stderr)


if __name__ == "__main__":
    unittest.main()
