import { ProductImportError } from "./product-import.error";
import type { ProductImportPreview, ProductSite } from "./product-import.types";

type ProductImportAttempt = {
  // Hostname only: share links carry per-user tracking parameters that must not reach logs.
  readonly host: string;
  readonly site: ProductSite;
  readonly startedAt: number;
};

const baseFields = (attempt: ProductImportAttempt) => ({
  message: "product_import_outcome",
  host: attempt.host,
  site: attempt.site,
  elapsedMs: Date.now() - attempt.startedAt
});

// One JSON line per attempt so Cloud Logging indexes the fields as jsonPayload.
export const logProductImportSuccess = (attempt: ProductImportAttempt, preview: ProductImportPreview): void => {
  console.info(JSON.stringify({
    severity: "INFO",
    ...baseFields(attempt),
    outcome: "succeeded",
    partial: preview.partial
  }));
};

export const logProductImportFailure = (attempt: ProductImportAttempt, error: unknown): void => {
  const failure = error instanceof ProductImportError
    ? { code: error.code, statusCode: error.statusCode, retryable: error.retryable }
    : { code: "UNEXPECTED", errorName: error instanceof Error ? error.name : typeof error };
  console.warn(JSON.stringify({
    severity: "WARNING",
    ...baseFields(attempt),
    outcome: "failed",
    ...failure
  }));
};
