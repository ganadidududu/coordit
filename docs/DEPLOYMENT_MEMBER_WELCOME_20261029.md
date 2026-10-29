# 회원 가입 실타래 정책 운영 반영 — 2026-10-29

2026-10-29 15:53 KST에 Cloud Run 운영 트래픽을 새 리비전으로 100% 전환했다. 서비스와 DB의 `staging` 이름은 기존 운영 리소스 명칭이다.

## 반영 대상

- GCP: `coordit-dev` / `asia-northeast3` / `coordit-backend-staging`
- 새 리비전: `coordit-backend-staging-member-welcome-1029`
- 이전 리비전: `coordit-backend-staging-guest-email-1027`
- Cloud Build: `6554c17e-9750-47a2-bbbb-1a877a985449` — SUCCESS
- 이미지 digest: `sha256:dfdb7b2d95cac1f4932bf3db6e9d1778a0bd83837e0d169523276d6068f251ff`
- 배포 소스 SHA-256: `dee745bc0b31287390f20edb54ef82075670f1c871106c4ec5fde8efd9acf831`
- Supabase: `vzvnrfpbbwxdeeuzyxpr` (`coordit-staging`)
- 마이그레이션: `supabase/migrations/20261029090000_member_only_welcome_threads.sql`
- 마이그레이션 SHA-256: `6eb51c844067e62e40c59fbea6c6fd3cb6173303946b990767951b4e2c364f2c`

현재 운영 소스의 Cloud Build 보관본을 기준으로 비회원 웰컴 지급을 잔액 조회로 바꾸는 서비스·저장소 수정만 배포했다. 기존 운영의 빈 이메일 처리 수정과 광고/IAP 설정을 유지했다. 로컬 브랜치 전체를 운영에 덮어쓰지 않았으며 iOS 앱 배포는 이 서버 배포에 포함되지 않는다.

DB는 Supabase SQL Editor에서 트랜잭션으로 적용했다. 이 DB에는 `supabase_migrations.schema_migrations` 이력 테이블이 없어 CLI 이력을 새로 만들지 않았다. 이미 적용된 trigger 생성 SQL을 다시 실행하지 않는다.

## 검증

- 로컬 DB 정책 테스트: 기존 운영 함수 형식과 새 lease 함수 형식 모두 통과, 관련 Vitest 15개 통과.
- 운영 DB 임시 트랜잭션: 신규 비회원 0개, 신규 회원 3개, 구형/신형 비회원 지급 RPC 모두 추가 지급 없음.
- 비회원의 적립 잔액 2개를 유지한 채 회원 전환하면 5개, 재실행해도 5개 유지, welcome ledger 1건.
- 익명/일반 인증 역할에 지급 RPC 실행 권한 없음. 모든 테스트 행은 ROLLBACK.
- 마이그레이션 전후 기존 지갑 74개, 잔액 fingerprint `97bdab6d188c7b5465afe17b91bb4b2e` 동일.
- 후보 URL과 앱에 설정된 운영 URL에서 신규 비회원 생성 → 잔액 0 → 이전 웰컴 호출 후 0 → 광고 보상 요청 생성 → 잔액 0 확인. 테스트 계정은 각 확인 후 삭제했다.
- 광고 enabled, IAP enabled. 실제 광고 시청/서명된 광고 보상 정산이나 실제 결제는 이 배포 점검에서 수행하지 않았다.
- Cloud Run Ready/ConfigurationsReady/RoutesReady 모두 True, 새 리비전 100%. 확인 시점 새 리비전 ERROR 로그 없음.

## 증빙

- [운영 API 검증](evidence/member-welcome-20261029/production-smoke.json)
- [후보 API 검증](evidence/member-welcome-20261029/candidate-smoke.json)
- [트래픽 검증](evidence/member-welcome-20261029/traffic-verification.json)
- [배포 소스 파일 manifest](evidence/member-welcome-20261029/source-manifest.json)
- [운영 DB 정책 검증](evidence/member-welcome-20261029/db-policy-verification.jpg)
- [운영 DB 적용 상태](evidence/member-welcome-20261029/db-applied.jpg)

서버 롤백은 이전 리비전으로 트래픽을 전환할 수 있다. DB의 비회원 지급 차단은 구형 서버에서도 작동한다. DB 정책까지 되돌리면 비회원 지급이 다시 활성화되므로 별도 판단이 필요하다.
