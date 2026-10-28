# AI Hub 봉제점 로컬 검수

## v2 좌우·앞뒤 기준 수정 — 2026-10-28

기존 v1의 “화면 좌우” 정의는 aRTF publisher의 대칭 해소 규칙과 다르다. **v1 묶음을 검수 완료로 바꿔 새 학습에 넣지 않는다.** importer는 v1 완료 주석을 거부한다. 원래 v1 파일은 보존했다.

현재 로컬 묶음은 `ml/artifacts/aihub71501/seam-review-v2/`다. `training_review.html`에 코트 64장·재킷 64장, **128장/제안 512개**가 있다. 앞면 60장·뒷면 68장을 원본 파일명으로 구분한다. `blind_holdout_candidate.html`은 별도 앞면 2장이며 예측점은 없다. 검증된 AI Hub 봉제점은 여전히 **0개**다.

새 프로토콜은 `coordit-upper-seam-v2`다. 원본 픽셀 좌표의 bbox 왼쪽 아래 모서리에 더 가까운 **밑단 끝이 속한 의류 쪽**을 left로 정의하고, 반대쪽을 right로 정의한다. 각 어깨/겨드랑이 쌍을 따로 x순 정렬하지 않고 **옷 전체에서 같은 쪽**을 유지한다. 착용자의 해부학적 좌우라는 뜻도 아니다. aRTF의 공개된 상의 waist/hem 대칭 해소 규칙을 참고했다. 비교 평가의 기존 aRTF 정답은 수정하지 않았다.

검수자는 4개 봉제점 외에 `hem_reference_left`, `hem_reference_right` 두 기준점을 **직접** 추가한다. 옷 실제 밑단의 양 끝이 보일 때만 찍고 각각 verified/visibility 2로 설정한다. 이 두 점은 `side_reference` 검수 근거로 보관하며, 목 중심·총장·밑단 중심 등의 모델 정답으로 변환하지 않는다. importer가 원본 픽셀 단위의 코너 거리, 기준점 중복/반전, 원본 front/back과 검수 view의 일치를 검사한다. 기준점이 보이지 않거나 옷의 같은 쪽을 따라갈 수 없으면 완료 처리하지 않는다.

file attributes의 `view`와 `protocol`은 원래 task에 고정돼 있으므로 수정하지 않는다. `reviewer`, `evidence`, `review_complete`와 실제 확인한 region 속성만 작성한다. 새 import 설정은 `ml/import-aihub-via-v2.json`, blind 평가 예시는 `ml/evaluate-aihub-blind-v2.example.json`이다. 실제 VIA export를 지정한 다음 실행한다.

```sh
uv run python -m coordit_ml prepare-aihub-seam-review aihub-seam-review-v2.json
uv run python -m coordit_ml import-via-seam-reviews import-aihub-via-v2.json
```

현재 새 묶음은 이미 생성돼 있어 같은 output으로 준비 명령을 다시 실행하면 실패한다. 재생성은 config에 새 output을 지정한다. 학습/평가 export는 서로 다른 파일·output으로 import한다. 실제 사람이 검수하지 않은 초기 프로젝트는 import가 실패해야 정상이다.

**로컬 주석은 이미 허가돼 있다.** 현재 부족한 것은 외부 AI 허가를 다시 받는 일이 아니라, 실제 사람이 봉제선을 확인한 좌표와 측정 프로토콜 일치다. AI Hub 가슴 수치는 겨드랑이에서 1인치 아래의 폭×2, 어깨는 뒤쪽 측정이다. 앞면 겨드랑이 점 두 개의 거리와 원본 가슴둘레 숫자를 같은 cm 정답으로 연결하지 않는다. 검수 후 semantic 학습 범위를 등록할 때도 이 의미와 증거를 확인한다.

아래는 **과거 v1 묶음의 기록**이며 최신 작업은 위 v2 규칙을 따른다. 오프라인 도구의 기본 조작과 사진 외부 전송 금지 조건은 같다.

원본 사진을 외부 AI에 전송하지 않는 조건으로 준비했다. 사진은 로컬 JPEG로만 읽고 EXIF는 제거돼 있다. 온라인 annotation 사이트에 올리지 않는다. 봉제점이 보이지 않거나 위치가 모호하면 정답을 만들지 않는다.

