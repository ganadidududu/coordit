# /// script
# requires-python = ">=3.12"
# ///
# How to run: cd ml && uv run python -m coordit_ml --help
"""Explicit development CLIs; no command enables app features or production deployment."""

import argparse
import json
from pathlib import Path
from typing import Literal, assert_never

from coordit_ml.acquisition import convert_artf, download_artf
from coordit_ml.aihub import audit_aihub
from coordit_ml.aihub_blind_evaluation import BlindEvaluation, evaluate_aihub_blind
from coordit_ml.aihub_conversion import AIHubConversion, convert_aihub
from coordit_ml.aihub_review_queue import QueueConfig, prepare_aihub_review_queue
from coordit_ml.approval import approve_dataset
from coordit_ml.artf_landmarks import prepare_artf_landmarks
from coordit_ml.category_review import prepare_review
from coordit_ml.centimeter_evaluation import evaluate_centimeters
from coordit_ml.evaluation import evaluate
from coordit_ml.field_evaluation import field_report
from coordit_ml.garmentcode_conversion import GarmentSelection, render_garmentcode
from coordit_ml.garmentcode_download import (
    download_garmentcode_metadata,
    download_sample_prefix,
    prepare_garmentcode_sample,
)
from coordit_ml.inventory import audit_inventory
from coordit_ml.provenance import REGISTRY_ROOT, approved_entry, audit_records
from coordit_ml.publisher_test import TestPreparation, prepare_publisher_test
from coordit_ml.schema import read_registry
from coordit_ml.seam_comparison import SeamComparison, compare_seams
from coordit_ml.seam_reviews import ReviewImport, import_seam_reviews
from coordit_ml.secondhand_conversion import ConversionConfig, convert_secondhand
from coordit_ml.secondhand_download import download_secondhand
from coordit_ml.synthetic import generate
from coordit_ml.synthetic_v2 import generate_v2
from coordit_ml.training import TrainingConfig, load_model, train
from coordit_ml.via_reviews import ViaImport, import_via_reviews


class Arguments(argparse.Namespace):
    """Mutable argparse builder; each subparser owns the fields it reads."""

    command: Literal[
        "registry",
        "approve-dataset",
        "audit-inventory",
        "audit-aihub",
        "prepare-aihub-seam-review",
        "import-via-seam-reviews",
        "evaluate-aihub-blind",
        "convert-aihub",
        "download-artf",
        "download-secondhand",
        "convert-secondhand",
        "review-secondhand",
        "convert-artf",
        "prepare-artf-landmarks",
        "download-garmentcode-sample",
        "render-garmentcode",
        "compare-seams",
        "prepare-publisher-test",
        "import-seam-reviews",
        "synthetic",
        "validate",
        "train",
        "evaluate",
        "evaluate-cm",
        "field-report",
        "infer",
        "export-onnx",
    ] = "registry"
    output: Path = Path()
    archive: Path = Path()
    source: Path = Path()
    per_category: int = 30
    seed: int = 17
    version: str = "v1"
    manifest: Path = Path()
    config: Path = Path()
    model: Path = Path()
    split: str = "test"
    csv: Path = Path()
    image: Path = Path()


