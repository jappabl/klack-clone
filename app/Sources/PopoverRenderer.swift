import AppKit

/// Surface A — the Klack popover.
/// Row geometry is transcribed from LEDGER.md; every constant is a measured value.
struct PopoverState {
    var enabled = true
    var volume: CGFloat = 0.70
    var hovered: Int? = nil          // row index
    var toggleFocused = false
    var thumbPressed = false          // pointer down on the slider
    var thumbDragging = false         // moved >3px: `left` transition is dropped

    var rowHover: [Int: Anim] = [:]
    var knob = Anim(1, duration: 0.220, easing: .knob)
    var track = Anim(1, duration: 0.220, easing: .easeOut)
    var fill  = Anim(0.70, duration: 0.220, easing: .easeOut)
    /// `transition-[scale,box-shadow] duration-220 ease-out`, target `scale-110`
    var thumbScale = Anim(1, duration: 0.220, easing: .easeOut)

    mutating func hoverProgress(_ i: Int) -> CGFloat { rowHover[i]?.value ?? 0 }

    mutating func setHover(_ i: Int?) {
        guard hovered != i else { return }
        hovered = i
        for r in PopoverRenderer.interactiveRows {
            var a = rowHover[r] ?? Anim(0, duration: 0.100, easing: .easeOut)
            a.set(r == i ? 1 : 0)
            rowHover[r] = a
        }
    }

    mutating func tick(_ dt: CGFloat) -> Bool {
        var live = false
        for k in rowHover.keys {
            var a = rowHover[k]!; if a.isRunning { live = true }
            a.tick(dt); rowHover[k] = a
        }
        for kp in [\PopoverState.knob, \PopoverState.track, \PopoverState.fill, \PopoverState.thumbScale] {
            if self[keyPath: kp].isRunning { live = true }
            self[keyPath: kp].tick(dt)
        }
        return live
    }
}

enum PopoverRenderer {

    // MARK: layout — panel-relative, logical px
    static let W = PopoverMetrics.width, H = PopoverMetrics.height
    static let contentTop: CGFloat = 13        // padding 12 + border-top 1
    static let contentX: CGFloat = 12
    static let contentW: CGFloat = 264
    static let rowX: CGFloat = 24              // content + li px-3
    static let rowW: CGFloat = 240

    enum Row { case body(CGFloat, CGFloat), header(CGFloat, CGFloat) }
    /// (y, height) panel-relative, in list order.
    static let rows: [(y: CGFloat, h: CGFloat, header: Bool)] = [
        (13.0,  30.5, false),   // 0 Klack + toggle
        (49.5,  31.0, true),    // 1 Sound
        (82.5,  28.0, false),   // 2 slider
        (116.5, 31.0, true),    // 3 Switches
        (149.5, 96.0, false),   // 4 switches preview
        (251.5, 31.0, true),    // 5 Version 2.2
        (284.5, 30.5, false),   // 6 Klack Settings...
        (328.0, 30.5, false),   // 7 Quit Klack
    ]
    static let interactiveRows = [6, 7]

    static func rowRect(_ i: Int) -> CGRect {
        CGRect(x: contentX, y: rows[i].y, width: contentW, height: rows[i].h)
    }

    static func rowRadii(_ i: Int) -> (CGFloat, CGFloat, CGFloat, CGFloat) {
        if i == 0 { return (12, 12, 8, 8) }
        if i == rows.count - 1 { return (8, 8, 12, 12) }
        return (8, 8, 8, 8)
    }

    static var toggleRect: CGRect {
        CGRect(x: rowX + rowW - 44, y: rows[0].y + 4 + (22.5 - 20)/2, width: 44, height: 20)
    }
    static var trackRect: CGRect {
        CGRect(x: rowX, y: rows[2].y + 4 + 6, width: rowW, height: 4)
    }
    static let thumbW: CGFloat = 20, thumbH: CGFloat = 16
    /// The thumb is inset so it never overhangs the track: its centre travels
    /// `v x (trackW - thumbW) + thumbW/2`. Reading the reference only at its
    /// default 70% hid this — the two formulas agree at 0.70 and nowhere else.
    /// Confirmed against the live slider at 40%: left edge = 24 + 0.4x220 = 112.
    static func thumbRect(_ v: CGFloat) -> CGRect {
        CGRect(x: rowX + v * (rowW - thumbW), y: trackRect.midY - thumbH/2,
               width: thumbW, height: thumbH)
    }

