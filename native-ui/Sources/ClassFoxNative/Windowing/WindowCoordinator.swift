import AppKit
import Combine

@MainActor
final class WindowCoordinator {
    static let shared = WindowCoordinator()

    private weak var window: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    func bind(window: NSWindow, to viewModel: AppViewModel) {
        if self.window !== window {
            self.window = window
            configureBaseWindow(window)
        }

        if cancellables.isEmpty {
            viewModel.$panelState
                .combineLatest(viewModel.$alertActive)
                .sink { [weak self, weak viewModel] _, _ in
                    guard let self, let viewModel else {
                        return
                    }
                    self.applyLayout(for: viewModel)
                }
                .store(in: &cancellables)

            viewModel.$styleSettings
                .sink { [weak self] _ in
                    self?.window?.invalidateShadow()
                }
                .store(in: &cancellables)
        }

        applyLayout(for: viewModel)
    }

    private func configureBaseWindow(_ window: NSWindow) {
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.standardWindowButton(.zoomButton)?.isHidden = true
    }

    private func applyLayout(for viewModel: AppViewModel) {
        guard let window else {
            return
        }

        let targetSize = viewModel.preferredWindowSize
        if window.contentLayoutRect.size != targetSize {
            window.setContentSize(targetSize)
        }

        window.minSize = targetSize
        window.maxSize = targetSize
    }
}
