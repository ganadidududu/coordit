# 마이페이지·설정 검증

## 구현 범위

- 보유 실타래 조회와 충전 준비 안내
- 계정 요약, 프로필 이름 수정, 연결된 Google 계정 표시
- 소셜 로그인 비밀번호 안내, 로그아웃, 확인 후 회원탈퇴
- 키·몸무게 조회와 새 측정값 저장, 성별·생일 조회
- Android 13 이상 알림 권한 요청, OS 앱 알림 설정 이동, 마케팅 알림 로컬 설정
- 개인정보 처리방침, 서비스 이용약관, 개인화·AI 분석 데이터 로컬 설정
- 앱 버전과 지원 이메일

프로필은 `PATCH /users/me`, 신체 정보는 `POST /body-measurements`, 회원탈퇴는 `DELETE /users/me`에 연결했다. 회원탈퇴 API가 성공한 뒤에만 암호화된 로컬 세션을 삭제한다. 서버 실패 시 세션을 유지한다.

실타래 충전은 Google Play Billing 상품과 서버 영수증 검증 계약이 없어 구매를 성공한 것처럼 처리하지 않는다. 현재 잔액과 준비 안내만 표시한다.

## 자동·수동 검증

- `MyPageFlowTest`가 13개 화면 상태를 실제 Compose Activity에서 순회한다.
- 프로필 이름과 키·몸무게 저장 값, 로그아웃·회원탈퇴 콜백을 검증한다.
- `SessionRepositoryTest`가 PATCH/POST/DELETE 경로, Bearer 인증, JSON 필드와 삭제 후 세션 제거를 MockWebServer에서 검증한다.
- 일반 화면 캡처: `android/.qa/mypage-android-approved-normal-08`
- 소형 화면 캡처: `android/.qa/mypage-android-approved-small-02`

일반 화면은 1080×2400/420dpi, 소형 화면은 720×1600/320dpi에서 확인했다. 긴 한글 제목은 크기를 조정하고 페이지 전환마다 스크롤·IME 포커스를 초기화해 이전 화면 위치가 다음 화면에 남지 않도록 했다.

## 남은 외부 검증

실제 staging 계정으로 프로필 저장, 신체 정보 저장, 회원탈퇴를 실행하면 사용자 데이터가 변경되므로 이번 로컬 검증에서는 호출하지 않았다. API 계약과 실패 안전성은 MockWebServer로 검증했다. 출시 전 테스트 전용 계정으로 실제 서버 E2E를 수행해야 한다.
