import dotenv from "dotenv";

dotenv.config();

const required = (key: string): string => {
  const value = process.env[key];
  if (!value) {
    throw new Error(`Missing required environment variable: ${key}`);
  }
  return value;
};

export const env = {
  nodeEnv: process.env.NODE_ENV ?? "development",
  port: Number(process.env.PORT ?? 4000),
  supabaseUrl: required("SUPABASE_URL"),
  supabaseAnonKey: required("SUPABASE_ANON_KEY"),
  supabaseServiceRoleKey: required("SUPABASE_SERVICE_ROLE_KEY"),
  jwtSecret: process.env.JWT_SECRET ?? "local-dev-secret",
  anthropicApiKey: process.env.ANTHROPIC_API_KEY ?? null,
  ollamaGenerateUrl: process.env.OLLAMA_GENERATE_URL ?? "http://localhost:11434/api/generate",
  ollamaModel: process.env.OLLAMA_MODEL ?? "llama3.1:8b",
};
