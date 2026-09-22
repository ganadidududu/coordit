import { z } from "zod";
import type { JsonObject } from "../../shared/types/database";
import type { GenerateFitReportResult } from "./fit-report.types";

const measurementKeySchema = z.enum([
  "total_length",
  "shoulder_width",
  "chest_width",
  "sleeve_length",
  "waist_width",
  "hip_width",
  "rise",
  "outseam"
]);

const reportSchema = z.object({
  title: z.string(),
  summary: z.string(),
  garmentFitContext: z.string().optional(),
  recommendationReason: z.string(),
  measurementAnalysis: z.array(z.object({
    measurement: z.string(),
    text: z.string()
  })),
  cautions: z.array(z.string()),
  nextActions: z.array(z.string()),
  sizeTradeoff: z.string().optional()
});

const chartDataSchema = z.object({
  fitPointScores: z.array(z.object({
    key: z.enum(["silhouette", "mobility", "layering"]),
    label: z.string(),
    score: z.number().finite().min(0).max(100)
  })).default([]),
  measurementScores: z.array(z.object({
    measurement: measurementKeySchema,
    label: z.string(),
    score: z.number().finite().min(0).max(100),
    diff: z.number().finite(),
    status: z.string().nullable()
  })).default([]),
  idealVsProduct: z.array(z.object({
    measurement: measurementKeySchema,
    label: z.string(),
    ideal: z.number().finite(),
    product: z.number().finite(),
    diff: z.number().finite(),
    status: z.string().nullable()
  })),
  differenceBar: z.array(z.object({
    measurement: measurementKeySchema,
    label: z.string(),
    diff: z.number().finite(),
    direction: z.enum(["larger", "smaller", "same"]),
    status: z.string().nullable()
  })),
  sizeScoreRanking: z.array(z.object({
    sizeLabel: z.string(),
    fitScore: z.number().finite(),
    fitLabel: z.string(),
    weightedFitDistance: z.number().finite(),
    recommendationConfidence: z.string()
  })),
  feedbackAdjustment: z.array(z.object({
    measurement: measurementKeySchema,
    label: z.string(),
    offset: z.number().finite(),
    weightMultiplier: z.number().finite()
  }))
});

const storedFitReportArtifactSchema = z.object({
  schemaVersion: z.literal(1),
  source: z.enum(["openrouter", "fallback"]),
  modelName: z.string(),
  promptVersion: z.enum(["fit_report_v6", "fit_report_v7"]),
  report: reportSchema,
  chartData: chartDataSchema
});

type StoredFitReportArtifact = z.infer<typeof storedFitReportArtifactSchema>;

const storedReportDetailsSchema = z.object({
  storedFitReport: storedFitReportArtifactSchema.optional()
}).passthrough();

export const readStoredFitReport = (details: JsonObject): StoredFitReportArtifact | null => {
  const parsed = storedReportDetailsSchema.safeParse(details);
  if (!parsed.success) return null;
  return parsed.data.storedFitReport ?? null;
};

export const storeFitReport = (
  details: JsonObject,
  report: GenerateFitReportResult
): JsonObject => ({
  ...details,
  storedFitReport: {
    schemaVersion: 1,
    source: report.source,
    modelName: report.modelName,
    promptVersion: report.promptVersion,
    report: report.report,
    chartData: report.chartData
  }
});
