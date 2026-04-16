import SwiftUI

struct StatusBannerView: View {
    let message: UserMessage?

    var body: some View {
        if let message {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbolName(for: message.kind))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(foregroundColor(for: message.kind))
                    .frame(width: 24, alignment: .center)
                    .accessibilityHidden(true)

                Text(message.text)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(backgroundColor(for: message.kind))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(foregroundColor(for: message.kind).opacity(0.22), lineWidth: 1)
                    }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func symbolName(for kind: UserMessage.Kind) -> String {
        switch kind {
        case .info:
            return "info.circle.fill"
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.octagon.fill"
        }
    }

    private func backgroundColor(for kind: UserMessage.Kind) -> Color {
        switch kind {
        case .info:
            return .blue.opacity(0.12)
        case .success:
            return .green.opacity(0.14)
        case .warning:
            return .orange.opacity(0.14)
        case .error:
            return .red.opacity(0.14)
        }
    }

    private func foregroundColor(for kind: UserMessage.Kind) -> Color {
        switch kind {
        case .info:
            return .blue
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}
