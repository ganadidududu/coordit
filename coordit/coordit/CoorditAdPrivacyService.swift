import Combine
import Foundation
import GoogleMobileAds
import UserMessagingPlatform

#if canImport(UIKit)
import UIKit
#endif

#if os(iOS)
@MainActor
final class CoorditAdPrivacyService: ObservableObject {
    static let shared = CoorditAdPrivacyService()

    @Published private(set) var canRequestAds = false
    @Published private(set) var privacyOptionsRequired = false
    @Published private(set) var statusText = "광고 개인정보 설정을 확인하고 있어요."

    private var refreshTask: Task<Bool, Never>?
    private var didStartMobileAds = false

    private init() {
        let configuration = MobileAds.shared.requestConfiguration
        configuration.setPublisherFirstPartyIDEnabled(false)
        configuration.publisherPrivacyPersonalizationState = .disabled
    }

    @discardableResult
    func refreshConsent() async -> Bool {
        if ProcessInfo.processInfo.arguments.contains("--coordit-ui-testing") {
            canRequestAds = true
            privacyOptionsRequired = false
            statusText = "비개인화 광고 설정이 적용되어 있어요."
            return true
        }

        if let refreshTask {
            return await refreshTask.value
        }

        let task = Task { @MainActor [weak self] in
            guard let self else { return false }
            return await self.performConsentRefresh()
        }
        refreshTask = task
        let result = await task.value
        refreshTask = nil
        return result
    }

    func presentPrivacyOptions() async {
        guard await refreshConsent() else {
            statusText = "광고 개인정보 설정을 불러오지 못했어요. 다시 시도해 주세요."
            return
        }
        guard privacyOptionsRequired else {
            statusText = "현재 지역에서는 추가 선택이 필요하지 않아요."
            return
        }

        let error = await withCheckedContinuation { continuation in
            ConsentForm.presentPrivacyOptionsForm(from: nil) { error in
                continuation.resume(returning: error)
            }
        }
        updatePublishedState()
        statusText = error == nil
            ? "광고 개인정보 설정이 반영됐어요."
            : "광고 개인정보 설정을 열지 못했어요. 다시 시도해 주세요."
    }

    private func performConsentRefresh() async -> Bool {
        let updateError = await withCheckedContinuation { continuation in
            ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters()) { error in
                continuation.resume(returning: error)
            }
        }

        if updateError == nil {
            _ = await withCheckedContinuation { continuation in
                ConsentForm.loadAndPresentIfRequired(from: nil) { error in
                    continuation.resume(returning: error)
                }
            } as Error?
        }

        updatePublishedState()
        if canRequestAds {
            startMobileAdsIfNeeded()
            statusText = privacyOptionsRequired
                ? "광고 개인정보 설정을 언제든 변경할 수 있어요."
                : "비개인화 광고 설정이 적용되어 있어요."
        } else {
            statusText = "광고 개인정보 확인이 필요해요."
        }
        return canRequestAds
    }

    private func updatePublishedState() {
        let consentInformation = ConsentInformation.shared
        canRequestAds = consentInformation.canRequestAds
        privacyOptionsRequired = consentInformation.privacyOptionsRequirementStatus == .required
    }

    private func startMobileAdsIfNeeded() {
        guard !didStartMobileAds else { return }
        didStartMobileAds = true
        MobileAds.shared.start()
    }
}
#endif
