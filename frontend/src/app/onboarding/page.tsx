"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { Footer } from "../../components/Footer";
import { TopBar } from "../../components/TopBar";
import { api } from "../../lib/api";

// ─── Step 2: Measurements ────────────────────────────────────────────
function StepMeasurements({ onNext, onPrev }: { onNext: () => void; onPrev: () => void }) {
  const [values, setValues] = useState({ height: 172, weight: 62, shoulder: 44.5, chest: 98, waist: 82, hip: 96, inseam: 80 });
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState("");

  useEffect(() => {
    api<Array<{ height_cm?: number; weight_kg?: number; shoulder_width?: number; chest_circumference?: number; waist_circumference?: number; hip_circumference?: number; inseam?: number }>>("/body-measurements")
      .then(list => {
        const m = Array.isArray(list) ? list[0] : null;
        if (m?.height_cm) setValues(v => ({ ...v, height: m.height_cm ?? v.height, weight: m.weight_kg ?? v.weight, shoulder: m.shoulder_width ?? v.shoulder, chest: m.chest_circumference ?? v.chest, waist: m.waist_circumference ?? v.waist, hip: m.hip_circumference ?? v.hip, inseam: m.inseam ?? v.inseam }));
      })
      .catch(() => {});
  }, []);

  const save = async () => {
    setSaving(true); setSaveError("");
    try {
      await api("/body-measurements", { method: "POST", body: { height_cm: values.height, weight_kg: values.weight, shoulder_width: values.shoulder, chest_circumference: values.chest, waist_circumference: values.waist, hip_circumference: values.hip, inseam: values.inseam } });
      onNext();
    } catch (e) {
      setSaveError(e instanceof Error ? e.message : "저장 오류가 발생했습니다.");
    } finally { setSaving(false); }
  };

  const FIELDS = [
    { k: "height" as const,   label: "키",         unit: "cm", min: 140, max: 200, step: 1   },
    { k: "weight" as const,   label: "몸무게",     unit: "kg", min: 40,  max: 120, step: 0.5 },
    { k: "shoulder" as const, label: "어깨 너비",  unit: "cm", min: 30,  max: 60,  step: 0.5 },
    { k: "chest" as const,    label: "가슴 둘레",  unit: "cm", min: 70,  max: 130, step: 1   },
    { k: "waist" as const,    label: "허리 둘레",  unit: "cm", min: 60,  max: 110, step: 1   },
  ];

  return (
    <div style={{ background: "var(--bg-raised)", border: "1px solid var(--line)", borderRadius: 4, padding: 48, display: "grid", gridTemplateColumns: "1.2fr 1fr", gap: 48 }}>
      <div>
        <div className="korean-serif" style={{ fontSize: 32, fontWeight: 500, letterSpacing: "-0.02em", fontFamily: "var(--font-korean-display)" }}>신체를 수치로 담습니다</div>
        <p className="korean-sans" style={{ fontSize: 13, color: "var(--text-muted)", marginTop: 12, lineHeight: 1.7 }}>
          측정이 정밀할수록 핏 예측이 정밀해집니다.
        </p>
        <div style={{ marginTop: 32, display: "flex", flexDirection: "column", gap: 20 }}>
          {FIELDS.map(f => (
            <div key={f.k}>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", marginBottom: 6 }}>
                <span className="korean-sans" style={{ fontSize: 13 }}>{f.label}</span>
                <span style={{ fontFamily: "var(--font-display)", fontSize: 22, fontWeight: 500, letterSpacing: "-0.02em" }}>
                  {values[f.k]}<span style={{ fontSize: 12, color: "var(--text-muted)", marginLeft: 4 }}>{f.unit}</span>
                </span>
              </div>
              <input type="range" min={f.min} max={f.max} step={f.step} value={values[f.k]}
                onChange={e => setValues(v => ({ ...v, [f.k]: +e.target.value }))}
                style={{ width: "100%", accentColor: "#B08A5B" }} />
            </div>
          ))}
        </div>
        {saveError && <div style={{ marginTop: 16, padding: "10px 14px", background: "rgba(168,66,58,0.08)", border: "1px solid rgba(168,66,58,0.2)", borderRadius: 4, fontSize: 13, color: "var(--fit-tight)", fontFamily: "var(--font-korean)" }}>{saveError}</div>}
        <div style={{ display: "flex", gap: 10, marginTop: 16 }}>
          <button className="btn btn-secondary" onClick={onPrev}>이전</button>
          <button className="btn btn-primary" style={{ flex: 1, opacity: saving ? 0.7 : 1 }} onClick={save} disabled={saving}>
            {saving ? "저장중..." : "저장 & 다음 →"}
          </button>
        </div>
      </div>

      {/* Body preview */}
      <div style={{ background: "var(--obsidian)", color: "var(--ivory)", borderRadius: 4, padding: 32, display: "flex", flexDirection: "column" }}>
        <div style={{ fontSize: 10, fontFamily: "JetBrains Mono, monospace", letterSpacing: "0.15em", opacity: 0.6 }}>LIVE BODY MODEL</div>
        <div style={{ fontFamily: "var(--font-display)", fontStyle: "italic", fontSize: 26, marginTop: 8, fontWeight: 500 }}>Your Twin</div>
        <div style={{ flex: 1, display: "flex", alignItems: "center", justifyContent: "center", minHeight: 360 }}>
          <svg viewBox="0 0 200 340" style={{ width: 200, height: 340 }}>
            <g stroke="rgba(245,240,230,0.3)" fill="none" strokeWidth="1.2">
              <ellipse cx="100" cy="30" rx="20" ry="22" />
              <path d="M 50 70 Q 100 60 150 70" />
              <path d="M 50 70 Q 48 140 60 220" />
              <path d="M 150 70 Q 152 140 140 220" />
              <path d="M 60 220 L 62 330" />
              <path d="M 140 220 L 138 330" />
              <path d="M 50 75 L 30 180" />
              <path d="M 150 75 L 170 180" />
            </g>
            <line x1={100 - values.shoulder} y1="70" x2={100 + values.shoulder} y2="70" stroke="var(--camel)" strokeWidth="1.5" />
            <line x1={100 - values.chest / 2.5} y1="120" x2={100 + values.chest / 2.5} y2="120" stroke="var(--camel)" strokeWidth="1.5" strokeDasharray="2 2" />
            <line x1={100 - values.waist / 2.5} y1="180" x2={100 + values.waist / 2.5} y2="180" stroke="var(--camel)" strokeWidth="1.5" strokeDasharray="2 2" />
          </svg>
        </div>
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12, paddingTop: 16, borderTop: "1px solid rgba(245,240,230,0.12)" }}>
          <div><div style={{ fontSize: 9, opacity: 0.5, fontFamily: "JetBrains Mono, monospace" }}>PREDICTED SIZE</div><div style={{ fontFamily: "var(--font-display)", fontSize: 24, fontWeight: 500 }}>M</div></div>
          <div><div style={{ fontSize: 9, opacity: 0.5, fontFamily: "JetBrains Mono, monospace" }}>BODY TYPE</div><div style={{ fontFamily: "var(--font-display)", fontSize: 20, fontStyle: "italic" }}>Regular</div></div>
        </div>
      </div>
    </div>
  );
}

