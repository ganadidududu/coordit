/**
 * Coordit — Backend Server
 * Express + SQLite + JWT Auth
 * AI Styling via Claude API (optional, falls back to local logic)
 */

const express = require('express');
const path = require('path');
const fs = require('fs');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const sqlite3 = require('sqlite3').verbose();
const multer = require('multer');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3000;
const JWT_SECRET = process.env.JWT_SECRET || 'coordit-secret-key-2026';
const ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY || '';

// ── Middleware ──
app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(express.static(path.join(__dirname)));

// ── File upload (garment images) ──
const uploadsDir = path.join(__dirname, 'uploads');
if (!fs.existsSync(uploadsDir)) fs.mkdirSync(uploadsDir);

const storage = multer.diskStorage({
  destination: uploadsDir,
  filename: (req, file, cb) => {
    cb(null, `${Date.now()}-${file.originalname}`);
  },
});
const upload = multer({ storage, limits: { fileSize: 5 * 1024 * 1024 } });
app.use('/uploads', express.static(uploadsDir));

// ── Database ──
const DB_PATH = path.join(__dirname, 'coordit.db');
const db = new sqlite3.Database(DB_PATH);

function dbRun(sql, params = []) {
  return new Promise((res, rej) =>
    db.run(sql, params, function (err) { err ? rej(err) : res(this); })
  );
}
function dbGet(sql, params = []) {
  return new Promise((res, rej) =>
    db.get(sql, params, (err, row) => err ? rej(err) : res(row))
  );
}
function dbAll(sql, params = []) {
  return new Promise((res, rej) =>
    db.all(sql, params, (err, rows) => err ? rej(err) : res(rows))
  );
}

async function initDB() {
  await dbRun(`CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    name TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )`);

  await dbRun(`CREATE TABLE IF NOT EXISTS measurements (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    height REAL DEFAULT 172,
    weight REAL DEFAULT 65,
    shoulder REAL DEFAULT 44.5,
    chest REAL DEFAULT 98,
    waist REAL DEFAULT 82,
    hip REAL DEFAULT 96,
    inseam REAL DEFAULT 80,
    neck REAL DEFAULT 38,
    body_type TEXT DEFAULT 'regular',
    predicted_size TEXT DEFAULT 'M',
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )`);

  // Add new measurement columns if they don't exist yet (migration)
  for (const col of ['sleeve REAL', 'top_length REAL', 'thigh REAL', 'rise REAL', 'hem REAL', 'bot_length REAL']) {
    await dbRun(`ALTER TABLE measurements ADD COLUMN ${col}`).catch(() => {});
  }

  await dbRun(`CREATE TABLE IF NOT EXISTS closet_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    name_ko TEXT,
    category TEXT NOT NULL,
    brand TEXT,
    color TEXT DEFAULT '#8F6F45',
    fabric TEXT,
    size TEXT,
    price INTEGER,
    image_url TEXT,
    garment_shoulder REAL,
    garment_chest REAL,
    garment_waist REAL,
    garment_length REAL,
    garment_sleeve REAL,
    tags TEXT DEFAULT '[]',
    notes TEXT,
    worn_count INTEGER DEFAULT 0,
    is_favorite INTEGER DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )`);

  await dbRun(`CREATE TABLE IF NOT EXISTS styling_looks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    name TEXT,
    name_ko TEXT,
    mood TEXT,
    occasion TEXT,
    item_ids TEXT DEFAULT '[]',
    palette TEXT DEFAULT '[]',
    ai_reasoning TEXT,
    fit_score REAL DEFAULT 0,
    is_saved INTEGER DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )`);

  await dbRun(`CREATE TABLE IF NOT EXISTS fit_analyses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    item_id INTEGER REFERENCES closet_items(id) ON DELETE CASCADE,
    shoulder_state TEXT,
    chest_state TEXT,
    waist_state TEXT,
    length_state TEXT,
    shoulder_delta REAL,
    chest_delta REAL,
    waist_delta REAL,
    overall_score REAL,
    recommendation TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )`);

  await dbRun(`CREATE TABLE IF NOT EXISTS style_preferences (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER UNIQUE,
    styles TEXT DEFAULT '[]',
    occasions TEXT DEFAULT '[]',
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )`);

  console.log('✓ Database initialized');
}

