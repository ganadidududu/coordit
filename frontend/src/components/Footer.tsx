import { Logo } from "./Logo";

const LINKS = ["이용약관", "개인정보 처리방침", "지속가능성 리포트", "Fit Guide", "고객지원"];

export function Footer() {
  return (
    <footer style={{
      padding: "48px 48px 32px",
      borderTop: "1px solid var(--line)",
      background: "var(--bg-raised)",
      display: "flex", justifyContent: "space-between", alignItems: "flex-start",
      gap: 32, marginTop: 64,
    }}>
      <div>
        <Logo size={20} />
        <div style={{
          fontSize: 11, color: "var(--text-dim)", marginTop: 8,
          fontFamily: "JetBrains Mono, monospace", letterSpacing: "0.1em",
        }}>
          THE CURATED WARDROBE · EST. 2026
        </div>
      </div>
      <div style={{ display: "flex", gap: 32, fontSize: 12, color: "var(--text-muted)" }}>
        {LINKS.map(link => (
          <a key={link} style={{ color: "inherit", textDecoration: "none", cursor: "pointer" }}>
            {link}
          </a>
        ))}
      </div>
    </footer>
  );
}