// ─── Step 3: Style ────────────────────────────────────────────────────
function StepStyle({ onNext, onPrev }: { onNext: () => void; onPrev: () => void }) {
  const STYLES = [
    { id: "minimal",  label: "미니멀", en: "Minimal",  desc: "군더더기 없는 깔끔한 라인" },
    { id: "classic",  label: "클래식", en: "Classic",  desc: "시간을 초월한 정통 스타일" },
    { id: "casual",   label: "캐주얼", en: "Casual",   desc: "편안하고 자연스러운 일상복" },
    { id: "street",   label: "스트릿", en: "Street",   desc: "도시적이고 개성 있는 무드" },
    { id: "formal",   label: "포멀",   en: "Formal",   desc: "격식 있는 비즈니스 룩" },
    { id: "vintage",  label: "빈티지", en: "Vintage",  desc: "레트로 감성의 독특한 감각" },
  ];
  const OCCASIONS = ["출근", "데이트", "여행", "운동", "파티", "일상"];
  const [selected, setSelected] = useState<string[]>([]);
  const [selOccasion, setSelOccasion] = useState<string[]>([]);

  const toggle = (arr: string[], setArr: (v: string[]) => void, v: string) =>
    setArr(arr.includes(v) ? arr.filter(x => x !== v) : [...arr, v]);

  return (
    <div style={{ background: "var(--bg-raised)", border: "1px solid var(--line)", borderRadius: 4, padding: 48 }}>
      <div className="korean-serif" style={{ fontSize: 32, fontWeight: 500, letterSpacing: "-0.02em", fontFamily: "var(--font-korean-display)", marginBottom: 8 }}>스타일 취향을 알려주세요</div>
      <p className="korean-sans" style={{ fontSize: 13, color: "var(--text-muted)", marginBottom: 32, lineHeight: 1.7 }}>선택한 취향을 바탕으로 AI가 코디를 추천해드립니다. 복수 선택 가능합니다.</p>

      <div style={{ fontSize: 10, fontFamily: "JetBrains Mono, monospace", letterSpacing: "0.14em", opacity: 0.6, marginBottom: 14 }}>STYLE TYPE</div>
      <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: 12, marginBottom: 36 }}>
        {STYLES.map(s => (
          <div key={s.id} onClick={() => toggle(selected, setSelected, s.id)} style={{ padding: "20px 24px", borderRadius: 4, cursor: "pointer", transition: "all 0.15s", border: selected.includes(s.id) ? "1px solid var(--camel-soft)" : "1px solid var(--line)", background: selected.includes(s.id) ? "var(--camel)" : "var(--bg-raised)" }}>
            <div style={{ fontFamily: "var(--font-display)", fontStyle: "italic", fontSize: 22, fontWeight: 500 }}>{s.en}</div>
            <div className="korean-sans" style={{ fontSize: 15, fontWeight: 600, marginTop: 4 }}>{s.label}</div>
            <div className="korean-sans" style={{ fontSize: 11, opacity: 0.7, marginTop: 6, lineHeight: 1.5 }}>{s.desc}</div>
          </div>
        ))}
      </div>

      <div style={{ fontSize: 10, fontFamily: "JetBrains Mono, monospace", letterSpacing: "0.14em", opacity: 0.6, marginBottom: 14 }}>OCCASION</div>
      <div style={{ display: "flex", flexWrap: "wrap", gap: 10, marginBottom: 36 }}>
        {OCCASIONS.map(o => (
          <button key={o} onClick={() => toggle(selOccasion, setSelOccasion, o)} className="korean-sans" style={{ padding: "10px 20px", borderRadius: 2, cursor: "pointer", fontSize: 13, transition: "all 0.15s", border: selOccasion.includes(o) ? "1px solid var(--camel-soft)" : "1px solid var(--line-strong)", background: selOccasion.includes(o) ? "var(--walnut)" : "transparent", color: "var(--obsidian)" }}>{o}</button>
        ))}
      </div>

      <div style={{ display: "flex", gap: 10 }}>
        <button className="btn btn-secondary" onClick={onPrev}>이전</button>
        <button className="btn btn-primary" style={{ flex: 1 }} onClick={onNext}>저장 & 다음 →</button>
      </div>
    </div>
  );
}

