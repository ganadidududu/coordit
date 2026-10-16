# README 조사·캡처·검증 기록

기준일: 2026-10-16. 이 기록은 루트 README에 실린 사실과 화면의 근거를 남깁니다. 제품 출시 또는 운영 서비스 전체 검증 보고서는 아닙니다.

## 조사 결과

| 항목 | 확인한 구현 / 근거 |
| --- | --- |
| 제품 플랫폼 | iOS·Android. 본문의 실제 캡처는 SwiftUI iOS 앱. [RootView](../coordit/coordit/CoorditRootView.swift), [FrameRoute](../coordit/coordit/CoorditFrameRoute.swift), [DESIGN.md](../DESIGN.md) |
| 첫 실행·인증 | splash와 provider sheet. [인증 UI](../coordit/coordit/CoorditSplashAuthenticationSheet.swift), [서버 인증](../backend/src/modules/auth/auth.service.ts), [Bearer 검증](../backend/src/middleware/auth.middleware.ts) |
| 등록 | 링크·사진·직접 입력. 이름, 상하의·세부 카테고리, cm 실측. [Closet 등록](../coordit/coordit/CoorditClosetAddFlow.swift) |
| 기준 옷 | Home 선택 sheet와 Fit Lab 기준 의류 선택. [Home](../coordit/coordit/CoorditHomeScreens.swift), [RootView](../coordit/coordit/CoorditRootView.swift) |
| OCR | iOS Vision OCR와 검토 입력 UI. [Extractor](../coordit/coordit/CoorditFitLabSizeExtractor.swift), [OCR UI](../coordit/coordit/CoorditFitLabOCRInput.swift) |
| 상품 / 사이즈표 | [수동 입력](../coordit/coordit/CoorditFitLabManualInput.swift), [URL 입력](../coordit/coordit/CoorditFitLabURLInput.swift), [API](../coordit/coordit/CoorditFitLabAPI.swift) |
| 추천 호출 | [Coordinator](../coordit/coordit/CoorditFitLabCoordinator.swift), [서버 service](../backend/src/modules/fit/fit.service.ts) |
| 결과 화면 | [Fit Lab screens](../coordit/coordit/CoorditFitLabScreens.swift), [점수 컴포넌트](../coordit/coordit/CoorditFitLabScoreComponents.swift) |
| 히스토리 | [FileHistoryStore](../coordit/coordit/CoorditFitLabHistoryStore.swift), [상세 UI](../coordit/coordit/CoorditFitLabHistoryDetailScreen.swift). 사용자별 로컬 스냅샷 |
| 피드백 | [routes](../backend/src/routes.ts), [feedback profile](../backend/src/modules/fit/feedback-fit-profile.builder.ts). 서버 API·보정 구현, iOS 입력 UI 연결은 확인되지 않음 |
| 카테고리 / 핏 | [garment profiles](../backend/src/modules/fit/garment-fit-profiles.ts), [tolerance](../backend/src/modules/fit/fit-tolerance.ts), [V2](../backend/src/modules/fit/fit-score.v2.ts) |
| 웹 | 사용자 확인에 따라 내부 테스트용·배포 제외로 명시. 제품 소개·아키텍처·스택·실행 안내에서 제외. 기존 조사·실행 기록은 아래에 보존 |
| Android | Kotlin/Compose 구현과 [포팅 상태](../android/docs/IMPLEMENTATION_STATUS.md). 전체 출시 완료로 표현하지 않음 |
| DB / 배포 | schema/indexes/RLS 및 기능별 SQL, Dockerfile, backend CI, staging/production 배포 문서 |

## 기존 README에서 바로잡은 내용

