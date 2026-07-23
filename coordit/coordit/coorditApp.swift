import SwiftUI

#if os(iOS)
@main
struct coorditApp: App {
    @StateObject private var backendSession = CoorditBackendSessionStore()

    init() {
        CoorditFontRegistration.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(backendSession)
                .onOpenURL { url in
                    _ = CoorditGoogleSignIn.handle(url)
                }
        }
    }
}
#endif
