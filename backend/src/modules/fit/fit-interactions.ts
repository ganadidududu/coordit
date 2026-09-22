import { getGarmentFitProfile } from "./garment-fit-profiles";
import type {
  Category,
  FitInteractionResult,
  FitInteractionSeverity,
  FitSemanticFact
} from "./fit.types";

const penaltyBySeverity: Readonly<Record<FitInteractionSeverity, number>> = {
  none: 0,
  mild: .2,
  moderate: .5,
  significant: 1
};

const getSeverity = (intensity: number, imbalance: number): FitInteractionSeverity => {
  const signal = Math.max(intensity, imbalance * 1.25);
  if (signal < .6) return "none";
  if (signal < 1) return "mild";
  if (signal < 1.75) return "moderate";
  return "significant";
};

export const analyzeFitInteractions = (
  category: Category,
  facts: readonly FitSemanticFact[]
): readonly FitInteractionResult[] => {
  const factsByMeasurement = new Map(facts.map((fact) => [fact.measurement, fact]));
  return getGarmentFitProfile(category).interactionRules.flatMap((rule) => {
    const ruleFacts = rule.measurements.flatMap((measurement) => {
      const fact = factsByMeasurement.get(measurement);
      return fact ? [fact] : [];
    });
    if (ruleFacts.length < 2) return [];
    const normalized = ruleFacts.map((fact) => fact.normalizedDiff);
    const intensity = normalized.reduce((total, value) => total + value, 0) / normalized.length;
    const imbalance = Math.max(...normalized) - Math.min(...normalized);
    const severity = getSeverity(intensity, imbalance);
    if (severity === "none") return [];
    const directions = ruleFacts
      .map((fact) => fact.direction)
      .filter((direction): direction is "smaller" | "larger" => direction !== "same");
    const uniqueDirections = new Set(directions);
    const onlyDirection = directions[0];
    const direction = uniqueDirections.size === 1 && onlyDirection ? onlyDirection : "mixed";
    return [{
      id: rule.id,
      severity,
      direction,
      involvedMeasurements: rule.measurements,
      semanticEffects: rule.semanticEffects,
      scorePenalty: penaltyBySeverity[severity]
    }];
  });
};

export const getInteractionPenalty = (interactions: readonly FitInteractionResult[]): number =>
  Number(Math.min(2, interactions.reduce((total, result) => total + result.scorePenalty, 0)).toFixed(2));
