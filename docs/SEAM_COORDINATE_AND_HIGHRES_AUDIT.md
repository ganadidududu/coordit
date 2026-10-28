# 봉제점 좌표 점검·고해상도 실험 — 2026-10-28

`codex/camera-auto-guides`에서 Phase 2만 작업했다. iOS/Android 센서·기존 카드/LiDAR·결제·저장·DB·Phase 3 코드는 변경하지 않았다. 새 모델은 로컬 개발용이며 폰/운영 서버에 설치하지 않았다. 기존 checkpoint는 보존했다.

## 1. 좌표 오류 확인

공개 aRTF 학습 사진 524장과 학습 미사용 사진 561장을 확인했다. 모두 **512×256**, EXIF orientation 1이며 manifest와 실제 이미지 크기 불일치는 0건이다. 전체 사진을 정사각 입력으로 리사이즈하는 현재 경로는 외관 비율을 바꾸지만, 좌표도 x/width·y/height로 정규화하므로 그 자체가 전반적인 좌표 축 오류는 아니다. 비정사각 사진의 표시점→리사이즈 픽셀 정합 테스트와 기존 회전/잘림 테스트를 실행했다.

원래 통합 50epoch 모델에 대해 동일 561장에 축 반전·180도 회전·xy 전치·알려진 양측 점 이름 교환을 진단했다. 원본 정답은 바꾸지 않았다. 전체 반전으로 일관되게 개선되지 않아 전반적인 mirror/축 오류를 원인으로 확정하지 않았다.

| 진단 | 티셔츠 PCK / NME | 반바지 PCK / NME |
| --- | --- | --- |
| 원래 좌표 | 20.77% / 0.14491 | 22.00% / 0.14152 |
| x 반전 | 7.10% / 0.18634 | 7.57% / 0.16980 |
| xy 전치 | 3.58% / 0.21451 | 9.38% / 0.17817 |
| heatmap 최대값 진단 | 28.84% / 0.16623 | 31.97% / 0.17393 |

현재 softargmax는 여러 후보의 평균을 반환할 수 있다. 최대값으로 바꾸면 PCK는 오르지만 **평균 위치 오차 NME가 두 종류 모두 악화**됐다. 따라서 좋은 점수만 골라 decoder를 바꾸지 않았다. 전체 점의 가시 정답을 평가하고 낮은 모델 신뢰도의 실패 점도 빼지 않았다. 한 의류 전체의 좌우를 한 번 바꿔 보는 oracle 진단도 별도 기록했으며, 그 결과를 실제 추론·기존 ordered PCK로 대체하지 않았다.

양측 점 사이 길이 오차는 원본 512×256 픽셀로 복원한 2D 투영 길이 기준으로 별도 기록했다. 이 값도 실제 cm가 아니며 원근·AR 오차를 평가하지 않는다. PCK@0.05/NME는 기존과 같은 **정규화 정사각 입력 대각선** 기준이다.

실제 공개 사진 2장의 원래 정답(초록), 이전 모델/256 모델 출력(빨강)을 로컬 `ml/artifacts/coordinate-audit-v1/public-unseen-visual-audit.png`에서 확인했다. 이 시각 점검은 새 독립 정확도 평가가 아니며 AI Hub 사진은 사용하지 않았다.

## 2. 발견한 의미·프로토콜 차이

