import SwiftUI

#if os(iOS)
import UIKit

struct CoorditHomeReferenceCard: View {
    let items: [CoorditClosetItem]
    let selectedIDs: Set<String>
    let metrics: CoorditResponsiveMetrics
    let onSelect: () -> Void

    private var previewItems: [CoorditClosetItem] {
        let selected = items.filter { selectedIDs.contains($0.id) }
        return Array((selected.isEmpty ? items : selected).prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.value(9)) {
            HStack(alignment: .top, spacing: metrics.value(10)) {
                VStack(alignment: .leading, spacing: metrics.value(3)) {
                    Text("기준 의류")
                        .font(CoorditTypography.gmarketBold(size: metrics.value(14)))
                        .foregroundStyle(CoorditHomeReferencePalette.ink)
                    Text(statusText)
                        .font(CoorditTypography.gmarketMedium(size: metrics.value(9.5)))
                        .foregroundStyle(CoorditHomeReferencePalette.ink.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Button(selectedIDs.isEmpty ? "옷장에서 선택" : "다시 선택", action: onSelect)
                    .font(CoorditTypography.gmarketBold(size: metrics.value(9.5)))
                    .foregroundStyle(.white)
                    .padding(.horizontal, metrics.value(11))
                    .frame(height: metrics.value(36))
                    .background(CoorditHomeReferencePalette.ink)
                    .clipShape(Capsule())
                    .coorditPressFeedback()
                    .accessibilityIdentifier("home-reference-select")
            }

            if !previewItems.isEmpty {
                HStack(spacing: metrics.value(8)) {
                    ForEach(previewItems) { item in
                        HStack(spacing: metrics.value(6)) {
                            CoorditHomeReferenceThumbnail(item: item, metrics: metrics)
                                .frame(width: metrics.value(34), height: metrics.value(46))
                            VStack(alignment: .leading, spacing: metrics.value(2)) {
                                Text(item.name)
                                    .font(CoorditTypography.gmarketBold(size: metrics.value(8.5)))
                                    .lineLimit(1)
                                Text(item.exactCategory.koreanTitle)
                                    .font(CoorditTypography.gmarketMedium(size: metrics.value(7.5)))
                                    .foregroundStyle(CoorditHomeReferencePalette.ink.opacity(0.48))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("home-reference-preview-\(item.id)")
                    }
                }
            }
        }
        .padding(metrics.value(CoorditDesignTokens.HomeReferenceMetrics.cardPadding))
        .frame(width: metrics.value(CoorditDesignTokens.HomeReferenceMetrics.cardWidth), alignment: .topLeading)
        .background(CoorditDesignTokens.ColorToken.panel)
        .clipShape(RoundedRectangle(cornerRadius: metrics.value(CoorditDesignTokens.HomeReferenceMetrics.cardRadius), style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: metrics.value(CoorditDesignTokens.HomeReferenceMetrics.cardRadius), style: .continuous)
                .stroke(CoorditHomeReferencePalette.ink.opacity(0.08), lineWidth: metrics.value(0.8))
        }
        .accessibilityIdentifier("home-reference-card")
    }

    private var statusText: String {
        if items.isEmpty { return "옷장에 의류를 추가한 뒤 기준 옷으로 선택할 수 있어요." }
        if selectedIDs.isEmpty { return "등록된 상·하의 \(items.count)개 중 잘 맞는 옷을 골라주세요." }
        return "선택한 기준 의류 \(selectedIDs.count)개를 핏 계산에 사용해요."
    }
}

struct CoorditHomeReferenceSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let items: [CoorditClosetItem]
    let initialSelection: Set<String>
    let onCommit: (Set<String>) -> Void
    let onAddGarment: () -> Void

    @State private var selection: Set<String>

    init(
        items: [CoorditClosetItem],
        initialSelection: Set<String>,
        onCommit: @escaping (Set<String>) -> Void,
        onAddGarment: @escaping () -> Void
    ) {
        self.items = items
        self.initialSelection = initialSelection
        self.onCommit = onCommit
        self.onAddGarment = onAddGarment
        _selection = State(initialValue: initialSelection.intersection(Set(items.map(\.id))))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CoorditDesignTokens.HomeReferenceMetrics.sectionSpacing) {
                    Text("상의와 하의에서 실제로 잘 맞는 옷을 여러 개 선택할 수 있어요.")
                        .font(CoorditTypography.gmarketMedium(size: CoorditDesignTokens.HomeReferenceMetrics.introFontSize))
                        .foregroundStyle(CoorditHomeReferencePalette.ink.opacity(0.58))

                    if items.isEmpty {
                        emptyPanel
                    } else {
                        group(.top)
                        group(.bottom)

                        Button("새 의류 등록하기") {
                            dismiss()
                            onAddGarment()
                        }
                        .font(CoorditTypography.gmarketBold(size: CoorditDesignTokens.HomeReferenceMetrics.actionFontSize))
                        .foregroundStyle(CoorditHomeReferencePalette.ink)
                        .frame(maxWidth: .infinity, minHeight: CoorditDesignTokens.HomeReferenceMetrics.actionHeight)
                        .background(CoorditDesignTokens.ColorToken.panel)
                        .clipShape(RoundedRectangle(cornerRadius: CoorditDesignTokens.HomeReferenceMetrics.actionRadius))
                        .coorditPressFeedback()
                    }
                }
                .padding(CoorditDesignTokens.HomeReferenceMetrics.sheetPadding)
            }
            .background(CoorditDesignTokens.ColorToken.appBackground)
            .navigationTitle("기준 의류")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("선택 완료") {
                        onCommit(selection)
                        dismiss()
                    }
                    .disabled(items.isEmpty)
                    .accessibilityIdentifier("home-reference-done")
                }
            }
        }
    }

    private func group(_ category: CoorditClosetCategory) -> some View {
        let categoryItems = items.filter { $0.category == category }
        return VStack(alignment: .leading, spacing: CoorditDesignTokens.HomeReferenceMetrics.groupRowSpacing) {
            Text(category.title)
                .font(CoorditTypography.gmarketBold(size: CoorditDesignTokens.HomeReferenceMetrics.groupTitleFontSize))
            if categoryItems.isEmpty {
                Text("등록된 \(category.title) 의류가 없어요.")
                    .font(CoorditTypography.gmarketMedium(size: CoorditDesignTokens.HomeReferenceMetrics.emptyTextFontSize))
                    .foregroundStyle(CoorditHomeReferencePalette.ink.opacity(0.48))
                    .padding(.vertical, CoorditDesignTokens.HomeReferenceMetrics.emptyTextVerticalPadding)
            } else {
                ForEach(categoryItems) { item in
                    referenceRow(item)
                }
            }
        }
        .padding(CoorditDesignTokens.HomeReferenceMetrics.sectionSpacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CoorditDesignTokens.ColorToken.panel)
        .clipShape(RoundedRectangle(cornerRadius: CoorditDesignTokens.HomeReferenceMetrics.sectionRadius))
    }

    private func referenceRow(_ item: CoorditClosetItem) -> some View {
        let selected = selection.contains(item.id)
        return Button {
            if selected { selection.remove(item.id) } else { selection.insert(item.id) }
        } label: {
            HStack(spacing: CoorditDesignTokens.HomeReferenceMetrics.rowSpacing) {
                CoorditHomeReferenceThumbnail(
                    item: item,
                    metrics: CoorditResponsiveMetrics(size: CGSize(width: 402, height: 874))
                )
                .frame(
                    width: CoorditDesignTokens.HomeReferenceMetrics.thumbnailWidth,
                    height: CoorditDesignTokens.HomeReferenceMetrics.thumbnailHeight
                )
                VStack(alignment: .leading, spacing: CoorditDesignTokens.HomeReferenceMetrics.rowTextSpacing) {
                    Text(item.name)
                        .font(CoorditTypography.gmarketBold(size: CoorditDesignTokens.HomeReferenceMetrics.rowTitleFontSize))
                    Text("\(item.category.title) · \(item.exactCategory.koreanTitle)")
                        .font(CoorditTypography.gmarketMedium(size: CoorditDesignTokens.HomeReferenceMetrics.rowSubtitleFontSize))
                        .foregroundStyle(CoorditHomeReferencePalette.ink.opacity(0.52))
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: CoorditDesignTokens.HomeReferenceMetrics.rowIconSize, weight: .semibold))
            }
            .foregroundStyle(CoorditHomeReferencePalette.ink)
            .padding(.horizontal, CoorditDesignTokens.HomeReferenceMetrics.rowHorizontalPadding)
            .frame(maxWidth: .infinity, minHeight: CoorditDesignTokens.HomeReferenceMetrics.rowHeight)
            .background(selected ? CoorditDesignTokens.ColorToken.closetField : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: CoorditDesignTokens.HomeReferenceMetrics.rowRadius))
        }
        .coorditPressFeedback()
        .accessibilityIdentifier("home-reference-item-\(item.id)")
    }

    private var emptyPanel: some View {
        VStack(spacing: CoorditDesignTokens.HomeReferenceMetrics.emptyPanelSpacing) {
            Image(systemName: "hanger")
                .font(.system(size: CoorditDesignTokens.HomeReferenceMetrics.emptyIconSize, weight: .medium))
            Text("아직 옷장에 등록된 의류가 없어요.")
                .font(CoorditTypography.gmarketBold(size: CoorditDesignTokens.HomeReferenceMetrics.groupTitleFontSize))
            Button("새 의류 등록하기") {
                dismiss()
                onAddGarment()
            }
            .font(CoorditTypography.gmarketBold(size: CoorditDesignTokens.HomeReferenceMetrics.actionFontSize))
            .foregroundStyle(.white)
            .padding(.horizontal, CoorditDesignTokens.HomeReferenceMetrics.sheetPadding)
            .frame(height: CoorditDesignTokens.HomeReferenceMetrics.actionHeight)
            .background(CoorditHomeReferencePalette.ink)
            .clipShape(RoundedRectangle(cornerRadius: CoorditDesignTokens.HomeReferenceMetrics.actionRadius))
            .coorditPressFeedback()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CoorditDesignTokens.HomeReferenceMetrics.emptyPanelVerticalPadding)
        .background(CoorditDesignTokens.ColorToken.panel)
        .clipShape(RoundedRectangle(cornerRadius: CoorditDesignTokens.HomeReferenceMetrics.sectionRadius))
    }
}

private struct CoorditHomeReferenceThumbnail: View {
    let item: CoorditClosetItem
    let metrics: CoorditResponsiveMetrics

    var body: some View {
        CoorditClosetGarmentArtwork(imageData: item.imageData, category: item.category, metrics: metrics)
    }
}

private enum CoorditHomeReferencePalette {
    static let ink = CoorditDesignTokens.ColorToken.ink
}
#endif
