import importlib.util
import tempfile
import unittest
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "process_store_screenshots",
    ROOT / "scripts" / "process-store-screenshots.py",
)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


class StoreScreenshotProcessingTest(unittest.TestCase):
    def test_flattens_alpha_and_pads_mobile_capture_to_two_to_one(self):
        image = Image.new("RGBA", (390, 844), (20, 184, 166, 100))

        result = MODULE.store_ready(image)

        self.assertEqual(result.mode, "RGB")
        self.assertEqual(result.size, (422, 844))

    def test_rejects_dimensions_below_store_minimum(self):
        with self.assertRaisesRegex(ValueError, "minimum dimension"):
            MODULE.validate(Image.new("RGB", (319, 500)))

    def test_rejects_empty_runtime_capture_directory(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            raw = root / "raw"
            raw.mkdir()
            feature_source = root / "feature.png"
            Image.new("RGB", (1024, 500)).save(feature_source)
            args = type(
                "Args",
                (),
                {
                    "input_dir": raw,
                    "output_dir": root / "output",
                    "feature_source": feature_source,
                    "feature_output": root / "output" / "feature.png",
                    "manifest": root / "output" / "manifest.json",
                },
            )()

            with self.assertRaisesRegex(ValueError, "no PNG screenshots"):
                MODULE.process(args)

    def test_writes_exact_rgb_feature_graphic_and_manifest(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            raw = root / "raw"
            output = root / "output"
            raw.mkdir()
            Image.new("RGBA", (1920, 1080), (1, 2, 3, 128)).save(
                raw / "browse.png"
            )
            feature_source = root / "feature-source.png"
            Image.new("RGB", (1600, 900), (4, 5, 6)).save(feature_source)
            feature_output = output / "feature-graphic-1024x500.png"
            manifest = output / "store-assets.json"
            args = type(
                "Args",
                (),
                {
                    "input_dir": raw,
                    "output_dir": output,
                    "feature_source": feature_source,
                    "feature_output": feature_output,
                    "manifest": manifest,
                },
            )()

            records = MODULE.process(args)

            with Image.open(feature_output) as feature:
                self.assertEqual(feature.size, (1024, 500))
                self.assertEqual(feature.mode, "RGB")
            self.assertEqual(len(records), 2)
            self.assertIn('"alpha": false', manifest.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
