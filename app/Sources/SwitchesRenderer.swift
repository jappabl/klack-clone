import AppKit

/// Surface B — the switches panel.
struct SwitchesState {
    var hovered: Int? = nil           // index into `SwitchesRenderer.items`
    var playing: Int? = nil
    /// Tailwind `animate-pulse`: opacity 1 -> .5 -> 1 over 2s, cubic-bezier(.4,0,.6,1).
    /// Held at the 0% phase for verification captures.
    var pulse: CGFloat = 1
    var rowHover: [Int: Anim] = [:]        // row background: 100ms ease-out
    var affHover: [Int: Anim] = [:]        // Preview label + play button: 150ms ease-in-out

    mutating func setHover(_ i: Int?) {
        guard hovered != i else { return }
        hovered = i
        for r in 0..<SwitchesRenderer.items.count {
            var a = rowHover[r] ?? Anim(0, duration: 0.100, easing: .easeOut)
            a.set(r == i ? 1 : 0)
            rowHover[r] = a
            var b = affHover[r] ?? Anim(0, duration: 0.150, easing: .easeInOut)
            b.set(r == i ? 1 : 0)
            affHover[r] = b
        }
    }
    func progress(_ i: Int) -> CGFloat { rowHover[i]?.value ?? 0 }
    func affordance(_ i: Int) -> CGFloat { affHover[i]?.value ?? 0 }
    mutating func tick(_ dt: CGFloat) -> Bool {
        var live = false
        for k in rowHover.keys {
            var a = rowHover[k]!; if a.isRunning { live = true }
            a.tick(dt); rowHover[k] = a
        }
        for k in affHover.keys {
            var a = affHover[k]!; if a.isRunning { live = true }
            a.tick(dt); affHover[k] = a
        }
        return live
    }
}

enum SwitchesRenderer {

    static let W = SwitchesMetrics.width, H = SwitchesMetrics.height
    static let contentTop: CGFloat = 13
    static let contentX: CGFloat = 12
    static let contentW: CGFloat = 304
    static let rowX: CGFloat = 24
    static let rowW: CGFloat = 280

    struct Line { let y: CGFloat; let h: CGFloat; let header: Bool; let idx: Int }

    /// Flattened list, panel-relative. Built once from the catalogue with the
    /// measured spacing rules: header pt 11 (first 10) + mt 6, rows h 36 + gap 2.
    static let (lines, items): ([Line], [SwitchModel]) = {
        var out: [Line] = []
        var models: [SwitchModel] = []
        var y = contentTop
        var first = true
        for g in Catalog.groups {
            if !first { y += SwitchesMetrics.headerMarginTop }
            let h: CGFloat = first ? 30 : 31
            out.append(Line(y: y, h: h, header: true, idx: -1))
            y += h
            first = false
            for m in g.items {
                y += SwitchesMetrics.rowGap
                out.append(Line(y: y, h: SwitchesMetrics.rowHeight, header: false, idx: models.count))
                models.append(m)
                y += SwitchesMetrics.rowHeight
            }
        }
        y += SwitchesMetrics.headerMarginTop
        out.append(Line(y: y, h: 39, header: true, idx: -2))     // trailing ellipsis row
        return (out, models)
    }()

    static func rowRect(_ l: Line) -> CGRect {
        CGRect(x: contentX, y: l.y, width: contentW, height: l.h)
    }

    static func hitRow(_ p: CGPoint) -> Int? {
        for l in lines where !l.header && rowRect(l).contains(p) { return l.idx }
        return nil
    }

