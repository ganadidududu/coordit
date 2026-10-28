# 실제 사진 봉제점 추가 학습·평가 — 2026-10-28

기존 브랜치에서 Phase 2만 수정했다. 원본 AI Hub 5epoch와 통합 50epoch checkpoint는 보존했다. Apple Metal/MPS에서 추가 30epoch와 별도 60epoch 학습을 **완료**했다. 두 새 모델 모두 운영 승인·앱 설치·서버 배포하지 않았다.

## 정답과 학습량

현재 실제 좌표 지도학습의 핵심은 aRTF 티셔츠 210장과 반바지 104장, 총 **314장**이다. GCD는 합성 이미지 48장 중 24장에 좌표가 있고 그중 17장에 가시점이 있다. AI Hub 2,482장과 Second-Hand Fashion은 이번에도 봉제 좌표 정답이 없으므로 각각 원본 마스크·분류와 분류 학습에만 사용했다. 이 사진 수를 봉제점 정답 사진 수로 더하지 않는다.

| 실행 | 완료 epoch | 실제 사용 고유 이미지 | 노출 횟수 | optimizer step | 가시 좌표 있는 고유 이미지 |
| --- | ---: | ---: | ---: | ---: | --- |
| `seam-real-augmentation-v1` | 30 | 2,355 | 30,720 | 1,920 | 실제 314 + 합성 17 |
| `seam-diverse-real-augmentation-v1` | 60 | 12,671 | 61,440 | 3,840 | 실제 314 + 합성 17 |

30epoch 실행의 고유 소스 수는 AI Hub 1,783 / aRTF 524 / GCD 48이다. 60epoch 실행은 AI Hub 1,745 / aRTF 524 / GCD 48 / Second-Hand 10,354다. 고유 합성 이미지 **48장**을 재사용했으며 새 합성 사진 수로 중복 집계하지 않는다. 합성 노출은 각각 1,530 / 3,060회다. 기존 50epoch에 새 90epoch를 직렬 누적한 모델은 아니다. 30epoch는 기존 통합 모델에서, 60epoch는 기존 AI Hub mask 모델에서 각각 초기화했다.

기존 128×128 RGB, 공유 17개 landmark head 구조를 유지했다. RGB·마스크·좌표에 같은 회전(±20°), 크기(0.85–1.15), 이동(±0.06)을 적용하고 밝기를 0.7–1.3배 변경했다. 잘려 나간 점은 위치 정답에서 제외한다. 좌우 및 한쪽 소매/옆선 의미를 임의로 바꾸는 mirror augmentation은 쓰지 않는다. 첫 시도에서 MPS의 border padding 미지원 오류가 epoch 0 전에 발생했고, zero padding과 평균 RGB 배경으로 수정한 후 별도 로그를 보존하며 재실행했다. 실패한 시도를 학습 성공으로 집계하지 않았다.

## 학습에 쓰지 않은 실제 사진 561장

aRTF publisher test에서 티셔츠 **389장**, 반바지 **172장**을 추출했다. 기존 CameraDataset 16장의 원본 경로와 과거 학습 이미지에 유사한 3장을 제외했다. 준비 시 과거 19개 학습 artifact의 모든 manifest를 SHA-256으로 고정하고 사진 SHA·원본 SHA·의류 ID·dHash를 비교했다. 점수 계산 시 비교하는 모델의 현재 manifest도 다시 확인한다. 세 실행 모두 평가 사진의 기록된 학습 중복은 0장이다.

평가 corpus는 미등록 `artf-publisher-test-evaluation-only-v1` 소스 ID를 쓰며 일반 학습 loader에서 거부한다. split만 train으로 바꿔도 학습에 넣을 수 없다. 준비 영수증과 manifest 해시, 원본 이미지 해시도 검사한다.

**새로운 독립 출시 평가라는 뜻은 아니다.** 같은 publisher test 계열 중 기존 16장은 과거 휴리스틱 개발에 사용됐고 원저자의 의류·세션 ID를 완전히 복원하지 못했다. 이번 점수를 보고 augmentation 설정을 비교했으므로 이 평가 풀은 향후 개발 평가로 취급한다. 새로 봉인한 실제 촬영·줄자 최종 평가 세트는 여전히 없다.

| 모델 | 티셔츠 PCK@0.05 | 티셔츠 NME | 반바지 PCK@0.05 | 반바지 NME | 마스크 mIoU |
| --- | ---: | ---: | ---: | ---: | ---: |
| 기존 통합 50epoch | 20.77% | 0.14491 | 22.00% | 0.14152 | 0.59372 |
| 추가 30epoch, 기하·밝기 증강 | 18.55% | 0.15527 | 23.20% | 0.13480 | 0.61771 |
| 별도 60epoch, 실제 사진 다양성 추가 | 23.63% | 0.13525 | 20.91% | 0.14202 | 0.61323 |

