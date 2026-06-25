# Docs Refactor Analysis

문서 상태: 리팩토링 분석 완료  
기준일: 2026-06-25  
작업 범위: `docs/` 문서만 분석 및 재구성

## 1. 목적

현재 Coordit 문서는 웹 MVP 개발 과정에서 점진적으로 늘어나면서 제품 설명, API 흐름, DB 구조, Fit Engine 동작, 로드맵이 여러 문서에 반복되어 있다. 모바일 앱 MVP 개발 관점에서는 읽어야 할 문서가 많고, 같은 내용을 여러 곳에서 수정해야 하는 유지보수 비용이 발생한다.

이번 리팩토링의 목표는 다음이다.

- 문서 수 최소화
- 중복 설명 제거
- 문서별 책임 분리
- 모바일 앱 MVP 개발 기준으로 재정리

## 2. 기존 문서 목록과 목적

| 기존 문서 | 목적 | 판단 |
| --- | --- | --- |
| `docs/README.md` | 문서 인덱스 | 최종 구조 기준으로 재작성 |
| `docs/overview/PROJECT_OVERVIEW.md` | 제품 개요 | `docs/PRODUCT_OVERVIEW.md`로 통합 |
| `docs/overview/CURRENT_STATUS.md` | 현재 구현 상태 | `ROADMAP.md` 일부로 흡수 |
| `docs/overview/ROADMAP.md` | 개발 계획 | `ROADMAP.md`로 이동 및 재작성 |
| `docs/app/APP_FEATURE_SPEC.md` | 앱 기능 명세 | `PRODUCT_OVERVIEW.md`, `API_SPEC_MOBILE.md`로 흡수 |
| `docs/app/APP_SCREEN_SPEC.md` | 4개 탭 화면 명세 | `PRODUCT_OVERVIEW.md`, `API_SPEC_MOBILE.md`로 흡수 |
| `docs/backend/API_REFERENCE.md` | REST API 목록 | `API_SPEC_MOBILE.md`로 재작성 |
| `docs/backend/API_FLOW.md` | API 호출 순서 | `API_SPEC_MOBILE.md`로 흡수 |
| `docs/backend/DATABASE_SCHEMA.md` | DB 스키마 | `DATABASE_SCHEMA.md`로 이동 및 정리 |
| `docs/backend/AUTH_AND_SECURITY.md` | 인증/보안 | API 인증 요약과 DB RLS 섹션으로 분리 흡수 |
| `docs/backend/ARCHITECTURE.md` | 백엔드 코드 구조 | 모바일 MVP 문서 체계에서는 제거 |
| `docs/frontend/ARCHITECTURE.md` | 웹 프론트 구조 | 모바일 MVP 문서 체계에서는 제거 |
| `docs/frontend/ROUTES_AND_SCREENS.md` | 웹 라우트와 화면 | 모바일 4탭 구조로 대체 |
| `docs/fit-engine/FIT_ENGINE.md` | 추천 알고리즘 | 유지하되 엔진 설명만 남기도록 정리 |
| `docs/fit-engine/FIT_ENGINE_CHANGELOG.md` | 엔진 변경 이력 | 유지 |
| `docs/archive/old/README.md` | 과거 문서 보관 안내 | 최종 단순 구조에서 제거 |

## 3. 주요 중복 내용

### 3.1 제품 정의 중복

반복 위치:

- `overview/PROJECT_OVERVIEW.md`
- `overview/CURRENT_STATUS.md`
- `app/APP_FEATURE_SPEC.md`
- `app/APP_SCREEN_SPEC.md`
- `README.md`

정리 방향:

- 제품 정의, 문제 정의, 가치, MVP 범위는 `PRODUCT_OVERVIEW.md`에만 둔다.

### 3.2 사용자 흐름 중복

반복 위치:

- `overview/PROJECT_OVERVIEW.md`
- `backend/API_FLOW.md`
- `frontend/ROUTES_AND_SCREENS.md`
- `app/APP_FEATURE_SPEC.md`
- `app/APP_SCREEN_SPEC.md`

정리 방향:

- 제품 관점의 큰 흐름은 `PRODUCT_OVERVIEW.md`에 둔다.
- API 호출 관점의 흐름은 `API_SPEC_MOBILE.md`에 둔다.
- 웹 라우트 중심 설명은 제거한다.

### 3.3 API 설명 중복

반복 위치:

- `backend/API_REFERENCE.md`
- `backend/API_FLOW.md`
- `frontend/ROUTES_AND_SCREENS.md`
- `app/APP_FEATURE_SPEC.md`
- `app/APP_SCREEN_SPEC.md`

정리 방향:

- 모바일 앱 화면과 사용자 플로우 중심 API만 `API_SPEC_MOBILE.md`에 둔다.
- SQL, 테이블, 레이어, repository/service/controller 설명은 API 문서에서 제거한다.

### 3.4 DB 설명 중복

반복 위치:

