import SwiftUI

#if os(iOS)
struct CoorditSplashAuthenticationSheet: View {
    let onAuthenticated: () -> Void
    let onGuestAuthenticated: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var backendSession: CoorditBackendSessionStore
    @State private var mode: AuthenticationMode = .providers
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focusedField: AuthenticationField?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("coordit 시작하기")
                    .font(CoorditTypography.gmarketBold(size: CoorditSplashAuthenticationDesign.titleSize, relativeTo: .title2))
                    .foregroundStyle(Main01DesignTokens.Colors.chrome)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("coordit-splash-auth-sheet")

                Text(mode == .providers ? "비회원으로 시작하거나 계정을 연결하세요." : "이메일과 비밀번호를 입력하세요.")
                    .font(CoorditTypography.gmarketMedium(size: CoorditSplashAuthenticationDesign.subtitleSize, relativeTo: .subheadline))
                    .foregroundStyle(Main01DesignTokens.Colors.chrome.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, CoorditSplashAuthenticationDesign.titleToSubtitleSpacing)

                Group {
                    switch mode {
                    case .providers:
                        providerChoices
                    case .email:
                        emailLoginForm
                    }
                }
                .padding(.top, CoorditSplashAuthenticationDesign.subtitleToProviderSpacing)

                if backendSession.isWorking {
                    HStack(spacing: CoorditSplashAuthenticationDesign.providerStackSpacing) {
                        ProgressView()
                        Text("로그인 중이에요")
                            .font(CoorditTypography.gmarketMedium(size: CoorditSplashAuthenticationDesign.subtitleSize, relativeTo: .subheadline))
                    }
                    .tint(Main01DesignTokens.Colors.chrome)
                    .padding(.top, CoorditSplashAuthenticationDesign.statusTopSpacing)
                    .accessibilityLabel("로그인 진행 중")
                } else if backendSession.isWarning {
                    Label(authenticationErrorText, systemImage: "exclamationmark.circle")
                        .font(CoorditTypography.gmarketMedium(size: CoorditSplashAuthenticationDesign.statusSize, relativeTo: .caption))
                        .foregroundStyle(CoorditSplashAuthenticationDesign.errorForeground)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(CoorditSplashAuthenticationDesign.providerStackSpacing)
                        .background(CoorditSplashAuthenticationDesign.errorForeground.opacity(0.06), in: RoundedRectangle(cornerRadius: CoorditSplashAuthenticationDesign.providerCornerRadius))
                        .padding(.top, CoorditSplashAuthenticationDesign.statusTopSpacing)
                        .accessibilityIdentifier("splash-auth-error")
                }

