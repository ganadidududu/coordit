import SwiftUI

#if os(iOS)
/// 홈 화면은 Figma 760px 폭 프레임(iPhone 15 Pro 393pt 기준)을 그대로 옮긴다.
/// 모든 길이는 Figma px 단위로 적고 `value(_:)`로 화면 폭에 맞춰 환산한다.
struct CoorditHomeLayout {
    static let figmaWidth: CGFloat = 760

    let width: CGFloat
    let scale: CGFloat

    init(width: CGFloat) {
        self.width = width
        scale = max(width / Self.figmaWidth, 0.1)
    }

    func value(_ figmaValue: CGFloat) -> CGFloat {
        figmaValue * scale
    }

    /// 좌우 여백(34.03px).
    var gutter: CGFloat { value(34.03) }
}

/// 4개 화면 정지 지점의 정의.
/// Figma의 4개 프레임(디자인 QA 반영 / Home-FitLab / Home-Closet / 디자인 QA 반영)이
/// 긴 홈 프레임의 어느 위치를 보여주는지에서 역산했다.
enum CoorditHomeSnapStop: Int, CaseIterable {
    /// 1. 카드 뉴스 (맨 위)
    case cardNews
    /// 2. FIT LAB — 섹션 상단이 헤더 바로 아래(220px)에 걸린다.
    case fitLab
    /// 3. CLOSET — 섹션 상단이 헤더 바로 아래(200px)에 걸린다.
    case closet
    /// 4. 실타래 + 푸터 — 스크롤 맨 끝.
    case footer

    /// 섹션 상단이 화면 위에서 얼마나 떨어져 멈추는지(Figma px).
    var sectionInset: CGFloat {
        switch self {
        case .cardNews, .footer: 0
        case .fitLab: 220
        case .closet: 200
        }
    }
}

/// 섹션 상단 위치(콘텐츠 좌표)를 모아 정지 지점으로 바꾼다.
struct CoorditHomeSnapAnchors: Equatable {
    var fitLabTop: CGFloat?
    var closetTop: CGFloat?

    func offsets(layout: CoorditHomeLayout) -> [CGFloat] {
        var result: [CGFloat] = [0]
        if let fitLabTop { result.append(fitLabTop - layout.value(CoorditHomeSnapStop.fitLab.sectionInset)) }
        if let closetTop { result.append(closetTop - layout.value(CoorditHomeSnapStop.closet.sectionInset)) }
        // 마지막 화면은 스크롤 끝(.infinity → 동작 시 maxOffset으로 고정).
        result.append(.infinity)
        return result
    }
}

/// "일정 비율 이상 스크롤하면 다음/이전 화면, 아니면 제자리"로 멈추는 페이지형 스냅.
struct CoorditHomeSnapScrollBehavior: ScrollTargetBehavior {
    /// 정지 지점(콘텐츠 offset). `.infinity`는 스크롤 끝을 뜻한다.
    let anchors: [CGFloat]
    /// 다음 화면으로 넘어가기 위해 필요한 이동 비율(두 정지 지점 사이 거리 대비).
    var threshold: CGFloat = 0.18
    /// 구간이 길어도 이 비율(화면 높이 대비)만큼 넘기면 다음 화면으로 간다.
    var viewportThreshold: CGFloat = 0.1

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        let maxOffset = max(0, context.contentSize.height - context.containerSize.height)
        let stops = Self.resolvedStops(
            anchors: anchors,
            maxOffset: maxOffset,
            viewportHeight: context.containerSize.height
        )
        guard stops.count > 1 else { return }

        // 제스처가 시작된 위치(직전에 멈춰 있던 화면).
        let start = context.originalTarget.rect.minY
        let proposed = target.rect.minY
        let current = Self.nearestIndex(to: start, in: stops)
        var destination = current
        let delta = proposed - stops[current]
        let viewportLimit = context.containerSize.height * viewportThreshold

        if delta > 0, current < stops.count - 1 {
            let gap = stops[current + 1] - stops[current]
            if delta > min(gap * threshold, viewportLimit) { destination = current + 1 }
        } else if delta < 0, current > 0 {
            let gap = stops[current] - stops[current - 1]
            if -delta > min(gap * threshold, viewportLimit) { destination = current - 1 }
        }