- Next.js 중심 목록에 없던 iOS·Android와 공유 확장, 실제 모바일 제품 흐름을 추가했다.
- `JWT-ready` 대신 Supabase `auth.getUser`를 통한 현재 토큰 검증을 설명했다.
- OCR·상품 URL 가져오기·피드백 보정·RLS를 무조건 미래 기능으로 분류하지 않았다. 구현, 베타, 앱 미연결 범위를 나눴다.
- 단순 가중 절대거리 설명을 V2의 방향별 tolerance, Huber loss, 부위 조합 감점, 다중 기준 프로필로 교체했다.
- 모든 핏 타입을 iOS에서 선택할 수 있다고 쓰지 않았다. 현재 iOS 생성 요청의 `regular`와 API의 네 가지 지원 타입을 구분했다.
- 서버 분석 기록과 사용자가 명시적으로 저장한 기기 로컬 히스토리를 구분했다.
- 기본 schema/indexes/RLS만으로 최신 앱 실행이 끝난다고 안내하지 않았다. atomic closet save·지갑·상세 리포트·비회원 등 후속 SQL 순서를 분리했다.
- 비회원 병합 함수의 `styling_looks` 의존성도 확인했다. 기본 SQL 목록의 생성 성공만으로 계정 병합까지 준비되었다고 안내하지 않았다.
- 작업 중 함께 반영된 저장소 정리의 `tools/`, `frontend/public/logo.png`, 플랫폼별 폴더·문서 안내를 새 README에 유지했다.
- 제품 플랫폼을 iOS·Android로 한정했다. 웹은 내부 테스트용으로 명시하고, Android Emulator의 로컬 API 연결·실행 안내를 추가했다. Android 명령은 Gradle 설정·기존 검증 문서와 대조했으며 이번 작업에서 Android 빌드를 재실행하지 않았다.

## 캡처 방식

- iPhone 17 Pro / iOS 26.5, 402 × 874pt 화면, Debug scheme `coordit`.
- `simslim list --json` 후 `config/simslim/coordit-dev.json` 적용 및 verify 통과. 필수 기능 doctor는 push, StoreKit, universal links, keychain sync, photos 5/5 통과.
- XcodeBuildMCP로 소스에서 빌드·설치. `COORDIT_API_BASE_URL=http://127.0.0.1:4000`으로 staging 연결을 덮어썼다.
- XcodeBuildMCP UI 조작과 `xcrun simctl io … screenshot`으로 실제 화면을 캡처했다. 이미지 재생성·UI 합성·가짜 결과 삽입은 하지 않았다.
- 데이터는 기존 [FitLabFixtures](../coordit/coordit/CoorditFitLabFixtures.swift), Closet `seedItems`, `--coordit-test-reference-fit-profiles`를 사용했다. 화면의 사진 없음 placeholder도 실제 구현 그대로다.
- README를 위한 제품 소스 수정, 운영 DB 쓰기, 실제 소셜 로그인·결제·광고 정산·외부 LLM 호출은 하지 않았다.
- 정적 화면 순서가 입력값과 결과를 읽기 쉬워 GIF는 추가하지 않았다.

### 이미지 목록

모든 파일은 [images/readme/](images/readme/)에 있다. 원본 화면 비율을 유지해 README용으로 축소했다.

| 파일 | 캡처한 화면 / 데이터 |
| --- | --- |
| [wardrobe.png](images/readme/wardrobe.png) | Closet의 기준 실측, 카테고리, 보유 의류. `closet-overview` + reference-fit-profiles fixture |
| [add-clothing.png](images/readme/add-clothing.png) | 직접 등록 폼의 초기 상태. `closet-add-manual` |
| [reference-selection.png](images/readme/reference-selection.png) | Home → 옷장에서 선택 → Oxford Shirt 체크 |
| [product-input.png](images/readme/product-input.png) | `manual-selected-reference` fixture → 직접 입력. 상품·카테고리 |
| [size-chart.png](images/readme/size-chart.png) | 같은 입력 폼을 내려 M 사이즈의 실제 측정값 확인 |
| [fit-analysis.png](images/readme/fit-analysis.png) | `submission-success` fixture에서 기준 옷을 선택한 분석 직전 상태 |
| [recommendation.png](images/readme/recommendation.png) | `fitlab-result-top` + `upper-result`. 추천 M, 92.0점, 마네킹·후보 점수 |
| [score-breakdown.png](images/readme/score-breakdown.png) | 같은 결과의 착용 관점·부위 점수 |
| [measurement-comparison.png](images/readme/measurement-comparison.png) | 같은 결과의 부호 있는 cm 차이 |
| [history.png](images/readme/history.png) | 실제 데모 분석 → 히스토리에 추가 → 최근 핏 분석에 표시 |

