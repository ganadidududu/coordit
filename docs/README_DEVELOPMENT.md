# README 개발 환경 안내

이 문서는 루트 [README](../README.md)의 iOS·Android 및 공통 API 실행 안내를 보완합니다. 웹은 내부 테스트용이며 배포 대상이 아닙니다. 2026-10-16의 소스·설정과 일회용 로컬 DB 검증을 기준으로 작성했습니다.

AR·봉제점·의류 실측 모델 개발은 [AR 전용 개발 브랜치 안내](AR_DEVELOPMENT_BRANCH.md)를 따른다. 일반 앱의 카메라/AR 비활성화 상태와 별도 Debug 시험 경로를 구분한다.

## Prerequisites

| 대상 | 준비 사항 |
| --- | --- |
| 공통 API | Node.js 22(CI 기준), npm, 별도의 개발용 Supabase 프로젝트 |
| URL import | backend에서 `npx playwright install chromium`; Linux에서는 필요한 OS 의존성도 설치 |
| iOS | iOS 26.5 SDK와 Simulator runtime을 지원하는 Xcode, SimSlim. scheme `coordit` |
| Android | JDK 17 이상, Android SDK 35. [Android 실행 안내](../android/README.md) 참조 |

루트에는 npm workspace가 없습니다. API는 `backend/package-lock.json`을 사용하며, `backend/`에서 실행하면 dotenv가 해당 디렉터리의 환경파일을 읽습니다. 모바일 앱은 각각 Xcode와 Gradle로 빌드합니다.

## Database

### 새 개발용 Supabase 프로젝트

아래는 **빈 개발 DB에만** 적용하는 순서입니다. Supabase가 제공하는 `auth.users`, `auth.uid()`, `auth.role()`와 기본 역할이 있는 환경을 전제로 합니다.

| 순서 | SQL 파일 | 추가되는 기능 |
| --- | --- | --- |
| 1 | [schema.sql](../supabase/schema.sql) | 사용자·동의, 옷장·실측·기준 의류, 상품·사이즈, 분석·피드백·로그 |
| 2 | [indexes.sql](../supabase/indexes.sql) | 조회 인덱스 |
| 3 | [rls.sql](../supabase/rls.sql) | 소유자 기준 데이터 접근 정책 |
| 4 | [20260730_add_atomic_closet_save.sql](../supabase/migrations/20260730_add_atomic_closet_save.sql) | 의류와 실측의 원자적 저장 RPC |
| 5 | [20260730_add_thread_wallet.sql](../supabase/migrations/20260730_add_thread_wallet.sql) | 실타래 지갑·원장과 분석 저장 RPC |
| 6 | [20260806_add_fit_report_thread_charge.sql](../supabase/migrations/20260806_add_fit_report_thread_charge.sql) | 상세 리포트 차감, 기본 추천과 차감 단계 분리 |
| 7 | [20260809_add_apple_iap_thread_credit.sql](../supabase/migrations/20260809_add_apple_iap_thread_credit.sql) | Apple 구매 정산 테이블·함수 |
| 8 | [20260811_add_admob_rewarded_ssv.sql](../supabase/migrations/20260811_add_admob_rewarded_ssv.sql) | 광고 보상 시도·정산 |
| 9 | [20260814_harden_admob_reward_atomicity.sql](../supabase/migrations/20260814_harden_admob_reward_atomicity.sql) | 광고 보상과 리포트 차감의 원자성 보강 |
| 10 | [20260821_add_apple_iap_notification_receipts.sql](../supabase/migrations/20260821_add_apple_iap_notification_receipts.sql) | Apple 서버 알림 영수증·중복 처리 |
| 11 | [20260826_seed_new_user_thread_balance.sql](../supabase/migrations/20260826_seed_new_user_thread_balance.sql) | 신규 사용자 잔액 초기화 trigger |
| 12 | [20260902_add_guest_devicecheck_auth.sql](../supabase/migrations/20260902_add_guest_devicecheck_auth.sql) | 비회원 구분, DeviceCheck 지급 상태, 계정 병합 RPC |