    /// Hit-test in panel-relative coordinates.
    static func hitRow(_ p: CGPoint) -> Int? {
        for i in interactiveRows where rowRect(i).contains(p) { return i }
        return nil
    }

    // MARK: draw
    static func draw(_ ctx: CGContext, origin: CGPoint, state: PopoverState,
                     backdrop: CGImage?, backdropOriginCSS: CGPoint, scale: CGFloat) {
        ctx.saveGState()
        ctx.translateBy(x: origin.x, y: origin.y)

        let panel = CGRect(x: 0, y: 0, width: W, height: H)
        let shape = Draw.roundedPath(panel, PopoverMetrics.radius)

        // shadow  — 0 25px 50px -12px stone-800/30
        Draw.shadow(ctx, rect: panel, radius: PopoverMetrics.radius,
                    CSSShadow.panelLight, scale: scale)

        // backdrop-filter: blur(24px), then the 80% fill on top
        if let bd = backdrop {
            Draw.backdropBlur(ctx, backdrop: bd,
                              backdropOriginCSS: CGPoint(x: backdropOriginCSS.x - origin.x,
                                                         y: backdropOriginCSS.y - origin.y),
                              scale: scale, rect: panel, path: shape,
                              sigma: T.backdropSigmaFor24)
        }
        Draw.fill(ctx, shape, T.orange50.withAlphaComponent(0.80))
        Draw.borderTop(ctx, rect: panel, radius: PopoverMetrics.radius,
                       width: 1, color: T.orange50.withAlphaComponent(0.30))

        let body   = T.font(15, 500)
        let bodyB  = T.font(15, 700)
        let header = T.font(14, 600)
        let hdrColor = T.stone500.withAlphaComponent(0.75)
        let ruleColor = T.stone800.withAlphaComponent(0.10)

        // hovered row backgrounds (transition: 100ms ease-out)
        var st = state
        for i in interactiveRows {
            let p = st.hoverProgress(i)
            guard p > 0.001 else { continue }
            let (tl, tr, br, bl) = rowRadii(i)
            Draw.fill(ctx, Draw.roundedPath(Draw.snapped(ctx, rowRect(i)), tl, tr, br, bl),
                      T.stone800.withAlphaComponent(0.10 * p))
        }
        func textColor(_ i: Int) -> NSColor {
            let p = st.hoverProgress(i)
            guard p > 0 else { return T.stone800 }
            return blend(T.stone800, T.orange50, p)
        }

        // r0 — "Klack" + toggle
        Draw.text(ctx, "Klack", x: rowX, lineTop: rows[0].y + 4,
                  lineHeight: 22.5, font: bodyB, color: T.stone800)
        drawToggle(ctx, state: st)

        // r1 — Sound
        drawHeader(ctx, i: 1, "Sound", font: header, color: hdrColor, rule: ruleColor)

        // r2 — slider
        let tr = trackRect
        Draw.fillPill(ctx, tr, T.stone800.withAlphaComponent(0.10))
        let v = st.fill.value
        if v > 0 {
            Draw.fillPill(ctx, CGRect(x: tr.minX, y: tr.minY, width: tr.width * v, height: tr.height),
                          T.stone800)
        }
        // `scale-110` on press, scaled about the thumb's centre
        let base = thumbRect(v)
        let k = st.thumbScale.value
        let th = CGRect(x: base.midX - base.width  * k / 2,
                        y: base.midY - base.height * k / 2,
                        width: base.width * k, height: base.height * k)
        Draw.shadow(ctx, rect: th, radius: th.height/2, CSSShadow.sm, scale: scale)
        Draw.fillPill(ctx, th, T.orange50)

        // r3 — Switches
        drawHeader(ctx, i: 3, "Switches", font: header, color: hdrColor, rule: ruleColor)

        // r4 — switches preview (masked, fades to transparent downward)
        drawSwitchPreview(ctx)

        // r5 — Version 2.2
        drawHeader(ctx, i: 5, nil, font: header, color: hdrColor, rule: ruleColor)
        let vx = Draw.text(ctx, "Version", x: rowX, lineTop: rows[5].y + 11,
                           lineHeight: 20, font: header, color: hdrColor)
        Draw.text(ctx, "2.2", x: rowX + vx + 4, lineTop: rows[5].y + 11,
                  lineHeight: 20, font: header, color: hdrColor)

        // r6 / r7
        Draw.text(ctx, "Klack Settings...", x: rowX, lineTop: rows[6].y + 4,
                  lineHeight: 22.5, font: body, color: textColor(6))
        // r7 rule sits 7px above the row box
        Draw.fillRect(ctx, CGRect(x: rowX, y: rows[7].y - 7, width: rowW, height: 1), ruleColor)
        Draw.text(ctx, "Quit Klack", x: rowX, lineTop: rows[7].y + 4,
                  lineHeight: 22.5, font: body, color: textColor(7))

        ctx.restoreGState()
    }

