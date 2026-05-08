import type { Response } from "express";
import type { AuthenticatedRequest, AuthUser } from "../types/http";
import { createHttpError } from "./http-error";

export const requireUser = (req: AuthenticatedRequest): AuthUser => {
  if (!req.user) {
    throw createHttpError(401, "Authentication is required");
  }
  return req.user;
};

export const sendCreated = <T>(res: Response, data: T): void => {
  res.status(201).json(data);
};

export const asOptionalString = (value: unknown): string | null => {
  if (typeof value === "string" && value.trim().length > 0) return value.trim();
  return null;
};

export const asRequiredString = (value: unknown, field: string): string => {
  const parsed = asOptionalString(value);
  if (!parsed) throw createHttpError(400, `${field} is required`);
  return parsed;
};

export const asOptionalNumber = (value: unknown): number | null => {
  if (value === null || value === undefined || value === "") return null;
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return null;
  return parsed;
};

export const asOptionalRecord = (value: unknown): Record<string, unknown> => {
  if (value && typeof value === "object" && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  return {};
};
