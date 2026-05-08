import type { NextFunction, Response } from "express";
import type { AuthenticatedRequest } from "../../shared/types/http";
import { asRequiredString, requireUser, sendCreated } from "../../shared/utils/request";
import {
  createExternalProductSizeForUser,
  deleteExternalProductSizeForUser,
  listExternalProductSizesForUser,
  updateExternalProductSizeForUser
} from "./external-product-sizes.service";

export const createExternalProductSize = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    sendCreated(
      res,
      await createExternalProductSizeForUser(
        requireUser(req).id,
        asRequiredString(req.params.id, "external product id"),
        req.body
      )
    );
  } catch (error) {
    next(error);
  }
};

export const listExternalProductSizes = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    res.json(await listExternalProductSizesForUser(requireUser(req).id, asRequiredString(req.params.id, "external product id")));
  } catch (error) {
    next(error);
  }
};

export const updateExternalProductSize = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    res.json(await updateExternalProductSizeForUser(requireUser(req).id, asRequiredString(req.params.id, "id"), req.body));
  } catch (error) {
    next(error);
  }
};

export const deleteExternalProductSize = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    await deleteExternalProductSizeForUser(requireUser(req).id, asRequiredString(req.params.id, "id"));
    res.status(204).send();
  } catch (error) {
    next(error);
  }
};