- `backend/DATABASE_SCHEMA.md`
- `overview/PROJECT_OVERVIEW.md`
- `overview/CURRENT_STATUS.md`
- `backend/API_FLOW.md`
- `fit-engine/FIT_ENGINE.md`

정리 방향:

- 테이블, 관계, 인덱스, RLS, migration은 `DATABASE_SCHEMA.md`에만 둔다.
- 다른 문서에서는 DB 테이블 상세를 반복하지 않는다.

### 3.5 Fit Engine 설명 중복

반복 위치:

- `fit-engine/FIT_ENGINE.md`
- `fit-engine/FIT_ENGINE_CHANGELOG.md`
- `backend/API_FLOW.md`
- `backend/API_REFERENCE.md`
- `overview/CURRENT_STATUS.md`
- `DATABASE_SCHEMA.md`

정리 방향:

- 알고리즘 입력, 계산 과정, 다중 기준 의류, 표준편차 기반 가중치, 점수, confidence, feedback 구조는 `fit-engine/FIT_ENGINE.md`에 둔다.
- API 문서에서는 Fit Lab 기능이 어떤 엔진 개념을 사용해 응답하는지만 간단히 설명한다.

### 3.6 로드맵 중복

반복 위치:

- `overview/ROADMAP.md`
- `overview/CURRENT_STATUS.md`
- `app/APP_FEATURE_SPEC.md`
- `fit-engine/FIT_ENGINE_CHANGELOG.md`

정리 방향:

- 제품/개발 단계 계획은 `ROADMAP.md`에 둔다.
- 엔진 버전별 변경 이력은 `fit-engine/FIT_ENGINE_CHANGELOG.md`에만 둔다.

## 4. 통합 결과

| 최종 문서 | 흡수한 기존 문서 |
| --- | --- |
| `PRODUCT_OVERVIEW.md` | `overview/PROJECT_OVERVIEW.md`, `app/APP_FEATURE_SPEC.md`, `app/APP_SCREEN_SPEC.md` |
| `API_SPEC_MOBILE.md` | `backend/API_REFERENCE.md`, `backend/API_FLOW.md`, `frontend/ROUTES_AND_SCREENS.md`, 앱 문서의 API 관련 내용 |
| `DATABASE_SCHEMA.md` | `backend/DATABASE_SCHEMA.md`, `backend/AUTH_AND_SECURITY.md`의 RLS/권한 내용 |
| `fit-engine/FIT_ENGINE.md` | 기존 `fit-engine/FIT_ENGINE.md`에서 API/DB 저장 설명 제거 |
| `ROADMAP.md` | `overview/ROADMAP.md`, `overview/CURRENT_STATUS.md` |
| `fit-engine/FIT_ENGINE_CHANGELOG.md` | 유지 |

## 5. 삭제 후보와 사유

| 삭제 후보 | 사유 |
| --- | --- |
| `overview/` | 제품 개요/상태/로드맵이 새 문서로 통합됨 |
| `app/` | 앱 기능/화면 명세가 제품 개요와 모바일 API 문서로 흡수됨 |
| `backend/` | API/DB/Auth 문서가 새 구조로 분리되고, backend architecture는 최종 목표 범위 밖임 |
| `frontend/` | 웹 라우트 문서는 모바일 앱 MVP 기준에서 제거 대상임 |
| `archive/old/` | 최종 문서 구조 단순화를 위해 제거 대상임 |
| `docs/.DS_Store` | 문서가 아닌 OS 메타데이터 파일임 |

## 6. 최종 문서 책임

| 읽고 싶은 내용 | 볼 문서 |
| --- | --- |
| 기획, 문제, 가치, MVP 범위 | `PRODUCT_OVERVIEW.md` |
| 모바일 앱 API | `API_SPEC_MOBILE.md` |
| 추천 알고리즘 | `fit-engine/FIT_ENGINE.md` |
| 추천 엔진 변경 이력 | `fit-engine/FIT_ENGINE_CHANGELOG.md` |
| DB, RLS, 인덱스, migration | `DATABASE_SCHEMA.md` |
| 향후 계획 | `ROADMAP.md` |

단일 파일만 들어있는 폴더는 제거하고 해당 문서를 `docs/` 바로 아래에 배치했다. `fit-engine/`은 `FIT_ENGINE.md`와 `FIT_ENGINE_CHANGELOG.md` 두 문서를 함께 가지므로 유지한다.

## 7. 남은 주의사항

- 이번 작업은 문서 체계만 정리하며 코드, API 구현, DB 스키마는 수정하지 않는다.
- `API_SPEC_MOBILE.md`는 모바일 MVP 관점의 문서이므로 실제 구현과 다른 신규 후보 API는 명확히 `추가 후보`로 표시해야 한다.
- 기존 웹 화면 문서가 제거되므로, 웹 유지보수 문서가 필요해지는 시점에는 별도 웹 문서로 다시 만들 수 있다.