## 현재 준비된 묶음

Finder에서 `ml/artifacts/aihub71501/seam-review-v1/` 폴더를 연다. 기존 사진, 주석 JSON, task SHA를 함께 보존한다.

- `training_review.html`: 코트 8장 + 재킷 8장, 사진별 어깨/겨드랑이 제안 4개. 총 64개는 **모델 예측·미검수**다.
- `blind_holdout_candidate.html`: 코트 1장 + 재킷 1장, **예측점 없이** 직접 주석. 기존 학습 manifest의 사진 SHA·의류 ID·유사 hash를 피한 작은 후보 묶음이다. 원저자 세션/동일 실물 의류까지 독립 인증된 최종 평가가 아니다.
- `annotation-tasks.jsonl`, `tasks.sha256`: 원래 학습/평가 용도와 사진 SHA를 고정한다. VIA에서 purpose를 바꿔도 import는 거부한다.
- `draft-seams.jsonl`: 검수 전 제안의 기록이다. 학습 정답으로 import되지 않는다.

VIA는 Oxford VGG의 기존 오프라인 도구다. 분석용 Google Analytics 스크립트를 제거했고 HTML CSP로 네트워크·외부 이미지·폼 전송을 차단했다. 원문은 실행되지 않는 `upstream-via-2.0.12.source.txt`로 보관한다. 수정한 HTML을 사용한다.

**검증 범위:** 공개 합성 fixture에서 HTML 내 JavaScript 문법, project bootstrap, analytics 제거, CSP를 정적으로 확인했다. import·SHA·split 차단 자동 테스트도 통과했다. Codex 브라우저의 `file://` 접근은 자동 보안 검토에서 거절되어 실제 화면 클릭/드래그 QA는 수행하지 못했다. HTTP 서버나 다른 브라우저 자동화로 우회하지 않았다. 사용자는 파일을 직접 열어 화면과 저장 동작을 확인해야 한다. 실제 AI Hub 사진을 원격 화면 검수에 보내지 않았다.

## 점의 정의

이번 프로토콜은 `coordit-upper-seam-v1`이다. **좌우는 화면에서 보이는 좌우**이며 사진은 upright RGB다. 점은 의류 바깥 윤곽 끝이 아니다.

| 키 | 확인할 실제 위치 |
| --- | --- |
| `shoulder_left`, `shoulder_right` | 몸판의 어깨 봉제선과 소매 달림 봉제선이 만나는 화면 좌/우 지점 |
| `armpit_left`, `armpit_right` | 몸판 옆 봉제선과 소매 아래 봉제선이 만나는 화면 좌/우 지점 |

드롭숄더는 실제 봉제선을 따른다. 라글란·특이 패턴처럼 이 정의의 교차점을 특정할 수 없으면 그 점을 제외한다. 후드/옷깃, 접힌 팔, 가려짐 때문에 추정해야 하는 점도 제외한다. 겨드랑이 주름의 끝이나 마스크 폭의 극점을 대신 찍지 않는다. 목 중심·소매 끝·밑단·cm 치수는 이 묶음에서 추가하지 않는다. 줄자 정답과 좌표 정답은 별도다.

## 검수·저장

1. HTML을 로컬 브라우저에서 연다. 파일 목록에서 사진을 선택한다. 사진이 안 보이면 `images/`와 HTML이 같은 묶음인지 확인하고 VIA의 로컬 파일 추가/경로 설정으로 같은 사진을 선택한다. 원격 URL로 바꾸지 않는다.
2. 학습용은 제안점을 선택해 실제 봉제 교차점으로 옮긴다. blind용은 Point 도구로 직접 찍는다. 모호한 점은 삭제한다. 사진 전체가 불확실하면 `review_complete`를 `no`로 둔다.
3. 각 보이는 점의 region attributes에 올바른 `landmark_type`, `visibility: 2`, `review_status: verified`를 지정한다. 검수하지 않은 제안은 그대로 verified로 일괄 변경하지 않는다. 숨겨진/제외할 점은 삭제해 이 visible-only import에서 제외한다.
4. file attributes의 `reviewer`에 실제 검수자, `evidence`에 확인한 봉제선 근거를 적는다. 예: “어깨 봉제선과 소매 달림 봉제선 교차가 원본 확대에서 보임”. `protocol`은 그대로 두고 확인 완료 사진에만 `review_complete: yes`를 쓴다. identity/hash/purpose/category는 바꾸지 않는다.
5. **Project → Save**로 전체 VIA project JSON을 로컬 저장한다. CSV/이미지 캡처 대신 `_via_img_metadata`가 있는 project JSON이 필요하다. 원래 HTML과 원본 JSON을 덮어쓰지 않는다.