        target.rect.origin.y = stops[destination]
    }

    /// 정지 지점을 [0, maxOffset] 안으로 정리한다.
    /// 화면보다 긴 구간(큰 글씨 등)은 중간 지점을 추가해 내용이 잘려 보이지 않게 한다.
    static func resolvedStops(anchors: [CGFloat], maxOffset: CGFloat, viewportHeight: CGFloat) -> [CGFloat] {
        let clamped = anchors
            .map { $0.isInfinite ? maxOffset : min(max(0, $0), maxOffset) }
            .sorted()
        var stops: [CGFloat] = []
        for value in clamped where stops.last.map({ value - $0 > 1 }) ?? true {
            if let last = stops.last, viewportHeight > 0 {
                let step = viewportHeight * 0.85
                var filler = last + step
                while value - filler > step * 0.25 {
                    stops.append(filler)
                    filler += step
                }
            }
            stops.append(value)
        }
        return stops
    }

    static func nearestIndex(to offset: CGFloat, in stops: [CGFloat]) -> Int {
        stops.indices.min { abs(stops[$0] - offset) < abs(stops[$1] - offset) } ?? 0
    }
}

enum CoorditHomePalette {
    static let navy = CoorditDesignTokens.ColorToken.ink // #000C40
    static let slate = Main01DesignTokens.Colors.rgb(74, 85, 132) // #4A5584
    static let chipFill = Main01DesignTokens.Colors.rgb(115, 123, 157) // #737B9D
    static let panel = CoorditDesignTokens.ColorToken.panel // #FCFDFE
    static let line = CoorditDesignTokens.ColorToken.line // #E1E5EA
    static let muted = CoorditDesignTokens.ColorToken.muted // #7E8492
    static let blue = CoorditDesignTokens.ColorToken.blue // #194096
    static let closetTop = Main01DesignTokens.Colors.rgb(252, 253, 254)
    static let footer = Main01DesignTokens.Colors.rgb(244, 245, 248) // #F4F5F8

