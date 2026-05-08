import type { ErrorRequestHandler } from "express";

export const errorMiddleware: ErrorRequestHandler = (error, _req, res, _next) => {
  const statusCode = typeof error.statusCode === "number" ? error.statusCode : 500;
  res.status(statusCode).json({
    message: error.message ?? "Unexpected server error"
  });
};

