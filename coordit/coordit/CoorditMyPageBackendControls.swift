import SwiftUI

#if os(iOS)
extension CoorditMyPageFamilyView {
    func backendConnectionStatus(metrics: CoorditResponsiveMetrics) -> some View {
        CoorditSettingsStatusBanner(
            text: backendSession.statusText,
            identifier: "mypage-backend-status",
            metrics: metrics,
            isWarning: backendSession.isWarning
        )
    }

    func syncBackendProfile() {
        guard let profile = backendSession.profile else { return }
        profileName = profile.displayName ?? "코딧 사용자"
        backendEmail = profile.email
    }

    func syncBackendBodyMeasurement() {
        guard let measurement = backendSession.latestBodyMeasurement else { return }
        shoulderMeasurement = measurement.shoulderWidth.map { String(format: "%.1f", $0) } ?? shoulderMeasurement
        chestMeasurement = measurement.chestCircumference.map { String(format: "%.1f", $0) } ?? chestMeasurement
        waistMeasurement = measurement.waistCircumference.map { String(format: "%.1f", $0) } ?? waistMeasurement
        hipMeasurement = measurement.hipCircumference.map { String(format: "%.1f", $0) } ?? hipMeasurement
    }

    func backendAuthControls(metrics: CoorditResponsiveMetrics) -> some View {
        CoorditSettingsCard(metrics: metrics) {
            VStack(spacing: metrics.value(13)) {
                CoorditSettingsTextField(
                    title: "백엔드 계정 이메일",
                    placeholder: "email@example.com",
                    text: $backendEmail,
                    identifier: "mypage-backend-email",
                    metrics: metrics
                )
                CoorditSettingsTextField(
                    title: "백엔드 계정 비밀번호",
                    placeholder: "비밀번호",
                    text: $backendPassword,
                    identifier: "mypage-backend-password",
                    metrics: metrics,
                    isSecure: true
                )

                HStack(spacing: metrics.value(10)) {
                    CoorditSettingsPrimaryButton(
                        title: "로그인",
                        identifier: "mypage-backend-login",
                        metrics: metrics,
                        isEnabled: canSubmitBackendAuth
                    ) {
                        Task {
                            await backendSession.login(email: backendEmail, password: backendPassword)
                            syncBackendProfile()
                            syncBackendBodyMeasurement()
                        }
                    }
                    CoorditSettingsPrimaryButton(
                        title: "가입",
                        identifier: "mypage-backend-signup",
                        metrics: metrics,
                        isEnabled: canSubmitBackendAuth
                    ) {
                        Task {
                            await backendSession.signup(email: backendEmail, password: backendPassword)
                            syncBackendProfile()
                            syncBackendBodyMeasurement()
                        }
                    }
                }

                if backendSession.isAuthenticated {
                    CoorditSettingsPrimaryButton(
                        title: "이 기기에서 로그아웃",
                        identifier: "mypage-backend-local-logout",
                        metrics: metrics
                    ) {
                        backendSession.logout()
                    }
                }
            }
            .padding(.horizontal, metrics.value(13))
        }
    }

    private var canSubmitBackendAuth: Bool {
        backendEmail.contains("@") && backendPassword.count >= 6 && !backendSession.isWorking
    }
}
#endif
