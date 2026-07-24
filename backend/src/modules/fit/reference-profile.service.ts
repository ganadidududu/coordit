import { supabase } from "../../config/supabase";
import { createHttpError } from "../../shared/utils/http-error";
import { rowToMeasurements } from "../../shared/utils/measurements";
import { BOTTOM_CATEGORIES, TOP_CATEGORIES } from "./fit.constants";
import {
  calculateDynamicWeightsByReferenceVariance,
  calculateReferenceFitProfile,
  getWeightsByCategory
} from "./fit-score.engine";
import type {
  Category,
  FitType,
  MeasurementMap,
  ReferenceClothingInput
} from "./fit.types";

export const CLOSET_GARMENT_KINDS = ["upper", "lower"] as const;
export type ClosetGarmentKind = (typeof CLOSET_GARMENT_KINDS)[number];

interface DbReferenceClothing {
  readonly id: string;
  readonly clothing_item_id: string;
  readonly fit_type: FitType;
  readonly preference_score: number | null;
}

interface DbClothingSize extends MeasurementMap {
  readonly clothing_item_id: string;
  readonly size_label: string | null;
}

export interface ClosetReferenceProfile {
  readonly garmentKind: ClosetGarmentKind;
  readonly referenceCount: number;
  readonly measurements: MeasurementMap;
  readonly sampleCounts: Partial<Record<keyof MeasurementMap, number>>;
  readonly strategy: "weighted_huber_profile_v1" | "unavailable";
}

const profileConfig: Record<
  ClosetGarmentKind,
  { readonly categories: readonly Category[]; readonly profileCategory: Category }
> = {
  upper: { categories: TOP_CATEGORIES, profileCategory: "shirt" },
  lower: { categories: BOTTOM_CATEGORIES, profileCategory: "pants" }
};

export const getClosetReferenceProfile = async (
  userId: string,
  garmentKind: ClosetGarmentKind
): Promise<ClosetReferenceProfile> => {
  const config = profileConfig[garmentKind];
  const { data: references, error: referenceError } = await supabase
    .from("reference_clothing")
    .select("id, clothing_item_id, fit_type, preference_score")
    .eq("user_id", userId)
    .eq("is_active", true)
    .in("category", [...config.categories])
    .returns<DbReferenceClothing[]>();

  if (referenceError) {
    throw createHttpError(500, "Failed to load active reference clothing");
  }
  if (!references || references.length === 0) {
    return {
      garmentKind,
      referenceCount: 0,
      measurements: {},
      sampleCounts: {},
      strategy: "unavailable"
    };
  }

  const clothingItemIds = references.map((reference) => reference.clothing_item_id);
  const { data: sizes, error: sizeError } = await supabase
    .from("clothing_sizes")
    .select("*")
    .eq("user_id", userId)
    .in("clothing_item_id", clothingItemIds)
    .returns<DbClothingSize[]>();

  if (sizeError) {
    throw createHttpError(500, "Failed to load reference clothing measurements");
  }

  const sizeByItemId = new Map(
    (sizes ?? []).map((size) => [size.clothing_item_id, size])
  );
  const inputs = references.flatMap<ReferenceClothingInput>((reference) => {
    const size = sizeByItemId.get(reference.clothing_item_id);
    if (!size) return [];
    return [{
      id: reference.id,
      clothingItemId: reference.clothing_item_id,
      sizeLabel: size.size_label,
      fitType: reference.fit_type,
      preferenceScore: reference.preference_score ?? 100,
      measurements: rowToMeasurements(size)
    }];
  });

  if (inputs.length === 0) {
    return {
      garmentKind,
      referenceCount: 0,
      measurements: {},
      sampleCounts: {},
      strategy: "unavailable"
    };
  }

  const baseWeights = getWeightsByCategory(config.profileCategory);
  const { dynamicWeights } = calculateDynamicWeightsByReferenceVariance(baseWeights, inputs);
  const profile = calculateReferenceFitProfile(inputs, dynamicWeights);
  return {
    garmentKind,
    referenceCount: inputs.length,
    measurements: profile.measurements,
    sampleCounts: profile.sampleCounts,
    strategy: profile.strategy
  };
};
