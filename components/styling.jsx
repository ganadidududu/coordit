// Coordit — AI Styling (TPO 추천)

function Styling({ onNav, brand }) {
  const [prompt, setPrompt] = useState('내일 오후 2시 파트너사 미팅. 비 예보 있음.');
  const [activeCoord, setActiveCoord] = useState(0);

  const coords = [
    {
      name: 'Parisian Weekday',
      mood: '비즈니스 · 비 예보',
      temp: '18°C',
      palette: ['#8F6F45', '#F5F0E6', '#2D2A27'],
      items: [
        { t: '헤리티지 카멜 코트', role: 'HERO', tag: '아우터' },
        { t: '에센셜 피마 티셔츠', role: 'BASE', tag: '이너' },
        { t: '프리시전 플리츠 트라우저', role: 'STRUCTURE', tag: '하의' },
        { t: '에센셜 화이트 스니커즈', role: 'ACCENT', tag: '슈즈' },
      ],
    },
    {
      name: 'Obsidian Evening',
      mood: '디너 · 실내',
      temp: '18°C',
      palette: ['#1C1B1A', '#4A3826', '#D4B896'],
      items: [
        { t: '옵시디언 모토 재킷', role: 'HERO', tag: '아우터' },
        { t: '클라우드 캐시미어 니트', role: 'BASE', tag: '이너' },
        { t: '생지 데님 팬츠', role: 'STRUCTURE', tag: '하의' },
        { t: '브러시드 로퍼', role: 'ACCENT', tag: '슈즈' },
      ],
    },
    {
      name: 'Soft Ivory',
      mood: '캐주얼 · 주말',
      temp: '18°C',
      palette: ['#E8DFC9', '#B08A5B', '#5A6B7E'],
      items: [
        { t: '아키텍처럴 포플린 셔츠', role: 'HERO', tag: '상의' },
        { t: '울 트라우저', role: 'STRUCTURE', tag: '하의' },
        { t: '리넨 스카프', role: 'ACCENT', tag: '액세서리' },
        { t: '로우탑 카프 스니커즈', role: 'ACCENT', tag: '슈즈' },
      ],
    },
  ];

  const c = coords[activeCoord];

  return (
    <main>
      <TopBar active="styling" onNav={onNav} brand={brand} />

      <section style={{ padding: '48px 48px 0', maxWidth: 1600, margin: '0 auto' }}>
        <div className="eyebrow">AI STYLIST · TPO ENGINE</div>
        <div style={{ marginTop: 16, display: 'grid', gridTemplateColumns: '1.2fr 1fr', gap: 48, alignItems: 'flex-end' }}>
          <h1 className="korean-serif" style={{
            margin: 0, fontSize: 88, fontWeight: 400,
            letterSpacing: '-0.035em', lineHeight: 1,
            fontFamily: "var(--font-korean-display, serif)",
          }}>
            당신의 순간을<br/>
            <span style={{ fontFamily: 'var(--font-display, serif)', fontStyle: 'italic', color: 'var(--walnut)' }}>큐레이팅</span>합니다.
          </h1>
          <div>
            <div style={{ fontSize: 11, fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.15em', color: 'var(--text-muted)' }}>
              POWERED BY CLAUDE · OPUS
            </div>
            <p className="korean-sans" style={{ marginTop: 10, fontSize: 14, color: 'var(--text-muted)', lineHeight: 1.6 }}>
              일정·날씨·컨텍스트를 읽어 옷장 안에서 답을 구성합니다. 새로 사지 않습니다.
            </p>
          </div>
        </div>
      </section>

      {/* Prompt bar */}
      <section style={{ padding: '40px 48px 0', maxWidth: 1600, margin: '0 auto' }}>
        <div style={{
          background: 'var(--bg-raised)', border: '1px solid var(--line-strong)',
          borderRadius: 4, padding: '12px 12px 12px 20px',
          display: 'flex', gap: 12, alignItems: 'center',
        }}>
          <span style={{ fontSize: 14, color: 'var(--walnut)' }}>✦</span>
          <input
            value={prompt} onChange={e => setPrompt(e.target.value)}
            style={{
              flex: 1, border: 'none', background: 'transparent', outline: 'none',
              fontSize: 15, fontFamily: "var(--font-korean, 'Pretendard', sans-serif)",
              color: 'var(--obsidian)',
            }}
          />
          <button className="btn btn-primary" style={{ padding: '12px 20px' }}>오늘의 코디 추천</button>
        </div>
        <div style={{ display: 'flex', gap: 8, marginTop: 12, flexWrap: 'wrap' }}>
          {['내일 미팅', '주말 브런치', '파리 출장 3일', '첫 소개팅', '결혼식 하객', '갤러리 오프닝'].map(q => (
            <Chip key={q} onClick={() => setPrompt(q)}>{q}</Chip>
          ))}
        </div>
      </section>

      {/* Weather / Style DNA strip */}
      <section style={{ padding: '32px 48px 0', maxWidth: 1600, margin: '0 auto' }}>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 16 }}>
          <InfoCard
            label="TODAY"
            title="18°C"
            sub="구름 조금 · 선선함"
            note="린넨·울 레이어링 추천"
            accent="var(--slate)"
          />
          <InfoCard
            label="STYLE DNA"
            title="88"
            unit="/100"
            sub="시너지 스코어"
            note="미니멀 실루엣 × 어스 톤"
            accent="var(--walnut)"
            bar={88}
          />
          <InfoCard
            label="WARDROBE UTILIZATION"
            title="94"
            unit="%"
            sub="이번 주 활용도"
            note="추천 반영률 상위 구간"
            accent="var(--fit-perfect)"
            bar={94}
          />
        </div>
      </section>

      {/* Coordinate explorer */}
      <section style={{ padding: '56px 48px 0', maxWidth: 1600, margin: '0 auto' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', marginBottom: 32 }}>
          <div>
            <div className="eyebrow">CURATED FOR YOU · 03</div>
            <div className="korean-serif" style={{ fontSize: 44, marginTop: 12, fontWeight: 500, letterSpacing: '-0.02em', fontFamily: "var(--font-korean-display, serif)" }}>
              추천 코디
            </div>
          </div>
          <div style={{ display: 'flex', gap: 6 }}>
            {coords.map((_, i) => (
              <button key={i} onClick={() => setActiveCoord(i)} style={{
                width: 40, height: 40, borderRadius: '50%',
                border: activeCoord === i ? '1px solid var(--obsidian)' : '1px solid var(--line-strong)',
                background: activeCoord === i ? 'var(--obsidian)' : 'transparent',
                color: activeCoord === i ? 'var(--ivory)' : 'var(--obsidian)',
                fontFamily: 'var(--font-display, serif)', fontSize: 14, fontStyle: 'italic',
                cursor: 'pointer',
              }}>
                {i + 1}
              </button>
            ))}
          </div>
        </div>

        {/* Featured coordinate — editorial layout */}
        <div style={{
          display: 'grid', gridTemplateColumns: '1fr 1.4fr', gap: 24,
          background: activeCoord === 1 ? 'var(--obsidian)' : 'var(--bg-raised)',
          color: activeCoord === 1 ? 'var(--ivory)' : 'var(--obsidian)',
          borderRadius: 4, padding: 40,
          border: '1px solid var(--line)',
          transition: 'background 0.4s',
        }}>
          {/* Left: Editorial copy */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 24, paddingRight: 24 }}>
            <div style={{ fontSize: 10, fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.15em', opacity: 0.6 }}>
              LOOK N°{String(activeCoord + 1).padStart(2, '0')} · {c.mood}
            </div>
            <h2 className="korean-serif" style={{
              margin: 0, fontFamily: 'var(--font-display, serif)',
              fontSize: 64, fontWeight: 500, fontStyle: 'italic',
              letterSpacing: '-0.03em', lineHeight: 1,
            }}>
              {c.name}
            </h2>
            <p className="korean-sans" style={{ margin: 0, fontSize: 14, lineHeight: 1.7, opacity: 0.85 }}>
              {activeCoord === 0 && '정제된 실루엣과 따뜻한 캐멀 톤. 미팅의 밀도 있는 무드를 위한 3-레이어 구성입니다. 갑작스런 비에도 실루엣을 잃지 않습니다.'}
              {activeCoord === 1 && '모토 재킷이 만들어내는 구조적 긴장감. 캐시미어가 그 톤을 부드럽게 풀어줍니다. 저녁 디너에 맞는 비율.'}
              {activeCoord === 2 && '린넨과 면의 가벼움 위에 우디한 베이지를 얹은 주말용. 발목까지 이어지는 포플린 자락이 걸을 때 리듬을 만듭니다.'}
            </p>

            <div style={{ display: 'flex', gap: 8, marginTop: 4 }}>
              {c.palette.map(col => (
                <div key={col} style={{
                  width: 44, height: 44, borderRadius: 2, background: col,
                  border: '1px solid rgba(255,255,255,0.1)',
                }} />
              ))}
            </div>

            <div style={{
              marginTop: 'auto', paddingTop: 32,
              borderTop: `1px solid ${activeCoord === 1 ? 'rgba(245,240,230,0.15)' : 'var(--line)'}`,
              display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 20,
            }}>
              <div>
                <div style={{ fontSize: 10, fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.1em', opacity: 0.6 }}>TEMP</div>
                <div style={{ fontFamily: 'var(--font-display, serif)', fontSize: 24, fontWeight: 500, marginTop: 4 }}>{c.temp}</div>
              </div>
              <div>
                <div style={{ fontSize: 10, fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.1em', opacity: 0.6 }}>FIT SCORE</div>
                <div style={{ fontFamily: 'var(--font-display, serif)', fontSize: 24, fontWeight: 500, marginTop: 4, color: activeCoord === 1 ? 'var(--camel-soft)' : 'var(--walnut)' }}>
                  9{activeCoord + 1}.{Math.floor(Math.random() * 9)}%
                </div>
              </div>
            </div>

            <div style={{ display: 'flex', gap: 10 }}>
              <button className={activeCoord === 1 ? 'btn btn-camel' : 'btn btn-primary'} style={{ flex: 1 }}>
                저장하기
              </button>
              <button style={{
                padding: '14px 18px',
                border: `1px solid ${activeCoord === 1 ? 'rgba(245,240,230,0.3)' : 'var(--line-strong)'}`,
                background: 'transparent', color: 'inherit',
                borderRadius: 8, cursor: 'pointer', fontSize: 14,
              }}>
                ♡
              </button>
            </div>
          </div>

          {/* Right: 4-item grid */}
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gridTemplateRows: '1fr 1fr', gap: 8 }}>
            {c.items.map((it, i) => (
              <CoordItem key={i} item={it} idx={i} dark={activeCoord === 1} color={c.palette[i % c.palette.length]} />
            ))}
          </div>
        </div>

        {/* Alt carousel — mini looks */}
        <div style={{ marginTop: 40, display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16 }}>
          {[
            { name: 'Morning Meeting', tag: 'BIZ CASUAL', t: '08:30 - 12:00', color: '#8F6F45' },
            { name: 'Cafe Lunch', tag: 'SMART CASUAL', t: '12:30 - 14:00', color: '#D4B896' },
            { name: 'Client Dinner', tag: 'ELEVATED', t: '19:00 - 22:00', color: '#1C1B1A' },
            { name: 'Weekend Walk', tag: 'EFFORTLESS', t: 'SAT - SUN', color: '#5A6B7E' },
          ].map((l, i) => (
            <MiniLook key={i} {...l} />
          ))}
        </div>
      </section>

      {/* AI Reasoning */}
      <section style={{ padding: '80px 48px 0', maxWidth: 1600, margin: '0 auto' }}>
        <div style={{
          background: 'var(--linen)', borderRadius: 4, padding: 48,
          display: 'grid', gridTemplateColumns: '1fr 2fr', gap: 48,
          border: '1px solid var(--line)',
        }}>
          <div>
            <div className="eyebrow">AI REASONING</div>
            <h3 className="korean-serif" style={{
              margin: '16px 0 0', fontSize: 36, fontWeight: 500,
              letterSpacing: '-0.02em', lineHeight: 1.2,
              fontFamily: "var(--font-korean-display, serif)",
            }}>
              왜 이 조합일까요?
            </h3>
            <p className="korean-sans" style={{ marginTop: 16, fontSize: 13, color: 'var(--text-muted)', lineHeight: 1.7 }}>
              Coordit는 결정을 내리고, 그 결정의 이유를 투명하게 보여줍니다.
            </p>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            {[
              { label: '날씨 매칭', detail: '18°C에는 중간 두께의 울 아우터가 최적. 카멜 코트 선정.', tag: 'WEATHER' },
              { label: 'TPO 문맥', detail: '"파트너사 미팅"은 비즈니스 격식 요구. 플리츠 트라우저로 포멀 강화.', tag: 'CONTEXT' },
              { label: '체형 궁합', detail: '어깨 폭(44.5cm) 대비 구조적 라펠이 프레임을 잡아줍니다.', tag: 'BODY' },
              { label: '컬러 하모니', detail: '카멜·아이보리·옵시디언 3톤 — 미니멀 실루엣 프로필과 94% 일치.', tag: 'PALETTE' },
            ].map((r, i) => (
              <div key={i} style={{
                padding: '16px 20px',
                background: 'rgba(255,255,255,0.6)',
                borderRadius: 2,
                display: 'grid', gridTemplateColumns: '120px 1fr 60px', gap: 16, alignItems: 'center',
              }}>
                <div className="korean-sans" style={{ fontSize: 13, fontWeight: 500 }}>{r.label}</div>
                <div className="korean-sans" style={{ fontSize: 12, color: 'var(--text-muted)', lineHeight: 1.5 }}>{r.detail}</div>
                <div style={{ fontSize: 9, fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.1em', color: 'var(--walnut)', textAlign: 'right' }}>{r.tag}</div>
              </div>
            ))}
          </div>
        </div>
      </section>

      <Footer brand={brand} />
    </main>
  );
}

function InfoCard({ label, title, unit, sub, note, accent, bar }) {
  return (
    <div style={{
      background: 'var(--bg-raised)', border: '1px solid var(--line)',
      borderRadius: 4, padding: 24,
      display: 'flex', flexDirection: 'column', gap: 12,
    }}>
      <div style={{ fontSize: 10, fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.15em', color: 'var(--text-muted)' }}>
        {label}
      </div>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 8 }}>
        <div style={{ fontFamily: 'var(--font-display, serif)', fontSize: 52, fontWeight: 500, letterSpacing: '-0.03em', color: accent, lineHeight: 1 }}>
          {title}
        </div>
        {unit && <div style={{ fontSize: 18, color: 'var(--text-muted)' }}>{unit}</div>}
      </div>
      <div className="korean-sans" style={{ fontSize: 12, color: 'var(--text-muted)' }}>{sub}</div>
      {bar !== undefined && (
        <div style={{ height: 2, background: 'var(--line)', borderRadius: 1 }}>
          <div style={{ width: `${bar}%`, height: '100%', background: accent }} />
        </div>
      )}
      <div className="korean-sans" style={{ fontSize: 11, color: 'var(--walnut)', marginTop: 'auto' }}>
        → {note}
      </div>
    </div>
  );
}

function CoordItem({ item, idx, dark, color }) {
  return (
    <div style={{
      background: color,
      borderRadius: 2, padding: 16,
      display: 'flex', flexDirection: 'column', justifyContent: 'space-between',
      minHeight: 180,
      color: ['#F5F0E6','#E8DFC9','#D4B896'].includes(color) ? 'var(--walnut)' : 'var(--ivory)',
      backgroundImage: `repeating-linear-gradient(135deg, rgba(255,255,255,0.04) 0 1px, transparent 1px 8px)`,
      position: 'relative',
    }}>
      <div style={{ display: 'flex', justifyContent: 'space-between' }}>
        <span style={{ fontSize: 9, fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.12em', opacity: 0.7 }}>
          {item.role}
        </span>
        <span style={{ fontSize: 9, fontFamily: 'JetBrains Mono, monospace', opacity: 0.5 }}>
          0{idx + 1}
        </span>
      </div>
      <div>
        <div className="korean-sans" style={{ fontSize: 15, fontWeight: 500, lineHeight: 1.3 }}>
          {item.t}
        </div>
        <div style={{ fontSize: 10, opacity: 0.7, marginTop: 4, fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.08em' }}>
          · {item.tag}
        </div>
      </div>
    </div>
  );
}

function MiniLook({ name, tag, t, color }) {
  return (
    <div style={{ background: 'var(--bg-raised)', border: '1px solid var(--line)', borderRadius: 4, overflow: 'hidden', cursor: 'pointer', transition: 'all 0.2s' }}
    onMouseEnter={e => e.currentTarget.style.transform = 'translateY(-2px)'}
    onMouseLeave={e => e.currentTarget.style.transform = 'none'}
    >
      <div style={{ aspectRatio: '3/4', background: color, position: 'relative', padding: 14, backgroundImage: `repeating-linear-gradient(135deg, rgba(255,255,255,0.05) 0 1px, transparent 1px 8px)` }}>
        <div style={{ fontSize: 9, color: 'var(--ivory)', opacity: 0.7, fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.1em' }}>
          {tag}
        </div>
      </div>
      <div style={{ padding: '14px 16px' }}>
        <div className="korean-sans" style={{ fontFamily: 'var(--font-display, serif)', fontStyle: 'italic', fontSize: 18, fontWeight: 500 }}>{name}</div>
        <div style={{ fontSize: 11, color: 'var(--text-muted)', marginTop: 4, fontFamily: 'JetBrains Mono, monospace' }}>{t}</div>
      </div>
    </div>
  );
}

window.Styling = Styling;
