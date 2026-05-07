// Coordit — Shared components and design system
// Export to window for cross-file access

const { useState, useEffect, useRef, useMemo } = React;

// ═══════════════════════════════════════════════════
// Logo / wordmark
// ═══════════════════════════════════════════════════
function Logo({ size = 24, color, brand = "Coordit" }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'baseline', gap: 2,
      fontFamily: "var(--font-display, 'Cormorant Garamond', serif)",
      fontSize: size, fontWeight: 500,
      letterSpacing: '-0.02em',
      color: color || 'var(--obsidian)',
    }}>
      <span style={{ fontStyle: 'italic', fontWeight: 600 }}>C</span>
      <span>oordit</span>
      <span style={{
        width: 5, height: 5, borderRadius: '50%',
        background: 'var(--camel)', marginLeft: 2,
        alignSelf: 'center', transform: 'translateY(-1px)',
      }} />
    </div>
  );
}

// ═══════════════════════════════════════════════════
// TopBar (nav)
// ═══════════════════════════════════════════════════
function TopBar({ active, onNav, brand }) {
  const items = [
    { id: 'closet', label: 'Closet', ko: '옷장' },
    { id: 'styling', label: 'Styling', ko: '스타일링' },
    { id: 'fit', label: 'Fit Lab', ko: '핏 분석' },
    { id: 'atelier', label: 'Atelier', ko: '아뜰리에' },
  ];
  return (
    <header style={{
      position: 'sticky', top: 0, zIndex: 50,
      background: 'rgba(245,240,230,0.85)',
      backdropFilter: 'blur(20px)',
      borderBottom: '1px solid var(--line)',
      padding: '18px 48px',
      display: 'flex', alignItems: 'center', gap: 40,
    }}>
      <div onClick={() => onNav('landing')} style={{ cursor: 'pointer' }}>
        <Logo size={22} brand={brand} />
      </div>
      <nav style={{ display: 'flex', gap: 32, marginLeft: 24 }}>
        {items.map(it => (
          <button
            key={it.id}
            onClick={() => onNav(it.id)}
            style={{
              background: 'transparent', border: 'none', cursor: 'pointer',
              padding: '6px 2px',
              fontFamily: "var(--font-korean, 'Pretendard', sans-serif)",
              fontSize: 13, letterSpacing: '0.02em',
              color: active === it.id ? 'var(--obsidian)' : 'var(--text-muted)',
              borderBottom: active === it.id ? '1px solid var(--camel)' : '1px solid transparent',
              transition: 'all 0.2s',
            }}
          >
            <span style={{ fontFamily: "var(--font-display, serif)", fontStyle: 'italic', fontWeight: 500, marginRight: 6 }}>
              {it.label}
            </span>
            <span style={{ fontSize: 11, opacity: 0.7 }}>{it.ko}</span>
          </button>
        ))}
      </nav>
      <div style={{ marginLeft: 'auto', display: 'flex', gap: 16, alignItems: 'center' }}>
        <div style={{
          padding: '8px 14px',
          border: '1px solid var(--line-strong)',
          borderRadius: 20,
          fontSize: 11, color: 'var(--text-muted)',
          fontFamily: 'JetBrains Mono, monospace',
          letterSpacing: '0.1em',
          display: 'flex', gap: 8, alignItems: 'center',
        }}>
          <span style={{ width: 6, height: 6, borderRadius: '50%', background: 'var(--fit-perfect)' }} />
          AI ACTIVE
        </div>
        <div style={{
          width: 32, height: 32, borderRadius: '50%',
          background: 'var(--walnut)', color: 'var(--ivory)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          fontSize: 12, fontWeight: 600,
          fontFamily: 'var(--font-display, serif)', fontStyle: 'italic',
        }}>인</div>
      </div>
    </header>
  );
}

