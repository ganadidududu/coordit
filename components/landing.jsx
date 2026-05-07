// Coordit — Landing Page (editorial vintage wardrobe)

function Landing({ onNav, brand }) {
  return (
    <main>
      <TopBar active="landing" onNav={onNav} brand={brand} />

      {/* ═══ HERO ═══ */}
      <section style={{
        padding: '80px 64px 120px',
        position: 'relative',
        overflow: 'hidden',
      }}>
        <div style={{
          display: 'grid',
          gridTemplateColumns: '1.2fr 1fr',
          gap: 64,
          maxWidth: 1440,
          margin: '0 auto',
          alignItems: 'center',
          minHeight: 640,
        }}>
          {/* Left: editorial copy */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 32 }}>
            <div className="eyebrow" style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
              <span style={{ width: 32, height: 1, background: 'var(--camel)' }} />
              THE CURATED LENS · N°001
            </div>

            <h1 className="korean-serif" style={{
              margin: 0,
              fontSize: 100,
              lineHeight: 0.95,
              fontWeight: 400,
              letterSpacing: '-0.035em',
              color: 'var(--obsidian)',
            }}>
              입을 옷이,<br/>
              <span style={{ fontFamily: 'var(--font-display, serif)', fontStyle: 'italic', fontWeight: 500, color: 'var(--walnut)' }}>
                늘 거기에.
              </span>
            </h1>

            <p className="korean-sans" style={{
              margin: 0, maxWidth: 480,
              fontSize: 17, lineHeight: 1.7,
              color: 'var(--text-muted)',
            }}>
              Coordit는 당신의 옷장을 AI로 디지털화하고,<br/>
              체형·일정·날씨에 맞춘 코디를 매일 아침 큐레이션합니다.
            </p>

            <div style={{ display: 'flex', gap: 12, marginTop: 16 }}>
              <button className="btn btn-primary" onClick={() => onNav('onboarding')}>
                무료로 시작하기 →
              </button>
              <button className="btn btn-secondary" onClick={() => onNav('atelier')}>
                아뜰리에 둘러보기
              </button>
            </div>

            {/* press strip */}
            <div style={{
              display: 'flex', gap: 40, marginTop: 32,
              paddingTop: 32, borderTop: '1px solid var(--line)',
              alignItems: 'center',
            }}>
              <div style={{ fontSize: 10, color: 'var(--text-dim)', fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.15em' }}>AS SEEN IN</div>
              <div style={{ display: 'flex', gap: 28, fontFamily: 'var(--font-display, serif)', fontSize: 16, color: 'var(--text-muted)', fontStyle: 'italic' }}>
                <span>Vogue Korea</span>
                <span style={{ opacity: 0.4 }}>·</span>
                <span>W Magazine</span>
                <span style={{ opacity: 0.4 }}>·</span>
                <span>Noblesse</span>
              </div>
            </div>
          </div>

          {/* Right: editorial still-life composition */}
          <HeroComposition />
        </div>
      </section>

      {/* ═══ QUIETLY ANIMATED RULE ═══ */}
      <div style={{
        padding: '16px 64px',
        borderTop: '1px solid var(--line)',
        borderBottom: '1px solid var(--line)',
        background: 'var(--bg-raised)',
        overflow: 'hidden',
      }}>
        <div style={{
          display: 'flex', gap: 48,
          fontFamily: 'var(--font-display, serif)', fontStyle: 'italic',
          fontSize: 20, color: 'var(--walnut)',
          animation: 'coordit-marquee 40s linear infinite',
          whiteSpace: 'nowrap',
        }}>
          {Array.from({ length: 2 }).map((_, k) => (
            <React.Fragment key={k}>
              <span>체형 기반 핏 분석</span>
              <span style={{ color: 'var(--camel)' }}>✦</span>
              <span>TPO 스타일링</span>
              <span style={{ color: 'var(--camel)' }}>✦</span>
              <span>Digital Twin Wardrobe</span>
              <span style={{ color: 'var(--camel)' }}>✦</span>
              <span>AI 큐레이션</span>
              <span style={{ color: 'var(--camel)' }}>✦</span>
              <span>매일 아침 7시, 오늘의 코디</span>
              <span style={{ color: 'var(--camel)' }}>✦</span>
            </React.Fragment>
          ))}
        </div>
      </div>
      <style>{`@keyframes coordit-marquee { to { transform: translateX(-50%); } }`}</style>

      {/* ═══ 4 CORE MODULES ═══ */}
      <section style={{ padding: '120px 64px 80px', maxWidth: 1440, margin: '0 auto' }}>
        <SectionHeader
          eyebrow="CAPABILITY — 04"
          title={<>네 가지 정밀함,<br/>하나의 옷장.</>}
          subtitle="사진 한 장에서 시작해, 오늘 입을 옷까지. Coordit의 엔진이 네 단계로 작동합니다."
        />

        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(12, 1fr)',
          gap: 24,
          marginTop: 72,
        }}>
          <ModuleCard
            n="01" label="DIGITAL CLOSET"
            title="옷장을 통째로 디지털화"
            body="사진 업로드 또는 URL. GPT-4o Vision이 소재·실루엣·컬러를 자동 태깅합니다."
            span={7} tall
            accent="var(--walnut)"
            visual={<ClosetMiniVisual />}
          />
          <ModuleCard
            n="02" label="FIT FORENSICS"
            title={<>체형 기반<br/>사이즈 예측</>}
            body="경쟁사가 하지 못하는 것. 실제 신체 수치 × 브랜드 사이즈 표 파싱."
            span={5} tall
            accent="var(--fit-tight)"
            visual={<FitMiniVisual />}
          />
          <ModuleCard
            n="03" label="TPO STYLING"
            title="상황이 옷을 결정합니다"
            body="‘내일 소개팅’, ‘파리 출장’. Claude가 옷장 안에서 답을 찾습니다."
            span={5}
            accent="var(--slate-deep)"
            visual={<TPOMiniVisual />}
          />
          <ModuleCard
            n="04" label="VISUALIZER"
            title="입어보지 않고 보는 코디"
            body="추천 아이템을 한 화면에서 조합·대체·저장. 에디토리얼 레이아웃."
            span={7}
            accent="var(--camel-deep)"
            visual={<VisMiniVisual />}
          />
        </div>
      </section>

      {/* ═══ METRICS ═══ */}
      <section style={{
        background: 'var(--obsidian)', color: 'var(--ivory)',
        padding: '100px 64px', margin: '80px 0 0',
      }}>
        <div style={{ maxWidth: 1440, margin: '0 auto' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', marginBottom: 56 }}>
            <h3 className="korean-serif" style={{
              margin: 0, fontSize: 42, fontWeight: 400,
              fontFamily: "var(--font-korean-display, serif)",
              letterSpacing: '-0.02em',
              maxWidth: 560,
            }}>
              데이터로 이야기하는,<br/>
              <span style={{ fontStyle: 'italic', color: 'var(--camel-soft)', fontFamily: 'var(--font-display, serif)' }}>
                가장 정밀한 옷장.
              </span>
            </h3>
            <div style={{ fontSize: 11, color: 'var(--linen)', opacity: 0.6, fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.15em' }}>
              CLOSED BETA · Q2 2026
            </div>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 48, paddingTop: 48, borderTop: '1px solid rgba(245,240,230,0.12)' }}>
            {[
              { v: '98.4', u: '%', l: 'AI 태깅 정확도', sub: 'GPT-4o Vision 기반' },
              { v: '840', u: '+', l: '연동 브랜드 DB', sub: '국내외 쇼핑몰' },
              { v: '±1.5', u: 'cm', l: '핏 예측 오차', sub: '내부 벤치마크' },
              { v: '3.2', u: 'min', l: '평균 큐레이션 시간', sub: '아침 알림 기준' },
            ].map((s, i) => (
              <div key={i}>
                <div style={{ fontFamily: 'var(--font-display, serif)', fontSize: 72, fontWeight: 400, letterSpacing: '-0.03em', lineHeight: 1 }}>
                  {s.v}<span style={{ fontSize: 28, color: 'var(--camel-soft)' }}>{s.u}</span>
                </div>
                <div style={{ fontSize: 12, marginTop: 12, fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.1em', textTransform: 'uppercase', color: 'var(--linen)' }}>
                  {s.l}
                </div>
                <div style={{ fontSize: 12, color: 'rgba(245,240,230,0.5)', marginTop: 6, fontFamily: "var(--font-korean, 'Pretendard', sans-serif)" }}>
                  {s.sub}
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ═══ TESTIMONIAL / EDITORIAL ═══ */}
      <section style={{ padding: '120px 64px', maxWidth: 1200, margin: '0 auto' }}>
        <div style={{ textAlign: 'center' }}>
          <div className="eyebrow" style={{ marginBottom: 40 }}>FROM OUR READERS</div>
          <blockquote style={{
            margin: 0,
            fontFamily: "var(--font-korean-display, 'Noto Serif KR', serif)",
            fontSize: 48, lineHeight: 1.4, fontWeight: 400,
            color: 'var(--obsidian)',
            letterSpacing: '-0.02em',
          }}>
            "옷장을 열기 전에 옷이 먼저 도착했다.<br/>
            <span style={{ fontStyle: 'italic', color: 'var(--walnut)', fontFamily: 'var(--font-display, serif)' }}>
              — 이게 큐레이션이라는 것.
            </span>"
          </blockquote>
          <div style={{ marginTop: 40, fontSize: 12, color: 'var(--text-muted)', fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.1em' }}>
            SUYEON K. · 베타 테스터 · 서울
          </div>
        </div>
      </section>

      {/* ═══ CTA ═══ */}
      <section style={{
        background: 'var(--linen)',
        padding: '100px 64px',
        position: 'relative',
      }}>
        <div style={{ maxWidth: 960, margin: '0 auto', textAlign: 'center' }}>
          <h2 className="korean-serif" style={{
            margin: 0, fontSize: 72, fontWeight: 400,
            lineHeight: 1.1, letterSpacing: '-0.02em',
            color: 'var(--obsidian)',
          }}>
            오늘 아침, <span style={{ fontFamily: 'var(--font-display, serif)', fontStyle: 'italic', color: 'var(--walnut)' }}>무얼</span> 입으셨나요?
          </h2>
          <p style={{ fontSize: 18, color: 'var(--text-muted)', margin: '24px 0 40px', fontFamily: "var(--font-korean, 'Pretendard', sans-serif)" }}>
            베타 테스터 500명 모집 중 · 3분이면 가입이 끝납니다.
          </p>
          <div style={{ display: 'flex', gap: 12, justifyContent: 'center' }}>
            <button className="btn btn-primary" onClick={() => onNav('onboarding')}>지금 시작 →</button>
            <button className="btn btn-secondary" onClick={() => onNav('fit')}>핏 분석 데모</button>
          </div>
        </div>
      </section>

      <Footer brand={brand} />
    </main>
  );
}

// ═════════════════════════════════════
// Visuals
// ═════════════════════════════════════
function HeroComposition() {
  return (
    <div style={{
      position: 'relative',
      height: 640,
      display: 'grid',
      gridTemplateColumns: '1fr 1fr',
      gridTemplateRows: '1fr 1fr',
      gap: 12,
    }}>
      <div style={{ gridRow: '1 / 3', borderRadius: 4, overflow: 'hidden', background: '#2a2623' }}>
        <img src={IMG.heroCamel} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover', filter: 'grayscale(0.1) contrast(1.02)' }}/>
      </div>
      <div style={{ borderRadius: 4, overflow: 'hidden', background: '#2a2623' }}>
        <img src={IMG.heroPortrait} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }}/>
      </div>
      <div style={{
        borderRadius: 4, background: 'var(--obsidian)', color: 'var(--linen)',
        padding: 20, display: 'flex', flexDirection: 'column', justifyContent: 'space-between',
        fontFamily: 'JetBrains Mono, monospace', fontSize: 10, letterSpacing: '0.1em',
      }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', opacity: 0.6 }}>
          <span>// TODAY</span>
          <span>18°C</span>
        </div>
        <div>
          <div style={{ fontFamily: 'var(--font-display, serif)', fontStyle: 'italic', fontSize: 28, letterSpacing: '-0.02em', marginBottom: 8, fontWeight: 500 }}>
            Parisian<br/>Weekday
          </div>
          <div style={{ display: 'flex', gap: 4 }}>
            {['#B08A5B','#1C1B1A','#F5F0E6'].map(c => (
              <span key={c} style={{ width: 18, height: 18, background: c, borderRadius: '50%' }} />
            ))}
          </div>
        </div>
      </div>

      {/* floating accent card */}
      <div style={{
        position: 'absolute', right: -32, top: 40,
        width: 220, padding: 16,
        background: 'var(--bg-raised)',
        border: '1px solid var(--line)',
        borderRadius: 4,
        boxShadow: '0 12px 32px rgba(74,56,38,0.12)',
      }}>
        <div style={{ fontSize: 9, fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.12em', color: 'var(--text-muted)' }}>
          LiDAR ACCURACY
        </div>
        <div style={{ fontFamily: 'var(--font-display, serif)', fontSize: 36, fontWeight: 500, letterSpacing: '-0.02em', marginTop: 4 }}>
          98.4<span style={{ fontSize: 14, color: 'var(--camel)' }}>%</span>
        </div>
        <div style={{ height: 2, background: 'var(--line)', marginTop: 12, borderRadius: 1 }}>
          <div style={{ width: '98.4%', height: '100%', background: 'var(--camel)', borderRadius: 1 }} />
        </div>
      </div>

      {/* floating fit badge */}
      <div style={{
        position: 'absolute', left: -28, bottom: 40,
        width: 160, padding: 14,
        background: 'var(--walnut)', color: 'var(--ivory)',
        borderRadius: 4,
        boxShadow: '0 12px 32px rgba(28,27,26,0.18)',
      }}>
        <div style={{ fontSize: 9, fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.12em', opacity: 0.7 }}>
          FIT PREDICTION
        </div>
        <div style={{ fontFamily: 'var(--font-display, serif)', fontStyle: 'italic', fontSize: 22, marginTop: 4 }}>
          Perfect · M
        </div>
      </div>
    </div>
  );
}

function ModuleCard({ n, label, title, body, span, tall, accent, visual }) {
  return (
    <div style={{
      gridColumn: `span ${span}`,
      minHeight: tall ? 480 : 360,
      padding: 36,
      background: 'var(--bg-raised)',
      border: '1px solid var(--line)',
      borderRadius: 4,
      display: 'flex', flexDirection: 'column', justifyContent: 'space-between',
      gap: 24,
      position: 'relative', overflow: 'hidden',
    }}>
      <div>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 12, marginBottom: 24 }}>
          <div style={{
            fontFamily: 'var(--font-display, serif)',
            fontSize: 40, fontWeight: 500, fontStyle: 'italic',
            color: accent, letterSpacing: '-0.02em', lineHeight: 1,
          }}>{n}</div>
          <div style={{ fontSize: 10, fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.15em', color: 'var(--text-muted)' }}>
            {label}
          </div>
        </div>
        <h3 className="korean-serif" style={{
          margin: 0, fontSize: 32, fontWeight: 500,
          letterSpacing: '-0.02em', color: 'var(--obsidian)', lineHeight: 1.2,
          fontFamily: "var(--font-korean-display, serif)",
        }}>{title}</h3>
        <p className="korean-sans" style={{ margin: '14px 0 0', fontSize: 14, lineHeight: 1.6, color: 'var(--text-muted)' }}>
          {body}
        </p>
      </div>
      <div style={{ marginTop: 'auto' }}>{visual}</div>
    </div>
  );
}

function ClosetMiniVisual() {
  const items = [
    { tag: 'COAT', c: '#8F6F45' },
    { tag: 'KNIT', c: '#E8DFC9' },
    { tag: 'DENIM', c: '#3F4E5E' },
    { tag: 'SILK', c: '#D4B896' },
    { tag: 'WOOL', c: '#4A3826' },
  ];
  return (
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: 8 }}>
      {items.map((it, i) => (
        <div key={i} style={{
          aspectRatio: '3/4',
          background: it.c,
          borderRadius: 2,
          display: 'flex', flexDirection: 'column',
          justifyContent: 'flex-end', padding: 8,
          color: i === 1 || i === 3 ? 'var(--walnut)' : 'var(--ivory)',
          fontSize: 9, fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.1em',
          position: 'relative', overflow: 'hidden',
        }}>
          <div style={{ position: 'absolute', top: 8, right: 8, fontSize: 8, opacity: 0.7 }}>0{i+1}</div>
          {it.tag}
        </div>
      ))}
    </div>
  );
}

function FitMiniVisual() {
  const rows = [
    { part: '어깨', v: '-1.5', state: 'Tight', color: 'var(--fit-tight)', pct: 85 },
    { part: '가슴', v: '+4.0', state: 'Perfect', color: 'var(--fit-perfect)', pct: 65 },
    { part: '허리', v: '+6.0', state: 'Loose', color: 'var(--fit-loose)', pct: 45 },
  ];
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
      {rows.map((r, i) => (
        <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 10, fontSize: 11 }}>
          <span className="korean-sans" style={{ width: 34, color: 'var(--text-muted)' }}>{r.part}</span>
          <div style={{ flex: 1, height: 4, background: 'var(--line)', borderRadius: 2, overflow: 'hidden' }}>
            <div style={{ width: `${r.pct}%`, height: '100%', background: r.color }} />
          </div>
          <span style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 10, color: r.color, minWidth: 40, textAlign: 'right' }}>
            {r.v}cm
          </span>
        </div>
      ))}
    </div>
  );
}

function TPOMiniVisual() {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
      {[
        { t: '내일 · 소개팅', s: 'Camel + Ivory' },
        { t: '금요일 · 파티', s: 'Obsidian + Silk' },
      ].map((x, i) => (
        <div key={i} style={{
          padding: '10px 14px',
          background: i === 0 ? 'var(--obsidian)' : 'transparent',
          color: i === 0 ? 'var(--ivory)' : 'var(--text-muted)',
          border: i === 0 ? 'none' : '1px solid var(--line-strong)',
          borderRadius: 2,
          display: 'flex', justifyContent: 'space-between', alignItems: 'center',
          fontSize: 12,
        }}>
          <span className="korean-sans">{x.t}</span>
          <span style={{ fontSize: 10, fontStyle: 'italic', fontFamily: 'var(--font-display, serif)', opacity: 0.8 }}>{x.s}</span>
        </div>
      ))}
    </div>
  );
}

function VisMiniVisual() {
  const items = ['COAT','KNIT','TROUSER','LOAFER'];
  return (
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 6 }}>
      {items.map((i, idx) => (
        <div key={idx} className="ph" style={{ aspectRatio: '3/4', fontSize: 8, borderRadius: 2 }}>
          {i}
        </div>
      ))}
    </div>
  );
}

window.Landing = Landing;