// ── Auth Middleware ──
function authMiddleware(req, res, next) {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'Authentication required' });
  try {
    req.user = jwt.verify(token, JWT_SECRET);
    next();
  } catch {
    res.status(401).json({ error: 'Invalid token' });
  }
}

// ══════════════════════════════════════════════
// AUTH ROUTES
// ══════════════════════════════════════════════

app.post('/api/auth/register', async (req, res) => {
  try {
    const { email, password, name } = req.body;
    if (!email || !password) return res.status(400).json({ error: '이메일과 비밀번호를 입력해주세요.' });

    const existing = await dbGet('SELECT id FROM users WHERE email = ?', [email]);
    if (existing) return res.status(409).json({ error: '이미 사용중인 이메일입니다.' });

    const hash = await bcrypt.hash(password, 10);
    const result = await dbRun(
      'INSERT INTO users (email, password_hash, name) VALUES (?, ?, ?)',
      [email, hash, name || email.split('@')[0]]
    );

    // Create default measurements
    await dbRun(
      'INSERT INTO measurements (user_id) VALUES (?)',
      [result.lastID]
    );

    // Seed some closet items for new user
    const seedItems = [
      { name: 'Heritage Camel Coat', name_ko: '헤리티지 카멜 코트', category: '아우터', color: '#8F6F45', fabric: 'Wool', size: 'M', garment_shoulder: 43, garment_chest: 102, garment_waist: 96, garment_length: 95, garment_sleeve: 63 },
      { name: 'Cloud Cashmere Knit', name_ko: '클라우드 캐시미어 니트', category: '상의', color: '#E8DFC9', fabric: 'Cashmere', size: 'M', garment_shoulder: 42, garment_chest: 99, garment_waist: 94, garment_length: 68, garment_sleeve: 62 },
      { name: 'Precision Pleats Trouser', name_ko: '프리시전 플리츠 트라우저', category: '하의', color: '#2D2A27', fabric: 'Wool', size: 'M', garment_waist: 80, garment_length: 100 },
      { name: 'Azure Midnight Gown', name_ko: '애쥬어 미드나잇 가운', category: '원피스', color: '#3F4E5E', fabric: 'Silk', size: 'M', garment_chest: 94, garment_waist: 76, garment_length: 130 },
      { name: 'Raw Denim Pants', name_ko: '생지 데님 팬츠', category: '하의', color: '#4A5568', fabric: 'Denim', size: 'M', garment_waist: 82, garment_length: 100 },
      { name: 'Architectural Poplin Shirt', name_ko: '아키텍처럴 포플린 셔츠', category: '상의', color: '#F5F0E6', fabric: 'Cotton', size: 'M', garment_shoulder: 44, garment_chest: 100, garment_waist: 92, garment_length: 75, garment_sleeve: 64 },
    ];

    for (const item of seedItems) {
      await dbRun(
        `INSERT INTO closet_items (user_id, name, name_ko, category, color, fabric, size, garment_shoulder, garment_chest, garment_waist, garment_length, garment_sleeve)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [result.lastID, item.name, item.name_ko, item.category, item.color, item.fabric, item.size,
         item.garment_shoulder, item.garment_chest, item.garment_waist, item.garment_length, item.garment_sleeve]
      );
    }

    const token = jwt.sign({ id: result.lastID, email }, JWT_SECRET, { expiresIn: '30d' });
    res.json({ token, user: { id: result.lastID, email, name: name || email.split('@')[0] } });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: '서버 오류가 발생했습니다.' });
  }
});

app.post('/api/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    const user = await dbGet('SELECT * FROM users WHERE email = ?', [email]);
    if (!user || !(await bcrypt.compare(password, user.password_hash))) {
      return res.status(401).json({ error: '이메일 또는 비밀번호가 올바르지 않습니다.' });
    }
    const token = jwt.sign({ id: user.id, email: user.email }, JWT_SECRET, { expiresIn: '30d' });
    res.json({ token, user: { id: user.id, email: user.email, name: user.name } });
  } catch (err) {
    res.status(500).json({ error: '서버 오류' });
  }
});

// ══════════════════════════════════════════════
// MEASUREMENTS
// ══════════════════════════════════════════════

app.get('/api/measurements', authMiddleware, async (req, res) => {
  const m = await dbGet('SELECT * FROM measurements WHERE user_id = ?', [req.user.id]);
  res.json(m || {});
});

app.put('/api/measurements', authMiddleware, async (req, res) => {
  const { height, weight, shoulder, chest, waist, hip, inseam, neck } = req.body;

  // Calculate body type and predicted size
  const bodyType = calculateBodyType({ shoulder, chest, waist, hip });
  const predictedSize = calculateSize({ shoulder, chest, waist });

  await dbRun(
    `INSERT INTO measurements (user_id, height, weight, shoulder, chest, waist, hip, inseam, neck, body_type, predicted_size, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
     ON CONFLICT(user_id) DO UPDATE SET
       height=excluded.height, weight=excluded.weight,
       shoulder=excluded.shoulder, chest=excluded.chest,
       waist=excluded.waist, hip=excluded.hip,
       inseam=excluded.inseam, neck=excluded.neck,
       body_type=excluded.body_type, predicted_size=excluded.predicted_size,
       updated_at=CURRENT_TIMESTAMP`,
    [req.user.id, height, weight, shoulder, chest, waist, hip, inseam, neck, bodyType, predictedSize]
  );

  const updated = await dbGet('SELECT * FROM measurements WHERE user_id = ?', [req.user.id]);
  res.json(updated);
});

app.patch('/api/measurements', authMiddleware, async (req, res) => {
  const allowed = ['height', 'weight', 'shoulder', 'chest', 'waist', 'hip', 'inseam', 'neck', 'sleeve', 'top_length', 'thigh', 'rise', 'hem', 'bot_length'];
  const fieldUpdates = {};
  for (const f of allowed) {
    if (req.body[f] !== undefined) fieldUpdates[f] = req.body[f];
  }
  if (Object.keys(fieldUpdates).length === 0) {
    return res.status(400).json({ error: '수정할 필드가 없습니다.' });
  }
  const current = await dbGet('SELECT * FROM measurements WHERE user_id = ?', [req.user.id]);
  if (!current) return res.status(404).json({ error: '측정값이 없습니다. 먼저 회원가입을 완료해주세요.' });

  const merged = { ...current, ...fieldUpdates };
  const bodyType = calculateBodyType(merged);
  const predictedSize = calculateSize(merged);

  const setClauses = [...Object.keys(fieldUpdates).map(f => `${f} = ?`), 'body_type = ?', 'predicted_size = ?', 'updated_at = CURRENT_TIMESTAMP'];
  const vals = [...Object.values(fieldUpdates), bodyType, predictedSize, req.user.id];

  await dbRun(`UPDATE measurements SET ${setClauses.join(', ')} WHERE user_id = ?`, vals);
  const updated = await dbGet('SELECT * FROM measurements WHERE user_id = ?', [req.user.id]);
  res.json(updated);
});

function calculateBodyType({ shoulder, chest, waist, hip }) {
  if (!shoulder || !chest || !waist) return 'regular';
  const ratio = shoulder / (waist || 1);
  if (ratio > 1.3) return 'inverted_triangle';
  if (hip && hip > chest * 1.05) return 'pear';
  if (Math.abs((shoulder || 0) - (hip || 0)) < 3 && waist < (chest || 100) * 0.85) return 'hourglass';
  return 'regular';
}

function calculateSize({ shoulder, chest, waist }) {
  const s = shoulder || 44;
  if (s <= 40 || (chest && chest <= 90)) return 'XS';
  if (s <= 42 || (chest && chest <= 94)) return 'S';
  if (s <= 45 || (chest && chest <= 100)) return 'M';
  if (s <= 47 || (chest && chest <= 106)) return 'L';
  return 'XL';
}

// ══════════════════════════════════════════════
// CLOSET
// ══════════════════════════════════════════════

app.get('/api/closet', authMiddleware, async (req, res) => {
  const { category, search } = req.query;
  let sql = 'SELECT * FROM closet_items WHERE user_id = ?';
  const params = [req.user.id];

  if (category && category !== '전체') {
    sql += ' AND category = ?';
    params.push(category);
  }
  if (search) {
    sql += ' AND (name_ko LIKE ? OR name LIKE ? OR fabric LIKE ?)';
    params.push(`%${search}%`, `%${search}%`, `%${search}%`);
  }
  sql += ' ORDER BY created_at DESC';

  const items = await dbAll(sql, params);
  res.json(items);
});

app.get('/api/closet/:id', authMiddleware, async (req, res) => {
  const item = await dbGet('SELECT * FROM closet_items WHERE id = ? AND user_id = ?', [req.params.id, req.user.id]);
  if (!item) return res.status(404).json({ error: '아이템을 찾을 수 없습니다.' });
  res.json(item);
});

app.post('/api/closet', authMiddleware, async (req, res) => {
  const { name, name_ko, category, color, fabric, size, brand, price, notes,
          garment_shoulder, garment_chest, garment_waist, garment_length, garment_sleeve } = req.body;

  if (!name || !category) return res.status(400).json({ error: '이름과 카테고리는 필수입니다.' });

  const result = await dbRun(
    `INSERT INTO closet_items (user_id, name, name_ko, category, color, fabric, size, brand, price, notes,
      garment_shoulder, garment_chest, garment_waist, garment_length, garment_sleeve)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [req.user.id, name, name_ko, category, color || '#8F6F45', fabric, size, brand, price, notes,
     garment_shoulder, garment_chest, garment_waist, garment_length, garment_sleeve]
  );

  const item = await dbGet('SELECT * FROM closet_items WHERE id = ?', [result.lastID]);
  res.json(item);
});

app.put('/api/closet/:id', authMiddleware, async (req, res) => {
  const item = await dbGet('SELECT id FROM closet_items WHERE id = ? AND user_id = ?', [req.params.id, req.user.id]);
  if (!item) return res.status(404).json({ error: '아이템을 찾을 수 없습니다.' });

  const fields = ['name', 'name_ko', 'category', 'color', 'fabric', 'size', 'brand', 'price', 'notes',
                  'garment_shoulder', 'garment_chest', 'garment_waist', 'garment_length', 'garment_sleeve',
                  'is_favorite', 'worn_count', 'image_url'];
  const updates = [];
  const params = [];

  for (const f of fields) {
    if (req.body[f] !== undefined) {
      updates.push(`${f} = ?`);
      params.push(req.body[f]);
    }
  }

  if (updates.length === 0) return res.status(400).json({ error: '수정할 필드가 없습니다.' });

  params.push(req.params.id);
  await dbRun(`UPDATE closet_items SET ${updates.join(', ')} WHERE id = ?`, params);

  const updated = await dbGet('SELECT * FROM closet_items WHERE id = ?', [req.params.id]);
  res.json(updated);
});

app.delete('/api/closet/:id', authMiddleware, async (req, res) => {
  const item = await dbGet('SELECT id FROM closet_items WHERE id = ? AND user_id = ?', [req.params.id, req.user.id]);
  if (!item) return res.status(404).json({ error: '아이템을 찾을 수 없습니다.' });
  await dbRun('DELETE FROM closet_items WHERE id = ?', [req.params.id]);
  res.json({ success: true });
});

app.post('/api/closet/:id/wear', authMiddleware, async (req, res) => {
  await dbRun(
    'UPDATE closet_items SET worn_count = worn_count + 1 WHERE id = ? AND user_id = ?',
    [req.params.id, req.user.id]
  );
  res.json({ success: true });
});

app.post('/api/closet/upload-image', authMiddleware, upload.single('image'), async (req, res) => {
  if (!req.file) return res.status(400).json({ error: '이미지를 업로드해주세요.' });
  const imageUrl = `/uploads/${req.file.filename}`;
  if (req.body.item_id) {
    await dbRun('UPDATE closet_items SET image_url = ? WHERE id = ? AND user_id = ?',
      [imageUrl, req.body.item_id, req.user.id]);
  }
  res.json({ imageUrl });
});

// ══════════════════════════════════════════════
// FIT ANALYSIS
// ══════════════════════════════════════════════

app.get('/api/fit-analysis', authMiddleware, async (req, res) => {
  const { item_id } = req.query;

  const measurements = await dbGet('SELECT * FROM measurements WHERE user_id = ?', [req.user.id]);
  if (!measurements) return res.json({ error: '체형 측정값이 없습니다. 먼저 측정값을 입력해주세요.' });

  if (item_id) {
    const item = await dbGet('SELECT * FROM closet_items WHERE id = ? AND user_id = ?', [item_id, req.user.id]);
    if (!item) return res.status(404).json({ error: '아이템을 찾을 수 없습니다.' });

    const analysis = analyzeFit(measurements, item);
    res.json({ measurements, item, analysis });
  } else {
    // Return fit overview for all closet items
    const items = await dbAll('SELECT * FROM closet_items WHERE user_id = ?', [req.user.id]);
    const analyses = items.map(item => ({
      item,
      analysis: analyzeFit(measurements, item),
    }));
    res.json({ measurements, analyses });
  }
});

function analyzeFit(measurements, item) {
  const results = {};

  // Shoulder
  if (item.garment_shoulder && measurements.shoulder) {
    const delta = item.garment_shoulder - measurements.shoulder;
    results.shoulder = {
      delta: delta.toFixed(1),
      state: delta < -1 ? 'tight' : delta > 3 ? 'loose' : 'perfect',
      label: delta < -1 ? 'Tight' : delta > 3 ? 'Loose' : 'Perfect',
      value_cm: Math.abs(delta).toFixed(1),
      sign: delta > 0 ? '+' : '',
    };
  }

  // Chest
  if (item.garment_chest && measurements.chest) {
    const delta = item.garment_chest - measurements.chest;
    results.chest = {
      delta: delta.toFixed(1),
      state: delta < 2 ? 'tight' : delta > 10 ? 'loose' : 'perfect',
      label: delta < 2 ? 'Tight' : delta > 10 ? 'Loose' : 'Perfect',
      value_cm: Math.abs(delta).toFixed(1),
      sign: delta > 0 ? '+' : '',
    };
  }

  // Waist
  if (item.garment_waist && measurements.waist) {
    const delta = item.garment_waist - measurements.waist;
    results.waist = {
      delta: delta.toFixed(1),
      state: delta < 1 ? 'tight' : delta > 8 ? 'loose' : 'perfect',
      label: delta < 1 ? 'Tight' : delta > 8 ? 'Loose' : 'Perfect',
      value_cm: Math.abs(delta).toFixed(1),
      sign: delta > 0 ? '+' : '',
    };
  }

  // Length (vs inseam for bottoms, or just garment_length)
  if (item.garment_length) {
    const ref = measurements.inseam || measurements.height * 0.48;
    const delta = item.garment_length - ref;
    results.length = {
      delta: delta.toFixed(1),
      state: delta < -3 ? 'tight' : delta > 5 ? 'loose' : 'perfect',
      label: delta < -3 ? 'Short' : delta > 5 ? 'Long' : 'Perfect',
      value_cm: Math.abs(delta).toFixed(1),
      sign: delta > 0 ? '+' : '',
    };
  }

  // Overall score
  const states = Object.values(results).map(r => r.state);
  const perfectCount = states.filter(s => s === 'perfect').length;
  const overallScore = states.length > 0
    ? Math.round((perfectCount / states.length) * 100 * 0.6 + 40)
    : 85;

  const recommendation = generateFitRecommendation(results, item);

  return { ...results, overall_score: overallScore, recommendation };
}

function generateFitRecommendation(results, item) {
  const tight = Object.entries(results).filter(([k, v]) => v && v.state === 'tight').map(([k]) => k);
  const loose = Object.entries(results).filter(([k, v]) => v && v.state === 'loose').map(([k]) => k);

  const partNames = { shoulder: '어깨', chest: '가슴', waist: '허리', length: '기장' };

  if (tight.length === 0 && loose.length === 0) {
    return '전체적으로 완벽한 핏입니다. 이 아이템은 당신의 체형에 이상적으로 맞습니다.';
  }

  let rec = '';
  if (tight.length > 0) {
    rec += `${tight.map(k => partNames[k]).join(', ')} 부분이 다소 타이트합니다. `;
    if (tight.includes('shoulder')) rec += '한 치수 큰 사이즈를 권장합니다. ';
  }
  if (loose.length > 0) {
    rec += `${loose.map(k => partNames[k]).join(', ')} 부분에 여유가 있습니다. `;
    if (loose.includes('waist')) rec += '수선을 고려해보세요.';
  }
  return rec.trim();
}

// ══════════════════════════════════════════════
// AI STYLING
// ══════════════════════════════════════════════

app.post('/api/styling/generate', authMiddleware, async (req, res) => {
  const { prompt, occasion } = req.body;

  const measurements = await dbGet('SELECT * FROM measurements WHERE user_id = ?', [req.user.id]);
  const closetItems = await dbAll('SELECT * FROM closet_items WHERE user_id = ?', [req.user.id]);

  if (closetItems.length === 0) {
    return res.json({ error: '옷장에 아이템이 없습니다. 먼저 아이템을 추가해주세요.' });
  }

  try {
    let looks;
    if (ANTHROPIC_API_KEY) {
      looks = await generateAIStyling(prompt, occasion, measurements, closetItems);
    } else {
      looks = generateLocalStyling(prompt, occasion, measurements, closetItems);
    }

    // Save looks to DB
    const savedLooks = [];
    for (const look of looks) {
      const result = await dbRun(
        `INSERT INTO styling_looks (user_id, name, name_ko, mood, occasion, item_ids, palette, ai_reasoning, fit_score)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [req.user.id, look.name, look.name_ko, look.mood, occasion || prompt,
         JSON.stringify(look.item_ids), JSON.stringify(look.palette),
         look.ai_reasoning, look.fit_score]
      );
      look.id = result.lastID;
      savedLooks.push(look);
    }

    res.json({ looks: savedLooks, closetItems });
  } catch (err) {
    console.error('Styling error:', err);
    const looks = generateLocalStyling(prompt, occasion, measurements, closetItems);
    res.json({ looks, closetItems });
  }
});

async function generateAIStyling(prompt, occasion, measurements, items) {
  const Anthropic = require('@anthropic-ai/sdk');
  const client = new Anthropic({ apiKey: ANTHROPIC_API_KEY });

  const itemList = items.map(i => `- ID:${i.id} "${i.name_ko || i.name}" (${i.category}, ${i.color})`).join('\n');
  const bodyInfo = measurements
    ? `키: ${measurements.height}cm, 어깨: ${measurements.shoulder}cm, 가슴: ${measurements.chest}cm, 허리: ${measurements.waist}cm`
    : '측정 없음';

  const response = await client.messages.create({
    model: 'claude-opus-4-6',
    max_tokens: 1500,
    messages: [{
      role: 'user',
      content: `당신은 패션 스타일리스트입니다. 다음 옷장 아이템들로 주어진 상황에 맞는 코디 3가지를 추천해주세요.

옷장 아이템:
${itemList}

체형 정보: ${bodyInfo}

상황: ${prompt || occasion || '일상적인 코디'}

각 코디는 다음 JSON 형식으로 반환하세요:
{
  "looks": [
    {
      "name": "영어 코디명",
      "name_ko": "한국어 코디명",
      "mood": "무드 설명",
      "item_ids": [사용할 아이템 ID 배열],
      "palette": ["색상코드1", "색상코드2", "색상코드3"],
      "ai_reasoning": "왜 이 조합인지 한국어 설명 (2-3문장)",
      "fit_score": 85~98 사이의 숫자
    }
  ]
}`
    }]
  });

  const text = response.content[0].text;
  const jsonMatch = text.match(/\{[\s\S]*\}/);
  if (jsonMatch) {
    return JSON.parse(jsonMatch[0]).looks;
  }
  return generateLocalStyling(prompt, occasion, null, items);
}

function generateLocalStyling(prompt, occasion, measurements, items) {
  const outer = items.filter(i => i.category === '아우터');
  const top = items.filter(i => i.category === '상의');
  const bottom = items.filter(i => i.category === '하의');
  const dress = items.filter(i => i.category === '원피스');

  const looks = [];

  // Look 1: Classic work
  const look1Items = [];
  if (outer.length > 0) look1Items.push(outer[0]);
  if (top.length > 0) look1Items.push(top[0]);
  if (bottom.length > 0) look1Items.push(bottom[0]);

  if (look1Items.length > 0) {
    looks.push({
      name: 'Parisian Workday',
      name_ko: '파리지엔 워크데이',
      mood: '비즈니스 · 미팅',
      item_ids: look1Items.map(i => i.id),
      palette: look1Items.map(i => i.color).slice(0, 3),
      ai_reasoning: `${look1Items.map(i => i.name_ko || i.name).join(', ')} 조합은 구조적인 실루엣을 만들어냅니다. 어스 톤의 팔레트가 세련된 비즈니스 무드를 연출합니다.`,
      fit_score: measurements ? (90 + Math.floor(Math.random() * 8)) : 88,
    });
  }

  // Look 2: Casual
  const look2Items = [];
  if (top.length > 1) look2Items.push(top[1]);
  else if (top.length > 0) look2Items.push(top[0]);
  if (bottom.length > 1) look2Items.push(bottom[1]);
  else if (bottom.length > 0) look2Items.push(bottom[0]);

  if (look2Items.length > 0) {
    looks.push({
      name: 'Weekend Essai',
      name_ko: '주말의 에세이',
      mood: '캐주얼 · 주말',
      item_ids: look2Items.map(i => i.id),
      palette: look2Items.map(i => i.color).slice(0, 3),
      ai_reasoning: `가벼운 텍스처의 조합이 주말의 여유를 표현합니다. 레이어링 없이 심플하게 완성됩니다.`,
      fit_score: measurements ? (85 + Math.floor(Math.random() * 10)) : 82,
    });
  }

  // Look 3: Evening
  if (dress.length > 0) {
    looks.push({
      name: 'Evening Atelier',
      name_ko: '이브닝 아뜰리에',
      mood: '포멀 · 이브닝',
      item_ids: [dress[0].id],
      palette: [dress[0].color, '#1C1B1A', '#D4B896'],
      ai_reasoning: `싱글 피스 드레스의 실루엣이 이브닝 디너에 완벽합니다. 드레스 자체가 충분한 존재감을 갖고 있습니다.`,
      fit_score: measurements ? (88 + Math.floor(Math.random() * 8)) : 85,
    });
  } else if (outer.length > 0 && bottom.length > 0) {
    const eveningItems = [outer[outer.length - 1], bottom[0]];
    looks.push({
      name: 'Obsidian Evening',
      name_ko: '옵시디언 이브닝',
      mood: '포멀 · 디너',
      item_ids: eveningItems.map(i => i.id),
      palette: eveningItems.map(i => i.color),
      ai_reasoning: `다크 팔레트의 아우터와 보텀의 조합이 저녁 행사에 적합한 분위기를 만듭니다.`,
      fit_score: measurements ? (87 + Math.floor(Math.random() * 8)) : 84,
    });
  }

  return looks.slice(0, 3);
}

app.get('/api/styling/saved', authMiddleware, async (req, res) => {
  const looks = await dbAll(
    'SELECT * FROM styling_looks WHERE user_id = ? ORDER BY created_at DESC LIMIT 20',
    [req.user.id]
  );
  res.json(looks);
});

app.post('/api/styling/:id/save', authMiddleware, async (req, res) => {
  await dbRun(
    'UPDATE styling_looks SET is_saved = 1 WHERE id = ? AND user_id = ?',
    [req.params.id, req.user.id]
  );
  res.json({ success: true });
});

// ══════════════════════════════════════════════
// STYLE PREFERENCES
// ══════════════════════════════════════════════

app.get('/api/style-preferences', authMiddleware, async (req, res) => {
  try {
    const pref = await dbGet('SELECT * FROM style_preferences WHERE user_id = ?', [req.user.id]);
    if (!pref) return res.json({ styles: [], occasions: [] });
    res.json({
      styles: JSON.parse(pref.styles || '[]'),
      occasions: JSON.parse(pref.occasions || '[]'),
      updated_at: pref.updated_at,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: '서버 오류가 발생했습니다.' });
  }
});

app.put('/api/style-preferences', authMiddleware, async (req, res) => {
  try {
    const { styles = [], occasions = [] } = req.body;
    await dbRun(
      `INSERT INTO style_preferences (user_id, styles, occasions, updated_at)
       VALUES (?, ?, ?, CURRENT_TIMESTAMP)
       ON CONFLICT(user_id) DO UPDATE SET
         styles = excluded.styles,
         occasions = excluded.occasions,
         updated_at = CURRENT_TIMESTAMP`,
      [req.user.id, JSON.stringify(styles), JSON.stringify(occasions)]
    );
    const updated = await dbGet('SELECT * FROM style_preferences WHERE user_id = ?', [req.user.id]);
    res.json({
      styles: JSON.parse(updated.styles || '[]'),
      occasions: JSON.parse(updated.occasions || '[]'),
      updated_at: updated.updated_at,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: '서버 오류가 발생했습니다.' });
  }
});

// ══════════════════════════════════════════════
// STATS / DASHBOARD
// ══════════════════════════════════════════════

app.get('/api/stats', authMiddleware, async (req, res) => {
  const totalItems = await dbGet('SELECT COUNT(*) as count FROM closet_items WHERE user_id = ?', [req.user.id]);
  const totalLooks = await dbGet('SELECT COUNT(*) as count FROM styling_looks WHERE user_id = ?', [req.user.id]);
  const mostWornTop3 = await dbAll(
    'SELECT id, name_ko, name, worn_count, category FROM closet_items WHERE user_id = ? ORDER BY worn_count DESC LIMIT 3',
    [req.user.id]
  );
  const unwornCount = await dbGet('SELECT COUNT(*) as count FROM closet_items WHERE user_id = ? AND worn_count = 0', [req.user.id]);
  const favoriteCount = await dbGet('SELECT COUNT(*) as count FROM closet_items WHERE user_id = ? AND is_favorite = 1', [req.user.id]);
  const measurements = await dbGet('SELECT predicted_size, body_type FROM measurements WHERE user_id = ?', [req.user.id]);

  res.json({
    totalItems: totalItems?.count || 0,
    totalLooks: totalLooks?.count || 0,
    mostWorn: mostWornTop3 || [],
    unworn_count: unwornCount?.count || 0,
    favorite_count: favoriteCount?.count || 0,
    predictedSize: measurements?.predicted_size || 'M',
    bodyType: measurements?.body_type || 'regular',
  });
});

// ── Serve HTML ──
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'index.html'));
});

// ── Start ──
initDB().then(() => {
  app.listen(PORT, () => {
    console.log(`\n🧥 Coordit server running at http://localhost:${PORT}`);
    console.log(`   DB: ${DB_PATH}`);
    if (ANTHROPIC_API_KEY) {
      console.log('   ✓ Claude AI styling enabled');
    } else {
      console.log('   ⚠ Claude AI not configured — set ANTHROPIC_API_KEY for AI styling');
    }
  });
}).catch(err => {
  console.error('Failed to initialize DB:', err);
  process.exit(1);
});
