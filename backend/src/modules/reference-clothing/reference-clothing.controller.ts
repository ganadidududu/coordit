import type { NextFunction, Response } from "express";
import type { AuthenticatedRequest } from "../../shared/types/http";
import type { Category } from "../../shared/types/database";
import { asRequiredString, requireUser, sendCreated } from "../../shared/utils/request";
import {
  createReferenceClothingForUser,
  deactivateReferenceClothingForUser,
  getReferenceClothingForUser,
  listReferenceClothingByCategoryForUser,
  listReferenceClothingForUser,
  updateReferenceClothingForUser
} from "./reference-clothing.service";

export const createReferenceClothing = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    sendCreated(res, await createReferenceClothingForUser(requireUser(req).id, req.body));
  } catch (error) {
    next(error);
  }
};

export const listReferenceClothing = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    res.json(await listReferenceClothingForUser(requireUser(req).id));
  } catch (error) {
    next(error);
  }
};

export const getReferenceClothingByCategory = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    res.json(
      await listReferenceClothingByCategoryForUser(
        requireUser(req).id,
        asRequiredString(req.params.category, "category") as Category
      )
    );
  } catch (error) {
    next(error);
  }
};

export const getReferenceClothing = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    res.json(await getReferenceClothingForUser(requireUser(req).id, asRequiredString(req.params.id, "id")));
  } catch (error) {
    next(error);
  }
};

export const updateReferenceClothing = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    res.json(await updateReferenceClothingForUser(requireUser(req).id, asRequiredString(req.params.id, "id"), req.body));
  } catch (error) {
    next(error);
  }
};

export const deactivateReferenceClothing = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    res.json(await deactivateReferenceClothingForUser(requireUser(req).id, asRequiredString(req.params.id, "id")));
  } catch (error) {
    next(error);
  }
};
