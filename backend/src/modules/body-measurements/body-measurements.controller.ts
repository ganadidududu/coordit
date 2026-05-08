import type { NextFunction, Response } from "express";
import type { AuthenticatedRequest } from "../../shared/types/http";
import { requireUser, sendCreated } from "../../shared/utils/request";
import { createBodyMeasurementForUser, listBodyMeasurementsForUser } from "./body-measurements.service";

export const createBodyMeasurement = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    sendCreated(res, await createBodyMeasurementForUser(requireUser(req).id, req.body));
  } catch (error) {
    next(error);
  }
};

export const listBodyMeasurements = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    res.json(await listBodyMeasurementsForUser(requireUser(req).id));
  } catch (error) {
    next(error);
  }
};
