import SwiftUI

#if os(iOS)
struct CoorditLinkPasteButton: View {
    @Binding var text: String
    let metrics: CoorditResponsiveMetrics

    var body: some View {
        PasteButton(payloadType: String.self) { values in
            guard let value = values.first else { return }
            text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .labelStyle(.titleAndIcon)
        .tint(CoorditFitLabPalette.ink)
        .buttonBorderShape(.roundedRectangle(radius: metrics.value(7)))
        .controlSize(.large)
        .fixedSize(horizontal: true, vertical: false)
        .frame(minHeight: 44)
        .accessibilityLabel("링크 붙여넣기")
    }
}

struct CoorditLinkInputRow<Field: View>: View {
    @Binding var text: String
    let metrics: CoorditResponsiveMetrics
    let pasteIdentifier: String
    @ViewBuilder let field: () -> Field

    var body: some View {
        HStack(spacing: metrics.value(8)) {
            Image(systemName: "link")
                .font(.system(size: metrics.value(16), weight: .medium))
                .foregroundStyle(CoorditFitLabPalette.muted)
                .accessibilityHidden(true)
            field()
                .font(CoorditTypography.gmarketMedium(size: metrics.value(12), relativeTo: .body))
                .frame(maxWidth: .infinity, minHeight: 44)
            CoorditLinkPasteButton(text: $text, metrics: metrics)
                .accessibilityIdentifier(pasteIdentifier)
        }
        .padding(.leading, metrics.value(12))
        .padding(.trailing, metrics.value(5))
        .padding(.vertical, metrics.value(5))
        .background(CoorditFitLabPalette.field, in: RoundedRectangle(cornerRadius: metrics.value(10)))
        .overlay {
            RoundedRectangle(cornerRadius: metrics.value(10))
                .stroke(CoorditFitLabPalette.ink.opacity(0.08), lineWidth: 1)
        }
    }
}
#endif
