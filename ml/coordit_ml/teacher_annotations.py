"""Public training-photo packets and pinned, explicitly unverified visual-teacher annotations."""

import hashlib
import shutil
from pathlib import Path
from typing import Annotated, Final

from pydantic import Field

from coordit_ml.external_pilot import ExternalPredictions, PilotCase
from coordit_ml.provenance import REGISTRY_ROOT, approved_entry, audit_records, check_separation, sha256
from coordit_ml.publisher_test import PublisherTestDataset
from coordit_ml.schema import BoundaryModel, PipelineError, Record, read_registry

TEACHER_TARGETS: Final[dict[str, tuple[str, ...]]] = {
    "tshirt": (
        "shoulder_left", "shoulder_right", "armpit_left", "armpit_right",
        "length_start", "hem_center", "sleeve_start", "sleeve_end",
    ),
    "shorts": ("waist_left", "waist_right", "crotch", "side_hem", "waist_center"),
}


class TeacherPreparation(BoundaryModel):
    """Selection is fixed using source identity, before labels or teacher responses are inspected."""

    manifest: Path
    evaluation_manifest: Path
    protocol: Path
    output: Path
    per_category: Annotated[int, Field(ge=1, le=32)] = 12
    seed: int = 20261029


class TeacherPacket(BoundaryModel):
    """Training-only public pixels, with an immutable exclusion corpus and annotation protocol."""

    preparation: TeacherPreparation
    manifest_sha256: str
    evaluation_manifest_sha256: str
    protocol_sha256: str
    cases: list[PilotCase]
    attribution: str


class TeacherPin(BoundaryModel):
    """Unverified annotations are an optional weak objective, never imported as supervised truth."""

    packet: Path
    packet_sha256: str
    predictions: Path
    predictions_sha256: str
    loss_weight: Annotated[float, Field(gt=0, le=1)] = 0.25


def require_training_artf(record: Record) -> None:
    """Reject AI Hub, evaluation identities, alternate licenses and renamed publisher test files."""
    if (
        record.source_dataset != "artf-1.0.1"
        or record.original_license != "CC-BY-4.0"
        or record.split != "train"
        or not record.source_path.startswith("train/")
        or record.category not in TEACHER_TARGETS
    ):
        raise PipelineError("Visual teacher accepts only approved public aRTF training photos")


def prepare_teacher_packet(config: TeacherPreparation) -> Path:
    """Create a label-free packet from audited training bytes; never sample from the evaluation corpus."""
    registry = read_registry(REGISTRY_ROOT / "DATASET_MANIFEST.json")
    source = approved_entry(registry, "artf-1.0.1")
    records = audit_records(config.manifest, registry)
    evaluation = PublisherTestDataset(config.evaluation_manifest, registry)
    check_separation(records + [record for _, record in evaluation.samples])
    selected: list[Record] = []
    for category in ("tshirt", "shorts"):
        candidates = sorted(
            (r for r in records if r.category == category),
            key=lambda r: hashlib.sha256(f"{config.seed}:{r.sha256}".encode()).hexdigest(),
        )
        if len(candidates) < config.per_category:
            raise PipelineError("Insufficient public training photos; cannot substitute private or evaluation images")
        selected.extend(candidates[:config.per_category])
    for record in selected:
        require_training_artf(record)
    config.output.mkdir(parents=True, exist_ok=False)
    cases: list[PilotCase] = []
    for record in selected:
        case_id = f"T{len(cases) + 1:02d}"
        filename = f"{case_id}.png"
        _ = shutil.copyfile(config.manifest.parent / record.file_name, config.output / filename)
        cases.append(PilotCase.model_validate({
            "case_id": case_id, "category": record.category, "source_image_id": record.image_id,
            "image_file": filename, "image_sha256": record.sha256, "width": record.width, "height": record.height,
        }))
    packet = TeacherPacket(
        preparation=config, manifest_sha256=sha256(config.manifest),
        evaluation_manifest_sha256=sha256(config.evaluation_manifest),
        protocol_sha256=sha256(config.protocol), cases=cases, attribution=source.attribution,
    )
    output = config.output / "packet.json"
    _ = output.write_text(packet.model_dump_json(indent=2) + "\n")
    return output


def read_teacher(pin: TeacherPin, training_records: list[Record]) -> tuple[TeacherPacket, ExternalPredictions]:
    """Verify every original source and response pin before constructing any weak learning target."""
    if sha256(pin.packet) != pin.packet_sha256 or sha256(pin.predictions) != pin.predictions_sha256:
        raise PipelineError("Teacher packet or frozen predictions changed")
    packet = TeacherPacket.model_validate_json(pin.packet.read_bytes())
    config = packet.preparation
    if (
        sha256(config.manifest) != packet.manifest_sha256
        or sha256(config.evaluation_manifest) != packet.evaluation_manifest_sha256
        or sha256(config.protocol) != packet.protocol_sha256
    ):
        raise PipelineError("Teacher source, protocol or exclusion corpus changed")
    registry = read_registry(REGISTRY_ROOT / "DATASET_MANIFEST.json")
    approved = {r.image_id: r for r in audit_records(config.manifest, registry)}
    evaluation = PublisherTestDataset(config.evaluation_manifest, registry)
    check_separation(training_records + [r for _, r in evaluation.samples])
    indexed = {r.image_id: r for r in training_records}
    case_ids = [case.case_id for case in packet.cases]
    image_ids = [case.source_image_id for case in packet.cases]
    if not case_ids or len(set(case_ids)) != len(case_ids) or len(set(image_ids)) != len(image_ids):
        raise PipelineError("Teacher cases must be nonempty unique training images")
    response = ExternalPredictions.model_validate_json(pin.predictions.read_bytes())
    if response.receipt_sha256 != pin.packet_sha256 or response.protocol_sha256 != packet.protocol_sha256:
        raise PipelineError("Teacher response belongs to another packet or protocol")
    predictions = {p.case_id: p for p in response.predictions}
    if len(predictions) != len(response.predictions) or set(predictions) != set(case_ids):
        raise PipelineError("Teacher response is incomplete or repeats an image")
    for case in packet.cases:
        if case.source_image_id not in indexed or case.source_image_id not in approved:
            raise PipelineError("Teacher photo is absent from the approved training corpus")
        record = indexed[case.source_image_id]
        require_training_artf(record)
        if record != approved[record.image_id] or (record.sha256, record.width, record.height) != (
            case.image_sha256, case.width, case.height,
        ):
            raise PipelineError("Teacher coordinates reference another source image or training labels")
        prediction = predictions[case.case_id]
        names = [p.landmark_type for p in prediction.points]
        if (
            prediction.image_sha256 != record.sha256
            or set(names) != set(TEACHER_TARGETS[record.category])
            or len(set(names)) != len(names)
        ):
            raise PipelineError("Teacher source hash or semantic targets disagree")
    return packet, response
