import CoreText
import Foundation

enum CoorditFontRegistration {
    private static let bundledFonts = [
        ("ClimateCrisisKRVF", "ttf"),
        ("GmarketSansLight", "otf"),
        ("GmarketSansMedium", "otf"),
        ("GmarketSansBold", "otf"),
        ("Mona12TextHK", "otf")
    ]

    static func registerBundledFonts() {
        for font in bundledFonts {
            guard let url = Bundle.main.url(forResource: font.0, withExtension: font.1) else {
                continue
            }

            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
