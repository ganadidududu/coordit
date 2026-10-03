# Google 로그인 설정

기존 iOS Xcode project에 설정된 Web Client ID와 staging API URL을 Android `gradle.properties`의 공개 기본 설정으로 재사용한다. Client secret은 앱에 포함하지 않는다. `-P` 속성으로 다른 환경을 지정할 수 있다. release API는 별도 HTTPS 설정이며 자동으로 staging에 연결하지 않는다.

Google Cloud Console → Google Auth Platform → 클라이언트에서 기존 iOS/Web 항목을 보존하고 Android 유형을 추가한다.

| 값 | 현재 개발 빌드 |
|---|---|
| 이름 | Coordit Android Debug |
| package | `com.inseong.coordit.debug` |
| SHA-1 | `A2:60:95:4D:EC:ED:B2:D0:83:96:46:7F:BF:95:FC:28:7C:96:DD:3D` |
| Web client | `789827940031-omahjmi6eepp4rpf5ue7kjqndf8rhjr7.apps.googleusercontent.com` |

SHA-1은 이 Mac의 debug keystore에서 `./gradlew :app:signingReport`로 확인한 값이다. 다른 개발 환경은 자신의 서명을 등록해야 한다. 배포 package는 `com.inseong.coordit`이며 Play App Signing 인증서는 별도 Android OAuth 클라이언트로 등록한다. Android client ID를 GOOGLE_WEB_CLIENT_ID에 넣지 않는다. Supabase 허용 Google audience도 이 Web client와 일치해야 한다.

Google Credential Manager의 명시적 버튼 로그인으로 ID token을 받고 기존 POST /auth/google에 전달한다. 기존 iOS와 동일하게 보안 난수 raw nonce의 SHA-256을 Google 요청에 넣고 raw nonce를 backend에 보낸다. 취소/오류/오래된 콜백은 인증 성공으로 취급하지 않는다. logout은 로컬 암호화 세션을 삭제하고 credential provider 상태도 해제한다.

- [Google 클라이언트 인증/SHA-1](https://developers.google.com/android/guides/client-auth)
- [Google Android Credential Manager](https://developer.android.com/identity/sign-in/credential-manager-siwg-implementation)

## Apple 별도 의존성

iOS 원본: AuthenticationServices가 ID token을 반환하고 POST /auth/apple로 교환한다.

Android 제약: Apple Services ID와 HTTPS return endpoint의 form_post 처리 및 앱 복귀가 필요하다. 기존 backend에는 이 callback 계약이 없다.

현재 구현: Apple 제공자 버튼은 유지하며 미지원 상태를 명시한다. 임의 로그인 성공, iOS client ID 재사용, 미검증 custom scheme token 수신을 넣지 않는다. backend를 수정하지 않는 이번 작업 경계를 유지한다.

UI 차이: SF Symbols 대신 Apple 공식 로그인 마크 자산을 사용하며 배경색에 차이가 있다. 출처는 `apple-sign-in-logo-PROVENANCE.md`.

기능 차이: Android Apple OAuth는 아직 실행할 수 없다. Services ID/return endpoint 확정 후 구현해야 한다.

- [Apple 다른 플랫폼 로그인](https://developer.apple.com/documentation/signinwithapple/incorporating-sign-in-with-apple-into-other-platforms)
