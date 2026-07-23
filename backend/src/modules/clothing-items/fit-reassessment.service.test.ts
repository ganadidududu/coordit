import assert from "node:assert/strict";
import test from "node:test";
import type {
  ClothingItemRow,
  ClothingSizeRow,
  ReferenceClothingRow
} from "../../shared/types/database";
import { createFitReassessmentService } from "./fit-reassessment.service";
import type {
  ClothingFitAssessmentRow,
  FitReassessmentRepository
} from "./fit-reassessment.types";

const targetItem: ClothingItemRow = {
  id: "target",
  user_id: "user",
  name: "Target T-shirt",
  brand: null,
  category: "tshirt",
  fit_type: "regular",
  size_label: "M",
  notes: null,
  image_url: null,
  raw_product_data: {},
  created_at: "2026-07-22T00:00:00.000Z",
  updated_at: "2026-07-22T00:00:00.000Z"
};

const size = (id: string, clothingItemId: string, chestWidth: number): ClothingSizeRow => ({
  id,
  user_id: "user",
  clothing_item_id: clothingItemId,
  size_label: "M",
  total_length: 70,
  shoulder_width: 45,
  chest_width: chestWidth,
  sleeve_length: 61,
  raw_measurements: {},
  created_at: "2026-07-22T00:00:00.000Z",
  updated_at: "2026-07-22T00:00:00.000Z"
});

const reference = (id: string, clothingItemId: string): ReferenceClothingRow => ({
  id,
  user_id: "user",
  clothing_item_id: clothingItemId,
  nickname: id,
  category: "hoodie",
  fit_type: "regular",
  preference_score: 100,
  is_active: true,
  notes: null,
  created_at: "2026-07-22T00:00:00.000Z",
  updated_at: "2026-07-22T00:00:00.000Z"
});

test("reassessment uses every same-group reference and excludes the selected item", async () => {
  // Given: one upper target, its own reference, and another upper exact category reference.
  let recorded: ClothingFitAssessmentRow | undefined;
  const repository: FitReassessmentRepository = {
    loadSource: async () => ({
      target: { item: targetItem, size: size("target-size", "target", 54) },
      references: [
        { reference: reference("self-reference", "target"), size: size("target-size", "target", 54) },
        { reference: reference("hoodie-reference", "hoodie-item"), size: size("hoodie-size", "hoodie-item", 56) }
      ]
    }),
    record: async (input) => {
      recorded = {
        id: "assessment",
        user_id: input.userId,
        clothing_item_id: input.clothingItemId,
        clothing_size_id: input.clothingSizeId,
        created_at: input.assessment.evaluated_at,
        ...input.assessment
      };
      return recorded;
    }
  };
  const service = createFitReassessmentService({
    repository,
    buildFeedbackProfile: async () => undefined,
    now: () => new Date("2026-07-22T01:00:00.000Z")
  });

  // When: the selected T-shirt is reassessed.
  const assessment = await service.reassess("user", "target");

  // Then: the same selected item is persisted against only the other upper reference.
  assert.equal(assessment.clothing_item_id, "target");
  assert.deepEqual(recorded?.result_details.referenceClothingIds, ["hoodie-reference"]);
});
