# Coordit Android

기존 SwiftUI 원본을 기준으로 진행 중인 Kotlin/Jetpack Compose 포팅이다. 새 브랜치는 `codex/android-native-port`, 작업 트리는 `/Users/insihwan/Documents/Project/coordit/coordit-android`다. 모든 저장소 변경은 `android/`에 한정한다.

현재는 **Foundation + 계정·홈 + 옷장 + FitLab 분석·히스토리 + 마이페이지·설정 단계**다. MainActivity가 제품 시작점이며 Google 로그인, 세션 복원, 온보딩, 홈 기준 의류 조회·선택·저장, 로그아웃을 연결했다. 실제 Google 계정의 서버 인증·프로필 조회·홈 진입과 앱 재시작 후 세션 복원을 확인했다. 옷장 검색·직접 입력·링크 추출·사진 OCR·수정·삭제, FitLab 추천·리포트·히스토리, 프로필·신체정보·알림·개인정보·회원탈퇴를 연결했다. Apple 로그인·Google Play 결제는 남아 있어 아직 출시 가능한 전체 앱은 아니다.

## 구현

- Gradle Wrapper 8.11.1(SHA256 고정), AGP 8.9.1, Kotlin 2.0.21, Compose, Navigation Compose.
- minSdk 26, compileSdk/targetSdk 35. 출시 전 당시 Play 정책과 지원 버전 재확인이 필요하다.
- 원본 색상·다중 gradient·크기·Gmarket/Mona/Climate 가변 폰트, 원본 이미지 26개.
- 기본/보조/비활성화 버튼과 press state, 설정 폼·카드·제목 및 chrome 컴포넌트.
- 스플래시 신규/재방문 레이아웃·콜백·단계별 애니메이션·동작 줄이기.
- Google Credential Manager와 실제 Retrofit 인증/refresh/프로필/온보딩 API, StateFlow 앱 상태.
- 원본 인증·3단계 온보딩·약관·홈(main04), 실제 기준 의류 API, 마이페이지의 프로필·신체정보·알림·개인정보·로그아웃·회원탈퇴.
- Android Keystore AES-GCM + AtomicFile 세션 저장, 백업 제외, 인증 응답 strict parsing.
- FitLab 단계별 API 체크포인트와 추천·리포트 idempotency key를 사용자별로 원자 저장해 앱 재시작 뒤에도 이어서 처리하며, 사용자별 50개 로컬 히스토리를 보관한다.
- 디버그 전용 catalog와 StateFlow/SavedStateHandle, 시스템 Back·화면 재생성 검증.

공통 chrome 중 Liquid Glass는 밝은 backdrop/tint/capsule 대응이며 Apple의 실시간 굴절 효과와 같다고 판정하지 않았다. 전체 화면 포팅·Apple 웹 OAuth·Google Play 정산과 신규 계정 온보딩 저장의 실제 서버 검증은 아직 남아 있다. 상세 진행/검증 범위는 [구현 상태](docs/IMPLEMENTATION_STATUS.md)를 확인한다.

## 실행

Android Studio에서 **이 android 디렉터리**를 열고 SDK 경로를 설정한다. JDK 17 이상이 필요하며 이 작업에서는 Android Studio 내장 JBR을 사용했다. SDK Platform 35와 Build Tools 35.0.0이 필요하다. `local.properties`는 기기별 설정으로 Git에서 제외한다.

```bash
./gradlew :app:assembleDebug :app:testDebugUnitTest :app:lintDebug
./gradlew :app:connectedDebugAndroidTest
./gradlew :app:installDebug
adb shell am start -n com.inseong.coordit.debug/com.inseong.coordit.MainActivity
```

별도 FoundationActivity 검증 화면에서 최초/재방문 스플래시를 열거나 직접 시작할 수 있다. 스플래시 CTA는 개발용 host에서 콜백을 기록하고 catalog로 돌아간다. 사용자 로그인 성공으로 처리하는 코드가 아니다.

```bash
adb shell am start -S -n com.inseong.coordit.debug/com.inseong.coordit.preview.FoundationActivity --es route first-install --ez reduce_motion true
adb shell am start -S -n com.inseong.coordit.debug/com.inseong.coordit.preview.FoundationActivity --es route returning --ez reduce_motion true
```

DEBUG API와 Google Web Client ID는 기존 iOS의 staging 공개 설정을 `gradle.properties`에 기록했다. 로컬 서버는 `-PCOORDIT_API_BASE_URL=http://10.0.2.2:4000/`로 선택한다. API 설정을 바꾸려면 Gradle 속성을 지정한다. Foundation catalog만 서버 호출을 하지 않는다.

```bash
./gradlew :app:assembleDebug -PCOORDIT_API_BASE_URL=https://your-api.example/
```

release API는 `COORDIT_RELEASE_API_BASE_URL`로 별도 지정하고 HTTPS만 허용한다. 기본 미설정 주소에서는 요청을 차단한다. 서비스 역할 키나 서버 비밀값을 APK에 넣지 않는다. Google Android client/signature 등록은 [설정 안내](docs/GOOGLE_SIGN_IN_SETUP.md)를 따른다. Apple callback과 Play 상품/검증 서버 연동은 별도 구현 대상이다.

## 자산 재생성

```bash
cd tools
npm ci
node render-assets.cjs
```

원본 iOS 폰트는 그대로 복사한다. SVG artwork는 4배율 투명 PNG로 변환하며 viewBox/filter를 보존한다. 전체 화면 screenshot을 UI로 사용하지 않는다. [자산 대응표](docs/ASSET_MAPPING.md)에 원본 해시·치수·font axis가 있다.

## 문서

- [A–L 원본 감사](docs/IOS_PORT_AUDIT.md)
- [API·저장소 계약 감사](docs/DATA_CONTRACT_AUDIT.md)
- [전체 소스 인벤토리](docs/IOS_SOURCE_INVENTORY.md)
- [Foundation 데이터 구현](docs/FOUNDATION_DATA.md)
- [단계별 구현·검증 상태](docs/IMPLEMENTATION_STATUS.md)
- [Foundation 검증 기록](docs/FOUNDATION_VALIDATION.md)
- [계정·온보딩·홈 검증 및 제한](docs/ACCOUNT_FLOW_VALIDATION.md)
- [Google OAuth 등록 안내](docs/GOOGLE_SIGN_IN_SETUP.md)
- [FitLab 검증 기록](docs/FITLAB_VALIDATION.md)
- [마이페이지·설정 검증 기록](docs/MYPAGE_VALIDATION.md)

원본 기준 `bd1f9311638645a4a1500c2a5693a33482dc1214` (2026-09-16 fetch). iOS·backend·frontend 소스는 수정하지 않았다. commit/push는 하지 않았다.
