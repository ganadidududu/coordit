import {
  ALGORITHM_VERSION,
  BOTTOM_CATEGORIES,
  BOTTOM_WEIGHTS,
  MEASUREMENT_LABELS,
  TOP_WEIGHTS
} from "./fit.constants";
import type {
  BestSizeRecommendation,
  Category,
  ExternalProductSizeInput,
  FitLabel,
  FitType,
  MeasurementDiffs,
  MeasurementKey,
  MeasurementMap,
  MeasurementWeights,
  ReferenceClothingInput,
  SizeFitScore
} from "./fit.types";

const round = (value: number, digits = 2): number => Number(value.toFixed(digits));

const isNumber = (value: number | null | undefined): value is number =>
  typeof value === "number" && Number.isFinite(value);

const getPartStatus = (diff: number) => {
  if (Math.abs(diff) <= 1) return "very_similar" as const;
  if (diff < 0 && Math.abs(diff) <= 3) return "slightly_small" as const;
  if (diff > 0 && Math.abs(diff) <= 3) return "slightly_large" as const;
  return "large_gap" as const;
};

export const getWeightsByCategory = (category: Category): MeasurementWeights => {
  if (BOTTOM_CATEGORIES.includes(category)) {
    return BOTTOM_WEIGHTS;
  }
  return TOP_WEIGHTS;
};

export const calculateDiff = (
  referenceMeasurements: MeasurementMap,
  targetMeasurements: MeasurementMap
): MeasurementDiffs => {
  const keys = Object.keys({ ...referenceMeasurements, ...targetMeasurements }) as MeasurementKey[];

  return keys.reduce<MeasurementDiffs>((diffs, key) => {
    const referenceValue = referenceMeasurements[key];
    const targetValue = targetMeasurements[key];
    if (isNumber(referenceValue) && isNumber(targetValue)) {
      diffs[key] = round(targetValue - referenceValue);
    }
    return diffs;
  }, {});
};

export const calculateWeightedFitDistance = (
  reference: MeasurementMap,
  target: MeasurementMap,
  weights: MeasurementWeights
): number => {
  let weightedDistance = 0;
  let usedWeight = 0;

  for (const [key, weight] of Object.entries(weights) as [MeasurementKey, number][]) {
    const referenceValue = reference[key];
    const targetValue = target[key];
    if (!isNumber(referenceValue) || !isNumber(targetValue)) {
      continue;
    }

    weightedDistance += Math.abs(targetValue - referenceValue) * weight;
    usedWeight += weight;
  }

  if (usedWeight === 0) {
    throw new Error("No comparable measurements were provided");
  }

  return round(weightedDistance / usedWeight, 3);
};

export const convertDistanceToScore = (distance: number): number => {
  const score = 100 - distance * 10;
  return round(Math.max(0, Math.min(100, score)));
};

export const applyFitTypePenalty = (
  score: number,
  fitType: FitType,
  diffs: MeasurementDiffs
): { finalScore: number; penalty: number } => {
  let penalty = 0;
  const shoulderDiff = diffs.shoulder_width;
  const chestDiff = diffs.chest_width;
  const waistDiff = diffs.waist_width;

  if (fitType === "oversized" && isNumber(shoulderDiff) && shoulderDiff < -2) penalty += 5;
  if (fitType === "oversized" && isNumber(chestDiff) && chestDiff < -2) penalty += 5;
  if (fitType === "relaxed" && isNumber(chestDiff) && chestDiff < -2) penalty += 5;
  if (fitType === "slim" && isNumber(chestDiff) && chestDiff > 3) penalty += 3;
  if (fitType === "slim" && isNumber(waistDiff) && waistDiff > 2) penalty += 3;

  const majorDiffs = [shoulderDiff, chestDiff, waistDiff, diffs.hip_width].filter(isNumber);
  if (fitType === "regular" && majorDiffs.some((diff) => Math.abs(diff) > 4)) {
    penalty += 3;
  }

  return {
    finalScore: round(Math.max(0, score - penalty)),
    penalty
  };
};

const getAverageMajorDiff = (diffs: MeasurementDiffs, category: Category): number => {
  const keys: MeasurementKey[] = BOTTOM_CATEGORIES.includes(category)
    ? ["waist_width", "hip_width", "rise", "inseam"]
    : ["shoulder_width", "chest_width", "total_length", "sleeve_length"];
  const values = keys.map((key) => diffs[key]).filter(isNumber);
  if (values.length === 0) return 0;
  return values.reduce((sum, value) => sum + value, 0) / values.length;
};

