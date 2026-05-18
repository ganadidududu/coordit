# 현재 개발 상황

문서 상태: 최신  
기준일: 2026-05-19  
기준 코드: `backend/src/routes.ts`, `frontend/src/app/*`, `supabase/schema.sql`

현재 coordit은 기준 의류 기반 핏 추천 MVP가 구현된 상태입니다. 백엔드 REST API, Supabase DB 스키마, 주요 프론트 화면은 존재하며, 추천 결과 저장과 로그/피드백 흐름까지 기본 골격이 연결되어 있습니다.

## 구현 완료

### Backend

- Express + TypeScript 서버 구성
- `/health` 헬스 체크
- Supabase Auth 기반 회원가입/로그인
- 보호 API용 `authMiddleware`
- 사용자 프로필 조회/수정
- 신체 치수 등록/조회
- 보유 의류 CRUD
- 보유 의류 실측값 CRUD
- 기준 의류 등록/조회/수정/비활성화
- 외부 상품 등록/조회/수정
- 외부 상품 사이즈표 CRUD
- Fit 추천 단건 실행
- Fit 추천 batch 실행
- 최근 추천 결과 조회
- 추천 결과 단건 조회
- 사용자 피드백 등록/조회
- 추천 로그 조회
- 추천 클릭/구매 이벤트 기록

### Database

- Supabase PostgreSQL schema 작성
- 사용자 소유 데이터용 `user_id` 구조
- 주요 FK 관계 설정
- RLS 활성화 SQL 작성
- 기본 인덱스 SQL 작성
- seed SQL 작성

### Frontend

- Next.js App Router 기반 화면 구성
- API client 구성
- auth context와 token 주입 흐름
- 로그인/회원가입 화면
- 대시보드
- 보유 의류 등록 화면
- 보유 의류 실측값 입력 화면
- 기준 의류 화면
- 외부 상품 등록 화면
- 외부 상품 사이즈표 입력 화면
- 추천 결과 실행/표시 화면
- 공통 UI 컴포넌트 구성

### Fit Engine

- Rule-based 추천 엔진 구현
- 단일/다중 기준 의류 지원
- `preference_score` 기반 다중 기준 의류 가중 평균
- 상의/하의 카테고리별 측정값 가중치 분리
- fit type penalty 적용
- 카테고리 호환성 검사
- 부위별 차이, 설명, 상태, confidence 반환
- 추천 결과와 추천 로그 DB 저장

## 부분 구현 또는 MVP 수준 구현

- `POST /external-products/from-url`은 실제 크롤링이 아니라 mock 데이터 반환입니다.
- 신체 치수는 저장되지만 현재 추천 엔진 핵심 계산에는 적극 반영되지 않습니다.
- 추천 엔진은 ML이 아니라 rule-based입니다.
- `external_product_sizes`의 OCR/파싱 관련 컬럼은 준비되어 있으나 실제 OCR 파이프라인은 없습니다.
- 프론트 랜딩 페이지 일부 문구는 현재 제품 방향인 “실측 기반 핏 추천”보다 더 넓은 스타일링 제품처럼 보일 수 있습니다.
- API 문서와 실제 request key 사이에 과거 camelCase 예시가 있었고, 이번 정리에서 snake_case 중심으로 바로잡았습니다.

## 미구현 또는 보강 필요

- 자동화 테스트
- Supabase migration 디렉터리 또는 migration 운영 방식
- 배포 설정
- 운영 로깅/모니터링
- 엄격한 CORS 정책
- URL scraping/OCR/상품 파서
- 브랜드별 사이즈 보정
- 피드백 기반 추천 개선
- `updated_at` 자동 갱신 trigger
- 다중 기준 의류 결과 저장용 join table

## 개발 시 가장 중요한 주의사항

- 백엔드는 `SUPABASE_SERVICE_ROLE_KEY`로 Supabase client를 생성하므로, 모든 user-owned 쿼리에 `user_id` 필터가 반드시 필요합니다.
- 보호 API는 `routes.use(authMiddleware)` 뒤에 선언되어야 합니다.
- 측정값 필드는 현재 `total_length`, `shoulder_width`처럼 snake_case가 기준입니다.
- 추천 실행 전 기준 의류 실측값과 외부 상품 사이즈표가 모두 있어야 합니다.
- 카테고리가 호환되지 않으면 추천 API는 실패합니다.