aRTF 원저자 ordering 코드를 고정 revision에서 직접 확인했다. 상의 left는 **waist/hem 점이 원본 bbox 왼쪽 아래에 더 가까운 쪽**, 반바지는 허리 점이 bbox 왼쪽 위에 더 가까운 쪽이다. 옷 전체의 양측 점을 함께 바꾸는 대칭 해소 규칙이며, 착용자 좌우 또는 각 쌍의 x순 정렬이 아니다. [원저자 코드](https://github.com/tlpss/aRTF-Clothes-dataset/blob/e3eda811bca47584f1bb9432e3f11366ccef1e4a/artf_clothes/scripts/keypoint_ordering.py)

실제 aRTF 티셔츠 학습 사진의 가시 어깨 쌍 196개 중 62개, 평가 쌍 382개 중 94개는 `left.x > right.x`다. 이는 이름을 무조건 잘못 붙였다는 증거가 아니다. 기존 AI Hub v1 문서의 “화면 좌우”와 섞을 때 충돌할 수 있다는 증거다. **테스트 라벨을 예측값에 맞춰 정렬하거나 교정하지 않았다.**

GCD 기존 렌더러는 투영된 어깨/허리 쌍의 x순서로 옷 전체의 좌우를 바꾼다. aRTF 밑단/허리 코너 규칙과 모든 변형에서 같다고 인증하지 않았다. 이 작은 합성 주석의 좌우 정의도 향후 통합 프로토콜 검토 대상이다. 기존 파일·정답·checkpoint를 임의로 다시 쓰지 않았으며 현재 결과를 실제 봉제선 인증으로 사용하지 않는다.

AI Hub 원본 JSON **6,161개/Polygon 6,183개**의 필드를 다시 검사했다. 봉제 좌표가 숨겨져 있지 않았으며 마스크 polygon과 scalar 치수만 있었다. 원문 측정법에서 가슴은 겨드랑이 아래 **1인치의 폭×2**, 어깨는 **뒷면**에서 측정한다. 앞면 겨드랑이 좌표와 native 가슴 cm 숫자를 직접 대응시키면 다른 부위를 학습하게 된다. 이 숫자를 봉제점 위치나 AR cm 정답으로 전환하지 않았다.

## 3. AI Hub 로컬 주석 준비

외부 AI로 사진을 보내지 않는 조건을 유지했다. v2 task는 코트 64장 + 재킷 64장, **128장/미검수 제안 512개**다. 원본 파일명 기준 앞면 60장·뒷면 68장을 분리했다. 별도 학습 미사용 후보 앞면 2장은 예측점을 전혀 보여주지 않는다. 이전 v1 묶음은 보존했다.

`coordit-upper-seam-v2`는 사람이 직접 찍는 밑단 기준점 두 개와 원본 front/back을 함께 요구한다. 이 기준점은 전체 의류의 좌우를 확인하기 위한 `side_reference`이며 총장/밑단 중심 정답으로 바꾸지 않는다. SHA, 실제 이미지 크기, task 용도, view, protocol, 검수자, 가시성·verified 상태를 검사한다. v1 주석·밑단 기준점 누락·반전·앞뒤 변경·미검수 제안은 거부한다. blind 자료는 학습 loader에서 계속 차단한다.

**현재 사람이 검증한 AI Hub 봉제 좌표는 0개다.** 로컬 annotation은 이미 허가돼 있다. 원본 사진을 외부 AI가 보게 하지 않는 조건에서 이 agent가 자동 예측을 인간 검수로 선언하지 않았다. 새 AI Hub 좌표 정답·AI Hub PCK/NME·AI Hub 봉제점 지도학습 완료를 보고하지 않는다. 준비한 묶음에서 실제 로컬 검수자가 봉제 교차점과 같은 의류 쪽을 확인한 export가 필요하다. 그 전에는 semantic 학습 범위를 승인 상태로 바꾸지 않는다.

[v2 검수 절차](AIHUB_LOCAL_SEAM_REVIEW.md), `ml/import-aihub-via-v2.json`, `ml/evaluate-aihub-blind-v2.example.json`에 실행 경로와 pin이 있다. 원본 사진을 외부 annotation 서비스에 업로드하지 않는다. 초기 프로젝트 128장/2장을 실제 importer에 통과시켜 **정답 0개·출력 미생성으로 거절**되는 것을 확인했다. JavaScript 문법·네트워크 차단 CSP·analytics 제거도 정적으로 검사했다. 앞선 `file://` 브라우저 보안 거절을 우회하지 않아 화면 클릭/드래그 QA는 미실행이다.

## 4. 실제 고해상도 학습

기존 409,328개 parameter를 가진 공간 모델을 유지하고 256/512 입력을 별도 version으로 구분했다. 기존 128 checkpoint를 새 해상도로 몰래 재해석하지 않는다. **128→256 가중치 전환은 명시적 옵션과 동일 spatial 계열일 때만** 허용하고 부모 SHA·현재 데이터 권한·strict state dict를 검사한다. tiny-v1처럼 다른 구조는 옵션이 있어도 거절한다. 512 계약은 코드만 추가했으며 512 학습은 하지 않았다.

같은 부모 통합 50epoch, 같은 승인 manifest와 seed42에서 다음을 실행했다. 각 실행은 **20epoch, batch4, epoch512장, 총 10,240노출/2,560 step**으로 고정했다. 새 optimizer를 썼고 회전/이동/크기 증강 없이 밝기 0.7–1.3만 바꿨다. 이미지 기준 좌우 규칙의 불연속성을 고려한 실험 설정이며 전체 모델에 대해 증강 최적화를 증명하지 않는다.

- `seam-resolution-128-v1`: 기존 128 RGB / 64 heatmap 대조군.
- `seam-resolution-256-v1`: 256 RGB / 128 heatmap, 같은 convolution 구조와 decoder.
- `seam-resolution-256-context-v1`: 256 RGB / 128 heatmap, convolution dilation 2로 주변 문맥을 넓힌 추가 가설 실험. 새 parameter·외부 가중치는 없다.
- `seam-resolution-256-pairs-v1`: 동일 context 구조에 가시 정답의 투영 거리 손실을 더한 실행. cm 회귀 모델이 아니다.

각 실행의 source quota는 epoch당 AI Hub 51 / aRTF 435 / GCD 26이다. AI Hub는 기존 polygon 마스크·분류만, 좌표는 실제 aRTF **314장**과 가시점이 있는 GCD 합성 **17장**에서 학습한다. GCD 고유 합성 이미지는 48장이고 매 실행 합성 노출은 520회다. 다른 실제 분류 사진을 봉제점 정답 이미지로 집계하지 않았다. GCD의 가려진 점은 위치 학습에서 제외했다.

실제로 각 실행에서 노출된 고유 사진은 **1,416장**(AI Hub 844 / aRTF 524 / GCD 48)으로 같다. 가시 좌표가 있는 실제 사진 314장·합성 17장도 같다. 네 실행을 더해 새로운 사진 5,664장을 확보했다고 집계하지 않는다. 학습량은 새로 완료한 20epoch 실행 4개이지 한 모델에 80epoch를 직렬 누적한 것이 아니다.

단순 256 모델이 악화되어 기존 128과 같은 상대적 문맥을 보지 못하는 영향을 추가로 시험했다. context 모델은 nearest-neighbor 2배 이미지에서 첫 convolution이 원래 공간 표본을 재현하는 수치 테스트를 통과했다. 이것은 전체 모델의 실측 정확도 향상 증거가 아니다. 평가에서는 원래 softargmax와 정답을 그대로 유지했다.

크기 우선 검증에서는 context 모델의 PCK 상승과 달리 가슴 양측 점의 원본 픽셀 2D 길이 평균 상대오차가 **32.72%→34.38%**로 나빠졌다. 어깨는 37.97%→37.10%, 반바지 허리는 34.06%→32.00%로 조금 줄었다. 이 역시 cm 실측 오차가 아니다. 모든 측정 부위가 좋아졌다고 판단하지 않는다.

이를 구분하기 위해 `seam-resolution-256-pairs-v1` 실행을 추가했다. 동일 context 구조·원래 부모·데이터·20epoch 조건에서 `projected_pair_loss_weight: 2.0`만 더한다. 가시 GT 양측 점이 실제로 있을 때만 **원본 width/height 비율을 복원한 투영 거리의 상대오차**를 학습한다. 가림/미주석 쌍은 0 supervision이며 숨겨진 점·새 cm 정답을 생성하지 않는다. 이 목적함수는 전체 점 위치 손실을 대체하지 않는다. 두 점 간 거리가 맞아도 둘 다 잘못된 곳에 있을 수 있으므로 PCK·NME·마스크·거리 지표를 함께 비교한다.

## 5. 학습 미사용 실제 사진 전후 비교

같은 티셔츠 389장·반바지 172장, 총 **561장**을 모든 모델에 썼다. 사진 hash·원본 hash·의류 ID·유사 hash 및 현재/과거 학습 manifest를 대조했다. 새로운 모델에 평가 사진을 학습시키지 않았다. 기존 16장과 유사 학습 사진 3장은 준비 단계에서 제외돼 있다.

| 모델 | 티셔츠 PCK / NME | 반바지 PCK / NME | 두 종류 마스크 mIoU |
| --- | --- | --- | ---: |
| 기존 통합 50epoch | 20.77% / 0.14491 | 22.00% / 0.14152 | 0.59372 |
| 새 128 대조군 +20epoch | 19.14% / 0.14587 | 23.32% / 0.14208 | 0.64221 |
| 새 256 +20epoch | 13.61% / 0.16108 | 11.90% / 0.14872 | 0.58783 |
| 새 256 context +20epoch | 23.05% / 0.14351 | 24.16% / 0.13655 | 0.65073 |
| 새 256 context +거리손실 +20epoch | 22.20% / 0.14051 | 24.52% / 0.13475 | 0.66354 |

추가 context 실행은 같은 128 대조군보다 두 종류 PCK/NME가 좋아졌고 기존 통합 50epoch 대비도 소폭 개선됐다. 최종 비교는 `ml/reports/seam-resolution-128-vs-256-context.json`에 있다. 이전 다양한 사진 60epoch 실행의 티셔츠 점수(23.63% / 0.13525)보다 높아진 것은 아니므로 모든 과거 모델보다 우수하다고 주장하지 않는다. 좋은 카테고리·좋은 decoder 점수만 골라 결과를 대체하지 않는다. 단순 256 모델은 채택하지 않고 context 모델은 후속 개발 후보로만 보존한다. 아직 정확한 자동 실측에 쓸 성능이 아니며, 고해상도에서의 문맥·표본 수·데이터 도메인 영향을 단일 원인으로 확정하지 않는다.

거리손실 실행은 context 대비 티셔츠 PCK가 조금 낮아졌고, NME 두 종류와 반바지 PCK는 개선됐다. 원본 픽셀 투영 길이의 평균 상대오차는 다음과 같다. **가슴은 원래 모델보다 여전히 나쁘므로 실측 모델로 승격하지 않는다.**

| 투영 길이 — cm 아님 | 원래 모델 | context | context +거리손실 |
| --- | ---: | ---: | ---: |
| 어깨 | 37.97% | 37.10% | 37.17% |
| 겨드랑이 사이 | 32.72% | 34.38% | 33.01% |
| 반바지 허리 | 34.06% | 32.00% | 29.40% |

학습한 거리와 평가한 거리는 2D 투영 거리다. 이 값의 개선을 실제 AR/줄자 cm 개선으로 해석하지 않는다. 최종 거절 조건은 그대로 유지하고 운영 측정 후보는 null이다. 원문은 `ml/reports/seam-resolution-context-vs-pairs.json`, `ml/reports/coordinate-pairs-audit.json`에 있다.

**이 561장은 학습에 안 쓴 개발 평가 사진이다.** 같은 publisher test 계열이 과거 16장 휴리스틱 개선에 사용됐고, 이후 이번 평가를 보며 실험을 추가했다. 원저자 동일 실물 의류·촬영 세션의 완전한 독립성도 인증하지 못했다. 새로 봉인한 최종 출시 평가로 주장하지 않는다. 실제 줄자 cm MAE/P95·기기별 AR 오차는 여전히 미검증이다.

## 6. 실행·재현·검증

`ml/`에서 실행한다. 승인 데이터와 부모 checkpoint가 로컬에 있어야 하고 출력이 있으면 config에 새 실행 이름을 지정한다. 완료 artifact를 덮어쓰거나 hash를 바꿔 통과시키지 않는다.

```sh
uv sync --locked --python 3.12
uv run python -m coordit_ml audit-coordinates audit-coordinate-baseline.json
uv run python -m coordit_ml train config-seam-resolution-128.json
uv run python -m coordit_ml train config-seam-resolution-256.json
uv run python -m coordit_ml train config-seam-resolution-256-context.json
uv run python -m coordit_ml train config-seam-resolution-256-pairs.json
uv run python -m coordit_ml compare-seams compare-seam-resolution-control.json
uv run python -m coordit_ml compare-seams compare-seam-resolution-256.json
uv run python -m coordit_ml compare-seams compare-seam-resolution-256-context.json
uv run python -m coordit_ml compare-seams compare-seam-resolution-pairs.json
uv run python -m coordit_ml audit-coordinates audit-coordinate-pairs.json
uv run pytest -q
uv run ruff check coordit_ml tests
uv run basedpyright
```

checkpoint는 위 이름의 `ml/artifacts/<run>/checkpoint.pt`, 실제 로그는 각 run의 `training.jsonl`이다. 정확한 모델/artifact/manifest/source hash와 실제 고유 사진 수는 `ml/reports/SEAM_HIGHRES_RUNS.json`에 있다. baseline pin은 변하지 않았다. 가중치·사진은 Git 밖에 있다.

128/단순256 실행 후 상속된 모듈 속성에 type annotation을 추가했다. 실행 당시의 원본 source·registry·uv.lock은 각 run의 `training-source/`에 보존했고 원래 학습 fingerprint와 일치하는 것을 검사했다. 현재 소스로 구 실행 resume을 허용하려고 artifact를 고치지 않았다. 정확한 resume이 필요하면 해당 snapshot을 Python 모듈 경로의 맨 앞에 두고 같은 원본 config/데이터를 사용한다. 새 source의 재학습은 새 output·새 SHA로 기록한다.

실제 로컬 FastAPI `/v1/landmarks`에 단순256 모델과 공개 aRTF 사진을 연결했다. 미인증 요청은 HTTP401, 인증·처리 동의가 있는 요청은 HTTP200이다. mask는 실제 256×256이고 학습한 4개 점만 반환한다. 필요한 측정점이 부족하므로 `failed/landmarks_missing_or_occluded`, cm는 빈 값으로 거절했다. 이 API 시험은 정확도 또는 서버 배포 승인이 아니다. 임시 loopback 서버는 종료했다. `ml/reports/highres-local-inference-smoke.json`에 기록했다.

마지막 거리손실 모델도 실제 HTTP에서 같은 인증·치수 거절 동작을 다시 확인했다. 기록은 `ml/reports/pair-final-local-inference-smoke.json`이다. 네 실행 모두 보존한 training-source의 원래 fingerprint를 별도 Python 프로세스에서 검증했다.

새 네 모델의 ONNX/Core ML 변환은 실행하지 않았다. export CLI의 heatmap 출력 이름은 입력 해상도 숫자 대신 실제 출력 유무로 결정하도록 보완했지만, 변환 파일·모바일 실행 성공을 주장하지 않는다.

자동 테스트 **78개**와 Ruff를 통과했다. 새 모듈/직접 테스트의 basedpyright는 0 errors / 0 warnings, 전체는 기존 Torch/ONNX stub의 27 warnings 때문에 exit1(0 errors)이다. iOS/Android 앱과 실제 센서는 이번에 시험하지 않았다. 다음 실측 단계에서는 같은 촬영 프레임의 수동점+AR와 자동점+AR를 줄자 정답에 각각 비교해야 한다. 목표 MAE≤1cm/P95≤2cm가 검증되지 않은 방식·카테고리는 운영 활성화하지 않는다.
