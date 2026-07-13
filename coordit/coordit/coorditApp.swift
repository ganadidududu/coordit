import SwiftUI

#if os(iOS)
@main
struct coorditApp: App {
    init() {
        CoorditFontRegistration.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
#endif