export const getFitLabel = (
  score: number,
  diffs: MeasurementDiffs,
  category: Category
): FitLabel => {
  if (score >= 95) return "very_good_fit";
  if (score >= 85) return "good_fit";
  if (score >= 70) return "acceptable";

  const averageDiff = getAverageMajorDiff(diffs, category);
  if (score >= 50) {
    return averageDiff < 0 ? "slightly_small" : "slightly_large";
  }

  return averageDiff < 0 ? "too_small" : "too_large";
};

export const generateFitComment = (result: SizeFitScore): string => {
  const closeMeasurements = result.comparedMeasurements
    .filter((key) => Math.abs(result.diffs[key] ?? 999) <= 1)
    .map((key) => MEASUREMENT_LABELS[key]);

  if (result.fitLabel === "very_good_fit" || result.fitLabel === "good_fit") {
    const parts = closeMeasurements.length > 0 ? closeMeasurements.join(", ") : "주요 실측";
    return `${result.sizeLabel} 사이즈를 추천합니다. 기준 의류와 ${parts} 차이가 작아 유사한 핏이 예상됩니다. 현재 선호 핏과 가장 가까운 실측 조합입니다.`;
  }

  if (result.fitLabel.includes("small")) {
    return `${result.sizeLabel} 사이즈는 기준 의류보다 작게 느껴질 수 있습니다. 한 사이즈 큰 선택지도 함께 확인하세요.`;
  }

  if (result.fitLabel.includes("large")) {
    return `${result.sizeLabel} 사이즈는 기준 의류보다 여유롭게 느껴질 수 있습니다. 원하는 핏 타입과 비교해 결정하세요.`;
  }

  return `${result.sizeLabel} 사이즈는 착용 가능한 범위입니다. 다만 일부 부위 실측 차이를 확인하는 것이 좋습니다.`;
};

export const generatePartExplanations = (diffs: MeasurementDiffs): string[] =>
  (Object.entries(diffs) as [MeasurementKey, number][])
    .filter(([, diff]) => isNumber(diff))
    .map(([key, diff]) => {
      const label = MEASUREMENT_LABELS[key];
      if (Math.abs(diff) <= 1) return `${label}은 기준 의류와 ${Math.abs(diff)}cm 차이로 매우 유사합니다.`;
      if (diff < 0) return `${label}은 기준 의류보다 ${Math.abs(diff)}cm 작아 더 타이트하게 느껴질 수 있습니다.`;
      return `${label}은 기준 의류보다 ${diff}cm 커서 더 여유롭게 느껴질 수 있습니다.`;
    });

export const calculateRecommendationConfidence = (
  score: number,
  comparedCount: number,
  weightedFitDistance: number,
  scoreGap: number
): "high" | "medium" | "low" => {
  if (comparedCount >= 4 && score >= 85 && weightedFitDistance <= 1.5 && scoreGap >= 5) return "high";
  if (comparedCount >= 3 && score >= 70 && weightedFitDistance <= 3) return "medium";
  return "low";
};

export const calculateFitScoreForSize = (
  referenceClothing: ReferenceClothingInput,
  externalProductSize: ExternalProductSizeInput,
  category: Category
): SizeFitScore => {
  const weights = getWeightsByCategory(category);
  const diffs = calculateDiff(referenceClothing.measurements, externalProductSize.measurements);
  const weightedFitDistance = calculateWeightedFitDistance(
    referenceClothing.measurements,
    externalProductSize.measurements,
    weights
  );
  const baseScore = convertDistanceToScore(weightedFitDistance);
  const fitType = externalProductSize.fitType ?? referenceClothing.fitType;
  const { finalScore, penalty } = applyFitTypePenalty(baseScore, fitType, diffs);
  const fitLabel = getFitLabel(finalScore, diffs, category);
  const comparedMeasurements = (Object.keys(weights) as MeasurementKey[]).filter((key) =>
    isNumber(diffs[key])
  );

  const result: SizeFitScore = {
    externalProductSizeId: externalProductSize.id,
    sizeLabel: externalProductSize.sizeLabel,
    fitScore: baseScore,
    finalFitScore: finalScore,
    fitLabel,
    fitComment: "",
    partExplanations: [],
    partStatuses: Object.fromEntries(
      (Object.entries(diffs) as [MeasurementKey, number][]).map(([key, diff]) => [key, getPartStatus(diff)])
    ),
    recommendationConfidence: "low",
    weightedFitDistance,
    penalty,
    diffs,
    comparedMeasurements,
    algorithmVersion: ALGORITHM_VERSION
  };

  return {
    ...result,
    fitComment: generateFitComment(result),
    partExplanations: generatePartExplanations(diffs)
  };
};

