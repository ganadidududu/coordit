"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { Footer } from "../../components/Footer";
import { TopBar } from "../../components/TopBar";
import { api } from "../../lib/api";

// ─── Types ────────────────────────────────────────────────────────────
interface RawProductData {
  color?: string;
  is_favorite?: boolean;
  [key: string]: unknown;
}

interface ClothingItem {
  id: string;
  name: string;
  brand?: string;
  category: string;
  fit_type: string;
  size_label?: string;
  notes?: string;
  image_url?: string;
  raw_product_data?: RawProductData;
  created_at: string;
}

// ─── MiniStat ────────────────────────────────────────────────────────
function MiniStat({ label, value, unit, accent }: { label: string; value: string | number; unit?: string; accent?: string }) {
  return (
    <div>
      <div style={{ fontFamily: "var(--font-display)", fontSize: 24, fontWeight: 500, letterSpacing: "-0.02em", color: accent || "var(--obsidian)", lineHeight: 1 }}>
        {value}{unit && <span style={{ fontSize: 12, color: "var(--text-muted)", marginLeft: 2 }}>{unit}</span>}
      </div>
      <div style={{ fontSize: 10, color: "var(--text-muted)", marginTop: 6, fontFamily: "JetBrains Mono, monospace", letterSpacing: "0.1em", textTransform: "uppercase" }}>
        {label}
      </div>
    </div>
  );
}

// ─── ClosetCard ───────────────────────────────────────────────────────
function ClosetCard({ item, onFit, onFavorite, onDelete, favLoading }: {
  item: ClothingItem;
  onFit: () => void;
  onFavorite: () => void;
  onDelete: () => void;
  favLoading: boolean;
}) {
  const [hover, setHover] = useState(false);
  const isFav = item.raw_product_data?.is_favorite;
  const color = (item.raw_product_data?.color as string) || "#8F6F45";

  return (
    <div
      style={{ background: "var(--bg-raised)", border: isFav ? "1px solid var(--camel)" : "1px solid var(--line)", borderRadius: 4, overflow: "hidden", transition: "all 0.25s", transform: hover ? "translateY(-2px)" : "none", boxShadow: hover ? "0 12px 28px rgba(74,56,38,0.10)" : "none" }}
      onMouseEnter={() => setHover(true)} onMouseLeave={() => setHover(false)}
    >
      <div style={{ aspectRatio: "4/5", background: color, position: "relative", overflow: "hidden" }}>
        {item.image_url
          ? <img src={item.image_url} alt={item.name} style={{ position: "absolute", inset: 0, width: "100%", height: "100%", objectFit: "cover", filter: "grayscale(0.1) contrast(1.02)" }} />
          : <div style={{ position: "absolute", inset: 0, backgroundImage: "repeating-linear-gradient(135deg, rgba(255,255,255,0.04) 0 1px, transparent 1px 10px)", display: "flex", alignItems: "center", justifyContent: "center" }}>
              <span style={{ fontSize: 9, fontFamily: "JetBrains Mono, monospace", letterSpacing: "0.15em", color: "rgba(255,255,255,0.4)" }}>{item.category.toUpperCase()}</span>
            </div>
        }
        {item.notes && (
          <div style={{ position: "absolute", top: 14, left: 14, padding: "4px 10px", background: "rgba(245,240,230,0.92)", color: "var(--walnut)", fontSize: 9, fontFamily: "JetBrains Mono, monospace", letterSpacing: "0.12em", borderRadius: 2 }}>
            {item.notes.toUpperCase()}
          </div>
        )}
        <div style={{ position: "absolute", top: 14, right: 14, display: "flex", gap: 6 }}>
          <button
            onClick={e => { e.stopPropagation(); onFavorite(); }}
            disabled={favLoading}
            style={{ width: 28, height: 28, borderRadius: "50%", background: "rgba(13,12,11,0.55)", border: "none", cursor: favLoading ? "default" : "pointer", color: isFav ? "#D4B896" : "rgba(245,240,230,0.6)", fontSize: 12, opacity: favLoading ? 0.5 : 1 }}
          >
            {isFav ? "♥" : "♡"}
          </button>
          <button onClick={e => { e.stopPropagation(); onDelete(); }} style={{ width: 28, height: 28, borderRadius: "50%", background: "rgba(13,12,11,0.55)", border: "none", cursor: "pointer", color: "rgba(245,240,230,0.6)", fontSize: 10 }}>
            ✕
          </button>
        </div>
        <div style={{ position: "absolute", bottom: 12, left: 14, padding: "4px 8px", background: "rgba(13,12,11,0.55)", backdropFilter: "blur(8px)", color: "var(--ivory)", fontSize: 10, fontFamily: "JetBrains Mono, monospace", letterSpacing: "0.15em", borderRadius: 2 }}>
          {item.size_label || "M"} · #{item.id?.slice(-3).toUpperCase() ?? "---"}
        </div>
      </div>
      <div style={{ padding: "14px 16px" }}>
        <div className="korean-sans" style={{ fontSize: 14, fontWeight: 500 }}>{item.name}</div>
        <div className="korean-sans" style={{ fontSize: 11, color: "var(--text-muted)", marginTop: 2 }}>
          {item.category}{item.brand ? ` · ${item.brand}` : ""}
        </div>
        <div style={{ marginTop: 10 }}>
          <button onClick={onFit} style={{ width: "100%", padding: "7px 0", background: "var(--linen)", border: "none", borderRadius: 2, fontSize: 10, fontFamily: "JetBrains Mono, monospace", letterSpacing: "0.08em", color: "var(--walnut)", cursor: "pointer" }}>
            핏 분석
          </button>
        </div>
      </div>
    </div>
  );
}