    /// FIT LAB 섹션 배경 (#000C40 4.4% → #4A5584 77.4%).
    static let fitLabBackground = LinearGradient(
        stops: [
            .init(color: navy, location: 0.044),
            .init(color: slate, location: 0.774),
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// 실타래 섹션 배경 (#4A5584 4.4% → #000C40 77.4%).
    static let threadBackground = LinearGradient(
        stops: [
            .init(color: slate, location: 0.044),
            .init(color: navy, location: 0.774),
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// CLOSET 섹션 배경 (흰색 위에 남색 계열 반투명 그라데이션).
    static let closetBackground = LinearGradient(
        stops: [
            .init(color: Main01DesignTokens.Colors.rgb(252, 253, 254), location: 0.046),
            .init(color: Main01DesignTokens.Colors.rgb(166, 171, 189).opacity(0.5), location: 0.642),
            .init(color: Main01DesignTokens.Colors.rgb(99, 107, 139).opacity(0.3), location: 0.917),
            .init(color: navy.opacity(0.1), location: 1.0),
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// 상·하단 크롬: 남색이 35%까지 꽉 차 있다가 투명으로 풀린다.
    /// 불투명 배경이 아니라 투명으로 풀리기 때문에, 아래로 지나가는 콘텐츠 색과 자연스럽게 섞인다.
    /// → FIT LAB(남색) 구간이 지나갈 때만 위·아래가 통째로 남색으로 이어진다.
    static func chromeFade(fromTop: Bool) -> LinearGradient {
        LinearGradient(
            stops: [
                .init(color: navy, location: 0),
                .init(color: navy, location: 0.351),
                .init(color: navy.opacity(0.72), location: 0.52),
                .init(color: navy.opacity(0.38), location: 0.70),
                .init(color: navy.opacity(0.12), location: 0.86),
                .init(color: navy.opacity(0), location: 1),
            ],
            startPoint: fromTop ? .top : .bottom,
            endPoint: fromTop ? .bottom : .top
        )
    }
}

extension View {
    /// Figma 공용 칩(#737B9D, 흰 테두리 35%) 모양의 큰 버튼.
    func coorditHomePrimaryChip(layout: CoorditHomeLayout, verticalPadding: CGFloat = 13) -> some View {
        self
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(.white)
            .padding(.horizontal, layout.value(15.124))
            .padding(.vertical, layout.value(verticalPadding))
            .frame(maxWidth: .infinity)
            .background(CoorditHomePalette.chipFill, in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.35), lineWidth: layout.value(2)))
            .contentShape(Capsule())
    }
}
#endif

#if os(iOS)
/// 스크롤 위치에 따라 상·하단 크롬을 FIT LAB 남색으로 덮는 정도(0~1).
/// 1번→2번으로 내려올 때 FIT LAB이 위로 올라오면서 서서히 남색이 차오르고,
/// 2번→3번으로 넘어가며 CLOSET이 들어오기 전에 다시 원래의 투명 그라데이션으로 풀린다.
struct CoorditHomeChromeTint: Equatable {
    var top: CGFloat = 0
    var bottom: CGFloat = 0

    static func resolve(offset: CGFloat, fitLabStop: CGFloat?, closetStop: CGFloat?) -> Self {
        guard let fitLabStop, fitLabStop > 1 else { return Self() }
        if offset <= fitLabStop {
            let t = offset / fitLabStop
            return Self(
                top: smoothstep((t - 0.45) / 0.55),
                bottom: smoothstep((t - 0.3) / 0.7)
            )
        }
        guard let closetStop, closetStop - fitLabStop > 1 else { return Self(top: 1, bottom: 1) }
        let t = (offset - fitLabStop) / (closetStop - fitLabStop)
        return Self(
            top: 1 - smoothstep((t - 0.5) / 0.5),
            bottom: 1 - smoothstep(t / 0.35)
        )
    }

    private static func smoothstep(_ x: CGFloat) -> CGFloat {
        let t = min(max(x, 0), 1)
        return t * t * (3 - 2 * t)
    }
}

/// 상·하단 크롬 오버레이.
struct CoorditHomeChromeOverlay: View {
    let layout: CoorditHomeLayout
    let tint: CoorditHomeChromeTint
    /// 2번 화면에서 FIT LAB 아래로 드러나는 영역까지 덮을 하단 높이.
    let bottomCoverHeight: CGFloat
    /// 화면 위에서 FIT LAB 섹션 윗선까지의 거리. 남색 덮개가 이 선까지 따라 내려와 흰 틈을 없앤다.
    let fitLabTopOnScreen: CGFloat?
    /// 화면 위에서 CLOSET 섹션 윗선까지의 거리. 3번 화면에서 FIT LAB 끝자락을 가려
    /// Figma처럼 남색 → CLOSET 밝은색으로 부드럽게 이어지게 한다.
    let closetTopOnScreen: CGFloat?

    /// CLOSET 윗선이 헤더 아래 정지선(200px)에 가까울수록 1.
    private var closetBlend: CGFloat {
        guard let closetTopOnScreen else { return 0 }
        let rest = layout.value(CoorditHomeSnapStop.closet.sectionInset)
        let fadeDistance = layout.value(300)
        let x = 1 - (closetTopOnScreen - rest) / fadeDistance
        let t = min(max(x, 0), 1)
        return t * t * (3 - 2 * t)
    }

    /// 남색 덮개 아래쪽이 풀리는 길이(Figma px).
    private static let topFeather: CGFloat = 30

    private var topCoverHeight: CGFloat {
        let base = layout.value(CoorditHomeSnapStop.fitLab.sectionInset + Self.topFeather)
        guard let fitLabTopOnScreen, fitLabTopOnScreen > 0 else { return base }
        return max(base, fitLabTopOnScreen + layout.value(Self.topFeather))
    }

    private var topSolidRatio: CGFloat {
        let height = topCoverHeight
        guard height > 0 else { return 0 }
        return min(max((height - layout.value(Self.topFeather - 2)) / height, 0), 1)
    }

    var body: some View {
        ZStack {
            ZStack(alignment: .top) {
                CoorditHomePalette.chromeFade(fromTop: true)
                    .frame(height: layout.value(225.536))
                // FIT LAB 섹션 시작선(220px)까지는 완전한 남색, 그 아래 30px에서만 풀린다.
                // 2번 화면에서 풀리는 구간은 FIT LAB 남색 위에 겹치므로 경계가 보이지 않는다.
                LinearGradient(
                    stops: [
                        .init(color: CoorditHomePalette.navy, location: 0),
                        .init(color: CoorditHomePalette.navy, location: topSolidRatio),
                        .init(color: CoorditHomePalette.navy.opacity(0), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: topCoverHeight)
                .opacity(tint.top)

                if let closetTopOnScreen, closetTopOnScreen > 0, closetBlend > 0 {
                    LinearGradient(
                        stops: [
                            .init(color: CoorditHomePalette.navy, location: 0),
                            .init(color: CoorditHomePalette.navy, location: 0.351),
                            .init(color: CoorditHomePalette.closetTop, location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: closetTopOnScreen + 1)
                    .opacity(closetBlend)
                }
            }
            .frame(height: topCoverHeight, alignment: .top)
            .frame(maxHeight: .infinity, alignment: .top)

            ZStack(alignment: .bottom) {
                LinearGradient(
                    stops: [
                        .init(color: CoorditHomePalette.slate.opacity(0), location: 0),
                        .init(color: CoorditHomePalette.slate, location: 0.18),
                        .init(color: CoorditHomePalette.navy, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: max(bottomCoverHeight, layout.value(290)))
                .opacity(tint.bottom)

                CoorditHomePalette.chromeFade(fromTop: false)
                    .frame(height: layout.value(290))
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
#endif
