# AR 전용 개발 브랜치

2026-10-30 기준 `codex/camera-auto-guides`는 배포용 `main`을 바탕으로 AR 의류 실측과 측정점 모델을 개발하는 브랜치다. 브랜치 이름은 유지한다.

## 기준 코드와 범위

- 동기화 전 AR HEAD: `0811892`.
- 반영한 원격 main HEAD: `e7cd437` (`Merge pull request #49 from ganadidududu/codex/release-link-first-fitlab`).
- 기존 AR 이력은 이미 main에 포함돼 있었다. 그 이후의 41개 커밋을 **fast-forward**로 반영했고 기존 커밋을 재작성하지 않았다.
- 배포용 홈·Fit Lab·옷장·상품 링크·가입/결제·무료 첫 리포트 정리는 main의 코드를 그대로 사용한다. 이 브랜치에서 별도 제품 변경을 병행하지 않는다.
- 앞으로 이 브랜치에서 수정할 범위는 ARKit/ARCore 촬영·좌표/평면 기하·측정 랜드마크·수동 보정·관련 추론 서비스·승인 데이터 수집/주석/학습/평가·전용 테스트/문서다.
- 현재 우선순위는 대략적인 점 제안 → 사용자 확인/수정 → 촬영 시점 AR 평면으로 cm 계산이다. cm 실기기 정확도와 전체 카테고리 봉제점 성능은 여전히 미검증이다.
- Phase 3 단일 RGB 스케일 추정은 진행하지 않는다. 사용자 예산 중단 지시에 따라 추가 유료 Vision API 호출도 하지 않는다.

`main`의 로컬 체크아웃과 릴리스 브랜치의 커밋을 변경하지 않았다. 이 작업 폴더는 AR 브랜치로 전환했다. 운영 배포, Supabase migration/RLS/RPC 적용, 모델 승인 변경은 수행하지 않는다.

## 일반 앱과 개발 시험의 경계

일반 Debug/Release 앱의 진입 제한도 main과 동일하게 유지한다. Debug라는 이유만으로 카메라 진입을 다시 허용하지 않는다. `CoorditGarmentCaptureController.featureEnabled`는 `CoorditCameraComparisonEnabled`를 읽는 main 구현을 유지한다.

| iOS Info.plist | 기본값 |
| --- | --- |
| `CoorditCameraComparisonEnabled` | false |
| `CoorditCardlessAREnabled` | false |
| `CoorditAILandmarksEnabled` | false |
| `CoorditAILandmarksDevelopmentEnabled` | false |
| `CoorditRGBEstimateEnabled` | false |

Android의 `CARDLESS_AR_ENABLED`, `AI_LANDMARKS_ENABLED`, `AI_LANDMARKS_DEVELOPMENT_ENABLED`, `RGB_ESTIMATE_ENABLED`도 false다. 새 AR 시험을 위해 공용 release 설정을 바꾸지 않는다. iOS 회귀 테스트에 기본 카메라 진입과 개발 AI 비활성화 확인을 보강했다.

별도 iOS Debug 앱은 기존 `scripts/run-ar-field-test-ios.sh`를 사용한다. 임시 프로젝트·별도 앱 ID `com.insihwan.coordit.arfieldtest`·`CoorditARFieldTestBuild`를 사용하므로 기본 배포 앱 설정을 변경하지 않는다.

```sh
# 실제 기기용 로컬 AR 시험 앱 설치. 기존 팀/연결 기기 값을 넣는다.
scripts/run-ar-field-test-ios.sh <TEAM_ID> <DEVICE_UDID>
```

이 명령 자체는 외부 모델을 호출하지 않는다. 기본 실행에는 hosted gateway 연결을 주입하지 않는다. 공급자 호출을 사용자가 다시 승인하기 전에는 `scripts/run-hosted-ar-gateway.sh`나 유료 벤치마크 CLI를 실행하지 않는다. 이미 설치한 goofy 앱은 기존 설치본이며 이번 브랜치 동기화에서 재설치하지 않는다.

시뮬레이터의 `--coordit-ar-field-test --coordit-hosted-ar-fixture --coordit-ui-testing`는 작성된 샘플 화면이다. 실기기 AR 센서/cm 검증을 대신하지 않는다. 앱 전체 UI 확인은 이 인수 없이 일반 앱을 실행한다.

## 보존한 개발 자료

기존 `CoorditARPlaneMeasurement`, `CoorditHostedAR*`, 캡처/보정 화면, ARCore 구현, `ml/coordit_ml/`, `ml/registry/`, 학습·전처리 설정, 실행 스크립트와 보고서를 보존했다. main 반영 과정에서 ML 하위의 추적 파일 변경은 기존 경고를 비치명적으로 처리하는 `ml/pyproject.toml` 설정 3줄뿐이며, 학습 코드·데이터 레지스트리를 삭제하거나 교체하지 않았다. Android 추론 클라이언트의 bounded-response 읽기 호환 수정과 iOS 기본 카메라 진입 차단은 main의 수정으로 유지했다.

