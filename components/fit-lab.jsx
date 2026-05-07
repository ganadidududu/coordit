// Coordit — Fit Lab (핏 분석) — redesigned hero + editorial layout

function FitLab({ onNav, brand }) {
  const [selectedSize, setSelectedSize] = useState('M');
  const sizes = ['XS', 'S', 'M', 'L', 'XL'];

  const regions = [
    { part: '어깨', en: 'SHOULDER', state: 'Tight',   color: 'var(--fit-tight)',   v: '-1.5', pct: 85, top: '14%' },
    { part: '가슴', en: 'CHEST',    state: 'Perfect', color: 'var(--fit-perfect)', v: '+4.0', pct: 65, top: '28%' },
    { part: '허리', en: 'WAIST',    state: 'Loose',   color: 'var(--fit-loose)',   v: '+6.0', pct: 45, top: '46%' },
    { part: '총장', en: 'LENGTH',   state: 'Perfect', color: 'var(--fit-perfect)', v: '+1.5', pct: 55, top: '68%' },
  ];

  return (
    <main>
      <TopBar active="fit" onNav={onNav} brand={brand} />

      {/* ═══ HERO — Big Editorial Headline ═══ */}
      <section style={{ padding: '56px 48px 32px', maxWidth: 1600, margin: '0 auto' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', marginBottom: 20 }}>
          <div className="eyebrow">
            COORDIT FIT FORENSICS · REPORT N°002
          </div>
          <div className="eyebrow" style={{ color: 'var(--walnut)' }}>
            2026.04.23 · LIVE SCAN
          </div>
        </div>

        <h1 className="korean-serif" style={{
          margin: 0, fontSize: 128, fontWeight: 400,
          letterSpacing: '-0.045em', lineHeight: 0.9,
          fontFamily: "var(--font-korean-display, serif)",
        }}>
          핏을, <span style={{ fontFamily: 'var(--font-display, serif)', fontStyle: 'italic', color: 'var(--walnut)', fontWeight: 500 }}>해부</span>합니다.
        </h1>
        <p className="korean-sans" style={{ margin: '28px 0 0', fontSize: 18, lineHeight: 1.6, color: 'var(--text-muted)', maxWidth: 760 }}>
          당신의 실측 체형 데이터와 브랜드 사이즈 표를 AI가 교차 분석합니다. <span style={{ color: 'var(--walnut)', fontStyle: 'italic', fontFamily: 'var(--font-display, serif)' }}>±0.3cm</span>의 정밀도로.
        </p>
      </section>

      {/* ═══ FORENSIC SCAN — full-bleed editorial ═══ */}
      <section style={{ padding: '40px 48px 0', maxWidth: 1600, margin: '0 auto' }}>
        <div style={{
          background: 'var(--obsidian)', color: 'var(--ivory)',
          borderRadius: 4, overflow: 'hidden',
          display: 'grid', gridTemplateColumns: '1.3fr 1fr',
          minHeight: 780,
        }}>
          {/* LEFT: Technical body-map dossier */}
          <div style={{ position: 'relative', background: '#0a0908', overflow: 'hidden' }}>
            {/* Blueprint background */}
            <div style={{
              position: 'absolute', inset: 0,
              backgroundImage: `
                linear-gradient(rgba(180,138,91,0.04) 1px, transparent 1px),
                linear-gradient(90deg, rgba(180,138,91,0.04) 1px, transparent 1px),
                linear-gradient(rgba(180,138,91,0.08) 1px, transparent 1px),
                linear-gradient(90deg, rgba(180,138,91,0.08) 1px, transparent 1px)
              `,
              backgroundSize: '20px 20px, 20px 20px, 100px 100px, 100px 100px',
            }}/>
            {/* Radial glow */}
            <div style={{ position: 'absolute', inset: 0,
              background: 'radial-gradient(ellipse at 50% 42%, rgba(212,184,150,0.08) 0%, transparent 60%)' }}/>

            {/* Central body-map — 3D mannequin (Three.js) with SVG fallback */}
            {window.THREE && window.Body3D ? (
              <Body3D width={540} height={760} />
            ) : (
              <svg viewBox="0 0 400 720" preserveAspectRatio="xMidYMid meet"
                style={{ position: 'absolute', inset: 0, width: '100%', height: '100%' }}>
                <defs>
                  <linearGradient id="bodyFillFallback" x1="0" y1="0" x2="1" y2="1">
                    <stop offset="0%"  stopColor="#2a2420"/>
                    <stop offset="100%" stopColor="#0f0c0a"/>
                  </linearGradient>
                </defs>
                {/* Simple silhouette fallback */}
                <ellipse cx="200" cy="75" rx="22" ry="27" fill="url(#bodyFillFallback)" stroke="rgba(212,184,150,0.3)" strokeWidth="0.7"/>
                <path d="M 188 118 L 130 152 Q 112 162 108 182 L 104 260 Q 102 360 108 450 L 130 450 L 135 280 L 140 260 Q 148 254 152 265 L 150 450 L 250 450 L 248 265 Q 252 254 260 260 L 265 280 L 270 450 L 292 450 Q 298 360 296 260 L 292 182 Q 288 162 270 152 L 212 118 Z"
                  fill="url(#bodyFillFallback)" stroke="rgba(212,184,150,0.35)" strokeWidth="0.8"/>
                <text x="200" y="680" textAnchor="middle" fill="rgba(212,184,150,0.5)" fontSize="10" fontFamily="JetBrains Mono, monospace" letterSpacing="2">LOADING 3D MANNEQUIN…</text>
              </svg>
            )}

            {/* Pulsing scan line */}
            <div style={{
              position: 'absolute', left: '10%', right: '10%', top: '50%',
              height: 1, background: 'linear-gradient(90deg, transparent, #D4B896, transparent)',
              opacity: 0.6, boxShadow: '0 0 12px #D4B896',
              animation: 'coordit-scan 4s ease-in-out infinite',
            }}/>
            <style>{`
              @keyframes coordit-scan {
                0%, 100% { top: 18%; opacity: 0.3; }
                50% { top: 78%; opacity: 0.7; }
              }
            `}</style>
            {/* Measurement lines — horizontal rulers across body */}
            {false && regions.map((r, i) => (
              <div key={r.en} style={{
                position: 'absolute', left: 0, right: 0, top: r.top,
                pointerEvents: 'none',
              }}>
                {/* Full-width dashed line */}
                <div style={{
                  position: 'absolute', left: 0, right: 0, top: '50%',
                  height: 1,
                  backgroundImage: `repeating-linear-gradient(90deg, ${r.color} 0 6px, transparent 6px 14px)`,
                  opacity: 0.7,
                }}/>
                {/* Small ticks */}
                <div style={{
                  position: 'absolute', left: '28%', top: '50%', transform: 'translateY(-50%)',
                  width: 8, height: 8, borderRadius: '50%', background: r.color,
                  boxShadow: `0 0 0 2px rgba(13,12,11,0.8), 0 0 20px ${r.color}88`,
                }}/>
                <div style={{
                  position: 'absolute', right: '28%', top: '50%', transform: 'translateY(-50%)',
                  width: 8, height: 8, borderRadius: '50%', background: r.color,
                  boxShadow: `0 0 0 2px rgba(13,12,11,0.8), 0 0 20px ${r.color}88`,
                }}/>

                {/* Label pill */}
                <div style={{
                  position: 'absolute',
                  left: i % 2 === 0 ? 24 : 'auto',
                  right: i % 2 === 0 ? 'auto' : 24,
                  top: '50%', transform: 'translateY(-50%)',
                  background: 'rgba(13,12,11,0.75)',
                  backdropFilter: 'blur(12px)',
                  border: `1px solid ${r.color}`,
                  padding: '8px 14px', borderRadius: 2,
                  minWidth: 140,
                }}>
                  <div style={{ fontSize: 9, fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.14em', color: 'rgba(245,240,230,0.55)' }}>
                    {r.en}
                  </div>
                  <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, marginTop: 2 }}>
                    <span style={{ fontFamily: 'var(--font-display, serif)', fontStyle: 'italic', fontSize: 18, fontWeight: 600, color: r.color }}>
                      {r.state}
                    </span>
                    <span style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 11, color: 'var(--ivory)' }}>
                      {r.v}cm
                    </span>
                  </div>
                </div>
              </div>
            ))}

            {/* TOP-LEFT: garment meta */}
            <div style={{ position: 'absolute', top: 32, left: 32, zIndex: 5 }}>
              <div style={{ fontSize: 10, fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.18em', opacity: 0.65 }}>
                GARMENT
              </div>
              <div className="korean-sans" style={{ fontSize: 15, marginTop: 6, fontWeight: 500 }}>
                옵시디언 모토 재킷 II
              </div>
              <div style={{ fontSize: 11, fontFamily: 'JetBrains Mono, monospace', marginTop: 4, opacity: 0.6, letterSpacing: '0.1em' }}>
                SIZE M · SKU 0142
              </div>
            </div>

            {/* TOP-RIGHT: live indicator */}
            <div style={{ position: 'absolute', top: 32, right: 32, zIndex: 5,
              display: 'flex', alignItems: 'center', gap: 8,
              padding: '6px 12px',
              background: 'rgba(13,12,11,0.6)', backdropFilter: 'blur(10px)',
              border: '1px solid rgba(245,240,230,0.15)',
              borderRadius: 2,
              fontSize: 10, fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.15em',
            }}>
              <span style={{ width: 6, height: 6, borderRadius: '50%', background: 'var(--fit-perfect)', boxShadow: '0 0 8px var(--fit-perfect)' }}/>
              LIVE · ±0.3cm
            </div>

            {/* BOTTOM: Editorial caption */}
            <div style={{ position: 'absolute', bottom: 32, left: 32, right: 32, zIndex: 5 }}>
              <div style={{ fontSize: 10, fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.2em', opacity: 0.55, marginBottom: 6 }}>
                FORENSIC FIT SCAN
              </div>
              <div style={{
                fontFamily: 'var(--font-display, serif)', fontStyle: 'italic',
                fontSize: 52, fontWeight: 500, letterSpacing: '-0.02em', lineHeight: 1,
              }}>
                A body, <span style={{ color: 'var(--camel-soft)' }}>mapped</span>.
              </div>
            </div>

            {/* Corner registration marks */}
            {['top-left','top-right','bottom-left','bottom-right'].map(c => {
              const pos = {
                'top-left':     { top: 16, left: 16, borderTop: '1px solid', borderLeft: '1px solid' },
                'top-right':    { top: 16, right: 16, borderTop: '1px solid', borderRight: '1px solid' },
                'bottom-left':  { bottom: 16, left: 16, borderBottom: '1px solid', borderLeft: '1px solid' },
                'bottom-right': { bottom: 16, right: 16, borderBottom: '1px solid', borderRight: '1px solid' },
              }[c];
              return <div key={c} style={{ position: 'absolute', width: 18, height: 18, borderColor: 'var(--camel-soft)', zIndex: 4, ...pos }}/>;
            })}
          </div>

          {/* RIGHT: AI Verdict + size */}
          <div style={{ padding: 48, display: 'flex', flexDirection: 'column', justifyContent: 'space-between', gap: 32 }}>
            {/* Verdict */}
            <div>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 }}>
                <div style={{ fontSize: 10, fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.18em', color: 'var(--camel-soft)' }}>
                  ✦ COORDIT AI · VERDICT
                </div>
                <div style={{
                  padding: '4px 12px', borderRadius: 2,
                  background: 'var(--fit-perfect)', color: 'var(--ivory)',
                  fontSize: 9, fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.14em', fontWeight: 500,
                }}>PERFECT · 92/100</div>
              </div>

              <h2 className="korean-serif" style={{
                margin: 0, fontSize: 44, fontWeight: 400, lineHeight: 1.15,
                letterSpacing: '-0.025em',
                fontFamily: "var(--font-korean-display, serif)",
              }}>
                이 옷은 당신에게<br/>
                <span style={{ fontFamily: 'var(--font-display, serif)', fontStyle: 'italic', color: 'var(--camel-soft)', fontWeight: 500 }}>
                  Size M
                </span>으로 완성됩니다.
              </h2>

              <p className="korean-sans" style={{ margin: '20px 0 0', fontSize: 14, lineHeight: 1.7, color: 'rgba(245,240,230,0.75)' }}>
                어깨 라인이 프레임을 잡아주고, 허리에 4cm 여유가 생겨 레이어링이 가능합니다.
                구조적 테일러링을 의도한 브랜드 설계로 추정됩니다.
              </p>

              <div style={{ marginTop: 28, padding: '16px 20px', background: 'rgba(245,240,230,0.04)', borderRadius: 2, border: '1px solid rgba(245,240,230,0.08)' }}>
                <div style={{ fontSize: 10, fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.14em', opacity: 0.55, marginBottom: 10 }}>
                  PREDICTION CONFIDENCE
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                  <div style={{ flex: 1, height: 4, background: 'rgba(245,240,230,0.1)', borderRadius: 2, overflow: 'hidden' }}>
                    <div style={{ width: '94%', height: '100%', background: 'linear-gradient(90deg, var(--camel) 0%, var(--camel-soft) 100%)' }}/>
                  </div>
                  <span style={{ fontFamily: 'var(--font-display, serif)', fontSize: 32, fontWeight: 500, color: 'var(--camel-soft)', lineHeight: 1 }}>
                    94<span style={{ fontSize: 16, opacity: 0.5 }}>%</span>
                  </span>
                </div>
              </div>
            </div>

            {/* Size picker */}
            <div>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 14 }}>
                <div style={{ fontSize: 10, fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.14em', opacity: 0.6 }}>
                  SIZE · AI PICK IS M
                </div>
                <div className="korean-sans" style={{ fontSize: 11, color: 'var(--camel-soft)' }}>
                  사이즈 변경 시 실시간 재분석
                </div>
              </div>
              <div style={{ display: 'flex', gap: 6, marginBottom: 20 }}>
                {sizes.map(s => (
                  <button
                    key={s}
                    onClick={() => setSelectedSize(s)}
                    style={{
                      flex: 1, padding: '16px 0', position: 'relative',
                      border: selectedSize === s ? '1px solid var(--camel-soft)' : '1px solid rgba(245,240,230,0.15)',
                      background: selectedSize === s ? 'var(--camel)' : 'transparent',
                      color: selectedSize === s ? 'var(--obsidian)' : 'var(--ivory)',
                      fontFamily: 'var(--font-display, serif)', fontSize: 20, fontWeight: 500,
                      cursor: 'pointer', borderRadius: 2, transition: 'all 0.15s',
                    }}
                  >
                    {s}
                    {s === 'M' && (
                      <div style={{ position: 'absolute', top: -8, right: -4, padding: '2px 6px', background: 'var(--camel-soft)', color: 'var(--obsidian)', fontSize: 8, fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.1em', borderRadius: 2 }}>
                        AI
                      </div>
                    )}
                  </button>
                ))}
              </div>
              <div style={{ display: 'flex', gap: 10 }}>
                <button className="btn btn-camel" style={{ flex: 1 }}>장바구니에 담기</button>
                <button style={{
                  padding: '14px 18px',
                  border: '1px solid rgba(245,240,230,0.2)',
                  background: 'transparent', color: 'var(--ivory)',
                  borderRadius: 8, cursor: 'pointer', fontSize: 14,
                }}>♡</button>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* ═══ VITALS — 4-card quick read ═══ */}
      <section style={{ padding: '40px 48px 0', maxWidth: 1600, margin: '0 auto' }}>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16 }}>
          {[
            { label: 'OVERALL FIT', value: '92', unit: '/100', sub: 'Fit Forensics Score', accent: 'var(--fit-perfect)' },
            { label: 'BRAND MATCH', value: 'A+',             sub: '체형 유형 일치도',      accent: 'var(--walnut)' },
            { label: 'SILHOUETTE',  value: 'Structured',     italic: true, sub: '구조적 실루엣',        accent: 'var(--camel)' },
            { label: 'AUTHORITY',   value: '94', unit: '%', sub: '예측 신뢰도',           accent: 'var(--obsidian)' },
          ].map((v, i) => (
            <div key={i} style={{
              background: i === 3 ? 'var(--obsidian)' : 'var(--bg-raised)',
              color: i === 3 ? 'var(--ivory)' : 'var(--obsidian)',
              border: '1px solid var(--line)',
              borderRadius: 4, padding: 24, minHeight: 130,
              display: 'flex', flexDirection: 'column', justifyContent: 'space-between',
            }}>
              <div style={{ fontSize: 10, fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.15em', color: i === 3 ? 'rgba(245,240,230,0.55)' : 'var(--text-muted)' }}>
                {v.label}
              </div>
              <div>
                <div style={{
                  fontFamily: 'var(--font-display, serif)',
                  fontSize: v.italic ? 36 : 52, fontWeight: 500,
                  fontStyle: v.italic ? 'italic' : 'normal',
                  letterSpacing: '-0.03em', lineHeight: 1,
                  color: v.accent,
                }}>
                  {v.value}{v.unit && <span style={{ fontSize: 18, opacity: 0.6, marginLeft: 2 }}>{v.unit}</span>}
                </div>
                <div className="korean-sans" style={{ fontSize: 12, marginTop: 6, color: i === 3 ? 'rgba(245,240,230,0.65)' : 'var(--text-muted)' }}>
                  {v.sub}
                </div>
              </div>
            </div>
          ))}
        </div>
      </section>

      {/* ═══ DETAILED TABLE ═══ */}
      <section style={{ padding: '48px 48px 0', maxWidth: 1600, margin: '0 auto' }}>
        <div style={{ background: 'var(--bg-raised)', border: '1px solid var(--line)', borderRadius: 4, padding: '40px 40px 24px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', marginBottom: 32 }}>
            <div>
              <div className="eyebrow">DOSSIER · N°002 · DETAILED MEASUREMENTS</div>
              <div className="korean-serif" style={{ fontSize: 40, marginTop: 12, fontWeight: 500, letterSpacing: '-0.02em', fontFamily: "var(--font-korean-display, serif)", lineHeight: 1.1 }}>
                내 체형 × <span style={{ fontFamily: 'var(--font-display, serif)', fontStyle: 'italic', color: 'var(--walnut)' }}>가먼트</span> 교차 분석
              </div>
              <div className="korean-sans" style={{ fontSize: 13, color: 'var(--text-muted)', marginTop: 6 }}>
                단위 cm · 브랜드 공식 사이즈 표 기준 (Ref. Brand SS26 #014)
              </div>
            </div>
            <div style={{ display: 'flex', gap: 10 }}>
              <button className="btn btn-secondary" style={{ fontSize: 12, padding: '10px 18px' }}>PDF 리포트</button>
              <button className="btn btn-secondary" style={{ fontSize: 12, padding: '10px 18px' }}>사이즈 표 원문 ↗</button>
            </div>
          </div>

          <div style={{
            display: 'grid',
            gridTemplateColumns: '2fr 1.2fr 1.2fr 1.2fr 1.5fr 1fr',
            fontSize: 13,
          }}>
            {['측정 부위', '내 사이즈', '가먼트 (M)', 'Δ', '상태', '신뢰도'].map(h => (
              <div key={h} style={{
                padding: '14px 16px', borderBottom: '1px solid var(--line-strong)',
                fontFamily: 'JetBrains Mono, monospace', fontSize: 10,
                letterSpacing: '0.12em', textTransform: 'uppercase', color: 'var(--text-muted)',
              }}>{h}</div>
            ))}
            {[
              { part: '어깨 너비', mine: 44.5, g: 43.0, v: '-1.5', state: 'Tight',   color: 'var(--fit-tight)',   conf: 97 },
              { part: '가슴 둘레', mine: 98.0, g: 102.0, v: '+4.0', state: 'Perfect', color: 'var(--fit-perfect)', conf: 94 },
              { part: '허리 둘레', mine: 82.0, g: 88.0, v: '+6.0', state: 'Loose',   color: 'var(--fit-loose)',   conf: 96 },
              { part: '총장',      mine: 72.0, g: 73.5, v: '+1.5', state: 'Perfect', color: 'var(--fit-perfect)', conf: 98 },
              { part: '소매 길이', mine: 62.5, g: 63.0, v: '+0.5', state: 'Perfect', color: 'var(--fit-perfect)', conf: 93 },
              { part: '밑단 너비', mine: 52.0, g: 55.0, v: '+3.0', state: 'Perfect', color: 'var(--fit-perfect)', conf: 91 },
            ].map((r, i) => (
              <React.Fragment key={i}>
                <div style={flCell(i, true)} className="korean-sans">{r.part}</div>
                <div style={{ ...flCell(i), fontFamily: 'var(--font-display, serif)', fontSize: 20, fontWeight: 500 }}>{r.mine}</div>
                <div style={{ ...flCell(i), fontFamily: 'var(--font-display, serif)', fontSize: 20, fontWeight: 500, color: 'var(--text-muted)' }}>{r.g}</div>
                <div style={{ ...flCell(i), fontFamily: 'JetBrains Mono, monospace', fontSize: 14, color: r.color, fontWeight: 500 }}>{r.v}</div>
                <div style={flCell(i)}>
                  <span style={{
                    padding: '5px 12px', borderRadius: 999,
                    background: `${r.color}1a`, color: r.color,
                    fontSize: 12, fontFamily: 'var(--font-display, serif)', fontStyle: 'italic', fontWeight: 600,
                  }}>{r.state}</span>
                </div>
                <div style={{ ...flCell(i), display: 'flex', alignItems: 'center', gap: 8 }}>
                  <div style={{ flex: 1, height: 2, background: 'var(--line)', borderRadius: 1 }}>
                    <div style={{ width: `${r.conf}%`, height: '100%', background: 'var(--camel)' }}/>
                  </div>
                  <span style={{ fontSize: 10, fontFamily: 'JetBrains Mono, monospace', color: 'var(--text-muted)' }}>{r.conf}</span>
                </div>
              </React.Fragment>
            ))}
          </div>

          <div style={{
            marginTop: 28, padding: '18px 22px', borderRadius: 2,
            background: 'var(--obsidian)', color: 'var(--linen)',
            display: 'flex', gap: 20, alignItems: 'center',
            fontSize: 13,
          }}>
            <span style={{ fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.14em', color: 'var(--camel-soft)', whiteSpace: 'nowrap' }}>
              ✦ AI NOTE
            </span>
            <span className="korean-sans" style={{ lineHeight: 1.55, opacity: 0.9 }}>
              어깨 <span style={{ color: 'var(--camel-soft)', fontWeight: 500 }}>-1.5cm 타이트함</span>은 구조적 테일러링을 의도한 브랜드 설계. 캐주얼 무드를 원한다면 <span style={{ fontStyle: 'italic', fontFamily: 'var(--font-display, serif)' }}>Size L</span>을 고려하세요.
            </span>
          </div>
        </div>
      </section>

      {/* ═══ RELATED TRY-ONS ═══ */}
      <section style={{ padding: '64px 48px 0', maxWidth: 1600, margin: '0 auto' }}>
        <div className="eyebrow" style={{ marginBottom: 12 }}>COMPARE · 유사 핏 가먼트</div>
        <h3 className="korean-serif" style={{ margin: '0 0 28px', fontSize: 40, fontWeight: 500, letterSpacing: '-0.02em', fontFamily: "var(--font-korean-display, serif)" }}>
          같은 체형 · 다른 실루엣
        </h3>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16 }}>
          {[
            { src: IMG.coat, name: '헤리티지 카멜 코트', fit: 'Perfect', size: 'M', score: 95 },
            { src: IMG.knit, name: '클라우드 캐시미어 니트', fit: 'Loose', size: 'S', score: 88 },
            { src: IMG.trouser, name: '프리시전 플리츠 트라우저', fit: 'Perfect', size: 'M', score: 96 },
            { src: IMG.shirt, name: '아키텍처럴 포플린 셔츠', fit: 'Tight', size: 'L', score: 82 },
          ].map((x, i) => (
            <div key={i} style={{ background: 'var(--bg-raised)', border: '1px solid var(--line)', borderRadius: 4, overflow: 'hidden', cursor: 'pointer' }}>
              <div style={{ aspectRatio: '4/5', background: '#2a2623', position: 'relative' }}>
                <img src={x.src} alt="" style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover', filter: 'grayscale(0.15)' }}/>
                <div style={{ position: 'absolute', top: 12, left: 12, padding: '4px 10px', background: 'rgba(245,240,230,0.92)', fontSize: 9, fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.1em', borderRadius: 2, color: 'var(--walnut)' }}>
                  FIT · {x.fit.toUpperCase()}
                </div>
                <div style={{ position: 'absolute', bottom: 12, right: 12, fontFamily: 'var(--font-display, serif)', fontStyle: 'italic', fontSize: 32, color: 'var(--ivory)', fontWeight: 600, textShadow: '0 1px 4px rgba(0,0,0,0.5)' }}>
                  {x.size}
                </div>
              </div>
              <div style={{ padding: '14px 16px' }}>
                <div className="korean-sans" style={{ fontSize: 13, fontWeight: 500 }}>{x.name}</div>
                <div style={{ marginTop: 10, display: 'flex', alignItems: 'center', gap: 8 }}>
                  <div style={{ flex: 1, height: 2, background: 'var(--line)', borderRadius: 1 }}>
                    <div style={{ width: `${x.score}%`, height: '100%', background: 'var(--camel)' }}/>
                  </div>
                  <span style={{ fontFamily: 'var(--font-display, serif)', fontSize: 14, fontWeight: 500, color: 'var(--walnut)' }}>{x.score}</span>
                </div>
              </div>
            </div>
          ))}
        </div>
      </section>

      <Footer brand={brand} />
    </main>
  );
}

const flCell = (i, first) => ({
  padding: '18px 16px',
  borderBottom: '1px solid var(--line)',
  display: 'flex', alignItems: 'center',
  fontWeight: first ? 500 : 400,
});

window.FitLab = FitLab;
