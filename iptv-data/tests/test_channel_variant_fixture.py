"""Parity checks for the repository-wide channel variant fixture."""

import json
from pathlib import Path

from src.processors.deduplicator import canonical_channel_name


def test_python_classifier_matches_shared_golden_fixture() -> None:
    fixture_path = Path(__file__).parents[2] / "fixtures/channel_variant_cases.json"
    fixture = json.loads(fixture_path.read_text(encoding="utf-8"))

    for case in fixture["canonicalCases"]:
        assert canonical_channel_name(case["input"]) == case["expected"]

    for case in fixture["scopeCases"]:
        left = case["left"]
        right = case["right"]
        same = (
            canonical_channel_name(left["name"]) == canonical_channel_name(right["name"])
            and left["country"] == right["country"]
            and left["language"] == right["language"]
        )
        assert same is case["sameChannel"]
