import SwiftUI

struct ContentView: View {
    var body: some View {
        Group {
            #if os(iOS)
            #if DEBUG
            if CoorditARFieldTestMode.enabled {
                CoorditARFieldTestScreen()
            } else {
                CoorditRootView()
            }
            #else
            CoorditRootView()
            #endif
            #else
            EmptyView()
            #endif
        }
#if os(iOS)
            .statusBarHidden(true)
            .persistentSystemOverlays(.hidden)
#endif
    }
}
