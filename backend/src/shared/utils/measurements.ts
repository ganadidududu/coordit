import type { MeasurementKey, MeasurementMap } from "../types/database";
import { asOptionalNumber } from "./request";

export const measurementKeys: MeasurementKey[] = [
  "total_length",
  "shoulder_width",
  "chest_width",
  "sleeve_length",
  "waist_width",
  "hip_width",
  "rise",
  "outseam"
];

export const pickMeasurements = (source: Record<string, unknown>): MeasurementMap =>
  measurementKeys.reduce<MeasurementMap>((measurements, key) => {
    const value = asOptionalNumber(source[key]);
    if (value !== null) measurements[key] = value;
    return measurements;
  }, {});

export const rowToMeasurements = (source: MeasurementMap): MeasurementMap =>
  measurementKeys.reduce<MeasurementMap>((measurements, key) => {
    const value = source[key];
    if (typeof value === "number" && Number.isFinite(value)) measurements[key] = value;
    return measurements;
  }, {});
