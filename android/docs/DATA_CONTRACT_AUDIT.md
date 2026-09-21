# API·상태·저장소 포팅 계약

기준 `bd1f9311638645a4a1500c2a5693a33482dc1214`, 2026-09-16. 소스 감사 결과이며 실제 서버를 호출해 검증한 문서가 아니다.

## ObservableObject / ViewModel 대응

| 원본 | 상태 소유권 | Kotlin 대응 계획 |
|---|---|---|
| CoorditBackendSessionStore.swift:55 | session/profile/body/onboarding/reference profile/readiness | 앱 범위 SessionRepository + StateFlow |
| CoorditFitLabCoordinator.swift:14 | draft/reference/checkpoint/recommendation/report/history/analysis/banner | app 또는 nav-graph 범위 FitLab ViewModel, 탭 교체 시 유지 |
| CoorditRewardedAdService.swift:71 | 광고 단계·서버 정산 잔액 | wallet scope 광고 adapter 상태 머신 |
| CoorditThreadPurchaseService.swift:231 | 상품·결제 단계·정산 잔액 | wallet scope billing adapter 상태 머신 |
| CoorditRootView.swift:5 | route/closet/draft/reference selection/balance/share URL | root state 및 명시적 navigation state |
| 입력·설정 View의 @State/@Binding | 검토 단계·포커스·지역 편집 값 | rememberSaveable/화면 ViewModel; 원본 수명 반영 |

원본에 화면별 ViewModel 클래스가 모두 갖춰져 있는 것은 아니다. 각 `@State`, `@StateObject`, `@Published`, `@EnvironmentObject` 선언은 [JSON 인벤토리](ios-source-inventory.json)의 `state`에 줄 번호와 함께 있다. DEBUG probe는 production 상태 모델로 가져오지 않는다.

## Model / DTO 목록

전체 nested 타입·CodingKeys 위치는 인벤토리 참조. 아래는 핵심 계약 묶음이다.

| 원본 파일 | 타입/역할 |
|---|---|
| CoorditBackendModels.swift | AuthSession/AuthUser, UserProfile, BodyMeasurement, OnboardingStatus/Completion/Request(+Measurements/Consent), BackendHealth/ErrorResponse, ThreadBalanceResponse |
| 같은 파일 | ClothingItemResponse/WithSizeResponse/SizeResponse, ReferenceClothingResponse, ExternalProductResponse/SizeResponse, MeasurementMap/StatusMap, ReferenceFitProfileResponse, ClosetFitComparisonResponse, FitRecommendation/SizeScore |
| CoorditBackendClient.swift | 소셜 로그인/refresh/profile/clothing/reference/product/size request, 수익화 readiness/reward/검증 DTO 및 HTTP 오류 |
| CoorditFitLabAPIModels.swift | ReferenceRow, URLPrefillRequest/Response.Size, ProductRequest/ExternalProductRow, SizeRequest/ExternalProductSizeRow, RecommendationRequest/Response, AnalysisResultRow, ReportRequest/Response |
| ReportResponse nested | Report/MeasurementAnalysis, ChartData/Comparison/Difference/SizeScore, 부분 응답 및 lossy decoding |
| CoorditFitLabModels.swift | Source, GarmentKind, Category, MeasurementKey, Screen, SubmissionStep, LoadState, Error, SizeDraft, Draft/Validation, SubmissionCheckpoint, OCRMetadata, HistorySnapshot.ProductSummary/ReferenceSummary |
| CoorditFitEngineMapping.swift | 원본 category/측정/fit 의미 매핑 |
| CoorditClosetScreens.swift | ClosetItem, ClosetDraft 등 옷장 UI·입력 모델 |
| CoorditThreadPurchaseService.swift | ThreadProduct/구매 state·플랫폼 거래 데이터 |

응답에 DB snake_case와 service camelCase가 섞여 있다. 전역 snake-case 설정에만 의존하지 말고 Kotlin 필드별 serialized name을 원본 CodingKeys와 대조한다. Swift 추천 decoder의 알 수 없는 치수 key 무시, size-score lossy decoding, report 누락 필드의 default/빈 배열 정책을 보존한다. 모든 필드를 non-null 필수로 만들면 iOS에서 표시되던 부분 결과가 실패하게 된다.

