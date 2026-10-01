# Phase 1 검증 기록

기준: bd1f9311638645a4a1500c2a5693a33482dc1214, 2026-09-16.

- git fetch 후 원격 29개 커밋 차이 확인. 최신 origin/main에서 별도 브랜치·작업 트리 생성.
- 앱/확장 Swift 71개 파일과 인벤토리 수 일치.
- 32개 route 모두 A–L 감사 문서에 기재됨.
- 인벤토리 선언/state/typography/presentation의 모든 줄 번호·문구를 실제 소스와 대조: 불일치 0.
- 새 Markdown의 로컬 링크 대상 존재 검사: 오류 0.
- 새 Markdown trailing whitespace 검사: 오류 0.
- 기존 coordit-dev의 9개 수정 파일 및 두 미추적 폴더 상태 유지. 새 작업 트리는 android/만 추가됨.
- Android 코드·의존성·기존 앱 변경 없음. commit/push 없음.

LSP 자동 후크는 새 작업 트리가 현재 요청 cwd 밖이라는 경로 제한을 보고했다. 이는 Markdown 내용 진단 결과가 아니며 LSP 통과로 기록하지 않는다. 문서의 구조·링크·원본 줄 번호는 별도 스크립트로 검사했다.

iOS/Android 빌드, 런타임 UI, 실제 API·광고·결제 및 screenshot 비교는 이번 Phase 1에서 실행하지 않았다. 앱 구현 완료 또는 시각 동일성 통과를 뜻하지 않는다.
