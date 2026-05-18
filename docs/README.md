# coordit 개발 문서

문서 상태: 최신 정리본  
기준일: 2026-05-19  
기준 코드: `backend/src/routes.ts`, `supabase/schema.sql`, `frontend/src/app/*`

이 디렉터리는 coordit 프로젝트를 개발, 유지보수, 발표, 인수할 때 필요한 문서를 목적별로 나눈 공간입니다. 핸드오버 문서는 현재 정리 범위에서 제외했습니다.

## 먼저 읽을 문서

처음 프로젝트를 보는 사람은 아래 순서로 읽으면 됩니다.

1. `overview/PROJECT_OVERVIEW.md`
2. `overview/CURRENT_STATUS.md`
3. `overview/ROADMAP.md`

백엔드/API/DB를 보는 사람은 아래 순서가 좋습니다.

1. `backend/ARCHITECTURE.md`
2. `backend/AUTH_AND_SECURITY.md`
3. `backend/API_REFERENCE.md`
4. `backend/DATABASE_SCHEMA.md`
5. `backend/API_FLOW.md`

프론트엔드를 보는 사람은 아래 순서가 좋습니다.

1. `frontend/ARCHITECTURE.md`
2. `frontend/ROUTES_AND_SCREENS.md`
3. `backend/API_REFERENCE.md`

추천 엔진을 보는 사람은 아래 순서가 좋습니다.

1. `fit-engine/FIT_ENGINE.md`
2. `fit-engine/FIT_ENGINE_CHANGELOG.md`

## 디렉터리 구조

```text
docs/
  README.md
  overview/
    PROJECT_OVERVIEW.md
    CURRENT_STATUS.md
    ROADMAP.md
  backend/
    ARCHITECTURE.md
    API_REFERENCE.md
    API_FLOW.md
    DATABASE_SCHEMA.md
    AUTH_AND_SECURITY.md
  frontend/
    ARCHITECTURE.md
    ROUTES_AND_SCREENS.md
  fit-engine/
    FIT_ENGINE.md
    FIT_ENGINE_CHANGELOG.md
  archive/
    old/
```

## 문서별 역할

| 문서 | 역할 |
| --- | --- |
| `overview/PROJECT_OVERVIEW.md` | coordit의 제품 목적과 전체 구조 |
| `overview/CURRENT_STATUS.md` | 현재 구현 완료/부분 구현/미구현 상태 |
| `overview/ROADMAP.md` | 앞으로 개발할 우선순위 |
| `backend/ARCHITECTURE.md` | 백엔드 코드 구조와 모듈 레이어 |
| `backend/AUTH_AND_SECURITY.md` | 인증, 토큰, user scope, RLS 주의사항 |
| `backend/API_REFERENCE.md` | 현재 Express 라우트 기준 API 목록 |
| `backend/API_FLOW.md` | MVP 사용 흐름과 추천 실행 흐름 |
| `backend/DATABASE_SCHEMA.md` | Supabase 테이블, 관계, 인덱스, RLS 요약 |
| `frontend/ARCHITECTURE.md` | Next.js 프론트엔드 구조와 상태 흐름 |
| `frontend/ROUTES_AND_SCREENS.md` | 현재 구현된 화면과 연결 API |
| `fit-engine/FIT_ENGINE.md` | 현재 추천 엔진 동작 기준 |
| `fit-engine/FIT_ENGINE_CHANGELOG.md` | 추천 엔진 변경 이력과 다음 개선 후보 |

## 문서 관리 원칙

- 실제 코드와 맞지 않는 문서는 유지하지 않습니다.
- API 목록은 `backend/src/routes.ts`를 기준으로 갱신합니다.
- DB 구조는 `supabase/schema.sql`, `supabase/indexes.sql`, `supabase/rls.sql`을 기준으로 갱신합니다.
- 추천 알고리즘은 `backend/src/modules/fit/*`를 기준으로 갱신합니다.
- 오래된 문서를 남겨야 할 때는 `archive/old/`로 옮기고, 최신 문서에서는 링크하지 않습니다.
