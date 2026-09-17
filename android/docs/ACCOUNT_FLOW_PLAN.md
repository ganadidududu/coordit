# 계정·온보딩·홈 구현 결과

1. 완료: 원본 계약 확인, Google Credential Manager 및 세션 복원/로그아웃/root 상태 연결.
2. 완료: 원본 인증 화면·3단계 온보딩·main04 홈과 기준 의류 API 연결.
3. 완료: 단위·기기 테스트 및 실제 MainActivity 제공자 진입/취소 확인. 시각 비교의 한글 줄바꿈 보정 후 최종 검증 기록은 ACCOUNT_FLOW_VALIDATION.md에 둔다.

변경 경계: android/만. backend API 변경 없음.

Google 등록 후 실제 계정 인증·홈 진입·재시작 세션 복원 확인 완료. 신규 계정 온보딩 저장의 실제 서버 검증은 남아 있다. Apple Android 로그인은 Services ID/HTTPS return endpoint 계약이 필요하다. 임의 endpoint·우회 인증·가짜 성공을 추가하지 않았다.

시각 대응: iOS native Liquid Glass는 Android에 동일 API가 없어 capsule에 밝은 backdrop와 navy tint/outline/shadow를 합성한다. 실시간 굴절/동적 blur는 원본과 같지 않으며 남은 차이로 기록한다.
