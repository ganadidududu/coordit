# Astra / Gemini 봉제점 + 촬영 시점 AR 평면 시험

2026-10-28. Phase 2 개발 전용. Phase 3, 운영 플래그, 결제·저장 API, 기존 카드/LiDAR 경로는 변경하지 않는다.

## 구현 범위와 계산 기준

`Coordit AR Test`의 카드 없는 AR 촬영 후 `Astra / Gemini 봉제점 · AR cm`로 진입한다. Astra(`openai/gpt-6-astra`), Gemini 3.8 Flash(`google/gemini-3.8-flash`)를 선택한다. 별도 인증 개발 게이트웨이 → OpenRouter → 선택 제공업체로 의류 픽셀만 전송한다. 모델은 정규화된 2D 봉제점만 반환한다. **cm는 AI 응답에서 읽지 않고**, 해당 사진을 촬영할 때 고정한 프레임 ID·내부 파라미터·카메라 포즈·AR 평면 경계로 두 광선을 교차시켜 휴대폰에서 계산한다. 네트워크 대기 중 카메라가 움직여도 새 포즈와 섞지 않는다.

11종의 기존 부위 스키마를 유지하며 스커트에는 밑위를 만들지 않는다. 어깨는 소매 부착 봉제선, 가슴은 겨드랑이 단면, 상의 총장은 기존 화면에서 선택한 기준(`high_shoulder_to_hem` 또는 `back_neck_to_hem`)을 요청·응답·내보내기에 고정한다. 어깨 기준은 **왼쪽 어깨–목 접점에서 옷 세로 방향을 따라 내려간 밑단**이며 밑단 중앙으로 대각선을 재지 않는다. 기존 키 `hem_center`는 이 API에서 총장 기준에 맞는 밑단 끝점을 뜻한다. 뒷목 기준은 보이는 뒷목 중심부터 밑단 중심이고 가려진 뒷목을 추측하지 않는다. 소매는 오른쪽 어깨부터 커프 중심이다. 줄자도 같은 두 끝점의 **직선 거리**로 비교해야 한다. 곡선 봉제선 길이·둘레와 비교하면 안 된다. 엉덩이 측정선 등 확인하기 어려운 점은 모델이 abstain하도록 요청한다.

`visible_proposal`도 독립 검증된 정답이라는 뜻은 아니다. 2026-10-29부터는 불확실한 좌표도 **주황색 AI 초안과 초안 cm**로 먼저 보여준다. 사용자는 맞는 점을 움직일 필요 없이 `표시된 점 확인했어요`로 확인하거나, 드래그/사진 터치/백분율 입력으로 수정한다. 확인만 한 점은 `user_confirmed`, 옮긴 점은 `user_corrected`로 구분한다. 양 끝점을 모두 확인/수정해야 그 부위가 사용자 확인 결과가 된다. 누락·평면 밖·비현실적 치수는 초안에서도 cm를 만들지 않는다. 원래 응답과 수정 응답은 분리한다. 이 화면은 기존 캡처의 측정값을 덮어쓰거나 옷장·결제·핏 분석을 호출하지 않는다. 내보내지 않은 결과가 있으면 닫기에서 삭제 확인을 띄우고 실수로 쓸어내려 닫는 동작을 막는다. JSON 저장 성공 후에는 바로 닫을 수 있다. 닫으면 기존 화면으로 돌아간다.

Layout: NavigationStack 안의 단일 세로 ScrollView, 모델/보정 선택 → 고정 사진 → 좌표 수정/점 확인 → 부분별 초안/확인 cm → 명시적 전송 동의/추론. 사진에서 점 보정은 별도 토글을 켰을 때만 동작해 스크롤이 좌표를 바꾸지 않는다. 번호나 색만으로 점을 구분하지 않고 한글 기준점 선택과 접근성 이름·상태를 제공한다. 1차 목표는 사용자가 빠르게 보정할 수 있는 초안이다. 재추론은 유료이므로 확인/수정 동작에서는 API를 호출하지 않는다. 웹/데스크톱 레이아웃은 범위 밖이다.

