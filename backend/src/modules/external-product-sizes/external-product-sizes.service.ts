import { pickMeasurements } from "../../shared/utils/measurements";
import { asOptionalNumber, asOptionalRecord, asOptionalString, asRequiredString } from "../../shared/utils/request";
import {
  insertExternalProductSize,
  patchExternalProductSize,
  removeExternalProductSize,
  selectExternalProductSizes,
  type ExternalProductSizeDto
} from "./external-product-sizes.repository";

const toDto = (body: Record<string, unknown>): ExternalProductSizeDto => ({
  size_label: asRequiredString(body.sizeLabel ?? body.size_label, "sizeLabel"),
  raw_size_data: asOptionalRecord(body.rawSizeData ?? body.raw_size_data),
  parsing_status: asOptionalString(body.parsingStatus ?? body.parsing_status) ?? "manual",
  measurement_source: asOptionalString(body.measurementSource ?? body.measurement_source) ?? "manual",
  extracted_text: asOptionalString(body.extractedText ?? body.extracted_text),
  extraction_confidence: asOptionalNumber(body.extractionConfidence ?? body.extraction_confidence),
  ...pickMeasurements(body)
});

export const createExternalProductSizeForUser = (
  userId: string,
  externalProductId: string,
  body: Record<string, unknown>
) => insertExternalProductSize(userId, externalProductId, toDto(body));

export const listExternalProductSizesForUser = (userId: string, externalProductId: string) =>
  selectExternalProductSizes(userId, externalProductId);

export const updateExternalProductSizeForUser = (
  userId: string,
  id: string,
  body: Record<string, unknown>
) => patchExternalProductSize(userId, id, toDto(body));

export const deleteExternalProductSizeForUser = (userId: string, id: string) =>
  removeExternalProductSize(userId, id);
