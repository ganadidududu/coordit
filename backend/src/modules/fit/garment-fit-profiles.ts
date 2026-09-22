import type {
  Category,
  DirectionalToleranceMap,
  FitInteractionRule,
  GarmentFitProfile,
  MeasurementKey,
  MeasurementWeights
} from "./fit.types";

export const GARMENT_PROFILE_VERSION = "garment_profiles_v2_0" as const;

const upperBalance: FitInteractionRule = {
  id: "upper_body_balance",
  measurements: ["shoulder_width", "chest_width"],
  semanticEffects: ["upper_body_balance_changed"]
};
const shoulderSleeve: FitInteractionRule = {
  id: "shoulder_sleeve_balance",
  measurements: ["shoulder_width", "sleeve_length"],
  semanticEffects: ["arm_mobility_balance_changed"]
};
const chestLength: FitInteractionRule = {
  id: "body_length_balance",
  measurements: ["chest_width", "total_length"],
  semanticEffects: ["silhouette_balance_changed"]
};
const outerwearVolume: FitInteractionRule = {
  id: "outerwear_volume_balance",
  measurements: ["chest_width", "sleeve_length"],
  semanticEffects: ["layering_volume_balance_changed"]
};
const waistHip: FitInteractionRule = {
  id: "waist_hip_balance",
  measurements: ["waist_width", "hip_width"],
  semanticEffects: ["waist_hip_balance_changed", "seated_comfort_may_change"]
};
const hipRise: FitInteractionRule = {
  id: "hip_rise_balance",
  measurements: ["hip_width", "rise"],
  semanticEffects: ["hip_rise_balance_changed", "seated_comfort_may_change"]
};
const riseOutseam: FitInteractionRule = {
  id: "rise_length_balance",
  measurements: ["rise", "outseam"],
  semanticEffects: ["leg_proportion_changed"]
};
const jeansCore: FitInteractionRule = {
  id: "jeans_core_balance",
  measurements: ["waist_width", "hip_width", "rise"],
  semanticEffects: ["jeans_silhouette_balance_changed", "seated_comfort_may_change"]
};
const skirtCore: FitInteractionRule = {
  id: "skirt_core_balance",
  measurements: ["waist_width", "hip_width", "total_length"],
  semanticEffects: ["skirt_silhouette_balance_changed"]
};

type ProfileConfig = {
  readonly category: Category;
  readonly weights: MeasurementWeights;
  readonly tolerances: DirectionalToleranceMap;
  readonly critical: readonly MeasurementKey[];
  readonly secondary: readonly MeasurementKey[];
  readonly rules: readonly FitInteractionRule[];
  readonly wearRole: string;
  readonly concerns: readonly string[];
  readonly layering: boolean;
  readonly mobility: boolean;
};

const createProfile = (config: ProfileConfig): GarmentFitProfile => ({
  category: config.category,
  weights: config.weights,
  baseTolerances: Object.fromEntries(
    Object.entries(config.tolerances).map(([key, tolerance]) => [
      key,
      tolerance ? (tolerance.smaller + tolerance.larger) / 2 : 1
    ])
  ),
  directionalTolerances: config.tolerances,
  criticalMeasurements: config.critical,
  secondaryMeasurements: config.secondary,
  interactionRules: config.rules,
  semanticProfile: {
    wearRole: config.wearRole,
    primaryFitConcerns: config.concerns,
    layeringRelevant: config.layering,
    mobilityRelevant: config.mobility
  }
});

