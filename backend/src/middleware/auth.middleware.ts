import type { NextFunction, Response } from "express";
import jwt from "jsonwebtoken";
import { env } from "../config/env";
import { supabase } from "../config/supabase";
import type { AuthenticatedRequest, AuthUser } from "../shared/types/http";
import { createHttpError } from "../shared/utils/http-error";

interface JwtPayload {
  sub?: string;
  email?: string;
}

export const authMiddleware = async (
  req: AuthenticatedRequest,
  _res: Response,
  next: NextFunction
) => {
  try {
    const header = req.headers.authorization;
    if (!header?.startsWith("Bearer ")) {
      throw createHttpError(401, "Missing bearer token");
    }

    const token = header.slice("Bearer ".length);
    const { data } = await supabase.auth.getUser(token);

    if (data.user) {
      req.user = { id: data.user.id, email: data.user.email };
      return next();
    }

    const decoded = jwt.verify(token, env.jwtSecret) as JwtPayload;
    if (!decoded.sub) {
      throw createHttpError(401, "Invalid token subject");
    }

    const user: AuthUser = { id: decoded.sub, email: decoded.email };
    req.user = user;
    return next();
  } catch (error) {
    return next(error instanceof Error ? error : createHttpError(401, "Unauthorized"));
  }
};

