import AppKit

/// The verification stage: the exact page composition the reference was captured
/// from, so the clone and the reference can be diffed over an identical backdrop.
/// Translucent UI has no appearance independent of what is behind it, so the
/// backdrop has to be part of the measurement.
enum Stage {
    static let pageSize = CGSize(width: 1440, height: 1300)
    static let wallpaperRect = CGRect(x: 144, y: 572, width: 1152, height: 576)
    static let wallpaperRadius: CGFloat = 48
    /// `aspect-video h-auto w-full` -> 1152 x 648, anchored top, clipped by the parent.
    static let wallpaperDraw = CGRect(x: 144, y: 572, width: 1152, height: 648)
    static let popoverOrigin = CGPoint(x: 1044, y: 668)
    static let switchesOrigin = CGPoint(x: 176, y: 664.5)

    /// Crops that mirror the reference captures, in page coordinates.
    static let crops: [(String, CGRect)] = [
        ("pop",    CGRect(x: 1044, y: 668, width: 288, height: 370.5)),
        ("sw",     CGRect(x: 176, y: 664.5, width: 328, height: 551)),
        ("pop-sh", CGRect(x: 1008, y: 668, width: 360, height: 414.5)),
        ("sw-sh",  CGRect(x: 140, y: 664.5, width: 400, height: 595)),
        ("hero",   CGRect(x: 144, y: 572, width: 1152, height: 576)),
    ]

    static var wallpaper: CGImage? = {
        let candidates = [
            Bundle.main.url(forResource: "wallpaper", withExtension: "jpg"),
            URL(fileURLWithPath: "assets/wallpaper.jpg"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("assets/wallpaper.jpg"),
        ].compactMap { $0 }
        for u in candidates {
            if let d = try? Data(contentsOf: u),
               let src = CGImageSourceCreateWithData(d as CFData, nil),
               let img = CGImageSourceCreateImageAtIndex(src, 0, nil) { return img }
        }
        FileHandle.standardError.write("warning: wallpaper.jpg not found\n".data(using: .utf8)!)
        return nil
    }()

    /// Everything behind the panels. Rendered once; the panels' backdrop-filter
    /// samples this, exactly as CSS samples the backdrop root.
    static func backdropImage(scale: CGFloat) -> CGImage? {
        let w = Int(pageSize.width * scale), h = Int(pageSize.height * scale)
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: scale, y: -scale)          // flip to CSS orientation
        ctx.interpolationQuality = .high
        drawBackdrop(ctx)
        return ctx.makeImage()
    }

    static func drawBackdrop(_ ctx: CGContext) {
        Draw.fillRect(ctx, CGRect(origin: .zero, size: pageSize), T.orange50)
        ctx.saveGState()
        ctx.addPath(Draw.roundedPath(wallpaperRect, wallpaperRadius))
        ctx.clip()
        Draw.fillRect(ctx, wallpaperRect, T.stone900)
        if let wp = wallpaper { Draw.image(ctx, wp, in: wallpaperDraw) }
        ctx.restoreGState()
    }

    /// Full composition: backdrop + both surfaces.
    static func drawAll(_ ctx: CGContext, pop: PopoverState, sw: SwitchesState,
                        backdrop: CGImage?, scale: CGFloat) {
        drawBackdrop(ctx)
        SwitchesRenderer.draw(ctx, origin: switchesOrigin, state: sw,
                              backdrop: backdrop, backdropOriginCSS: .zero, scale: scale)
        PopoverRenderer.draw(ctx, origin: popoverOrigin, state: pop,
                             backdrop: backdrop, backdropOriginCSS: .zero, scale: scale)
    }
}

/// The on-screen view used by --verify. Its `draw` is the same code path the
/// shipping panels use, so what gets measured is what the app renders.
final class StageView: NSView {
    var pop = PopoverState()
    var sw = SwitchesState()
    var backdrop: CGImage?
    var backdropOnly = false
    override var isFlipped: Bool { true }

    override func draw(_ dirty: CGRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        if backdropOnly { Stage.drawBackdrop(ctx); return }
        Stage.drawAll(ctx, pop: pop, sw: sw, backdrop: backdrop, scale: 2)
    }
}
