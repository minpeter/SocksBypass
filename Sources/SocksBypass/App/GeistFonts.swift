import CoreText
import Foundation

/// Registers the bundled Geist / Geist Mono (SIL OFL 1.1, see Fonts/Geist-OFL.txt).
/// Hangul and other missing glyphs fall back to the system font automatically.
enum GeistFonts {
    static func register() {
        guard let dir = Bundle.module.url(forResource: "Fonts", withExtension: nil),
              let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for url in files where url.pathExtension == "ttf" {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