export const calculateWeightedScoreForSize = (
  referenceClothing: ReferenceClothingInput[],
  externalProductSize: ExternalProductSizeInput,
  category: Category
): SizeFitScore => {
  if (referenceClothing.length === 0) {
    throw new Error("At least one reference clothing item is required");
  }

  const scoredReferences = referenceClothing.map((reference) => ({
    score: calculateFitScoreForSize(reference, externalProductSize, category),
    weight: Math.max(1, reference.preferenceScore ?? 100)
  }));
  const totalWeight = scoredReferences.reduce((sum, item) => sum + item.weight, 0);
  const bestRepresentative = scoredReferences
    .map((item) => item.score)
    .sort((a, b) => b.finalFitScore - a.finalFitScore)[0];
  const finalFitScore = round(
    scoredReferences.reduce((sum, item) => sum + item.score.finalFitScore * item.weight, 0) / totalWeight
  );
  const weightedFitDistance = round(
    scoredReferences.reduce((sum, item) => sum + item.score.weightedFitDistance * item.weight, 0) / totalWeight,
    3
  );
  const comparedMeasurements = Array.from(
    new Set(scoredReferences.flatMap((item) => item.score.comparedMeasurements))
  );
  const fitLabel = getFitLabel(finalFitScore, bestRepresentative.diffs, category);

  const result: SizeFitScore = {
    ...bestRepresentative,
    fitScore: finalFitScore,
    finalFitScore,
    weightedFitDistance,
    fitLabel,
    comparedMeasurements,
    fitComment: "",
    partExplanations: generatePartExplanations(bestRepresentative.diffs)
  };

  return { ...result, fitComment: generateFitComment(result) };
};

export const recommendBestSize = (
  referenceClothing: ReferenceClothingInput,
  externalProductSizes: ExternalProductSizeInput[],
  category: Category
): BestSizeRecommendation => {
  if (externalProductSizes.length === 0) {
    throw new Error("At least one external product size is required");
  }

  const allSizeScores = externalProductSizes
    .map((size) => calculateFitScoreForSize(referenceClothing, size, category))
    .sort((a, b) => b.finalFitScore - a.finalFitScore);

  return {
    recommended: {
      ...allSizeScores[0],
      recommendationConfidence: calculateRecommendationConfidence(
        allSizeScores[0].finalFitScore,
        allSizeScores[0].comparedMeasurements.length,
        allSizeScores[0].weightedFitDistance,
        allSizeScores[0].finalFitScore - (allSizeScores[1]?.finalFitScore ?? 0)
      )
    },
    allSizeScores: allSizeScores.map((score, index) => ({
      ...score,
      recommendationConfidence: calculateRecommendationConfidence(
        score.finalFitScore,
        score.comparedMeasurements.length,
        score.weightedFitDistance,
        score.finalFitScore - (allSizeScores[index + 1]?.finalFitScore ?? 0)
      )
    }))
  };
};

export const recommendBestSizeWithReferences = (
  referenceClothing: ReferenceClothingInput[],
  externalProductSizes: ExternalProductSizeInput[],
  category: Category
): BestSizeRecommendation => {
  if (externalProductSizes.length === 0) {
    throw new Error("At least one external product size is required");
  }

  const allSizeScores = externalProductSizes
    .map((size) => calculateWeightedScoreForSize(referenceClothing, size, category))
    .sort((a, b) => b.finalFitScore - a.finalFitScore);

  return {
    recommended: {
      ...allSizeScores[0],
      recommendationConfidence: calculateRecommendationConfidence(
        allSizeScores[0].finalFitScore,
        allSizeScores[0].comparedMeasurements.length,
        allSizeScores[0].weightedFitDistance,
        allSizeScores[0].finalFitScore - (allSizeScores[1]?.finalFitScore ?? 0)
      )
    },
    allSizeScores
  };
};
