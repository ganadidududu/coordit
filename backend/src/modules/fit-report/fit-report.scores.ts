import type { MeasurementKey } from "../../shared/types/database";
import { round } from "./fit-report.result-details";
import type { FitReportChartData, MeasurementReportRow } from "./fit-report.types";

const fitPointDefinitions = [
  { key: "silhouette", label: "실루엣" },
  { key: "mobility", label: "활동성" },
  { key: "layering", label: "레이어링" }
] as const;

export const buildFitPointScores = (
  semanticSubscores: Readonly<Record<string, number>>
): FitReportChartData["fitPointScores"] =>
  fitPointDefinitions.flatMap((definition) => {
    const score = semanticSubscores[definition.key];
    return typeof score === "number" && Number.isFinite(score)
      ? [{ ...definition, score }]
      : [];
  });

export const buildMeasurementScores = (
  measurements: readonly MeasurementReportRow[],
  measurementSubscores: Readonly<Partial<Record<MeasurementKey, number>>>
): FitReportChartData["measurementScores"] =>
  measurements.flatMap((measurement) => {
    const score = measurementSubscores[measurement.key];
    return typeof score === "number" && Number.isFinite(score)
      ? [{
        measurement: measurement.key,
        label: measurement.label,
        score: round(Math.min(Math.max(score, 0), 100), 2),
        diff: measurement.diff,
        status: measurement.status
      }]
      : [];
  });
