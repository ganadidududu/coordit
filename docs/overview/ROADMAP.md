# 개발 로드맵

문서 상태: 최신  
기준일: 2026-05-19  
관련 문서: `overview/CURRENT_STATUS.md`

이 로드맵은 현재 구현 상태를 기준으로 다음 개발 우선순위를 정리한 문서입니다.

## Phase 1. MVP 안정화

목표: 현재 구현된 기능이 로컬에서 일관되게 동작하도록 정리합니다.

- API 요청/응답 예시를 실제 코드 기준으로 맞추기
- 실측값 입력 key를 snake_case 기준으로 통일하거나 변환 계층 추가
- 주요 API 수동 테스트 시나리오 문서화
- `npm run typecheck`, `npm run build` 기준으로 기본 검증
- 프론트 화면의 메시지와 실제 제품 방향 정렬

## Phase 2. 추천 흐름 완성도 개선

목표: 기준 의류 기반 추천 흐름을 사용자가 막힘 없이 수행하게 만듭니다.

- 기준 의류 선택 UX 개선
- 외부 상품 사이즈표 입력 UX 개선
- 추천 결과 화면에서 부위별 차이와 confidence 표현 개선
- 추천 결과 이력 화면 개선
- 피드백 등록 흐름을 추천 결과와 자연스럽게 연결

## Phase 3. API/DB 품질 보강

목표: 다른 개발자가 안전하게 확장할 수 있는 백엔드 상태로 만듭니다.

- integration test 추가
- Supabase migration 전략 도입
- `updated_at` 자동 갱신 trigger 도입 검토
- service role key 사용 범위와 user scope 점검
- DB 인덱스 추가 검토
- 에러 응답 코드와 메시지 표준화

## Phase 4. 상품/사이즈표 자동화

목표: 수동 입력 중심의 외부 상품 등록을 자동화합니다.

- URL 기반 상품 파싱 실제 구현
- 사이즈표 텍스트 붙여넣기 파서 구현
- 사이즈표 이미지 OCR 파이프라인 도입
- `external_product_sizes.parsing_status`, `measurement_source`, `extracted_text`, `extraction_confidence` 활용
- 브랜드/쇼핑몰별 사이즈표 정규화 로직 추가

## Phase 5. 추천 엔진 고도화

목표: Rule-based MVP를 실제 피드백 기반 추천으로 확장합니다.

- 사용자 피드백 기반 penalty 조정
- 카테고리별 가중치 개선
- 브랜드별 치수 보정
- 다중 기준 의류 저장 구조 개선
- 추천 결과 분석용 테이블 또는 view 추가

## Phase 6. 배포/운영 준비

목표: MVP를 외부 사용자에게 안정적으로 제공할 준비를 합니다.

- 배포 환경 구성
- 환경변수 관리 체계 정리
- 로깅/모니터링 추가
- CORS 정책 제한
- Supabase RLS 운영 점검
- seed/demo 데이터 분리
