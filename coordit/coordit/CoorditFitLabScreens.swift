import SwiftUI

#if os(iOS)
struct CoorditFitLabFamilyView: View {
    let currentRoute: CoorditFrameRoute
    let onRouteChange: (CoorditFrameRoute) -> Void

    var body: some View {
        CoorditScreenScaffold(route: currentRoute, onRouteChange: onRouteChange, contentTop: 115) { metrics in
            VStack(spacing: metrics.value(22)) {
                CoorditFitLabTitleCard(
                    title: currentRoute == .fitLabHistoryDetail ? "FIT DETAIL" : "FIT LAB",
                    metrics: metrics
                ) {
                    onRouteChange(.fitLabInput)
                }
                .padding(.horizontal, metrics.value(15))

                switch currentRoute {
                case .fitLabInput:
                    CoorditFitLabInputScreen(metrics: metrics, onRouteChange: onRouteChange)
                case .fitLabLoading:
                    CoorditFitLabLoadingScreen(metrics: metrics)
                case .fitLabResultTop:
                    CoorditFitLabResultScreen(variant: .top, metrics: metrics, onRouteChange: onRouteChange)
                case .fitLabResultBottom:
                    CoorditFitLabResultScreen(variant: .bottom, metrics: metrics, onRouteChange: onRouteChange)
                case .fitLabHistoryRegister:
                    CoorditFitLabHistoryRegisterScreen(metrics: metrics, onRouteChange: onRouteChange)
                case .fitLabHistoryDetail:
                    CoorditFitLabHistoryDetailScreen(metrics: metrics, onRouteChange: onRouteChange)
                default:
                    CoorditFitLabInputScreen(metrics: metrics, onRouteChange: onRouteChange)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .accessibilityIdentifier(currentRoute.fitLabAccessibilityIdentifier)
        }
    }
}

struct CoorditFitLabScreens: View {
    let currentRoute: CoorditFrameRoute
    let onRouteChange: (CoorditFrameRoute) -> Void

    var body: some View {
        CoorditFitLabFamilyView(currentRoute: currentRoute, onRouteChange: onRouteChange)
    }
}

private struct CoorditFitLabInputScreen: View {
    let metrics: CoorditResponsiveMetrics
    let onRouteChange: (CoorditFrameRoute) -> Void

    var body: some View {
        VStack(spacing: metrics.value(14)) {
            HStack(spacing: metrics.value(11)) {
                CoorditFitLabSourceButton(title: "갤러리에서 추가", metrics: metrics) {
                    onRouteChange(.fitLabLoading)
                }
                CoorditFitLabSourceButton(title: "카메라에서 추가", metrics: metrics) {
                    onRouteChange(.fitLabLoading)
                }
            }
            .padding(metrics.value(9))
            .background(
                CoorditFitLabTexturedPanel(cornerRadius: metrics.value(7), intensity: 1.0)
            )
            .clipShape(RoundedRectangle(cornerRadius: metrics.value(7)))
            .shadow(color: CoorditFitLabPalette.ink.opacity(0.28), radius: metrics.value(8), y: metrics.value(3))

            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: metrics.value(7), style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                CoorditFitLabPalette.surface,
                                Color(red: 244 / 255, green: 246 / 255, blue: 250 / 255),
                                Color(red: 230 / 255, green: 234 / 255, blue: 244 / 255),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        CoorditFitLabSubtleNoise()
                            .clipShape(RoundedRectangle(cornerRadius: metrics.value(7), style: .continuous))
                            .opacity(0.26)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: metrics.value(7), style: .continuous)
                            .stroke(Color.black.opacity(0.15), lineWidth: metrics.value(0.8))
                    )

                RoundedRectangle(cornerRadius: metrics.value(8), style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white,
                                Color(red: 251 / 255, green: 252 / 255, blue: 254 / 255),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: metrics.value(276))
                    .padding(.horizontal, metrics.value(12))
                    .padding(.top, metrics.value(31))
                    .shadow(color: .black.opacity(0.09), radius: metrics.value(20), y: metrics.value(10))
            }
            .frame(maxWidth: .infinity)
            .frame(height: metrics.value(495))
            .shadow(color: .black.opacity(0.08), radius: metrics.value(14), y: metrics.value(5))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, metrics.value(33))
    }
}

