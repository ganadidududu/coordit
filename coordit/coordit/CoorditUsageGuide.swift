import SwiftUI

#if os(iOS)
enum CoorditUsageGuide: String, Identifiable {
    case fitLab, fitLabReferences, closet
    var id: Self { self }
    var title: String {
        switch self {
        case .fitLab: "핏 랩 사용법"
        case .fitLabReferences: "내 옷과 비교하는 방법"
        case .closet: "옷장 사용법"
        }
    }
    struct Topic: Identifiable {
        let id: String
        let title: String
        let body: String
    }
    var introduction: String {
        switch self {
        case .fitLab: "상품 링크로 시작하는 걸 추천해요. 상품명과 여러 사이즈의 치수를 한 번에 가져올 수 있어요."
        case .fitLabReferences: "평소 잘 맞는 내 옷을 기준으로 골라주세요. 새로 등록할 수도 있고, 옷장에 저장한 옷을 그대로 쓸 수도 있어요."
        case .closet: "내가 실제로 가진 옷과 사이즈를 등록하는 공간이에요. 잘 맞는 옷을 저장해두면 핏랩에서 다시 등록할 필요가 없어요."
        }
    }
    var topics: [Topic] {
        switch self {
        case .fitLab:
            [
                .init(id: "link", title: "추천 · 상품 링크로 불러오기", body: "쇼핑몰에서 구매할 옷의 상품 페이지 주소를 복사하고, ‘링크로 불러오기’에서 붙여넣기를 눌러주세요. 상품 정보를 가져온 뒤 옷 종류와 사이즈표가 맞는지 확인해요. 자동으로 찾은 옷 종류가 다르면 직접 바꿀 수 있어요."),
                .init(id: "capture", title: "링크가 없거나 불러오지 못했다면", body: "상품 페이지의 사이즈표를 캡처한 뒤 ‘사이즈표 사진 넣기’에서 사진을 선택해주세요. 옷 사진이 아니라 사이즈명·항목명·숫자가 함께 보이는 표가 필요해요. 긴 표는 글자가 잘 보이게 잘라서 준비하고, 읽어온 숫자와 단위를 확인해주세요."),
                .init(id: "manual", title: "직접 입력하거나 잘못 읽힌 값 고치기", body: "링크를 불러오거나 사이즈표를 읽는 데 실패하면 오류 안내의 ‘직접 입력’에서 상품명, 옷 종류, 사이즈별 실측을 적어주세요. 길이는 cm, 가슴·허리·엉덩이 너비는 단면 기준이에요. 모르는 값은 추측하지 말고 상품 페이지에서 확인해주세요. 무료 리포트의 ‘상품 정보 수정’으로 돌아가서 고칠 수도 있어요."),
                .init(id: "free", title: "무료 리포트에서 알 수 있는 것", body: "상품에 적힌 실측을 바탕으로 사이즈별 너비와 길이 차이, 옷 종류에 따라 볼 부분을 정리해요. 이 단계는 무료이고, 아직 내 몸이나 내 옷에 맞는 사이즈를 추천한 결과는 아니에요. 자세한 숫자는 ‘상세 실측표 펼치기’에서 볼 수 있어요."),
                .init(id: "references", title: "내 옷과 비교 · 기존 옷과 새 옷 중 선택", body: "‘내 옷과 비교하기’를 누른 뒤, 이미 등록한 옷이 있으면 ‘옷장에서 골라 비교’에서 선택해요. 아직 등록하지 않은 내 옷으로 비교하려면 ‘내 옷 링크로 등록’을 눌러주세요. 보유 사이즈를 고르면 내 옷장에도 자동 저장되어 다음 비교에서 다시 쓸 수 있어요. 비교 화면의 사용법에서 두 방법을 자세히 볼 수 있어요."),
                .init(id: "cost", title: "실타래는 언제 쓰고, 결과는 어떻게 보나요?", body: "링크 등록과 무료 리포트, 비교할 옷을 고르는 단계에서는 실타래를 쓰지 않아요. ‘비교하기 · 실타래 1개’를 누르면 사이즈 추천과 상세 리포트를 만들어요. 결과에서 사이즈별 차이를 살펴보고 ‘히스토리에 추가’로 저장해두세요. 최근 리포트는 최신 3개를 먼저 보여주고 전체 보기로 더 볼 수 있어요."),
                .init(id: "camera", title: "카메라로 직접 옷을 재고 싶다면", body: "카메라 측정은 아직 준비 중이에요. 지금은 상품 링크나 사이즈표 캡처를 이용해주세요. 불러오지 못하면 오류 안내에서 직접 입력으로 이어갈 수 있어요. 사이즈표 캡처를 사진 보관함에서 가져오는 기능은 사용할 수 있어요.")
            ]
        case .fitLabReferences:
            [
                .init(id: "existing", title: "이미 옷장에 등록한 옷을 쓸 때", body: "‘옷장에서 골라 비교’를 누르면 선택 팝업이 열려요. 지금 비교할 상품과 같은 종류의 옷 중 평소 잘 맞는 것을 선택하고 ‘선택 완료’를 눌러주세요. 여러 벌이 보이면 이름과 옷 종류를 확인하고 비교에 쓸 옷을 골라요. 목록이 비어 있으면 그 옷 종류로 등록한 기준 옷이 있는지 확인해주세요."),
                .init(id: "new", title: "잘 맞는 옷을 새로 등록할 때", body: "‘내 옷 링크로 등록’을 누르면 옷장 등록 화면으로 이동해요. 구매하려는 새 상품이 아니라 이미 가지고 있는 옷의 링크를 붙여넣어주세요. 실제 보유한 사이즈를 고르고 실측을 확인해 등록하면 그 옷과 보유 사이즈가 내 옷장에 자동 저장되고, 핏랩으로 돌아와 비교를 이어갈 수 있어요. 다음부터는 옷장에서 바로 골라 쓰면 돼요. 상세 비교를 실행하기 전까지 실타래는 사용하지 않아요."),
                .init(id: "no-link", title: "내 옷의 상품 링크가 없을 때", body: "옷장의 옷 추가 화면에서 ‘사이즈표 사진 넣기’를 이용해주세요. 표를 읽지 못하면 오류 안내에서 ‘직접 입력’을 선택할 수 있어요. 보유한 사이즈의 치수를 확인해 저장한 뒤 핏랩으로 돌아와 옷장 선택 팝업에서 고르면 돼요. 카메라로 옷을 직접 측정하는 기능은 준비 중이에요."),
                .init(id: "choose", title: "어떤 옷을 기준으로 고르면 좋나요?", body: "평소 가장 편하게 입는 비슷한 종류의 옷이 좋아요. 너무 크거나 작은 옷을 고르면 그 차이도 비교에 반영돼요. 구매할 상품과 기준 옷의 종류, 보유 사이즈, 단면·둘레 단위가 맞는지 먼저 확인해주세요."),
                .init(id: "charge", title: "비교 버튼을 누르기 전 확인", body: "기준 옷을 선택하면 비교 버튼이 활성화돼요. 옷을 고르거나 새로 등록하는 동안에는 차감하지 않고, ‘비교하기 · 실타래 1개’를 누를 때 실타래를 사용해요. 뒤로가기를 누르면 무료 리포트로 돌아갈 수 있어요.")
            ]
        case .closet:
            [
                .init(id: "link", title: "상품 링크가 있을 때", body: "‘옷 추가’에서 ‘링크로 불러오기’를 선택하고, 내가 가진 옷의 상품 주소를 붙여넣어주세요. 상품과 옷 종류를 확인한 뒤 실제 보유한 사이즈를 선택해요. 이름이 같아도 다른 시즌이나 다른 모델이면 치수가 다를 수 있어요."),
                .init(id: "capture", title: "사이즈표 캡처로 등록할 때", body: "쇼핑몰의 사이즈표를 캡처해 사진 보관함에 저장한 뒤 ‘사이즈표 사진 넣기’로 가져와주세요. 사이즈명과 숫자가 잘 보여야 해요. 읽어온 표에서 내 사이즈를 고르고 누락되거나 잘못 읽힌 치수는 수정해주세요."),
                .init(id: "manual", title: "링크나 사진을 불러오지 못했을 때", body: "오류 안내에서 ‘직접 입력’을 선택한 뒤 이름, 옷 종류와 실측을 넣어주세요. 옷을 평평하게 펼쳐 너비와 길이를 cm로 재면 돼요. 가슴·허리·엉덩이는 둘레가 아닌 단면 너비로 입력하고, 모르는 치수는 임의로 채우지 말아주세요."),
                .init(id: "save", title: "저장하기 전에 확인할 것", body: "내가 가진 사이즈가 선택됐는지, 옷 종류와 실측 단위가 맞는지 확인해주세요. 알아보기 쉬운 이름으로 등록하면 나중에 고르기 편해요. 등록을 마친 뒤 옷 상세 화면에서 저장된 치수를 확인할 수 있어요."),
                .init(id: "compare", title: "등록한 옷을 핏랩에서 사용할 때", body: "핏랩에서 구매할 상품의 무료 리포트를 열고 ‘내 옷과 비교하기’ → ‘옷장에서 골라 비교’를 눌러주세요. 잘 맞는 보유 의류를 선택하면 다음에도 같은 옷을 기준으로 비교할 수 있어요."),
                .init(id: "camera", title: "내 옷 촬영하기 · 현재 준비 중", body: "카메라 측정 버튼은 안내 팝업만 보여줘요. 지금은 링크나 사이즈표 캡처로 등록해주세요. 불러오기에 실패하면 직접 입력할 수 있어요. 예시 따라하기는 실제 옷장에 저장하거나 실타래를 사용하지 않아요.")
            ]
        }
    }
}

