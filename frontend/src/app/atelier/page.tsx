"use client";

import { Footer } from "../../components/Footer";
import { TopBar } from "../../components/TopBar";
import { IMG } from "../../lib/images";

// ─── Data ─────────────────────────────────────────────────────────────

interface Look {
  name: string;
  kr:   string;
  img:  string;
  vol:  string;
  mood: string;
  ratio: string;
}

const LOOKS: Look[] = [
  { name: "Morning Ritual", kr: "기록된 아침",      img: IMG.look1, vol: "VOL.01", mood: "Quiet Morning",  ratio: "3/4"  },
  { name: "Galerie Hours",  kr: "갤러리 시간",      img: IMG.look2, vol: "VOL.02", mood: "Curator Mode",   ratio: "2/3"  },
  { name: "Soft Machine",   kr: "부드러운 기계",    img: IMG.look3, vol: "VOL.03", mood: "Urban Tech",     ratio: "4/5"  },
  { name: "Weekend Essai",  kr: "주말의 에세이",    img: IMG.look4, vol: "VOL.04", mood: "Loose Tailor",   ratio: "3/5"  },
  { name: "Tokyo Drift",    kr: "도쿄의 드리프트", img: IMG.look5, vol: "VOL.05", mood: "Night Edit",     ratio: "5/7"  },
  { name: "Quiet Luxury",   kr: "조용한 럭셔리",   img: IMG.look6, vol: "VOL.06", mood: "Cashmere Hour",  ratio: "7/10" },
];

// Left-to-right Pinterest masonry: 3 flex columns
const COLS = ([0, 1, 2] as const).map(ci => LOOKS.filter((_, i) => i % 3 === ci));

// ─── LookCard — dev branch card DNA + masonry ratio ───────────────────

function LookCard({ look: l }: { look: Look }) {
  return (
    <div style={{
      background: "var(--bg-raised)",
      border: "1px solid var(--line)",
      borderRadius: 4,
      overflow: "hidden",
      cursor: "pointer",
    }}>
      {/* Image */}
      <div style={{ aspectRatio: l.ratio, background: "#2a2623", position: "relative", overflow: "hidden" }}>
        <img
          src={l.img}
          alt={`${l.name} — ${l.mood}`}
          style={{ position: "absolute", inset: 0, width: "100%", height: "100%", objectFit: "cover", filter: "grayscale(0.1) contrast(1.02)" }}
        />
        <div style={{
          position: "absolute",
          top: 14, left: 14,
          padding: "3px 8px",
          background: "rgba(13,12,11,0.55)",
          backdropFilter: "blur(6px)",
          color: "var(--ivory)",
          fontSize: 9,
          fontFamily: "JetBrains Mono, monospace",
          letterSpacing: "0.14em",
          borderRadius: 2,
        }}>
          {l.vol} · 2026
        </div>
        <div style={{ position: "absolute", bottom: 18, left: 18, right: 18 }}>
          <div style={{
            fontFamily: "var(--font-display)",
            fontStyle: "italic",
            fontSize: 14,
            color: "var(--camel-soft)",
            fontWeight: 500,
            letterSpacing: "0.02em",
            textShadow: "0 1px 6px rgba(0,0,0,0.6)",
          }}>
            — {l.mood}
          </div>
        </div>
      </div>

      {/* Info — dev branch bottom section */}
      <div style={{ padding: "20px 24px", display: "flex", justifyContent: "space-between", alignItems: "flex-end" }}>
        <div>
          <div style={{
            fontFamily: "var(--font-display)",
            fontStyle: "italic",
            fontSize: 26,
            fontWeight: 500,
            letterSpacing: "-0.01em",
          }}>
            {l.name}
          </div>
          <div className="korean-sans" style={{ fontSize: 13, color: "var(--text-muted)", marginTop: 2 }}>
            {l.kr}
          </div>
        </div>
        <div style={{ fontSize: 20 }}>→</div>
      </div>
    </div>
  );
}

// ─── Page ─────────────────────────────────────────────────────────────

export default function AtelierPage() {
  return (
    <main>
      <TopBar />

      <section style={{ padding: "48px 48px 0", maxWidth: 1600, margin: "0 auto" }}>
        <div className="eyebrow">THE ATELIER · EDITORIAL ARCHIVE</div>
        <h1 className="korean-serif" style={{
          margin: "16px 0 40px",
          fontSize: 88,
          fontWeight: 400,
          letterSpacing: "-0.035em",
          lineHeight: 0.95,
          fontFamily: "var(--font-korean-display)",
        }}>
          <span style={{ fontFamily: "var(--font-display)", fontStyle: "italic", color: "var(--walnut)" }}>Atelier</span>,<br />
          큐레이터가 모은 옷들.
        </h1>

        {/* Pinterest masonry: 3 flex columns, varied aspect ratios */}
        <div style={{ display: "flex", gap: 20, alignItems: "flex-start" }}>
          {COLS.map((col, ci) => (
            <div key={ci} style={{ flex: 1, display: "flex", flexDirection: "column", gap: 20 }}>
              {col.map(l => (
                <LookCard key={l.vol} look={l} />
              ))}
            </div>
          ))}
        </div>
      </section>

      <Footer />
    </main>
  );
}