private struct CoorditFitLabLoadingScreen: View {
    let metrics: CoorditResponsiveMetrics

    var body: some View {
        VStack(spacing: metrics.value(22)) {
            Spacer(minLength: metrics.value(158))
            ZStack {
                Image(CoorditAssetNames.loadingMannequin)
                    .resizable()
                    .scaledToFit()
                    .frame(width: metrics.value(58), height: metrics.value(82))
                    .opacity(0.28)
                Image(CoorditAssetNames.loadingOrbit)
                    .resizable()
                    .scaledToFit()
                    .frame(width: metrics.value(85), height: metrics.value(44))
                    .opacity(0.75)
            }
            Text("핏 스코어 계산 중 . . .")
                .font(CoorditTypography.gmarketMedium(size: metrics.value(16), relativeTo: .body))
                .foregroundStyle(Color.black.opacity(0.76))
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CoorditFitLabResultScreen: View {
    let variant: CoorditFitLabResultVariant
    let metrics: CoorditResponsiveMetrics
    let onRouteChange: (CoorditFrameRoute) -> Void

    var body: some View {
        VStack(spacing: metrics.value(14)) {
            HStack(spacing: metrics.value(8)) {
                CoorditFitLabMannequinPanel(assetName: variant.assetName, metrics: metrics)
                    .frame(width: metrics.value(109), height: metrics.value(240))

                CoorditFitLabScoreCard(variant: variant, metrics: metrics)
                    .frame(width: metrics.value(229), height: metrics.value(240))
            }

            CoorditFitLabDescriptionCard(metrics: metrics, compact: false, onDetail: nil)
                .frame(maxWidth: .infinity)
                .frame(height: metrics.value(263))

            CoorditFitLabPrimaryButton(title: "히스토리에 추가", metrics: metrics) {
                onRouteChange(.fitLabHistoryRegister)
            }
            .padding(.top, metrics.value(1))
        }
        .padding(.horizontal, metrics.value(28))
    }
}

private struct CoorditFitLabHistoryRegisterScreen: View {
    let metrics: CoorditResponsiveMetrics
    let onRouteChange: (CoorditFrameRoute) -> Void

    var body: some View {
        VStack(spacing: metrics.value(12)) {
            HStack(spacing: metrics.value(8)) {
                CoorditFitLabMannequinPanel(assetName: CoorditFitLabResultVariant.bottom.assetName, metrics: metrics)
                    .frame(width: metrics.value(109), height: metrics.value(240))

                CoorditFitLabScoreCard(variant: .bottom, metrics: metrics)
                    .frame(width: metrics.value(229), height: metrics.value(240))
            }

            CoorditFitLabDescriptionCard(metrics: metrics, compact: false, onDetail: nil)
                .frame(maxWidth: .infinity)
                .frame(height: metrics.value(263))

            CoorditFitLabPrimaryButton(title: "히스토리에 추가", metrics: metrics) {
                onRouteChange(.fitLabHistoryDetail)
            }
        }
        .padding(.horizontal, metrics.value(28))
    }
}

private extension CoorditFrameRoute {
    var fitLabAccessibilityIdentifier: String {
        switch self {
        case .fitLabInput,
             .fitLabLoading,
             .fitLabResultTop,
             .fitLabResultBottom,
             .fitLabHistoryRegister,
             .fitLabHistoryDetail:
            "coordit-screen-\(rawValue)"
        default:
            "coordit-screen-fitlab-input"
        }
    }
}
#endif
