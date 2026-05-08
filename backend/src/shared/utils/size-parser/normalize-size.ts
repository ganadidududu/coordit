export const normalizeSizeLabel = (value: string): string =>
  value.trim().toUpperCase().replace(/\s+/g, "");

export const normalizeMeasurementValue = (value: string | number | null | undefined): number | null => {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (!value) return null;
  const numeric = Number(String(value).replace(/[^\d.]/g, ""));
  return Number.isFinite(numeric) ? numeric : null;
};
