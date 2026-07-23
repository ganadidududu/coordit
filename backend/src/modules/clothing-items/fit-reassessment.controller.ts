import type { NextFunction, Response } from "express";
import type { AuthenticatedRequest } from "../../shared/types/http";
import { createHttpError } from "../../shared/utils/http-error";
import { asRequiredString, requireUser } from "../../shared/utils/request";
import { fitReassessmentService } from "./fit-reassessment.runtime";
import type { FitReassessmentService } from "./fit-reassessment.types";

type ReassessmentService = Pick<FitReassessmentService, "reassess">;

export const createReassessClothingItemFitController = (
  service: ReassessmentService
) => async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    res.status(201).json(await service.reassess(
      requireUser(req).id,
      asRequiredString(req.params.id, "clothing item id")
    ));
  } catch (error) {
    next(error instanceof Error ? error : createHttpError(500, "Unexpected reassessment error"));
  }
};

export const reassessClothingItemFit = createReassessClothingItemFitController(
  fitReassessmentService
);
