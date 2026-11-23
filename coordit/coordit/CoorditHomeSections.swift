import SwiftUI

#if os(iOS)
import UIKit

// MARK: - 1. 카드 뉴스

/// 카드 뉴스 한 장. `imageName`이 있으면 이미지 한 장이 카드 전체를 채운다.
/// (카드 뉴스 이미지는 추후 받아서 Assets에 넣고 `CoorditHomeCardNews.items`만 바꾸면 된다.)
struct CoorditHomeCardNews: Identifiable {
    let id: String
    var imageName: String?
    var highlight: String
    var title: String
    var source: String = "coordit | magazine"

    static let items: [CoorditHomeCardNews] = [
        CoorditHomeCardNews(
            id: "black-friday-1",
            imageName: "CoorditCardNews1",
            highlight: "빙하기가 오기 전에 할 일: 블프 뽕뽑기",
            title: "코딧 매거진이\n블프 알잘딱 정리해드립니다."
        ),
        CoorditHomeCardNews(
            id: "black-friday-2",
            imageName: "CoorditCardNews2",
            highlight: "브랜드별 블랙프라이데이 일정",
            title: "가을은 자고로 블프의 계절"
        ),
        CoorditHomeCardNews(
            id: "black-friday-3",
            imageName: "CoorditCardNews3",
            highlight: "반품 없이 사는 법",
            title: "하지만 반품비로 더 큰 지출을 만들 수는 없는 법."
        ),
    ]
}

struct CoorditHomeCardNewsSection: View {
    let layout: CoorditHomeLayout
    let items: [CoorditHomeCardNews]

    private let cardWidth: CGFloat = 650
    private let cardHeight: CGFloat = 690
    private let cardSpacing: CGFloat = 20

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: layout.value(cardSpacing)) {
                ForEach(items) { item in
                    CoorditHomeCardNewsCard(item: item, layout: layout)
                        .frame(width: layout.value(cardWidth), height: layout.value(cardHeight))
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, layout.value((CoorditHomeLayout.figmaWidth - cardWidth) / 2), for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
        .frame(height: layout.value(cardHeight))
        .padding(.top, layout.value(221.19))
        .padding(.bottom, layout.value(954 - 221.19 - cardHeight))
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("coordit-main04-banner")
    }
}

