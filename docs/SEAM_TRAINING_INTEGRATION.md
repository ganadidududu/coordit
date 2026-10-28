# 봉제선 학습 통합 — 2026-10-28

후속 추가 90epoch 학습과 **학습 미사용 실제 사진 561장 평가**는 [추가 학습·평가 기록](SEAM_GENERALIZATION_2026_10_28.md)에 있다. 이 문서 아래의 PCK 100%는 당시 학습 사진 적합도다. 후속 실제 사진 PCK는 약 20–24%로 낮으며 AI Hub의 사람이 검증한 봉제점은 아직 0개다.

기존 `codex/camera-auto-guides` 브랜치에서 진행했다. Phase 3, 운영 feature flag, DB·결제 로직은 변경하지 않았다. 표시 명칭은 iOS·Android·리포트·문서에서 **반바지**로 통일하고 `shorts` raw value와 API·데이터셋 키는 유지했다.

## 실제 확보·사용 범위

| 소스 | 이번 학습 풀 | 좌표 주석 | 제한 |
| --- | ---: | --- | --- |
| AI Hub 71501 | 실제 코트·재킷 2,482장 | 원본 마스크·치수 메타데이터, 검증된 봉제 좌표 **0장** | 로컬 학습 권한만 사용, 사진의 외부 AI 전송 없음 |
| aRTF 1.0.1 | 실제 사진 524장 | 티셔츠 210장·반바지 104장의 부분 해부학적 좌표 | 타월 210장은 마스크 보조; 봉제·cm 인증 정답 아님 |
| GarmentCodeData v2 | 합성 렌더링 48장, 의류 디자인 6개 | 24장에 3D→2D 좌표, 그중 17장에 가시점 존재 | 실제 사진 아님; 펼친 옷의 cm 정답 아님 |

aRTF의 기존 파일 524장을 새 데이터로 중복 집계하지 않았다. 새 manifest만 만들고 원본 이미지는 hard link로 재사용했다. 총 1,310개 가시 semantic target에는 같은 허리 점을 쓰는 `waist_left`와 `side_waist` 두 헤드가 포함되며, 별도 사진이나 독립적인 측정 횟수로 세지 않는다. 기존 CameraDataset 16장과 모든 publisher test 계열은 계속 학습·검증에서 제외한다. 기존 개발에 사용한 사진으로 새로운 독립 평가 세트를 만들었다고 주장하지 않는다.

GarmentCodeData는 공식 배포 서버의 368GB 전체가 아니라 첫 batch의 5,121,727,032-byte 압축 파일 **앞 32MiB**만 실제로 받았다. 원문 v2 PDF·공식 split·DOI도 확인했다. SHA-256 고정 prefix에서 의류 폴더 15개를 완전히 추출하고, 명확한 공식 training 디자인 6개만 8개 각도로 렌더링했다. 나머지 9개는 복합 드레스·점프수트·불확실한 분류 또는 공식 training 미포함 때문에 제외했다. 기존 소스의 인체 메시·신체 치수·텍스처·렌더·pickle은 추출하지 않는다. 원본별 해시는 로컬 `source-receipt.json`에 있다.

## 주석을 만드는 방법