## 실제 Swift 호출 API 전체

근거: [CoorditBackendClient.swift](../../coordit/coordit/CoorditBackendClient.swift) L103–335, [CoorditFitLabAPI.swift](../../coordit/coordit/CoorditFitLabAPI.swift) L21–46, [서버 routes](../../backend/src/routes.ts) L80–145.

| 영역 | 메서드 / 경로 |
|---|---|
| 상태 | GET `/health` |
| 로그인 | POST `/auth/google`, `/auth/apple`, `/auth/refresh` |
| 온보딩 | GET `/auth/onboarding/status`; POST `/auth/onboarding` |
| 계정 | GET/PATCH/DELETE `/users/me` |
| 신체 | GET/POST `/body-measurements` |
| 지갑 | GET `/thread-wallet/balance`, `/thread-wallet/monetization-readiness` |
| 보상광고 | POST `/thread-wallet/reward-attempts` |
| Apple 결제 | POST `/thread-wallet/iap/verify` (서버 설정에 따라 조건부 등록) |
| 옷장 | GET/POST `/clothing-items`; POST `/clothing-items/with-size`; DELETE `/clothing-items/{id}` |
| 옷장 사이즈 | GET/POST `/clothing-items/{id}/sizes` |
| 기준 의류 | GET/POST `/reference-clothing`; GET `/reference-clothing/by-category/{category}`; PATCH `/reference-clothing/{id}/deactivate` |
| 비교 | GET `/fit/reference-profile/{garmentKind}`, `/fit/closet-items/{id}/comparison` |
| 상품 | POST `/external-products/from-url`, `/external-products`, `/external-products/{id}/sizes` |
| 분석 | POST `/fit/recommend`; GET `/fit-analysis-results/{id}`; POST `/fit-analysis-results/{id}/report` |

서버 endpoint와 이름상 불일치는 발견하지 못했다. 이는 배포 서버 smoke test를 통과했다는 뜻이 아니다. `/health`는 routes.ts 밖 app.ts에서 처리된다.

서버에만 있고 현재 Swift UI가 호출하지 않는 recent/list 분석, batch 추천, import preview v1, styling, feedback, recommendation logs 및 일부 CRUD/reward-attempt 조회를 새로운 Android 화면 요구사항으로 취급하지 않는다.

인증 경계는 social/refresh/signed webhook(public) → auth middleware → onboarding/account → onboarding middleware → 지갑/옷장/분석이다. 온보딩 전 계정 조회와 제품 진입 허용 여부를 분리한다. JSON + Bearer, 오류 `{message}`. FitLab timeout은 180초다. 원본 공용 send에는 자동 401 retry가 없고 bootstrap에서 refresh한다. Android에 자동 retry를 넣는 경우 mutation/idempotency 및 재인증 루프 의미를 별도 검증한다.

## 로그인·세션 계약

- AuthSession: `accessToken`, `refreshToken`, `user{id,email}`.
- Apple/Google SDK에 SHA256 nonce, backend에는 identity token + 원문 nonce. Android provider flow가 같은 nonce 검증을 충족해야 한다.
- 서버 Supabase `signInWithIdToken(provider, token, nonce)`를 그대로 사용한다. 콘솔 audience/Android 서명 설정은 코드만으로 검증할 수 없다.
- `authenticate()` 순서: 안전한 세션 저장 → session 공개 → profile/body/onboarding 조회. 세션 확보 즉시 인증 UI를 닫는다. 후속 로딩 실패가 로그인 UI를 붙잡지 않게 한다.
- `bootstrap()`에서 저장 세션 refresh 후 health/account/onboarding 조회. invalid refresh에서는 로컬 세션 제거.
- 로그아웃은 로컬 세션 삭제이며 서버 logout API 호출은 없다.
- 신규 지갑 기본값 3개는 서버 migration의 정책이다. Android 클라이언트에서 임의 지급하지 않는다.

## 로컬 저장소 전체