private struct CoorditHomeCardNewsCard: View {
    let item: CoorditHomeCardNews
    let layout: CoorditHomeLayout

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: layout.value(32), style: .continuous)
        ZStack {
            if let imageName = item.imageName {
                // 카드 뉴스 원본은 4:5(1080×1350)이고 배경이 흰색이라,
                // 잘리지 않게 카드 안에 맞춰 넣어도 흰 카드와 이음새 없이 이어진다.
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .accessibilityLabel(Text("\(item.highlight). \(item.title.replacingOccurrences(of: "\n", with: " "))"))
            } else {
                placeholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .clipShape(shape)
        .overlay(shape.stroke(CoorditHomePalette.navy.opacity(0.08), lineWidth: layout.value(1.5)))
        .accessibilityIdentifier("coordit-main04-card-news-\(item.id)")
    }

    /// 실제 카드 뉴스 이미지가 들어오기 전까지 쓰는 자리 표시용 레이아웃.
    private var placeholder: some View {
        VStack(alignment: .leading, spacing: layout.value(14)) {
            Image("CoorditHomeEditorial")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityHidden(true)

            Text(item.highlight)
                .font(CoorditTypography.gmarketMedium(size: layout.value(20), relativeTo: .caption))
                .foregroundStyle(.black)
                .padding(.horizontal, layout.value(4))
                .background(Main01DesignTokens.Colors.rgb(255, 241, 118))

            Text(item.title)
                .font(CoorditTypography.gmarketMedium(size: layout.value(38), relativeTo: .title))
                .foregroundStyle(.black)
                .lineSpacing(layout.value(4))
                .fixedSize(horizontal: false, vertical: true)

            Text(item.source)
                .font(CoorditTypography.gmarketMedium(size: layout.value(18), relativeTo: .caption))
                .foregroundStyle(.black.opacity(0.75))
        }
        .padding(.horizontal, layout.value(36))
        .padding(.top, layout.value(24))
        .padding(.bottom, layout.value(36))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - 2. FIT LAB

struct CoorditHomeFitLabSection: View {
    let layout: CoorditHomeLayout
    let closetItems: [CoorditClosetItem]
    let selectedReferenceIDs: Set<String>
    let history: [CoorditFitLabHistorySnapshot]
    let onStartAnalysis: () -> Void
    let onSelectReference: () -> Void
    let onOpenHistory: (CoorditFitLabHistorySnapshot) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: layout.value(80)) {
            CoorditHomeSectionHeading(
                layout: layout,
                wordmark: "FIT LAB",
                caption: "나에게 가장 잘 맞는 기준 의류 정보",
                onDark: true
            )

            Button(action: onStartAnalysis) {
                let wordmark = Text("FIT LAB").font(CoorditTypography.climate2010(size: layout.value(30), relativeTo: .headline))
                let rest = Text("에서 새로운 옷 분석하기").font(CoorditTypography.gmarketBold(size: layout.value(30), relativeTo: .headline))
                Text("\(wordmark)\(rest)")
                    .coorditHomePrimaryChip(layout: layout)
            }
            .buttonStyle(.plain)
            .coorditPressFeedback()
            .accessibilityLabel("FIT LAB에서 새로운 옷 분석하기")
            .accessibilityIdentifier("coordit-main04-new-fit-button")

            VStack(alignment: .leading, spacing: layout.value(40)) {
                CoorditHomeReferenceRow(
                    layout: layout,
                    category: .top,
                    items: closetItems.filter { $0.category == .top },
                    selectedIDs: selectedReferenceIDs,
                    onSelect: onSelectReference
                )
                CoorditHomeReferenceRow(
                    layout: layout,
                    category: .bottom,
                    items: closetItems.filter { $0.category == .bottom },
                    selectedIDs: selectedReferenceIDs,
                    onSelect: onSelectReference
                )
            }

            Button(action: onSelectReference) {
                Text("기준 의류 추가하기")
                    .font(CoorditTypography.gmarketBold(size: layout.value(25), relativeTo: .headline))
                    .coorditHomePrimaryChip(layout: layout, verticalPadding: 9)
            }
            .buttonStyle(.plain)
            .coorditPressFeedback()
            .accessibilityIdentifier("home-reference-select")

            CoorditHomeRecentFitCard(layout: layout, history: history, onOpenHistory: onOpenHistory)
        }
        .padding(.top, layout.value(80))
        .padding(.bottom, layout.value(90))
        .padding(.horizontal, layout.gutter)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CoorditHomePalette.fitLabBackground)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("coordit-main04-fitlab-section")
    }
}

struct CoorditHomeSectionHeading: View {
    let layout: CoorditHomeLayout
    let wordmark: String
    let caption: String
    let onDark: Bool

