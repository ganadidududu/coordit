import { measurementKeys } from "../../shared/utils/measurements";
import type { MeasurementKey } from "../../shared/types/database";
import type { FitInteractionResult, FitSemanticFact, SizeTradeoffAnalysis } from "../fit/fit.types";
import { isKnownFitSemanticEffect } from "../fit/fit-semantic-facts";
import { isKnownFitInteractionEffect, isKnownFitInteractionId } from "../fit/garment-fit-profiles";
import { asNumber } from "./fit-report.result-details";
import type { ResultDetails } from "./fit-report.result-details";

const isRecord = (value: unknown): value is Record<string, unknown> =>
  value !== null && typeof value === "object" && !Array.isArray(value);
const allowed = <T extends string>(value: unknown, values: readonly T[]): value is T =>
  typeof value === "string" && values.some((candidate) => candidate === value);
const isMeasurementKey = (value: unknown): value is MeasurementKey => allowed(value, measurementKeys);
const stringArray = (source: unknown): string[] =>
  Array.isArray(source) ? source.filter((item): item is string => typeof item === "string") : [];

export const sanitizeSemanticFacts = (source: unknown): readonly FitSemanticFact[] =>
  Array.isArray(source) ? source.flatMap((item): FitSemanticFact[] => {
    if (!isRecord(item) || !isMeasurementKey(item.measurement)) return [];
    const reference = asNumber(item.reference);
    const product = asNumber(item.product);
    const diff = asNumber(item.diff);
    const normalizedDiff = asNumber(item.normalizedDiff);
    if (reference === null || product === null || diff === null || normalizedDiff === null) return [];
    if (!allowed(item.direction, ["smaller", "larger", "same"] as const) ||
        !allowed(item.severity, ["very_similar", "mild", "moderate", "significant"] as const) ||
        !allowed(item.importance, ["critical", "primary", "secondary"] as const)) return [];
    return [{ measurement: item.measurement, reference, product, diff, normalizedDiff,
      direction: item.direction, severity: item.severity, importance: item.importance,
      semanticEffects: stringArray(item.semanticEffects).filter(isKnownFitSemanticEffect) }];
  }) : [];

export const sanitizeInteractions = (source: unknown): readonly FitInteractionResult[] =>
  Array.isArray(source) ? source.flatMap((item): FitInteractionResult[] => {
    if (!isRecord(item) || !isKnownFitInteractionId(item.id) ||
        !allowed(item.severity, ["none", "mild", "moderate", "significant"] as const)) return [];
    const scorePenalty = asNumber(item.scorePenalty);
    if (scorePenalty === null) return [];
    const direction = allowed(item.direction, ["smaller", "larger", "mixed"] as const)
      ? item.direction : undefined;
    return [{ id: item.id, severity: item.severity,
      ...(direction ? { direction } : {}),
      involvedMeasurements: Array.isArray(item.involvedMeasurements)
        ? item.involvedMeasurements.filter(isMeasurementKey) : [],
      semanticEffects: stringArray(item.semanticEffects).filter(isKnownFitInteractionEffect), scorePenalty }];
  }) : [];

export const sanitizeSizeTradeoff = (source: unknown): SizeTradeoffAnalysis | undefined => {
  if (!isRecord(source) || typeof source.recommended !== "string" ||
      typeof source.alternative !== "string" || !Array.isArray(source.tradeoffs)) return undefined;
  const tradeoffs = source.tradeoffs.flatMap((item) => {
    if (!isRecord(item) || !isMeasurementKey(item.measurement) ||
        !allowed(item.preferred, ["recommended", "alternative", "equal"] as const)) return [];
    const recommendedDiff = asNumber(item.recommendedDiff);
    const alternativeDiff = asNumber(item.alternativeDiff);
    return recommendedDiff === null || alternativeDiff === null ? []
      : [{ measurement: item.measurement, recommendedDiff, alternativeDiff, preferred: item.preferred }];
  });
  return { recommended: source.recommended, alternative: source.alternative, tradeoffs };
};

export const sanitizeVersions = (source: unknown): ResultDetails["versions"] | undefined => {
  if (!isRecord(source)) return undefined;
  const keys = ["fitEngineVersion", "garmentProfileVersion", "semanticRulesVersion", "fitReportPromptVersion"] as const;
  const versions = keys.reduce<Record<string, string>>((output, key) => {
    if (typeof source[key] === "string") output[key] = source[key];
    return output;
  }, {});
  return Object.keys(versions).length > 0 ? versions : undefined;
};
