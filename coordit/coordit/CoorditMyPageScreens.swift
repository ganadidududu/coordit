import SwiftUI

#if os(iOS)
struct CoorditMyPageFamilyView: View {
    let route: CoorditFrameRoute
    let onRouteChange: (CoorditFrameRoute) -> Void

    @State var feedDataConsent = true
    @State var aiDataConsent = false
    @State var marketingNotifications = false
    @State var selectedTheme: MyPageTheme = .system
    @State var selectedLanguage: MyPageLanguage = .korean

    var body: some View {
        CoorditScreenScaffold(route: route, onRouteChange: onRouteChange, contentTop: 119) { metrics in
            ScrollView(.vertical, showsIndicators: false) {
                routeContent(metrics: metrics)
                    .frame(width: metrics.value(370))
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, metrics.value(26))
            }
            .accessibilityIdentifier(routeIdentifier)
        }
    }

    private var routeIdentifier: String {
        switch route {
        case .myPage:
            "coordit-screen-mypage"
        case .myPageThreadCharge:
            "coordit-screen-mypage-thread-charge"
        case .myPageBody:
            "coordit-screen-mypage-body"
        case .myPageAccount:
            "coordit-screen-mypage-account"
        case .myPagePrivacy:
            "coordit-screen-mypage-privacy"
        case .myPageAppSettings:
            "coordit-screen-mypage-app-settings"
        case .myPageNotifications:
            "coordit-screen-mypage-notifications"
        default:
            "coordit-screen-mypage"
        }
    }

    @ViewBuilder
    private func routeContent(metrics: CoorditResponsiveMetrics) -> some View {
        switch route {
        case .myPage:
            myPageLanding(metrics: metrics)
        case .myPageThreadCharge:
            threadCharge(metrics: metrics)
        case .myPageBody:
            bodyInfo(metrics: metrics)
        case .myPageAccount:
            account(metrics: metrics)
        case .myPagePrivacy:
            privacy(metrics: metrics)
        case .myPageAppSettings:
            appSettings(metrics: metrics)
        case .myPageNotifications:
            notifications(metrics: metrics)
        default:
            myPageLanding(metrics: metrics)
        }
    }

    private func myPageLanding(metrics: CoorditResponsiveMetrics) -> some View {
        VStack(spacing: metrics.value(10)) {
            pageHeader("MY PAGE", metrics: metrics, backRoute: .main04)

            VStack(spacing: metrics.value(10)) {
                CoorditSettingsMenuRow(
                    title: "계정",
                    subtitle: "프로필, 이메일, 비밀번호, 로그아웃",
                    assetName: CoorditAssetNames.mypageAccount,
                    metrics: metrics
                ) {
                    onRouteChange(.myPageAccount)
                }

                CoorditSettingsMenuRow(
                    title: "내 신체 정보",
                    subtitle: "키, 몸무게, 성별, 체수, 단위",
                    assetName: CoorditAssetNames.mypageBody,
                    metrics: metrics
                ) {
                    onRouteChange(.myPageBody)
                }

                CoorditSettingsMenuRow(
                    title: "알림",
                    subtitle: "구매 후 피드백, 재확인, 리포트",
                    assetName: CoorditAssetNames.mypageNotifications,
                    metrics: metrics
                ) {
                    onRouteChange(.myPageNotifications)
                }

                CoorditSettingsMenuRow(
                    title: "개인정보/보안",
                    subtitle: "정책, 약관, 데이터 동의",
                    assetName: CoorditAssetNames.mypagePrivacy,
                    metrics: metrics
                ) {
                    onRouteChange(.myPagePrivacy)
                }

                CoorditSettingsMenuRow(
                    title: "앱 설정",
                    subtitle: "테마, 언어, 버전, 문의, 신고",
                    assetName: CoorditAssetNames.mypageSettings,
                    metrics: metrics
                ) {
                    onRouteChange(.myPageAppSettings)
                }
            }
            .padding(.top, metrics.value(121))
        }
    }

    private func account(metrics: CoorditResponsiveMetrics) -> some View {
        VStack(spacing: metrics.value(27)) {
            pageHeader("계정", metrics: metrics)

            CoorditSettingsCard(metrics: metrics) {
                CoorditSettingsDetailRow(title: "프로필 수정", subtitle: "이름, 사진, 기본 소개", metrics: metrics, action: {}) {
                    CoorditSettingsChevron(metrics: metrics)
                }
                CoorditSettingsDivider(metrics: metrics)
                CoorditSettingsDetailRow(title: "이메일 확인", metrics: metrics) {
                    CoorditSettingsValuePill(text: "verified@coordit.app", metrics: metrics)
                }
                CoorditSettingsDivider(metrics: metrics)
                CoorditSettingsDetailRow(title: "비밀번호 변경", subtitle: "마지막 변경 32일 전", metrics: metrics, action: {}) {
                    CoorditSettingsChevron(metrics: metrics)
                }
                CoorditSettingsDivider(metrics: metrics)
                CoorditSettingsDetailRow(title: "로그아웃", subtitle: "현재 기기에서 로그아웃", metrics: metrics, action: {}) {
                    CoorditSettingsChevron(metrics: metrics)
                }
                CoorditSettingsDivider(metrics: metrics)
                CoorditSettingsDetailRow(title: "회원 탈퇴", subtitle: "계정 및 데이터 삭제", metrics: metrics, titleColor: CoorditSettingsStyle.danger, action: {}) {
                    CoorditSettingsChevron(metrics: metrics, color: CoorditSettingsStyle.danger)
                }
            }
        }
    }

    private func bodyInfo(metrics: CoorditResponsiveMetrics) -> some View {
        VStack(spacing: metrics.value(27)) {
            pageHeader("내 신체 정보", metrics: metrics)

            CoorditSettingsCard(metrics: metrics) {
                CoorditSettingsDetailRow(title: "키", metrics: metrics) {
                    CoorditSettingsValuePill(text: "177 cm", metrics: metrics)
                }
                CoorditSettingsDivider(metrics: metrics)
                CoorditSettingsDetailRow(title: "몸무게", metrics: metrics) {
                    CoorditSettingsValuePill(text: "68 kg", metrics: metrics)
                }
                CoorditSettingsDivider(metrics: metrics)
                CoorditSettingsDetailRow(title: "성별", metrics: metrics) {
                    CoorditSettingsValuePill(text: "남성", metrics: metrics)
                }
                CoorditSettingsDivider(metrics: metrics)
                CoorditSettingsDetailRow(title: "출생연도", metrics: metrics) {
                    CoorditSettingsValuePill(text: "1996", metrics: metrics)
                }
                CoorditSettingsDivider(metrics: metrics)
                CoorditSettingsDetailRow(title: "신체 치수 관리", subtitle: "어깨, 가슴, 허리 등", metrics: metrics, action: {}) {
                    CoorditSettingsChevron(metrics: metrics)
                }
            }
        }
    }

    func pageHeader(
        _ title: String,
        metrics: CoorditResponsiveMetrics,
        backRoute: CoorditFrameRoute = .myPage
    ) -> some View {
        CoorditSettingsHeaderCard(title: title, metrics: metrics) {
            onRouteChange(backRoute)
        }
    }

}
#endif