`submission-success`에서 기준 옷 선택 → 분석 시작 → 리포트 표시 → 히스토리에 추가 → 최근 핏 분석 표시를 직접 조작했다. 기록된 fixture 요청에는 기준 조회, 상품 생성, M/L 사이즈 생성, 추천, 리포트 요청이 포함되었다. 이는 실제 UI와 fixture API 계약을 확인한 것이며 원격 서버 E2E가 아니다.

등록 폼의 숫자 입력 중 자동화 UI snapshot이 응답하지 않는 경우가 있어 앱을 재실행했다. 입력 완료·저장 성공으로 보고하지 않고, 깨끗한 초기 폼을 사용했다. 등록 API와 원자 저장 SQL은 코드로 조사했으며 실서비스 저장을 검증하지 않았다.

## 실행 검증

| 검사 | 결과 / 범위 |
| --- | --- |
| iOS Debug build | 성공. XcodeBuildMCP build 결과에 warning/error 없음 |
| Simulator 실행 | Closet, 등록 폼, 기준 선택, Fit Lab 입력·결과·히스토리 실제 화면 확인 |
| Backend `typecheck` | 통과 |
| Backend `test:fit` | 통과. 다중 기준, 특이값, 누락 측정, V2, 11개 프로필, 방향별 tolerance, 피드백 적용 조건, 카테고리 호환성 |
| Backend `test:report` | 통과. fallback, 결과 형식, legacy 호환, 멱등성, controller. Vitest의 기존 configLoader 관련 경고 1건 |
| Backend 실행 | loopback Supabase 주소와 테스트용 키로 프로세스 시작; 포트 4100 `/health` → HTTP 200, `ok: true`. DB 서비스 연결 검증 아님 |
| Frontend 의존성 / 실행 | `npm ci` 성공. `npm run dev -- --hostname 127.0.0.1`, 포트 3000 HTTP 200, 독립 Chromium에서 렌더 확인 |
| Frontend `typecheck` | 통과 |
| 새 DB SQL 순서 | 로컬 일회용 PostgreSQL에서 기본 3개 SQL + 기능별 9개 SQL 적용 통과. 추가로 역사적 styling SQL의 테이블 생성 확인, 총 23개 public 테이블. 초기화 도중 운영 DB 접근 없음 |

SQL 검증은 최소 Auth 스텁 역할·함수로 수행했다. Supabase 서비스, RLS 권한별 시나리오와 실제 인증 성공을 검증했다고 주장하지 않는다. 전체 backend CI·Android 빌드·App Store/Play 출시 검증은 이번 문서 작업의 실행 범위 밖이다.

## 렌더 검증

로컬 GFM 파서, GitHub Markdown CSS, Mermaid로 프리뷰를 생성하고 독립 Chromium에서 확인했다. 이 프리뷰는 GitHub와 가까운 로컬 검증이며 GitHub에 게시된 화면 검증은 아니다.

| 항목 | 결과 |
| --- | --- |
| Viewport | 데스크톱 1440 × 900, 모바일 390 × 844 |
| 가로 넘침 | 없음. 모바일 document width 390px |
| 이미지 | README의 로고 1개·캡처 9개 모두 로드 성공 |
| 링크 | 세 문서의 로컬 파일·디렉터리 참조 존재 확인, README 내부 앵커 누락 0개 |
| Mermaid | 제품 흐름·아키텍처 2개 파싱 및 SVG 렌더 성공 |
| 문서 구조 | h1 → h2 → h3 순서, 표 5개와 코드 블록 확인 |
| 시각 검토 | Hero, 사용 흐름, Fit Engine, 아키텍처를 두 viewport에서 캡처해 확인 |
| 이미지 용량 | PNG 10개 합계 3,462,297 bytes, 약 3.3 MiB |
| diff | `git diff --check` 통과 |

HTML은 중앙 정렬과 이미지 크기 지정 등 GitHub가 지원하는 요소만 사용한다. README 자체에는 CSS·JavaScript 의존성이 없다.
