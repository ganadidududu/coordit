import SwiftUI

#if os(iOS)
extension CoorditMyPageFamilyView {
    func backendConnectionStatus(metrics: CoorditResponsiveMetrics) -> some View {
        CoorditSettingsStatusBanner(
            text: backendAccountStatusText,
            identifier: "mypage-backend-status",
            metrics: metrics,
            isWarning: backendSession.isWarning
        )
    }

    private var backendAccountStatusText: String {
        if backendSession.isWarning { return backendSession.statusText }
        if backendSession.isMember { return "계정 연결됨" }
        if backendSession.isAuthenticated { return "비회원으로 이용 중" }
        return "계정을 연결하면 기록을 안전하게 보관할 수 있어요"
    }

    func syncBackendProfile() {
        guard let profile = backendSession.profile else { return }
        profileName = profile.displayName ?? "코딧 사용자"
    }

    func syncBackendBodyMeasurement() {
        guard let measurement = backendSession.latestBodyMeasurement else { return }
        heightMeasurement = measurement.heightCm.map { String(format: "%.1f", $0) } ?? ""
        weightMeasurement = measurement.weightKg.map { String(format: "%.1f", $0) } ?? ""
    }

    @ViewBuilder
    func backendAuthControls(metrics: CoorditResponsiveMetrics) -> some View {
        if backendSession.isAuthenticated {
            CoorditSettingsCard(metrics: metrics) {
                VStack(spacing: metrics.value(13)) {
                    VStack(alignment: .leading, spacing: metrics.value(4)) {
                        Text(backendSession.displayNameText)
                            .font(CoorditTypography.gmarketBold(size: metrics.value(14), relativeTo: .headline))
                            .foregroundStyle(CoorditSettingsStyle.ink)
                        Text(backendSession.emailText)
                            .font(CoorditTypography.gmarketMedium(size: metrics.value(10), relativeTo: .caption))
                            .foregroundStyle(CoorditSettingsStyle.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    CoorditSettingsPrimaryButton(
                        title: "이 기기에서 로그아웃",
                        identifier: "mypage-backend-local-logout",
                        metrics: metrics
                    ) {
                        backendSession.logout()
                    }
                }
                .padding(.horizontal, metrics.value(13))
            }
        }
    }
}
#endif
