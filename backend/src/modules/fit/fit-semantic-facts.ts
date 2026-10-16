import { getGarmentFitProfile } from "./garment-fit-profiles";
import { getEffectiveTolerance } from "./fit-tolerance";
import type {
  Category,
  FitSemanticFact,
  FitType,
  MeasurementKey,
  MeasurementMap,
  ReferenceFitProfile
} from "./fit.types";

export const SEMANTIC_RULES_VERSION = "fit_semantics_v2_0" as const;

const isNumber = (value: number | null | undefined): value is number =>
  typeof value === "number" && Number.isFinite(value);

const round = (value: number): number => Number(value.toFixed(3));
const MAX_SCORED_DIFF = 1_000_000;

const effectDictionary: Readonly<Record<Category, Partial<Record<MeasurementKey, {
  readonly smaller: readonly string[];
  readonly larger: readonly string[];
}>>>> = {
  tshirt: { chest_width: { smaller: ["body_room_reduced", "tshirt_silhouette_closer"], larger: ["body_room_increased", "tshirt_silhouette_looser"] }, shoulder_width: { smaller: ["shoulder_line_moves_inward"], larger: ["shoulder_drop_increased"] }, total_length: { smaller: ["hem_sits_higher"], larger: ["hem_sits_lower"] } },
  shirt: { chest_width: { smaller: ["body_room_reduced", "forward_arm_movement_may_tighten"], larger: ["body_room_increased", "shirt_silhouette_looser"] }, shoulder_width: { smaller: ["shoulder_line_moves_inward", "arm_mobility_may_reduce"], larger: ["shoulder_line_moves_outward"] }, sleeve_length: { smaller: ["sleeve_position_higher"], larger: ["sleeve_position_lower"] } },
  sweatshirt: { chest_width: { smaller: ["body_volume_reduced"], larger: ["body_volume_increased"] }, shoulder_width: { smaller: ["shoulder_room_reduced"], larger: ["shoulder_volume_increased"] } },
  hoodie: { chest_width: { smaller: ["body_volume_reduced", "layering_room_reduced"], larger: ["body_volume_increased", "layering_room_increased"] }, sleeve_length: { smaller: ["sleeve_volume_reduced"], larger: ["sleeve_volume_increased"] } },
  knit: { chest_width: { smaller: ["body_room_reduced", "knit_silhouette_closer"], larger: ["body_room_increased", "knit_silhouette_looser"] }, total_length: { smaller: ["hem_sits_higher"], larger: ["hem_sits_lower"] } },
  jacket: { chest_width: { smaller: ["body_room_reduced", "layering_room_reduced", "forward_arm_movement_may_tighten"], larger: ["body_room_increased", "layering_room_increased"] }, shoulder_width: { smaller: ["shoulder_structure_tighter", "arm_mobility_may_reduce"], larger: ["shoulder_structure_relaxed"] }, sleeve_length: { smaller: ["sleeve_position_higher"], larger: ["sleeve_position_lower"] } },
  coat: { chest_width: { smaller: ["body_volume_reduced", "layering_room_reduced"], larger: ["body_volume_increased", "layering_room_increased"] }, total_length: { smaller: ["coat_length_shorter"], larger: ["coat_length_longer"] }, shoulder_width: { smaller: ["shoulder_structure_tighter"], larger: ["shoulder_structure_relaxed"] } },
  pants: { waist_width: { smaller: ["waist_pressure_increased"], larger: ["waist_hold_reduced"] }, hip_width: { smaller: ["hip_room_reduced", "seated_comfort_may_reduce"], larger: ["hip_room_increased"] }, rise: { smaller: ["rise_room_reduced", "seated_comfort_may_reduce"], larger: ["rise_room_increased"] }, outseam: { smaller: ["hem_sits_higher"], larger: ["hem_sits_lower"] } },
  jeans: { waist_width: { smaller: ["waist_pressure_increased"], larger: ["waist_hold_reduced"] }, hip_width: { smaller: ["hip_room_reduced", "seated_comfort_may_reduce"], larger: ["hip_room_increased"] }, rise: { smaller: ["rise_room_reduced"], larger: ["rise_room_increased"] } },
  shorts: { waist_width: { smaller: ["waist_pressure_increased"], larger: ["waist_hold_reduced"] }, hip_width: { smaller: ["hip_room_reduced", "seated_movement_may_reduce"], larger: ["hip_room_increased"] }, total_length: { smaller: ["leg_exposure_increased"], larger: ["leg_exposure_reduced"] } },
  skirt: { waist_width: { smaller: ["waist_pressure_increased"], larger: ["waist_hold_reduced"] }, hip_width: { smaller: ["hip_room_reduced", "skirt_silhouette_closer"], larger: ["hip_room_increased", "skirt_silhouette_looser"] }, total_length: { smaller: ["skirt_length_shorter"], larger: ["skirt_length_longer"] } }
};

const knownSemanticEffects = new Set<string>([
  "measurement_matches_reference",
  "measurement_directional_change",
  ...Object.values(effectDictionary).flatMap((measurements) =>
    Object.values(measurements).flatMap((directions) =>
      directions ? [...directions.smaller, ...directions.larger] : []
    )
  )
]);

export const isKnownFitSemanticEffect = (value: unknown): value is string =>
  typeof value === "string" && knownSemanticEffects.has(value);

const severityFor = (normalizedDiff: number): FitSemanticFact["severity"] => {
  if (normalizedDiff <= .25) return "very_similar";
  if (normalizedDiff <= .75) return "mild";
  if (normalizedDiff <= 1.5) return "moderate";
  return "significant";
};

export const buildFitSemanticFacts = (
  input: {
    readonly reference: MeasurementMap;
    readonly product: MeasurementMap;
    readonly category: Category;
    readonly fitType: FitType;
    readonly referenceProfile?: ReferenceFitProfile;
  }
): readonly FitSemanticFact[] => {
  const profile = getGarmentFitProfile(input.category);
  return (Object.keys(profile.weights) as MeasurementKey[]).flatMap((measurement) => {
    const referenceValue = input.reference[measurement];
    const productValue = input.product[measurement];
    if (!isNumber(referenceValue) || !isNumber(productValue)) return [];
    const rawDiff = productValue - referenceValue;
    const diff = round(Math.max(-MAX_SCORED_DIFF, Math.min(MAX_SCORED_DIFF, rawDiff)));
    const direction = diff < 0 ? "smaller" as const : diff > 0 ? "larger" as const : "same" as const;
    const normalizedDiff = round(Math.abs(diff) / getEffectiveTolerance({
      category: input.category,
      fitType: input.fitType,
      key: measurement,
      diff,
      referenceProfile: input.referenceProfile
    }));
    const effects = direction === "same"
      ? ["measurement_matches_reference"]
      : effectDictionary[input.category][measurement]?.[direction] ?? ["measurement_directional_change"];
    const importance = profile.criticalMeasurements.includes(measurement)
      ? "critical" as const
      : profile.secondaryMeasurements.includes(measurement) ? "secondary" as const : "primary" as const;
    return [{ measurement, reference: referenceValue, product: productValue, diff, normalizedDiff, direction, severity: severityFor(normalizedDiff), importance, semanticEffects: effects }];
  });
};
