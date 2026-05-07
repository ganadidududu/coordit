// Coordit — Product detail, Onboarding, Atelier (misc screens, compact)

// ═══ PRODUCT DETAIL ═══
function Product({ onNav, brand }) {
  return (
    <main>
      <TopBar active="atelier" onNav={onNav} brand={brand} />
      <section style={{ padding: '48px 48px 0', maxWidth: 1600, margin: '0 auto' }}>
        <div className="eyebrow">SHOP / OUTERWEAR / OBSIDIAN MOTO II</div>

        <div style={{ display: 'grid', gridTemplateColumns: '1.3fr 1fr', gap: 48, marginTop: 32 }}>
          {/* Images */}
          <div>
            <div className="ph" style={{
              aspectRatio: '4/5', background: '#1C1B1A',
              backgroundImage: 'repeating-linear-gradient(135deg, rgba(245,240,230,0.04) 0 1px, transparent 1px 10px)',
              borderRadius: 4, position: 'relative', color: 'var(--linen)',
            }}>
              <div style={{ position: 'absolute', top: 20, left: 20, padding: '6px 12px', background: 'rgba(245,240,230,0.9)', color: 'var(--walnut)', fontSize: 10, fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.12em', borderRadius: 2 }}>
                ✦ AI 분석 완료
              </div>
              <span style={{ opacity: 0.5, fontSize: 11 }}>FRONT · HERO</span>
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 8, marginTop: 8 }}>
              {['BACK','DETAIL','STYLED'].map(l => (
                <div key={l} className="ph" style={{ aspectRatio: '1/1', background: '#2D2A27', color: 'var(--linen)', borderRadius: 4, fontSize: 10 }}>{l}</div>
              ))}
            </div>
          </div>

          {/* Info */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 24 }}>
            <div>
              <div style={{ fontSize: 11, fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.15em', color: 'var(--walnut)' }}>ATELIER EXCLUSIVE</div>
              <h1 className="korean-serif" style={{
                margin: '12px 0 0', fontSize: 56, fontWeight: 400,
                letterSpacing: '-0.03em', lineHeight: 1.1,
                fontFamily: "var(--font-korean-display, serif)",
              }}>옵시디언 모토 <span style={{ fontFamily: 'var(--font-display, serif)', fontStyle: 'italic', color: 'var(--walnut)' }}>II</span></h1>
              <div style={{ display: 'flex', alignItems: 'baseline', gap: 12, marginTop: 12 }}>
                <div style={{ fontFamily: 'var(--font-display, serif)', fontSize: 36, fontWeight: 500, letterSpacing: '-0.02em' }}>₩845,000</div>
                <div style={{ fontSize: 11, color: 'var(--text-muted)', textDecoration: 'line-through' }}>₩960,000</div>
              </div>
            </div>

            <p className="korean-sans" style={{ margin: 0, fontSize: 14, color: 'var(--text-muted)', lineHeight: 1.7 }}>
              재활용 가죽으로 제작된 독보적인 실루엣. 두 번째 에디션은 강화된 솔기와 시그니처 '큐레이터 렌즈' 안감이 특징입니다.
            </p>

            {/* AI Fit Guide card */}
            <div style={{ background: 'var(--linen)', border: '1px solid var(--line)', padding: 20, borderRadius: 4 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <div style={{ fontSize: 10, fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.12em', color: 'var(--walnut)' }}>
                  ✦ AI 핏 가이드 · 당신의 체형 기반
                </div>
                <div style={{ padding: '3px 8px', background: 'var(--fit-perfect)', color: 'var(--ivory)', fontSize: 9, letterSpacing: '0.1em', fontFamily: 'JetBrains Mono, monospace', borderRadius: 2 }}>
                  PERFECT · M
                </div>
              </div>
              <div style={{ marginTop: 14, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, fontSize: 12 }}>
                {[
                  { p: '어깨', s: '좁음 ●', c: 'var(--fit-tight)' },
                  { p: '가슴', s: '완벽함 ●', c: 'var(--fit-perfect)' },
                  { p: '허리', s: '여유있음 ●', c: 'var(--fit-loose)' },
                  { p: '총장', s: '완벽함 ●', c: 'var(--fit-perfect)' },
                ].map(r => (
                  <div key={r.p} style={{ display: 'flex', justifyContent: 'space-between', padding: '6px 0', borderBottom: '1px solid rgba(28,27,26,0.08)' }}>
                    <span className="korean-sans" style={{ color: 'var(--text-muted)' }}>{r.p}</span>
                    <span style={{ color: r.c, fontFamily: 'var(--font-display, serif)', fontStyle: 'italic' }}>{r.s}</span>
                  </div>
                ))}
              </div>
              <button className="btn btn-secondary" style={{ width: '100%', marginTop: 14, fontSize: 12, padding: '10px' }} onClick={() => onNav('fit')}>
                상세 핏 분석 보기 →
              </button>
            </div>

            {/* Size */}
            <div>
              <div style={{ fontSize: 11, fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.12em', color: 'var(--text-muted)', marginBottom: 10 }}>사이즈</div>
              <div style={{ display: 'flex', gap: 6 }}>
                {['XS','S','M','L','XL'].map(s => (
                  <button key={s} style={{
                    flex: 1, padding: '14px 0',
                    border: s === 'M' ? '1px solid var(--obsidian)' : '1px solid var(--line-strong)',
                    background: s === 'M' ? 'var(--obsidian)' : 'transparent',
                    color: s === 'M' ? 'var(--ivory)' : 'var(--obsidian)',
                    fontFamily: 'var(--font-display, serif)', fontSize: 16, fontWeight: 500,
                    borderRadius: 2, cursor: 'pointer',
                  }}>{s}</button>
                ))}
              </div>
            </div>

            <div style={{ display: 'flex', gap: 10 }}>
              <button className="btn btn-primary" style={{ flex: 1 }}>구매하기</button>
              <button className="btn btn-secondary" style={{ padding: '14px 18px' }}>♡</button>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 20, paddingTop: 20, borderTop: '1px solid var(--line)', fontSize: 12 }}>
              <div><div style={{ color: 'var(--text-muted)' }}>원산지</div><div className="korean-sans" style={{ marginTop: 4, fontWeight: 500 }}>이탈리아 토스카나</div></div>
              <div><div style={{ color: 'var(--text-muted)' }}>소재</div><div className="korean-sans" style={{ marginTop: 4, fontWeight: 500 }}>100% 리사이클 가죽</div></div>
              <div><div style={{ color: 'var(--text-muted)' }}>하드웨어</div><div className="korean-sans" style={{ marginTop: 4, fontWeight: 500 }}>브러시드 팔라듐</div></div>
              <div><div style={{ color: 'var(--text-muted)' }}>무게</div><div className="korean-sans" style={{ marginTop: 4, fontWeight: 500 }}>1.2kg (미디엄)</div></div>
            </div>
          </div>
        </div>

        {/* Match with closet */}
        <div style={{ marginTop: 72 }}>
          <div className="eyebrow">MATCH WITH YOUR CLOSET</div>
          <div className="korean-serif" style={{ fontSize: 40, marginTop: 12, fontWeight: 500, letterSpacing: '-0.02em', fontFamily: "var(--font-korean-display, serif)" }}>
            옷장 안에서 매칭하기
          </div>
          <div style={{ marginTop: 32, display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 16 }}>
            {[
              { name: '그레이 울 트라우저', note: '완벽한 균형', body: '울의 매트한 질감이 가죽의 광택을 중화시켜 세련된 이브닝 룩.', tag: '보노크롬', c: '#5A6B7E' },
              { name: '에센셜 피마 티셔츠', note: '캐주얼 코어', body: '자켓의 하드웨어를 돋보이게 하는 대비감. 일상적인 데일리 룩.', tag: '엣지 미니멀', c: '#F5F0E6' },
              { name: '생지 데님 팬츠', note: '위크엔드 톤', body: '구조적 가죽 × 워싱 데님의 믹스 매치. 거리감 있는 실루엣.', tag: '캐주얼 컨트라스트', c: '#3F4E5E' },
            ].map((m, i) => (
              <div key={i} style={{ background: 'var(--bg-raised)', border: '1px solid var(--line)', borderRadius: 4, overflow: 'hidden' }}>
                <div style={{ aspectRatio: '4/3', background: m.c, padding: 14, backgroundImage: 'repeating-linear-gradient(135deg, rgba(255,255,255,0.05) 0 1px, transparent 1px 10px)', display: 'flex', alignItems: 'flex-end', color: ['#F5F0E6'].includes(m.c) ? 'var(--walnut)' : 'var(--ivory)' }}>
                  <span style={{ fontSize: 9, fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.12em' }}>MATCH · 0{i + 1}</span>
                </div>
                <div style={{ padding: 20 }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 8 }}>
                    <div>
                      <div className="korean-sans" style={{ fontSize: 15, fontWeight: 500 }}>{m.name}</div>
                      <div style={{ fontFamily: 'var(--font-display, serif)', fontStyle: 'italic', color: 'var(--walnut)', fontSize: 13, marginTop: 2 }}>— {m.note}</div>
                    </div>
                    <div style={{ padding: '3px 8px', background: 'var(--linen)', fontSize: 9, color: 'var(--walnut)', fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.1em', borderRadius: 2, whiteSpace: 'nowrap' }}>
                      {m.tag}
                    </div>
                  </div>
                  <p className="korean-sans" style={{ margin: '12px 0 0', fontSize: 12, color: 'var(--text-muted)', lineHeight: 1.6 }}>{m.body}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>
      <Footer brand={brand} />
    </main>
  );
}

// ═══ ONBOARDING ═══
function Onboarding({ onNav, brand }) {
  const [step, setStep] = useState(2);
  const [values, setValues] = useState({ height: 172, weight: 62, shoulder: 44.5, chest: 98, waist: 82 });
  const steps = [
    { n: '01', t: '계정', ko: '시작하기' },
    { n: '02', t: '체형', ko: '신체 측정' },
    { n: '03', t: '스타일', ko: '취향 설정' },
    { n: '04', t: '옷장', ko: '첫 등록' },
  ];
  return (
    <main>
      <TopBar active="" onNav={onNav} brand={brand} />
      <section style={{ padding: '48px 48px 0', maxWidth: 1200, margin: '0 auto' }}>
        <div className="eyebrow">ONBOARDING · 04 STEPS</div>
        <h1 className="korean-serif" style={{
          margin: '16px 0 40px', fontSize: 72, fontWeight: 400,
          letterSpacing: '-0.03em', lineHeight: 1,
          fontFamily: "var(--font-korean-display, serif)",
        }}>
          당신을 <span style={{ fontFamily: 'var(--font-display, serif)', fontStyle: 'italic', color: 'var(--walnut)' }}>측정</span>합니다.
        </h1>

        {/* Step rail */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 40 }}>
          {steps.map((s, i) => (
            <div key={i} style={{
              padding: 20, borderRadius: 4,
              background: i === step - 1 ? 'var(--obsidian)' : 'var(--bg-raised)',
              color: i === step - 1 ? 'var(--ivory)' : 'var(--obsidian)',
              border: '1px solid var(--line)',
              opacity: i > step - 1 ? 0.5 : 1,
              cursor: 'pointer',
            }} onClick={() => setStep(i + 1)}>
              <div style={{ fontFamily: 'var(--font-display, serif)', fontSize: 28, fontStyle: 'italic', fontWeight: 500, color: i === step - 1 ? 'var(--camel-soft)' : 'var(--walnut)' }}>{s.n}</div>
              <div className="korean-sans" style={{ fontSize: 14, fontWeight: 500, marginTop: 8 }}>{s.ko}</div>
              <div style={{ fontSize: 10, fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.1em', opacity: 0.6, marginTop: 2 }}>{s.t.toUpperCase()}</div>
            </div>
          ))}
        </div>

        {/* Step 2 content — measurements */}
        <div style={{ background: 'var(--bg-raised)', border: '1px solid var(--line)', borderRadius: 4, padding: 48, display: 'grid', gridTemplateColumns: '1.2fr 1fr', gap: 48 }}>
          <div>
            <div className="korean-serif" style={{ fontSize: 32, fontWeight: 500, letterSpacing: '-0.02em', fontFamily: "var(--font-korean-display, serif)" }}>
              신체를 수치로 담습니다
            </div>
            <p className="korean-sans" style={{ fontSize: 13, color: 'var(--text-muted)', marginTop: 12, lineHeight: 1.7 }}>
              측정이 정밀할수록 핏 예측이 정밀해집니다. 줄자가 없다면 사진 기반 자동 측정도 가능합니다.
            </p>

            <div style={{ marginTop: 32, display: 'flex', flexDirection: 'column', gap: 20 }}>
              {[
                { k: 'height', label: '키', unit: 'cm', min: 140, max: 200 },
                { k: 'weight', label: '몸무게', unit: 'kg', min: 40, max: 120 },
                { k: 'shoulder', label: '어깨 너비', unit: 'cm', min: 30, max: 60, step: 0.5 },
                { k: 'chest', label: '가슴 둘레', unit: 'cm', min: 70, max: 130 },
                { k: 'waist', label: '허리 둘레', unit: 'cm', min: 60, max: 110 },
              ].map(f => (
                <div key={f.k}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 6 }}>
                    <span className="korean-sans" style={{ fontSize: 13 }}>{f.label}</span>
                    <span style={{ fontFamily: 'var(--font-display, serif)', fontSize: 22, fontWeight: 500, letterSpacing: '-0.02em' }}>
                      {values[f.k]}<span style={{ fontSize: 12, color: 'var(--text-muted)', marginLeft: 4 }}>{f.unit}</span>
                    </span>
                  </div>
                  <input type="range" min={f.min} max={f.max} step={f.step || 1} value={values[f.k]}
                    onChange={e => setValues({ ...values, [f.k]: +e.target.value })}
                    style={{ width: '100%', accentColor: '#B08A5B' }} />
                </div>
              ))}
            </div>

            <div style={{ display: 'flex', gap: 10, marginTop: 32 }}>
              <button className="btn btn-secondary" onClick={() => setStep(Math.max(1, step - 1))}>이전</button>
              <button className="btn btn-primary" style={{ flex: 1 }} onClick={() => setStep(Math.min(4, step + 1))}>다음 단계 →</button>
            </div>
          </div>

          {/* Right — preview body */}
          <div style={{ background: 'var(--obsidian)', color: 'var(--ivory)', borderRadius: 4, padding: 32, display: 'flex', flexDirection: 'column' }}>
            <div style={{ fontSize: 10, fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.15em', opacity: 0.6 }}>
              LIVE BODY MODEL
            </div>
            <div style={{ fontFamily: 'var(--font-display, serif)', fontStyle: 'italic', fontSize: 26, marginTop: 8, fontWeight: 500 }}>
              Your Twin
            </div>
            <div style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', minHeight: 360, position: 'relative' }}>
              <svg viewBox="0 0 200 340" style={{ width: 200, height: 340 }}>
                <g stroke="rgba(245,240,230,0.3)" fill="none" strokeWidth="1.2">
                  <ellipse cx="100" cy="30" rx="20" ry="22"/>
                  <path d={`M 50 70 Q 100 60 150 70`}/>
                  <path d="M 50 70 Q 48 140 60 220"/>
                  <path d="M 150 70 Q 152 140 140 220"/>
                  <path d="M 60 220 L 62 330"/>
                  <path d="M 140 220 L 138 330"/>
                  <path d="M 50 75 L 30 180"/>
                  <path d="M 150 75 L 170 180"/>
                </g>
                <line x1={100 - values.shoulder} y1="70" x2={100 + values.shoulder} y2="70" stroke="var(--camel)" strokeWidth="1.5"/>
                <line x1={100 - values.chest / 2.5} y1="120" x2={100 + values.chest / 2.5} y2="120" stroke="var(--camel)" strokeWidth="1.5" strokeDasharray="2 2"/>
                <line x1={100 - values.waist / 2.5} y1="180" x2={100 + values.waist / 2.5} y2="180" stroke="var(--camel)" strokeWidth="1.5" strokeDasharray="2 2"/>
              </svg>
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, paddingTop: 16, borderTop: '1px solid rgba(245,240,230,0.12)' }}>
              <div><div style={{ fontSize: 9, opacity: 0.5, fontFamily: 'JetBrains Mono, monospace' }}>PREDICTED SIZE</div><div style={{ fontFamily: 'var(--font-display, serif)', fontSize: 24, fontWeight: 500 }}>M</div></div>
              <div><div style={{ fontSize: 9, opacity: 0.5, fontFamily: 'JetBrains Mono, monospace' }}>BODY TYPE</div><div style={{ fontFamily: 'var(--font-display, serif)', fontSize: 20, fontStyle: 'italic' }}>Regular</div></div>
            </div>
          </div>
        </div>

        {/* alt paths */}
        <div style={{ marginTop: 32, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
          <AltMethod icon="📷" title="사진으로 측정" body="전신 사진 한 장. AI가 18개 포인트를 자동 측정합니다." tag="추천" />
          <AltMethod icon="📐" title="줄자로 직접" body="동영상 가이드를 따라 5분. 가장 정확한 방법입니다." />
        </div>
      </section>
      <Footer brand={brand} />
    </main>
  );
}

function AltMethod({ icon, title, body, tag }) {
  return (
    <div style={{ background: 'var(--linen)', border: '1px solid var(--line)', borderRadius: 4, padding: 24, display: 'flex', gap: 20, alignItems: 'flex-start', cursor: 'pointer' }}>
      <div style={{ fontSize: 32 }}>{icon}</div>
      <div style={{ flex: 1 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <div className="korean-serif" style={{ fontSize: 18, fontWeight: 500, fontFamily: "var(--font-korean-display, serif)" }}>{title}</div>
          {tag && <span style={{ padding: '2px 8px', background: 'var(--walnut)', color: 'var(--ivory)', fontSize: 9, letterSpacing: '0.12em', fontFamily: 'JetBrains Mono, monospace', borderRadius: 2 }}>{tag}</span>}
        </div>
        <div className="korean-sans" style={{ fontSize: 12, color: 'var(--text-muted)', marginTop: 6, lineHeight: 1.6 }}>{body}</div>
      </div>
      <div style={{ fontSize: 20 }}>→</div>
    </div>
  );
}

// ═══ ATELIER — simple showcase ═══
function Atelier({ onNav, brand }) {
  const looks = [
    { name: 'Morning Ritual', kr: '기록된 아침', img: IMG.look1, vol: 'VOL.01', mood: 'Quiet Morning' },
    { name: 'Galerie Hours',  kr: '갤러리 시간',  img: IMG.look2, vol: 'VOL.02', mood: 'Curator Mode' },
    { name: 'Soft Machine',   kr: '부드러운 기계', img: IMG.look3, vol: 'VOL.03', mood: 'Urban Tech' },
    { name: 'Weekend Essai',  kr: '주말의 에세이', img: IMG.look4, vol: 'VOL.04', mood: 'Loose Tailor' },
    { name: 'Tokyo Drift',    kr: '도쿄의 드리프트', img: IMG.look5, vol: 'VOL.05', mood: 'Night Edit' },
    { name: 'Quiet Luxury',   kr: '조용한 럭셔리', img: IMG.look6, vol: 'VOL.06', mood: 'Cashmere Hour' },
  ];
  return (
    <main>
      <TopBar active="atelier" onNav={onNav} brand={brand} />
      <section style={{ padding: '48px 48px 0', maxWidth: 1600, margin: '0 auto' }}>
        <div className="eyebrow">THE ATELIER · EDITORIAL ARCHIVE</div>
        <h1 className="korean-serif" style={{
          margin: '16px 0 40px', fontSize: 88, fontWeight: 400,
          letterSpacing: '-0.035em', lineHeight: 0.95,
          fontFamily: "var(--font-korean-display, serif)",
        }}>
          <span style={{ fontFamily: 'var(--font-display, serif)', fontStyle: 'italic', color: 'var(--walnut)' }}>Atelier</span>,<br/>
          큐레이터가 모은 옷들.
        </h1>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 24 }}>
          {looks.map((l, idx) => (
            <div key={idx} style={{ background: 'var(--bg-raised)', border: '1px solid var(--line)', borderRadius: 4, overflow: 'hidden', cursor: 'pointer' }}>
              <div style={{ aspectRatio: '4/5', background: '#2a2623', position: 'relative', overflow: 'hidden' }}>
                <img src={l.img} alt="" style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover', filter: 'grayscale(0.1) contrast(1.02)' }}/>
                <div style={{ position: 'absolute', top: 14, left: 14, padding: '3px 8px', background: 'rgba(13,12,11,0.55)', backdropFilter: 'blur(6px)', color: 'var(--ivory)', fontSize: 9, fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.14em', borderRadius: 2 }}>
                  {l.vol} · 2026
                </div>
                <div style={{ position: 'absolute', bottom: 18, left: 18, right: 18 }}>
                  <div style={{ fontFamily: 'var(--font-display, serif)', fontStyle: 'italic', fontSize: 14, color: 'var(--camel-soft)', fontWeight: 500, letterSpacing: '0.02em', textShadow: '0 1px 6px rgba(0,0,0,0.6)' }}>
                    — {l.mood}
                  </div>
                </div>
              </div>
              <div style={{ padding: '20px 24px', display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end' }}>
                <div>
                  <div style={{ fontFamily: 'var(--font-display, serif)', fontStyle: 'italic', fontSize: 26, fontWeight: 500, letterSpacing: '-0.01em' }}>{l.name}</div>
                  <div className="korean-sans" style={{ fontSize: 13, color: 'var(--text-muted)', marginTop: 2 }}>{l.kr}</div>
                </div>
                <div style={{ fontSize: 20 }}>→</div>
              </div>
            </div>
          ))}
        </div>
      </section>
      <Footer brand={brand} />
    </main>
  );
}

Object.assign(window, { Product, Onboarding, Atelier });
