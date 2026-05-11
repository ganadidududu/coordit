import type { NextFunction, Response } from "express";
import type { AuthenticatedRequest } from "../../shared/types/http";
import { asRequiredString, requireUser, sendCreated } from "../../shared/utils/request";
import { supabase } from "../../config/supabase";
import type { ClosetItemContext } from "./styling.types";
import {
  createStylingLook,
  generateStylingLooks,
  listSavedStylingLooks,
  saveStylingLook,
} from "./styling.service";

interface ClothingItemRow {
  id: string;
  name: string;
  category: string;
  brand: string | null;
  size_label: string | null;
}

export const generateStylingController = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
) => {
  try {
    const user = requireUser(req);
    const prompt = asRequiredString(req.body.prompt, "prompt");

    const { data: items } = await supabase
      .from("clothing_items")
      .select("id, name, category, brand, size_label")
      .eq("user_id", user.id)
      .returns<ClothingItemRow[]>();

    const closetItems: ClosetItemContext[] = (items ?? []).map((i) => ({
      id: i.id,
      name: i.name,
      category: i.category,
      brand: i.brand,
      size_label: i.size_label,
    }));

    const result = await generateStylingLooks({ userId: user.id, prompt, closetItems });

    // Persist all generated looks so they can be individually saved later
    const savedLooks = await Promise.all(
      result.looks.map((look) => createStylingLook(user.id, look, prompt))
    );

    res.json({ looks: savedLooks, closetItems: result.closetItems });
  } catch (error) {
    next(error);
  }
};

export const listSavedStylingController = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
) => {
  try {
    const looks = await listSavedStylingLooks(requireUser(req).id);
    res.json(looks);
  } catch (error) {
    next(error);
  }
};

export const saveStylingLookController = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
) => {
  try {
    const user = requireUser(req);
    const id = asRequiredString(req.params.id, "id");
    const look = await saveStylingLook(user.id, id);
    sendCreated(res, look);
  } catch (error) {
    next(error);
  }
};
