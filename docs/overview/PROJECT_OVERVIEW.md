# 프로젝트 개요

문서 상태: 최신  
기준일: 2026-05-19  
관련 코드: `README.md`, `backend/src/routes.ts`, `frontend/src/app/*`, `supabase/schema.sql`

coordit은 코디 추천 앱이 아니라, 사용자가 이미 가지고 있는 기준 의류의 실측값을 바탕으로 온라인 상품의 사이즈를 추천하는 핏 추천 MVP입니다.

핵심 질문은 다음과 같습니다.

> 내가 이미 잘 맞는다고 느끼는 옷과 비교했을 때, 새로 사려는 상품은 어떤 사이즈가 가장 비슷한 핏일까?

## 제품 방향

현재 구현은 TPO, 날씨, 스타일링 큐레이션보다 실측 기반 사이즈 추천에 집중합니다. 사용자가 자신의 보유 의류와 실측값을 등록하고, 그중 잘 맞는 옷을 기준 의류로 지정한 뒤, 외부 상품의 사이즈표와 비교해 가장 가까운 사이즈를 추천합니다.

## 핵심 사용자 흐름

1. 회원가입 또는 로그인
2. 보유 의류 등록
3. 보유 의류 실측값 입력
4. 기준 의류 등록
5. 외부 상품 등록
6. 외부 상품 사이즈표 입력
7. Fit 추천 실행
8. 추천 결과 확인
9. 피드백 또는 추천 로그 기록

## 시스템 구성

```text
coordit-dev/
  backend/    Express + TypeScript REST API
  frontend/   Next.js App Router UI
  supabase/   PostgreSQL schema, indexes, RLS, seed
  docs/       개발 문서
```

## 기술 스택

| 영역 | 기술 |
| --- | --- |
| Frontend | Next.js App Router, React, TypeScript, Tailwind CSS |
| Backend | Node.js, Express, TypeScript |
| Database | Supabase PostgreSQL |
| Auth | Supabase Auth access token + Express middleware |
| Recommendation | Rule-based Fit Engine |

## 현재 MVP의 핵심 데이터

추천 품질에 직접 영향을 주는 데이터는 다음입니다.

- `clothing_items`: 사용자가 보유한 의류 정보
- `clothing_sizes`: 보유 의류의 실측값
- `reference_clothing`: 추천 기준으로 선택된 보유 의류
- `external_products`: 비교 대상 외부 상품
- `external_product_sizes`: 외부 상품의 사이즈표
- `fit_analysis_results`: 추천 실행 결과
- `recommendation_logs`: 추천 노출/클릭/구매 로그
- `user_feedback`: 실제 착용 또는 구매 후 피드백

## 현재 구현의 성격

현재 프로젝트는 기능 검증용 MVP입니다. Supabase와 REST API, 주요 프론트 화면은 연결되어 있으나, 운영 수준의 테스트/배포/마이그레이션 체계는 아직 보강이 필요합니다.

특히 `POST /external-products/from-url`은 실제 크롤링이 아니라 mock 데이터 반환 기능입니다. OCR, URL 파싱, 브랜드별 보정, ML 학습은 확장 후보입니다.
