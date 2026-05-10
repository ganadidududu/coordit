'use strict';

const { analyzeFit, DEFAULT_CONFIG } = require('./fitScoreEngine');

// ─── Case 1: 자켓 — 전반적으로 잘 맞는 케이스 ───────────────────────────────

test('jacket — 전체적으로 잘 맞음 (diff 1~2cm 이내)', () => {
  const result = analyzeFit({
    category: 'jacket',
    reference: { shoulder: 44, chest: 96, sleeve: 62, length: 70 },
    target:    { shoulder: 45, chest: 97, sleeve: 62, length: 70 },
  });

  expect(result.totalScore).toBeGreaterThanOrEqual(80);
  expect(['잘 맞음', '대체로 맞음']).toContain(result.verdict);
  expect(result.confidence).toBe(0.95); // 4/4 부위 모두 제공, 함수 상한 0.95
});

// ─── Case 2: 팬츠 — 허리 3cm 조임 (착용 불가 수준) ──────────────────────────

test('pants — 허리 3cm 조임은 주의 필요/맞지 않음', () => {
  const result = analyzeFit({
    category: 'pants',
    reference: { waist: 82, hip: 96, thigh: 56, length: 100, rise: 28 },
    target:    { waist: 79, hip: 96, thigh: 56, length: 100, rise: 28 },
  });

  // 허리가 3cm 타이트하면 종합 점수도 주의 필요 이하여야 함
  expect(result.totalScore).toBeLessThan(70);
  expect(['주의 필요', '맞지 않음']).toContain(result.verdict);
  expect(result.details.waist.diff).toBe(-3);
  expect(result.details.waist.score).toBeLessThan(50);
});

// ─── Case 3: 어깨 크게 내려감 — 자켓 핵심 부위 bottleneck 동작 검증 ─────────

test('jacket — 어깨 5cm 큰 경우 전체 점수가 상한에 제한됨', () => {
  const result = analyzeFit({
    category: 'jacket',
    reference: { shoulder: 42, chest: 96, sleeve: 62, length: 70 },
    target:    { shoulder: 47, chest: 96, sleeve: 62, length: 70 },
  });

  const shoulderScore = result.details.shoulder.score;
  // criticalClamp=15 이므로 총점은 shoulder점수 + 15를 넘을 수 없음
  expect(result.totalScore).toBeLessThanOrEqual(shoulderScore + DEFAULT_CONFIG.criticalClamp);
  expect(['주의 필요', '맞지 않음']).toContain(result.verdict);
  expect(result.details.shoulder.comment).toContain('어깨선');
});

// ─── Case 4: 니트 — 스트레치 허용폭 확대로 같은 diff에서 더 관대한 점수 ──────

test('knit vs tshirt — 같은 가슴 차이에서 니트가 더 관대한 점수', () => {
  const shared = {
    reference: { shoulder: 44, chest: 96, sleeve: 60, length: 66 },
    target:    { shoulder: 44, chest: 100, sleeve: 60, length: 66 }, // 가슴 4cm 큼 (3cm 초과 시 스트레치 효과 차이가 발생)
  };

  const knitResult   = analyzeFit({ category: 'knit',   ...shared });
  const tshirtResult = analyzeFit({ category: 'tshirt', ...shared });

  expect(knitResult.totalScore).toBeGreaterThan(tshirtResult.totalScore);
});

// ─── Case 5: 일부 부위 누락 — confidence가 낮아짐 ────────────────────────────

test('pants — 허벅지 데이터 없으면 confidence 감소', () => {
  const full = analyzeFit({
    category: 'pants',
    reference: { waist: 80, hip: 96, thigh: 56, length: 100, rise: 28 },
    target:    { waist: 80, hip: 96, thigh: 56, length: 100, rise: 28 },
  });

  const partial = analyzeFit({
    category: 'pants',
    reference: { waist: 80, hip: 96, length: 100 },  // thigh, rise 없음
    target:    { waist: 80, hip: 96, length: 100 },
  });

  expect(full.confidence).toBeGreaterThan(partial.confidence);
  expect(partial.confidence).toBeLessThan(0.8);
});

// ─── Case 6: 사용자 정의 config로 외부 가중치 주입 ──────────────────────────

test('customConfig — waist 가중치 올리면 허리 타이트에 더 민감하게 반응', () => {
  const input = {
    category: 'pants',
    reference: { waist: 80, hip: 96, thigh: 56, length: 100, rise: 28 },
    target:    { waist: 77, hip: 96, thigh: 56, length: 100, rise: 28 }, // 허리 3cm 타이트
  };

  const defaultResult = analyzeFit(input);
  const customResult  = analyzeFit(input, {
    categoryWeights: {
      pants: { waist: 0.60, hip: 0.25, thigh: 0.10, length: 0.05 },
    },
  });

  expect(customResult.totalScore).toBeLessThanOrEqual(defaultResult.totalScore);
});

// ─── Case 7: 완전히 동일한 사이즈 → 만점 ────────────────────────────────────

test('정확히 동일한 사이즈 → totalScore 100, 잘 맞음', () => {
  const ref = { shoulder: 44, chest: 98, sleeve: 62, length: 70 };
  const result = analyzeFit({
    category: 'jacket',
    reference: ref,
    target: { ...ref },
  });

  expect(result.totalScore).toBe(100);
  expect(result.verdict).toBe('잘 맞음');
});
