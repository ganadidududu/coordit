import SwiftUI

#if os(iOS)
struct CoorditGarmentCategorySelector: View {
    @Binding var kind: CoorditFitLabGarmentKind
    @Binding var category: CoorditFitLabCategory
    let metrics: CoorditResponsiveMetrics
    let identifier: String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showsCategories = false
    @State private var pendingCategory: CoorditFitLabCategory?

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.value(12)) {
            Text("옷 종류")
                .font(CoorditTypography.gmarketBold(size: metrics.value(15), relativeTo: .headline))
            HStack(spacing: metrics.value(6)) {
                kindButton(.upper, title: "상의")
                kindButton(.lower, title: "하의")
            }
            .padding(4)
            .background(CoorditFitLabPalette.field, in: Capsule())
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("\(identifier)-kind-picker")

            Button { showsCategories = true } label: {
                HStack(spacing: metrics.value(12)) {
                    Text("품목")
                        .font(CoorditTypography.gmarketMedium(size: metrics.value(12), relativeTo: .body))
                        .foregroundStyle(CoorditFitLabPalette.muted)
                    Spacer(minLength: 8)
                    Text(category.koreanTitle)
                        .font(CoorditTypography.gmarketMedium(size: metrics.value(14), relativeTo: .body))
                        .fixedSize(horizontal: false, vertical: true)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                }
                .padding(.horizontal, metrics.value(14))
                .padding(.vertical, metrics.value(6))
                .frame(minHeight: 52)
                .background(CoorditFitLabPalette.field, in: RoundedRectangle(cornerRadius: metrics.value(8)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("품목 선택")
            .accessibilityValue(category.koreanTitle)
            .accessibilityIdentifier("\(identifier)-category-picker")
        }
        .foregroundStyle(CoorditFitLabPalette.ink)
        .padding(metrics.value(14))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CoorditFitLabPalette.surface, in: RoundedRectangle(cornerRadius: metrics.value(9)))
        .overlay(RoundedRectangle(cornerRadius: metrics.value(9)).stroke(CoorditFitLabPalette.ink.opacity(0.07), lineWidth: 0.8))
        .sheet(isPresented: $showsCategories, onDismiss: {
            guard let selection = pendingCategory else { return }
            pendingCategory = nil
            category = selection
        }) {
            CoorditGarmentCategorySheet(kind: kind, selected: category, identifier: identifier) {
                pendingCategory = $0
            }
            .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.height(540), .large])
            .presentationDragIndicator(.visible)
        }
    }

    private func kindButton(_ option: CoorditFitLabGarmentKind, title: String) -> some View {
        Button { kind = option } label: {
            Text(title)
                .font(CoorditTypography.gmarketMedium(size: metrics.value(13), relativeTo: .body))
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(kind == option ? .white : CoorditFitLabPalette.ink)
                .background(kind == option ? CoorditFitLabPalette.ink : .clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(kind == option ? .isSelected : [])
        .accessibilityIdentifier("\(identifier)-kind-\(option.rawValue)")
    }
}

private struct CoorditGarmentCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    let kind: CoorditFitLabGarmentKind
    let selected: CoorditFitLabCategory
    let identifier: String
    let onSelect: (CoorditFitLabCategory) -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(kind == .upper ? "상의 품목" : "하의 품목")
                    .font(CoorditTypography.gmarketBold(size: 22, relativeTo: .title2))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .background(CoorditFitLabPalette.field, in: Circle())
                }
                .accessibilityLabel("품목 선택 닫기")
                .accessibilityIdentifier("category-sheet-close")
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(CoorditFitLabCategory.allCases.filter { $0.garmentKind == kind }) { option in
                        Button {
                            onSelect(option)
                            dismiss()
                        } label: {
                            HStack {
                                Text(option.koreanTitle)
                                    .font(CoorditTypography.gmarketMedium(size: 16, relativeTo: .body))
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 12)
                                if selected == option {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .frame(minHeight: 48)
                            .background(selected == option ? CoorditFitLabPalette.field : .clear, in: RoundedRectangle(cornerRadius: 10))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected == option ? .isSelected : [])
                        .accessibilityIdentifier("\(identifier)-category-\(option.rawValue)")
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .foregroundStyle(CoorditFitLabPalette.ink)
        .background(CoorditFitLabPalette.surface)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("category-sheet")
    }
}
#endif
