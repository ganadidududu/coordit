import SwiftUI
import WebKit

#if os(iOS)

/// 상품 페이지를 실제로 화면에 띄우면서 사이즈표를 조용히 추출한다.
///
/// 서버가 아닌 사용자 기기에서 페이지를 열기 때문에
///  - 요청이 사용자별 IP로 나가 판매처 차단(단일 IP 몰림)을 피할 수 있고
///  - 로그인·캡차가 뜨면 사용자가 그 자리에서 통과할 수 있고
///  - 이미지형 사이즈표는 화면 캡처본을 Vision OCR로 넘길 수 있다.
///
/// 사용자는 아무것도 누르지 않는다. 링크를 넣으면 이 화면이 뜨고,
/// 파싱이 끝나면 자동으로 다음 단계로 넘어간다.
struct CoorditProductWebView: UIViewRepresentable {
    let url: URL
    let onExtracted: (CoorditWebSizeChart) -> Void
    let onFailure: (CoorditWebSizeChartError) -> Void
    /// 자동 추출이 실패했을 때 사용자가 직접 이어갈 수 있도록 타이머를 관리한다.
    let timeout: TimeInterval

    func makeCoordinator() -> Coordinator {
        Coordinator(onExtracted: onExtracted, onFailure: onFailure, timeout: timeout)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        // 기본 웹뷰 UA에는 Safari 토큰이 없어 일부 판매처(지그재그 등)가 상품을 못 찾는 화면을 준다.
        // Safari와 같은 모양으로 맞춘다.
        let major = UIDevice.current.systemVersion.split(separator: ".").first.map(String.init) ?? "18"
        configuration.applicationNameForUserAgent = "Version/\(major).0 Mobile/15E148 Safari/604.1"

        let controller = WKUserContentController()
        controller.addUserScript(
            WKUserScript(
                source: CoorditSizeChartScript.source,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
        )
        controller.add(context.coordinator, name: CoorditSizeChartScript.messageHandlerName)
        configuration.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.isInspectable = false
        webView.allowsBackForwardNavigationGestures = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        context.coordinator.attach(webView: webView)
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.cancel()
        webView.configuration.userContentController.removeScriptMessageHandler(
            forName: CoorditSizeChartScript.messageHandlerName
        )
        webView.stopLoading()
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        private let onExtracted: (CoorditWebSizeChart) -> Void
        private let onFailure: (CoorditWebSizeChartError) -> Void
        private let timeout: TimeInterval
        private weak var webView: WKWebView?
        private var timeoutTask: Task<Void, Never>?
        private var pollTask: Task<Void, Never>?
        private var followedFallbacks: Set<URL> = []
        private var hasFinished = false

        init(
            onExtracted: @escaping (CoorditWebSizeChart) -> Void,
            onFailure: @escaping (CoorditWebSizeChartError) -> Void,
            timeout: TimeInterval
        ) {
            self.onExtracted = onExtracted
            self.onFailure = onFailure
            self.timeout = timeout
        }

        func attach(webView: WKWebView) {
            self.webView = webView
            Self.log("start \(webView.url?.absoluteString ?? "-") ua=\(webView.configuration.applicationNameForUserAgent ?? "-")")
            // 로딩이 끝나지 않는 페이지도 기다리다 멈추도록 처음부터 타이머를 건다.
            startTimeout()
        }

        func cancel() {
            timeoutTask?.cancel()
            timeoutTask = nil
            pollTask?.cancel()
            pollTask = nil
            hasFinished = true
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
        ) {
            // 앱 열기(musinsa:// 등)·스토어 이동은 막고 상품 페이지에 머문다.
            let scheme = navigationAction.request.url?.scheme?.lowercased()
            let isWeb = scheme == "http" || scheme == "https" || scheme == "about" || scheme == "blob"
            let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true
            if isMainFrame {
                Self.log("nav \(isWeb ? "allow" : "BLOCK") \(navigationAction.request.url?.absoluteString ?? "-")")
            }
            // 앱에서 복사한 공유 링크는 "앱 열기" 중계 페이지로 넘어간다(지그재그 s.zigzag.kr → abr.ge).
            // 그 주소에 담긴 웹용 상품 주소로 바로 간다.
            if isMainFrame, isWeb, let url = navigationAction.request.url,
               let fallback = Self.webFallback(in: url), !followedFallbacks.contains(fallback) {
                followedFallbacks.insert(fallback)
                Self.log("fallback -> \(fallback.absoluteString)")
                decisionHandler(.cancel)
                webView.load(URLRequest(url: fallback))
                return
            }
            decisionHandler(isWeb ? .allow : .cancel)
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            startPolling(in: webView)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Self.log("didFinish \(webView.url?.absoluteString ?? "-")")
            startPolling(in: webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            Self.log("didFail \(error as NSError)")
            guard !Self.isIgnorable(error) else { return }
            finish(.failure(.init(kind: .loadFailed, message: error.localizedDescription)))
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            Self.log("didFailProvisional \(error as NSError)")
            guard !Self.isIgnorable(error) else { return }
            finish(.failure(.init(kind: .loadFailed, message: error.localizedDescription)))
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            finish(.failure(.init(kind: .loadFailed, message: "상품 페이지를 표시하지 못했어요.")))
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard !hasFinished else { return }
            guard let payload = CoorditSizeChartScript.decode(message.body) else { return }
            switch payload {
            case .success(let chart):
                Self.log("extracted rows=\(chart.rows.count) ocr=\(chart.requiresVisionOCR) name=\(chart.productName ?? "-")")
                finish(.success(chart))
            case .failure(let error) where error.isRetryable:
                // 사이즈 탭이 아직 안 열렸을 수 있다. 폴링이 타임아웃까지 다시 확인한다.
                break
            case .failure(let error):
                finish(.failure(error))
            }
        }

        /// 딥링크 중계 서비스(Airbridge, AppsFlyer, Branch 등)가 쓰는 "웹에서 열 주소" 파라미터.
        private static let webFallbackParameters: Set<String> = [
            "fallback_desktop", "af_web_dp", "$desktop_url", "$fallback_url", "fallback_url", "ofl",
        ]

        private static func webFallback(in url: URL) -> URL? {
            guard let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return nil }
            for item in items where webFallbackParameters.contains(item.name) {
                guard let value = item.value, let fallback = URL(string: value),
                      let scheme = fallback.scheme?.lowercased(), scheme == "http" || scheme == "https",
                      fallback.host != nil, fallback != url
                else { continue }
                return fallback
            }
            return nil
        }

        /// 실기기에서 어디서 멈추는지 보기 위한 디버그 로그. 릴리스 빌드에서는 아무것도 하지 않는다.
        private static func log(_ message: @autoclosure () -> String) {
            #if DEBUG
            print("[CoorditWebImport] \(message())")
            #endif
        }

        #if DEBUG
        private static let diagnosticScript = """
        JSON.stringify({ url: location.href, title: document.title, tables: document.querySelectorAll('table').length,
          installed: !!window.__coorditSizeChartInstalled,
          tabs: Array.prototype.slice.call(document.querySelectorAll("button, [role='tab'], a")).map(function (e) {
            return (e.textContent || '').replace(/\\s+/g, ' ').trim(); }).filter(function (t) { return /사이즈|size|실측/i.test(t) && t.length < 30; }).slice(0, 8),
          text: (document.body ? document.body.innerText : '').replace(/\\s+/g, ' ').slice(0, 300) })
        """
        #endif

        /// 리다이렉트로 취소된 로드, 우리가 막은 앱 스킴 이동은 실패가 아니다.
        private static func isIgnorable(_ error: Error) -> Bool {
            let error = error as NSError
            if error.domain == NSURLErrorDomain, error.code == NSURLErrorCancelled { return true }
            return error.domain == "WebKitErrorDomain" && error.code == 102
        }

        /// 표가 늦게 그려지는 페이지를 위해 끝날 때까지 주기적으로 다시 확인한다.
        private func startPolling(in webView: WKWebView) {
            guard pollTask == nil, !hasFinished else { return }
            pollTask = Task { @MainActor [weak self, weak webView] in
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                    guard let self, let webView, !Task.isCancelled, !self.hasFinished else { return }
                    _ = try? await webView.evaluateJavaScript(CoorditSizeChartScript.retryInvocation)
                }
            }
        }

        private func startTimeout() {
            guard timeoutTask == nil else { return }
            timeoutTask = Task { @MainActor [weak self] in
                guard let self else { return }
                try? await Task.sleep(nanoseconds: UInt64(self.timeout * 1_000_000_000))
                guard !Task.isCancelled, !self.hasFinished else { return }
                #if DEBUG
                let state = try? await self.webView?.evaluateJavaScript(Self.diagnosticScript)
                Self.log("TIMEOUT \(state as? String ?? "-")")
                #endif
                self.finish(.failure(.init(kind: .timedOut, message: "사이즈표를 찾지 못했어요.")))
            }
        }

        private func finish(_ result: Result<CoorditWebSizeChart, CoorditWebSizeChartError>) {
            guard !hasFinished else { return }
            hasFinished = true
            timeoutTask?.cancel()
            timeoutTask = nil
            pollTask?.cancel()
            pollTask = nil
            webView?.stopLoading()
            switch result {
            case .success(let chart): onExtracted(chart)
            case .failure(let error): onFailure(error)
            }
        }
    }
}

#endif
