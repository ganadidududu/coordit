import SwiftUI

#if os(iOS)
struct CoorditFitLabReferencePicker: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var coordinator: CoorditFitLabCoordinator
    let reload: () async -> Void
    let register: () -> Void
    @State private var selectedIDs: Set<String>

    init(coordinator: CoorditFitLabCoordinator, reload: @escaping () async -> Void, register: @escaping () -> Void) {
        self.coordinator = coordinator
        self.reload = reload
        self.register = register
        _selectedIDs = State(initialValue: coordinator.draft.selectedReferenceIDs)
    }

    private var available: [CoorditFitLabReferenceRow] {
        coordinator.references.filter { $0.isActive && $0.category.isCompatible(with: coordinator.draft.category) }
    }
    private var validSelection: Set<String> { selectedIDs.intersection(available.map(\.id)) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("비교할 내 옷 고르기")
                    .font(CoorditTypography.gmarketBold(size: 20, relativeTo: .title2))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").font(.title2)
                }
                .frame(width: 44, height: 44)
                .accessibilityLabel("옷 선택 취소")
                .accessibilityIdentifier("fitlab-reference-picker-close")
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("평소 잘 맞는 옷을 골라주세요. 여러 벌을 선택할 수도 있어요.")
                        .font(CoorditTypography.gmarketMedium(size: 13, relativeTo: .body))
                        .fixedSize(horizontal: false, vertical: true)
                    if coordinator.loadState == .loading {
                        ProgressView("옷장을 불러오는 중이에요")
                    } else if available.isEmpty {
                        Text("비교할 옷이 아직 없어요. 이 상품과 비슷한 종류의 옷을 먼저 등록해주세요.")
                            .font(CoorditTypography.gmarketMedium(size: 14, relativeTo: .body))
                            .padding(.vertical, 24)
                            .accessibilityIdentifier("fitlab-reference-picker-empty")
                        if coordinator.error != nil {
                            Button("다시 불러오기") { Task { await reload() } }
                                .buttonStyle(CoorditContentActionButtonStyle(prominence: .secondary))
                        }
                        if !coordinator.draft.isTutorialExample {
                            Button("내 옷 링크로 등록") { dismiss(); register() }
                                .buttonStyle(CoorditContentActionButtonStyle(prominence: .primary))
                                .accessibilityIdentifier("fitlab-reference-picker-register")
                        }
                    } else {
                        ForEach(available) { reference in
                            Button {
                                if selectedIDs.contains(reference.id) { selectedIDs.remove(reference.id) }
                                else { selectedIDs.insert(reference.id) }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: selectedIDs.contains(reference.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.title2)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(reference.nickname ?? "기준 옷")
                                            .font(CoorditTypography.gmarketBold(size: 14, relativeTo: .body))
                                        Text("\(reference.category.koreanTitle) · \(reference.fitType)")
                                            .font(CoorditTypography.gmarketMedium(size: 12, relativeTo: .caption))
                                    }
                                    Spacer()
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                                .background(selectedIDs.contains(reference.id) ? CoorditFitLabPalette.empty : CoorditFitLabPalette.field, in: RoundedRectangle(cornerRadius: 12))
                            }
                            .coorditPressFeedback()
                            .accessibilityIdentifier("fitlab-reference-\(reference.id)")
                            .accessibilityValue(selectedIDs.contains(reference.id) ? "선택됨" : "선택 안 됨")
                        }
                    }
                }
                .padding(22)
            }
            VStack(spacing: 10) {
                Button("선택 완료 · \(validSelection.count)벌") {
                    for reference in available where coordinator.draft.selectedReferenceIDs.contains(reference.id) != validSelection.contains(reference.id) {
                        coordinator.toggleReference(reference)
                    }
                    dismiss()
                }
                .buttonStyle(CoorditContentActionButtonStyle(prominence: .primary, height: 52))
                .disabled(validSelection.isEmpty || coordinator.loadState == .loading)
                .accessibilityIdentifier("fitlab-reference-picker-done")
                Text("옷을 고르는 단계에서는 실타래를 사용하지 않아요.")
                    .font(CoorditTypography.gmarketMedium(size: 11, relativeTo: .caption))
                    .foregroundStyle(CoorditFitLabPalette.muted)
            }
            .padding(22)
        }
        .foregroundStyle(CoorditFitLabPalette.ink)
        .background(CoorditFitLabPalette.surface)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("fitlab-reference-picker")
    }
}
#endif
