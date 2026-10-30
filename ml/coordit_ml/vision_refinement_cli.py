# /// script
# requires-python = ">=3.12"
# ///
# How to run: cd ml && uv run --env-file .env python -m coordit_ml.vision_refinement_cli prepare
"""Freeze a public-photo holdout, run a single self-review candidate, and replay paired metrics offline."""

import argparse
import json
from pathlib import Path
from typing import Literal, assert_never

from coordit_ml.provenance import sha256
from coordit_ml.vision_api_types import BenchmarkConfig
from coordit_ml.vision_refinement_packet import current_catalog, prepare_holdout
from coordit_ml.vision_refinement_report import compare_refinement
from coordit_ml.vision_refinement_runner import RefinementConfig, run_refinement


class Arguments(argparse.Namespace):
    """Typed CLI arguments; all paths are local and never inserted into model requests."""

    partial: bool = False
    command: Literal["prepare", "configure", "run", "score"] = "prepare"
    output_frame: Literal["crop", "original"] = "crop"
    config: Path = Path("benchmark-artf-openrouter.json")
    output: Path = Path("artifacts/artf-vision-refinement-v1")


def main() -> None:
    """Use separate original-prediction and self-review directories; never overwrite a paid experiment."""
    parser = argparse.ArgumentParser(description=__doc__)
    _ = parser.add_argument("command", choices=("prepare", "configure", "run", "score"))
    _ = parser.add_argument("--config", type=Path, default=Arguments.config)
    _ = parser.add_argument("--output", type=Path, default=Arguments.output)
    _ = parser.add_argument("--output-frame", choices=("crop", "original"), default="crop")
    _ = parser.add_argument("--partial", action="store_true")
    args = parser.parse_args(namespace=Arguments())
    match args.command:
        case "prepare":
            baseline = BenchmarkConfig.model_validate_json(args.config.read_bytes())
            args.output.mkdir(parents=True, exist_ok=False)
            catalog = current_catalog(args.output)
            packet = prepare_holdout(baseline, args.output / "holdout")
            changes = {
                "models": ["openai/gpt-6-astra", "google/gemini-3.8-flash"],
                "catalog": catalog,
                "catalog_sha256": sha256(catalog),
                "spending_limit_usd": 5,
            }
            development = baseline.model_copy(update=changes)
            heldout = development.model_copy(
                update={
                    "receipt": packet,
                    "receipt_sha256": sha256(packet),
                    "images_per_model": 16,
                    "output": args.output / "holdout-baseline",
                }
            )
            for name, config in (("development-baseline", development), ("holdout-baseline", heldout)):
                _ = (args.output / (name + ".json")).write_text(config.model_dump_json(indent=2) + "\n")
            _ = (args.output / "preregistered-plan.json").write_text(
                json.dumps(
                    {
                        "candidate": "one_self_review_own_proposal_crop_3x_original_context",
                        "development_images": 8,
                        "holdout_images": 16,
                        "models": changes["models"],
                        "new_paid_call_limit": 80,
                        "max_actual_experiment_usd": 5,
                        "primary": "visible-only PCK and projected pair error/coverage on untouched holdout",
                        "no_automatic_deployment": True,
                        "no_tuning_after_holdout_scoring": True,
                    },
                    indent=2,
                )
                + "\n"
            )
            target = args.output
        case "configure":
            baseline = BenchmarkConfig.model_validate_json(args.config.read_bytes())
            parent = baseline.output / "attempts.json"
            config = RefinementConfig(
                baseline=baseline,
                parent_attempts=parent,
                parent_attempts_sha256=sha256(parent),
                output=args.output,
                output_frame=args.output_frame,
            )
            target = args.output.with_suffix(".json")
            with target.open("x") as stream:
                _ = stream.write(config.model_dump_json(indent=2) + "\n")
        case "run":
            target = run_refinement(RefinementConfig.model_validate_json(args.config.read_bytes()))
        case "score":
            target = compare_refinement(
                RefinementConfig.model_validate_json(args.config.read_bytes()), args.output, allow_partial=args.partial
            )
        case unreachable:
            assert_never(unreachable)
    print(target)  # noqa: T201 -- Artifact path only, no credential or photo payload logging.


if __name__ == "__main__":
    main()
