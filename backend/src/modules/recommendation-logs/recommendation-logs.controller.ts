import type { NextFunction, Response } from "express";
import type { AuthenticatedRequest } from "../../shared/types/http";
import { asRequiredString, requireUser } from "../../shared/utils/request";
import { listLogsForUser, markLogClicked, markLogPurchased } from "./recommendation-logs.service";

export const listRecommendationLogs = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    res.json(await listLogsForUser(requireUser(req).id));
  } catch (error) {
    next(error);
  }
};

export const markRecommendationClicked = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    res.json(await markLogClicked(requireUser(req).id, asRequiredString(req.params.id, "id")));
  } catch (error) {
    next(error);
  }
};

export const markRecommendationPurchased = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    res.json(await markLogPurchased(requireUser(req).id, asRequiredString(req.params.id, "id")));
  } catch (error) {
    next(error);
  }
};
