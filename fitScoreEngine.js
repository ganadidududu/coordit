'use strict';

/**
 * Coordit Fit Score Engine
 *
 * 기준 옷(reference)과 구매 예정 옷(target)의 실측값을 비교해
 * 부위별 불쾌 점수(discomfort score)를 기반으로 종합 핏 점수를 반환한다.
 *
 * diff 방향 규칙: diff = target - reference
 *   diff > 0 → target이 더 큼 (여유 ↑, 느슨한 방향)
 *   diff < 0 → target이 더 작음 (여유 ↓, 조이는 방향)
 */

// ─── 기본 설정 ────────────────────────────────────────────────────────────────

const DEFAULT_CONFIG = {
  /**
   * 불쾌점수 → 부위 점수 변환 민감도
   * partScore = max(0, 100 - discomfort * sensitivity)
   */
  sensitivity: 10,

  /**
   * 방향별 불쾌 계수
   *   pos: target이 큰 방향 (느슨)
   *   neg: target이 작은 방향 (조임)
   *
   * 설계 근거:
   *   shoulder: 어깨선 내려감(pos)이 치명적, 조임(neg)은 그나마 버팀
   *   waist/hip/thigh: 조임(neg)이 착용 불가 수준으로 치명적
   *   sleeve/length: 취향 영역 → 양방향 낮은 계수
   *   rise: 짧으면(neg) 앉을 때 불편, 길면 크게 상관없음
   */
  partCoeffs: {
    shoulder: { pos: 1.8, neg: 0.8 },
    chest:    { pos: 1.0, neg: 1.0 },
    waist:    { pos: 0.5, neg: 2.0 },
    hip:      { pos: 0.6, neg: 2.2 },
    thigh:    { pos: 0.6, neg: 2.0 },
    sleeve:   { pos: 0.5, neg: 0.5 },
    length:   { pos: 0.4, neg: 0.6 },
    rise:     { pos: 0.7, neg: 1.5 },
    hem:      { pos: 0.4, neg: 0.4 },
  },

  /**
   * 구간별 곡선 적용
   * zoneThresholds: [1cm, 3cm] → 0–1 / 1–3 / 3+
   * zoneMultipliers: 각 구간의 패널티 곱수
   */
  zoneThresholds: [1, 3],
  zoneMultipliers: [0.2, 1.0, 2.0],

  /**
   * 카테고리별 부위 가중치 (합 = 1.0)
   * 팬츠류: thigh 0.20으로 높임 (허벅지 낑기면 허리 맞아도 못 입음)
   */
  categoryWeights: {
    jacket:   { shoulder: 0.35, chest: 0.30, sleeve: 0.20, length: 0.15 },
    blazer:   { shoulder: 0.35, chest: 0.30, sleeve: 0.20, length: 0.15 },
    shirt:    { shoulder: 0.30, chest: 0.30, sleeve: 0.25, length: 0.15 },
    tshirt:   { shoulder: 0.35, chest: 0.35, length: 0.20, sleeve: 0.10 },
    top:      { shoulder: 0.35, chest: 0.35, length: 0.20, sleeve: 0.10 },
    knit:     { shoulder: 0.30, chest: 0.30, sleeve: 0.20, length: 0.20 },
    knitwear: { shoulder: 0.30, chest: 0.30, sleeve: 0.20, length: 0.20 },
    coat:     { shoulder: 0.30, chest: 0.25, sleeve: 0.25, length: 0.20 },
    outer:    { shoulder: 0.30, chest: 0.25, sleeve: 0.25, length: 0.20 },
    pants:    { waist: 0.35, hip: 0.30, thigh: 0.20, length: 0.10, rise: 0.05 },
    slacks:   { waist: 0.35, hip: 0.30, thigh: 0.20, length: 0.10, rise: 0.05 },
    jeans:    { waist: 0.30, hip: 0.25, thigh: 0.25, length: 0.10, rise: 0.10 },
    skirt:    { waist: 0.45, hip: 0.35, length: 0.20 },
    dress:    { shoulder: 0.25, chest: 0.25, waist: 0.25, hip: 0.15, length: 0.10 },
  },

  /**
   * 핵심 부위: 하나라도 점수가 낮으면 전체 점수를 끌어내림 (bottleneck)
   * totalScore = min(weightedAvg, minCriticalScore + criticalClamp)
   */
  criticalParts: {
    jacket:   ['shoulder', 'chest'],
    blazer:   ['shoulder', 'chest'],
    shirt:    ['shoulder', 'chest'],
    tshirt:   ['shoulder', 'chest'],
    top:      ['shoulder', 'chest'],
    knit:     ['chest'],
    knitwear: ['chest'],
    coat:     ['shoulder', 'chest'],
    outer:    ['shoulder', 'chest'],
    pants:    ['waist', 'hip', 'thigh'],
    slacks:   ['waist', 'hip', 'thigh'],
    jeans:    ['waist', 'hip', 'thigh'],
    skirt:    ['waist', 'hip'],
    dress:    ['waist', 'hip', 'chest'],
  },

  criticalClamp: 15,

  /**
   * 신축성 있는 소재: 허용 구간을 1.5배로 넓힘
   * (zoneThreshold가 1/3cm → 1.5/4.5cm로 늘어나는 효과)
   */
  stretchCategories: ['knit', 'knitwear'],
  stretchFactor: 1.5,

  defaultWeights:       { shoulder: 0.30, chest: 0.30, length: 0.20, sleeve: 0.20 },
  defaultCriticalParts: ['shoulder', 'chest'],

  verdictThresholds: [
    { min: 85, label: '잘 맞음' },
    { min: 70, label: '대체로 맞음' },
    { min: 50, label: '주의 필요' },
    { min: 0,  label: '맞지 않음' },
  ],
};

