import SwiftUI

struct ContentView: View {
    var body: some View {
        Group {
            #if os(iOS)
            CoorditRootView()
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
