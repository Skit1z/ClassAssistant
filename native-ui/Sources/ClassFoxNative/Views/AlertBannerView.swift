import SwiftUI

struct AlertBannerView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let alert: AlertMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Live alert", systemImage: "bell.badge.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Button("Dismiss") {
                    viewModel.dismissAlert()
                }
                .buttonStyle(.plain)
                .foregroundColor(Color.white.opacity(0.75))
            }

            Text(alert.keywords.joined(separator: ", "))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.7))

            Text(alert.text)
                .font(.system(size: 12))
                .foregroundColor(.white)
                .lineLimit(3)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.red.opacity(0.24))
        )
    }
}
