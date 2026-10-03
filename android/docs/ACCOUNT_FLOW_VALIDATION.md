# 계정 흐름 구현 및 검증

범위: Android 로그인 진입 → Google Credential Manager → 기존 서버 세션 교환 → 온보딩 → main04 홈 → 계정 로그아웃. `android/` 외 소스 변경 없음.

## 기능

- 제품 MainActivity launcher를 추가했다. Foundation/AccountPreview Activity는 debug 전용이며 실제 앱 인증 우회 경로가 없다.
- 기존 iOS의 공개 Web Client ID와 staging API를 debug 설정에 연결했다. `docs/GOOGLE_SIGN_IN_SETUP.md`에 Android OAuth 등록 package/SHA-1을 기록했다.
- 인증 취소·실패·중복/늦은 provider 응답을 구분하고 저장 완료 전에는 로그인된 UI를 공개하지 않는다.
- 로그인 세션 저장 직후 인증 화면에서 벗어나 별도 계정 로딩 상태로 이동한다. 후속 프로필 실패를 로그인 실패로 되돌리지 않는다.
- 서버 온보딩 상태를 확인한 뒤에만 제품 화면에 진입한다. 저장세션 refresh의400/401/403은 삭제, 네트워크/5xx는 보존하고 재시도/다시로그인을 제공한다.
- 3단계 프로필/신체정보/동의 화면, 원본 약관, 필수동의/생일검증, 입력보존/IME/Back 처리.
- 실제 clothing-items/reference-clothing API로 홈과 기준 의류 선택을 읽고 저장한다. 기존 iOS와 같은 원본 정적 magazine 콘텐츠를 이식했다.
- Android에서 아직 생성하지 않은 분석 history는 실제로 비어 있다. 서버 recent API를 로컬history처럼 위장하거나 샘플결과를 넣지 않았다.
- 계정 메뉴에서 실제 logout과 사용자 데이터 초기화. full My Page 편집화면은 이번 범위가 아니다.

## 명시적 제한

- 실제 Google 계정의 서버 인증·프로필 조회·홈 진입·재시작 세션 복원은 확인했다. 신규 계정 온보딩 저장과 기준 의류 변경 저장은 실제 사용자 데이터로 검증하지 않았다.
- Apple Android 웹 OAuth는 Services ID/HTTPS callback 계약이 없어 아직 미지원이다. 버튼은 이유를 알리며 숨기거나 성공 처리하지 않는다. backend는 수정하지 않았다.
- FitLab/옷장 등록·분석 화면은 후속 단계다. 홈에서 해당 기능 선택 시 준비 중임을 표시하며 가짜 데이터 화면을 제공하지 않는다.
- iOS native Liquid Glass 굴절/실시간 blur와 SF Symbols는 Android에서 완전히 같지 않다. nav는 밝은 backdrop + 원본 navy tint/outline/shadow로 대응했다. Apple mark는 공식 로그인 자산의 검정 배경 차이가 있다.
- reference iPhone17 safe area62/34pt를 기준으로 auth/onboarding 레이아웃을 맞추고 Android cutout/navigation inset이 더 크면 확장한다. splash/home 원본은 edge-to-edge다.

## 증거 위치

- 빌드/lint/release: `.qa/account-final-build.log`, `app/build/reports/`.
- JVM tests: `app/build/test-results/testDebugUnitTest/`.
- 기기 전체 테스트: `.qa/account-all-instrumentation.log`.
- 상태별 실제 Android 캡처: `.qa/account-android/account-qa/`.
- iOS 원본 reference7화면, 소스해시와 재현스크립트: `.qa/account-ios-reference/README.md`.
- Back 조사: `.qa/account-back-debug.md`. 테스트가 Dialog창이 아닌 Activity에 직접dispatch해서 Activity가 닫혔으며 실제 Back 키로 검증한다.

테스트의 API/계정 fixture는 src/androidTest와 src/test에만 있다. 실제 OAuth 로그인·실제 사용자 계정의 서버저장으로 오인하지 않는다. QA 캡처는 테스트사용자 데이터를 사용한다.

## 실행 결과

