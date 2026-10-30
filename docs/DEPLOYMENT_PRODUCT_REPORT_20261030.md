# 상품별 무료 1차 리포트 운영 반영 — 2026-10-30

Cloud Run `coordit-backend-staging`은 이름과 달리 현재 앱이 사용하는 운영 서비스다. 최종 검수 후 `coordit-backend-staging-product-report-1030-final`에 트래픽100%를 전환했다.

- 프로젝트/지역: `coordit-dev` / `asia-northeast3`
- 이전 운영 리비전: `coordit-backend-staging-member-welcome-1029`
- 이미지: `asia-northeast3-docker.pkg.dev/coordit-dev/cloud-run-source-deploy/coordit-backend-staging@sha256:8e654170a4c55d1644be91c66a92bdda832a75ff77b04c01f69d25d4e080eb69`
- Cloud Build: `679d5e9d-fcc0-43f0-95b3-51ff5d6889ed`
- 배포 소스는 이전 운영의 보관본에 이번 product-import 변경과 robots-parser 의존성만 적용했다. DB 마이그레이션, 결제·계정 설정 변경은 없다.
- 앱 코드: backend `98744b2` + `067d503`, iOS `b31fd06`, Android `0c9e745`.

두 앱의 무료 리포트는 확인된 사이즈 범위·차이, 판매처의 소재·구조, 핏·모델 착용 정보, 관리 안내를 같은 순서로 표시한다. 없는 항목은 추측하지 않으며 상품 원문과 확인 시간을 제공한다. 상품명·링크·입력 방식이 바뀌면 이전 상품의 정보는 숨긴다. 상세 실측표와 상품 정보 수정 아래의 비교 버튼/실타래 안내는 유지한다.

## 검증

- 브랜치와 운영 소스 기반 배포 후보 각각: product-import48개 및 TypeScript 검사 통과. 실제 Chromium 문서 렌더링→크롤러→응답 스키마→앱 prefill 매핑 포함.
- 같은 페이지의 다른 상품 소재 혼입, 잘못된 첫 JSON-LD 상품 선택, HTTP200 CAPTCHA robots 응답에 대한 회귀 테스트 포함.
- iOS14개 단위 테스트와 밝음/어두움 각각4개 UI 시나리오 통과.
- Android90개 단위 테스트, lint, 일반 밝음/좁은 어두움 각각2개 네이티브 시나리오 통과.
- 현재 앱 바이너리의 원본 화면32장, 전후 비교8쌍을 독립 검수했다. 화면 검수 PASS, 최종 무결성 검수 APPROVE/차단사항 없음. 기존 브랜드의 글꼴 크기·색상 대비까지 새로 인증한 것은 아니다.
- 최종 후보 및 운영 URL에서 실제 기존 계정으로 세션 갱신→잔액 조회→잘못된 링크400→상품 미리보기→잔액 재조회 통과. 미리보기 전후 잔액 동일.
- 실판매처 시험 링크 `https://www.musinsa.com/products/5219138`은 수집 정책 확인/접근 제한으로422와 직접 입력 안내를 반환했다. 이를 실제 판매처에서 소재·핏 추출에 성공한 검증으로 해석하지 않는다. 수집 가능한 문서의 긍정 경로는 통제된 Chromium HTML/JSON fixture와 두 앱의 동일 JSON fixture로 검증했다. 차단 우회는 하지 않았다.
- 최종 서비스 Ready/ConfigurationsReady/RoutesReady 모두 True, 최종 리비전100%를 별도 조회로 확인했다.

## 증빙과 롤백

- [검증 요약](evidence/product-report-20261030/verification.json)
- [배포 소스 해시](evidence/product-report-20261030/source-manifest.json)
- [트래픽 확인](evidence/product-report-20261030/traffic-verification.json)

필요하면 이전 운영 리비전에 트래픽100%를 되돌릴 수 있다. 앱의 새 메타데이터 필드는 선택 사항이어서 구형 서버 응답도 사이즈 요약으로 처리한다. 별도 데이터 변경을 되돌릴 필요는 없다.
