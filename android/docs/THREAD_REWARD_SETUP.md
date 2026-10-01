# Android 실타래 보상광고 설정

Android는 `/thread-wallet/reward-attempts`로 서버 발급 UUID를 먼저 받고, 이를 AdMob SSV `custom_data`에 넣는다. 광고 SDK의 보상 콜백은 충전 성공으로 취급하지 않는다. `/webhooks/admob/rewarded`가 Google 서명을 검증해 잔액을 반영한 뒤에만 앱이 `/thread-wallet/balance`를 최대 8회, 2초 간격으로 조회해 표시 잔액을 갱신한다.

## 현재 앱 동작

- `debug`는 Google 공식 보상형 광고 테스트 단위 `ca-app-pub-3940256099942544/5224354917`을 사용한다.
- `release`는 `ADMOB_APP_ID`와 `ADMOB_REWARDED_AD_UNIT_ID`가 모두 설정되어야 SDK 로드를 허용한다. 값이 없으면 충전 화면에 준비 중 상태를 표시한다.
- Google Mobile Ads SDK는 현재 프로젝트의 Kotlin 2.0.21과 호환되는 `play-services-ads:23.6.0`을 사용한다. 최신 24.x/25.x SDK는 더 새 Kotlin 메타데이터로 빌드되어 현재 프로젝트에서 컴파일되지 않는다.
- 화면의 5·10·20 실타래 유료 패키지는 Google Play 결제 검증 서버 계약이 아직 없으므로 비활성화한다. Apple 전용 `/thread-wallet/iap/verify` 엔드포인트로 Android 구매를 전송하지 않는다.

## 릴리스 설정

AdMob에서 Android 앱과 보상형 광고 단위를 만든 뒤, 배포 빌드에 다음 Gradle 속성을 제공한다. 실제 값은 저장소에 넣지 않는다.

```bash
./gradlew :app:assembleRelease \
  -PADMOB_APP_ID=ca-app-pub-실제앱ID \
  -PADMOB_REWARDED_AD_UNIT_ID=ca-app-pub-실제광고단위ID \
  -PCOORDIT_RELEASE_API_BASE_URL=https://api.example.com/
```

백엔드 배포 환경도 같은 실제 광고 단위와 보상 설정을 가져야 한다.

```text
ADMOB_REWARDED_AD_UNIT_ID=ca-app-pub-실제광고단위ID
ADMOB_REWARD_ITEM=thread
ADMOB_REWARD_AMOUNT=1
```

AdMob 보상형 광고 단위의 SSV callback URL은 공개 HTTPS 서버의 `/webhooks/admob/rewarded`로 설정한다. Android 테스트 광고 단위는 개발 중 광고 로드 검증에만 사용하며, 실제 SSV 정산 검증에는 staging/production AdMob 단위와 같은 백엔드 환경 변수가 필요하다.

## 남은 결제 작업

Google Play Console에서 소모성 상품을 만든 뒤에는 Android purchase token을 Google Play Developer API로 검증하고, 중복 정산을 막는 별도 서버 엔드포인트와 ledger 처리가 필요하다. 이 계약이 배포되기 전에는 유료 패키지를 활성화하지 않는다.
