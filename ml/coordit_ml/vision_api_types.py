"""Typed public-photo API experiment, sanitized responses and provider-reported billing."""

from pathlib import Path
from typing import Annotated, ClassVar, Literal

from pydantic import BaseModel, ConfigDict, Field

from coordit_ml.external_pilot import ExternalPoint
from coordit_ml.schema import BoundaryModel


class BenchmarkConfig(BoundaryModel):
    """A frozen public-photo packet; explicit models, one sample each, no training or model fallback."""

    receipt: Path
    receipt_sha256: str
    protocol: Path
    protocol_sha256: str
    catalog: Path
    catalog_sha256: str
    models: list[str]
    output: Path
    max_tokens: Annotated[int, Field(ge=1024, le=8192)] = 4096
    input_token_reservation: Annotated[int, Field(ge=4096, le=32768)] = 8192
    spending_limit_usd: Annotated[float, Field(gt=0, le=10)] = 5
    seed: int = 20261028
    images_per_model: Annotated[int, Field(ge=1, le=40)] = 8


class CatalogPrice(BaseModel):
    """Catalog estimates, without claiming that each provider bills identical native tokens."""

    model_config: ClassVar[ConfigDict] = ConfigDict(frozen=True, extra="ignore")
    prompt: Annotated[float, Field(ge=0)]
    completion: Annotated[float, Field(ge=0)]


class CatalogArchitecture(BaseModel):
    """Image input support must be advertised, never inferred from a model's name."""

    model_config: ClassVar[ConfigDict] = ConfigDict(frozen=True, extra="ignore")
    input_modalities: list[str]


class ApiModel(BaseModel):
    """Original catalog details stay in the hashed source snapshot, including modality and pricing metadata."""

    model_config: ClassVar[ConfigDict] = ConfigDict(frozen=True, extra="ignore")
    id: str
    pricing: CatalogPrice
    supported_parameters: list[str]
    architecture: CatalogArchitecture


class ModelCatalog(BaseModel):
    """Parse provider metadata without treating its advertised prices as observed cost."""

    model_config: ClassVar[ConfigDict] = ConfigDict(frozen=True, extra="ignore")
    data: list[ApiModel]


class ApiAnnotation(BoundaryModel):
    """Schema constrained model output; all four target names are checked again before scoring."""

    points: list[ExternalPoint]
    note: str


class UsageDetails(BaseModel):
    """Model-native token details; reasoning is included in completion_tokens, never billed twice."""

    model_config: ClassVar[ConfigDict] = ConfigDict(frozen=True, extra="ignore")
    cached_tokens: int = 0
    cache_write_tokens: int = 0
    reasoning_tokens: int = 0


class ApiUsage(BaseModel):
    """Cost is returned by OpenRouter, not guessed from picture size or text length."""

    model_config: ClassVar[ConfigDict] = ConfigDict(frozen=True, extra="ignore", allow_inf_nan=False)
    prompt_tokens: Annotated[int, Field(ge=0)]
    completion_tokens: Annotated[int, Field(ge=0)]
    total_tokens: Annotated[int, Field(ge=0)]
    cost: Annotated[float, Field(ge=0)] | None = None
    is_byok: bool | None = None
    prompt_tokens_details: UsageDetails | None = None
    completion_tokens_details: UsageDetails | None = None


class ApiMessage(BaseModel):
    """Reasoning text, credentials, input pixels and account metadata are deliberately not persisted."""

    model_config: ClassVar[ConfigDict] = ConfigDict(frozen=True, extra="ignore")
    content: str | None = None
    refusal: str | None = None


class ApiChoice(BaseModel):
    """One answer may terminate early; incomplete JSON is not an accurate landmark result."""

    model_config: ClassVar[ConfigDict] = ConfigDict(frozen=True, extra="ignore")
    message: ApiMessage
    finish_reason: str | None = None
    native_finish_reason: str | None = None


class ApiErrorMetadata(BaseModel):
    """Persist documented budget categories only; never vendor messages or arbitrary metadata."""

    model_config: ClassVar[ConfigDict] = ConfigDict(frozen=True, extra="ignore")
    limit_source: Literal["openrouter_in_flight_budget", "openrouter_key_limit", "openrouter_credits"] | None = None


class ApiError(BaseModel):
    """Keep numeric/string error identity only; vendor messages may contain credential fragments."""

    model_config: ClassVar[ConfigDict] = ConfigDict(frozen=True, extra="ignore")
    code: str | int | None = None
    metadata: ApiErrorMetadata | None = None


class ApiResponse(BaseModel):
    """Allowlisted response sufficient to replay coordinates, usage and actual selected provider."""

    model_config: ClassVar[ConfigDict] = ConfigDict(frozen=True, extra="ignore")
    id: str | None = None
    model: str | None = None
    provider: str | None = None
    choices: list[ApiChoice] = Field(default_factory=list)
    usage: ApiUsage | None = None
    error: ApiError | None = None


class ApiAttempt(BoundaryModel):
    """Every scheduled image is retained, including refusals, invalid geometry and uncertain billing."""

    model_requested: str
    case_id: str
    image_sha256: str
    started_utc: str
    elapsed_seconds: Annotated[float, Field(ge=0)]
    http_status: int | None
    request_sha256: str
    response_sha256: str | None
    response: ApiResponse | None
    annotation: ApiAnnotation | None
    failure: str | None
    retry_after_seconds: Annotated[int, Field(ge=0, le=3600)] | None = None
