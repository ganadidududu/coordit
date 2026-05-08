import type { NextFunction, Response } from "express";
import type { AuthenticatedRequest } from "../../shared/types/http";
import { asRequiredString, requireUser } from "../../shared/utils/request";
import {
  getFitAnalysisResult,
  listRecentFitAnalysisResults,
  recommendFit,
  recommendFitBatch
} from "./fit.service";

export const recommendFitController = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
) => {
  try {
    const user = requireUser(req);

    const { referenceClothingId, referenceClothingIds, externalProductId } = req.body as {
      referenceClothingId?: string;
      referenceClothingIds?: string[];
      externalProductId?: string;
    };

    const result = await recommendFit({
      userId: user.id,
      referenceClothingId,
      referenceClothingIds,
      externalProductId: asRequiredString(externalProductId, "externalProductId")
    });

    res.status(201).json(result);
  } catch (error) {
    next(error);
  }
};

export const recommendFitBatchController = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
) => {
  try {
    const user = requireUser(req);
    const referenceClothingIds = Array.isArray(req.body.referenceClothingIds)
      ? req.body.referenceClothingIds.filter((id: unknown): id is string => typeof id === "string")
      : [];
    const externalProductIds = Array.isArray(req.body.externalProductIds)
      ? req.body.externalProductIds.filter((id: unknown): id is string => typeof id === "string")
      : [];

    const result = await recommendFitBatch(user.id, referenceClothingIds, externalProductIds);
    res.status(201).json({ results: result });
  } catch (error) {
    next(error);
  }
};

export const recentFitAnalysisResultsController = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
) => {
  try {
    res.json(await listRecentFitAnalysisResults(requireUser(req).id));
  } catch (error) {
    next(error);
  }
};

export const getFitAnalysisResultController = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
) => {
  try {
    res.json(await getFitAnalysisResult(requireUser(req).id, asRequiredString(req.params.id, "id")));
  } catch (error) {
    next(error);
  }
};
