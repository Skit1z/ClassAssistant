import SwiftUI

struct MainControlView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 10) {
            if viewModel.isMonitoring {
                monitoringControls
            } else {
                idleControls
            }

            if viewModel.panelState == .expanded {
                expandedActions
            }
        }
    }

    private var idleControls: some View {
        HStack(spacing: 10) {
            TextField("Course name", text: $viewModel.activeCourseName)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .frame(height: 40)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .foregroundColor(.white)

            Button(action: viewModel.startMonitoring) {
                label(icon: "dot.radiowaves.left.and.right", text: viewModel.isLoading ? "Starting" : "Start")
            }
            .buttonStyle(PrimaryCapsuleButtonStyle())
            .disabled(viewModel.isLoading)

            Button(action: viewModel.toggleExpanded) {
                label(icon: "ellipsis.circle", text: "More")
            }
            .buttonStyle(SecondaryCapsuleButtonStyle())
        }
    }

    private var monitoringControls: some View {
        HStack(spacing: 10) {
            Button(action: viewModel.togglePause) {
                label(icon: viewModel.isPaused ? "play.fill" : "pause.fill", text: viewModel.isPaused ? "Resume" : "Pause")
            }
            .buttonStyle(SecondaryCapsuleButtonStyle())

            Button(action: viewModel.stopMonitoring) {
                label(icon: "stop.fill", text: "Stop")
            }
            .buttonStyle(DangerCapsuleButtonStyle())

            Button(action: viewModel.toggleExpanded) {
                label(icon: "slider.horizontal.3", text: "More")
            }
            .buttonStyle(SecondaryCapsuleButtonStyle())
        }
    }

    private var expandedActions: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button(action: {
                    Task {
                        await viewModel.refreshHealth()
                    }
                }) {
                    label(icon: "wave.3.right", text: "Ping backend")
                }
                .buttonStyle(FeatureButtonStyle())

                Button(action: viewModel.openSettings) {
                    label(icon: "gearshape.2.fill", text: "Settings")
                }
                .buttonStyle(FeatureButtonStyle())
            }

            if !viewModel.citeFiles.isEmpty {
                Picker("Reference", selection: $viewModel.selectedCiteFilename) {
                    Text("No cite file").tag("")
                    ForEach(viewModel.citeFiles) { item in
                        Text(item.filename).tag(item.filename)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
        }
    }

    private func label(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.system(size: 13 * viewModel.styleSettings.fontScale, weight: .semibold))
        .frame(minWidth: 72)
    }
}

struct PrimaryCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(red: 0.19, green: 0.74, blue: 0.86).opacity(configuration.isPressed ? 0.22 : 0.30))
            )
    }
}

struct SecondaryCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(Color.white.opacity(0.92))
            .padding(.horizontal, 16)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.10 : 0.14))
            )
    }
}

struct DangerCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.red.opacity(configuration.isPressed ? 0.25 : 0.34))
            )
    }
}

struct FeatureButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.black.opacity(configuration.isPressed ? 0.18 : 0.28))
            )
    }
}
