"use client";

import { useState } from "react";
import type { FormEvent } from "react";
import { Button } from "../../components/Button";
import { FormSection } from "../../components/FormSection";
import { Input } from "../../components/Input";
import { Layout } from "../../components/Layout";
import { useAuth } from "../../lib/auth-context";

export default function LoginPage() {
  const { login, signup, userEmail, logout } = useAuth();
  const [mode, setMode] = useState<"login" | "signup">("login");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const submit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    setLoading(true);
    setError(null);
    try {
      const email = String(formData.get("email"));
      const password = String(formData.get("password"));
      if (mode === "login") await login(email, password);
      else await signup(email, password);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Authentication failed");
    } finally {
      setLoading(false);
    }
  };

  return (
    <Layout>
      <h1 className="text-3xl font-semibold">로그인 / 회원가입</h1>
      {userEmail ? (
        <div className="mt-6 rounded-md border border-line bg-white p-4 text-sm">
          <p className="font-medium">{userEmail}</p>
          <Button type="button" className="mt-3" onClick={logout}>Logout</Button>
        </div>
      ) : null}
      <form className="mt-8" onSubmit={submit}>
        <FormSection title="Account" description="Supabase Auth 세션으로 실제 API를 호출합니다.">
          <div className="flex gap-2">
            <Button type="button" onClick={() => setMode("login")}>Login</Button>
            <Button type="button" className="bg-white text-ink hover:bg-ink hover:text-white" onClick={() => setMode("signup")}>
              Sign up
            </Button>
          </div>
          <Input name="email" label="Email" type="email" placeholder="you@example.com" required />
          <Input name="password" label="Password" type="password" placeholder="8자 이상" required minLength={8} />
          <Button type="submit" disabled={loading}>{loading ? "Working..." : mode === "login" ? "Login" : "Create account"}</Button>
        </FormSection>
      </form>
      {error ? <p className="mt-4 text-sm text-red-600">{error}</p> : null}
    </Layout>
  );
}
