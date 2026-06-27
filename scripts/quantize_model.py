#!/usr/bin/env python3
"""Developer wrapper for Google AI Edge quantization flows.

This script intentionally keeps repository-side logic thin:
- `quantize-tflite` wraps the AI Edge Quantizer for existing LiteRT/TFLite files.
- `export-hf` forwards to the upstream `litert-torch export_hf` CLI for
  Hugging Face or local checkpoints that the upstream exporter supports.

Run `python scripts/quantize_model.py --help` for usage.
"""

from __future__ import annotations

import argparse
import importlib
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Callable


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Google AI Edge quantization helper for Airo developers.",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    quantize_parser = subparsers.add_parser(
        "quantize-tflite",
        help="Quantize an existing LiteRT/TFLite file with AI Edge Quantizer.",
    )
    quantize_parser.add_argument(
        "--input-tflite",
        required=True,
        help="Path to the source .tflite or .litert model.",
    )
    quantize_parser.add_argument(
        "--output-tflite",
        required=True,
        help="Path for the quantized output artifact.",
    )
    quantize_parser.add_argument(
        "--recipe",
        default="dynamic_wi8_afp32",
        help=(
            "Built-in AI Edge Quantizer recipe. "
            "Default: dynamic_wi8_afp32."
        ),
    )
    quantize_parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Allow overwriting an existing output file.",
    )
    quantize_parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Validate arguments and print the intended action without running it.",
    )
    quantize_parser.set_defaults(func=run_quantize_tflite)

    export_parser = subparsers.add_parser(
        "export-hf",
        help="Export a supported Hugging Face or local checkpoint via litert-torch.",
    )
    export_parser.add_argument(
        "--model",
        required=True,
        help="Hugging Face model id or local checkpoint directory.",
    )
    export_parser.add_argument(
        "--output-dir",
        required=True,
        help="Directory where litert-torch should write the exported artifacts.",
    )
    export_parser.add_argument(
        "--litert-torch-bin",
        default="litert-torch",
        help="Binary to use for the upstream exporter. Default: litert-torch.",
    )
    export_parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Allow exporting into a non-empty output directory.",
    )
    export_parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Validate arguments and print the intended action without running it.",
    )
    export_parser.add_argument(
        "extra_args",
        nargs=argparse.REMAINDER,
        help=(
            "Additional arguments forwarded to `litert-torch export_hf`. "
            "Prefix them with `--`, for example: "
            "`... export-hf --model ... --output-dir ... -- "
            "--prefill_seq_lens 512,1024`"
        ),
    )
    export_parser.set_defaults(func=run_export_hf)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return args.func(args)
    except QuantizationToolError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2


class QuantizationToolError(RuntimeError):
    """Raised for actionable user-facing CLI errors."""


def run_quantize_tflite(args: argparse.Namespace) -> int:
    input_path = _existing_file(args.input_tflite, flag="--input-tflite")
    output_path = Path(args.output_tflite).expanduser().resolve()
    _prepare_output_path(output_path, overwrite=args.overwrite, is_dir=False)

    recipe_factory = _resolve_recipe(args.recipe)
    if args.dry_run:
        print("Dry run: quantize-tflite")
        print(f"  input:   {input_path}")
        print(f"  output:  {output_path}")
        print(f"  recipe:  {args.recipe}")
        return 0

    try:
        quantizer_module = importlib.import_module("ai_edge_quantizer")
    except ImportError as exc:
        raise QuantizationToolError(
            "Missing dependency `ai-edge-quantizer`. Install it first, for "
            "example: `python3 -m pip install ai-edge-quantizer`."
        ) from exc

    quantizer = quantizer_module.Quantizer(model_path=str(input_path))
    recipe = recipe_factory()
    quantizer.quantize(recipe=recipe, save_path=str(output_path))

    print("Quantization complete.")
    print(f"  output: {output_path}")
    print("Suggested next step:")
    print(f"  file {output_path}")
    return 0


def run_export_hf(args: argparse.Namespace) -> int:
    output_dir = Path(args.output_dir).expanduser().resolve()
    _prepare_output_path(output_dir, overwrite=args.overwrite, is_dir=True)

    binary = shutil.which(args.litert_torch_bin)
    if binary is None:
        raise QuantizationToolError(
            f"Could not find `{args.litert_torch_bin}` in PATH. Install the "
            "LiteRT Torch exporter first, then retry."
        )

    extra_args = list(args.extra_args)
    if extra_args[:1] == ["--"]:
        extra_args = extra_args[1:]

    command = [
        binary,
        "export_hf",
        "--model_name",
        args.model,
        "--output_dir",
        str(output_dir),
        *extra_args,
    ]

    if args.dry_run:
        print("Dry run: export-hf")
        print(f"  model:      {args.model}")
        print(f"  output_dir: {output_dir}")
        print("  command:")
        print(f"    {' '.join(command)}")
        return 0

    try:
        subprocess.run(command, check=True)
    except subprocess.CalledProcessError as exc:
        raise QuantizationToolError(
            f"`{args.litert_torch_bin} export_hf` failed with exit code "
            f"{exc.returncode}."
        ) from exc

    print("Export complete.")
    print(f"  output_dir: {output_dir}")
    print("Suggested next steps:")
    print(f"  ls -lah {output_dir}")
    print(
        "  Import the generated artifact into Airo and compare prompt quality "
        "against the source checkpoint before committing to distribution."
    )
    return 0


def _resolve_recipe(name: str) -> Callable[[], object]:
    try:
        recipe_module = importlib.import_module("ai_edge_quantizer.recipe_manager")
    except ImportError as exc:
        raise QuantizationToolError(
            "Missing dependency `ai-edge-quantizer`. Install it first, for "
            "example: `python3 -m pip install ai-edge-quantizer`."
        ) from exc

    recipe_name = f"{name}_recipe"
    recipe_factory = getattr(recipe_module, recipe_name, None)
    if recipe_factory is None:
        available = sorted(
            attribute.removesuffix("_recipe")
            for attribute in dir(recipe_module)
            if attribute.endswith("_recipe")
        )
        raise QuantizationToolError(
            f"Unknown recipe `{name}`. Available recipes: {', '.join(available)}."
        )
    return recipe_factory


def _existing_file(path_text: str, *, flag: str) -> Path:
    path = Path(path_text).expanduser().resolve()
    if not path.is_file():
        raise QuantizationToolError(f"{flag} file does not exist: {path}")
    return path


def _prepare_output_path(path: Path, *, overwrite: bool, is_dir: bool) -> None:
    if path.exists() and not overwrite:
        if is_dir and path.is_dir() and not any(path.iterdir()):
            return
        raise QuantizationToolError(
            f"Refusing to overwrite existing {'directory' if is_dir else 'file'} "
            f"without --overwrite: {path}"
        )

    if is_dir:
        path.mkdir(parents=True, exist_ok=True)
        if path.exists() and overwrite and not path.is_dir():
            raise QuantizationToolError(f"Output path is not a directory: {path}")
        return

    path.parent.mkdir(parents=True, exist_ok=True)


if __name__ == "__main__":
    raise SystemExit(main())