// ─── AddItemModal ─────────────────────────────────────────────────────
function AddItemModal({ onClose, onSaved }: { onClose: () => void; onSaved: () => void }) {
  const [form, setForm] = useState({ name: "", brand: "", category: "상의", notes: "", size_label: "M", color: "#8F6F45", image_url: "", garment_shoulder: "", garment_chest: "", garment_waist: "", garment_length: "" });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const set = (k: keyof typeof form, v: string) => setForm(f => ({ ...f, [k]: v }));

  const save = async () => {
    if (!form.name) { setError("이름을 입력해주세요."); return; }
    setLoading(true); setError("");
    try {
      const sizeEntries: [string, number][] = [
        ["shoulder_width", parseFloat(form.garment_shoulder)],
        ["chest_width",    parseFloat(form.garment_chest)],
        ["waist_width",    parseFloat(form.garment_waist)],
        ["total_length",   parseFloat(form.garment_length)],
      ].filter(([, v]) => Number.isFinite(v)) as [string, number][];

      const item = await api<{ id: string }>("/clothing-items", {
        method: "POST",
        body: {
          name: form.name,
          brand: form.brand || undefined,
          category: form.category,
          notes: form.notes || undefined,
          size_label: form.size_label,
          image_url: /^https?:\/\//.test(form.image_url) ? form.image_url : undefined,
          raw_product_data: { color: form.color },
        },
      });

      if (sizeEntries.length > 0) {
        try {
          await api(`/clothing-items/${item.id}/sizes`, { method: "POST", body: { size_label: form.size_label, ...Object.fromEntries(sizeEntries) } });
        } catch {
          // Item saved but sizes failed — not fatal, show warning
          setError("아이템은 저장되었지만 사이즈 등록에 실패했습니다.");
          onSaved();
          return;
        }
      }

      onSaved();
    } catch (e) {
      setError(e instanceof Error ? e.message : "저장 오류가 발생했습니다.");
    } finally {
      setLoading(false);
    }
  };

  const inp = (k: keyof typeof form, label: string, type = "text", placeholder = "") => (
    <div key={k}>
      <div style={{ fontSize: 11, color: "var(--text-muted)", marginBottom: 4, fontFamily: "JetBrains Mono, monospace", letterSpacing: "0.08em" }}>{label}</div>
      <input type={type} value={form[k]} onChange={e => set(k, e.target.value)} placeholder={placeholder}
        style={{ width: "100%", padding: "10px 12px", border: "1px solid var(--line-strong)", borderRadius: 4, background: "transparent", outline: "none", fontSize: 14, fontFamily: "var(--font-korean)", color: "var(--obsidian)" }} />
    </div>
  );

  return (
    <div style={{ position: "fixed", inset: 0, background: "rgba(28,27,26,0.7)", zIndex: 10000, display: "flex", alignItems: "center", justifyContent: "center", padding: 24 }}>
      <div style={{ background: "var(--bg)", borderRadius: 4, width: "100%", maxWidth: 640, padding: 40, maxHeight: "90vh", overflowY: "auto" }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 28 }}>
          <h2 className="korean-serif" style={{ margin: 0, fontSize: 28, fontWeight: 500, fontFamily: "var(--font-korean-display)" }}>새 의류 등록</h2>
          <button onClick={onClose} style={{ background: "none", border: "none", fontSize: 20, cursor: "pointer", color: "var(--text-muted)" }}>✕</button>
        </div>

        <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
          {/* 이미지 URL */}
          <div>
            <div style={{ fontSize: 11, color: "var(--text-muted)", marginBottom: 8, fontFamily: "JetBrains Mono, monospace", letterSpacing: "0.08em" }}>의류 이미지 URL (선택)</div>
            {form.image_url && /^https?:\/\//.test(form.image_url) && (
              <div style={{ width: "100%", aspectRatio: "4/3", maxHeight: 200, borderRadius: 4, overflow: "hidden", marginBottom: 8, position: "relative" }}>
                <img src={form.image_url} alt="미리보기" style={{ width: "100%", height: "100%", objectFit: "cover" }} />
              </div>
            )}
            <input type="text" value={form.image_url} onChange={e => set("image_url", e.target.value)} placeholder="https://example.com/image.jpg"
              style={{ width: "100%", padding: "10px 12px", border: "1px solid var(--line-strong)", borderRadius: 4, background: "transparent", outline: "none", fontSize: 13, fontFamily: "var(--font-korean)", color: "var(--obsidian)" }} />
          </div>

          {inp("name", "의류명", "text", "예: 헤리티지 카멜 코트")}
          {inp("brand", "브랜드 (선택)", "text", "예: COS, Uniqlo")}

          <div>
            <div style={{ fontSize: 11, color: "var(--text-muted)", marginBottom: 4, fontFamily: "JetBrains Mono, monospace", letterSpacing: "0.08em" }}>카테고리</div>
            <select value={form.category} onChange={e => set("category", e.target.value)} style={{ width: "100%", padding: "10px 12px", border: "1px solid var(--line-strong)", borderRadius: 4, background: "var(--bg)", fontSize: 14, color: "var(--obsidian)" }}>
              {["상의", "하의", "아우터", "원피스", "액세서리"].map(c => <option key={c} value={c}>{c}</option>)}
            </select>
          </div>

          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }}>
            {inp("notes", "소재", "text", "Wool, Cotton, Cashmere...")}
            {inp("size_label", "사이즈", "text", "XS / S / M / L / XL")}
          </div>

          <div>
            <div style={{ fontSize: 11, color: "var(--text-muted)", marginBottom: 4, fontFamily: "JetBrains Mono, monospace", letterSpacing: "0.08em" }}>대표 색상</div>
            <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
              <input type="color" value={form.color} onChange={e => set("color", e.target.value)} style={{ width: 44, height: 44, border: "1px solid var(--line-strong)", borderRadius: 4, cursor: "pointer", padding: 2 }} />
              <span style={{ fontSize: 12, fontFamily: "JetBrains Mono, monospace", color: "var(--text-muted)" }}>{form.color}</span>
            </div>
          </div>

          <div style={{ borderTop: "1px solid var(--line)", paddingTop: 16 }}>
            <div style={{ fontSize: 11, color: "var(--text-muted)", marginBottom: 12, fontFamily: "JetBrains Mono, monospace", letterSpacing: "0.08em" }}>실측 사이즈 (선택 — 핏 분석에 활용)</div>
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }}>
              {inp("garment_shoulder", "어깨 (cm)", "number", "43.0")}
              {inp("garment_chest", "가슴 너비 (cm)", "number", "55")}
              {inp("garment_waist", "허리 너비 (cm)", "number", "48")}
              {inp("garment_length", "총장 (cm)", "number", "70")}
            </div>
          </div>
        </div>

        {error && <div style={{ marginTop: 16, padding: "10px 14px", background: "rgba(168,66,58,0.08)", border: "1px solid rgba(168,66,58,0.2)", borderRadius: 4, fontSize: 13, color: "var(--fit-tight)", fontFamily: "var(--font-korean)" }}>{error}</div>}

        <div style={{ display: "flex", gap: 10, marginTop: 28 }}>
          <button className="btn btn-secondary" onClick={onClose} style={{ flex: 1 }}>취소</button>
          <button className="btn btn-primary" onClick={save} disabled={loading} style={{ flex: 2, opacity: loading ? 0.7 : 1 }}>
            {loading ? "저장중..." : "등록하기"}
          </button>
        </div>
      </div>
    </div>
  );
}

