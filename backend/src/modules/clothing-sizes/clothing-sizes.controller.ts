import type { NextFunction, Response } from "express";
import type { AuthenticatedRequest } from "../../shared/types/http";
import { asRequiredString, requireUser, sendCreated } from "../../shared/utils/request";
import {
  createClothingSizeForUser,
  deleteClothingSizeForUser,
  listClothingSizesForUser,
  updateClothingSizeForUser
} from "./clothing-sizes.service";

export const createClothingSize = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    sendCreated(
      res,
      await createClothingSizeForUser(
        requireUser(req).id,
        asRequiredString(req.params.id, "clothing item id"),
        req.body
      )
    );
  } catch (error) {
    next(error);
  }
};

export const listClothingSizes = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    res.json(await listClothingSizesForUser(requireUser(req).id, asRequiredString(req.params.id, "clothing item id")));
  } catch (error) {
    next(error);
  }
};

export const updateClothingSize = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    res.json(await updateClothingSizeForUser(requireUser(req).id, asRequiredString(req.params.id, "id"), req.body));
  } catch (error) {
    next(error);
  }
};

export const deleteClothingSize = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    await deleteClothingSizeForUser(requireUser(req).id, asRequiredString(req.params.id, "id"));
    res.status(204).send();
  } catch (error) {
    next(error);
  }
};
