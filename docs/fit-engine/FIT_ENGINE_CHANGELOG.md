# Fit Engine 변경 이력

문서 상태: 최신  
기준일: 2026-05-19  
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

## 다음 개선 후보

### v1.2 Measurement Input Normalization

- camelCase 측정값 입력 지원
- cm/mm 단위 정규화
- 문자열 기반 치수 파싱
- 필수 측정값 부족 시 더 명확한 에러 메시지

### v1.3 Feedback-aware Score Adjustment

- `user_feedback` 기반 penalty 조정
- 사용자별 선호 여유분 학습
- 카테고리별 오차 보정

### v1.4 Product Parsing Confidence

- OCR/URL 파싱 confidence를 추천 confidence에 반영
- `measurement_source`별 신뢰도 차등 적용
- 수동 입력과 자동 추출 데이터 구분

### v2.0 Data-driven Fit Model

- 충분한 피드백 데이터 확보 후 ML 또는 통계 기반 보정
- 브랜드별/카테고리별 사이즈 편차 모델링
- 사용자 체형 데이터와 기준 의류 데이터 결합
