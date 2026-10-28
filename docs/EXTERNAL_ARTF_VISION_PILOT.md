# 공개 aRTF 외부 시각 AI 파일럿 — 2026-10-28

## 실행 범위

사용자가 외부 전송을 허용한 **공개 aRTF 사진만** 사용했다. AI Hub 사진은 전송하지 않았다. Phase 3, 운영 flag, 앱·백엔드·DB·결제·기존 가중치는 변경하지 않았다. 학습도 실행하지 않았다.

별도 Vision API key가 현재 환경/프로젝트 설정에 없어, **현재 Codex 채팅의 시각 AI가 원본을 보고 좌표를 제안하는 interactive 파일럿**으로 실행했다. 외부 업체 API를 별도로 호출해 원시 응답을 자동 수집한 시험이 아니다. 정확한 모델 revision은 확인할 수 없으며, 같은 API 모델을 고정해 재현 가능한 배치 시험이라고 주장하지 않는다. agent가 사진을 해석하고 좌표를 구조화해 저장했다. 별도 API 모델/유료 Weave 실행은 하지 않았다.

모델별 입력은 이전 CNN 128×128, 최신 CNN 256×256, 시각 AI 원본 512×256이다. 각 기존 모델의 실제 전처리를 그대로 사용한 제안 품질 비교이며 해상도만을 통제한 ablation은 아니다. 시각 AI의 API 속도·비용·자동 배치 실행은 평가하지 않았다. AI Hub나 다른 9개 의류 카테고리의 성능으로 일반화하지 않는다.

## 사진·좌표 고정

학습에 쓰지 않은 기존 aRTF 평가 풀에서 티셔츠 4장·반바지 4장, 총 **8장**을 hash 기반으로 고정했다(seed 20261028). 이전에 확인한 초기 사진을 피하려고 카테고리별 처음 32개를 먼저 제외했다. 정답 가시성·자세·모델 오차로 사진을 고르거나 교체하지 않았다. 기존 모델 두 개의 모든 학습 manifest와 사진 SHA/의류 ID/유사 hash도 대조했다.

시각 AI에는 512×256 **원본 사진**, 카테고리, 좌표 규칙만 제공했다. 정답 좌표·정답 overlay·기존 모델 출력은 주지 않았다. 저대비·무늬·접힘으로 모호한 점은 uncertain 또는 abstain으로 남겼다. P02 사진은 네 점 모두 기권했다. 모든 제안을 한 번 저장하고 SHA를 고정한 다음 정답 채점을 실행했으며, 점수를 본 뒤 좌표를 수정하지 않았다.

- packet SHA: `67e41b8192e00bfbf6dc08c1d26e65b285026117d7499d3e8bd01169a62d8e08`
- 제안 SHA: `56c505738a465e2f2b80972aa39cc3e14da304f7863befcc3f4a21c81a4e5b93`
- 원본 입력 명세: `ml/reports/EXTERNAL_ARTF_VISION_PACKET.json`
- 실제 제안: `ml/reports/EXTERNAL_ARTF_VISION_PROPOSALS.json`
- 사전 규칙: `ml/protocols/external-artf-vision-v1.md`

이는 정답을 입력하지 않은 자기보고 절차다. 같은 agent가 준비·추정·채점 코드를 다루므로 별도 관찰자가 통제한 독립 블라인드 시험은 아니다. 공개 모델의 사전학습에 이 사진이 들어갔는지도 확인할 수 없다.

## 같은 사진·같은 점의 PCK와 NME

세 참여자 모두 상의 어깨·겨드랑이 4점, 반바지 허리 좌우·가랑이·해당 다리 외측 밑단 4점을 대상으로 했다. 중복 `side_waist` alias는 모두 제외했다. 따라서 기존 561장 전체 보고서와 target 수가 다르며 그 숫자와 직접 비교하지 않는다. 기존 모델은 예측 confidence/visibility로 실패 점을 빼지 않았다. 외부 AI도 uncertain 좌표를 그대로 채점했다.

총 32개 요청 중 원저자가 visible로 표시한 정답은 **30개**다. 외부 AI는 그중 27개에 좌표를 주고 3개에 기권했다. 기권한 가시점도 PCK 실패다. PCK@0.05/NME는 이전과 같은 **정규화 정사각 입력 대각선** 기준이다.

| 참여자 | PCK — 전체 가시 정답 | 좌표 응답률 | NME — 응답한 점만 | 기권 벌점 NME |
| --- | ---: | ---: | ---: | ---: |
| 기존 다양한 사진 60epoch 모델 | 16.67% (5/30) | 100% | 0.15956 | 0.15956 |
| 기존 최신 거리손실 모델 | 13.33% (4/30) | 100% | 0.13689 | 0.13689 |
| 이 채팅 시각 AI 제안 | **83.33% (25/30)** | **90% (27/30)** | **0.01924** | **0.11731** |

응답점만의 NME는 서로 다른 27점/30점에 대한 조건부 값이다. 기권 벌점 NME는 누락 가시점마다 정규화 좌표 상자에서 가능한 최대 오차 **1**을 부여한 보수적 보조 지표다. 표준 NME에 없는 누락점 좌표를 실제로 측정했다는 뜻도, 통계적 신뢰구간도 아니다. 기권을 숨긴 조건부 PCK 25/27을 전체 정확도로 제시하지 않는다.