이 순서는 일회용 PostgreSQL에서 Supabase Auth의 테이블·함수·역할을 최소 구성해 SQL 적용을 검증했습니다. Supabase Auth 서비스, 권한별 데이터 접근, 결제·광고 E2E 검증을 대신하지는 않습니다. 결제·광고는 스키마가 있어도 서버 활성화 플래그가 false이면 제공되지 않습니다.

기본 `schema.sql`에는 이미 동의, 부위별 피드백, 의류 비교 기록, 상품 URL 관련 필드가 포함됩니다. 과거 마이그레이션을 날짜순으로 전부 재실행하지 않습니다. `seed.sql`은 선택 사항이며 **실제 개발용 Auth 사용자 UUID로 치환한 뒤** 실행해야 합니다. 로그인 계정을 자동으로 만들어 주는 파일이 아닙니다.

내부 테스트용 웹의 스타일링 테이블은 모바일 제품 기능과 별개입니다. 기본 스키마에는 `styling_looks`가 없으며, 역사적 [20260511_add_styling_looks.sql](../supabase/migrations/20260511_add_styling_looks.sql)은 테이블 생성만 하고 RLS를 구성하지 않습니다. 이 README의 기본 핏 데모에는 해당 테이블이 필요하지 않습니다.

**비회원 계정 병합은 추가 의존성이 있습니다.** 12번 SQL의 병합 함수가 `styling_looks`도 갱신하므로, 위 기본 목록만 적용한 DB에서는 병합이 실패합니다. 계정 연결·병합까지 시험하려면 해당 테이블과 접근 정책을 별도로 준비해야 합니다. SQL 생성 성공과 함수의 모든 실행 경로 검증은 다릅니다.

### 기존 DB / 운영 배포

기존 프로젝트에는 위 목록을 그대로 적용하지 않습니다. 특히 아래 파일은 특정 스키마 상태와 전용 runner 문맥을 검사하는 운영용 전진 마이그레이션입니다.

- `20260822_reconcile_monetization_release_schema.sql`
- `20260824_reconcile_profile_styling_schema.sql`
- `20260825_finalize_styling_schema.sql`

일반 SQL 초기화 스크립트처럼 실행하면 거절되도록 작성되어 있습니다. 기존 DB의 상태별 절차는 [운영 배포 문서](DEPLOYMENT_PRODUCTION.md)를 따릅니다. [스테이징 가이드](DEPLOYMENT_STAGING.md)의 초기 SQL 목록에는 최신 앱에 필요한 atomic closet save와 이후 기능들이 모두 나열되어 있지 않으므로, 새 개발 환경은 위 목록과 현재 코드를 함께 기준으로 삼습니다.

## Authentication

- **Android:** Google Android client와 앱 서명을 등록하고 `GOOGLE_WEB_CLIENT_ID`를 설정합니다. [Google 로그인 설정](../android/docs/GOOGLE_SIGN_IN_SETUP.md)을 따릅니다. Apple 로그인과 Google Play 정산은 아직 구현 대상입니다.
- **iOS:** Google·Apple 네이티브 로그인 설정과 서버 Auth 설정이 함께 필요합니다. 기존 이메일 계정 로그인도 지원합니다. 회원가입 API는 `POST /auth/signup`, 소셜 로그인 API는 `/auth/google`, `/auth/apple`입니다.
- **비회원:** Supabase anonymous sign-in이 필요합니다. 계정 연결 기능은 manual identity linking 설정도 사용합니다. 환영 실타래 지급은 Apple DeviceCheck 설정과 실기기 검증이 별도이며, Simulator fixture 성공으로 검증되지 않습니다.
- **Onboarding:** `/auth/onboarding`과 `/auth/onboarding/status`를 사용합니다. 일반 제품 API는 인증 후 온보딩 검사도 통과해야 합니다. 키·몸무게는 선택 입력입니다.

