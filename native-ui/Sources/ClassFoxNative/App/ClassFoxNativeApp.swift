import SwiftUI

@main
struct ClassFoxNativeApp: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(viewModel)
                .background(
                    WindowAccessor { window in
                        WindowCoordinator.shared.bind(window: window, to: viewModel)
                    }
                )
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
