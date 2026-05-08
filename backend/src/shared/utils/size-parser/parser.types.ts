import type { MeasurementMap } from "../../types/database";

export type ParsingStatus = "manual" | "pending" | "parsed" | "failed" | "mocked";
export type MeasurementSource = "manual" | "ocr" | "url" | "admin";

export interface ParsedSizeRow {
  sizeLabel: string;
  measurements: MeasurementMap;
  rawSizeData: Record<string, unknown>;
  parsingStatus: ParsingStatus;
  measurementSource: MeasurementSource;
  extractedText?: string;
  extractionConfidence?: number;
}
