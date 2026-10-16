import { getGarmentFitProfile } from "./garment-fit-profiles";
import type {
  Category,
  FitType,
  MeasurementKey,
  ReferenceFitProfile
} from "./fit.types";

const clamp = (value: number, minimum: number, maximum: number): number =>
  Math.max(minimum, Math.min(maximum, value));

const volumeKeys: readonly MeasurementKey[] = [
  "shoulder_width", "chest_width", "waist_width", "hip_width"
];

const getFitTypeModifier = (
  fitType: FitType,
  key: MeasurementKey,
  direction: "smaller" | "larger"
): number => {
  const isVolume = volumeKeys.includes(key);
  if (!isVolume) return fitType === "oversized" && direction === "larger" ? 1.15 : 1;
  switch (fitType) {
    case "slim":
      return direction === "larger" ? .8 : 1.05;
    case "regular":
      return 1;
    case "relaxed":
      return direction === "larger" ? 1.2 : .9;
    case "oversized":
      return direction === "larger" ? 1.5 : .8;
  }
};

export const getEffectiveTolerance = (
  input: {
    readonly category: Category;
    readonly fitType: FitType;
    readonly key: MeasurementKey;
    readonly diff: number;
    readonly referenceProfile?: ReferenceFitProfile;
  }
): number => {
  const profile = getGarmentFitProfile(input.category);
  const directional = profile.directionalTolerances[input.key];
  const fallback = profile.baseTolerances[input.key] ?? 1;
  const base = directional
    ? input.diff < 0 ? directional.smaller : directional.larger
    : fallback;
  const learned = input.referenceProfile?.tolerances[input.key];
  const varianceModifier = learned && fallback > 0
    ? clamp(learned / fallback, 1, 1.5)
    : 1;
  const direction = input.diff < 0 ? "smaller" : "larger";
  return base * getFitTypeModifier(input.fitType, input.key, direction) * varianceModifier;
};

export const huberLoss = (normalizedDiff: number): number => {
  const absolute = Math.abs(normalizedDiff);
  return absolute <= 1 ? .5 * absolute ** 2 : absolute - .5;
};

export const scoreFromLoss = (loss: number): number =>
  Number(Math.max(.1, Math.min(100, 100 * Math.exp(-Math.max(0, loss) / 1.5))).toFixed(2));
