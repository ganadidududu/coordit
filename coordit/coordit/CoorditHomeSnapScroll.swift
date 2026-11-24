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

    /// FIT LAB·CLOSET 섹션 위쪽 여백(px). 정지 시 섹션 제목이 화면 위에서 310px에 온다.
    static let sectionTopPadding: CGFloat = 100
}

/// 4개 화면 정지 지점의 정의.
/// Figma의 4개 프레임(디자인 QA 반영 / Home-FitLab / Home-Closet / 디자인 QA 반영)이
/// 긴 홈 프레임의 어느 위치를 보여주는지에서 역산했다.
enum CoorditHomeSnapStop: Int, CaseIterable {
    /// 1. 카드 뉴스 (맨 위)
    case cardNews
    /// 2. FIT LAB — 섹션 상단이 화면 위 210px(제목은 310px)에 걸린다.
    case fitLab
    /// 3. CLOSET — 섹션 상단이 화면 위 210px(제목은 310px)에 걸린다.
    case closet
    /// 4. 실타래 + 푸터 — 실타래 섹션 상단이 270px(잔량 줄은 310px)에 걸린다.
    case footer

    /// 섹션 상단이 화면 위에서 얼마나 떨어져 멈추는지(Figma px).
    var sectionInset: CGFloat {
        switch self {
        case .cardNews: 0
        case .fitLab, .closet: 210
        case .footer: 270
        }
    }
}

/// 섹션 상단 위치(콘텐츠 좌표)를 모아 정지 지점으로 바꾼다.
struct CoorditHomeSnapAnchors: Equatable {
    var fitLabTop: CGFloat?
    var closetTop: CGFloat?
    var threadTop: CGFloat?

