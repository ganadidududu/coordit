# main iOS 대응 및 Android App Bundle

검증일: 2026-10-27. 기준: fetch로 확인한 `origin/main` = `a4c1f0b831c090040a56d44ceca02b4dad46bb9e`.

작업 브랜치: `codex/android-ios-main-parity`. 작업 트리: `/Users/insihwan/.codex/worktrees/android-ios-main-parity/coordit-dev`.
기존 `codex/camera-auto-guides` 체크아웃의 미커밋 iOS 작업이나 main보다 앞선 커밋은 사용하지 않았다. iOS, backend, frontend 소스 변경은 없다.

## 이번에 맞춘 동작

| 영역 | Android 변경 |
|---|---|
| 인증 | iOS의 흰색 provider 버튼, 제목·간격·폰트·오류 표시, 키보드와 큰 글씨에서 스크롤 가능한 시트. 익명 계정 표시를 JSON/보안 저장에 보존하고 비회원은 회원 온보딩을 거치지 않고 진입 |
| 공통 UI | Fit Lab 제목을 Gmarket Sans Bold 22, 1.5 자간, 370×60 디자인 크기로 맞춤. Closet/Fit Lab 상단 chrome 정렬 |
| 홈 | 동일한 사용자별 Fit Lab 히스토리에서 최근 두 항목을 표시. 선택한 스냅샷의 상세 화면으로 이동 |
| Fit Lab | 저장 성공 즉시 입력 화면 복귀. 분석 중 Home/Closet 이동 허용. 전역 진행·완료·실패 알림과 위로 밀어 닫기, 접근성 닫기 동작. 진행 알림을 닫아도 완료 알림은 새로 표시 |
| 충전 연결 | Fit Lab의 충전 진입과 HTTP 402 이후 충전 화면 연결 |
| 공유 | Android ACTION_SEND text/plain과 `coordit://fitlab/shared?url=...` 수신. 로그인·계정 복원 전에는 기기 내 큐에 보관. 중복 제거, HTTP(S)/호스트 검증, URL 사용자 정보 거부. 진행 중 분석은 기다리고 기존 입력이 있으면 교체 여부를 확인 |
| 가이드 | Closet 7단계, Fit Lab 9단계의 실제 행동 기반 안내. 설치별 닫기·완료 저장, 다시 보기, 안내와 실제 대상만 밝게 보이는 scrim |
| 예시 체험 | iOS `CoorditTutorialExample.swift`의 링크와 S/M/L 실측·추천·리포트를 사용. 실제 서버 저장, 유료 분석, 히스토리 저장 없이 체험 |
| 사진 | Closet 의류 사진을 사용자·의류별 해시 경로와 AtomicFile로 저장. 화면 재진입·앱 재시작 후 재사용하며 계정 간 혼합을 방지 |
| 로딩 | iOS와 같은 마네킹·타원·sparkle 구성을 사용. 1.8초 회전과 시스템 동작 줄이기 대응 |
| 번들 | Play Console 등록에 맞춘 applicationId `com.coordit.app`, versionName `1.0.1`, versionCode `10`, minSdk 26, target/compileSdk 36, PKCS12 업로드 서명 |

2026-10-27 후속 수정: 사용자가 확인한 Play Console 패키지명 `com.coordit.app`으로 앱 ID를 수정했다. 개발용 앱 ID는 `com.coordit.app.debug`이다. Kotlin namespace `com.inseong.coordit`은 소스 클래스 경로이므로 유지하며, 배포 manifest의 패키지명과 FileProvider authority는 새 앱 ID를 사용한다. Google Android OAuth와 AdMob의 Android 앱 등록도 `com.coordit.app`을 기준으로 확인한다. 기존 업로드 키를 그대로 사용해 AAB와 설치 확인용 APK를 다시 생성한다.

패키지명 수정 후 release AAB 빌드와 release lint, bundletool 구조 검사, AAB 서명 및 파생 APK 서명·16KB 정렬 검사를 다시 통과했다. 아래 기능 전체 테스트 결과는 패키지명 수정 전 검증이며, 이 변경에서는 새 패키지 APK의 API 36 에뮬레이터 설치 성공, MainActivity 실행 성공, 실제 시작 화면의 `com.coordit.app` 패키지와 로그인/회원가입 버튼을 추가 확인했다.

## 재빌드

JDK 17 이상과 Android SDK 36을 사용한다. 이번 작업은 Android Studio의 JBR과 로컬 SDK를 사용했다.

```bash
export JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home'
export ANDROID_HOME="$HOME/Library/Android/sdk"
cd android
./gradlew :app:assembleDebug :app:assembleDebugAndroidTest :app:testDebugUnitTest :app:lintDebug :app:lintRelease :app:bundleRelease
```

기존 키가 있으면 재생성하지 않는다. 키가 없는 최초 설정에서만 `bash scripts/create-upload-key.sh`를 실행한다. `signing/release.properties`의 `storeFile`, `storePassword`, `keyAlias`, `keyPassword`를 Gradle이 읽는다. 다른 설정 파일은 `COORDIT_SIGNING_PROPERTIES` 환경 변수로 지정한다. 서명 설정이 없으면 release bundle 작업은 실패한다.

Bundletool 검증과 설치용 APK 추출:

```bash
export BUNDLETOOL_JAR=/path/to/bundletool-all-1.18.3.jar
bash scripts/verify-bundle.sh /path/to/local-deliverables
```

이 명령은 AAB 구조·JAR 서명·manifest·native library 압축 설정을 검사하고, 같은 업로드 키로 universal APK를 생성하여 APK 서명과 16KB zip alignment를 검증한다. 비밀번호는 임시 파일로 전달하고 종료 시 제거한다.

