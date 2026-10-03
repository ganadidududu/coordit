# 옷장 구현·검증

브랜치 `codex/android-native-port`, 비교 기준 origin/main `bd1f9311638645a4a1500c2a5693a33482dc1214`. 이번 단계 변경은 `android/` 내부다.

## 구현

- 실제 옷장 조회, 상하의/세부 종류/이름 필터, 비어 있음·실패·재시도.
- 직접 실측 입력, URL 상품 추출 후 사이즈 선택, Android 사진 선택/카메라·자르기·기기 내 Korean MLKit OCR.
- 원자적 의류/사이즈 저장, 실패 재시도 시 동일 idempotency key 사용, 저장 중 중복 요청 방지.
- 상세 치수·서버 핏 점수·차이 마네킹, 이름 수정, 삭제 확인, 삭제 후 기준 치수 갱신.
- 계정 변경 시 작업 취소 및 늦은 응답 무시. 등록 방식 변경 시 이전 추출 결과 해제.

## 검증 증거

- `.qa/closet-final-build.log`: debug/release APK, JVM 검사, lint 결과.
- `.qa/closet-instrumentation.log`: 옷장 전체 흐름, 실제 MLKit, 기존 계정 화면/흐름의 기기 검사.
- `.qa/closet-small-instrumentation.log`: 360×800dp/글꼴 1.3의 동일 등록·수정·삭제·링크 흐름.
- `.qa/closet-approved-normal/`, `.qa/closet-approved-small/`: 각각 18개 화면/상태 캡처.
- `.qa/closet-ios-reference/`: 원본 SwiftUI 실행 캡처 8개와 생성 방법.
- 실제 로그인 세션에서 빈 옷장 조회, 사진 선택, 표 영역 지정, M/L 두 행의 8개 실측값 인식과 선택을 직접 확인했다. `.qa/closet-live-crop.png`, `.qa/closet-live-ocr.png`.
- 쓰기 시나리오는 실제 ViewModel/Compose와 격리된 API fixture를 사용한다. 실제 사용자 옷을 임의 생성·수정·삭제하지 않았다.

## 제한

사진은 원본 iOS처럼 세션 메모리에만 유지한다. 사진 영구 업로드 API는 추가하지 않았다. iOS의 임의/기본 점수를 실제 점수로 표시하지 않고 서버 비교 결과가 없으면 안내한다. 이름 변경은 기존 PATCH API로 저장한다.

카메라 촬영의 실기기 품질, 다양한 실제 판매자 표의 OCR 정확도, 실제 상품 URL 추출 성공 및 실제 계정의 저장·수정·삭제 서버 E2E는 별도 확인이 필요하다. Android의 시스템 사진 선택/키보드/대화상자 및 blur·아이콘 래스터화는 iOS와 다를 수 있다. 전체 앱 이식 완료가 아니며 FitLab·리포트·결제·공유·Apple 로그인은 후속 범위다.

세션 저장소 회귀 검사는 별도 디렉터리와 Keystore 별칭을 사용한다. 기존 테스트가 개발 앱의 로컬 로그인 파일을 지우는 문제를 수정했고, 재로그인 후 검사 전후의 실제 암호화 세션 파일이 동일함을 확인했다 (`.qa/isolated-session-test.log`).

최종 자동 검증: JVM 51개, Android 기기 14개, 작은 화면 옷장 흐름 1개 통과. debug/release APK 생성 및 lint 통과(오류 0, 경고 37). 경고는 기존 Google Credential 검사 및 의존성 버전 등의 항목이며 이번 기능 검증 결과와 구분한다. APK 설치본과 로컬 파일의 SHA-256 일치 및 UI 소스 해시는 `.qa/closet-build-provenance.txt`에 기록했다. 마지막 실앱 실행에서도 재시작 세션 복원 → 홈 → 옷장 → 등록 방식 진입을 직접 확인했다.

## 최종 독립 검토

- 기능·코드/디자인 시스템: `.qa/closet-integrity-gate.md` PASS.
- 최신 36개 화면의 CJK·반응형: `.qa/closet-cjk-gate.md` PASS.
- 원본 8개 화면의 구조·색상·타이포그래피 비교: `.qa/closet-pixel-gate.md` PASS. Android 네이티브 그림자·아이콘·glass 및 fixture 데이터 차이를 구분한 판정이며 픽셀 완전 동일을 주장하지 않는다.

검토 중 발견한 테두리 렌더링, 비활성 글자 투명도, 링크 버튼 간격, 점수 카드 구조, 삭제 후 기준 치수 갱신, 등록 방식 간 추출 결과 잔류 문제를 수정했다. 모든 최종 캡처는 마지막 UI 수정 후 설치한 동일 APK에서 생성했다.