                Text("계속하면 coordit의 이용약관과 개인정보 처리방침에\n동의하게 됩니다.")
                    .font(CoorditTypography.gmarketMedium(size: CoorditSplashAuthenticationDesign.legalSize, relativeTo: .caption2))
                    .foregroundStyle(Main01DesignTokens.Colors.chrome.opacity(0.58))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, CoorditSplashAuthenticationDesign.footerMinimumSpacing)
                    .accessibilityIdentifier("splash-auth-legal")
            }
            .padding(.horizontal, CoorditSplashAuthenticationDesign.horizontalInset)
            .padding(.top, CoorditSplashAuthenticationDesign.topInset)
            .padding(.bottom, CoorditSplashAuthenticationDesign.bottomInset)
            .frame(maxWidth: CoorditSplashAuthenticationDesign.contentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(.white)
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.height(CoorditSplashAuthenticationDesign.sheetHeight), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(CoorditSplashAuthenticationDesign.sheetCornerRadius)
        .interactiveDismissDisabled(backendSession.isWorking)
        .preferredColorScheme(.light)
        .task {
            guard backendSession.shouldAutomaticallyAuthenticateAppleForUITest else { return }
            await authenticate { await backendSession.loginWithApple() }
        }
    }

    private var providerChoices: some View {
        VStack(spacing: CoorditSplashAuthenticationDesign.providerStackSpacing) {
            providerButton(
                title: "Google로 계속하기",
                identifier: "splash-auth-google",
                mark: .google
            ) {
                Task { await authenticate { await backendSession.loginWithGoogle() } }
            }

            providerButton(
                title: "Apple로 계속하기",
                identifier: "splash-auth-apple",
                mark: .apple
            ) {
                Task { await authenticate { await backendSession.loginWithApple() } }
            }

            providerButton(title: "비회원으로 계속하기", identifier: "splash-auth-guest", mark: .guest) {
                Task {
                    guard let balance = await backendSession.bootstrapGuestIfNeeded() else { return }
                    onGuestAuthenticated(balance)
                    dismiss()
                }
            }

            secondaryActionButton(title: "이메일로 로그인", identifier: "splash-auth-email") {
                backendSession.clearStatus()
                mode = .email
                focusedField = .email
            }
        }
    }

    private var emailLoginForm: some View {
        VStack(spacing: CoorditSplashAuthenticationDesign.emailFormSpacing) {
            TextField("이메일", text: $email)
                .textContentType(.username)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .email)
                .submitLabel(.next)
                .onSubmit { focusedField = .password }
                .accessibilityIdentifier("splash-auth-email-field")
                .authFieldStyle()
                .disabled(backendSession.isWorking)

            SecureField("비밀번호", text: $password)
                .textContentType(.password)
                .focused($focusedField, equals: .password)
                .submitLabel(.go)
                .onSubmit { submitEmailLogin() }
                .accessibilityIdentifier("splash-auth-password-field")
                .authFieldStyle()
                .disabled(backendSession.isWorking)

            providerButton(
                title: backendSession.isWorking ? "로그인 중…" : "이메일로 로그인",
                identifier: "splash-auth-email-submit",
                isPrimary: true,
                action: submitEmailLogin
            )
            .disabled(!canSubmitEmailLogin || backendSession.isWorking)

            secondaryActionButton(title: "다른 방법으로 로그인", identifier: "splash-auth-email-back") {
                focusedField = nil
                backendSession.clearStatus()
                mode = .providers
            }
        }
    }

    private var canSubmitEmailLogin: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty
    }

    private func submitEmailLogin() {
        guard canSubmitEmailLogin, !backendSession.isWorking else { return }
        focusedField = nil
        Task {
            await backendSession.login(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )
            guard backendSession.isMember else { return }
            onAuthenticated()
            dismiss()
        }
    }

    private func providerButton(
        title: String,
        identifier: String,
        mark: AuthenticationMark? = nil,
        isPrimary: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: CoorditSplashAuthenticationDesign.providerStackSpacing) {
                if let mark {
                    providerMark(mark)
                        .frame(width: CoorditSplashAuthenticationDesign.providerMarkFrame)
                        .accessibilityHidden(true)
                }
                Text(dynamicTypeSize.isAccessibilitySize ? title.replacingOccurrences(of: " 계속하기", with: "\n계속하기") : title)
                    .font(CoorditTypography.gmarketMedium(size: CoorditSplashAuthenticationDesign.providerTitleSize, relativeTo: .body))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                if mark != nil {
                    Color.clear.frame(width: CoorditSplashAuthenticationDesign.providerMarkFrame, height: 1)
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(isPrimary ? .white : Main01DesignTokens.Colors.chrome)
            .padding(.horizontal, CoorditSplashAuthenticationDesign.providerHorizontalInset)
            .padding(.vertical, CoorditSplashAuthenticationDesign.providerStackSpacing)
            .frame(maxWidth: .infinity, minHeight: CoorditSplashAuthenticationDesign.providerHeight)
            .background(isPrimary ? Main01DesignTokens.Colors.chrome : .white, in: RoundedRectangle(cornerRadius: CoorditSplashAuthenticationDesign.providerCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: CoorditSplashAuthenticationDesign.providerCornerRadius, style: .continuous)
                    .stroke(isPrimary ? .clear : CoorditDesignTokens.ColorToken.line, lineWidth: 1)
            }
        }
        .buttonStyle(AuthenticationButtonStyle())
        .disabled(backendSession.isWorking)
        .accessibilityIdentifier(identifier)
    }

    private func secondaryActionButton(
        title: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(CoorditTypography.gmarketMedium(size: CoorditSplashAuthenticationDesign.emailEntrySize, relativeTo: .body))
                .foregroundStyle(Main01DesignTokens.Colors.chrome.opacity(0.72))
                .frame(minHeight: CoorditSplashAuthenticationDesign.secondaryActionHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(AuthenticationButtonStyle())
        .disabled(backendSession.isWorking)
        .accessibilityIdentifier(identifier)
    }

    private func authenticate(_ action: () async -> Void) async {
        await action()
        guard backendSession.isMember else { return }
        onAuthenticated()
        dismiss()
    }

    private var authenticationErrorText: String {
        switch backendSession.statusText {
        case "Could not connect to the server.":
            "서버에 연결할 수 없어요. 잠시 후 다시 시도해 주세요."
        default:
            backendSession.statusText
        }
    }

    @ViewBuilder
    private func providerMark(_ mark: AuthenticationMark) -> some View {
        switch mark {
        case .google:
            Text("G")
                .font(.system(size: CoorditSplashAuthenticationDesign.providerMarkSize, weight: .bold))
                .foregroundStyle(CoorditSplashAuthenticationDesign.googleMarkForeground)
        case .apple:
            Image(systemName: "apple.logo")
                .font(.system(size: CoorditSplashAuthenticationDesign.providerMarkSize))
                .foregroundStyle(.black)
        case .guest:
            Image(systemName: "person")
                .font(.system(size: CoorditSplashAuthenticationDesign.providerMarkSize))
        }
    }
}

