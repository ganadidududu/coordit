import type { MeasurementKey, SizeFitScore, SizeTradeoffAnalysis } from "./fit.types";

export const buildSizeTradeoff = (
  recommended: SizeFitScore,
  alternative?: SizeFitScore
): SizeTradeoffAnalysis | undefined => {
  if (!alternative) return undefined;
  const keys = recommended.comparedMeasurements.filter((key) =>
    typeof alternative.diffs[key] === "number"
  );
  return {
    recommended: recommended.sizeLabel,
    alternative: alternative.sizeLabel,
    tradeoffs: keys.map((measurement: MeasurementKey) => {
      const recommendedDiff = recommended.diffs[measurement] ?? 0;
      const alternativeDiff = alternative.diffs[measurement] ?? 0;
      const recommendedGap = Math.abs(recommendedDiff);
      const alternativeGap = Math.abs(alternativeDiff);
      return {
        measurement,
        recommendedDiff,
        alternativeDiff,
        preferred: recommendedGap < alternativeGap
          ? "recommended" as const
          : alternativeGap < recommendedGap ? "alternative" as const : "equal" as const
      };
    })
  };
};
