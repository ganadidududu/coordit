# Android foundation data contract

Historical Phase 2 record. Current launcher, staging defaults, and provider integration supersede this snapshot; see [ACCOUNT_FLOW_VALIDATION.md](ACCOUNT_FLOW_VALIDATION.md) and [GOOGLE_SIGN_IN_SETUP.md](GOOGLE_SIGN_IN_SETUP.md).

Phase 2 delivers real API and secure-session plumbing, not a production product flow. The main manifest intentionally has no launcher; the debug source set hosts a visual validation screen. Release artifacts are not shippable apps.

## Build

Use JDK 17 or newer supported by Gradle/AGP, Android SDK 35, and the checked-in `./gradlew` (8.11.1, official distribution checksum pinned). AGP 8.9.1 and Kotlin/Compose compiler 2.0.21 are pinned. Set `ANDROID_HOME` or an ignored `local.properties`; do not commit machine paths.

- `./gradlew :app:testDebugUnitTest :app:assembleDebug :app:assembleDebugAndroidTest`
- `./gradlew :app:connectedDebugAndroidTest` with an emulator/device available

Debug defaults to emulator backend `http://10.0.2.2:4000/`. Override with `-PCOORDIT_API_BASE_URL=...`. Release uses `-PCOORDIT_RELEASE_API_BASE_URL=https://...`; HTTP is rejected during configuration, cleartext is disabled, and an omitted release URL is an explicitly blocked `unconfigured.invalid` endpoint. `GOOGLE_WEB_CLIENT_ID` defaults empty; provider UI/console setup is deferred. No fake successful response is supplied by the app.

## Public API

`AppContainer(context)` exposes `api: CoorditApi` and `repository: SessionRepository`. The repository offers `session: StateFlow<AuthSession?>`, `restore`, `loginGoogle`, `loginApple`, `logout`, `health`, `loadProfile`, `loadOnboardingStatus`, `completeOnboarding`, `loadBodyMeasurements`, and `loadThreadBalance`. Suspend functions throw errors to their caller. Provider login takes an identity token and the raw nonce. Provider SDK integration and nonce generation are not supplied by this phase.

DTOs mirror `CoorditBackendModels.swift` and endpoint/body contracts mirror `CoorditBackendClient.swift`: auth/onboarding service JSON is camelCase, persisted profile/body fields use explicit snake_case annotations. Session credentials redact `toString`. Protected calls send explicit Bearer headers. Calls are not transparently retried after 401, avoiding mutation replay.

Sessions are persisted before StateFlow publication. Restore exchanges the refresh token; HTTP 400/401/403 clears rejected credentials, while network/5xx/cancellation failures preserve stored credentials and propagate. Login/restore/logout mutations serialize with a mutex. Profile/onboarding calls remain separate so a post-login data error does not undo successful login. Consumers should cancel account-scoped data work on logout/user changes.

`SessionStore` is injectable. `SecureSessionStore` uses a nonexportable Android Keystore AES-GCM key, fresh random IVs, and an AtomicFile in `noBackupFilesDir`. Backup and device-transfer exclusions are explicit. Corruption/key-loss errors propagate for a future account recovery UI; this phase does not silently reset them. Onboarding/welcome preference caching is deferred to the relevant feature phase; the server remains authoritative.

## Validation scope

MockWebServer JVM tests validate actual Retrofit requests and response mappings, session persistence/publication, invalid/transient restore outcomes, cancellation, and malformed login responses. The instrumentation secure-store test checks encrypted bytes omit tokens, survives a new store instance, and deletes on clear. These tests do not prove deployed backend/provider configuration. No real account credentials or backend fixtures are bundled.
