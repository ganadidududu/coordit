import type { NextFunction, Request, Response } from "express";
import { asRequiredString } from "../../shared/utils/request";
import { loginWithEmail, signupWithEmail } from "./auth.service";

export const signup = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const email = asRequiredString(req.body.email, "email");
    const password = asRequiredString(req.body.password, "password");
    res.status(201).json(await signupWithEmail(email, password));
  } catch (error) {
    next(error);
  }
};

export const login = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const email = asRequiredString(req.body.email, "email");
    const password = asRequiredString(req.body.password, "password");
    res.json(await loginWithEmail(email, password));
  } catch (error) {
    next(error);
  }
};