Git에서 제외된 아래 자료도 현재 작업 폴더에 보존돼 있다.

- `ml/artifacts/aihub71501/real`, `approved-v1`, `seam-review-v2`: 로컬 원본·승인 변환·주석 작업.
- `ml/artifacts/aihub-coat-jacket-mask-pretrain-v2/checkpoint.pt`, `spatial-v2-shared/checkpoint.pt` 등 기존 체크포인트.
- `ml/artifacts/artf-*`, `garmentcodedata-v2`, `secondhand-*`: 기존 공개 데이터와 전처리/평가 산출물.
- `ml/.env`, `ml/artifacts/hosted-ar/connection.json`: 로컬 비밀 설정. 내용을 출력하거나 Git에 추가하지 않는다.

이 자료들은 GitHub 푸시로 백업되지 않는다. `git clean -xfd`나 `ml/artifacts/` 정리로 지우지 않는다. AI Hub 사진은 외부 AI에 전송하지 않고 수정 좌표도 사용자 동의 없이 학습에 편입하지 않는다. 동기화 시작 시 실행 중인 학습 프로세스는 발견되지 않았으며, 이 작업에서 학습 시작·중단·재개를 수행하지 않았다.

## 다음 main 반영

```sh
git switch codex/camera-auto-guides
git fetch origin main
git merge origin/main
```

AR 전용 커밋이 생긴 뒤에는 일반 merge로 main 변경을 반영한다. 공개된 이력을 rebase/force push하지 않는다. 충돌은 최신 main의 배포 흐름/비활성 플래그와 AR 개발 코드를 함께 보존하도록 해결하고 테스트한다. 비 AR 제품 변경은 main의 작업 흐름에서 처리한 뒤 이 브랜치로 가져온다. 정리 목적으로 데이터·가중치·기존 카드/LiDAR 코드를 제거하지 않는다.

## 이번 검증

ML 120개 테스트, Ruff, basedpyright(0 errors, 기존 Torch/ONNX warnings 28개), 승인 레지스트리와 출처 16,323개 inventory audit를 통과했다. Android `testDebugUnitTest assembleDebug`, 백엔드 typecheck·camera-comparison·garment-landmarks·report 및 공유 narrative 규칙 검사가 성공했다. 백엔드 회귀 테스트는 로컬 테스트 설정을 사용했다.

iOS는 `/tmp/coordit-ar-main-sync/ios.xcresult`에서 **97 passed / 4 skipped / 0 failed**를 확인했다. 단위 92개와 UI 5개가 통과했다. 스킵된 단위 4개는 main에서 일반 카메라 비교가 비활성화됐을 때 건너뛰도록 명시한 `CoorditCameraAnalysisTests`이며 통과로 집계하지 않는다. 기존 카드/LiDAR·AR 기하·저장·키체인·랜드마크 테스트를 유지하고, hosted AR 초안 확인/드래그/누락점/내보내기 UI 4개와 릴리스 링크·준비 중 카메라 안내·명시적 분석 차감 UI 1개를 실행했다. 배포용 진입 차단과 별도 Debug 시험 경로가 함께 유지됨을 확인했다.

XcodeBuildMCP 호출은 빌드와 UI 실행을 기다리다 300초 도구 제한에 걸렸지만, 실행은 완료돼 Xcode 로그가 `TEST EXECUTE SUCCEEDED`를 기록했다. 성공 판정은 로그 문구만이 아니라 `xcrun xcresulttool get test-results summary`의 `result=Passed`와 위 실제 개수로 확인했다. SimSlim을 적용한 별도 QA 시뮬레이터를 사용했다. Android는 Gradle 입력이 기존 검증과 동일해 43개 task가 `UP-TO-DATE`로 판정됐으며, 단위 테스트를 새로 전부 실행한 것으로 표현하지 않는다.

로컬 AI Hub 승인 corpus도 실제 파일로 다시 검증해 기존 **2,482장(코트 1,250 / 재킷 1,232)**이 수락됐다. 추가 수집·학습·주석 변경은 없다. 두 기존 체크포인트(각 4,990,994 bytes)의 현재 SHA-256은 다음과 같다.

| 체크포인트 | SHA-256 |
| --- | --- |
| `aihub-coat-jacket-mask-pretrain-v2/checkpoint.pt` | `0baeadd24aeb788b1a575c3f4762643b1b6a1b8b486d84ec1ceb0fb9cae96ddf` |
| `spatial-v2-shared/checkpoint.pt` | `bc5992b7572b5f451a3e2389fef3f9de915c4f540ec6cb66d2b84a141ed17798` |

백엔드/Android/ML 로그는 `/tmp/coordit-ar-main-sync-{backend,android,ml-types}.log`에 있다. 센서/cm 실측·실제 결제·운영 배포·유료 추론 검증은 이번 동기화 범위가 아니다.
