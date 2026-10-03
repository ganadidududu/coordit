# FitLab Android 이식 검증

## 구현 범위

- 홈·옷장 하단 탭에서 FitLab 진입과 시스템 Back 복귀
- 현재 실타래 조회와 URL, 사진 OCR, 직접 입력 소스 선택
- 상·하의 카테고리, 여러 사이즈 행, 카테고리별 실측값 검증
- Unicode NFKC 기준 중복 사이즈명 차단과 입력 확인 단계
- 호환 기준 의류 조회·선택, 외부 상품·사이즈 생성, 추천·리포트 생성
- 완료된 단계 체크포인트와 추천·리포트 idempotency key 재사용
- 로그아웃 또는 사용자 변경 시 진행 중 응답 폐기
- 결과·마네킹·사이즈 점수·리포트 표시
- 사용자별 로컬 히스토리 저장·목록·상세·삭제, 분석 ID 중복 제거, 최대 50개 유지

## 자동 검증

`FitLabFlowTest`는 실제 Compose 화면을 격리된 API와 메모리 저장소로 조작한다. 소스 3종, 직접 입력, 입력 확인, 기준 옷, 추천 실패·재시도, 리포트 실패·재시도, 결과, 히스토리 상세·삭제를 통과하며 상품·사이즈 요청 수와 추천·리포트 idempotency key를 검사한다. 별도 시나리오에서 ViewModel을 다시 만든 뒤 저장된 상품·사이즈 체크포인트와 추천 key로 이어지는지도 확인한다.

```bash
./gradlew :app:testDebugUnitTest :app:assembleDebug
./gradlew :app:connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.class=com.inseong.coordit.fitlab.FitLabFlowTest
```

정상 화면 `1080x2400/420dpi`와 소형 화면 `720x1600/320dpi`에서 같은 테스트를 실행했다. 캡처는 `.qa/fitlab-android-final`과 `.qa/fitlab-android-small`에 있다.

## iOS 원본 비교

SwiftUI `CoorditFitLabUITests.testManualUpperAndLowerDrafts`를 iPhone 17 Pro 시뮬레이터에서 새로 실행해 소스 선택, 상·하의 입력, 입력 확인 상태 6개를 캡처했다. 원본 결과는 `.qa/fitlab-ios-reference`, 테스트 결과 번들은 `.qa/fitlab-ios-manual.xcresult`에 있다. Android 최종 정상·소형 화면 캡처는 각각 `.qa/fitlab-android-approved-normal-13`, `.qa/fitlab-android-approved-small-13`에 있다. 각 묶음은 결과, 실타래 공을 사용한 중앙 기준 차이 그래프, 상세 리포트, 하단 액션, 히스토리 삭제까지 13개 상태를 포함한다.

## 실제 계정 확인 범위

로그인된 에뮬레이터에서 홈에서 FitLab 진입, 실타래 잔액 조회, 직접 입력 검증과 기준 옷 조회까지 확인했다. 해당 계정에는 호환 기준 의류가 없어 실제 추천 요청은 보내지 않았다. 서버 쓰기와 실타래 소비가 발생하는 전체 성공 흐름은 격리된 instrumentation API로 검증했다.