카테고리별 PCK는 시각 AI 티셔츠 **66.67% (10/15)**, 반바지 **100% (15/15)**다. 기존 60epoch는 각각 13.33%/20%, 최신 거리손실은 20%/6.67%였다. **반바지 4장·15점의 100%를 실제 서비스 정확도 100%라고 해석하지 않는다.**

## 길이 오차 — cm가 아니라 원본 사진의 2D 투영 길이

원본 512×256 픽셀로 복원해 두 점 간 길이를 계산했다. 시각 AI가 두 점 모두 제안한 **같은 사진 쌍**으로 각 모델을 다시 맞춰 비교했다. 원래 전체 결과에는 기권 실패를 별도로 남겼으며, 가슴은 전체 4쌍 중 1쌍에 시각 AI가 기권했다. 아래 가슴 값은 나머지 공통 3쌍이다.

| 부위 / 공통 쌍 수 | 60epoch 평균 상대오차 | 최신 거리손실 모델 | 시각 AI 제안 |
| --- | ---: | ---: | ---: |
| 어깨 / 3 | 39.14% | 37.07% | **9.11%** |
| 겨드랑이 사이 / 3 | 37.26% | 23.55% | **9.62%** |
| 반바지 허리 / 4 | 38.11% | 37.03% | **3.36%** |

시각 AI의 같은 공통 쌍 평균 절대 픽셀 오차는 어깨 9.35px, 겨드랑이 사이 10.27px, 허리 3.03px다. 원문 JSON에는 원래 전체 eligible/supplied/failed pair 수와 공통 쌍 결과를 모두 보존했다. 기권한 가슴 쌍을 성공으로 세거나 오차 0으로 처리하지 않았다.

이 파일럿에서는 시각 AI 제안이 작은 로컬 모델보다 좋은 초기 좌표를 줬다. 다만 **정밀 봉제점 정답 확정·90% 출시 정확도·실제 cm 정확도를 입증하지 않는다.** aRTF 주석은 해부학적 후보점이며 봉제선 측정 프로토콜로 인증된 정답이 아니다. 기존 16장 휴리스틱 개발과 같은 publisher 계열이고 실물 의류/촬영 세션의 완전한 독립성도 인증하지 못했다. 8장/30점은 결과 일반화에 부족하다.

## 재현과 차단 장치

`ml/`에서 실행한다. 승인 데이터와 고정 baseline checkpoint가 있어야 한다. 준비 출력이 이미 있으면 실패하며, 비교 출력이 있으면 새 output을 지정해야 한다.

```sh
uv run python -m coordit_ml prepare-external-pilot external-artf-pilot.json
# 새 환경: 같은 packet을 재생성한 뒤 고정 제안을 로컬 packet 폴더에 복사한다.
cp reports/EXTERNAL_ARTF_VISION_PROPOSALS.json artifacts/external-artf-vision-pilot-v1/external-proposals.json
uv run python -m coordit_ml compare-external-pilot compare-external-artf-pilot.json
uv run pytest -q
uv run ruff check coordit_ml tests
uv run basedpyright
```

준비 단계는 source ID·원본 라이선스·test 경로를 검사해 AI Hub/다른 데이터셋을 거부한다. 원래 publisher test adapter와 원본 SHA 검사를 우회하지 않는다. 응답/packet/protocol hash가 바뀌면 채점을 차단한다. 고정 제안의 **채점 재현**은 가능하지만, 정확한 모델 revision/API raw response가 없는 이번 시각 추정을 새 모델 호출로 똑같이 재현할 수 있다고 주장하지 않는다.

공식 지표는 `ml/reports/EXTERNAL_ARTF_VISION_PILOT.json`이다. 고정 원문과 최신 채점 코드를 별도 output으로 재실행해 전체 결과의 일치도 확인한다. 외부 제안은 `verified` 정답으로 승격하지 않았고 학습에 넣지 않았다. source manifest/weights도 수정하지 않았다. 이 작업의 다음 판단은 더 큰 별도 검수 표본에서 제안 품질과 검수 절약량을 확인하는 것이며, AI Hub 외부 전송은 이번 범위에 없다.

실제 CLI 재실행의 전체 결과는 원문 보고서와 같았다. mapped keypoints 대신 원저자 source_keypoints에서 별도로 계산해도 **30개 가시점·25개 PCK 성공·3개 기권**이 일치했다. ML 자동 테스트 83개와 Ruff를 통과했다. 새 모듈 typecheck는 0 errors/0 warnings, 전체는 기존 Torch/ONNX stub 27 warnings 때문에 exit1(0 errors)이다. 실행 방식·검증 기록은 `ml/reports/EXTERNAL_ARTF_VISION_EXECUTION.json`에 있다.

출처: Thomas Lips, Victor-Louis De Gusseme, Francis wyffels, Ghent University, [aRTF Clothes 원본](https://zenodo.org/records/14501499), [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). 원본 사진은 Git에 추가하지 않았다. 공개 평가 이미지 선택·제안·채점은 Coordit의 파생 평가 작업이며 저자의 보증/승인을 뜻하지 않는다.