// ─── Step 4: First Item ───────────────────────────────────────────────
function StepFirstItem({ onFinish, onPrev }: { onFinish: () => void; onPrev: () => void }) {
  const CATS = ["상의", "하의", "아우터", "원피스", "신발", "액세서리"];
  const [form, setForm] = useState({ name: "", category: "상의", size: "M", fabric: "", garment_shoulder: "", garment_chest: "", garment_waist: "", garment_length: "" });
  const [saving, setSaving] = useState(false);

  const save = async () => {
    if (!form.name.trim()) return;
    setSaving(true);
    try {
      await api("/clothing-items", {
        method: "POST",
        body: { name: form.name, category: form.category.toLowerCase(), fit_type: "regular", size_label: form.size },
      });
      onFinish();
    } finally { setSaving(false); }
  };

  const inp = (k: keyof typeof form, placeholder: string, type = "text") => (
    <input type={type} placeholder={placeholder} value={form[k]}
      onChange={e => setForm(f => ({ ...f, [k]: e.target.value }))}
      style={{ width: "100%", padding: "12px 16px", background: "var(--bg)", border: "1px solid var(--line)", borderRadius: 2, color: "var(--obsidian)", fontFamily: "var(--font-korean)", fontSize: 14 }} />
  );

  return (
    <div style={{ background: "var(--bg-raised)", border: "1px solid var(--line)", borderRadius: 4, padding: 48, display: "grid", gridTemplateColumns: "1fr 1fr", gap: 48 }}>
      <div>
        <div className="korean-serif" style={{ fontSize: 32, fontWeight: 500, letterSpacing: "-0.02em", fontFamily: "var(--font-korean-display)", marginBottom: 8 }}>첫 아이템을 등록하세요</div>
        <p className="korean-sans" style={{ fontSize: 13, color: "var(--text-muted)", marginBottom: 32, lineHeight: 1.7 }}>옷장에 아이템을 추가하면 핏 분석과 AI 코디 추천을 받을 수 있습니다.</p>
        <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
          <div><div className="korean-sans" style={{ fontSize: 11, opacity: 0.6, marginBottom: 6 }}>아이템 이름 *</div>{inp("name", "예: 화이트 오버핏 셔츠")}</div>
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }}>
            <div>
              <div className="korean-sans" style={{ fontSize: 11, opacity: 0.6, marginBottom: 6 }}>카테고리</div>
              <select value={form.category} onChange={e => setForm(f => ({ ...f, category: e.target.value }))} style={{ width: "100%", padding: "12px 16px", background: "var(--bg)", border: "1px solid var(--line)", borderRadius: 2, color: "var(--obsidian)", fontFamily: "var(--font-korean)", fontSize: 14 }}>
                {CATS.map(c => <option key={c} value={c}>{c}</option>)}
              </select>
            </div>
            <div>
              <div className="korean-sans" style={{ fontSize: 11, opacity: 0.6, marginBottom: 6 }}>사이즈</div>
              <select value={form.size} onChange={e => setForm(f => ({ ...f, size: e.target.value }))} style={{ width: "100%", padding: "12px 16px", background: "var(--bg)", border: "1px solid var(--line)", borderRadius: 2, color: "var(--obsidian)", fontFamily: "var(--font-korean)", fontSize: 14 }}>
                {["XS", "S", "M", "L", "XL", "XXL"].map(s => <option key={s} value={s}>{s}</option>)}
              </select>
            </div>
          </div>
        </div>
        <div style={{ display: "flex", gap: 10, marginTop: 32 }}>
          <button className="btn btn-secondary" onClick={onPrev}>이전</button>
          <button className="btn btn-primary" style={{ flex: 1, opacity: saving ? 0.7 : 1 }} disabled={saving} onClick={save}>{saving ? "등록 중..." : "등록하고 시작하기 →"}</button>
        </div>
        <button className="korean-sans" onClick={onFinish} style={{ marginTop: 12, width: "100%", background: "none", border: "none", color: "var(--text-muted)", fontSize: 12, cursor: "pointer", padding: "8px 0" }}>나중에 등록할게요 →</button>
      </div>

      <div style={{ background: "var(--obsidian)", color: "var(--ivory)", borderRadius: 4, padding: 32 }}>
        <div style={{ fontSize: 10, fontFamily: "JetBrains Mono, monospace", letterSpacing: "0.15em", opacity: 0.6, marginBottom: 24 }}>WARDROBE PREVIEW</div>
        <div style={{ padding: "20px 24px", border: "1px solid var(--camel-soft)", borderRadius: 4, background: "rgba(176,138,91,0.1)" }}>
          <div style={{ fontSize: 9, fontFamily: "JetBrains Mono, monospace", letterSpacing: "0.1em", opacity: 0.6, marginBottom: 8 }}>NEW · {form.category.toUpperCase()}</div>
          <div className="korean-sans" style={{ fontSize: 16, fontWeight: 600 }}>{form.name || "아이템 이름"}</div>
          <div style={{ fontSize: 11, opacity: 0.7, fontFamily: "JetBrains Mono, monospace", marginTop: 8 }}>{form.size}</div>
        </div>
        <div style={{ fontSize: 12, opacity: 0.5, textAlign: "center", fontFamily: "var(--font-display)", fontStyle: "italic", paddingTop: 24 }}>Your wardrobe begins here.</div>
      </div>
    </div>
  );
}

