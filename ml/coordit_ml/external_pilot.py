"""Public-aRTF-only, label-free visual pilot packets; external proposals never become training truth."""

import hashlib
import shutil
from pathlib import Path
from typing import Annotated, Final, Literal, Self

from pydantic import Field, model_validator

from coordit_ml.finetuning import ParentCheckpoint
from coordit_ml.history import HistoryPin, load_history
from coordit_ml.provenance import REGISTRY_ROOT, approved_entry, sha256
from coordit_ml.publisher_test import PublisherTestDataset
from coordit_ml.schema import BoundaryModel, PipelineError, Record, read_registry

TARGETS: Final[dict[str, tuple[str, ...]]] = {
    "tshirt": ("shoulder_left", "shoulder_right", "armpit_left", "armpit_right"),
    "shorts": ("waist_left", "waist_right", "crotch", "side_hem"),
}


class PilotBaseline(BoundaryModel):
    """Actual existing weights are fixed before the visual assistant produces any coordinates."""

    name: str
    model: ParentCheckpoint


class PilotPreparation(BoundaryModel):
    """Sampling uses image identity only; no favorable GT, pose, or model-score filtering."""

    manifest: Path
    output: Path
    baselines: list[PilotBaseline]
    per_category: Annotated[int, Field(ge=1, le=10)] = 4
    seed: int = 20261028
    exclude_first_per_category: Annotated[int, Field(ge=0)] = 32


class PilotCase(BoundaryModel):
    """Only this label-free record and original pixels may be shown to the visual assistant."""

    case_id: str
    category: Literal["tshirt", "shorts"]
    source_image_id: str
    image_file: str
    image_sha256: str
    width: int
    height: int


class PilotReceipt(BoundaryModel):
    """Packet identity, baseline history and original source rights remain auditable."""

    preparation: PilotPreparation
    manifest_sha256: str
    cases: list[PilotCase]
    ground_truth_in_visual_payload: Literal[False] = False
    aihub_images_in_visual_payload: Literal[False] = False
    license: str
    attribution: str


class ExternalPoint(BoundaryModel):
    """An uncertain proposal is not a human-verified label; explicit abstentions remain failures."""

    landmark_type: str
    x: Annotated[float, Field(ge=0, le=1)] | None
    y: Annotated[float, Field(ge=0, le=1)] | None
    status: Literal["visible_proposal", "uncertain_proposal", "abstain"]

    @model_validator(mode="after")
    def paired_coordinates(self) -> Self:
        """No half-coordinate or apparently precise position is accepted for an abstention."""
        if (self.x is None) != (self.y is None) or ((self.status == "abstain") != (self.x is None)):
            raise PipelineError("External point status and coordinate presence disagree")
        return self


class ExternalCasePrediction(BoundaryModel):
    """Each fixed image receives one proposal before any GT scoring is revealed."""

    case_id: str
    image_sha256: str
    points: list[ExternalPoint]
    note: str


class ExternalPredictions(BoundaryModel):
    """Interactive vision is explicitly distinguished from a separately invoked model API."""

    execution: Literal["interactive_assistant_vision", "provider_api"]
    model_identity: str
    exact_model_revision: str | None
    receipt_sha256: str
    protocol_sha256: str
    coordinate_system: Literal["upright_rgb_normalized_top_left"]
    ground_truth_supplied_before_predictions: Literal[False]
    predictions: list[ExternalCasePrediction]


def require_public_artf(record: Record, license_id: str) -> None:
    """AI Hub and every other source are rejected before creating any externally viewable packet."""
    if (
        record.source_dataset != "artf-publisher-test-evaluation-only-v1"
        or record.original_license != license_id
        or record.split != "test"
        or record.category not in TARGETS
        or not record.source_path.startswith("test/")
    ):
        raise PipelineError("External visual pilot accepts only reviewed public aRTF test photographs")


def prepare_external_pilot(config: PilotPreparation) -> Path:
    """Copy only frozen public source pixels; never place annotations or baseline points in the packet."""
    registry = read_registry(REGISTRY_ROOT / "DATASET_MANIFEST.json")
    source = approved_entry(registry, "artf-1.0.1")
    dataset = PublisherTestDataset(config.manifest, registry)
    history = load_history(
        [
            HistoryPin(artifact=b.model.directory / "artifact.json", sha256=b.model.artifact_sha256)
            for b in config.baselines
        ]
    )
    config.output.mkdir(parents=True, exist_ok=False)
    cases: list[PilotCase] = []
    for category in ("tshirt", "shorts"):
        candidates = [(root, r) for root, r in dataset.samples if r.category == category]
        candidates = candidates[config.exclude_first_per_category :]
        candidates.sort(key=lambda item: hashlib.sha256(f"{config.seed}:{item[1].sha256}".encode()).hexdigest())
        if len(candidates) < config.per_category:
            raise PipelineError("Not enough public evaluation images; never substitute another dataset")
        for root, record in candidates[: config.per_category]:
            require_public_artf(record, source.data_license)
            if history.overlaps(record):
                raise PipelineError("Pilot image overlaps a compared model's recorded training corpus")
            case_id = f"P{len(cases) + 1:02d}"
            filename = case_id + ".png"
            _ = shutil.copyfile(root / record.file_name, config.output / filename)
            cases.append(
                PilotCase(
                    case_id=case_id,
                    category=category,
                    source_image_id=record.image_id,
                    image_file=filename,
                    image_sha256=record.sha256,
                    width=record.width,
                    height=record.height,
                )
            )
    receipt = PilotReceipt(
        preparation=config,
        manifest_sha256=sha256(config.manifest),
        cases=cases,
        license=source.data_license,
        attribution=source.attribution,
    )
    path = config.output / "packet.json"
    _ = path.write_text(receipt.model_dump_json(indent=2) + "\n")
    return path
