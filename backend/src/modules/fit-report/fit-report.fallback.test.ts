import assert from "node:assert/strict";
import {
  configureReportTestEnv,
  FakeSupabaseQuery,
  fitResultId,
  useEnrichedFitResult,
  userId
} from "./fit-report.service.test-fixtures";

const main = async (): Promise<void> => {
  configureReportTestEnv();
  const [{ supabase }, reportBuilder, fallbackModule] = await Promise.all([
    import("../../config/supabase"),
    import("./fit-report.builder"),
    import("./fit-report.fallback")
  ]);
  Object.defineProperty(supabase, "from", {
    value: (table: string): FakeSupabaseQuery => new FakeSupabaseQuery(table)
  });

  useEnrichedFitResult();
  const shirtReportInput = await reportBuilder.buildFitReportInput(userId, fitResultId);
  const pantsReportInput: typeof shirtReportInput = {
    ...shirtReportInput,
    targetProduct: {
      ...shirtReportInput.targetProduct,
      category: "pants"
    }
  };
  const shirtFallback = fallbackModule.buildFallbackFitReport(shirtReportInput);
  const pantsFallback = fallbackModule.buildFallbackFitReport(pantsReportInput);
  const { buildGarmentNarrativeContext } = await import("./fit-report.garment-context");
  const categoryReportInput = (category: "tshirt" | "jacket" | "skirt") => ({
    ...shirtReportInput,
    targetProduct: { ...shirtReportInput.targetProduct, category },
    garmentContext: buildGarmentNarrativeContext({ category, fitType: "regular" as const })
  });
  const tshirtFallback = fallbackModule.buildFallbackFitReport(categoryReportInput("tshirt"));
  const jacketFallback = fallbackModule.buildFallbackFitReport(categoryReportInput("jacket"));
  const tshirtChest = tshirtFallback.measurementAnalysis.find((item) => item.measurement === "가슴단면")?.text;
  const jacketChest = jacketFallback.measurementAnalysis.find((item) => item.measurement === "가슴단면")?.text;
  assert.match(tshirtChest ?? "", /티셔츠/);
  assert.match(jacketChest ?? "", /재킷 여밈/);
  assert.equal(tshirtFallback.summary.includes("레이어드"), false);
  assert.equal(jacketFallback.summary.includes("레이어드"), true);
  assert.notEqual(tshirtChest, jacketChest);
  assert.equal(jacketFallback.sizeTradeoff?.includes("가슴단면"), true);
  // Given: the alternative is closer at the chest, while the recommendation preserves the shoulder.
  const twoSidedTradeoffInput = {
    ...shirtReportInput,
    sizeTradeoff: {
      recommended: "S",
      alternative: "M",
      tradeoffs: [
        { measurement: "chest_width" as const, recommendedDiff: -3.2, alternativeDiff: 1.8, preferred: "alternative" as const },
        { measurement: "shoulder_width" as const, recommendedDiff: 1.4, alternativeDiff: 3, preferred: "recommended" as const }
      ]
    }
  };
  // When: the fallback is generated without a model response.
  const twoSidedTradeoff = fallbackModule.buildFallbackFitReport(twoSidedTradeoffInput).sizeTradeoff ?? "";
  // Then: both sides of the choice are visible to the shopper.
  assert.match(twoSidedTradeoff, /추천 S 사이즈는 어깨/);
  assert.match(twoSidedTradeoff, /대안 M 사이즈는 가슴단면/);
  const equalTradeoff = fallbackModule.buildFallbackFitReport({
    ...shirtReportInput,
    sizeTradeoff: {
      recommended: "S",
      alternative: "M",
      tradeoffs: [{ measurement: "chest_width", recommendedDiff: -2, alternativeDiff: 2, preferred: "equal" }]
    }
  }).sizeTradeoff ?? "";
  assert.match(equalTradeoff, /기준과의 차이가 비슷/);
  assert.equal(equalTradeoff.includes("는 에서"), false);
  assert.equal(JSON.stringify(fallbackModule.buildFallbackFitReport(categoryReportInput("skirt"))).includes("스커트"), true);
  assert.equal(JSON.stringify(jacketFallback).includes("신축성이 있다"), false);
  const shirtLastSentences = shirtFallback.measurementAnalysis.map((item) =>
    item.text.split(/[.!?。]+/).map((sentence) => sentence.trim()).filter(Boolean).at(-1) ?? ""
  );

  assert.notEqual(
    shirtFallback.measurementAnalysis.map((item) => item.text).join("\n"),
    pantsFallback.measurementAnalysis.map((item) => item.text).join("\n")
  );
  assert.equal(new Set(shirtLastSentences).size, shirtFallback.measurementAnalysis.length);
  assert.equal(
    shirtFallback.measurementAnalysis.find((item) => item.measurement === "어깨")?.text.startsWith("어깨는"),
    true
  );
  assert.equal(shirtFallback.cautions[0]?.includes("여름철"), false);
  assert.equal(pantsFallback.measurementAnalysis.some((item) => item.text.includes("포켓")), false);

  console.log("fit-report fallback tests passed");
};

main().catch((error: unknown) => {
  if (error instanceof Error) console.error(error.message);
  throw error;
});