## 사용자 시험 순서

1. 얇은 티셔츠를 펼쳐 같은 기준으로 줄자 정답을 먼저 두 번 잰다. 상단 `시험 정보 입력`에 의류 ID·부위별 정답을 입력한다.
2. `카드 없이 AR`에서 옷 주변 바닥까지 비추며 휴대폰 위치를 좌우로 움직인다. 촬영 준비 안내가 되면 고정하고 촬영한다. 옷 인식 성공은 AR 촬영 버튼의 필수 조건이 아니다.
3. `Astra / Gemini 봉제점 · AR cm`를 누른다. 외부 전송 목적을 읽고 동의한 경우에만 추론 버튼이 활성화된다.
4. 예산이 허용될 때만 선택 모델을 1회 실행하고 **확인/수정 전에 JSON을 내보낸다.** 주황점과 초안 cm를 살펴본다. 이 값은 사용자 확인 전이며, 빠진 점·평면 밖에는 수치가 없어야 한다. 현재 예산 절약 지시가 유지되는 동안 개발자의 추가 API 호출은 하지 않는다.
5. 점이 틀리면 기준점을 선택하고 `사진에서 점 보정`을 켜서 드래그·터치·백분율 입력으로 고친다. 빠진 점은 메뉴로 선택한 후 직접 배치한다. 맞는 점은 움직이지 않고 `표시된 점 확인했어요`를 누르면 된다. 확인 버튼은 좌표를 바꾸거나 누락점을 채우지 않는다. 끝나면 보정을 끄고 JSON을 다시 내보낸다.
6. **동일한 촬영 사진**에서 Gemini로 바꾸어 같은 순서로 시험한다. 수동 보정은 현재 모델 결과에만 적용되며 모델 재호출은 추가 과금된다. 재호출 실패 시 기존 결과를 보존한다.
7. 처음에는 같은 티셔츠를 새로 촬영하여 3회 반복한다. 수동 보정 뒤에도 줄자와 차이가 크면 AR 스케일·평면 높이·기울기를 의심한다. 두꺼운 옷, 다른 카테고리, 다른 기기는 따로 늘린다.

내보내기는 메모리에 보관된 응답을 JSON 파일로 저장한다. 종료 전에 내보내야 한다. 이 전용 JSON은 `purpose=hosted_ar_development_not_training`, 촬영 증거, 변경 전 모든 모델 응답(`original_inferences`), 현재 수정 응답, 부위별 cm·입력한 줄자 정답·3D 선분·실패 사유를 포함하며 사진·토큰은 포함하지 않는다. **기존 `field-report` 수집 스키마와 별도이며 그 CLI에 바로 넣지 않는다.** 동일 프레임의 모델 간 원본점은 보존되지만 각 모델의 수정 결과도 비교하려면 모델을 바꾸기 전에 각각 내보낸다. 시뮬레이터 fixture는 `synthetic=true`로 표시한다.

## 연결과 개인정보

내보내기에는 `review_status`(`draft`, `user_reviewed`, `failed`), 부위 양 끝점 이름 `landmark_types`, 확인 전 `draft_centimeters`를 추가했다. 확인 전에는 기존 `centimeters`/`segment`에 확정값을 넣지 않는다. 양 끝점 확인 후에만 그 필드를 채우며 실패 시에는 비워둔다. 원본 모델 상태와 좌표는 `original_inferences`에 보존하고, 확인만 한 점을 직접 이동한 점으로 기록하지 않는다. 사용자 확인은 실제 cm 정확도 검증이나 학습 동의가 아니다.