- aRTF는 원저자의 수동 주석에서 이름과 의미가 확인된 점만 직접 연결한다. 티셔츠 어깨·겨드랑이, 반바지 허리·가랑이·옆선 끝만 사용한다. 목·총장·힙·소매·허리 중심을 평균이나 외곽선으로 만들어 내지 않는다. 원저자의 좌우 정의는 이미지에서 대칭을 구분하는 규칙이다.
- GarmentCodeData는 raw PLY의 인접 UV 중복 정점을 원본 ID로 복원한다. UV island의 삼각형 연결 성분을 publisher panel label에 대응시킨다. 앞·뒤 몸판과 앞·뒤 소매 패널 네 개가 만나는 정확한 정점 두 개가 확인될 때만 어깨/겨드랑이로 구분한다. 바지 네 패널의 유일한 교차점은 가랑이, 열린 경계와 옆 봉제선의 유일한 교차점은 일부 허리 끝이다.
- 패널 대응·정점 수·원본 단위가 불명확하면 실패한다. 3D 좌표, K/R/t와 cm 단위를 보존하고 자체 소프트웨어 렌더러로 투영한다. 가림은 실제 메시 ray/triangle 교차로 검사한다. 24개 가시점과 64개 가려진 점이 기록되었고, 가려진 점은 위치 학습에서 제외한다.
- 확인하지 못한 목 중심·총장 시작/끝·소매 끝·힙·밑위 시작점은 여전히 미완성이다. 이 자료만으로 전체 측정 부위를 자동 완성하지 않는다. 드레이프된 옷의 3D 직선거리를 평평하게 펼친 옷의 봉제선 치수로 취급하지 않는다.
- AI Hub에 사람이 검증하지 않은 점을 정답으로 추가하지 않았다. `import-seam-reviews`는 사진 SHA, 좌표계, 검수자, 측정 프로토콜, 픽셀 근거와 `verified` 상태를 요구한다. proposal/rejected/다른 crop/주석 권한 미승인 자료는 차단한다. 기존 GT는 덮어 지우지 않고 검수한 점을 병합한다. 현재 AI Hub의 semantic 권한은 별도 승인 전까지 차단되어 있다.
- 추론은 해당 카테고리에서 실제 가시 정답으로 학습한 헤드만 반환한다. 학습하지 않은 총장·소매 등의 임의 출력을 높은 신뢰도로 제시하지 않으며, 필요한 점이 부족하면 기존 실패·수동 보정 경로로 간다.

## 실제 학습과 체크포인트 보존

구조는 기존 `coordit-spatial-multitask-v2`(128×128 RGB, 공유 17개 랜드마크 헤드, 64×64 heatmap)를 유지했다. 새 외부 사전학습 가중치는 없다. Apple Metal GPU/MPS에서 실제로 학습했다.

| 실행 | 에포크 | 고유 이미지 | 노출 횟수 | step | epoch별 AI Hub:aRTF:GCD |
| --- | ---: | ---: | ---: | ---: | --- |
| 통합 pilot | 10 | 2,808 | 10,240 | 640 | 512:410:102 |
| 추가 fine tune | 40 | 3,029 | 40,960 | 2,560 | 256:717:51 |

Fine tune 실행에서 사용한 고유 이미지는 AI Hub 2,457장, aRTF 524장, GCD 48장이다. 두 새 실행의 합성 노출은 총 3,060회이며 **서로 다른 합성 이미지 48장**을 반복 사용했다. 과거 procedural-v1/v2 합성 이미지는 이 두 실행에 넣지 않았다. 비율은 작은 파일럿에서 학습 부족을 확인한 뒤 조정한 개발 설정이며 독립 검증으로 최적화했다고 주장하지 않는다.

원래 AI Hub 학습은 작업 시작 때 이미 5에포크를 완료했다. 실행 중인 학습을 중단한 적이 없다. 기존 checkpoint와 artifact SHA를 고정하고 다른 폴더에서 가중치만 초기화했다. 새 fine tune은 새 optimizer를 쓰며, 동일 실행의 resume은 그 실행의 optimizer/RNG/epoch를 복구한다. 원본 가중치와 메타데이터를 수정하거나 승인 hash를 고쳐 통과시키지 않는다.

- 기존 AI Hub: `ml/artifacts/aihub-coat-jacket-mask-pretrain-v2/checkpoint.pt` — `0baeadd24aeb788b1a575c3f4762643b1b6a1b8b486d84ec1ceb0fb9cae96ddf`
- pilot: `ml/artifacts/seam-integrated-pilot-v1/checkpoint.pt` — `eeb659c1fcb28aa4c7711976432f6590b2316d37877a3914114889f4da29ec00`
- fine tune: `ml/artifacts/seam-integrated-finetune-v1/checkpoint.pt` — `b60a2c9a7014bc3320b818321be24d83d86b2f66cf784f360245658f985ece49`