// ─── 내부 헬퍼 ────────────────────────────────────────────────────────────────

function normalizeCategory(raw) {
  return String(raw || '').toLowerCase().replace(/[\s_\-]/g, '');
}

function getZoneMultiplier(absDiff, thresholds, multipliers, stretch) {
  const [t1, t2] = thresholds.map(t => t * stretch);
  if (absDiff <= t1) return multipliers[0];
  if (absDiff <= t2) return multipliers[1];
  return multipliers[2];
}

// ─── 코멘트 생성 ──────────────────────────────────────────────────────────────

const COMMENT_MAP = {
  shoulder: {
    pos: ['어깨선이 살짝 내려갈 수 있어요', '어깨선이 내려가 실루엣이 흐트러져요', '어깨선이 많이 내려갑니다'],
    neg: ['어깨가 약간 당길 수 있어요', '어깨가 당겨 활동이 불편해요', '어깨가 너무 좁아 입기 어렵습니다'],
  },
  chest: {
    pos: ['가슴이 여유롭게 맞을 것 같아요', '가슴 부위가 다소 헐렁할 수 있어요', '가슴이 많이 남아 전체적으로 커 보여요'],
    neg: ['가슴이 약간 타이트할 수 있어요', '가슴이 당겨 답답할 수 있어요', '가슴이 꽉 껴서 입기 어렵습니다'],
  },
  waist: {
    pos: ['허리가 약간 여유 있어요', '허리가 헐렁할 수 있어요', '허리가 많이 남아 벨트가 필요해요'],
    neg: ['허리가 살짝 낑길 수 있어요', '허리가 많이 낑겨 불편할 수 있어요', '허리가 맞지 않습니다 — 사이즈업을 권장해요'],
  },
  hip: {
    pos: ['힙이 약간 여유 있어요', '힙이 헐렁할 수 있어요', '힙이 많이 커요'],
    neg: ['힙이 약간 타이트할 수 있어요', '힙이 많이 낑겨 불편합니다', '힙이 맞지 않습니다 — 사이즈업이 필요해요'],
  },
  thigh: {
    pos: ['허벅지가 약간 여유 있어요', '허벅지 부분이 헐렁해요', '허벅지가 많이 남아요'],
    neg: ['허벅지가 약간 타이트해요', '허벅지가 낑겨 활동이 불편합니다', '허벅지가 맞지 않습니다 — 사이즈업이 필요해요'],
  },
  sleeve: {
    pos: ['소매가 약간 길어요', '소매가 손등까지 내려올 수 있어요', '소매가 많이 길어요'],
    neg: ['소매가 약간 짧아요', '소매가 짧아 손목이 많이 보여요', '소매가 너무 짧습니다'],
  },
  length: {
    pos: ['기장이 조금 길어요', '기장이 길어요 — 취향에 따라 다를 수 있어요', '기장이 많이 길어요'],
    neg: ['기장이 조금 짧아요', '기장이 짧아요', '기장이 많이 짧습니다'],
  },
  rise: {
    pos: ['밑위가 약간 길어요', '밑위가 길어요', '밑위가 많이 길어요'],
    neg: ['밑위가 약간 짧아요', '밑위가 짧아 앉을 때 불편할 수 있어요', '밑위가 너무 짧습니다'],
  },
  hem: {
    pos: ['밑단이 약간 넓어요', '밑단이 넓어요', '밑단이 많이 넓어요'],
    neg: ['밑단이 약간 좁아요', '밑단이 좁아요', '밑단이 너무 좁습니다'],
  },
};