def main() -> None:
    """Parse bounded CLI actions; exceptions fail the job rather than producing empty success."""
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    _ = commands.add_parser("registry")
    inventory = commands.add_parser("audit-inventory")
    _ = inventory.add_argument("manifest", type=Path)
    aihub = commands.add_parser("audit-aihub", help="Inspect privately downloaded 71501 pairs; no training approval")
    _ = aihub.add_argument("source", type=Path)
    _ = aihub.add_argument("output", type=Path)
    queue = commands.add_parser("prepare-aihub-seam-review")
    _ = queue.add_argument("config", type=Path)
    via_reviews = commands.add_parser("import-via-seam-reviews")
    _ = via_reviews.add_argument("config", type=Path)
    blind_evaluation = commands.add_parser("evaluate-aihub-blind")
    _ = blind_evaluation.add_argument("config", type=Path)
    aihub_conversion = commands.add_parser("convert-aihub", help="Prepare approved local polygon supervision")
    _ = aihub_conversion.add_argument("config", type=Path)
    review = commands.add_parser("approve-dataset")
    _ = review.add_argument("config", type=Path)
    fetch = commands.add_parser("download-artf")
    _ = fetch.add_argument("output", type=Path)
    secondhand = commands.add_parser("download-secondhand")
    _ = secondhand.add_argument("output", type=Path)
    secondhand_conversion = commands.add_parser("convert-secondhand")
    _ = secondhand_conversion.add_argument("config", type=Path)
    secondhand_review = commands.add_parser("review-secondhand")
    _ = secondhand_review.add_argument("source", type=Path)
    _ = secondhand_review.add_argument("output", type=Path)
    convert = commands.add_parser("convert-artf")
    _ = convert.add_argument("archive", type=Path)
    _ = convert.add_argument("output", type=Path)
    artf_landmarks = commands.add_parser("prepare-artf-landmarks")
    _ = artf_landmarks.add_argument("manifest", type=Path)
    _ = artf_landmarks.add_argument("output", type=Path)
    garmentcode = commands.add_parser("download-garmentcode-sample")
    _ = garmentcode.add_argument("output", type=Path)
    render = commands.add_parser("render-garmentcode")
    _ = render.add_argument("config", type=Path)
    compare = commands.add_parser("compare-seams")
    _ = compare.add_argument("config", type=Path)
    publisher_test = commands.add_parser("prepare-publisher-test")
    _ = publisher_test.add_argument("config", type=Path)
    seam_reviews = commands.add_parser("import-seam-reviews")
    _ = seam_reviews.add_argument("config", type=Path)
    synth = commands.add_parser("synthetic")
    _ = synth.add_argument("output", type=Path)
    _ = synth.add_argument("--version", choices=("v1", "v2"), default="v1")
    _ = synth.add_argument("--per-category", type=int, default=30)
    _ = synth.add_argument("--seed", type=int, default=17)
    validate = commands.add_parser("validate")
    _ = validate.add_argument("manifest", type=Path)
    training = commands.add_parser("train")
    _ = training.add_argument(
        "config", type=Path, help="TrainingConfig JSON; all versioned hyperparameters are recorded"
    )
    scoring = commands.add_parser("evaluate")
    _ = scoring.add_argument("model", type=Path)
    _ = scoring.add_argument("manifest", type=Path)
    _ = scoring.add_argument("--split", choices=("train", "validation", "test"), default="test")
    cm = commands.add_parser("evaluate-cm")
    _ = cm.add_argument("csv", type=Path)
    field = commands.add_parser("field-report")
    _ = field.add_argument("source", type=Path)
    _ = field.add_argument("output", type=Path)
    infer = commands.add_parser("infer")
    _ = infer.add_argument("model", type=Path)
    _ = infer.add_argument("image", type=Path)
    export = commands.add_parser("export-onnx")
    _ = export.add_argument("model", type=Path)
    _ = export.add_argument("output", type=Path)
    args = parser.parse_args(namespace=Arguments())
    registry = read_registry(REGISTRY_ROOT / "DATASET_MANIFEST.json")
    match args.command:
        case "registry":
            for entry in registry.datasets:
                if entry.status.value == "approved":
                    _ = approved_entry(registry, entry.id)
            print(json.dumps({entry.id: entry.status.value for entry in registry.datasets}, indent=2))
        case "approve-dataset":
            approve_dataset(REGISTRY_ROOT / "DATASET_MANIFEST.json", args.config)
        case "audit-inventory":
            print(audit_inventory(args.manifest, registry))
        case "audit-aihub":
            print(audit_aihub(args.source, args.output).model_dump_json(indent=2))
        case "prepare-aihub-seam-review":
            print(prepare_aihub_review_queue(QueueConfig.model_validate_json(args.config.read_bytes()), registry))
        case "import-via-seam-reviews":
            print(import_via_reviews(ViaImport.model_validate_json(args.config.read_bytes())))
        case "evaluate-aihub-blind":
            print(evaluate_aihub_blind(BlindEvaluation.model_validate_json(args.config.read_bytes())))
        case "convert-aihub":
            print(convert_aihub(AIHubConversion.model_validate_json(args.config.read_bytes()), registry))
        case "download-artf":
            print(download_artf(args.output, registry))
        case "download-secondhand":
            print(download_secondhand(args.output, registry))
        case "convert-secondhand":
            print(convert_secondhand(ConversionConfig.model_validate_json(args.config.read_bytes()), registry))
        case "review-secondhand":
            print(prepare_review(args.source, args.output))
        case "convert-artf":
            print(convert_artf(args.archive, args.output, registry))
        case "prepare-artf-landmarks":
            print(prepare_artf_landmarks(args.manifest, args.output, registry))
        case "download-garmentcode-sample":
            _ = approved_entry(registry, "garmentcodedata-v2")
            download_garmentcode_metadata(args.output / "source")
            prefix = download_sample_prefix(args.output / "source/batch0-prefix-32MiB.tar.gz")
            print(prepare_garmentcode_sample(prefix, args.output / "pilot-15", registry))
        case "render-garmentcode":
            print(render_garmentcode(GarmentSelection.model_validate_json(args.config.read_bytes()), registry))
        case "compare-seams":
            print(compare_seams(SeamComparison.model_validate_json(args.config.read_bytes())))
        case "prepare-publisher-test":
            print(prepare_publisher_test(TestPreparation.model_validate_json(args.config.read_bytes()), registry))
        case "import-seam-reviews":
            print(import_seam_reviews(ReviewImport.model_validate_json(args.config.read_bytes()), registry))
        case "synthetic":
            generator = generate_v2 if args.version == "v2" else generate
            print(generator(args.output, args.per_category, args.seed))
        case "validate":
            records = audit_records(args.manifest, registry)
            print(
                json.dumps(
                    {
                        "accepted_images": len(records),
                        "categories": {c: sum(r.category == c for r in records) for c in registry.categories},
                    },
                    indent=2,
                )
            )
        case "train":
            print(train(TrainingConfig.model_validate_json(args.config.read_bytes())))
        case "evaluate":
            print(evaluate(args.model, args.manifest, args.split))
        case "evaluate-cm":
            print(json.dumps(evaluate_centimeters(args.csv), indent=2))
        case "field-report":
            print(field_report(args.source, args.output))
        case "infer":
            from coordit_ml.inference import infer_image

            print(infer_image(args.model, args.image.read_bytes()).model_dump_json(indent=2))
        case "export-onnx":
            import torch

            model = load_model(args.model)
            _ = torch.onnx.export(
                model,
                (torch.zeros(1, 3, model.input_size, model.input_size),),
                args.output,
                input_names=["rgb"],
                output_names=["category", "mask", "landmarks", "visibility"]
                + (["heatmaps"] if model.input_size == 128 else []),
                opset_version=18,
            )
            print(args.output)
        case unreachable:
            assert_never(unreachable)


if __name__ == "__main__":
    main()