    static func draw(_ ctx: CGContext, origin: CGPoint, state: SwitchesState,
                     backdrop: CGImage?, backdropOriginCSS: CGPoint, scale: CGFloat) {
        ctx.saveGState()
        ctx.translateBy(x: origin.x, y: origin.y)

        let panel = CGRect(x: 0, y: 0, width: W, height: H)
        let shape = Draw.roundedPath(panel, SwitchesMetrics.radius)

        Draw.shadow(ctx, rect: panel, radius: SwitchesMetrics.radius,
                    CSSShadow.panelDark, scale: scale)
        if let bd = backdrop {
            Draw.backdropBlur(ctx, backdrop: bd,
                              backdropOriginCSS: CGPoint(x: backdropOriginCSS.x - origin.x,
                                                         y: backdropOriginCSS.y - origin.y),
                              scale: scale, rect: panel, path: shape,
                              sigma: T.backdropSigmaFor24)
        }
        Draw.fill(ctx, shape, T.stone800.withAlphaComponent(0.80))
        Draw.borderTop(ctx, rect: panel, radius: SwitchesMetrics.radius,
                       width: 1, color: T.orange50.withAlphaComponent(0.15))

        let body = T.font(15, 500)
        let hdr  = T.font(14, 600)
        let small = T.font(14, 500)
        let hdrColor = T.orange50.withAlphaComponent(0.40)
        let rule = T.orange50.withAlphaComponent(0.15)

        var groupIter = Catalog.groups.makeIterator()
        var brand: String? = nil

        for l in lines {
            if l.header {
                if l.idx == -2 {
                    // trailing row: rule + centred ellipsis, opacity .6
                    Draw.fillRect(ctx, CGRect(x: rowX, y: l.y, width: rowW, height: 1), rule)
                    let g = SVGPath.path(Art.ellipsis, viewBox: 24, size: 24,
                                         origin: CGPoint(x: rowX + (rowW - 24)/2, y: l.y + 11 + 2))
                    Draw.fill(ctx, g, T.orange50.withAlphaComponent(0.60))
                    continue
                }
                brand = groupIter.next()?.brand
                let isFirst = (l.y == contentTop)
                if !isFirst { Draw.fillRect(ctx, CGRect(x: rowX, y: l.y, width: rowW, height: 1), rule) }
                Draw.text(ctx, brand ?? "", x: rowX,
                          lineTop: l.y + (isFirst ? SwitchesMetrics.headerPadTopFirst
                                                  : SwitchesMetrics.headerPadTop),
                          lineHeight: 20, font: hdr, color: hdrColor)
                continue
            }

            let m = items[l.idx]
            let p = state.progress(l.idx)
            let q = state.affordance(l.idx)     // 150ms ease-in-out, measured

            if p > 0.001 {
                Draw.fillRounded(ctx, rowRect(l), 8, T.orange50.withAlphaComponent(0.10 * p))
            }

            // swatch: gradient keycap, then the two overlay borders
            let sw = CGRect(x: rowX, y: l.y + 9, width: 18, height: 18)
            ctx.saveGState()
            ctx.addPath(Draw.roundedPath(sw, SwitchesMetrics.swatchRadius)); ctx.clip()
            let art = SVGPath.path(Art.swatch, viewBox: 26, size: 18, origin: sw.origin)
            ctx.saveGState()
            ctx.addPath(art); ctx.clip()
            let cs = CGColorSpaceCreateDeviceRGB()
            let grad = CGGradient(colorsSpace: cs, colors: [m.top.cgColor, m.bottom.cgColor] as CFArray,
                                  locations: [0, 1])!
            ctx.drawLinearGradient(grad, start: CGPoint(x: sw.midX, y: sw.minY),
                                   end: CGPoint(x: sw.midX, y: sw.maxY), options: [])
            ctx.restoreGState()
            ctx.restoreGState()
            // border (all sides) 1px orange-50/15, then border-top 1px orange-50/35
            ctx.saveGState()
            ctx.addPath(Draw.roundedPath(sw.insetBy(dx: 0.5, dy: 0.5), SwitchesMetrics.swatchRadius - 0.5))
            ctx.setStrokeColor(T.orange50.withAlphaComponent(0.15).cgColor)
            ctx.setLineWidth(1); ctx.strokePath()
            ctx.restoreGState()
            Draw.borderTop(ctx, rect: sw, radius: SwitchesMetrics.swatchRadius,
                           width: 1, color: T.orange50.withAlphaComponent(0.35))

            // name
            let nameX = rowX + 18 + SwitchesMetrics.swatchGap
            let nameW = Draw.text(ctx, m.name, x: nameX, lineTop: l.y + 6.75,
                                  lineHeight: 22.5, font: body, color: T.orange50)

            if m.isNew {
                let bx = nameX + nameW + 8
                let box = CGRect(x: bx, y: l.y + 8, width: 36, height: 20)
                ctx.saveGState()
                ctx.addPath(Draw.roundedPath(box.insetBy(dx: 0.75, dy: 0.75), 6 - 0.75))
                ctx.setStrokeColor(T.rose.withAlphaComponent(0.75).cgColor)
                ctx.setLineWidth(1.5); ctx.strokePath()
                ctx.restoreGState()
                let f = T.font(12, 600)
                let w = Draw.lineWidth("New", font: f)
                Draw.text(ctx, "New", x: box.midX - w/2, lineTop: box.minY + (20 - 16)/2,
                          lineHeight: 16, font: f, color: T.rose.withAlphaComponent(0.90))
            }

            // play button (right edge), and the "Preview" label that slides in
            let play = CGRect(x: rowX + rowW - 24, y: l.y + 6, width: 24, height: 24)
            Draw.shadow(ctx, rect: play, radius: 12, CSSShadow.sm, scale: scale)
            Draw.fillPill(ctx, play, T.orange50.withAlphaComponent(0.10 + 0.05 * q))
            Draw.borderTop(ctx, rect: play, radius: 12, width: 1,
                           color: T.orange50.withAlphaComponent(0.15))
            // While playing the glyph swaps play -> stop (150ms, opacity+scale-50,
            // mode out-in) and the stop square pulses. The play triangle carries
            // `ml-0.5`; the stop square is centred.
            let playing = (state.playing == l.idx)
            let glyphAlpha = 0.90 * (playing ? state.pulse : 1)
            let glyph = playing
                ? SVGPath.path(Art.stop, viewBox: 28, size: 14,
                               origin: CGPoint(x: play.midX - 7, y: play.midY - 7))
                : SVGPath.path(Art.play, viewBox: 28, size: 14,
                               origin: CGPoint(x: play.midX - 7 + 2, y: play.midY - 7))
            Draw.fill(ctx, glyph, T.orange50.withAlphaComponent(glyphAlpha))

            // the Preview label is replaced by the stop glyph while playing
            if q > 0.001 && !playing {
                let label = "Preview"
                let w = Draw.lineWidth(label, font: small)
                let x = play.minX - SwitchesMetrics.previewGap - w + 4 * (1 - q)   // translate-x-1 -> 0
                Draw.text(ctx, label, x: x, lineTop: l.y + 8, lineHeight: 20,
                          font: small, color: T.orange50.withAlphaComponent(0.40 * q))
            }
        }
        ctx.restoreGState()
    }
}