원본 checkpoint 보존, source별 실제 사용량, 부모·manifest·registry hash는 `ml/reports/SEAM_INTEGRATION_RUNS.json`에 있다. 가중치와 대형 데이터는 Git에서 제외했다. 휴대폰에 이 새 모델을 설치하거나 외부 서버에 배포하지 않았다.

## 정확도 — 학습 사진의 적합도와 독립 성능 구분

같은 aRTF 524장의 mask와 가시 좌표를 세 모델에 사용했다. 좌표 정답이 있는 사진은 314장이다. PCK@0.05와 NME의 기준은 **128×128 입력 대각선**이며 cm 오차가 아니다.

| 카테고리 | 기존 AI Hub mask 모델 PCK / NME | 10epoch pilot PCK / NME | 추가 40epoch PCK / NME |
| --- | --- | --- | --- |
| 티셔츠 | 1.84% / 0.15540 | 15.23% / 0.11373 | 100% / 0.00440 |
| 반바지 | 5.85% / 0.15158 | 12.90% / 0.12385 | 100% / 0.00422 |

마스크 mIoU는 같은 티셔츠·반바지·타월 그룹 평균으로 기존 0.30747, pilot 0.79378, fine tune 0.95011이다. 코트/재킷 AI Hub 학습 사진의 fine-tune IoU는 각각 0.94669/0.93808이다. 코트·재킷은 실제 봉제 좌표가 없어 PCK/NME가 null이다.

**100%는 학습에 사용한 사진에 대한 결과다.** 데이터 반복에 대한 과적합 가능성이 크며, 처음 보는 옷의 봉제선 정확도나 1cm 실측 목표 달성을 증명하지 않는다. 새 독립 실제 validation/test 사진은 각각 **0장**, 독립 줄자 cm 평가도 **0벌**이다. 다른 9개 카테고리의 실제 봉제점 정확도와 모든 카테고리의 실제 cm 오차는 미검증이다. 모델 선택·출시 판단에 이 숫자를 사용하지 않는다.

원문 결과: `ml/reports/seam-pilot-real-development-comparison.json`, `ml/reports/seam-finetune-real-development-comparison.json`, `ml/reports/seam-finetune-aihub-training-set-metrics.json`. 비교 실행은 baseline 파일을 쓰거나 다시 승인하지 않는다.

## 라이선스와 배포

aRTF의 원본 사진/주석은 CC BY 4.0, 코드 MIT를 각각 확인했다. GarmentCodeData v2의 ETH 원본 데이터는 CC BY 4.0이며 이번 승인은 의류 geometry와 자체 body-free/texture-free 파생물로 제한한다. 신체 데이터·원본 텍스처와 외부 mirror의 권리를 포괄 승인하지 않는다. GarmentCode 코드 MIT는 참고 정보일 뿐 데이터 승인 근거로 대체하지 않았다. 모든 데이터의 creator·원본 DOI·라이선스·수정 사실은 DATASET_LICENSES/THIRD_PARTY_NOTICES와 review JSON에 있다.

새 가중치도 AI Hub 로컬 처리·국외 반출 제한과 원본 두 데이터셋의 attribution을 승계한다. `MODEL_ARTIFACTS.json`의 app/server 목록은 비어 있고 모든 운영 flag는 계속 false다. PyYAML은 MIT로 안전하게 파싱하며 GPL plyfile, Warp, 외부 body/texture 에셋은 사용하지 않는다.

## 재현 명령과 미완료 작업

저장소의 `ml/`에서 실행한다. 아래 변환 명령은 출력이 없는 새 환경용이며 기존 manifest·가중치를 덮어쓰지 않는다. Python은 `uv sync --locked --python 3.12`로 준비한다.