// ═══════════════════════════════════════════════════
// Footer
// ═══════════════════════════════════════════════════
function Footer({ brand }) {
  return (
    <footer style={{
      padding: '48px 48px 32px',
      borderTop: '1px solid var(--line)',
      background: 'var(--bg-raised)',
      display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start',
      gap: 32, marginTop: 64,
    }}>
      <div>
        <Logo size={20} brand={brand} />
        <div style={{ fontSize: 11, color: 'var(--text-dim)', marginTop: 8, fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.1em' }}>
          THE CURATED WARDROBE · EST. 2026
        </div>
      </div>
      <div style={{ display: 'flex', gap: 32, fontSize: 12, color: 'var(--text-muted)' }}>
        <a style={linkStyle}>이용약관</a>
        <a style={linkStyle}>개인정보 처리방침</a>
        <a style={linkStyle}>지속가능성 리포트</a>
        <a style={linkStyle}>Fit Guide</a>
        <a style={linkStyle}>고객지원</a>
      </div>
    </footer>
  );
}
const linkStyle = { color: 'inherit', textDecoration: 'none', cursor: 'pointer' };

// ═══════════════════════════════════════════════════
// Chip / Tag
// ═══════════════════════════════════════════════════
function Chip({ children, active, onClick, variant = 'default' }) {
  const bg = variant === 'dark'
    ? (active ? 'var(--obsidian)' : 'transparent')
    : (active ? 'var(--obsidian)' : 'transparent');
  const color = active ? 'var(--ivory)' : 'var(--obsidian)';
  return (
    <button onClick={onClick} style={{
      padding: '8px 18px',
      borderRadius: 999,
      border: active ? '1px solid var(--obsidian)' : '1px solid var(--line-strong)',
      background: bg, color,
      fontSize: 12, letterSpacing: '0.02em',
      fontFamily: "var(--font-korean, 'Pretendard', sans-serif)",
      cursor: 'pointer',
      transition: 'all 0.2s',
    }}>{children}</button>
  );
}

// ═══════════════════════════════════════════════════
// Stat number (editorial display)
// ═══════════════════════════════════════════════════
function Stat({ value, label, unit, trend }) {
  return (
    <div>
      <div style={{ fontFamily: 'var(--font-display, serif)', fontSize: 40, fontWeight: 500, letterSpacing: '-0.02em', color: 'var(--obsidian)', lineHeight: 1 }}>
        {value}{unit && <span style={{ fontSize: 16, color: 'var(--text-muted)', marginLeft: 4 }}>{unit}</span>}
      </div>
      <div style={{ fontSize: 11, color: 'var(--text-muted)', marginTop: 8, letterSpacing: '0.1em', textTransform: 'uppercase', fontFamily: 'JetBrains Mono, monospace' }}>
        {label}
      </div>
      {trend && <div style={{ fontSize: 10, color: 'var(--fit-perfect)', marginTop: 4 }}>↑ {trend}</div>}
    </div>
  );
}

// ═══════════════════════════════════════════════════
// Garment card (used in closet + recs)
// ═══════════════════════════════════════════════════
function GarmentCard({ title, subtitle, tag, accuracy, swatches, placeholder = 'garment', size = 'md', onClick }) {
  const heights = { sm: 180, md: 280, lg: 360 };
  return (
    <div onClick={onClick} style={{
      background: 'var(--bg-raised)',
      border: '1px solid var(--line)',
      borderRadius: 12,
      overflow: 'hidden',
      cursor: onClick ? 'pointer' : 'default',
      transition: 'all 0.25s ease',
      display: 'flex', flexDirection: 'column',
    }}
    onMouseEnter={e => { e.currentTarget.style.transform = 'translateY(-2px)'; e.currentTarget.style.boxShadow = '0 12px 28px rgba(74,56,38,0.08)'; }}
    onMouseLeave={e => { e.currentTarget.style.transform = 'none'; e.currentTarget.style.boxShadow = 'none'; }}
    >
      <div className="ph" style={{ height: heights[size], position: 'relative' }}>
        {tag && (
          <div style={{
            position: 'absolute', top: 12, left: 12,
            padding: '4px 10px',
            background: 'rgba(245,240,230,0.9)',
            backdropFilter: 'blur(8px)',
            borderRadius: 4,
            fontSize: 10, letterSpacing: '0.08em',
            color: 'var(--walnut)',
            fontFamily: 'JetBrains Mono, monospace',
            textTransform: 'uppercase',
          }}>{tag}</div>
        )}
        <span style={{ opacity: 0.5 }}>{placeholder}</span>
        {swatches && (
          <div style={{ position: 'absolute', bottom: 12, left: 12, display: 'flex', gap: 4 }}>
            {swatches.map((c, i) => (
              <span key={i} style={{ width: 14, height: 14, borderRadius: '50%', background: c, border: '1px solid rgba(255,255,255,0.4)' }} />
            ))}
          </div>
        )}
      </div>
      <div style={{ padding: '16px 18px', display: 'flex', flexDirection: 'column', gap: 4 }}>
        <div style={{ fontSize: 14, fontWeight: 500, color: 'var(--obsidian)', fontFamily: "var(--font-korean, 'Pretendard', sans-serif)" }}>
          {title}
        </div>
        <div style={{ fontSize: 11, color: 'var(--text-muted)', fontFamily: "var(--font-korean, 'Pretendard', sans-serif)" }}>
          {subtitle}
        </div>
        {accuracy && (
          <div style={{ marginTop: 10, display: 'flex', alignItems: 'center', gap: 8 }}>
            <div style={{ flex: 1, height: 2, background: 'var(--line)', borderRadius: 1, overflow: 'hidden' }}>
              <div style={{ width: `${accuracy}%`, height: '100%', background: 'var(--camel)' }} />
            </div>
            <span style={{ fontSize: 10, color: 'var(--text-muted)', fontFamily: 'JetBrains Mono, monospace' }}>{accuracy}%</span>
          </div>
        )}
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════
// Section header
// ═══════════════════════════════════════════════════
function SectionHeader({ eyebrow, title, subtitle, align = 'left' }) {
  return (
    <div style={{ textAlign: align, display: 'flex', flexDirection: 'column', gap: 12, alignItems: align === 'center' ? 'center' : 'flex-start' }}>
      {eyebrow && <div className="eyebrow">{eyebrow}</div>}
      <h2 className="korean-serif" style={{
        margin: 0,
        fontFamily: "var(--font-korean-display, 'Noto Serif KR', serif)",
        fontWeight: 500,
        fontSize: 56,
        lineHeight: 1.15,
        letterSpacing: '-0.02em',
        color: 'var(--obsidian)',
        maxWidth: 900,
      }}>
        {title}
      </h2>
      {subtitle && <p style={{
        margin: 0,
        fontSize: 16, color: 'var(--text-muted)',
        lineHeight: 1.6, maxWidth: 640,
        fontFamily: "var(--font-korean, 'Pretendard', sans-serif)",
      }}>{subtitle}</p>}
    </div>
  );
}

Object.assign(window, {
  Logo, TopBar, Footer, Chip, Stat, GarmentCard, SectionHeader,
});
