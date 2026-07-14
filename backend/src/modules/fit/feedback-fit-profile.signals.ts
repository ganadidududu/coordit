import { BOTTOM_CATEGORIES } from "./fit.constants";
import type { Category, FeedbackFitLabel, MeasurementKey, PartFeedbackMap } from "./fit.types";
import type { FeedbackProfileSourceRow } from "./feedback-fit-profile.types";

export const CATEGORY_MIN_USABLE_ROWS = 5;
export const PART_MIN_USABLE_ROWS = 3;
export const MAX_OFFSET_CM = 2;
export const MAX_WEIGHT_MULTIPLIER = 1.3;
export const ISSUE_WEIGHT_STEP = 0.1;
export const CONFLICTING_DIRECTION_RATIO = 0.35;

const RECENCY_HALF_LIFE_DAYS = 180;
const MIN_RECENCY_WEIGHT = 0.25;
const CLICK_CORROBORATION_WEIGHT = 1.1;
const PURCHASE_CORROBORATION_WEIGHT = 1.25;

export const MEASUREMENT_OFFSET_SCALE: Record<MeasurementKey, number> = {
  shoulder_width: 1,
  chest_width: 1,
  total_length: 1.5,
  sleeve_length: 1.25,
  waist_width: 0.75,
  hip_width: 1,
  rise: 0.75,
  outseam: 1.5
};

const TOP_KEYS: readonly MeasurementKey[] = ["shoulder_width", "chest_width", "total_length", "sleeve_length"];
const BOTTOM_KEYS: readonly MeasurementKey[] = ["waist_width", "hip_width", "rise", "outseam"];

export const getCategoryMeasurementKeys = (category: Category): readonly MeasurementKey[] =>
  BOTTOM_CATEGORIES.includes(category) ? BOTTOM_KEYS : TOP_KEYS;

export const normalizeFeedbackLabel = (label: string | null | undefined): FeedbackFitLabel | undefined => {
  switch (label) {
    case "too_small":
    case "small":
      return "too_small";
    case "slightly_small":
      return "slightly_small";
    case "very_good_fit":
    case "good_fit":
    case "acceptable":
    case "good":
      return "good";
    case "slightly_large":
      return "slightly_large";
    case "too_large":
    case "large":
      return "too_large";
    default:
      return undefined;
  }
};

export const getFeedbackDirection = (label: FeedbackFitLabel): number => {
  switch (label) {
    case "too_small":
      return 1;
    case "slightly_small":
      return 0.5;
    case "good":
      return 0;
    case "slightly_large":
      return -0.5;
    case "too_large":
      return -1;
  }
};

export const clamp = (value: number, minimum: number, maximum: number): number =>
  Math.max(minimum, Math.min(maximum, value));

export const round = (value: number, digits = 3): number => Number(value.toFixed(digits));

const isMeasurementKey = (key: string): key is MeasurementKey =>
  Object.prototype.hasOwnProperty.call(MEASUREMENT_OFFSET_SCALE, key);

export const normalizePartFeedback = (value: unknown): PartFeedbackMap => {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};

  return Object.entries(value).reduce<PartFeedbackMap>((partFeedback, [key, label]) => {
    const normalizedLabel = normalizeFeedbackLabel(typeof label === "string" ? label : undefined);
    if (normalizedLabel && isMeasurementKey(key)) {
      partFeedback[key] = normalizedLabel;
    }
    return partFeedback;
  }, {});
};

const getRecencyWeight = (createdAt: string | null, now: Date): number => {
  if (!createdAt) return MIN_RECENCY_WEIGHT;
  const createdTime = new Date(createdAt).getTime();
  if (!Number.isFinite(createdTime)) return MIN_RECENCY_WEIGHT;
  const ageDays = Math.max(0, (now.getTime() - createdTime) / 86_400_000);
  return round(Math.max(MIN_RECENCY_WEIGHT, 0.5 ** (ageDays / RECENCY_HALF_LIFE_DAYS)), 4);
};

const getCorroborationWeight = (row: FeedbackProfileSourceRow): number => {
  const log = row.recommendationLog;
  if (!log) return 1;
  if (log.purchasedAt || log.eventType === "purchased") return PURCHASE_CORROBORATION_WEIGHT;
  if (log.clickedAt || log.eventType === "clicked") return CLICK_CORROBORATION_WEIGHT;
  return 1;
};

export const getRowWeight = (row: FeedbackProfileSourceRow, now: Date): number =>
  round(getRecencyWeight(row.createdAt, now) * getCorroborationWeight(row), 4);

export const hasUsableFeedback = (row: FeedbackProfileSourceRow): boolean =>
  Boolean(normalizeFeedbackLabel(row.actualFitLabel)) ||
  Object.keys(normalizePartFeedback(row.partFeedback)).length > 0;
