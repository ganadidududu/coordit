export interface StylingLookRow {
  id: string;
  user_id: string;
  name: string;
  name_ko: string;
  mood: string;
  palette: string[];
  ai_reasoning: string;
  fit_score: number | null;
  item_ids: string[];
  prompt: string;
  created_at: string;
}

export interface GenerateStylingInput {
  userId: string;
  prompt: string;
  closetItems: ClosetItemContext[];
}

export interface ClosetItemContext {
  id: string;
  name: string;
  category: string;
  brand?: string | null;
  size_label?: string | null;
}

export interface GeneratedLook {
  name: string;
  name_ko: string;
  mood: string;
  palette: string[];
  ai_reasoning: string;
  fit_score: number;
  item_ids: string[];
}
