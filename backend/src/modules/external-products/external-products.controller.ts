import type { NextFunction, Response } from "express";
import type { AuthenticatedRequest } from "../../shared/types/http";
import { asRequiredString, requireUser, sendCreated } from "../../shared/utils/request";
import {
  createExternalProductForUser,
  getExternalProductForUser,
  listExternalProductsForUser,
  mockExternalProductFromUrl,
  updateExternalProductForUser
} from "./external-products.service";

export const createExternalProduct = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    sendCreated(res, await createExternalProductForUser(requireUser(req).id, req.body));
  } catch (error) {
    next(error);
  }
};

export const listExternalProducts = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    res.json(await listExternalProductsForUser(requireUser(req).id));
  } catch (error) {
    next(error);
  }
};

export const getExternalProduct = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    res.json(await getExternalProductForUser(requireUser(req).id, asRequiredString(req.params.id, "id")));
  } catch (error) {
    next(error);
  }
};

export const updateExternalProduct = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    res.json(await updateExternalProductForUser(requireUser(req).id, asRequiredString(req.params.id, "id"), req.body));
  } catch (error) {
    next(error);
  }
};

export const createExternalProductFromUrl = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    requireUser(req);
    res.json(mockExternalProductFromUrl(asRequiredString(req.body.url, "url")));
  } catch (error) {
    next(error);
  }
};
