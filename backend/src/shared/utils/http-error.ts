import type { ApiError } from "../types/http";

export const createHttpError = (statusCode: number, message: string): ApiError => {
  const error = new Error(message) as ApiError;
  error.statusCode = statusCode;
  return error;
};