자세한 출시 조건은 [RELEASE_READINESS.md](RELEASE_READINESS.md)에 있습니다.

## Environment details

| 기능 | 변수 / 기본값 | 비고 |
| --- | --- | --- |
| API | `PORT=4000`, `NODE_ENV=development` | development에서 localhost:3000과 127.0.0.1:3000 허용 |
| 프록시 | `TRUST_PROXY_HOPS=1` | API 앞의 리버스 프록시 수. Cloud Run은 1, 클라이언트가 직접 접속하는 배포만 0. 동의 기록의 IP가 이 값에 따라 정해짐 |
| production CORS | `CORS_ORIGINS` | 쉼표로 구분한 정확한 HTTPS origin. 경로·마지막 `/` 제외 |
| Supabase | `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` | 세 값은 서버 시작에 필수. service-role key는 서버에만 보관 |
| iOS | `COORDIT_API_BASE_URL` | Xcode build setting. Simulator 로컬 API는 `http://127.0.0.1:4000` |
| Android | `COORDIT_API_BASE_URL`, `COORDIT_RELEASE_API_BASE_URL`, `GOOGLE_WEB_CLIENT_ID` | Gradle 속성. Emulator 로컬 API는 `http://10.0.2.2:4000/`, release는 HTTPS 필수 |
| Fit report | `OPENROUTER_API_KEY`, `OPENROUTER_MODEL=google/gemini-2.5-flash`, `OPENROUTER_TIMEOUT_MS=20000` | 키 미설정·호출 실패 시 deterministic fallback 경로 |
| DeviceCheck | `APPLE_DEVICECHECK_KEY_ID`, `APPLE_DEVICECHECK_TEAM_ID`, `APPLE_DEVICECHECK_PRIVATE_KEY`, `APPLE_DEVICECHECK_ENVIRONMENT` | 서버 설정. 기본 environment는 production |
| Apple IAP | `APPLE_IAP_ENABLED=false`, `APPLE_IAP_BUNDLE_ID`, `APPLE_IAP_APPLE_ID`, `APPLE_IAP_ROOT_CERTIFICATE_PATHS` | 인증서 파일과 verifier 초기화 조건도 만족해야 활성화 |
| AdMob | `ADMOB_REWARDED_ENABLED=false`, `ADMOB_REWARDED_AD_UNIT_ID`, `ADMOB_REWARD_ITEM`, `ADMOB_REWARD_AMOUNT`, `ADMOB_SSV_VALIDATION_CUSTOM_DATA` | 서명된 SSV callback으로 정산 |
| URL import | `CRAWL_TIMEOUT_MS`, `PAGE_LOAD_TIMEOUT_MS`, `MAX_CONCURRENT_PAGES`, `MAX_REDIRECTS`, `MAX_JSON_RESPONSE_BYTES`, `MAX_HTML_BYTES`, `MAX_IMAGES` | 기본값은 [env.ts](../backend/src/config/env.ts) 참조 |
| URL 요청 제한 | `DOMAIN_REQUEST_DELAY_MS`, `USER_RATE_LIMIT_PER_MINUTE`, `USER_AGENT` | 도메인 대기 간격·사용자 요청 횟수 제한 |

서버 예제는 [backend/.env.example](../backend/.env.example)을 사용합니다. 모바일 API·로그인 설정은 각 플랫폼의 빌드 설정으로 전달합니다. `JWT_SECRET`은 서버 예제에 존재하지만 현재 Bearer 인증은 Supabase에 검증을 위임합니다.

## 검증 범위

루트 README의 iOS 데모는 서버 요청을 fixture로 대체한 **실제 앱 UI 실행**입니다. 실제 로그인·상품 사이트 추출·DB 저장·외부 모델 호출은 별도 개발 계정으로 확인해야 합니다. 이 작업에서는 운영 데이터에 쓰지 않았습니다.

실행한 명령과 캡처 조건은 [README_EVIDENCE.md](README_EVIDENCE.md)에 있습니다.