## 확인한 검증

- Debug APK, AndroidTest APK, release AAB 빌드 성공.
- 단위 테스트 68개 통과, 실패·오류 0개. 유효한 비회원 JWT는 갱신 호출 없이 복원하며, 갱신 서버의 400 오류로 저장된 계정을 삭제하지 않는 회귀 테스트를 포함한다.
- Android API 36 에뮬레이터 전체 기기 테스트 24개 통과. 공유 링크 교체 뒤 ViewModel 재생성 시 버린 분석 체크포인트가 복원되지 않는 검사도 포함한다. 추가로 360×800dp·글자 배율 1.3·시스템 dark 조건의 주요 흐름 9개 통과. 앱의 제품 표면은 iOS처럼 밝은 테마를 유지한다.
- Debug/release Android lint 통과. 기존 의존성 업데이트와 KTX 권장 등의 warning은 별도로 남아 있으며 오류를 억제하지 않았다.
- 기존 계정·온보딩·옷장·Fit Lab 테스트에 더해 예시 체험의 서버 쓰기 0회·히스토리 저장 0회, 진행 중 Home 이동·알림 닫기·완료 재알림·결과 저장·Home의 동일 스냅샷 재진입을 에뮬레이터에서 확인.
- 공유 큐 재생성·중복 제거·지원하지 않는 intent 거부, 의류 사진 저장소 재생성·계정 분리를 Android에서 확인.
- iOS main을 별도 derived data로 빌드하여 로그인·Fit Lab·Closet 가이드의 실제 시뮬레이터 캡처와 대조. 기존 iOS 소스는 변경하지 않음.
- Bundletool 1.18.3 구조 검증, AAB 서명 검증, 파생 APK v2/v3 서명 및 16KB zip alignment 확인.
- arm64-v8a/x86_64의 모든 `.so` ELF LOAD alignment가 16384 이상이며 BundleConfig는 `PAGE_ALIGNMENT_16K`.
- iOS와 동일한 staging `/health`에서 `ok: true` 응답 확인.
- AAB에서 추출한 실제 release APK를 설치하여 staging 비회원 로그인·Home 진입, 앱 강제 종료 후 저장된 계정의 재방문 화면 복원, 로그인 화면 없이 Home 재진입, ACTION_SEND 상품 링크의 Fit Lab 입력 진입을 확인. 이 검증은 디버그 fixture를 사용하지 않았다.
- 독립 소스·화면 검토 결과 APPROVE, 남은 blocker 없음. 실제 Compose 컴포넌트·공유 스타일·현재 캡처 83개를 검토했으며, 공유 체크포인트와 실타래 아이콘 문제는 수정 후 확인했다. 픽셀 완전 동일이나 모든 접근성 조건의 검증을 의미하지 않는다.

## 서버 및 스토어 설정 경계

이 번들은 iOS main과 같은 **staging** 서버 `https://coordit-backend-staging-789827940031.asia-northeast3.run.app/`를 사용한다. production 서버 배포나 스토어 업로드는 하지 않았다.

- Google 로그인: 새 업로드 인증서 SHA-1 `B9:9C:79:6D:2D:D9:31:EA:C3:86:08:6D:24:0D:13:05:FD:8C:00:56`와 Android package의 OAuth 등록은 Google Console에서 확인해야 한다. Play App Signing 사용 시 스토어 배포 인증서도 별도로 등록한다. 이번 작업에서 실제 사용자 Google 인증을 완료했다고 주장하지 않는다.
- Apple 로그인: Android 웹 인증용 Apple Services ID와 HTTPS callback 계약이 없어 기존 안내 동작을 유지한다. iOS 네이티브 Apple 로그인과 같다고 판정하지 않는다.
- Google Play 유료 구매: main 서버는 Apple 전용 구매 검증만 제공한다. Play 상품·purchase-token 검증·정산이 없어 유료 패키지는 비활성화 상태다.
- 보상 광고: production Android AdMob App ID/광고 단위가 제공되지 않아 release 광고는 비활성화 상태다. 제공 시 기존 SSV 정산 흐름을 활성화할 수 있다. iOS 광고 ID를 Android에 사용하지 않았다.
- 비회원 첫 실타래: iOS의 DeviceCheck 지급과 같은 Android 기기 검증 계약은 main에 없다. Android에서 iOS 기기 토큰을 흉내 내거나 지급을 우회하지 않는다.
- 배포된 staging의 비회원 `/auth/refresh`는 `400 Auth user email is missing`을 반환했다. 아직 유효한 JWT는 iOS처럼 그대로 복원하여 불필요한 갱신으로 로그인이 풀리는 문제를 수정했다. 토큰 만료 후의 정상 갱신은 서버 수정이 필요하며, 이 서버 오류에서는 저장된 비회원 자격 증명을 보존한다.
- 시스템 인증·사진 선택 UI, SF Symbols, Liquid Glass 굴절은 플랫폼 차이가 있다. 모든 iOS 화면의 픽셀 동일성을 검증한 결과가 아니다. 최소 API 26 실기기 검증도 수행하지 않았다.

## 서명 키 보관

`android/signing/` 전체는 Git에서 제외했다. `coordit-upload.p12`, `release.properties`, `upload-certificate.pem`을 함께 비공개로 백업해야 이후 업데이트를 같은 키로 서명할 수 있다. 비밀번호는 채팅이나 Git에 기록하지 않았다.

빌드 산출물과 서명 키는 로컬에 보관하며 소스 커밋에서 제외한다. Play Console 업로드는 별도다.