| 데이터 | 실제 iOS 저장/근거 | Android 대응 계획 |
|---|---|---|
| access/refresh session | Keychain; BackendTokenStore L5–46, update 우선·ThisDeviceOnly | Keystore 기반 암호화 private 저장, atomic 갱신 |
| onboarding | SessionStore L861, user-ID별 UserDefaults | 사용자별 DataStore, 서버 재확인 |
| welcome | WelcomeLaunchState L22–36 | DataStore |
| API 주소 | BackendClient L24–59; launch args→Info.plist→UserDefaults, release HTTPS | variant 설정, emulator 주소 별도 |
| 마케팅 설정 | MyPageScreens L20 AppStorage | DataStore + OS 권한 별도 상태 |
| 분석 idempotency | FitLabCoordinator L494–543 fingerprint+UUID | 사용자/draft 기준 영속 key |
| FitLab history | HistoryStore actor, Application Support/CoorditFitLabHistory | 사용자별 atomic JSON, 동일 version/복구 정책 |
| pending share URL | App Group UserDefaults FIFO·중복 제거 | 영속 내부 queue + ACTION_SEND/ACTION_VIEW |
| 옷장 사진 | ClosetItem.imageData 메모리, server reload 때 local imageData만 보존 | parity는 메모리; 업로드/영속화는 추가 기능으로 구분 |
| 소개/아바타/일부 privacy 토글 | 지역 @State | 지역 상태 유지; 현재 서버 저장된다고 가정 금지 |

FitLab 기록은 서버 최근 목록 동기화가 아닌 로컬 snapshot이다. schema v2, 사용자별 최대 50개, atomic write/rename, legacy migration, 손상 파일 quarantine, 경로/symlink 검증이 있다. 제품/기준 옷/추천/리포트/chart/source 정보를 저장한다. 다른 사용자 기록 노출, 로그아웃/탈퇴 처리, 손상 파일 복구를 테스트해야 한다. Android에서 기존 iOS 기기 파일을 자동 이전할 수 있다고 가정하지 않는다.

## 분석·재시도·실 차감

원본 Coordinator L344–419: 상품 생성 → 각 사이즈 생성 → 추천 → 리포트. 이미 생성한 ID와 checkpoint를 유지해 단계별 재시도한다. 추천 fingerprint idempotency key와 report UUID를 구분한다. 서버 `availableThreads`가 잔액 권위이며 클라이언트 계산으로 보상을 지급하지 않는다.

일반 report 실패에는 추천 결과 표시와 재시도를 유지하지만 **HTTP 402는 실 부족 분기**다. 늦은 응답을 generation/cancel 체크로 차단하여 새 입력을 덮지 않는다. 탭 전환으로 작업은 유지하되 새로운 분석 시작·로그아웃·사용자 교체의 취소/정리 경계는 명시해야 한다.

## 광고·유료 충전

보상광고: 서버 reward attempt UUID 생성 → SSV custom data에 전달 → 광고 reward callback → 서버 잔액 polling으로 정산 확인. 광고 닫힘/실패/광고만 완료됐으나 서버 미정산 상태를 구분한다. Android AdMob ID 및 SSV 설정은 별도 검증한다.

Apple 결제는 5/10/20개 상품, verified transaction/account 매칭/JWS, backend 정산 후 지갑 확인과 finish를 구현한다. `/thread-wallet/iap/verify`는 `signedTransaction`을 요구하고 201 credited/200 already_credited를 구분한다. Play purchaseToken을 넣는 식의 치환은 불가능하다. Play 검증·중복 정산 방지·환불/취소 반영 계약과 콘솔 상품 설정이 Android 상용 결제의 선행 조건이다.

## OCR·공유 경계

Vision은 ko-KR/en-US, accurate recognition, bounding box/confidence를 사용한다. Android OCR의 좌표 원점·이미지 rotation·confidence 의미 차이와 한국어/영문 열 제목을 실제 fixture로 비교한다. 단순 문자열 인식 성공만으로 표 추출 완료를 선언하지 않는다.

공유는 `coordit://fitlab/shared?url=...`, HTTP/HTTPS만 허용하고 user/password가 있는 URL을 거부한다. 공유 queue FIFO/중복 제거, cold start·warm start·로그인/온보딩 대기 후 재개를 보존한다. App Group 메커니즘 자체 대신 Android 내부 저장소와 intent를 사용한다.