```sh
uv run python -m coordit_ml download-artf artifacts/artf-download
uv run python -m coordit_ml convert-artf artifacts/artf-download/aRTFClothes-resized-paper-splits.zip artifacts/artf-v1.1
uv run python -m coordit_ml prepare-artf-landmarks artifacts/artf-v1.1/records.jsonl artifacts/artf-landmarks-v1
uv run python -m coordit_ml download-garmentcode-sample artifacts/garmentcodedata-v2
uv run python -m coordit_ml render-garmentcode garmentcode-pilot.json
uv run python -m coordit_ml train config-seam-pilot.json
uv run python -m coordit_ml train config-seam-finetune.json
uv run python -m coordit_ml compare-seams compare-seam-finetune.json
uv run python -m coordit_ml evaluate artifacts/seam-integrated-finetune-v1 artifacts/aihub71501/approved-v1/records.jsonl --split train
uv run python -m coordit_ml validate artifacts/garmentcodedata-v2/body-free-pilot-v3/records.jsonl
uv run python -m coordit_ml audit-inventory reports/SOURCE_FILES.jsonl
uv run pytest -q
uv run ruff check coordit_ml tests
```

AI Hub 원본은 사용자 승인 계정의 로컬 사본을 이전 문서의 절차로 준비해야 한다. 부모 checkpoint는 자동 다운로드하지 않는다. 기존 파일이 있으면 그대로 보존하고 새 실행 이름을 사용한다. 비교 config의 hash는 이 환경의 실제 artifact에 고정되어 있으므로 새로 재현한 모델은 SHA를 다시 기록해 별도 config를 만든다. CUDA host에서는 별도 output과 `device: cuda`를 명시한다. 이번 실행에서 CUDA, ONNX/Core ML export와 새 모델의 iPhone/Android 추론은 테스트하지 않았다.

전체 GCD 자료 약 368GB를 저장할 여유가 없다(마지막 확인 시 호스트 여유 약 23GB). 전체 다운로드·전체 학습을 완료했다고 보고하지 않는다. 여러 배치로 확장하기 전에는 저장 공간과 source manifest를 확보하고, 새 독립 실제 봉제선·줄자 GT, category별 누락 점, flat-lay 도메인 검증이 필요하다. 현재 고정 prefix CLI는 작은 샘플용이며 전체 dataset downloader라고 주장하지 않는다. AI Hub 코트·재킷 봉제 주석, 목/소매/힙 등 누락점, 새로운 독립 사진 평가, 센서와 줄자 비교가 남아 있다.

## 검증 결과

이번 ML 자동 테스트 56개, Ruff, 새 전처리·주석·초기화·비교 모듈의 basedpyright 0 errors/0 warnings를 확인했다. 전체 basedpyright에는 기존 Torch/ONNX stub 경고 27개가 남아 exit 1이므로 전체 CI가 녹색이라고 표시하지 않는다. source inventory 16,323개와 loader hash/권한 검사를 수행했다. 렌더러의 한 실제 원본 샘플을 다시 생성해 픽셀 hash·마스크·주석 재현성을 확인했다.

새 checkpoint를 실제 로컬 FastAPI `/v1/landmarks`에 연결해 인증·동의가 있는 aRTF 사진으로 HTTP 200을 확인했다. 결과는 학습한 어깨/겨드랑이 4점만 반환하고, 필요한 나머지 점이 없으므로 `status: failed`, `reason: landmarks_missing_or_occluded`, `centimeter_values: {}`로 거절한다. 근거 없이 cm나 학습하지 않은 점을 채우지 않는다. 기록은 `ml/reports/seam-local-inference-smoke.json`이다. 실제 학습 사진의 publisher 좌표(초록)와 모델 출력(빨강) 겹침은 로컬 `ml/artifacts/seam-integrated-finetune-v1/real-training-overlay.png`에서 볼 수 있으며 독립 성능 증거는 아니다.

명칭 변경 후 백엔드 typecheck·`test:fit`·`test:report`를 통과했다. SimSlim list/on/verify/doctor 후 iOS UI 테스트에서 후드·반바지·스커트 선택→촬영 fixture→자동점→사진 포함 옷장 저장을 통과했다(`/tmp/coordit-seam-wording.xcresult`). 이 테스트는 센서나 새 신경망의 실제 정확도 검증이 아니다. Android는 표시명만 수정했고 이번에 빌드·실기기 시험은 하지 않았다. 기존 goofy 앱을 종료·재설치하지 않았다.