티셔츠 가시 target 1,536개, 반바지 832개를 평가했다. 반바지의 `waist_left`와 `side_waist`는 같은 원본 점이므로 독립 좌표 두 개로 해석하지 않는다. 모든 가시 GT 점을 점수에 넣으며 낮은 모델 신뢰도의 실패 점을 빼지 않는다. PCK는 **128×128 입력 대각선의 5% 이내**, NME는 같은 대각선으로 나눈 평균 위치 오차다. cm 오차가 아니다. mIoU는 두 카테고리의 사진별 IoU 평균을 카테고리별로 다시 평균한 값이다.

**추가 학습으로 일부 수치는 올랐지만 두 카테고리에서 일관된 개선은 없었다.** 기존 학습 사진의 PCK 100%는 과적합을 보여준다. 현재 20%대 결과로 어깨·가슴 등의 실제 치수를 자동 측정할 준비가 됐다고 판단할 수 없다. 목·소매·힙 등 미학습 점과 코트/재킷의 실제 봉제점은 미검증이다. cm MAE·P95는 null, 출시 승인은 false로 유지한다.

원문 지표:

- `ml/reports/artf-unseen-before-augmentation.json`
- `ml/reports/artf-unseen-after-augmentation.json`
- `ml/reports/artf-unseen-diverse-augmentation.json`
- `ml/reports/SEAM_GENERALIZATION_RUNS.json`

## AI Hub 좌표 정답을 늘리는 다음 경계

사진을 외부 AI에 보내지 않는 로컬 VIA 검수 도구를 준비했다. 학습 사진 16장에 **미검수 제안 64개**, 학습 이력이 없는 후보 사진 2장에는 **제안 0개**로 분리했다. 현재 사람이 검증한 AI Hub 봉제점은 여전히 0개다. 예측 좌표를 정답으로 재학습하거나 예측 좌표와 자기 자신을 비교해 높은 PCK를 만들지 않는다. [로컬 검수 절차](AIHUB_LOCAL_SEAM_REVIEW.md)를 따른다.

AI Hub semantic 주석의 실제 검수/프로토콜·권리 범위 확인 전 학습 승인은 추가하지 않았다. 새 검수점이 들어와도 원본 사진 SHA, 검수자, 픽셀 근거, 명시적 verified 상태를 검사하고 blind 평가 사진은 학습 loader에 넣지 않는다. 현재 학습만 더 반복하는 것보다 **AI Hub 실제 어깨 봉제선·겨드랑이의 올바른 좌표를 확보하는 일**이 먼저다.

## 재현

`ml/`에서 실행한다. 출력 폴더가 이미 있으면 기존 checkpoint를 덮어쓰지 말고 config에 새 실행 이름을 지정한다. 부모 checkpoint·승인 데이터는 로컬에 있어야 한다. 새로 재현한 모델은 새 SHA와 artifact SHA를 기록해 비교 config에 고정한다.

```sh
uv sync --locked --python 3.12
uv run python -m coordit_ml prepare-publisher-test prepare-publisher-test.json
uv run python -m coordit_ml train config-seam-real-augmentation.json
uv run python -m coordit_ml train config-seam-diverse-real.json
uv run python -m coordit_ml compare-seams compare-artf-unseen-diverse.json
uv run pytest -q
uv run ruff check coordit_ml tests
uv run basedpyright
```

checkpoint는 `ml/artifacts/seam-real-augmentation-v1/checkpoint.pt`, `ml/artifacts/seam-diverse-real-augmentation-v1/checkpoint.pt`에 있으며 Git에 포함하지 않는다. 파일별 SHA·부모 hash·registry hash·source별 사용량은 새 실행 보고서에 있다. checkpoint를 평가한 후 비교 출력이 이미 존재하면 별도 output 이름을 지정해야 한다. 중간 epoch를 덮어쓴 체크포인트로 최종 epoch 점수를 재현했다고 주장하지 않는다.

ML 자동 테스트 65개와 Ruff를 통과했다. 새 모듈·직접 테스트의 basedpyright는 0 errors / 0 warnings이며 전체 basedpyright는 기존 Torch/ONNX stub의 27 warnings 때문에 exit 1이다. iOS/Android 센서·앱 코드는 이번에 변경하지 않았고 새 기기 정확도 테스트도 실행하지 않았다. 카드/AR cm 정답과 이 신경망 평가를 혼동하지 않는다.