    var body: some View {
        HStack(alignment: .center, spacing: layout.value(12)) {
            Text(wordmark)
                .font(CoorditTypography.climate2010(size: layout.value(onDark ? 34 : 40), relativeTo: .title))
                .tracking(layout.value(-2))
                .foregroundStyle(onDark ? Color.white : CoorditHomePalette.navy)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 0)

            Text(caption)
                .font(CoorditTypography.gmarketBold(size: layout.value(20), relativeTo: .caption))
                .foregroundStyle(onDark ? Color.white.opacity(0.8) : CoorditHomePalette.navy.opacity(0.7))
                .shadow(color: (onDark ? Color.black : Color.white).opacity(0.25), radius: layout.value(4))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

private struct CoorditHomeReferenceRow: View {
    let layout: CoorditHomeLayout
    let category: CoorditClosetCategory
    let items: [CoorditClosetItem]
    let selectedIDs: Set<String>
    let onSelect: () -> Void

    private var reference: CoorditClosetItem? {
        items.first { selectedIDs.contains($0.id) }
    }

    private var measurements: [(label: String, value: Double?)] {
        let map = reference?.sizeChart?.measurements
        switch category {
        case .top:
            return [("어깨", map?.shoulderWidth), ("가슴", map?.chestWidth), ("소매", map?.sleeveLength)]
        case .bottom:
            return [("허리", map?.waistWidth), ("엉덩이", map?.hipWidth), ("총장", map?.outseam)]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: layout.value(15.124)) {
            HStack(spacing: layout.value(20)) {
                Text(category.title)
                    .font(CoorditTypography.gmarketBold(size: layout.value(20), relativeTo: .caption))
                    .foregroundStyle(CoorditHomePalette.navy)
                    .padding(.horizontal, layout.value(15.124))
                    .padding(.vertical, layout.value(7.562))
                    .background(Color.white, in: Capsule())

                ScrollView(.horizontal) {
                    HStack(spacing: layout.value(10)) {
                        if items.isEmpty {
                            chip(title: "등록된 \(category.title)가 없어요", isSelected: false)
                        }
                        ForEach(items) { item in
                            Button(action: onSelect) {
                                chip(title: item.name, isSelected: selectedIDs.contains(item.id))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(selectedIDs.contains(item.id) ? .isSelected : [])
                            .accessibilityHint("기준 의류를 다시 고를 수 있어요")
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }

            HStack(spacing: layout.value(11.343)) {
                ForEach(measurements, id: \.label) { measurement in
                    measurementTile(label: measurement.label, value: measurement.value)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("coordit-main04-reference-\(category == .top ? "top" : "bottom")")
    }

    private func chip(title: String, isSelected: Bool) -> some View {
        Text(title)
            .font(CoorditTypography.gmarketBold(size: layout.value(20), relativeTo: .caption))
            .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.7))
            .shadow(color: .black.opacity(isSelected ? 0.25 : 0), radius: layout.value(4))
            .lineLimit(1)
            .padding(.horizontal, layout.value(15.124))
            .padding(.vertical, layout.value(7.562))
            .background(isSelected ? CoorditHomePalette.chipFill : Color.white.opacity(0.09), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(isSelected ? 0.35 : 0.12), lineWidth: max(layout.value(1.9), 1)))
    }

    private func measurementTile(label: String, value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: layout.value(5.672)) {
                Text(value.map(Self.format) ?? "–")
                    .font(.system(size: layout.value(37.811), weight: .medium, design: .monospaced))
                    .foregroundStyle(.white)
                Text("cm")
                    .font(CoorditTypography.gmarketMedium(size: layout.value(17.015), relativeTo: .caption2))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)

            Text(label)
                .font(CoorditTypography.gmarketMedium(size: layout.value(18.905), relativeTo: .caption))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(layout.value(18.905))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: layout.value(22.687), style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: layout.value(22.687), style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: layout.value(1.891))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(value.map(Self.format) ?? "정보 없음") 센티미터")
    }

    private static func format(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }
}

private struct CoorditHomeRecentFitCard: View {
    let layout: CoorditHomeLayout
    let history: [CoorditFitLabHistorySnapshot]
    let onOpenHistory: (CoorditFitLabHistorySnapshot) -> Void

    private var latest: CoorditFitLabHistorySnapshot? {
        history.max {
            if $0.savedAt == $1.savedAt { return $0.analysisID < $1.analysisID }
            return $0.savedAt < $1.savedAt
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: layout.value(18.905)) {
            HStack {
                Text("최근 핏 분석")
                    .font(CoorditTypography.gmarketBold(size: layout.value(32.139), relativeTo: .headline))
                    .foregroundStyle(CoorditHomePalette.navy)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                if !history.isEmpty {
                    HStack(spacing: layout.value(3.781)) {
                        Text("전체 \(history.count)개")
                            .font(CoorditTypography.gmarketBold(size: layout.value(20.796), relativeTo: .caption))
                        Image(systemName: "chevron.right")
                            .font(.system(size: layout.value(16), weight: .bold))
                    }
                    .foregroundStyle(CoorditHomePalette.navy)
                }
            }

            if let latest {
                Button { onOpenHistory(latest) } label: {
                    CoorditHomeRecentFitRow(layout: layout, snapshot: latest)
                }
                .buttonStyle(.plain)
                .coorditPressFeedback()
                .accessibilityIdentifier("coordit-main04-history-card-\(latest.analysisID)")
            } else {
                Text("저장한 핏 리포트가 아직 없어요")
                    .font(CoorditTypography.gmarketMedium(size: layout.value(19), relativeTo: .caption))
                    .foregroundStyle(CoorditHomePalette.muted)
                    .frame(maxWidth: .infinity, minHeight: layout.value(124.776))
                    .background(Color.white, in: RoundedRectangle(cornerRadius: layout.value(18.905), style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: layout.value(18.905), style: .continuous)
                            .stroke(CoorditHomePalette.line, lineWidth: layout.value(1.891))
                    )
                    .accessibilityIdentifier("coordit-main04-history-empty")
            }
        }
        .padding(layout.value(30.249))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CoorditHomePalette.panel, in: RoundedRectangle(cornerRadius: layout.value(22.687), style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: layout.value(22.687), style: .continuous)
                .stroke(CoorditHomePalette.line.opacity(0.65), lineWidth: layout.value(1.323))
        )
        .shadow(color: CoorditHomePalette.navy.opacity(0.05), radius: layout.value(22.687), y: layout.value(7.562))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("coordit-main04-fitlab-card")
    }
}

private struct CoorditHomeRecentFitRow: View {
    let layout: CoorditHomeLayout
    let snapshot: CoorditFitLabHistorySnapshot

    var body: some View {
        let isUpper = snapshot.garmentKind == .upper
        let score = CoorditFitLabResultMeasurement.score(snapshot.recommendation.fitScore)
        let size = "\(snapshot.recommendation.recommendedSize) 추천"

        HStack(spacing: layout.value(18.905)) {
            Image("CoorditFitGarment-\(snapshot.category.rawValue)")
                .resizable()
                .scaledToFit()
                .frame(width: layout.value(69.875), height: layout.value(69.875))
                .frame(width: layout.value(83.184), height: layout.value(83.184))
                .background(CoorditDesignTokens.ColorToken.field, in: RoundedRectangle(cornerRadius: layout.value(15.124), style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: layout.value(5.672)) {
                HStack(spacing: layout.value(9.453)) {
                    Text(snapshot.product.name)
                        .font(CoorditTypography.gmarketBold(size: layout.value(20.796), relativeTo: .body))
                        .foregroundStyle(CoorditHomePalette.navy)
                        .lineLimit(1)
                    Text(isUpper ? "TOP" : "BOTTOM")
                        .font(.system(size: layout.value(15.124), weight: .medium, design: .monospaced))
                        .foregroundStyle(CoorditHomePalette.blue)
                }
                Text(size)
                    .font(CoorditTypography.gmarketMedium(size: layout.value(18.905), relativeTo: .caption))
                    .foregroundStyle(CoorditHomePalette.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 0) {
                Text("SCORE")
                    .font(.system(size: layout.value(14.179), weight: .medium, design: .monospaced))
                    .foregroundStyle(CoorditHomePalette.muted)
                Text(score)
                    .font(.system(size: layout.value(35.92), weight: .medium, design: .monospaced))
                    .foregroundStyle(CoorditHomePalette.navy)
            }
        }
        .padding(layout.value(18.905))
        .background(Color.white, in: RoundedRectangle(cornerRadius: layout.value(18.905), style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: layout.value(18.905), style: .continuous)
                .stroke(CoorditHomePalette.line, lineWidth: layout.value(1.891))
        )
        .contentShape(RoundedRectangle(cornerRadius: layout.value(18.905), style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(snapshot.product.name), \(size), \(score)점, 핏랩 히스토리")
    }
}

// MARK: - 3. CLOSET

struct CoorditHomeClosetSection: View {
    let layout: CoorditHomeLayout
    let closetItems: [CoorditClosetItem]
    let selectedReferenceIDs: Set<String>
    let onOpenCloset: () -> Void
    let onAddGarment: () -> Void

    var body: some View {
        VStack(spacing: layout.value(40)) {
            CoorditHomeSectionHeading(
                layout: layout,
                wordmark: "CLOSET",
                caption: "현재 내가 보유 중인 옷 목록",
                onDark: false
            )
            .padding(.horizontal, layout.gutter)

            ForEach(CoorditClosetCategory.allCases, id: \.self) { category in
                categoryRow(category)
            }

            Button(action: onAddGarment) {
                let wordmark = Text("CLOSET ").font(CoorditTypography.climate2010(size: layout.value(30), relativeTo: .headline))
                let rest = Text("으로 이동하여 보유 의류 추가").font(CoorditTypography.gmarketMedium(size: layout.value(30), relativeTo: .headline))
                Text("\(wordmark)\(rest)")
                    .coorditHomePrimaryChip(layout: layout)
            }
            .buttonStyle(.plain)
            .coorditPressFeedback()
            .padding(.horizontal, layout.gutter)
            .accessibilityLabel("CLOSET으로 이동하여 보유 의류 추가")
            .accessibilityIdentifier("coordit-main04-closet-button")
        }
        .padding(.top, layout.value(50))
        .padding(.bottom, layout.value(70))
        .frame(maxWidth: .infinity)
        .background {
            ZStack {
                Color.white
                CoorditHomePalette.closetBackground
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("coordit-main04-closet-section")
    }

    private func categoryRow(_ category: CoorditClosetCategory) -> some View {
        let items = closetItems.filter { $0.category == category }
        return VStack(alignment: .leading, spacing: layout.value(15.124)) {
            HStack {
                Text(category.title)
                    .font(CoorditTypography.gmarketBold(size: layout.value(18.905), relativeTo: .caption))
                    .foregroundStyle(CoorditHomePalette.navy)
                    .padding(.horizontal, layout.value(15.124))
                    .padding(.vertical, layout.value(7.562))
                    .background(Color.white, in: Capsule())
                Spacer(minLength: 0)
                Button(action: onOpenCloset) {
                    Text("\(items.count)벌  ›")
                        .font(CoorditTypography.gmarketBold(size: layout.value(18.905), relativeTo: .caption))
                        .foregroundStyle(CoorditHomePalette.navy)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(category.title) \(items.count)벌 모두 보기")
            }
            .padding(.horizontal, layout.gutter)

            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: layout.value(14)) {
                    if items.isEmpty {
                        emptyCard(category)
                    }
                    ForEach(items) { item in
                        Button(action: onOpenCloset) {
                            CoorditHomeClosetCard(
                                layout: layout,
                                item: item,
                                isReference: selectedReferenceIDs.contains(item.id)
                            )
                        }
                        .buttonStyle(.plain)
                        .coorditPressFeedback()
                    }
                }
                .padding(.bottom, layout.value(10))
            }
            .contentMargins(.horizontal, layout.gutter, for: .scrollContent)
            .scrollIndicators(.hidden)
        }
    }

    private func emptyCard(_ category: CoorditClosetCategory) -> some View {
        Button(action: onAddGarment) {
            VStack(spacing: layout.value(10)) {
                Image(systemName: "plus")
                    .font(.system(size: layout.value(40), weight: .semibold))
                Text("\(category.title) 등록하기")
                    .font(CoorditTypography.gmarketBold(size: layout.value(18), relativeTo: .caption))
            }
            .foregroundStyle(.white)
            .frame(width: layout.value(200), height: layout.value(252))
            .background(CoorditHomePalette.navy.opacity(0.45), in: RoundedRectangle(cornerRadius: layout.value(22), style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct CoorditHomeClosetCard: View {
    let layout: CoorditHomeLayout
    let item: CoorditClosetItem
    let isReference: Bool

    private var detail: String {
        let map = item.sizeChart?.measurements
        var parts: [String] = []
        if let size = item.sizeChart?.sizeLabel { parts.append(size) }
        let pairs: [(String, Double?)] = item.category == .top
            ? [("어깨", map?.shoulderWidth), ("가슴", map?.chestWidth)]
            : [("허리", map?.waistWidth), ("총장", map?.outseam)]
        for (label, value) in pairs {
            if let value { parts.append("\(label) \(value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value))") }
        }
        return parts.isEmpty ? item.exactCategory.koreanTitle : parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: layout.value(12)) {
            ZStack(alignment: .topLeading) {
                thumbnail
                    .frame(width: layout.value(124), height: layout.value(124))
                    .frame(width: layout.value(172), height: layout.value(172))
                    .background(Color.white.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: layout.value(16), style: .continuous))

                if isReference {
                    Text("기준")
                        .font(CoorditTypography.gmarketBold(size: layout.value(13), relativeTo: .caption2))
                        .foregroundStyle(.white)
                        .padding(.horizontal, layout.value(10))
                        .padding(.vertical, layout.value(4))
                        .background(CoorditHomePalette.navy.opacity(0.8), in: Capsule())
                        .padding(layout.value(10))
                }
            }

            VStack(alignment: .leading, spacing: layout.value(4)) {
                Text(item.name)
                    .font(CoorditTypography.gmarketBold(size: layout.value(18), relativeTo: .caption))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(detail)
                    .font(CoorditTypography.gmarketMedium(size: layout.value(14), relativeTo: .caption2))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }
            .frame(width: layout.value(172), alignment: .leading)
        }
        .padding(layout.value(14))
        .background(.ultraThinMaterial.opacity(0.35), in: RoundedRectangle(cornerRadius: layout.value(22), style: .continuous))
        .background(CoorditHomePalette.navy.opacity(0.45), in: RoundedRectangle(cornerRadius: layout.value(22), style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: layout.value(22), style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: layout.value(1.5))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.name), \(detail)\(isReference ? ", 기준 의류" : "")")
        .accessibilityIdentifier("coordit-main04-closet-card-\(item.id)")
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let data = item.imageData, let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFit()
        } else {
            Image("CoorditFitGarment-\(item.exactCategory.rawValue)").resizable().scaledToFit()
        }
    }
}

// MARK: - 4. 실타래 + 푸터

struct CoorditHomeThreadSection: View {
    let layout: CoorditHomeLayout
    let threadBalance: Int
    let onOpenHistory: () -> Void
    let onWatchAd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: layout.value(25)) {
            HStack(spacing: layout.value(18)) {
                Image("CoorditYarn")
                    .resizable()
                    .scaledToFit()
                    .frame(width: layout.value(83), height: layout.value(83))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: layout.value(2)) {
                    Text("내 실타래")
                        .font(CoorditTypography.gmarketMedium(size: layout.value(18.905), relativeTo: .caption))
                        .foregroundStyle(.white.opacity(0.7))
                    HStack(alignment: .firstTextBaseline, spacing: layout.value(6)) {
                        Text("\(threadBalance)")
                            .font(.system(size: layout.value(44), weight: .medium, design: .monospaced))
                            .foregroundStyle(.white)
                        Text("개 남음")
                            .font(CoorditTypography.gmarketBold(size: layout.value(20), relativeTo: .caption))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                .accessibilityElement(children: .combine)
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: onOpenHistory) {
                    Text("사용 내역 ›")
                        .font(CoorditTypography.gmarketBold(size: layout.value(16), relativeTo: .caption))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, layout.value(15.12))
                        .padding(.vertical, layout.value(7.56))
                        .background(Color.white.opacity(0.09), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("coordit-main04-thread-history")
            }
            .frame(height: layout.value(83))

            HStack(spacing: layout.value(20)) {
                Text("핏 분석 1회에 실타래 1개가 쓰여요.")
                    .font(CoorditTypography.gmarketBold(size: layout.value(18.905), relativeTo: .caption))
                    .foregroundStyle(.white)
                Text("기준 의류와 새 옷의 치수를 비교할 때마다 1개씩 차감됩니다.")
                    .font(CoorditTypography.gmarketLight(size: layout.value(16), relativeTo: .caption2))
                    .foregroundStyle(.white.opacity(0.65))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity)

            Button(action: onWatchAd) {
                Text("광고 보고 실타래 받기")
                    .font(CoorditTypography.gmarketBold(size: layout.value(30), relativeTo: .headline))
                    .coorditHomePrimaryChip(layout: layout)
            }
            .buttonStyle(.plain)
            .coorditPressFeedback()
            .accessibilityIdentifier("coordit-main04-thread-ad")
        }
        .padding(.top, layout.value(40))
        .padding(.bottom, layout.value(70))
        .padding(.horizontal, layout.value(34))
        .frame(maxWidth: .infinity)
        .background(CoorditHomePalette.threadBackground)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("coordit-main04-thread-section")
    }
}

struct CoorditHomeFooter: View {
    let layout: CoorditHomeLayout
    let onRouteChange: (CoorditFrameRoute) -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            magazine
            divider
            instagram
            divider
            support
        }
        .padding(.top, layout.value(24))
        .padding(.bottom, layout.value(208.756))
        .padding(.horizontal, layout.gutter)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CoorditHomePalette.footer)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("coordit-main04-footer")
    }

    private var divider: some View {
        Rectangle()
            .fill(CoorditHomePalette.navy.opacity(0.13))
            .frame(height: max(layout.value(1.5), 0.5))
    }

    private var magazine: some View {
        HStack(alignment: .center) {
            HStack(alignment: .center, spacing: layout.value(6)) {
                Text("COORDIT")
                    .font(CoorditTypography.climate2019(size: layout.value(22.565), relativeTo: .headline))
                    .tracking(layout.value(-2.5))
                    .foregroundStyle(CoorditHomePalette.navy)
                Text("매거진")
                    .font(CoorditTypography.gmarketBold(size: layout.value(22), relativeTo: .headline))
                    .foregroundStyle(CoorditHomePalette.navy)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            Text("더보기")
                .font(CoorditTypography.gmarketMedium(size: layout.value(17), relativeTo: .caption))
                .underline()
                .foregroundStyle(CoorditHomePalette.chipFill)
        }
        .padding(.vertical, layout.value(36))
    }

    private var instagram: some View {
        VStack(alignment: .leading, spacing: layout.value(22)) {
            sectionTitle("공식 인스타그램")

            HStack(spacing: layout.value(16)) {
                Image(systemName: "camera")
                    .font(.system(size: layout.value(26), weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: layout.value(52), height: layout.value(52))
                    .background(
                        LinearGradient(
                            stops: [
                                .init(color: Main01DesignTokens.Colors.rgb(254, 218, 117), location: 0.143),
                                .init(color: Main01DesignTokens.Colors.rgb(250, 126, 30), location: 0.357),
                                .init(color: Main01DesignTokens.Colors.rgb(214, 41, 118), location: 0.571),
                                .init(color: Main01DesignTokens.Colors.rgb(150, 47, 191), location: 0.857),
                            ],
                            startPoint: .bottomLeading,
                            endPoint: .topTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: layout.value(15), style: .continuous)
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: layout.value(3)) {
                    Text("@coord_it")
                        .font(CoorditTypography.gmarketBold(size: layout.value(19), relativeTo: .body))
                        .foregroundStyle(CoorditHomePalette.navy)
                    Text("새 매거진 소식을 가장 먼저 받아보세요")
                        .font(CoorditTypography.gmarketLight(size: layout.value(15), relativeTo: .caption))
                        .foregroundStyle(CoorditHomePalette.chipFill)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    if let url = URL(string: "https://www.instagram.com/coord_it") { openURL(url) }
                } label: {
                    Text("팔로우 ›")
                        .font(CoorditTypography.gmarketBold(size: layout.value(16), relativeTo: .caption))
                        .foregroundStyle(.white)
                        .padding(.horizontal, layout.value(18))
                        .padding(.vertical, layout.value(9))
                        .background(CoorditHomePalette.navy, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("인스타그램 coord_it 팔로우")
            }
            .padding(.horizontal, layout.value(20))
            .padding(.vertical, layout.value(18))
            .background(Color.white, in: RoundedRectangle(cornerRadius: layout.value(18), style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: layout.value(18), style: .continuous)
                    .stroke(CoorditHomePalette.navy.opacity(0.06), lineWidth: 1)
            )
        }
        .padding(.vertical, layout.value(36))
    }

    private var support: some View {
        VStack(alignment: .leading, spacing: layout.value(22)) {
            sectionTitle("고객 지원")

            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: layout.value(22)) {
                    supportLink("서비스 소개", route: nil)
                    supportLink("자주 묻는 질문", route: nil)
                    supportLink("개인정보처리방침", route: .myPagePrivacyPolicy)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: layout.value(22)) {
                    supportLink("문의하기", route: nil)
                    supportLink("이용약관", route: .myPageTerms)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text("© 2026 COORDIT. All rights reserved.")
                .font(CoorditTypography.gmarketLight(size: layout.value(13), relativeTo: .caption2))
                .foregroundStyle(CoorditHomePalette.chipFill.opacity(0.8))
        }
        .padding(.vertical, layout.value(36))
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(CoorditTypography.gmarketBold(size: layout.value(22), relativeTo: .headline))
            .foregroundStyle(CoorditHomePalette.navy)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private func supportLink(_ title: String, route: CoorditFrameRoute?) -> some View {
        let label = Text(title)
            .font(CoorditTypography.gmarketLight(size: layout.value(18), relativeTo: .body))
            .foregroundStyle(CoorditHomePalette.navy.opacity(0.85))
        if let route {
            Button { onRouteChange(route) } label: { label }
                .buttonStyle(.plain)
        } else {
            label
        }
    }
}
#endif