const profiles: Readonly<Record<Category, GarmentFitProfile>> = {
  tshirt: createProfile({
    category: "tshirt", weights: { chest_width: .38, total_length: .3, shoulder_width: .2, sleeve_length: .12 },
    tolerances: { chest_width: { smaller: 2, larger: 3 }, total_length: { smaller: 2.5, larger: 3 }, shoulder_width: { smaller: 1.5, larger: 2.5 }, sleeve_length: { smaller: 2, larger: 2.5 } },
    critical: ["chest_width", "total_length"], secondary: ["shoulder_width", "sleeve_length"], rules: [upperBalance, chestLength],
    wearRole: "base_layer", concerns: ["body_room", "overall_silhouette", "hem_length"], layering: false, mobility: false
  }),
  shirt: createProfile({
    category: "shirt", weights: { shoulder_width: .32, chest_width: .3, sleeve_length: .24, total_length: .14 },
    tolerances: { shoulder_width: { smaller: 1.2, larger: 2 }, chest_width: { smaller: 1.8, larger: 2.5 }, sleeve_length: { smaller: 1.5, larger: 2 }, total_length: { smaller: 2.5, larger: 3 } },
    critical: ["shoulder_width", "chest_width", "sleeve_length"], secondary: ["total_length"], rules: [upperBalance, shoulderSleeve],
    wearRole: "woven_top", concerns: ["shoulder_line", "body_room", "sleeve_position", "mobility"], layering: false, mobility: true
  }),
  sweatshirt: createProfile({
    category: "sweatshirt", weights: { chest_width: .36, shoulder_width: .28, total_length: .2, sleeve_length: .16 },
    tolerances: { chest_width: { smaller: 2, larger: 3.5 }, shoulder_width: { smaller: 1.8, larger: 3 }, total_length: { smaller: 2.5, larger: 3.5 }, sleeve_length: { smaller: 2, larger: 3 } },
    critical: ["chest_width", "shoulder_width"], secondary: ["total_length", "sleeve_length"], rules: [upperBalance, chestLength],
    wearRole: "casual_top", concerns: ["body_volume", "shoulder_line", "overall_silhouette"], layering: true, mobility: true
  }),
  hoodie: createProfile({
    category: "hoodie", weights: { chest_width: .35, shoulder_width: .25, sleeve_length: .22, total_length: .18 },
    tolerances: { chest_width: { smaller: 2.2, larger: 4 }, shoulder_width: { smaller: 2, larger: 3.5 }, sleeve_length: { smaller: 2, larger: 3.5 }, total_length: { smaller: 2.5, larger: 4 } },
    critical: ["chest_width", "sleeve_length"], secondary: ["shoulder_width", "total_length"], rules: [upperBalance, shoulderSleeve, chestLength],
    wearRole: "layering_top", concerns: ["body_volume", "sleeve_volume", "layering", "hooded_silhouette"], layering: true, mobility: true
  }),
  knit: createProfile({
    category: "knit", weights: { chest_width: .4, total_length: .3, shoulder_width: .18, sleeve_length: .12 },
    tolerances: { chest_width: { smaller: 1.8, larger: 3 }, total_length: { smaller: 2.5, larger: 3 }, shoulder_width: { smaller: 1.5, larger: 2.5 }, sleeve_length: { smaller: 1.8, larger: 2.5 } },
    critical: ["chest_width", "total_length"], secondary: ["shoulder_width", "sleeve_length"], rules: [upperBalance, chestLength],
    wearRole: "knit_top", concerns: ["body_room", "hem_length", "overall_silhouette"], layering: false, mobility: false
  }),
  jacket: createProfile({
    category: "jacket", weights: { shoulder_width: .34, chest_width: .32, sleeve_length: .22, total_length: .12 },
    tolerances: { shoulder_width: { smaller: 1.3, larger: 2.5 }, chest_width: { smaller: 3, larger: 4 }, sleeve_length: { smaller: 1.5, larger: 2.8 }, total_length: { smaller: 2.5, larger: 3.5 } },
    critical: ["shoulder_width", "chest_width", "sleeve_length"], secondary: ["total_length"], rules: [upperBalance, shoulderSleeve, outerwearVolume],
    wearRole: "outerwear", concerns: ["shoulder_line", "closure_room", "arm_mobility", "layering_room"], layering: true, mobility: true
  }),
  coat: createProfile({
    category: "coat", weights: { chest_width: .34, total_length: .26, shoulder_width: .25, sleeve_length: .15 },
    tolerances: { chest_width: { smaller: 2, larger: 4.5 }, total_length: { smaller: 3, larger: 5 }, shoulder_width: { smaller: 1.5, larger: 3 }, sleeve_length: { smaller: 1.8, larger: 3 } },
    critical: ["chest_width", "total_length", "shoulder_width"], secondary: ["sleeve_length"], rules: [upperBalance, chestLength, outerwearVolume],
    wearRole: "long_outerwear", concerns: ["layering_room", "body_volume", "shoulder_structure", "overall_length"], layering: true, mobility: true
  }),
  pants: createProfile({
    category: "pants", weights: { waist_width: .34, hip_width: .28, rise: .18, outseam: .2 },
    tolerances: { waist_width: { smaller: 1.2, larger: 1.8 }, hip_width: { smaller: 1.5, larger: 2.5 }, rise: { smaller: 1.2, larger: 2 }, outseam: { smaller: 2.5, larger: 3 } },
    critical: ["waist_width", "hip_width"], secondary: ["rise", "outseam"], rules: [waistHip, hipRise, riseOutseam],
    wearRole: "trousers", concerns: ["waist_pressure", "hip_room", "seated_comfort", "hem_length"], layering: false, mobility: true
  }),
  jeans: createProfile({
    category: "jeans", weights: { waist_width: .36, hip_width: .3, rise: .22, outseam: .12 },
    tolerances: { waist_width: { smaller: 1, larger: 1.6 }, hip_width: { smaller: 1.3, larger: 2.2 }, rise: { smaller: 1, larger: 1.8 }, outseam: { smaller: 2.5, larger: 3 } },
    critical: ["waist_width", "hip_width", "rise"], secondary: ["outseam"], rules: [waistHip, hipRise, jeansCore],
    wearRole: "denim_trousers", concerns: ["waist", "hip", "rise", "silhouette", "seated_comfort"], layering: false, mobility: true
  }),
  shorts: createProfile({
    category: "shorts", weights: { waist_width: .38, hip_width: .34, total_length: .28 },
    tolerances: { waist_width: { smaller: 1.2, larger: 1.8 }, hip_width: { smaller: 1.5, larger: 2.5 }, total_length: { smaller: 2, larger: 2.5 } },
    critical: ["waist_width", "hip_width"], secondary: ["total_length"], rules: [waistHip],
    wearRole: "short_bottom", concerns: ["waist", "hip", "leg_length", "seated_movement"], layering: false, mobility: true
  }),
  skirt: createProfile({
    category: "skirt", weights: { waist_width: .42, hip_width: .33, total_length: .25 },
    tolerances: { waist_width: { smaller: 1.2, larger: 1.8 }, hip_width: { smaller: 1.5, larger: 2.5 }, total_length: { smaller: 2.5, larger: 3 } },
    critical: ["waist_width", "hip_width"], secondary: ["total_length"], rules: [skirtCore],
    wearRole: "skirt", concerns: ["waist", "hip", "overall_length", "silhouette"], layering: false, mobility: true
  })
};

export const getGarmentFitProfile = (category: Category): GarmentFitProfile => profiles[category];

const knownInteractionRules = Object.values(profiles).flatMap((profile) => profile.interactionRules);
const knownInteractionIds = new Set(knownInteractionRules.map((rule) => rule.id));
const knownInteractionEffects = new Set(knownInteractionRules.flatMap((rule) => rule.semanticEffects));

export const isKnownFitInteractionId = (value: unknown): value is string =>
  typeof value === "string" && knownInteractionIds.has(value);

export const isKnownFitInteractionEffect = (value: unknown): value is string =>
  typeof value === "string" && knownInteractionEffects.has(value);
