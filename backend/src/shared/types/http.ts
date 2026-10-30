import type { Request } from "express";

export interface AuthUser {
  id: string;
  email?: string;
  isAnonymous?: boolean;
}

export interface AuthenticatedRequest extends Request {
  user?: AuthUser;
}

export interface ApiError extends Error {
  statusCode?: number;
}

