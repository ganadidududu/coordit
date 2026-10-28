"""Reproducible CPU smoke/GPU training with registry, data and checkpoint version pins."""

import hashlib
import random
from pathlib import Path
from typing import Literal

import torch

from coordit_ml.artifacts import Artifact, ManifestPin, read_checkpoint
from coordit_ml.finetuning import ParentCheckpoint, initialize
from coordit_ml.model_factory import Architecture, PerceptionModel, create_model, model_loss
from coordit_ml.network import ApprovedDataset, batch
from coordit_ml.provenance import REGISTRY_ROOT, approved_entry, read_records, sha256
from coordit_ml.sampling import SourceSampling, balance_categories, sample_sources
from coordit_ml.schema import BoundaryModel, PipelineError, read_registry


class TrainingConfig(BoundaryModel):
    """Pinned sampling, architecture and optimizer parameters."""

    manifests: list[Path]
    output: Path
    epochs: int = 5
    batch_size: int = 16
    learning_rate: float = 0.001
    seed: int = 42
    device: Literal["cpu", "cuda", "mps"] = "cpu"
    architecture: Architecture = "coordit-tiny-multitask-v1"
    category_heads: bool = False
    max_steps: int | None = None
    resume: bool = False
    synthetic_fraction: float = 0.5
    balance_real_categories: bool = False
    source_sampling: SourceSampling | None = None
    initialize_from: ParentCheckpoint | None = None


def fingerprint(config: TrainingConfig) -> str:
    """Changing data, registry or architecture invalidates resume rather than silently mixing versions."""
    payload = [sha256(p) for p in config.manifests] + [
        sha256(REGISTRY_ROOT / "DATASET_MANIFEST.json"),
        sha256(REGISTRY_ROOT / "EVALUATION_DENYLIST.json"),
        config.architecture,
        str(config.category_heads),
        sha256(Path(__file__).with_name("heatmap_network.py")),
        sha256(Path(__file__).with_name("model_factory.py")),
        str(config.seed),
        str(config.batch_size),
        str(config.learning_rate),
        str(config.synthetic_fraction),
        str(config.balance_real_categories),
        config.source_sampling.model_dump_json() if config.source_sampling else "none",
        config.initialize_from.model_dump_json() if config.initialize_from else "none",
        sha256(Path(__file__).with_name("finetuning.py")),
        sha256(Path(__file__).with_name("schema.py")),
        sha256(Path(__file__).with_name("sampling.py")),
        sha256(Path(__file__).with_name("provenance.py")),
        sha256(Path(__file__).with_name("similarity.py")),
        sha256(Path(__file__).with_name("network.py")),
        sha256(Path(__file__)),
        sha256(REGISTRY_ROOT.parent / "uv.lock"),
    ]
    return hashlib.sha256("\n".join(payload).encode()).hexdigest()


