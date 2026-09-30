#!/usr/bin/env python3
"""Offline generator. Never commit distribution_list.txt or insert_coupons.sql."""

from __future__ import annotations

import argparse
import datetime
import hashlib
import secrets
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate hashed community-pass coupons.")
    parser.add_argument("--count", type=int, default=100)
    parser.add_argument(
        "--duration",
        choices=("monthly", "yearly", "lifetime"),
        default="lifetime",
    )
    parser.add_argument("--expiry-days", type=int, default=365)
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=Path(__file__).resolve().parent.parent / "out",
    )
    args = parser.parse_args()

    args.out_dir.mkdir(parents=True, exist_ok=True)
    expires_at = (
        datetime.datetime.now(datetime.timezone.utc)
        + datetime.timedelta(days=args.expiry_days)
    ).isoformat()

    plaintext: list[str] = []
    inserts: list[str] = []
    for _ in range(args.count):
        # token_hex(10) → 20 hex chars, then uppercased with the AIKA- prefix.
        plaintext_code = f"AIKA-{secrets.token_hex(10).upper()}"
        code_hash = hashlib.sha256(plaintext_code.encode("utf-8")).hexdigest()
        plaintext.append(plaintext_code)
        inserts.append(
            "INSERT INTO public.coupons (code_hash, duration, expires_at) "
            f"VALUES ('{code_hash}', '{args.duration}', '{expires_at}');"
        )

    (args.out_dir / "distribution_list.txt").write_text(
        "\n".join(plaintext) + "\n", encoding="utf-8"
    )
    (args.out_dir / "insert_coupons.sql").write_text(
        "\n".join(inserts) + "\n", encoding="utf-8"
    )
    print(f"Wrote {args.count} codes under {args.out_dir}")


if __name__ == "__main__":
    main()
