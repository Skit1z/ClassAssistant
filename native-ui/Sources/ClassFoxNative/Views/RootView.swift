import SwiftUI

struct RootView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        ZStack {
            backgroundView

            VStack(spacing: 12) {
                HeaderBarView()

                if viewModel.panelState == .settings {
                    SettingsView()
                } else {
                    MainControlView()
                }

                if viewModel.alertActive, let alert = viewModel.lastAlert {
                    AlertBannerView(alert: alert)
                }
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            viewModel.onAppear()
        }
    }

    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: viewModel.styleSettings.windowRadius, style: .continuous)
            .fill(backgroundGradient)
            .opacity(viewModel.styleSettings.shellOpacity)
            .overlay(
                RoundedRectangle(cornerRadius: viewModel.styleSettings.windowRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 28, x: 0, y: 18)
            .padding(1)
    }

    private var backgroundGradient: LinearGradient {
        switch viewModel.styleSettings.backgroundPreset {
        case .ocean:
            return LinearGradient(
                colors: [Color(red: 0.02, green: 0.08, blue: 0.18), Color(red: 0.03, green: 0.16, blue: 0.29)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .sunset:
            return LinearGradient(
                colors: [Color(red: 0.19, green: 0.08, blue: 0.09), Color(red: 0.39, green: 0.13, blue: 0.14)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .forest:
            return LinearGradient(
                colors: [Color(red: 0.03, green: 0.10, blue: 0.07), Color(red: 0.04, green: 0.20, blue: 0.14)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .slate:
            return LinearGradient(
                colors: [Color(red: 0.08, green: 0.11, blue: 0.18), Color(red: 0.16, green: 0.20, blue: 0.30)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
