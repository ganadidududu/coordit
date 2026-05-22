# Fit Engine 변경 이력

문서 상태: 최신  
기준일: 2026-05-22  
관련 문서: `fit-engine/FIT_ENGINE.md`

이 문서는 추천 엔진의 변화와 다음 개선 후보를 기록합니다. 현재 실제 동작 기준 문서는 `FIT_ENGINE.md`입니다.

## v1.0 MVP Rule Engine

핵심 특징:

- 단일 기준 의류 기반 추천
- 기준 의류 실측값과 외부 상품 사이즈표 비교
- 부위별 차이를 weighted distance로 변환
- distance를 0~100 fit score로 변환
- 최고 점수 사이즈 추천
- 추천 결과 DB 저장

## v1.1 Multiple References

현재 코드에 반영된 주요 개선입니다.

- `referenceClothingIds`로 여러 기준 의류 입력 가능
- 각 기준 의류의 `preference_score`를 가중치로 사용
- 전체 외부 상품 사이즈 후보별 점수 반환
- 부위별 설명과 상태 반환
- `recommendationConfidence` 반환
- 카테고리 호환성 검사 강화

## v1.2 Reference Variance Weighting & Outseam Migration

현재 코드에 반영된 주요 개선입니다.

- 여러 기준 의류 사용 시 reference 간 표준편차 기반 동적 가중치 적용
- 기준 의류들 사이에서 변화 폭이 작은 측정 항목을 사용자가 중요하게 여기는 요소로 해석
- 표준편차가 작은 측정 항목은 가중치 증가
- 표준편차가 큰 측정 항목은 가중치 감소
- dynamic weight 합이 1이 되도록 정규화
- 추천 결과의 `result_details`에 `baseWeights`, `dynamicWeights`, `referenceVariance`, `weightingStrategy` 저장
- 하의 측정 항목을 `inseam`에서 `outseam`으로 변경
- `outseam`은 MVP 단계에서 바지 전체 기장 비교에 더 직관적인 항목으로 사용

## 다음 개선 후보

### v1.3 Measurement Input Normalization

- camelCase 측정값 입력 지원
- cm/mm 단위 정규화
- 문자열 기반 치수 파싱
- 필수 측정값 부족 시 더 명확한 에러 메시지

### v1.4 Feedback-aware Score Adjustment

- `user_feedback` 기반 penalty 조정
- 사용자별 선호 여유분 학습
- 카테고리별 오차 보정

### v1.5 Product Parsing Confidence

- OCR/URL 파싱 confidence를 추천 confidence에 반영
- `measurement_source`별 신뢰도 차등 적용
- 수동 입력과 자동 추출 데이터 구분

### v2.0 Data-driven Fit Model

- 충분한 피드백 데이터 확보 후 ML 또는 통계 기반 보정
- 브랜드별/카테고리별 사이즈 편차 모델링
- 사용자 체형 데이터와 기준 의류 데이터 결합
