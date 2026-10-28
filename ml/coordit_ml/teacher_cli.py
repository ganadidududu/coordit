# /// script
# requires-python = ">=3.12"
# ///
# How to run: cd ml && uv run python -m coordit_ml.teacher_cli --help
"""Public-only teacher preparation and frozen evaluation; no private-image upload command exists."""

import argparse
from pathlib import Path
from typing import Literal, assert_never

from coordit_ml.teacher_annotations import TeacherPreparation, prepare_teacher_packet
from coordit_ml.teacher_evaluation import TeacherEvaluation, evaluate_teacher_models


class Arguments(argparse.Namespace):
    """Typed parser boundary, with choices validated by argparse before dispatch."""

    command: Literal["prepare", "evaluate"] = "prepare"
    config: Path = Path()


def main() -> None:
    """Reuse project CLI conventions without expanding the unrelated application command surface."""
    parser = argparse.ArgumentParser(description=__doc__)
    _ = parser.add_argument("command", choices=("prepare", "evaluate"))
    _ = parser.add_argument("config", type=Path)
    args = parser.parse_args(namespace=Arguments())
    match args.command:
        case "prepare":
            output = prepare_teacher_packet(TeacherPreparation.model_validate_json(args.config.read_bytes()))
        case "evaluate":
            output = evaluate_teacher_models(TeacherEvaluation.model_validate_json(args.config.read_bytes()))
        case unreachable:
            assert_never(unreachable)
    print(output)  # noqa: T201 -- CLI output is the generated artifact path.


if __name__ == "__main__":
    main()