    private static func drawHeader(_ ctx: CGContext, i: Int, _ s: String?,
                                   font: NSFont, color: NSColor, rule: NSColor) {
        Draw.fillRect(ctx, CGRect(x: rowX, y: rows[i].y, width: rowW, height: 1), rule)
        if let s {
            Draw.text(ctx, s, x: rowX, lineTop: rows[i].y + 11,
                      lineHeight: 20, font: font, color: color)
        }
    }

    private static func drawToggle(_ ctx: CGContext, state: PopoverState) {
        let r = toggleRect
        let on = state.track.value
        // measured on the live reference by toggling it: bg-stone-800/10
        let off = T.stone800.withAlphaComponent(0.10)
        Draw.fillPill(ctx, r, blend(off, T.teal500, on))
        if state.toggleFocused {
            // focus-visible:ring-2 ring-stone-800/20  ->  a 2px ring outside the border box
            ctx.saveGState()
            ctx.addPath(Draw.pill(r.insetBy(dx: -1, dy: -1)))
            ctx.setStrokeColor(T.stone800.withAlphaComponent(0.20).cgColor)
            ctx.setLineWidth(2)
            ctx.strokePath()
            ctx.restoreGState()
        }
        let travel: CGFloat = 14
        let knob = CGRect(x: r.minX + 2 + travel * state.knob.value, y: r.minY + 2,
                          width: 26, height: 16)
        Draw.shadow(ctx, rect: knob, radius: 8, CSSShadow.xs, scale: 2)
        Draw.fillPill(ctx, knob, T.orange50)
    }

    private static func drawSwitchPreview(_ ctx: CGContext) {
        let top = rows[4].y + 4 + 4          // py-1 + mt-1
        let block = CGRect(x: rowX, y: top, width: rowW, height: 78)
        Draw.withVerticalFadeMask(ctx, rect: block) { c in
            let widths: [CGFloat] = [96, 80, 112]
            for (n, w) in widths.enumerated() {
                let y = top + CGFloat(n) * 30
                Draw.fillRounded(c, CGRect(x: rowX, y: y, width: 18, height: 18), 6,
                                 T.stone800.withAlphaComponent(0.15))
                Draw.fillRounded(c, CGRect(x: rowX + 28, y: y + 6, width: w, height: 6), 3,
                                 T.stone800.withAlphaComponent(0.10))
                if n == 0 {
                    // size-3.5 box with pb-0.5 -> 14x12 content, glyph fits to 12x12, centred
                    let g = SVGPath.path(Art.check, viewBox: 28, size: 12,
                                         origin: CGPoint(x: rowX + rowW - 14 + 1, y: y + 2))
                    Draw.fill(c, g, T.stone800.withAlphaComponent(0.15))
                }
            }
        }
    }
}

func blend(_ a: NSColor, _ b: NSColor, _ t: CGFloat) -> NSColor {
    let x = a.usingColorSpace(.sRGB)!, y = b.usingColorSpace(.sRGB)!
    return NSColor(srgbRed: x.redComponent   + (y.redComponent   - x.redComponent)   * t,
                   green:   x.greenComponent + (y.greenComponent - x.greenComponent) * t,
                   blue:    x.blueComponent  + (y.blueComponent  - x.blueComponent)  * t,
                   alpha:   x.alphaComponent + (y.alphaComponent - x.alphaComponent) * t)
}
