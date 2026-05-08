"use client";

import { createContext, useContext, useEffect, useMemo, useState } from "react";
import { api, setApiToken } from "./api";
import type { AuthResponse } from "./types";

interface AuthContextValue {
  token: string | null;
  userEmail: string | null;
  login: (email: string, password: string) => Promise<void>;
  signup: (email: string, password: string) => Promise<void>;
  logout: () => void;
}

const AuthContext = createContext<AuthContextValue | null>(null);

const TOKEN_KEY = "coordit.accessToken";
const EMAIL_KEY = "coordit.userEmail";

export const AuthProvider = ({ children }: { children: React.ReactNode }) => {
  const [token, setToken] = useState<string | null>(null);
  const [userEmail, setUserEmail] = useState<string | null>(null);

  useEffect(() => {
    const storedToken = window.localStorage.getItem(TOKEN_KEY);
    const storedEmail = window.localStorage.getItem(EMAIL_KEY);
    setToken(storedToken);
    setUserEmail(storedEmail);
    setApiToken(storedToken);
  }, []);

  const commitAuth = (auth: AuthResponse) => {
    window.localStorage.setItem(TOKEN_KEY, auth.accessToken);
    window.localStorage.setItem(EMAIL_KEY, auth.user.email);
    setToken(auth.accessToken);
    setUserEmail(auth.user.email);
    setApiToken(auth.accessToken);
  };

  const value = useMemo<AuthContextValue>(
    () => ({
      token,
      userEmail,
      login: async (email, password) => {
        commitAuth(await api<AuthResponse>("/auth/login", { method: "POST", body: { email, password } }));
      },
      signup: async (email, password) => {
        commitAuth(await api<AuthResponse>("/auth/signup", { method: "POST", body: { email, password } }));
      },
      logout: () => {
        window.localStorage.removeItem(TOKEN_KEY);
        window.localStorage.removeItem(EMAIL_KEY);
        setToken(null);
        setUserEmail(null);
        setApiToken(null);
      }
    }),
    [token, userEmail]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};

export const useAuth = () => {
  const value = useContext(AuthContext);
  if (!value) throw new Error("useAuth must be used inside AuthProvider");
  return value;
};
