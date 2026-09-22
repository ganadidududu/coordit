import { analyzeFitInteractions, getInteractionPenalty } from "./fit-interactions";
import { buildFitSemanticFacts } from "./fit-semantic-facts";
import { buildMeasurementSubscores, buildSemanticSubscores } from "./fit-subscores";
import { huberLoss, scoreFromLoss } from "./fit-tolerance";
import type {
  Category,
  FitType,
  MeasurementMap,
  MeasurementWeights,
  ReferenceFitProfile,
  SizeFitScore
} from "./fit.types";

type V2ScoreDetails = Pick<
  SizeFitScore,
  "fitScore" | "finalFitScore" | "weightedFitDistance" | "penalty" |
  "measurementSubscores" | "semanticSubscores" | "semanticFacts" | "interactions"
>;

type V2ScoreInput = {
  readonly reference: MeasurementMap;
  readonly product: MeasurementMap;
  readonly category: Category;
  readonly fitType: FitType;
  readonly weights: MeasurementWeights;
  readonly referenceProfile?: ReferenceFitProfile;
};

const getImportanceModifier = (fitType: FitType, measurement: keyof MeasurementWeights): number => {
  if (fitType === "slim" && (measurement === "chest_width" || measurement === "waist_width")) return 1.15;
  if (fitType === "relaxed" && (measurement === "chest_width" || measurement === "hip_width")) return 1.08;
  if (fitType === "oversized" && (measurement === "shoulder_width" || measurement === "chest_width")) return 1.12;
  return 1;
};

export const calculateV2ScoreDetails = (input: V2ScoreInput): V2ScoreDetails => {
  const facts = buildFitSemanticFacts(input);
  const weightedFacts = facts.flatMap((fact) => {
    const weight = input.weights[fact.measurement];
    return typeof weight === "number" && weight > 0
      ? [{ fact, weight: weight * getImportanceModifier(input.fitType, fact.measurement) }]
      : [];
  });
  const usedWeight = weightedFacts.reduce((total, item) => total + item.weight, 0);
  if (usedWeight === 0) throw new Error("No comparable measurements were provided");
  const normalizedLoss = weightedFacts.reduce(
    (total, item) => total + huberLoss(item.fact.normalizedDiff) * item.weight,
    0
  ) / usedWeight;
  const fitScore = scoreFromLoss(normalizedLoss);
  const interactions = analyzeFitInteractions(input.category, facts);
  const penalty = getInteractionPenalty(interactions);
  const finalFitScore = Number(Math.max(.1, fitScore - penalty).toFixed(2));
  const measurementSubscores = buildMeasurementSubscores(facts);
  return {
    fitScore,
    finalFitScore,
    weightedFitDistance: Number(normalizedLoss.toFixed(3)),
    penalty,
    measurementSubscores,
    semanticSubscores: buildSemanticSubscores(input.category, measurementSubscores),
    semanticFacts: facts,
    interactions
  };
};
