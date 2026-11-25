import SwiftUI

/// 쇼핑앱 "공유하기"로 복사하면 링크 앞뒤에 상품명 같은 문구가 붙어 온다(지그재그 등).
/// 그 안에서 http(s) 주소만 꺼낸다. 주소가 없으면 앞뒤 공백만 정리해 그대로 돌려준다.
enum CoorditProductLinkText {
    static func extract(from input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let start = trimmed.range(of: "https://", options: .caseInsensitive)?.lowerBound
                ?? trimmed.range(of: "http://", options: .caseInsensitive)?.lowerBound
        else { return trimmed }
        let tail = trimmed[start...]
        let end = tail.firstIndex(where: { $0.isWhitespace || $0.isNewline }) ?? tail.endIndex
        return String(tail[..<end])
    }
}

#if os(iOS)
struct CoorditLinkPasteButton: View {
    @Binding var text: String
    let metrics: CoorditResponsiveMetrics

    var body: some View {
        PasteButton(payloadType: String.self) { values in
            guard let value = values.first else { return }
            text = CoorditProductLinkText.extract(from: value)
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