    func offsets(layout: CoorditHomeLayout) -> [CGFloat] {
        var result: [CGFloat] = [0]
        if let fitLabTop { result.append(fitLabTop - layout.value(CoorditHomeSnapStop.fitLab.sectionInset)) }
        if let closetTop { result.append(closetTop - layout.value(CoorditHomeSnapStop.closet.sectionInset)) }
        if let threadTop { result.append(threadTop - layout.value(CoorditHomeSnapStop.footer.sectionInset)) }
        // 스크롤 끝(.infinity → maxOffset). iPhone 15 Pro에서는 4번 화면과 겹쳐 하나로 합쳐지고,
        // 화면이 더 짧은 폰에서는 푸터 끝까지 볼 수 있는 마지막 정지 지점이 된다.
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
        // 화면 높이의 10%보다 가까운 정지 지점은 하나로 합친다(뒤의 값을 쓴다).
        let mergeDistance = max(viewportHeight * 0.1, 1)
        for value in clamped {
            if let last = stops.last, value - last < mergeDistance {
                if stops.count > 1 { stops[stops.count - 1] = value }
                continue
            }
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
    /// CLOSET 섹션 배경(#F4F5F8).
    static let closetTop = Main01DesignTokens.Colors.rgb(244, 245, 248)
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

    /// 실타래 섹션 윗부분 색. Figma에서는 실타래 그라데이션(#4A5584 4.4% → #000C40 77.4%, 632px)이
    /// 화면 맨 위부터 깔리고 섹션은 270px 아래에서 시작하므로, 섹션 윗선은 그라데이션의 43% 지점 색이다.
    static let threadTop = Main01DesignTokens.Colors.rgb(35, 47, 96)

    /// 실타래 섹션 배경(362px): 살짝 밝은 남색에서 시작해 광고 버튼 근처(60%)에서 남색이 된다.
    static let threadBackground = LinearGradient(
        stops: [
            .init(color: threadTop, location: 0),
            .init(color: navy, location: 0.605),
            .init(color: navy, location: 1),
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// 상·하단 크롬: 남색이 35%까지 꽉 차 있다가 투명으로 풀린다.
    /// 불투명 배경이 아니라 투명으로 풀리기 때문에, 아래로 지나가는 콘텐츠 색과 자연스럽게 섞인다.
    /// → FIT LAB(남색) 구간이 지나갈 때만 위·아래가 통째로 남색으로 이어진다.
    /// 상단 헤더 페이드: Figma 화면을 측정하면 남색이 60px까지 유지되다 260px에서 완전히 풀린다.
    static let topFadeSolidUntil: CGFloat = 60
    static let topFadeEnd: CGFloat = 260

    static func chromeFade(fromTop: Bool, solidUntil: CGFloat = 0.351) -> LinearGradient {
        LinearGradient(
            stops: CoorditSmoothGradient.fade(color: navy, solidUntil: solidUntil),
            startPoint: fromTop ? .top : .bottom,
            endPoint: fromTop ? .bottom : .top
        )
    }
}

/// 층(띠) 없이 이어지는 그라데이션 도구.
/// 몇 개 지점을 직선으로 이으면 꺾이는 곳마다 눈에 경계(마하 밴드)가 보인다. 그래서 매끄러운 곡선
/// (smootherstep)을 촘촘하게 샘플링해 기울기가 갑자기 바뀌지 않게 만든다.
enum CoorditSmoothGradient {
    static let sampleCount = 32

    /// Figma 화면에서 잰 밝아지는 곡선: smoothstep(t^0.89).
    /// 시작과 끝 모두 기울기 0이라 남색·배경색에 닿는 곳에서 꺾임(선처럼 보이는 경계)이 없고,
    /// 지수 0.89로 가운데를 살짝 앞당겨 Figma 측정값과 0.03 이내로 맞춘다.
    static func ease(_ t: CGFloat) -> CGFloat {
        let x = pow(min(max(t, 0), 1), 0.89)
        return x * x * (3 - 2 * x)
    }

    /// `solidUntil`까지는 불투명, 그 뒤로 투명까지 부드럽게 풀린다.
    static func fade(color: Color, solidUntil: CGFloat) -> [Gradient.Stop] {
        var stops: [Gradient.Stop] = [.init(color: color, location: 0)]
        for index in 0...sampleCount {
            let t = CGFloat(index) / CGFloat(sampleCount)
            let location = solidUntil + (1 - solidUntil) * t
            stops.append(.init(color: color.opacity(1 - ease(t)), location: location))
        }
        return stops
    }

    /// `solidUntil`까지 `from` 색, `end`에서 `to` 색이 되고 그 뒤로는 `to` 색.
    static func blend(from: RGB, to: RGB, solidUntil: CGFloat, end: CGFloat) -> [Gradient.Stop] {
        var stops: [Gradient.Stop] = [.init(color: from.color, location: 0)]
        for index in 0...sampleCount {
            let t = CGFloat(index) / CGFloat(sampleCount)
            let location = solidUntil + (end - solidUntil) * t
            stops.append(.init(color: from.mixed(with: to, amount: ease(t)).color, location: location))
        }
        if end < 1 { stops.append(.init(color: to.color, location: 1)) }
        return stops
    }

    struct RGB {
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat

        init(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) {
            self.red = red
            self.green = green
            self.blue = blue
        }

        var color: Color { Main01DesignTokens.Colors.rgb(red, green, blue) }

        func mixed(with other: RGB, amount: CGFloat) -> RGB {
            RGB(
                red + (other.red - red) * amount,
                green + (other.green - green) * amount,
                blue + (other.blue - blue) * amount
            )
        }

        static let navy = RGB(0, 12, 64)
        static let closetTop = RGB(244, 245, 248)
        static let threadTop = RGB(35, 47, 96)
    }
}

/// 눈에 보이지 않는 미세 노이즈. 남색→밝은색처럼 좁은 색 범위가 길게 이어질 때 8비트 색 단계가
/// 몇 픽셀씩 뭉쳐 생기는 띠를 흩뜨린다(Figma 원본 배경의 노이즈와 같은 역할).
struct CoorditDitherNoise: View {
    private static let tile: UIImage = {
        let size = 96
        var generator = SystemRandomNumberGenerator()
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        for index in 0..<(size * size) {
            let white = Bool.random(using: &generator)
            let alpha = UInt8.random(in: 0...3, using: &generator)
            let value: UInt8 = white ? 255 : 0
            // 미리 곱한(premultiplied) 알파 형식.
            let premultiplied = UInt8((Int(value) * Int(alpha)) / 255)
            pixels[index * 4] = premultiplied
            pixels[index * 4 + 1] = premultiplied
            pixels[index * 4 + 2] = premultiplied
            pixels[index * 4 + 3] = alpha
        }
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        let image = CGImage(
            width: size,
            height: size,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: size * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!
        return UIImage(cgImage: image, scale: 3, orientation: .up)
    }()

    var body: some View {
        Image(uiImage: Self.tile)
            .resizable(resizingMode: .tile)
            .interpolation(.none)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

extension View {
    /// Figma 공용 칩(#737B9D, 흰 테두리 35%) 모양의 큰 버튼.
    func coorditHomePrimaryChip(
        layout: CoorditHomeLayout,
        verticalPadding: CGFloat = 13,
        fill: Color = CoorditHomePalette.chipFill
    ) -> some View {
        self
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(.white)
            .padding(.horizontal, layout.value(15.124))
            .padding(.vertical, layout.value(verticalPadding))
            .frame(maxWidth: .infinity)
            .background(fill, in: Capsule())
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
    /// 화면 위에서 실타래 섹션 윗선까지의 거리. 4번 화면에서 헤더 아래를 실타래 남색으로 채운다.
    let threadTopOnScreen: CGFloat?
    /// 화면 높이. 3번 화면 하단 덮개 계산에 쓴다.
    let viewportHeight: CGFloat

    /// 실타래 윗선이 정지선(270px) 근처면 1.
    /// 4번 화면은 스크롤 끝과 합쳐져 폰마다 실타래 위치가 조금씩 달라서, 정지선 아래 200px까지는
    /// 완전히 불투명하게 둔다. 반투명이면 밝은 배경이 비쳐 남색과 실타래 사이에 흰 줄이 생긴다.
    private var threadBlend: CGFloat {
        guard let threadTopOnScreen else { return 0 }
        let rest = layout.value(CoorditHomeSnapStop.footer.sectionInset + 200)
        let x = 1 - (threadTopOnScreen - rest) / layout.value(300)
        let t = min(max(x, 0), 1)
        return t * t * (3 - 2 * t)
    }

    /// 3번 화면 하단: 실타래 섹션 윗선이 화면 아래쪽(하단 내비 근처)에 있을 때 1.
    /// 이때 실타래 윗선 대신 CLOSET 배경 → 남색 그라데이션이 보이게 덮는다.
    private var closetBottomBlend: CGFloat {
        guard let threadTopOnScreen, threadTopOnScreen < viewportHeight, viewportHeight > 0 else { return 0 }
        let x = (threadTopOnScreen - viewportHeight * 0.55) / (viewportHeight * 0.25)
        let t = min(max(x, 0), 1)
        return t * t * (3 - 2 * t)
    }

    /// 3번 화면 하단 덮개가 실타래 윗선보다 위로 더 올라가 풀리는 길이(Figma px).
    private static let closetBottomFeather: CGFloat = 90

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
    /// 미세 노이즈를 까는 상·하단 높이(Figma px).
    private static let ditherHeight: CGFloat = 420

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

    /// 헤더 남색 → 섹션 윗부분 색으로 이어지는 덮개.
    /// 섹션 윗선에서 끝내면 그 아래로 헤더 남색 페이드(225px)의 꼬리가 남아 밝아지다 어두워지는
    /// 계단(층)이 생긴다. 그래서 덮개를 헤더 페이드 끝보다 아래까지 섹션 색으로 이어 칠한다.
    private func sectionBlend(sectionTop: CGFloat, sectionColor: CoorditSmoothGradient.RGB) -> some View {
        // Figma처럼 남색은 60px까지, 섹션 색은 260px(섹션이 더 아래면 섹션 윗선)에서 완성된다.
        let colorEnd = max(sectionTop, layout.value(CoorditHomePalette.topFadeEnd))
        let height = colorEnd + layout.value(4)
        return LinearGradient(
            stops: CoorditSmoothGradient.blend(
                from: .navy,
                to: sectionColor,
                solidUntil: layout.value(CoorditHomePalette.topFadeSolidUntil) / height,
                end: colorEnd / height
            ),
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: height)
    }

    var body: some View {
        ZStack {
            ZStack(alignment: .top) {
                CoorditHomePalette.chromeFade(
                    fromTop: true,
                    solidUntil: CoorditHomePalette.topFadeSolidUntil / CoorditHomePalette.topFadeEnd
                )
                .frame(height: layout.value(CoorditHomePalette.topFadeEnd))
                // FIT LAB 섹션 시작선(210px)까지는 완전한 남색, 그 아래 30px에서만 풀린다.
                // 2번 화면에서 풀리는 구간은 FIT LAB 남색 위에 겹치므로 경계가 보이지 않는다.
                LinearGradient(
                    stops: CoorditSmoothGradient.fade(color: CoorditHomePalette.navy, solidUntil: topSolidRatio),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: topCoverHeight)
                .opacity(tint.top)

                if let closetTopOnScreen, closetTopOnScreen > 0, closetBlend > 0 {
                    sectionBlend(sectionTop: closetTopOnScreen, sectionColor: .closetTop)
                        .opacity(closetBlend)
                }

                if let threadTopOnScreen, threadTopOnScreen > 0, threadBlend > 0 {
                    sectionBlend(sectionTop: threadTopOnScreen, sectionColor: .threadTop)
                        .opacity(threadBlend)
                }
            }
            .frame(height: topCoverHeight, alignment: .top)
            .frame(maxHeight: .infinity, alignment: .top)
            // 겹친 반투명 레이어를 한 번에 고정밀(부동소수점)로 합성해 단계마다 반올림되며 생기는 계단을 줄인다.
            .drawingGroup(opaque: false, colorMode: .extendedLinear)
            .overlay(alignment: .top) {
                CoorditDitherNoise()
                    .frame(height: layout.value(Self.ditherHeight))
                    .mask {
                        LinearGradient(
                            stops: CoorditSmoothGradient.fade(color: .black, solidUntil: 0.7),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
            }

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

                if let threadTopOnScreen, closetBottomBlend > 0 {
                    let feather = layout.value(Self.closetBottomFeather)
                    let height = viewportHeight - threadTopOnScreen + feather
                    LinearGradient(
                        stops: [
                            .init(color: CoorditHomePalette.closetTop.opacity(0), location: 0),
                            .init(color: CoorditHomePalette.closetTop, location: min(feather / max(height, 1), 0.5)),
                            .init(color: CoorditHomePalette.navy, location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: max(height, 0))
                    .opacity(closetBottomBlend)
                }

                CoorditHomePalette.chromeFade(fromTop: false)
                    .frame(height: layout.value(290))
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            .drawingGroup(opaque: false, colorMode: .extendedLinear)
            .overlay(alignment: .bottom) {
                CoorditDitherNoise()
                    .frame(height: layout.value(Self.ditherHeight))
                    .mask {
                        LinearGradient(
                            stops: CoorditSmoothGradient.fade(color: .black, solidUntil: 0.7),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
#endif