struct CoorditUsageGuideSheet: View {
    @Environment(\.dismiss) private var dismiss
    let guide: CoorditUsageGuide
    var isFirstUse = false
    var onSkip: (() -> Void)? = nil
    let onExample: () -> Void
    @State private var showsSkipConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text(guide.title)
                        .font(CoorditTypography.gmarketBold(size: 22, relativeTo: .title2))
                    Spacer()
                    Button {
                        if isFirstUse { showsSkipConfirmation = true } else { dismiss() }
                    } label: {
                        if isFirstUse { Text("건너뛰기") } else { Image(systemName: "xmark.circle.fill").font(.title2) }
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel(isFirstUse ? "튜토리얼 건너뛰기" : "사용법 닫기")
                    .accessibilityIdentifier("usage-guide-close")
                }
                if isFirstUse {
                    Text("처음이라면 예시로 한 번 따라 해보세요. 핏랩과 옷장 사용법을 차례로 안내해드릴게요.")
                        .font(CoorditTypography.gmarketMedium(size: 14, relativeTo: .body))
                        .accessibilityIdentifier("first-use-guide-introduction")
                }
                Text(guide.introduction)
                    .font(CoorditTypography.gmarketBold(size: 15, relativeTo: .body))
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(CoorditFitLabPalette.field, in: RoundedRectangle(cornerRadius: 12))
                ForEach(guide.topics) { topic in
                    DisclosureGroup {
                        Text(topic.body)
                            .font(CoorditTypography.gmarketMedium(size: 13, relativeTo: .body))
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.vertical, 8)
                    } label: {
                        Text(topic.title)
                            .font(CoorditTypography.gmarketBold(size: 14, relativeTo: .headline))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.vertical, 8)
                    }
                    .accessibilityIdentifier("usage-topic-\(topic.id)")
                    Divider()
                }
            }
            .padding(24)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if guide == .fitLabReferences {
                    Button("비교로 돌아가기") { dismiss() }
                        .buttonStyle(CoorditContentActionButtonStyle(prominence: .primary, height: 48))
                        .accessibilityIdentifier("usage-guide-return")
                } else {
                    Button(action: startExample) {
                        Label("링크 예시로 따라하기", systemImage: "play.circle")
                    }
                    .buttonStyle(CoorditContentActionButtonStyle(prominence: .primary, height: 48))
                    .accessibilityIdentifier("usage-guide-example")
                    Text("실타래 차감이나 저장 없이 체험해요.")
                        .font(CoorditTypography.gmarketMedium(size: 11, relativeTo: .caption))
                        .foregroundStyle(CoorditFitLabPalette.muted)
                }
            }
            .padding(20)
            .background(CoorditFitLabPalette.surface)
        }
        .foregroundStyle(CoorditFitLabPalette.ink)
        .background(CoorditFitLabPalette.surface)
        .presentationDetents([.large])
        .presentationDragIndicator(isFirstUse ? .hidden : .visible)
        .interactiveDismissDisabled(isFirstUse)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("usage-guide-sheet")
        .alert("처음이라면 따라 해보는 걸 추천해요", isPresented: $showsSkipConfirmation) {
            Button("따라 해볼게요", action: startExample)
            Button("이번에는 건너뛰기", role: .cancel) { onSkip?() }
        } message: {
            Text("예시를 한 번 해보면 등록과 비교 흐름을 익힐 수 있어요. 나중에 사용법에서 다시 시작할 수도 있어요.")
        }
    }

    private func startExample() {
        dismiss()
        onExample()
    }
}
#endif
