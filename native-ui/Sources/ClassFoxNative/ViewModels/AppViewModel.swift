import AppKit
import Combine
import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    enum PanelState: Equatable {
        case compact
        case expanded
        case settings
    }

    @Published var isMonitoring = false
    @Published var isPaused = false
    @Published var isLoading = false
    @Published var isConnected = false
    @Published var activeCourseName = ""
    @Published var backendStatus = "Connecting backend..."
    @Published var panelState: PanelState = .compact
    @Published var styleSettings: UIStyleSettings
    @Published var settingsDraft = ""
    @Published var settingsPath = ""
    @Published var citeFiles: [CiteFileItem] = []
    @Published var selectedCiteFilename = ""
    @Published var lastAlert: AlertMessage?
    @Published var alertActive = false
    @Published var notice = ""

    let apiClient: BackendAPIClient
    let alertClient: AlertWebSocketClient
    let preferencesStore: PreferencesStore

    init(
        apiClient: BackendAPIClient = .shared,
        alertClient: AlertWebSocketClient = AlertWebSocketClient(),
        preferencesStore: PreferencesStore = .shared
    ) {
        self.apiClient = apiClient
        self.alertClient = alertClient
        self.preferencesStore = preferencesStore
        self.styleSettings = preferencesStore.load()

        alertClient.onAlert = { [weak self] alert in
            guard let self else {
                return
            }
            self.lastAlert = alert
            self.alertActive = true
        }

        alertClient.onConnectionChange = { [weak self] connected in
            self?.isConnected = connected
        }
    }

    var preferredWindowSize: NSSize {
        switch panelState {
        case .compact:
            return alertActive ? NSSize(width: 320, height: 160) : NSSize(width: 320, height: 80)
        case .expanded:
            return NSSize(width: 320, height: 220)
        case .settings:
            return NSSize(width: 520, height: 620)
        }
    }

    func onAppear() {
        Task {
            await refreshHealth()
        }
    }

    func toggleExpanded() {
        panelState = panelState == .expanded ? .compact : .expanded
    }

    func openSettings() {
        panelState = .settings
        Task {
            await loadSettings()
            await loadCiteFiles()
        }
    }

    func closeSettings() {
        panelState = .compact
    }

    func dismissAlert() {
        alertActive = false
    }

    func persistStyleSettings() {
        preferencesStore.save(styleSettings)
    }

    func refreshHealth() async {
        do {
            let response = try await apiClient.healthCheck()
            backendStatus = "Backend \(response.status)"
        } catch {
            backendStatus = "Backend unavailable"
            notice = error.localizedDescription
        }
    }

    func startMonitoring() {
        Task {
            isLoading = true
            defer { isLoading = false }

            do {
                let response = try await apiClient.startMonitor(
                    payload: StartMonitorPayload(
                        course_name: activeCourseName.trimmingCharacters(in: .whitespacesAndNewlines),
                        cite_filename: selectedCiteFilename.isEmpty ? nil : selectedCiteFilename
                    )
                )
                isMonitoring = true
                isPaused = false
                alertClient.connect()
                notice = response.message
                panelState = .compact
            } catch {
                notice = error.localizedDescription
            }
        }
    }

    func togglePause() {
        Task {
            isLoading = true
            defer { isLoading = false }

            do {
                if isPaused {
                    let response = try await apiClient.resumeMonitor()
                    isPaused = false
                    alertClient.connect()
                    notice = response.message
                } else {
                    let response = try await apiClient.pauseMonitor()
                    isPaused = true
                    alertClient.disconnect()
                    notice = response.message
                }
            } catch {
                notice = error.localizedDescription
            }
        }
    }

    func stopMonitoring() {
        Task {
            isLoading = true
            defer { isLoading = false }

            do {
                let response = try await apiClient.stopMonitor()
                isMonitoring = false
                isPaused = false
                alertClient.disconnect()
                notice = response.message
                activeCourseName = ""
            } catch {
                notice = error.localizedDescription
            }
        }
    }

    func loadSettings() async {
        do {
            let response = try await apiClient.getSettings()
            settingsDraft = response.content
            settingsPath = response.path
        } catch {
            notice = error.localizedDescription
        }
    }

    func saveSettings() {
        Task {
            isLoading = true
            defer { isLoading = false }

            do {
                let response = try await apiClient.saveSettings(content: settingsDraft)
                persistStyleSettings()
                notice = response.message
                panelState = .compact
            } catch {
                notice = error.localizedDescription
            }
        }
    }

    func loadCiteFiles() async {
        do {
            let response = try await apiClient.getCiteFiles()
            citeFiles = response.items
        } catch {
            notice = error.localizedDescription
        }
    }
}
