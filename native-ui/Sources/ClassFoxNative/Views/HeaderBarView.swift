import SwiftUI

struct HeaderBarView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "fox.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("ClassFox Native")
                        .font(.system(size: 16 * viewModel.styleSettings.fontScale, weight: .semibold))
                        .foregroundColor(.white)

                    Circle()
                        .fill(statusColor)
                        .frame(width: 7, height: 7)
                }

                Text(viewModel.backendStatus)
                    .font(.system(size: 11 * viewModel.styleSettings.fontScale))
                    .foregroundColor(Color.white.opacity(0.6))
            }

            Spacer(minLength: 8)

            if !viewModel.notice.isEmpty {
                Text(viewModel.notice)
                    .lineLimit(1)
                    .font(.system(size: 11 * viewModel.styleSettings.fontScale))
                    .foregroundColor(Color.white.opacity(0.7))
                    .frame(maxWidth: 180, alignment: .trailing)
            }
        }
    }

    private var statusColor: Color {
        if viewModel.alertActive {
            return .red
        }
        if viewModel.isMonitoring && !viewModel.isPaused {
            return .green
        }
        if viewModel.isPaused {
            return .yellow
        }
        return viewModel.isConnected ? Color(red: 0.29, green: 0.79, blue: 0.94) : .gray
    }
}
