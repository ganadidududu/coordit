# Android 구현 진행

## 범위와 원본

`codex/android-native-port`는 GitHub origin/main을 fetch한 `bd1f9311638645a4a1500c2a5693a33482dc1214`에서 분기했다. 기존 로컬 main보다 원격이 29커밋 앞서 있어 별도 작업 트리를 사용했다. 기존 로컬 수정은 보존했다. 모든 새 파일은 `android/` 안에 있다.

현재 구현은 Foundation과 공통 요소에 이어 계정·온보딩·홈, 옷장 목록·등록·상세, FitLab 입력·추천·리포트·히스토리, 마이페이지·설정과 보상형 광고 실타래 충전까지 진행했다. 앱 전체 포팅 또는 출시 완료를 의미하지 않는다.

| 단계 | 상태 | 결과 |
|---|---|---|
| Phase 1 Audit | 완료 | A–L 분석, 71개 앱/확장 Swift 파일, 32개 route, 자산·API·저장소 대응표 |
| Phase 2 Foundation | 구현·실행 검증 | Gradle/Compose/Navigation, StateFlow, Retrofit 계약, Keystore 암호화 세션 |
| Phase 3 Shared Components | 일부 구현 | 원본 폰트·이미지·색상·gradient, 버튼/설정/chrome 기반. 마이페이지 설정 상태의 일반·소형 화면 검증 완료 |
| Phase 4 Screen Porting | 일부 구현 | 스플래시·인증·3단계 온보딩·원본 약관·main04·옷장·FitLab·마이페이지·보상광고 충전, 세션에 따른 제품 라우팅과 기능별 API 연결 |
| Phase 5 Widget | 해당 소스 없음 | 원본에는 WidgetKit 위젯이 없고 Share Extension이 있음. Android 공유 수신은 추후 구현 |

## 확인한 동작

- 디버그 catalog에서 두 스플래시 상태를 열고 콜백으로 돌아온다. 실제 로그인 성공으로 처리하지 않는다.
- 기본/비활성화 버튼, 클릭 상태 유지, 화면 재생성, 시스템 Back을 검증했다.
- 원본 iOS 소스를 별도 임시 host로 실행하여 402×874pt @3x 캡처와 Android 402×874dp @3x를 비교했다.
- 원본 UIFontMetrics의 크기 반올림과 마지막 글자 kerning을 반영했다.
- 360×800dp, 글꼴 배율 1.3에서 catalog와 최초 스플래시 문구/버튼이 잘리지 않는 것을 확인했다. 모든 접근성 배율 검증을 의미하지 않는다.
- 암호화 저장·재읽기·삭제, AtomicFile 백업 복구, 비정상 세션 응답 거부, refresh 실패·취소 정책을 테스트했다.
- FitLab 소스 3종부터 입력 확인, 기준 옷, 재시도, 결과, 사용자별 히스토리 상세·삭제까지 정상·소형 화면에서 검증했다.
- 마이페이지 13개 상태에서 프로필·신체정보 저장 콜백, 알림 권한/OS 설정, 개인정보 토글, 문서, 로그아웃·회원탈퇴 경로를 일반·소형 화면에서 검증했다.
- 충전 화면은 서버 보상 시도 UUID를 AdMob SSV custom data에 연결하고, 클라이언트 보상 콜백 뒤 서버 잔액 증가를 확인할 때만 충전 완료로 표시한다. 유료 패키지는 비활성화 상태다.

## 남은 작업

1. 신규 Google 계정 온보딩 저장의 실제 서버 검증. 기존 계정 Google 인증·프로필 조회·홈 진입·재시작 세션 복원은 확인 완료. Apple Services ID/HTTPS callback 계약 및 Android 연동은 남음.
2. Google Play 실타래 유료 결제와 공유/딥링크. 보상형 광고는 SSV 정산 연결까지 구현했으며, Play 구매 토큰 검증 서버 계약과 상품 설정은 남아 있다.
3. API DTO/서비스를 각 기능의 원본 계약에 맞춰 확장하고 실제 AdMob SSV·서버 E2E 실행.
4. iOS Liquid Glass의 blur/굴절 대응, 공통 설정·header·tab의 전체 상태 시각 비교, SF Symbols별 자산 대응.
5. Google Play 결제 검증 서버 계약과 상품 설정. 현재 Apple 전용 서버 결제 API를 Android용으로 임의 수정하지 않았다.
6. 최소 API 26 실기기/에뮬레이터, 다양한 크기·글꼴·IME·접근성 검증.

## 배포 제한

release에는 제품 MainActivity launcher가 있다. 개발용 preview Activity는 제외된다. 전체 기능이 아직 미완료이므로 출시 가능한 제품 앱은 아니다. 배포 URL 미설정 시 네트워크 요청을 차단한다. release APK 생성 성공은 제품 기능 완료를 뜻하지 않는다. iOS/backend/frontend는 수정하지 않았고 commit/push도 하지 않았다.

계정 단계의 최신 구현·검증 범위는 [ACCOUNT_FLOW_VALIDATION.md](ACCOUNT_FLOW_VALIDATION.md)를 따른다. 위 Foundation 검증 기록은 이전 단계 기록으로 보존한다.

옷장 단계의 구현·검증 및 실제 서버 쓰기 검증 제한은 [CLOSET_VALIDATION.md](CLOSET_VALIDATION.md)를 따른다.

FitLab 단계의 구현·재시도·히스토리·시각 검증 범위는 [FITLAB_VALIDATION.md](FITLAB_VALIDATION.md)를 따른다.

마이페이지·설정의 서버 계약과 화면 검증 범위는 [MYPAGE_VALIDATION.md](MYPAGE_VALIDATION.md)를 따른다.

보상광고의 실제 배포 설정과 정산 경계는 [THREAD_REWARD_SETUP.md](THREAD_REWARD_SETUP.md)를 따른다.
