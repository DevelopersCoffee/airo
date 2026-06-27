# Model Quantization

This guide documents the small developer workflow added for issue `#359`.

The repository wrapper does two things:

1. Quantize an existing LiteRT/TFLite artifact with Google AI Edge Quantizer.
2. Forward a supported Hugging Face or local checkpoint export to `litert-torch`.

The repo does not vendor model conversion dependencies. Install them into an
isolated Python environment first.

## Prerequisites

- Python 3.10+
- `pip`
- Enough free disk for the source checkpoint and exported artifact

Recommended virtual environment:

```bash
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install --upgrade pip
```

Install the upstream tools:

```bash
python3 -m pip install ai-edge-quantizer litert-torch
```

If the source model is private on Hugging Face, authenticate through the
standard Hugging Face CLI or environment variables. Do not pass tokens on the
command line.

## Quick Start

Show help:

```bash
python3 scripts/quantize_model.py --help
make quantize-model HELP=1
```

## Quantize An Existing LiteRT/TFLite Model

Use the built-in `dynamic_wi8_afp32` recipe from Google AI Edge Quantizer:

```bash
python3 scripts/quantize_model.py quantize-tflite \
  --input-tflite /tmp/model_fp32.tflite \
  --output-tflite /tmp/model_int8.tflite
```

Dry-run the same command first:

```bash
python3 scripts/quantize_model.py quantize-tflite \
  --input-tflite /tmp/model_fp32.tflite \
  --output-tflite /tmp/model_int8.tflite \
  --dry-run
```

## Export A Supported Hugging Face Model

The wrapper forwards to the upstream `litert-torch export_hf` CLI:

```bash
python3 scripts/quantize_model.py export-hf \
  --model google/gemma-3-270m-it \
  --output-dir /tmp/gemma3-export
```

Pass through exporter-specific flags after `--`:

```bash
python3 scripts/quantize_model.py export-hf \
  --model google/gemma-3-270m-it \
  --output-dir /tmp/gemma3-export \
  -- \
  --prefill_seq_lens 512,1024 \
  --kv_cache_max_len 1024
```

Use the Makefile handoff:

```bash
make quantize-model QUANTIZE_ARGS="export-hf --model google/gemma-3-270m-it --output-dir /tmp/gemma3-export"
```

## How To Check Quantized Model Perplexity

Perplexity should be compared against the original source checkpoint before the
artifact is adopted into Airo's model catalog.

Recommended baseline workflow:

1. Evaluate the source checkpoint with a reproducible harness such as
   [`lm-evaluation-harness`](https://github.com/EleutherAI/lm-evaluation-harness).
2. Record the baseline perplexity or downstream task score.
3. Export or quantize the model.
4. Re-run the same evaluation on the quantized/runtime-compatible artifact if
   your runtime exposes perplexity directly.
5. If the target runtime does not expose perplexity yet, use the same held-out
   prompts plus Airo's benchmark/import flow as a temporary gate and record the
   limitation in the PR.

Example source-checkpoint baseline:

```bash
python3 -m pip install lm-eval
python3 -m lm_eval \
  --model hf \
  --model_args pretrained=google/gemma-3-270m-it \
  --tasks wikitext \
  --batch_size auto
```

Until Airo exposes direct perplexity measurement for imported LiteRT artifacts,
do not treat quantization as complete without:

- a saved baseline metric from the source checkpoint
- a small held-out prompt regression check
- an import smoke test in Airo or the target LiteRT runtime

## Troubleshooting

- `Missing dependency ai-edge-quantizer`: install the Python package in the
  active virtual environment.
- `Could not find litert-torch`: install `litert-torch` or point
  `--litert-torch-bin` at the correct binary.
- `Unknown recipe`: run the script with the documented built-in recipe or
  inspect the installed `ai_edge_quantizer.recipe_manager` module.
- Export failure from `litert-torch`: retry with the exact upstream flags for
  the chosen architecture and confirm the model is supported by LiteRT Torch.
