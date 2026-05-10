"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { useAuth } from "../../lib/auth-context";

export default function LoginPage() {
  const router = useRouter();
  const { login, signup } = useAuth();
  const [mode, setMode] = useState<"login" | "register">("login");
  const [form, setForm] = useState({ email: "", password: "", name: "" });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const set = (k: keyof typeof form, v: string) => setForm(f => ({ ...f, [k]: v }));

  const submit = async () => {
    if (!form.email || !form.password) { setError("이메일과 비밀번호를 입력해주세요."); return; }
    setLoading(true); setError("");
    try {
      if (mode === "login") await login(form.email, form.password);
      else await signup(form.email, form.password);
      router.push("/closet");
    } catch (e) {
      setError(e instanceof Error ? e.message : "인증 오류가 발생했습니다.");
    } finally {
      setLoading(false);
    }
  };

  const inp = (k: keyof typeof form, placeholder: string, type = "text") => (
    <input
      type={type} placeholder={placeholder} value={form[k]}
      onChange={e => set(k, e.target.value)}
      onKeyDown={e => e.key === "Enter" && submit()}
      style={{ width: "100%", padding: "14px 16px", border: "1px solid var(--line-strong)", borderRadius: 4, background: "transparent", outline: "none", fontSize: 14, fontFamily: "var(--font-korean)", color: "var(--obsidian)" }}
    />
  );

  return (
    <main style={{ minHeight: "100vh", background: "var(--bg)", display: "flex", alignItems: "center", justifyContent: "center", padding: 24 }}>
      <div style={{ width: "100%", maxWidth: 440 }}>
        {/* Logo */}
        <div style={{ textAlign: "center", marginBottom: 48 }}>
          <img src="/logo.png" alt="Coordit" style={{ height: 52, width: "auto", display: "block", margin: "0 auto" }} />
          <div style={{ fontSize: 10, fontFamily: "JetBrains Mono, monospace", letterSpacing: "0.2em", color: "var(--text-muted)", marginTop: 8 }}>THE CURATED WARDROBE</div>
        </div>

        <div style={{ background: "var(--bg-raised)", border: "1px solid var(--line)", borderRadius: 4, padding: 40 }}>
          <div style={{ marginBottom: 28 }}>
            <h2 className="korean-serif" style={{ margin: 0, fontSize: 28, fontWeight: 500, fontFamily: "var(--font-korean-display)", letterSpacing: "-0.02em" }}>
              {mode === "login" ? "다시 만나요" : "큐레이션을 시작합니다"}
            </h2>
            <p style={{ margin: "8px 0 0", fontSize: 13, color: "var(--text-muted)", fontFamily: "var(--font-korean)" }}>
              {mode === "login" ? "옷장과 스타일 분석이 기다리고 있습니다." : "당신의 옷장을 AI가 큐레이션합니다."}
            </p>
          </div>

          <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
            {mode === "register" && inp("name", "이름 (선택)")}
            {inp("email", "이메일", "email")}
            {inp("password", "비밀번호", "password")}
          </div>

          {error && (
            <div style={{ marginTop: 12, padding: "10px 14px", background: "rgba(168,66,58,0.08)", border: "1px solid rgba(168,66,58,0.2)", borderRadius: 4, fontSize: 13, color: "var(--fit-tight)", fontFamily: "var(--font-korean)" }}>
              {error}
            </div>
          )}

          <button className="btn btn-primary" onClick={submit} disabled={loading} style={{ width: "100%", marginTop: 20, opacity: loading ? 0.7 : 1 }}>
            {loading ? "처리중..." : mode === "login" ? "로그인" : "계정 만들기"}
          </button>

          <div style={{ textAlign: "center", marginTop: 20, fontSize: 13, color: "var(--text-muted)", fontFamily: "var(--font-korean)" }}>
            {mode === "login" ? "계정이 없으신가요?" : "이미 계정이 있으신가요?"}{" "}
            <button onClick={() => { setMode(mode === "login" ? "register" : "login"); setError(""); }} style={{ background: "none", border: "none", color: "var(--walnut)", cursor: "pointer", fontSize: 13, fontFamily: "var(--font-korean)", textDecoration: "underline", padding: 0 }}>
              {mode === "login" ? "회원가입" : "로그인"}
            </button>
          </div>
        </div>

        <div style={{ textAlign: "center", marginTop: 16 }}>
          <button onClick={async () => {
            setLoading(true); setError("");
            try {
              try { await login("demo@coordit.com", "demo1234"); }
              catch { await signup("demo@coordit.com", "demo1234"); }
              router.push("/closet");
            } catch (e) { setError(e instanceof Error ? e.message : "오류"); }
            finally { setLoading(false); }
          }} style={{ fontSize: 11, fontFamily: "JetBrains Mono, monospace", letterSpacing: "0.1em", color: "var(--text-muted)", background: "none", border: "none", cursor: "pointer", textDecoration: "underline" }}>
            DEMO LOGIN
          </button>
        </div>
      </div>
    </main>
  );
}