// ─── Closet Page ──────────────────────────────────────────────────────
const FILTERS = ["전체", "상의", "하의", "아우터", "원피스", "액세서리"];

export default function ClosetPage() {
  const router = useRouter();
  const [filter, setFilter] = useState("전체");
  const [items, setItems] = useState<ClothingItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [showAddModal, setShowAddModal] = useState(false);
  const [favLoadingId, setFavLoadingId] = useState<string | null>(null);
  const [actionError, setActionError] = useState("");

  const loadItems = useCallback(async () => {
    try {
      setLoading(true);
      const data = await api<ClothingItem[]>("/clothing-items");
      setItems(Array.isArray(data) ? data : []);
    } catch {
      setItems([]);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { loadItems(); }, [loadItems]);

  const filtered = useMemo(
    () => filter === "전체" ? items : items.filter(i => i.category === filter),
    [items, filter]
  );

  const stats = useMemo(() => {
    const totalItems = items.length;
    const tally = new Map<string, number>();
    for (const item of items) tally.set(item.category, (tally.get(item.category) ?? 0) + 1);
    let topCategory = "-";
    let topCount = 0;
    for (const [cat, count] of tally) { if (count > topCount) { topCategory = cat; topCount = count; } }
    const favorites = items.filter(i => i.raw_product_data?.is_favorite).length;
    return { totalItems, topCategory, favorites };
  }, [items]);

  const handleFavorite = async (item: ClothingItem) => {
    if (favLoadingId) return;
    const isFav = item.raw_product_data?.is_favorite;
    // Optimistic update
    setItems(prev => prev.map(i => i.id === item.id
      ? { ...i, raw_product_data: { ...i.raw_product_data, is_favorite: !isFav } }
      : i
    ));
    setFavLoadingId(item.id);
    try {
      await api(`/clothing-items/${item.id}`, {
        method: "PATCH",
        body: { raw_product_data: { ...(item.raw_product_data ?? {}), is_favorite: !isFav } },
      });
    } catch (e) {
      // Revert on failure
      setItems(prev => prev.map(i => i.id === item.id
        ? { ...i, raw_product_data: { ...i.raw_product_data, is_favorite: isFav } }
        : i
      ));
      setActionError(e instanceof Error ? e.message : "즐겨찾기 변경에 실패했습니다.");
    } finally {
      setFavLoadingId(null);
    }
  };

  const handleDelete = async (id: string) => {
    if (!confirm("이 아이템을 삭제하시겠습니까?")) return;
    try {
      await api(`/clothing-items/${id}`, { method: "DELETE" });
      setItems(prev => prev.filter(i => i.id !== id));
    } catch (e) {
      setActionError(e instanceof Error ? e.message : "삭제에 실패했습니다.");
    }
  };

  return (
    <main>
      <TopBar />
      {showAddModal && <AddItemModal onClose={() => setShowAddModal(false)} onSaved={() => { setShowAddModal(false); loadItems(); }} />}

      <section style={{ padding: "56px 48px 0", maxWidth: 1600, margin: "0 auto" }}>
        <div className="eyebrow" style={{ marginBottom: 24 }}>HOME / CLOSET / ALL</div>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-end", marginBottom: 40 }}>
          <div>
            <h1 className="korean-serif" style={{ margin: 0, fontSize: 72, fontWeight: 400, letterSpacing: "-0.03em", lineHeight: 1, fontFamily: "var(--font-korean-display)" }}>
              나의 <span style={{ fontFamily: "var(--font-display)", fontStyle: "italic", color: "var(--walnut)" }}>옷장</span>
            </h1>
            <div className="korean-sans" style={{ fontSize: 14, color: "var(--text-muted)", marginTop: 12 }}>
              총 <span style={{ color: "var(--walnut)", fontWeight: 500 }}>{stats.totalItems}</span>개의 아이템
            </div>
          </div>
          <div style={{ display: "flex", gap: 10 }}>
            <button className="btn btn-secondary" onClick={() => router.push("/onboarding")}>핏 프로필</button>
            <button className="btn btn-primary" onClick={() => setShowAddModal(true)}>+ 새 의류 등록</button>
          </div>
        </div>

        {actionError && (
          <div style={{ marginBottom: 16, padding: "10px 14px", background: "rgba(168,66,58,0.08)", border: "1px solid rgba(168,66,58,0.2)", borderRadius: 4, fontSize: 13, color: "var(--fit-tight)", fontFamily: "var(--font-korean)", display: "flex", justifyContent: "space-between" }}>
            {actionError}
            <button onClick={() => setActionError("")} style={{ background: "none", border: "none", cursor: "pointer", fontSize: 12, color: "var(--text-muted)" }}>✕</button>
          </div>
        )}

        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "20px 0", borderTop: "1px solid var(--line)", borderBottom: "1px solid var(--line)" }}>
          <div style={{ display: "flex", gap: 8 }}>
            {FILTERS.map(f => (
              <button key={f} onClick={() => setFilter(f)}
                style={{ padding: "8px 18px", borderRadius: 999, border: filter === f ? "1px solid var(--obsidian)" : "1px solid var(--line-strong)", background: filter === f ? "var(--obsidian)" : "transparent", color: filter === f ? "var(--ivory)" : "var(--obsidian)", fontSize: 12, letterSpacing: "0.02em", fontFamily: "var(--font-korean)", cursor: "pointer", transition: "all 0.2s" }}>
                {f}
              </button>
            ))}
          </div>
          <div style={{ fontSize: 12, color: "var(--text-muted)", fontFamily: "JetBrains Mono, monospace", letterSpacing: "0.08em" }}>
            {filtered.length}개 표시중
          </div>
        </div>
      </section>

      <section style={{ padding: "40px 48px 80px", maxWidth: 1600, margin: "0 auto", display: "grid", gridTemplateColumns: "1fr 340px", gap: 40 }}>
        <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: 20, alignContent: "start" }}>
          {loading
            ? Array(6).fill(0).map((_, i) => <div key={i} style={{ aspectRatio: "4/5", background: "var(--linen)", borderRadius: 4 }} />)
            : filtered.length === 0
              ? (
                <div style={{ gridColumn: "1 / -1", textAlign: "center", padding: "80px 0", color: "var(--text-muted)" }}>
                  <div style={{ fontFamily: "var(--font-display)", fontStyle: "italic", fontSize: 36, marginBottom: 12 }}>—</div>
                  <div className="korean-sans" style={{ fontSize: 14 }}>
                    {filter === "전체" ? "아직 등록된 의류가 없습니다." : `${filter} 카테고리에 등록된 의류가 없습니다.`}
                  </div>
                  <button className="btn btn-primary" onClick={() => setShowAddModal(true)} style={{ marginTop: 20 }}>첫 의류 등록하기</button>
                </div>
              )
              : filtered.map(item => (
                  <ClosetCard
                    key={item.id}
                    item={item}
                    onFit={() => router.push("/fit")}
                    onFavorite={() => handleFavorite(item)}
                    onDelete={() => handleDelete(item.id)}
                    favLoading={favLoadingId === item.id}
                  />
                ))
          }
          {/* Add new item card — only show when not loading and not empty */}
          {!loading && (
            <div
              style={{ border: "1px dashed var(--line-strong)", borderRadius: 4, minHeight: 440, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 12, cursor: "pointer", color: "var(--text-muted)", transition: "all 0.2s" }}
              onMouseEnter={e => { (e.currentTarget as HTMLElement).style.borderColor = "var(--walnut)"; (e.currentTarget as HTMLElement).style.color = "var(--walnut)"; }}
              onMouseLeave={e => { (e.currentTarget as HTMLElement).style.borderColor = "var(--line-strong)"; (e.currentTarget as HTMLElement).style.color = "var(--text-muted)"; }}
              onClick={() => setShowAddModal(true)}
            >
              <div style={{ fontSize: 28, fontFamily: "var(--font-display)", fontStyle: "italic" }}>+</div>
              <div className="korean-sans" style={{ fontSize: 13 }}>새 의류 등록</div>
              <div style={{ fontSize: 10, fontFamily: "JetBrains Mono, monospace", letterSpacing: "0.1em", opacity: 0.6 }}>PHOTO · URL · SCAN</div>
            </div>
          )}
        </div>

        <aside style={{ display: "flex", flexDirection: "column", gap: 20, position: "sticky", top: 100, alignSelf: "flex-start" }}>
          {/* AI Today's Edit */}
          <div style={{ background: "var(--obsidian)", color: "var(--ivory)", padding: 24, borderRadius: 4 }}>
            <div style={{ fontSize: 10, fontFamily: "JetBrains Mono, monospace", letterSpacing: "0.15em", opacity: 0.6 }}>COORDIT AI</div>
            <div style={{ fontFamily: "var(--font-display)", fontStyle: "italic", fontSize: 28, marginTop: 8, fontWeight: 500 }}>Today's Edit</div>
            <p className="korean-sans" style={{ margin: "16px 0 20px", fontSize: 13, lineHeight: 1.6, opacity: 0.85 }}>
              옷장의 아이템들로 오늘의 코디를 AI가 자동 큐레이션합니다.
            </p>
            <button className="btn btn-camel" style={{ width: "100%" }} onClick={() => router.push("/styling")}>
              오늘의 코디 추천 →
            </button>
          </div>

          {/* Wardrobe stats */}
          <div style={{ background: "var(--bg-raised)", border: "1px solid var(--line)", padding: 24, borderRadius: 4 }}>
            <div style={{ fontSize: 10, fontFamily: "JetBrains Mono, monospace", letterSpacing: "0.15em", color: "var(--text-muted)" }}>WARDROBE DOSSIER</div>
            <div className="korean-serif" style={{ fontSize: 20, marginTop: 8, fontWeight: 500, fontFamily: "var(--font-korean-display)" }}>스타일 데이터</div>
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12, marginTop: 20 }}>
              <MiniStat label="총 아이템" value={stats.totalItems} />
              <MiniStat label="주요 카테고리" value={stats.topCategory} />
              <MiniStat label="핏 분석" value="AI" unit=" ✓" accent="var(--fit-perfect)" />
              <MiniStat label="즐겨찾기" value={stats.favorites} />
            </div>
          </div>

          {/* FitLab CTA */}
          <div style={{ background: "var(--linen)", border: "1px solid var(--line)", padding: 20, borderRadius: 4 }}>
            <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
              <span style={{ fontSize: 14 }}>✦</span>
              <div className="korean-serif" style={{ fontSize: 16, fontWeight: 500, fontFamily: "var(--font-korean-display)" }}>핏 분석</div>
            </div>
            <p className="korean-sans" style={{ margin: "10px 0", fontSize: 12, lineHeight: 1.6, color: "var(--text-muted)" }}>
              실측 체형 기반 AI 핏 분석으로 어떤 옷이 얼마나 잘 맞는지 확인하세요.
            </p>
            <button className="btn btn-secondary" style={{ width: "100%", fontSize: 12, padding: "10px" }} onClick={() => router.push("/fit")}>
              핏 분석 시작 →
            </button>
          </div>
        </aside>
      </section>
      <Footer />
    </main>
  );
}
