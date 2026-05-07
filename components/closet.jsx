// Coordit — Closet (나의 옷장)

function Closet({ onNav, brand }) {
  const [filter, setFilter] = useState('전체');
  const filters = ['전체', '상의', '하의', '아우터', '원피스', '액세서리'];

  const items = [
    { title: '애쥬어 미드나잇 가운', sub: '포멀 웨어 · 이브닝', tag: 'LUX SILK', acc: 98.4, c: '#3F4E5E', img: IMG.dress },
    { title: '프리시전 플리츠 트라우저', sub: '비즈니스 캐주얼', tag: 'WOOL', acc: 99.1, c: '#2D2A27', img: IMG.trouser },
    { title: '클라우드 캐시미어 니트', sub: '니트웨어', tag: 'CASHMERE', acc: 97.8, c: '#E8DFC9', img: IMG.knit },
    { title: '헤리티지 카멜 코트', sub: '아우터', tag: 'HERO PIECE', acc: 99.5, c: '#8F6F45', img: IMG.coat },
    { title: '아키텍처럴 포플린 셔츠', sub: '셔츠 · 데일리', tag: 'ORGANIC', acc: 98.9, c: '#F5F0E6', img: IMG.shirt },
    { title: '생지 데님 팬츠', sub: '데님', tag: 'SELVEDGE', acc: 98.2, c: '#3F4E5E', img: IMG.denim },
    { title: '에센셜 화이트 스니커즈', sub: '슈즈', tag: 'LEATHER', acc: 96.5, c: '#F5F0E6', img: IMG.sneaker },
    { title: '옵시디언 모토 재킷', sub: '아우터 · 레더', tag: 'RECYCLED', acc: 99.2, c: '#1C1B1A', img: IMG.moto },
  ];

  return (
    <main>
      <TopBar active="closet" onNav={onNav} brand={brand} />

      <section style={{ padding: '56px 48px 0', maxWidth: 1600, margin: '0 auto' }}>
        {/* Breadcrumb */}
        <div className="eyebrow" style={{ marginBottom: 24 }}>
          HOME / CLOSET / ALL
        </div>

        {/* Header row */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', marginBottom: 40 }}>
          <div>
            <h1 className="korean-serif" style={{
              margin: 0, fontSize: 72, fontWeight: 400,
              letterSpacing: '-0.03em', lineHeight: 1,
              fontFamily: "var(--font-korean-display, serif)",
            }}>
              나의 <span style={{ fontFamily: 'var(--font-display, serif)', fontStyle: 'italic', color: 'var(--walnut)' }}>옷장</span>
            </h1>
            <div style={{ fontSize: 14, color: 'var(--text-muted)', marginTop: 12, fontFamily: "var(--font-korean, 'Pretendard', sans-serif)" }}>
              AI로 큐레이션된 <span style={{ color: 'var(--walnut)', fontWeight: 500 }}>324</span>개의 아이템 · 마지막 업데이트 오늘 07:42
            </div>
          </div>
          <div style={{ display: 'flex', gap: 10 }}>
            <button className="btn btn-secondary" onClick={() => onNav('onboarding')}>핏 프로필</button>
            <button className="btn btn-primary">+ 새 의류 등록</button>
          </div>
        </div>

        {/* Filter bar */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '20px 0', borderTop: '1px solid var(--line)', borderBottom: '1px solid var(--line)' }}>
          <div style={{ display: 'flex', gap: 8 }}>
            {filters.map(f => (
              <Chip key={f} active={filter === f} onClick={() => setFilter(f)}>{f}</Chip>
            ))}
          </div>
          <div style={{ display: 'flex', gap: 20, alignItems: 'center', fontSize: 12, color: 'var(--text-muted)', fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.08em' }}>
            <span>VIEW: GRID</span>
            <span>SORT: 최근순 ↓</span>
          </div>
        </div>
      </section>

      <section style={{ padding: '40px 48px 0', maxWidth: 1600, margin: '0 auto', display: 'grid', gridTemplateColumns: '1fr 340px', gap: 40 }}>
        {/* Grid */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 20 }}>
          {items.map((it, i) => (
            <div key={i} onClick={() => i === 7 && onNav('product')} style={{
              cursor: i === 7 ? 'pointer' : 'default',
            }}>
              <ClosetCard {...it} featured={i === 7} />
            </div>
          ))}
          {/* Add new */}
          <div style={{
            border: '1px dashed var(--line-strong)',
            borderRadius: 4,
            minHeight: 440,
            display: 'flex', flexDirection: 'column',
            alignItems: 'center', justifyContent: 'center',
            gap: 12, cursor: 'pointer',
            color: 'var(--text-muted)',
            transition: 'all 0.2s',
          }}
          onMouseEnter={e => { e.currentTarget.style.borderColor = 'var(--walnut)'; e.currentTarget.style.color = 'var(--walnut)'; }}
          onMouseLeave={e => { e.currentTarget.style.borderColor = 'var(--line-strong)'; e.currentTarget.style.color = 'var(--text-muted)'; }}
          >
            <div style={{ fontSize: 28, fontFamily: 'var(--font-display, serif)', fontStyle: 'italic' }}>+</div>
            <div className="korean-sans" style={{ fontSize: 13 }}>새 의류 등록</div>
            <div style={{ fontSize: 10, fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.1em', opacity: 0.6 }}>
              PHOTO · URL · SCAN
            </div>
          </div>
        </div>

        {/* Right sidebar — style dossier */}
        <aside style={{ display: 'flex', flexDirection: 'column', gap: 20, position: 'sticky', top: 100, alignSelf: 'flex-start' }}>
          {/* Today's Pick */}
          <div style={{
            background: 'var(--obsidian)', color: 'var(--ivory)',
            padding: 24, borderRadius: 4,
          }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
              <div>
                <div style={{ fontSize: 10, fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.15em', opacity: 0.6 }}>
                  COORDIT AI · 07:42
                </div>
                <div style={{ fontFamily: 'var(--font-display, serif)', fontStyle: 'italic', fontSize: 28, marginTop: 8, fontWeight: 500, letterSpacing: '-0.01em' }}>
                  Today's Edit
                </div>
              </div>
              <div style={{ fontSize: 10, opacity: 0.6, fontFamily: 'JetBrains Mono, monospace' }}>18°C</div>
            </div>
            <p className="korean-sans" style={{ margin: '16px 0 20px', fontSize: 13, lineHeight: 1.6, opacity: 0.85 }}>
              헤리티지 카멜 코트를 중심으로 무드 레이어링. 생지 데님과 화이트 스니커즈가 캐주얼 밸런스를 잡아줍니다.
            </p>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 6, marginBottom: 16 }}>
              {['#8F6F45', '#3F4E5E', '#F5F0E6'].map(c => (
                <div key={c} style={{ aspectRatio: '1', background: c, borderRadius: 2 }} />
              ))}
            </div>
            <button className="btn btn-camel" style={{ width: '100%' }} onClick={() => onNav('styling')}>
              오늘의 코디 보기 →
            </button>
          </div>

          {/* Wardrobe Analytics */}
          <div style={{ background: 'var(--bg-raised)', border: '1px solid var(--line)', padding: 24, borderRadius: 4 }}>
            <div style={{ fontSize: 10, fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.15em', color: 'var(--text-muted)' }}>
              WARDROBE DOSSIER
            </div>
            <div className="korean-serif" style={{ fontSize: 20, marginTop: 8, fontWeight: 500, fontFamily: "var(--font-korean-display, serif)" }}>
              스타일 데이터
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginTop: 20 }}>
              <MiniStat label="옷장 가치" value="₩16.5" unit="M" />
              <MiniStat label="착용당 비용" value="₩5,400" />
              <MiniStat label="핏 정확도" value="99.1" unit="%" accent="var(--fit-perfect)" />
              <MiniStat label="지속가능 점수" value="A" unit="-" accent="var(--walnut)" />
            </div>

            <div style={{ marginTop: 20, paddingTop: 20, borderTop: '1px solid var(--line)' }}>
              <div style={{ fontSize: 11, color: 'var(--text-muted)', marginBottom: 12, fontFamily: "var(--font-korean, 'Pretendard', sans-serif)" }}>
                카테고리 분포
              </div>
              <div style={{ display: 'flex', gap: 4, height: 48, borderRadius: 2, overflow: 'hidden' }}>
                {[
                  { c: '#8F6F45', w: 28, l: '상의' },
                  { c: '#3F4E5E', w: 22, l: '하의' },
                  { c: '#4A3826', w: 18, l: '아우터' },
                  { c: '#D4B896', w: 16, l: '원피스' },
                  { c: '#5B7355', w: 10, l: '신발' },
                  { c: '#7A6FA0', w: 6, l: '기타' },
                ].map(b => (
                  <div key={b.l} style={{ flex: b.w, background: b.c, display: 'flex', alignItems: 'flex-end', padding: 4, fontSize: 8, color: '#fff', fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.05em' }}>
                    {b.w}%
                  </div>
                ))}
              </div>
              <div style={{ display: 'flex', gap: 8, marginTop: 8, fontSize: 10, color: 'var(--text-muted)', flexWrap: 'wrap' }}>
                <span>· 상의 28%</span>
                <span>· 하의 22%</span>
                <span>· 아우터 18%</span>
              </div>
            </div>
          </div>

          {/* AI Suggestion */}
          <div style={{ background: 'var(--linen)', border: '1px solid var(--line)', padding: 20, borderRadius: 4 }}>
            <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
              <span style={{ fontSize: 14 }}>✦</span>
              <div className="korean-serif" style={{ fontSize: 16, fontWeight: 500, fontFamily: "var(--font-korean-display, serif)" }}>코디 추천</div>
            </div>
            <p className="korean-sans" style={{ margin: '10px 0', fontSize: 12, lineHeight: 1.6, color: 'var(--text-muted)' }}>
              <span style={{ color: 'var(--walnut)', fontWeight: 500 }}>옵시디언 모토 재킷</span>은 옷장 안 <span style={{ color: 'var(--walnut)', fontWeight: 500 }}>울 트라우저</span>와 40% 이상 시너지가 높습니다.
            </p>
            <button className="btn btn-secondary" style={{ width: '100%', fontSize: 12, padding: '10px' }} onClick={() => onNav('product')}>
              전체 코디네이터 보기 →
            </button>
          </div>
        </aside>
      </section>

      <Footer brand={brand} />
    </main>
  );
}

function ClosetCard({ title, sub, tag, acc, c, featured, img }) {
  return (
    <div style={{
      background: 'var(--bg-raised)',
      border: featured ? '1px solid var(--walnut)' : '1px solid var(--line)',
      borderRadius: 4, overflow: 'hidden',
      transition: 'all 0.25s',
      cursor: 'pointer',
    }}
    onMouseEnter={e => { e.currentTarget.style.transform = 'translateY(-2px)'; e.currentTarget.style.boxShadow = '0 12px 28px rgba(74,56,38,0.10)'; }}
    onMouseLeave={e => { e.currentTarget.style.transform = 'none'; e.currentTarget.style.boxShadow = 'none'; }}
    >
      {/* Real photo */}
      <div style={{
        aspectRatio: '4/5',
        background: c,
        position: 'relative',
        display: 'flex', alignItems: 'flex-end', padding: 16,
        overflow: 'hidden',
      }}>
        {img && <img src={img} alt="" style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover', filter: 'grayscale(0.1) contrast(1.02)' }}/>}
        {tag && (
          <div style={{
            position: 'absolute', top: 14, left: 14,
            padding: '4px 10px',
            background: 'rgba(245,240,230,0.92)',
            color: 'var(--walnut)',
            fontSize: 9, fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.12em',
            borderRadius: 2,
          }}>{tag}</div>
        )}
        {featured && (
          <div style={{
            position: 'absolute', top: 14, right: 14,
            fontSize: 9, color: 'var(--ivory)', fontFamily: 'var(--font-display, serif)', fontStyle: 'italic',
          }}>— hero piece</div>
        )}
        <div style={{
          position: 'absolute', bottom: 12, left: 14,
          padding: '4px 8px', background: 'rgba(13,12,11,0.55)', backdropFilter: 'blur(8px)',
          color: 'var(--ivory)',
          fontSize: 10, fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.15em', opacity: 0.9,
          borderRadius: 2,
        }}>
          GARMENT · {String(title).length.toString().padStart(3, '0')}
        </div>
      </div>
      <div style={{ padding: '14px 16px' }}>
        <div className="korean-sans" style={{ fontSize: 14, fontWeight: 500 }}>{title}</div>
        <div className="korean-sans" style={{ fontSize: 11, color: 'var(--text-muted)', marginTop: 2 }}>{sub}</div>
        <div style={{ marginTop: 12, display: 'flex', alignItems: 'center', gap: 8 }}>
          <div style={{ flex: 1, height: 2, background: 'var(--line)', borderRadius: 1 }}>
            <div style={{ width: `${acc}%`, height: '100%', background: 'var(--camel)', borderRadius: 1 }} />
          </div>
          <span style={{ fontSize: 10, fontFamily: 'JetBrains Mono, monospace', color: 'var(--text-muted)' }}>
            {acc}%
          </span>
        </div>
      </div>
    </div>
  );
}

function MiniStat({ label, value, unit, accent }) {
  return (
    <div>
      <div style={{ fontFamily: 'var(--font-display, serif)', fontSize: 24, fontWeight: 500, letterSpacing: '-0.02em', color: accent || 'var(--obsidian)', lineHeight: 1 }}>
        {value}{unit && <span style={{ fontSize: 12, color: 'var(--text-muted)', marginLeft: 2 }}>{unit}</span>}
      </div>
      <div style={{ fontSize: 10, color: 'var(--text-muted)', marginTop: 6, fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.1em', textTransform: 'uppercase' }}>
        {label}
      </div>
    </div>
  );
}

window.Closet = Closet;