- JVM 36개 통과, 에뮬레이터 전체 12개 통과. debug/release APK와 lint 빌드 성공.
- 원본 iOS 7화면과 Android 17상태를 1206×2622로 비교했다. 실제 Google 사용자 인증 성공을 의미하지 않는다.
- 실제 MainActivity에서 최초 CTA → Google 제공자 호출 → Back → 재활성화된 로그인 버튼을 직접 확인했다. Google 제공자 화면은 서버 통신 오류를 표시했다. 콘솔 등록 여부나 오류 원인은 이 관찰만으로 단정할 수 없다. `.qa/account-android/google-provider-unavailable.png`에 기록했다.

줄바꿈 정책: 한국어 문구의 어절이 갈라지지 않도록 공통 typography에 한국어 locale과 phrase 단위 paragraph line break를 지정했다. 약관 상세·홈 magazine 측정/렌더링도 같은 정책을 쓴다. 확대 글꼴에서는 보기 버튼 폭을 글꼴 배율에 맞춰 늘린다. [Compose 단락 문서](https://developer.android.com/develop/ui/compose/text/style-paragraph?hl=ko)를 기준으로 적용했다.

- 최종 360×800dp/글꼴 1.3에서 인증·온보딩·홈 시나리오 3개가 통과했다. 15개 상태 캡처는 `.qa/account-small/account-qa/`의 1080×2400 PNG이며, 같은 폴더의 account-menu/recovery는 작은 화면 검증 대상이 아니다.
- 최종 제품 빌드를 기본 에뮬레이터 해상도로 되돌려 직접 실행하고 스플래시 CTA → 인증 화면 전환을 재확인했다. `.qa/account-android/final-product-auth.png`.
- 소스 해시 목록: `.qa/account-final-source-sha256.txt`. 로그와 캡처는 개발용 `.qa/`에 저장되며 Git에서 제외된다.

## 독립 검토 결과

- 기능 검토: 세션 저장·복원·취소/중복 응답·계정 초기화·온보딩 게이트에 차단 이슈 없음.
- 최종 시각/CJK 검토(`account_final_all_sizes`): 기본 17 + 작은 화면 15 상태와 iOS 7개 원본을 직접 열어 PASS. 모든 캡처가 최종 Kotlin 소스 이후 생성되었고 소스 해시도 일치한다.
- 최종 디자인/코드 검토(`account_final_fidelity`): 7개 쌍의 영역 확대 비교와 실제 Compose/공통 토큰 구조 확인 후 PASS. 원본 화면을 이미지로 대체하지 않았다.
- 승인 범위는 명시된 네이티브 플랫폼 차이를 포함하는 현재 로그인·온보딩·홈 단계다. 픽셀 완전 동일, 전체 앱 완료, 실제 OAuth 성공을 의미하지 않는다.

## Android OAuth 등록 후 재확인

사용자가 Android 클라이언트 추가를 알린 뒤 재시도했다. 초기 Google 통신 오류는 에뮬레이터의 네트워크 경로/DNS 실패 상태에서 재현됐다. 에뮬레이터 cold start와 AndroidWifi 재연결 후 Google 호스트 접근이 복구됐고 실제 Google 계정 입력 화면까지 진입했다. 이 시점에는 계정 입력 전이었으며 이후 검증 결과는 아래와 같다. 앱 코드 변경은 없으며 세부 관찰은 `.qa/oauth-registration-check.md`에 기록했다.


## 실제 계정 로그인 및 복원 확인 (2026-09-16)

사용자가 Google 로그인을 직접 완료한 뒤 제품 MainActivity에서 다음을 확인했다.

- 홈 MAGAZINE/MY CLOSET 표시. 실제 root 경로는 서버 세션 교환과 onboardingComplete 확인 후에만 Home으로 이동한다.
- 계정 메뉴에 서버 프로필 이메일이 존재한다. 이메일·이름·토큰 값은 증거에 저장하지 않았다.
- 앱 force-stop 후 재실행: 서버 refresh와 계정 조회를 거쳐 재방문 스플래시 표시, 화면 터치 후 재로그인 없이 Home 복귀.
- 기준 의류 선택에서 실제 빈 옷장 상태 표시, 조회 오류 없음. 저장/삭제는 수행하지 않고 Back으로 복귀했다.
- 현재 계정은 서버에서 온보딩 완료 상태로 인식된다. 신규 계정 온보딩 저장 성공은 이번 관찰에 포함하지 않는다.

사용자의 로그인 상태를 유지했다. 앱 코드 변경 없이 문서만 갱신했으며 기존 단위/기기 테스트를 불필요하게 재실행하지 않았다. 개인정보가 포함될 수 있는 임시 UI hierarchy 파일은 확인 후 삭제했다.
