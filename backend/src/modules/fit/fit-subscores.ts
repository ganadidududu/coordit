import { getGarmentFitProfile } from "./garment-fit-profiles";
import { huberLoss, scoreFromLoss } from "./fit-tolerance";
import type { Category, FitSemanticFact, MeasurementKey } from "./fit.types";

export const buildMeasurementSubscores = (
  facts: readonly FitSemanticFact[]
): Partial<Record<MeasurementKey, number>> =>
  facts.reduce<Partial<Record<MeasurementKey, number>>>((scores, fact) => {
    scores[fact.measurement] = scoreFromLoss(huberLoss(fact.normalizedDiff));
    return scores;
  }, {});

const average = (
  scores: Partial<Record<MeasurementKey, number>>,
  keys: readonly MeasurementKey[]
): number => {
  const available = keys.flatMap((key) => {
    const value = scores[key];
    return typeof value === "number" ? [value] : [];
  });
  return available.length === 0
    ? 0
    : Number((available.reduce((total, value) => total + value, 0) / available.length).toFixed(2));
};

export const buildSemanticSubscores = (
  category: Category,
  measurementScores: Partial<Record<MeasurementKey, number>>
): Readonly<Record<string, number>> => {
  const profile = getGarmentFitProfile(category);
  const silhouette = average(measurementScores, [...profile.criticalMeasurements, ...profile.secondaryMeasurements]);
  const output: Record<string, number> = { silhouette };
  if (profile.semanticProfile.mobilityRelevant) {
    output.mobility = average(measurementScores, ["shoulder_width", "sleeve_length", "hip_width", "rise"]);
  }
  if (profile.semanticProfile.layeringRelevant) {
    output.layering = average(measurementScores, ["chest_width", "shoulder_width"]);
  }
  return output;
};
