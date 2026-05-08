import axios from "axios";

const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:4000";

export const apiClient = axios.create({
  baseURL: API_BASE_URL,
  headers: { "Content-Type": "application/json" }
});

export const setApiToken = (token: string | null) => {
  if (token) {
    apiClient.defaults.headers.common.Authorization = `Bearer ${token}`;
  } else {
    delete apiClient.defaults.headers.common.Authorization;
  }
};

export const api = async <T>(path: string, options: { method?: string; body?: unknown } = {}): Promise<T> => {
  const response = await apiClient.request<T>({
    url: path,
    method: options.method ?? "GET",
    data: options.body
  });
  return response.data;
};