private enum CoorditSplashAuthenticationDesign {
    static let sheetHeight: CGFloat = 460
    static let contentMaxWidth: CGFloat = 480
    static let sheetCornerRadius: CGFloat = 28
    static let horizontalInset: CGFloat = 24
    static let topInset: CGFloat = 28
    static let bottomInset: CGFloat = 20
    static let titleSize: CGFloat = 22
    static let subtitleSize: CGFloat = 13
    static let titleToSubtitleSpacing: CGFloat = 10
    static let subtitleToProviderSpacing: CGFloat = 24
    static let providerStackSpacing: CGFloat = 12
    static let providerHeight: CGFloat = 56
    static let providerHorizontalInset: CGFloat = 16
    static let providerCornerRadius: CGFloat = 14
    static let providerSurface = CoorditDesignTokens.ColorToken.field
    static let providerMarkFrame: CGFloat = 24
    static let googleMarkForeground = Color(red: 0.26, green: 0.45, blue: 0.83)
    static let providerMarkSize: CGFloat = 20
    static let providerTitleSize: CGFloat = 14
    static let statusTopSpacing: CGFloat = 12
    static let statusSize: CGFloat = 13
    static let emailEntrySize: CGFloat = 13
    static let secondaryActionHeight: CGFloat = 44
    static let emailFormSpacing: CGFloat = 12
    static let errorForeground = Color(red: 0.62, green: 0.04, blue: 0.08)
    static let footerMinimumSpacing: CGFloat = 24
    static let legalSize: CGFloat = 11
}

private enum AuthenticationMark {
    case google, apple, guest
}

private struct AuthenticationButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.45)
    }
}

private enum AuthenticationMode {
    case providers
    case email
}

private enum AuthenticationField: Hashable {
    case email
    case password
}

private extension View {
    func authFieldStyle() -> some View {
        font(CoorditTypography.gmarketMedium(size: CoorditSplashAuthenticationDesign.providerTitleSize, relativeTo: .body))
            .foregroundStyle(Main01DesignTokens.Colors.chrome)
            .padding(.horizontal, CoorditSplashAuthenticationDesign.providerHorizontalInset)
            .padding(.vertical, CoorditSplashAuthenticationDesign.providerStackSpacing)
            .frame(maxWidth: .infinity, minHeight: CoorditSplashAuthenticationDesign.providerHeight)
            .background(
                CoorditSplashAuthenticationDesign.providerSurface,
                in: RoundedRectangle(cornerRadius: CoorditSplashAuthenticationDesign.providerCornerRadius, style: .continuous)
            )
    }
}
#endif
