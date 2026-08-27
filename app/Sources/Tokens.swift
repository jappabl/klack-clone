import AppKit

/// Design tokens, resolved to sRGB from the reference's oklch values.
/// Every value here traces to a row in ../LEDGER.md.
enum T {

    // MARK: palette (measured: tools/colors.mjs)
    static let orange50  = srgb(255, 247, 237)   // oklch(.98 .016 73.684)
    static let stone400  = srgb(166, 160, 155)
    static let stone500  = srgb(121, 113, 107)
    static let stone800  = srgb( 41,  37,  36)
    static let stone900  = srgb( 28,  25,  23)
    static let teal500   = srgb(  0, 187, 167)
    static let rose      = NSColor(srgbRed: 243/255, green: 88/255, blue: 115/255, alpha: 1)

    static func srgb(_ r: Int, _ g: Int, _ b: Int, _ a: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: CGFloat(r)/255, green: CGFloat(g)/255, blue: CGFloat(b)/255, alpha: a)
    }

    // MARK: type
    /// CSS `font-weight` -> AppKit weight.
    static func font(_ size: CGFloat, _ cssWeight: Int) -> NSFont {
        let w: NSFont.Weight
        switch cssWeight {
        case 900: w = .black
        case 800: w = .heavy
        case 700: w = .bold
        case 600: w = .semibold
        case 500: w = .medium
        default:  w = .regular
        }
        return NSFont.systemFont(ofSize: size, weight: w)
    }

    // MARK: filter calibration (tools/calib2.mjs, fitted against Chrome)
    /// CSS `blur(24px)` measured as a Gaussian with sigma 23.10 at 1x.
    static let backdropSigmaFor24: CGFloat = 23.10
    /// CSS `box-shadow ... 50px ...` measured as sigma 26.52 at 1x (= r/2 x 1.06).
    static func shadowSigma(cssBlur: CGFloat) -> CGFloat { cssBlur * 0.5305 }
}

/// A CSS box-shadow: offset, blur radius, spread, colour.
struct CSSShadow {
    var dx: CGFloat = 0
    var dy: CGFloat
    var blur: CGFloat
    var spread: CGFloat
    var color: NSColor

    static let panelLight = CSSShadow(dy: 25, blur: 50, spread: -12,
                                      color: T.stone800.withAlphaComponent(0.30))
    static let panelDark  = CSSShadow(dy: 25, blur: 50, spread: -12,
                                      color: T.stone900.withAlphaComponent(0.80))
    /// Tailwind `shadow-sm`: 0 1px 3px rgba/.1, 0 1px 2px -1px rgba/.1
    static let sm         = CSSShadow(dy: 1, blur: 3, spread: 0,
                                      color: T.stone800.withAlphaComponent(0.10))
    /// Tailwind `shadow-xs`: 0 1px 0 rgba/.1
    static let xs         = CSSShadow(dy: 1, blur: 0, spread: 0,
                                      color: T.stone800.withAlphaComponent(0.10))
}

/// Geometry of surface A, the popover. All values in logical px, from LEDGER.md.
enum PopoverMetrics {
    static let width: CGFloat = 288
    static let height: CGFloat = 370.5
    static let radius: CGFloat = 24
    static let padding: CGFloat = 12
    static let rowInsetX: CGFloat = 12          // li px-3
    static let rowGap: CGFloat = 2              // li+li mt-0.5
    static let headerPadTop: CGFloat = 11
    static let headerMarginTop: CGFloat = 6
    static let bodySize: CGFloat = 15
    static let bodyLine: CGFloat = 22.5
    static let headerSize: CGFloat = 14
    static let headerLine: CGFloat = 20
    static let rowRadius: CGFloat = 8
    static let firstRowRadiusTop: CGFloat = 12
    static let lastRowRadiusBottom: CGFloat = 12
}

/// Geometry of surface B, the switches panel.
enum SwitchesMetrics {
    static let width: CGFloat = 328
    static let height: CGFloat = 551
    static let radius: CGFloat = 24
    static let padding: CGFloat = 12
    static let rowInsetX: CGFloat = 12
    static let rowGap: CGFloat = 2
    static let rowHeight: CGFloat = 36
    static let headerPadTop: CGFloat = 11
    static let headerPadTopFirst: CGFloat = 10
    static let headerMarginTop: CGFloat = 6
    static let swatch: CGFloat = 18
    static let swatchRadius: CGFloat = 6
    static let swatchGap: CGFloat = 8           // mr-2
    static let playSize: CGFloat = 24
    static let previewGap: CGFloat = 8
}

struct SwitchModel {
    let name: String
    let top: NSColor
    let bottom: NSColor
    let isNew: Bool
}

struct SwitchGroup {
    let brand: String
    let items: [SwitchModel]
}

enum Catalog {
    static func hex(_ s: String) -> NSColor {
        var v: UInt64 = 0
        Scanner(string: String(s.dropFirst())).scanHexInt64(&v)
        return T.srgb(Int((v >> 16) & 0xff), Int((v >> 8) & 0xff), Int(v & 0xff))
    }
    /// Gradient stops read out of the reference's inline <linearGradient> defs.
    static let groups: [SwitchGroup] = [
        SwitchGroup(brand: "CherryMX™", items: [
            SwitchModel(name: "Japanese Black", top: hex("#878078"), bottom: hex("#44403c"), isNew: false)]),
        SwitchGroup(brand: "Everglide™", items: [
            SwitchModel(name: "Crystal Purple", top: hex("#f1acfb"), bottom: hex("#e879f9"), isNew: false),
            SwitchModel(name: "Oreo",           top: hex("#b2ada9"), bottom: hex("#78716c"), isNew: false)]),
        SwitchGroup(brand: "Flurples™", items: [
            SwitchModel(name: "Cardboard",      top: hex("#f7baa1"), bottom: hex("#f28c61"), isNew: false)]),
        SwitchGroup(brand: "Gateron™", items: [
            SwitchModel(name: "Milky Yellow",   top: hex("#fef6d7"), bottom: hex("#fde481"), isNew: false)]),
        SwitchGroup(brand: "Keychron™", items: [
            SwitchModel(name: "Super Red",      top: hex("#fb7185"), bottom: hex("#e11d48"), isNew: true)]),
        SwitchGroup(brand: "NovelKeys™", items: [
            SwitchModel(name: "Cream",          top: hex("#fff3e6"), bottom: hex("#fecf9a"), isNew: false)]),
    ]
}
