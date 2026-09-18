# Foundation 검증 기록

2026-09-16. 기준 소스 `bd1f9311638645a4a1500c2a5693a33482dc1214` 위의 미커밋 `android/` 변경. 앱 전체 완료 또는 pixel-perfect 판정이 아니다.

## 빌드·테스트

Android Studio JBR, Android SDK 35, API 36 에뮬레이터에서 다음을 실행했다.

```sh
./gradlew :app:assembleDebug :app:testDebugUnitTest :app:lintDebug :app:assembleRelease :app:connectedDebugAndroidTest
```

- 최종 BUILD SUCCESSFUL.
- JVM 9개, 기기 테스트 8개: 실패/오류/건너뜀 0.
- lint 오류 0, 경고 31. 라이브러리 최신 버전 알림, 아직 연결하지 않은 원본 자산, 중복 원본 이미지, 애니메이션 offset 성능 권고, 개발 단계 앱 아이콘 미설정 등이 남는다.
- 실제 서버·OAuth provider·Play Billing E2E는 수행하지 않았다.
- 로그: `.qa/final-build.log`; 정식 XML/HTML 결과: `app/build/test-results`, `app/build/reports`, `app/build/outputs/androidTest-results`.

## 실제 화면과 동작

| 대상 | 확인 | 증거 |
|---|---|---|
| catalog | 기본/disabled 상태, 실제 press scale/opacity, 클릭 수 | `.qa/android/catalog-final.png`, `catalog-pressed.png`, `catalog-clicked.png` |
| 최초 스플래시 | 문구·구분선·로고·CTA, CTA 콜백 | `.qa/android/first-install-final.png`, `first-callback.png`, `first-callback.xml` |
| 재방문 스플래시 | 안내 문구·전체 화면 진입 콜백 | `.qa/android/returning-final.png`, connected test |
| 진입 애니메이션 | catalog에서 출발 → 구분선 성장 중 → 로고/CTA 표시 완료 | `.qa/android/entrance-start.png`, `entrance-middle.png`, `entrance-settled.png` |
| Back | 첫/재방문 preview에서 catalog 복귀, 이벤트 오발행 없음, 루트에서는 앱 종료 | connected test, `.qa/back-debug/` |
| 화면 재생성 | 클릭 수 SavedStateHandle 복원 | connected test |
| 작은 화면·큰 글꼴 | 360×800dp, fontScale 1.3에서 catalog/최초 스플래시 clipping 없음 | `.qa/android/*small-largefont.png` |

최종 source의 버튼 그림자·logo 조정 전 작은 화면 캡처도 보존했다. 해당 증거는 최종 pixel 비교로 사용하지 않는다. 모든 크기와 접근성 배율의 검증을 의미하지 않는다.

## iOS 비교 방법

원본 Swift 파일을 수정하지 않고 독립 QA host에 그대로 연결했다. iPhone 17/iOS 26.5의 402×874pt @3x와 Android 402×874dp @3x를 비교했다. 원본 해시·빌드 명령·캡처는 `.qa/ios-reference/`에 있다.

- 원본 배경 이미지 재사용. 문구·구분선·로고·버튼은 실제 Compose tree다.
- UIKit UIFontMetrics의 정수 반올림과 Climate YEAR 축 값을 확인했다.
- SwiftUI의 glyph 뒤 kerning과 Android span letterSpacing 차이를 보정했다.
- SwiftUI `RoundedRectangle(style: .continuous).path(in:)`에서 직접 추출한 곡선을 사용한다. `.qa/swift-continuous-path.txt` 참조.
- elevation 대신 명시적 blur·y-offset·색상으로 CTA 그림자를 그린다. 재방문 문구도 실제 높이 중심 정렬과 원본 white shadow를 적용했다.
- diff JSON은 `.qa/first-install-final-diff.json`, `.qa/returning-final-diff.json`. 원본 배경 resampling의 1채널 차이도 mismatch로 집계하므로 raw similarity를 제품 완성도 수치로 해석하지 않는다. iOS Dynamic Island는 OS 영역이다.

`.qa/`와 빌드 산출물은 Git에서 제외했다. 사용자 계정·세션·비밀키를 캡처하거나 포함하지 않았다.

## 독립 검토

- 기능/구조 검토: foundation 범위 PASS. 실제 Compose tree, navigation/콜백/Back/재생성, 세션 저장 계약 검토.
- 최신 화면 재검토: catalog와 스플래시 두 상태 PASS, blocking 없음. 모서리·그림자·문구 중심·kerning 수정 후 전체 최신 캡처를 다시 검토했다. 기하 차이는 1dp 이내 반올림/폰트 rasterization 범위이며 byte-identical은 아니다.
- 승인 범위는 명시된 세 화면 상태뿐이며 전체 앱, 모든 공통 컴포넌트, 실제 계정 통합, 애니메이션 시간 정밀 비교까지 확대하지 않는다.

검증 APK SHA-256: `339de33485729ec7d91f3ef736f4b24b39e0e881962b2832c39ae215365cce65` (`app/build/outputs/apk/debug/app-debug.apk`).

최종 코드 수준 디자인 재현 검토: **APPROVE**, blockers 없음. 보고서 `.qa/splash-final-code-clone-fidelity.md`. 승인 범위는 catalog 및 스플래시 두 settled 상태다.