// ─── Onboarding Page ──────────────────────────────────────────────────
const STEPS = [
  { n: "01", t: "ACCOUNT", ko: "시작하기" },
  { n: "02", t: "BODY",    ko: "신체 측정" },
  { n: "03", t: "STYLE",   ko: "취향 설정" },
  { n: "04", t: "CLOSET",  ko: "첫 등록" },
];

export default function OnboardingPage() {
  const router = useRouter();
  const [step, setStep] = useState(2);

  return (
    <main>
      <TopBar />
      <section style={{ padding: "48px 48px 0", maxWidth: 1200, margin: "0 auto" }}>
        <div className="eyebrow">ONBOARDING · 04 STEPS</div>
        <h1 className="korean-serif" style={{ margin: "16px 0 40px", fontSize: 72, fontWeight: 400, letterSpacing: "-0.03em", lineHeight: 1, fontFamily: "var(--font-korean-display)" }}>
          당신을 <span style={{ fontFamily: "var(--font-display)", fontStyle: "italic", color: "var(--walnut)" }}>측정</span>합니다.
        </h1>

        {/* Step rail */}
        <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 12, marginBottom: 40 }}>
          {STEPS.map((s, i) => (
            <div key={i} onClick={() => { if (i + 1 >= 2) setStep(i + 1); }} style={{ padding: 20, borderRadius: 4, background: i === step - 1 ? "var(--obsidian)" : "var(--bg-raised)", color: i === step - 1 ? "var(--ivory)" : "var(--obsidian)", border: "1px solid var(--line)", opacity: i > step - 1 ? 0.5 : 1, cursor: i + 1 >= 2 ? "pointer" : "default" }}>
              <div style={{ fontFamily: "var(--font-display)", fontSize: 28, fontStyle: "italic", fontWeight: 500, color: i === step - 1 ? "var(--camel-soft)" : "var(--walnut)" }}>{s.n}</div>
              <div className="korean-sans" style={{ fontSize: 14, fontWeight: 500, marginTop: 8 }}>{s.ko}</div>
              <div style={{ fontSize: 10, fontFamily: "JetBrains Mono, monospace", letterSpacing: "0.1em", opacity: 0.6, marginTop: 2 }}>{s.t}</div>
            </div>
          ))}
        </div>

        {step === 2 && <StepMeasurements onNext={() => setStep(3)} onPrev={() => setStep(1)} />}
        {step === 3 && <StepStyle onNext={() => setStep(4)} onPrev={() => setStep(2)} />}
        {step === 4 && <StepFirstItem onFinish={() => router.push("/closet")} onPrev={() => setStep(3)} />}
      </section>
      <Footer />
    </main>
  );
}