def train(config: TrainingConfig) -> Path:
    """Train actual randomly initialized weights; CPU runs remain smoke artifacts."""
    if config.epochs < 1 or config.batch_size < 1 or not 0 <= config.synthetic_fraction <= 1:
        raise PipelineError("Invalid training hyperparameters")
    if config.source_sampling and config.balance_real_categories:
        raise PipelineError("Choose source quotas or category balancing explicitly")
    if config.device == "cuda" and not torch.cuda.is_available():
        raise PipelineError("CUDA is unavailable; do not claim GPU training")
    if config.device == "mps" and not torch.backends.mps.is_available():
        raise PipelineError("Metal GPU is unavailable")
    torch.set_num_threads(2)
    _ = torch.manual_seed(config.seed)
    registry = read_registry(REGISTRY_ROOT / "DATASET_MANIFEST.json")
    dataset = ApprovedDataset(config.manifests, registry, "train")
    if not len(dataset):
        raise PipelineError("No approved training images")
    run_fingerprint = fingerprint(config)
    model = create_model(config.architecture, config.category_heads).to(config.device)
    dataset.image_size = model.input_size
    optimizer = torch.optim.AdamW(model.parameters(), lr=config.learning_rate)
    config.output.mkdir(parents=True, exist_ok=True)
    checkpoint, metadata_path = config.output / "checkpoint.pt", config.output / "artifact.json"
    first_epoch = 0
    seen_ids: set[str] = set()
    if config.resume:
        metadata = Artifact.model_validate_json(metadata_path.read_bytes())
        if metadata.fingerprint != run_fingerprint or metadata.checkpoint_sha256 != sha256(checkpoint):
            raise PipelineError("Checkpoint/data/registry fingerprint mismatch")
        state = read_checkpoint(checkpoint)
        _ = model.load_state_dict(state.model)
        optimizer.load_state_dict(state.optimizer.model_dump())
        torch.set_rng_state(state.rng.cpu())
        first_epoch = state.epoch + 1
        seen_ids.update(metadata.seen_image_ids)
    elif checkpoint.exists():
        raise PipelineError("Run already exists; use resume or a new output directory")
    elif config.initialize_from:
        if config.output.resolve() == config.initialize_from.directory.resolve():
            raise PipelineError("Fine tuning must preserve the parent run directory")
        initialize(model, config.initialize_from)
    if first_epoch >= config.epochs:
        raise PipelineError("No new epochs requested")
    synthetic = [i for i, (_, r) in enumerate(dataset.samples) if r.acquisition_metadata.synthetic]
    real = [i for i, (_, r) in enumerate(dataset.samples) if not r.acquisition_metadata.synthetic]
    for epoch in range(first_epoch, config.epochs):
        _ = model.train()
        rng = random.Random(config.seed + epoch)
        synthetic = sorted(synthetic)
        real = sorted(real)
        rng.shuffle(synthetic)
        rng.shuffle(real)
        real_epoch = (
            balance_categories(real, [record.category for _, record in dataset.samples], rng)
            if config.balance_real_categories
            else real
        )
        if synthetic and real:
            total = min(
                len(synthetic) / max(config.synthetic_fraction, 0.000001),
                len(real_epoch) / max(1 - config.synthetic_fraction, 0.000001),
            )
            indices = (
                synthetic[: int(total * config.synthetic_fraction)]
                + real_epoch[: int(total * (1 - config.synthetic_fraction))]
            )
        else:
            indices = synthetic + real_epoch
        if config.source_sampling:
            indices = sample_sources(
                [record.source_dataset for _, record in dataset.samples], config.source_sampling, rng
            )
        rng.shuffle(indices)
        losses: list[float] = []
        used: list[int] = []
        for step, offset in enumerate(range(0, len(indices), config.batch_size)):
            if config.max_steps is not None and step >= config.max_steps:
                break
            selected = indices[offset : offset + config.batch_size]
            target = batch(dataset, selected, config.device)
            optimizer.zero_grad()
            objective = model_loss(config.architecture, model.forward(target.pixels, target.category), target)
            if not objective.isfinite():
                raise PipelineError("Nonfinite training objective")
            _ = objective.backward()
            _ = optimizer.step()
            losses.append(float(objective.detach()))
            used.extend(selected)
        if not losses:
            raise PipelineError("No training steps executed")
        temporary = checkpoint.with_suffix(".partial")
        torch.save(
            {
                "model": model.state_dict(),
                "optimizer": optimizer.state_dict(),
                "rng": torch.get_rng_state(),
                "epoch": epoch,
            },
            temporary,
        )
        _ = temporary.replace(checkpoint)
        seen_ids.update(dataset.samples[i][1].image_id for i in used)
        metadata = Artifact(
            architecture=config.architecture,
            input_size=model.input_size,
            fingerprint=run_fingerprint,
            checkpoint_sha256=sha256(checkpoint),
            epoch=epoch,
            device=config.device,
            category_heads=config.category_heads,
            deployment_approved=False,
            purpose="cpu_smoke" if config.device == "cpu" else "development_training",
            app_artifact=None,
            server_artifact=str(checkpoint),
            manifests=[ManifestPin(path=str(p.resolve()), sha256=sha256(p)) for p in config.manifests],
            registry_sha256=sha256(REGISTRY_ROOT / "DATASET_MANIFEST.json"),
            dataset_images=len(dataset),
            images_seen_this_epoch=len(used),
            unique_images_seen_this_epoch=len(set(used)),
            seen_image_ids=sorted(seen_ids),
            steps=len(losses),
            loss=sum(losses) / len(losses),
            categories_seen={c: sum(dataset.samples[i][1].category == c for i in used) for c in registry.categories},
            synthetic_images_seen=sum(dataset.samples[i][1].acquisition_metadata.synthetic for i in used),
            sources_seen={
                source: sum(dataset.samples[i][1].source_dataset == source for i in used)
                for source in sorted({record.source_dataset for _, record in dataset.samples})
            },
            parent_checkpoint_sha256=(config.initialize_from.checkpoint_sha256 if config.initialize_from else None),
            code_license="Coordit repository",
            weights_license="Internal development; source attribution obligations apply",
            training_config_json=config.model_dump_json(),
        )
        _ = metadata_path.write_text(metadata.model_dump_json(indent=2) + "\n")
        with (config.output / "training.jsonl").open("a") as log:
            _ = log.write(metadata.model_dump_json() + "\n")
    return checkpoint


def load_model(directory: Path) -> PerceptionModel:
    """Local artifacts only; verify recorded hash and use restricted torch loader."""
    metadata = Artifact.model_validate_json((directory / "artifact.json").read_bytes())
    if metadata.checkpoint_sha256 != sha256(directory / "checkpoint.pt"):
        raise PipelineError("Untrusted or incompatible model artifact")
    if metadata.registry_sha256 != sha256(REGISTRY_ROOT / "DATASET_MANIFEST.json"):
        raise PipelineError("Model rights registry changed; review or retrain before inference")
    registry = read_registry(REGISTRY_ROOT / "DATASET_MANIFEST.json")
    for pin in metadata.manifests:
        manifest = Path(pin.path)
        if not manifest.is_file() or sha256(manifest) != pin.sha256:
            raise PipelineError("Model training manifest changed or is unavailable")
        for record in read_records(manifest):
            _ = approved_entry(registry, record.source_dataset)
    model = create_model(metadata.architecture, metadata.category_heads)
    if metadata.input_size != model.input_size:
        raise PipelineError("Model input dimensions disagree with its architecture")
    state = read_checkpoint(directory / "checkpoint.pt")
    _ = model.load_state_dict(state.model)
    _ = model.eval()
    return model