## import와 평가

`ml/`에서 `import-via-seam-reviews`의 config를 작성한다. `tasks_sha256`은 `tasks.sha256`의 실제 값을 복사한다. 아래 각괄호는 자리표시자이므로 실제 로컬 경로/해시로 바꿔야 한다.

현재 묶음용 `ml/import-aihub-via.json`에는 실제 task SHA가 미리 들어 있다. 이 파일이 지정하는 `human-reviewed-project.json` 위치에 직접 저장한 VIA export를 넣어야 한다. 학습용과 blind용을 따로 export한 경우 각각 다른 project 경로와 output 이름으로 import한다.

```json
{
  "tasks": "artifacts/aihub71501/seam-review-v1/annotation-tasks.jsonl",
  "tasks_sha256": "<tasks.sha256의 값>",
  "project": "<로컬에 저장한 VIA project.json 경로>",
  "output": "artifacts/aihub71501/human-reviewed-v1"
}
```

```sh
uv run python -m coordit_ml import-via-seam-reviews import-via-local.json
```

검수 완료 자료만 용도별 `training_review.jsonl` / `blind_holdout_candidate.jsonl`로 분리한다. 사진 SHA·파일 크기·경로·용도·검수자를 검사한다. 검수점이 없으면 성공 처리하지 않는다. 아직 실제 사람이 검수한 AI Hub 점은 **0개**, AI Hub 봉제점 PCK/NME는 **계산 불가**다.

학습용은 기존 `import-seam-reviews`로 승인 manifest에 병합할 수 있지만 현재 AI Hub `semantic_keypoints` 권리/품질 검토가 끝나지 않아 registry gate가 차단한다. 검수 없이 annotation_types를 추가하거나 draft를 verified로 치환해서 통과시키지 않는다. blind 사진은 원본 training manifest에 없으며 별도 미등록 source ID여서 학습 import가 거부한다.

blind 평가 CLI `evaluate-aihub-blind`는 `BlindEvaluation` schema를 쓴다. config의 `tasks/tasks_sha256`, `reviews/reviews_sha256`, 과거 `history`(기존 `aihub-seam-review.json` 목록), `baseline`, `candidate`, `output`을 고정한다. 모델 pin 형식은 `compare-artf-unseen-diverse.json`과 같다. reviews에는 **blind 파일만** 지정한다. 평가 직전에 두 모델의 실제 학습 manifest까지 다시 대조하며 겹치거나 검수점이 없으면 지표 파일을 생성하지 않는다. 정확도는 작은 사진별 좌표 평가이며 cm 측정 정확도로 표시하지 않는다.

`ml/evaluate-aihub-blind.example.json`에는 기존/새 모델 pin과 history가 들어 있다. 사람 검수 후 생긴 blind JSONL의 실제 경로와 SHA를 넣어 별도 config로 저장한다. `REQUIRED_SHA256_AFTER_HUMAN_REVIEW`는 미완료를 표시하는 자리표시자이며 평가 결과가 아니다.

```sh
uv run python -m coordit_ml evaluate-aihub-blind evaluate-aihub-blind-local.json
```

새 묶음을 만들려면 `aihub-seam-review.json`에서 새 output 이름을 정하고 다음을 실행한다. 기존 데이터·checkpoint는 변경하지 않는다.

```sh
uv run python -m coordit_ml prepare-aihub-seam-review aihub-seam-review.json
```

VIA source download만 공식 Oxford 서버로 나간다. 사진/라벨 전송은 없다. 버전 SHA가 바뀌면 도구 다운로드가 실패하며 검토 전 다른 버전을 자동으로 수용하지 않는다.
