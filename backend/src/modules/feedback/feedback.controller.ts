import type { NextFunction, Response } from "express";
import type { AuthenticatedRequest } from "../../shared/types/http";
import { asRequiredString, requireUser, sendCreated } from "../../shared/utils/request";
import { createUserFeedback, listUserFeedback } from "./feedback.service";

export const createFeedback = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    sendCreated(
      res,
      await createUserFeedback(
        requireUser(req).id,
        asRequiredString(req.params.id, "fit analysis result id"),
        req.body
      )
    );
  } catch (error) {
    next(error);
  }
};

export const listFeedback = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    res.json(await listUserFeedback(requireUser(req).id));
  } catch (error) {
    next(error);
  }
};
