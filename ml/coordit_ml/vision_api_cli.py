# /// script
# requires-python = ">=3.12"
# ///
# How to run: cd ml && uv run --env-file .env python -m coordit_ml.vision_api_cli run benchmark-artf-openrouter.json
"""Explicit paid public-photo benchmark and offline replay; no private-image inference endpoint."""

import argparse
from pathlib import Path
from typing import Literal, assert_never

from coordit_ml.vision_api_billing import audit_billing
from coordit_ml.vision_api_report import score_api_benchmark
from coordit_ml.vision_api_runner import run_benchmark
from coordit_ml.vision_api_types import BenchmarkConfig


class Arguments(argparse.Namespace):
    """Typed project-style CLI boundary."""

    command: Literal["run", "score", "billing"] = "run"
    config: Path = Path()
    output: Path = Path("reports/ARTF_OPENROUTER_MODEL_COMPARISON.json")


def main() -> None:
    """A completed run refuses overwrites; offline score replay never makes a paid API call."""
    parser = argparse.ArgumentParser(description=__doc__)
    _ = parser.add_argument("command", choices=("run", "score", "billing"))
    _ = parser.add_argument("config", type=Path)
    _ = parser.add_argument("--output", type=Path, default=Arguments.output)
    args = parser.parse_args(namespace=Arguments())
    config = BenchmarkConfig.model_validate_json(args.config.read_bytes())
    match args.command:
        case "run":
            output = run_benchmark(config)
        case "score":
            output = score_api_benchmark(config, config.output / "attempts.json", args.output)
        case "billing":
            output = audit_billing(config, args.output)
        case unreachable:
            assert_never(unreachable)
    print(output)  # noqa: T201 -- Artifact path only; credentials and image payloads are never printed.


if __name__ == "__main__":
    main()