const FALLBACK_COMMENTS = {
  pos: ['약간 큰 편이에요', '큰 편이에요', '많이 커요'],
  neg: ['약간 작은 편이에요', '작은 편이에요', '많이 작아요'],
};

function generateComment(part, diff, score) {
  if (Math.abs(diff) < 0.5) return '잘 맞아요';

  const dir = diff > 0 ? 'pos' : 'neg';
  const list = (COMMENT_MAP[part] || FALLBACK_COMMENTS)[dir];

  if (score >= 80) return list[0];
  if (score >= 60) return list[1];
  return list[2];
}

// ─── 부위 점수 계산 ───────────────────────────────────────────────────────────

function scoreOnePart(part, diff, config, isStretch) {
  const coeffs = config.partCoeffs[part] || { pos: 1.0, neg: 1.0 };
  const stretch = isStretch ? config.stretchFactor : 1.0;

  const absDiff = Math.abs(diff);
  const dirCoeff = diff >= 0 ? coeffs.pos : coeffs.neg;
  const zm = getZoneMultiplier(absDiff, config.zoneThresholds, config.zoneMultipliers, stretch);

  const discomfort = absDiff * dirCoeff * zm;
  const score = Math.max(0, Math.round(100 - discomfort * config.sensitivity));
  const comment = generateComment(part, diff, score);

  return { diff, score, comment };
}

// ─── 판정 ─────────────────────────────────────────────────────────────────────

function getVerdict(score, thresholds) {
  for (const { min, label } of thresholds) {
    if (score >= min) return label;
  }
  return thresholds[thresholds.length - 1].label;
}

function calcConfidence(weights, reference, target) {
  const parts = Object.keys(weights);
  if (!parts.length) return 0;
  const provided = parts.filter(p => reference[p] != null && target[p] != null);
  return parseFloat(Math.min(0.95, (provided.length / parts.length) * 0.9 + 0.05).toFixed(2));
}

// ─── config 병합 ──────────────────────────────────────────────────────────────

function mergeConfig(base, override) {
  if (!override || !Object.keys(override).length) return base;
  return {
    ...base,
    ...override,
    partCoeffs:       { ...base.partCoeffs,       ...(override.partCoeffs       || {}) },
    categoryWeights:  { ...base.categoryWeights,  ...(override.categoryWeights  || {}) },
    criticalParts:    { ...base.criticalParts,     ...(override.criticalParts    || {}) },
    verdictThresholds: override.verdictThresholds || base.verdictThresholds,
  };
}

// ─── 공개 API ─────────────────────────────────────────────────────────────────

/**
 * analyzeFit
 *
 * @param {object} input
 *   @param {string} input.category   - 카테고리 (e.g. "jacket", "pants", "tshirt")
 *   @param {object} input.reference  - 기준 옷 실측값 (cm)
 *   @param {object} input.target     - 구매 예정 옷 사이즈표 (cm)
 * @param {object}  [customConfig]    - 외부 가중치 주입용 (피드백 루프 대비)
 *
 * @returns {{ totalScore, verdict, confidence, details }}
 */
function analyzeFit({ category, reference, target }, customConfig = {}) {
  const config = mergeConfig(DEFAULT_CONFIG, customConfig);

  const key = normalizeCategory(category);
  const weights = config.categoryWeights[key] || config.defaultWeights;
  const criticals = config.criticalParts[key] || config.defaultCriticalParts;
  const isStretch = config.stretchCategories.includes(key);

  const details = {};
  let weightedSum = 0;
  let totalWeight = 0;

  for (const [part, weight] of Object.entries(weights)) {
    if (reference[part] == null || target[part] == null) continue;

    const diff = target[part] - reference[part];
    const result = scoreOnePart(part, diff, config, isStretch);
    details[part] = result;
    weightedSum += result.score * weight;
    totalWeight += weight;
  }

  if (totalWeight === 0) {
    return { totalScore: null, verdict: '데이터 없음', confidence: 0, details: {} };
  }

  let totalScore = Math.round(weightedSum / totalWeight);

  // 핵심 부위 bottleneck: 핵심 부위가 낮으면 전체 점수 상한을 제한
  const criticalScores = criticals
    .map(p => details[p]?.score)
    .filter(s => s != null);

  if (criticalScores.length > 0) {
    const minCritical = Math.min(...criticalScores);
    totalScore = Math.min(totalScore, minCritical + config.criticalClamp);
  }

  totalScore = Math.max(0, Math.min(100, totalScore));

  return {
    totalScore,
    verdict: getVerdict(totalScore, config.verdictThresholds),
    confidence: calcConfidence(weights, reference, target),
    details,
  };
}

module.exports = { analyzeFit, DEFAULT_CONFIG };
