import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("System settings")
                        .font(.system(size: 22 * viewModel.styleSettings.fontScale, weight: .bold))
                        .foregroundColor(.white)

                    Text(viewModel.settingsPath.isEmpty ? "Backend settings path unavailable" : viewModel.settingsPath)
                        .font(.system(size: 11 * viewModel.styleSettings.fontScale))
                        .foregroundColor(Color.white.opacity(0.5))
                        .lineLimit(1)
                }

                Spacer()
            }

            HStack(spacing: 12) {
                Picker("Theme", selection: $viewModel.styleSettings.backgroundPreset) {
                    ForEach(BackgroundPreset.allCases) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 140)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Radius \(Int(viewModel.styleSettings.windowRadius))")
                        .foregroundColor(Color.white.opacity(0.8))
                    Slider(value: $viewModel.styleSettings.windowRadius, in: 10...28, step: 1)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Opacity \(Int(viewModel.styleSettings.shellOpacity * 100))%")
                        .foregroundColor(Color.white.opacity(0.8))
                    Slider(value: $viewModel.styleSettings.shellOpacity, in: 0.55...0.95)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Raw backend config")
                    .font(.system(size: 13 * viewModel.styleSettings.fontScale, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.92))

                TextEditor(text: $viewModel.settingsDraft)
                    .font(.system(size: 12 * viewModel.styleSettings.fontScale, weight: .regular, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.black.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .frame(minHeight: 300)
            }

            HStack {
                Spacer()

                Button("Cancel") {
                    viewModel.closeSettings()
                }
                .buttonStyle(SecondaryCapsuleButtonStyle())

                Button("Save settings") {
                    viewModel.persistStyleSettings()
                    viewModel.saveSettings()
                }
                .buttonStyle(PrimaryCapsuleButtonStyle())
            }
        }
        .padding(18)
    }
}