**설치 후 USB는 필요 없지만 이번 외부 AI 시험은 Mac 개발 서버·터널·인터넷이 켜져 있어야 한다.** 기존 로컬 AR/수동 측정은 계속 휴대폰 단독으로 가능하다. 이번 변경은 상시 원격 서버 배포가 아니다. Cloudflare Quick Tunnel은 임시 HTTPS 주소이며 재시작으로 주소가 바뀌면 앱을 새 설정으로 재빌드해야 한다. [Cloudflare 공식 안내](https://developers.cloudflare.com/tunnel/get-started/quick-tunnels/).

OpenRouter 키는 Git에서 제외된 `ml/.env`의 `OPENROUTER_API_KEY`(기존 `OPENAI_API_KEY`도 호환)에만 둔다. 앱에는 공급자 키를 넣지 않는다. 별도 무작위 개발 게이트웨이 토큰만 임시 시험 앱 Info.plist에 넣는다. 이 토큰은 시험용 접근권한이며 앱/임시 프로젝트/connection.json을 공개하지 않는다. 게이트웨이는 기본 비활성·인증 필수·동시 추론 1개·프로세스당 최대 60회 시도·자동 유료 재시도 없음이다. 개발 게이트웨이는 운영 멀티 사용자 인증·과금 시스템이 아니다.

원본에서 위치 EXIF 등을 제거하고 축소된 upright RGB 픽셀을 HTTPS로 보낸다. 서버는 사진/좌표를 파일에 저장하지 않고 access log를 끈다. 공개 aRTF 스모크 출력은 개발자가 별도로 저장한 좌표 JSON이며 원본 사진 로그가 아니다. 제공업체 요청에 `data_collection=deny`, `zdr=true`, fallback 금지, 지원 매개변수 필수를 적용한다. [OpenRouter 공식 정책](https://openrouter.ai/blog/insights/zero-data-retention/)에서 ZDR은 제공업체 정책이고 메모리 캐싱은 별도라는 점을 설명한다. 이는 자체 법적 승인이나 국내 처리 보장이 아니다. **AI Hub 사진은 보내지 않는다.** 앱에는 라이브 AR 캡처만 이 경로로 연결한다. 사진·수정점 자동 학습은 없다.

## 재현 명령

저장소 루트에서 실행한다. 필요한 Python 의존성은 `ml/uv.lock`에 고정돼 있다. 키 값을 명령행·채팅에 붙이지 않는다.

```sh
uv sync --directory ml
# cloudflared가 설치되어 있고, ml/.env에 유효한 OpenRouter 키가 있어야 한다.
# 이 터미널을 유지한다. Ctrl-C로 이 스크립트가 띄운 서버/터널만 종료한다.
scripts/run-hosted-ar-gateway.sh
```

별도 터미널에서 폰을 연결하고 잠금을 푼다. 출력된 private connection 파일 경로를 지정한다.

```sh
COORDIT_HOSTED_AR_CONNECTION_FILE="$PWD/ml/artifacts/hosted-ar/connection.json" \
  scripts/run-ar-field-test-ios.sh <TEAM_ID> <DEVICE_UDID>
```

연결 없이 서명 빌드까지만 할 때:

```sh
COORDIT_HOSTED_AR_CONNECTION_FILE="$PWD/ml/artifacts/hosted-ar/connection.json" \
COORDIT_AR_FIELD_BUILD_ONLY=1 COORDIT_AR_FIELD_DESTINATION='generic/platform=iOS' \
  scripts/run-ar-field-test-ios.sh <TEAM_ID> <DEVICE_UDID>
```

서버 단위 테스트는 외부 유료 호출 없이 수행한다.

```sh
uv run --directory ml pytest -q
uv run --directory ml ruff check coordit_ml tests
uv run --directory ml basedpyright
```

iOS 시뮬레이터는 먼저 AGENTS.md의 SimSlim list/on/verify/doctor를 수행한다. 그 다음 `xcodebuild build-for-testing`에 `CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-`를 사용한다. 키체인 회귀 테스트는 unsigned host에서 접근 오류가 생긴다. 실제 센서는 시뮬레이터로 검증하지 않는다. UI fixture launch args는 `--coordit-ar-field-test --coordit-hosted-ar-fixture --coordit-ui-testing`이며 시뮬레이터 전용이고 API를 호출하지 않는다.

## 2026-10-28 검증 기록

- 공개 aRTF P01 한 장을 HTTPS 개발 게이트웨이에서 실제 호출: Astra 200/11.94초/$0.02708, Gemini 200/4.82초/$0.002292. 인증 없는 요청은 401, 프레임 ID 반환 일치. 새로운 전체 부위 프롬프트에서 Astra 가시점 2/8·불확실 6/8, Gemini 가시점 8/8. **가시점 개수는 정답률이 아니다.** 이 실행은 원래 8장 벤치마크와 다른 프롬프트이므로 PCK를 그대로 옮겨 붙이지 않는다.
- 총장 기준 보완 후 같은 공개 P01에 제공업체 API 재호출: Astra 12.65초/$0.02717(가시점 2), Gemini 4.89초/$0.00237675(가시점 8). 프레임과 `length_basis` 반환 일치를 확인했다. 이 재호출은 제공업체 HTTPS 경로의 의미적 스모크이며 센서 cm 검증이 아니다.
- 기존 비교 점수는 [8장 모델 벤치마크](ARTF_OPENROUTER_MODEL_BENCHMARK.md) 참조. 이 통합 경로의 실제 cm MAE/P95는 아직 미검증이다. 운영 활성화 금지 상태를 유지한다.
- Python 108개 테스트 통과, Ruff 통과, 타입 오류 0/기존 경고 28. 신규 게이트웨이 모듈 타입 오류·경고 0.
- iOS signed 시뮬레이터 단위 72개 통과(기존 카드·사진·게스트 회복 포함). 최초 unsigned 실행의 키체인 15개 실패는 signed host로 재실행해 모두 통과했다.
- 별도 iPhone 시험 앱 Debug 서명 빌드 성공. 실기기 센서 측정/실제 줄자 비교는 사용자의 후속 시험이 필요하다. goofy 설치 성공 후 개발자 신뢰 재확인이 필요했고, 사용자가 신뢰 완료 및 시험 화면 진입을 확인했다. 프로필 만료는 2026-11-03 17:30:14 KST다.

최종 추가 검증: `fixed-light.xcresult`, `fixed-dark.xcresult`의 hosted UI 각 2개 통과. 큰 글자 Menu 라벨·고대비 고지·저장 전 닫기 경고·보정 드래그·동의 차단·Files 실제 저장·맨 아래 큰 글자 고지를 확인했다. 새 전용 JSON을 실제 Files에 저장한 뒤 다시 파싱해 원본 응답·총장 기준·불확실 부위 null·합성 40/60cm 값 보존을 확인했다. 이는 센서 정확도 검증이 아니다. 기존 시험 수집 UI 2개도 통과했으며 백엔드 typecheck·camera-comparison·report 회귀 명령이 모두 종료 코드 0이었다.

도구 설치 기록: cloudflared 설치 중 Homebrew 자동 정리가 Python 3.14.6을 제거하여 Python 3.14.10으로 복구했다. 프로젝트의 uv Python 3.12 환경은 그대로 사용했고 ML 검사도 통과했다. 이후 Homebrew 작업에서는 자동 정리를 비활성화했다.

최종 독립 검수는 기능/개인정보·고정 AR/저장 전 종료 경고와 시각 A–F 검수 모두 PASS다. 최종 16개 light/dark 캡처는 Git에서 제외된 `ml/artifacts/hosted-ar/ui/final/manifest.json`에 있다. 별도 앱의 AR·모델 연동/총장 기준 보완판은 goofy에 설치했다. 이후 URLSession을 화면 갱신마다 생성하지 않고 한 번 재사용하도록 수정한 최종 바이너리는 서명 빌드·전송 단위 테스트를 통과했으나, 폰 설치기가 추가 48,034,566 bytes 공간 부족을 반환했다. 사용자가 공간을 확보한 뒤 최종 바이너리를 재설치했고 `devicectl`에서 설치와 자동 실행 성공을 확인했다. 기존 앱이나 사진을 임의로 삭제하지 않았다.

## 2026-10-29 초안 우선·사용자 보정 변경 검증

기존 `codex/camera-auto-guides`에서 진행했다. 추가 유료 API 호출 0회, 가중치/프롬프트/학습 데이터 변경 0건, Phase 3 변경 0건이다. 공급자 응답을 더 정확하게 만들었다고 주장하지 않는다. 기존 좌표를 초안으로 보여주고 사용자가 수치 계산 기준점을 빠르게 확인/수정하게 한 변경이다. 서버/Android/운영 플래그/결제·옷장 API는 수정하지 않았다. 이번 버전은 시뮬레이터에 빌드·실행했으며 goofy에 재설치하지 않았다.

SimSlim list → profile on → verify와 push/StoreKit/links/keychain/photos doctor 5/5를 수행했다. 증거 루트는 `/tmp/coordit-landmark-draft-review/`다.

주요 원본/변경 후 UI 첨부, 최종 라이트·다크 상단/본문 PNG와 검사한 초안 JSON 사본은 Git 제외 경로 `ml/artifacts/hosted-ar/draft-review-20261029/`에도 보관했다. 이 폴더에는 합성 UI fixture만 있으며 키·실제 사용자 사진은 없다.

- 변경 전 hosted 화면 시험 1개 통과: `before.xcresult`.
- 변경 후 signed 시뮬레이터 단위 **75개 + UI 4개 통과**: `after-light.xcresult`. UI는 이동 없는 초안 확인, 드래그/동의 차단, 누락점 직접 배치, 큰 글자/실제 Files 내보내기를 실행했다. 단위에는 기존 카드·LiDAR/AR 기하·카테고리/스커트·사진 보관·분석 재시도·게스트/키체인 회귀가 포함된다.
- 확인 버튼 터치 영역을 보완한 빌드에서 UI **4/4 다크 모드 통과**(`after-dark.xcresult`), 같은 빌드의 라이트 모드 **4/4 통과**(`final-light.xcresult`). UI 자동화의 테스트 빌드는 유료 호출 설정이 없으며 동의 후에도 추론이 비활성임을 확인했다.
- 실제 Files에 저장된 합성 fixture JSON을 다시 읽어 네 부위 모두 `review_status=draft`, `draft_centimeters` 40/40/60/21.21, 확정 `centimeters`/`segment` 미기록, 원본 모델 상태/프레임 보존을 검사했다(`verified-draft-export.json`). 이 값들은 작성된 기하 fixture이며 센서 정확도 결과가 아니다.
- 다크 모드 선택점이 다른 점과 같은 흰 테두리가 되는 것을 발견해 기존 검은 선택 테두리를 복원했다. 최종 빌드·실행에 성공했고 현재 빌드의 상단/초안 치수·확인 버튼/아래 고지를 라이트·다크 모두 직접 캡처했다(`final-live-{light,dark}-{top,body}.png`). 선택점 복원 후 전체 UI 자동화를 다시 반복한 것으로 보고하지 않는다. 모델/기하/보정 로직은 앞서 통과한 빌드와 같다.
- 자체 시각 검수: 한 개 세로 ScrollView, 기존 NavigationStack/메뉴/토글/좌표 입력 유지, 주황 초안·초록 사용자 확인 상태의 텍스트 대안, 44pt 이상 확인 버튼, 큰 글자 스크롤/닫기/내보내기, 명시적 외부 전송 동의와 비활성 버튼을 확인했다. 웹/데스크톱·AR 센서·실제 봉제점 정확도는 대상이 아니다. 새 독립 리뷰어 검수는 실행하지 않았다.

캡처 도구 제한: 최초 `before-dark-top.png`는 테마 전환 중이라 유효한 다크 기준 화면으로 사용하지 않았다. 일부 XCTest 다크 캡처에는 글자가 누락된 합성 프레임이 있어 실제 UI의 최종 상단/본문을 다시 캡처해 확인했다. 재실행 뒤 XcodeBuildMCP의 의미 UI snapshot이 루트 1개만 반환하는 경우가 있었으나 실제 스크린샷은 정상이고 XCTest UI 시나리오는 통과했다. 이 도구 문제를 제품 성공이나 센서 검증으로 대신하지 않는다. 최종 빌드의 참고 경고 3개는 기존 capture controller의 actor 초기화/ARPlaneAnchor.extent 사용이며 이번 변경에서 발생한 컴파일 오류는 없다.
