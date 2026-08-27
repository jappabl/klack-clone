import AppKit

/// Draws surface D. Same discipline as the panels: every constant comes from
/// SettingsMetrics, which is a measurement off the reference frame.
enum SettingsRenderer {

    /// Row rects recorded during the last draw, so hit-testing uses exactly the
    /// geometry that was painted (including the scroll offset).
    struct Hit { let label: String; let rect: CGRect; let kind: Kind
                 enum Kind { case toggle, slider, popup, pad } }
    private(set) static var hits: [Hit] = []

    // The frame is a dark-appearance window over a bright wallpaper.
    static let label      = NSColor.white
    static let labelDim   = NSColor.white.withAlphaComponent(0.55)
    static let labelOff   = NSColor.white.withAlphaComponent(0.35)
    static let sectionCol = NSColor.white.withAlphaComponent(0.55)
    static let hairline   = NSColor.white.withAlphaComponent(0.12)
    static let groupFill  = NSColor.white.withAlphaComponent(0.08)
    static let selFill    = NSColor.white.withAlphaComponent(0.14)
    static let dividerCol = NSColor.white.withAlphaComponent(0.10)
    static let padFill    = NSColor.white.withAlphaComponent(0.05)
    static let padDot     = NSColor.white.withAlphaComponent(0.22)
    static let padDotLit  = NSColor.white.withAlphaComponent(0.75)
    static let toggleOff  = NSColor.white.withAlphaComponent(0.22)

    private static var symbolCache: [String: CGImage] = [:]

    /// SF Symbol rendered white at `size` pt, cached.
    static func symbol(_ name: String, size: CGFloat, scale: CGFloat) -> CGImage? {
        let key = "\(name)@\(size)@\(scale)"
        if let c = symbolCache[key] { return c }
        let cfg = NSImage.SymbolConfiguration(pointSize: size, weight: .semibold)
        guard let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
                .withSymbolConfiguration(cfg) else { return nil }
        let w = Int((size * 1.6 * scale).rounded()), h = w
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        let g = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = g
        let box = NSRect(x: 0, y: 0, width: CGFloat(w) / scale, height: CGFloat(h) / scale)
        ctx.scaleBy(x: scale, y: scale)
        NSColor.white.set()
        let s = img.size
        let r = NSRect(x: (box.width - s.width)/2, y: (box.height - s.height)/2,
                       width: s.width, height: s.height)
        img.draw(in: r)
        r.fill(using: .sourceAtop)
        NSGraphicsContext.restoreGraphicsState()
        let out = ctx.makeImage()
        if let out { symbolCache[key] = out }
        return out
    }

    // MARK: - sidebar

    static func drawSidebar(_ ctx: CGContext, height: CGFloat, selected: SettingsPane, scale: CGFloat) {
        let M = SettingsMetrics.self
        var y = M.firstItemCenterY
        var first = true
        for (header, panes) in SettingsPane.sections {
            if let header {
                if !first { y += M.itemToHeader }
                let f = T.font(M.headerFont, 600)
                Draw.text(ctx, header, x: M.labelX - 0.3, lineTop: y - 7,
                          lineHeight: 14, font: f, color: sectionCol)
                y += M.headerToFirst
            }
            for p in panes {
                drawItem(ctx, pane: p, centerY: y, selected: p == selected, scale: scale)
                y += M.itemH
                first = false
            }
            y -= M.itemH        // the loop over-advances past the last item
        }
        // divider between sidebar and detail
        Draw.fillRect(ctx, CGRect(x: M.sidebarW, y: 0, width: 1, height: height), dividerCol)
    }

    private static func drawItem(_ ctx: CGContext, pane: SettingsPane,
                                 centerY: CGFloat, selected: Bool, scale: CGFloat) {
        let M = SettingsMetrics.self
        if selected {
            Draw.fillRounded(ctx, CGRect(x: M.selInsetX, y: centerY - M.selH/2,
                                         width: M.selW, height: M.selH),
                             M.selRadius, selFill)
        }
        // icon tile
        let tile = CGRect(x: M.tileX, y: centerY - M.tileSize/2,
                          width: M.tileSize, height: M.tileSize)
        let dim = pane.isComingSoon
        Draw.fillRounded(ctx, tile, M.tileRadius,
                         pane.tile.withAlphaComponent(dim ? 0.55 : 1.0))
        if let g = symbol(pane.symbol, size: M.tileSize * 0.62, scale: scale) {
            let side = CGFloat(g.width) / scale
            Draw.image(ctx, g, in: CGRect(x: tile.midX - side/2, y: tile.midY - side/2,
                                          width: side, height: side))
        }
        // label
        let f = T.font(M.sidebarFont, 400)
        Draw.text(ctx, pane.title, x: M.labelX, lineTop: centerY - 8,
                  lineHeight: 16, font: f, color: dim ? labelOff : label)
        // "Soon" pill
        if dim {
            let pf = T.font(11, 500)
            let tw = Draw.lineWidth("Soon", font: pf)
            let pill = CGRect(x: M.selInsetX + M.selW - 12 - (tw + 16),
                              y: centerY - 9, width: tw + 16, height: 18)
            ctx.saveGState()
            ctx.addPath(Draw.pill(pill.insetBy(dx: 0.5, dy: 0.5)))
            ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.25).cgColor)
            ctx.setLineWidth(1); ctx.strokePath()
            ctx.restoreGState()
            Draw.text(ctx, "Soon", x: pill.midX - tw/2, lineTop: pill.midY - 7,
                      lineHeight: 14, font: pf, color: labelOff)
        }
    }

    // MARK: - detail

    /// Returns the full content height, so the caller can size a scroller.
    @discardableResult
    static func drawSoundPane(_ ctx: CGContext, scrollY: CGFloat, scale: CGFloat) -> CGFloat {
        let M = SettingsMetrics.self
        // header: tinted icon + title, pinned (not scrolled)
        let titleY = M.titleCenterY
        let tile = CGRect(x: M.groupX, y: titleY - 10, width: 20, height: 20)
        Draw.fillRounded(ctx, tile, 5, SettingsPane.sound.tile)
        if let g = symbol(SettingsPane.sound.symbol, size: 12, scale: scale) {
            let side = CGFloat(g.width) / scale
            Draw.image(ctx, g, in: CGRect(x: tile.midX - side/2, y: tile.midY - side/2,
                                          width: side, height: side))
        }
        Draw.text(ctx, "Sound", x: M.groupX + 30, lineTop: titleY - 11,
                  lineHeight: 22, font: T.font(17, 700), color: label)

        hits = []
        ctx.saveGState()
        ctx.clip(to: CGRect(x: M.detailX + 1, y: 44,
                            width: M.windowW - M.detailX - 1, height: M.windowH - 44))
        var y: CGFloat = 52 - scrollY
        for g in SoundPane.groups {
            if let h = g.header {
                Draw.text(ctx, h, x: M.groupX, lineTop: y + 2, lineHeight: 18,
                          font: T.font(M.sectionFont, 400), color: sectionCol)
                if h == "Tone Pad" {
                    // half-filled circle control at the group's right edge
                    let c = CGRect(x: M.groupX + M.groupW - 14, y: y + 3, width: 13, height: 13)
                    ctx.saveGState()
                    ctx.addPath(Draw.pill(c.insetBy(dx: 0.5, dy: 0.5)))
                    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.45).cgColor)
                    ctx.setLineWidth(1); ctx.strokePath()
                    ctx.restoreGState()
                    ctx.saveGState()
                    ctx.addPath(Draw.pill(c)); ctx.clip()
                    Draw.fillRect(ctx, CGRect(x: c.midX, y: c.minY, width: c.width/2, height: c.height),
                                  NSColor.white.withAlphaComponent(0.45))
                    ctx.restoreGState()
                }
                // measured chain, Profile card bottom -> track:
                //   card bottom +23.1 -> header centre +16.6 -> pad top
                //   pad bottom  +24.6 -> header centre +21.1 -> card top
                y += g.isPad ? 27.6 : 32.1
            }
            if g.isPad {
                let pad = CGRect(x: M.groupX, y: y, width: M.groupW, height: 201)
                Draw.fillRounded(ctx, pad, M.groupRadius, padFill)
                hits.append(Hit(label: "Tone Pad", rect: pad, kind: .pad))
                drawTonePad(ctx, pad, knob: Settings.shared.tonePad)
                y += pad.height + 13
                continue
            }
            func h(_ r: SoundPane.Row) -> CGFloat {
                if case .slider = r.control { return M.sliderRowH }
                if r.leadingSymbol != nil { return SleepPane.masterRowH }
                return M.rowH
            }
            let total = g.rows.reduce(CGFloat(0)) { $0 + h($1) }
            let card = CGRect(x: M.groupX, y: y, width: M.groupW, height: total)
            Draw.fillRounded(ctx, card, M.groupRadius, groupFill)
            var ry = y
            for (i, row) in g.rows.enumerated() {
                if i > 0 {
                    Draw.fillRect(ctx, CGRect(x: M.groupX + 12, y: ry,
                                              width: M.groupW - 24, height: 1), hairline)
                }
                let rr = CGRect(x: M.groupX, y: ry, width: M.groupW, height: h(row))
                var kind = Hit.Kind.toggle
                switch row.control {
                case .slider: kind = .slider
                case .popup:  kind = .popup
                case .tonePad: kind = .pad
                default: break
                }
                hits.append(Hit(label: row.label, rect: rr, kind: kind))
                drawRow(ctx, row, rect: rr, scale: scale)
                ry += h(row)
            }
            y += card.height + 13
        }
        ctx.restoreGState()
        return y + scrollY
    }

    private static func drawRow(_ ctx: CGContext, _ row: SoundPane.Row,
                                rect: CGRect, scale: CGFloat) {
        let f = T.font(SettingsMetrics.rowFont, 400)
        var labelTop = rect.midY - 8
        if case .slider = row.control { labelTop = rect.minY + 20.5 - 8 }
        var lx = rect.minX + 18
        if let sym = row.leadingSymbol {
            let tile = CGRect(x: lx, y: rect.midY - 9, width: 18, height: 18)
            Draw.fillRounded(ctx, tile, 4.5, row.leadingTint ?? .gray)
            if let g = symbol(sym, size: 11, scale: scale) {
                let side = CGFloat(g.width) / scale
                Draw.image(ctx, g, in: CGRect(x: tile.midX - side/2, y: tile.midY - side/2,
                                              width: side, height: side))
            }
            lx = tile.maxX + 10
        }
        let lw = Draw.text(ctx, row.label, x: lx, lineTop: labelTop,
                           lineHeight: 16, font: f, color: label)
        if row.trailingGlyph != nil, let g = symbol("person.wave.2", size: 11, scale: scale) {
            let side = CGFloat(g.width) / scale
            Draw.image(ctx, g, in: CGRect(x: lx + lw + 6, y: rect.midY - side/2,
                                          width: side, height: side))
        }
        // measured: toggle right edge 591.0 pt vs card right 602.3 pt
        let rightPad: CGFloat = 11.3
        switch row.control {
        case .toggle(let on):
            // the app's own switch, measured on the popover: 44x20, knob 26x16
            let t = CGRect(x: rect.maxX - rightPad - 44, y: rect.midY - 10, width: 44, height: 20)
            Draw.fillPill(ctx, t, on ? T.teal500 : toggleOff)
            let knob = CGRect(x: t.minX + 2 + (on ? 14 : 0), y: t.minY + 2, width: 26, height: 16)
            Draw.shadow(ctx, rect: knob, radius: 8, CSSShadow.xs, scale: scale)
            Draw.fillPill(ctx, knob, .white)
        case .slider(let v, let badge):
            // Both slider rows in the reference are two lines: label + a pill
            // showing the value, then a full-width track with a tick strip under
            // it. Measured off the Sound Effects group at t=50 s.
            if let badge {
                let bf = T.font(11, 500)
                let bw = Draw.lineWidth(badge, font: bf)
                let pill = CGRect(x: rect.maxX - rightPad - (bw + 18),
                                  y: rect.minY + 20.5 - 10, width: bw + 18, height: 20)
                ctx.saveGState()
                ctx.addPath(Draw.pill(pill.insetBy(dx: 0.5, dy: 0.5)))
                ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.22).cgColor)
                ctx.setLineWidth(1); ctx.strokePath()
                ctx.restoreGState()
                Draw.text(ctx, badge, x: pill.midX - bw/2, lineTop: pill.midY - 7,
                          lineHeight: 14, font: bf, color: label)
            }
            let inset: CGFloat = 12.6      // measured: track starts 253.9 pt
            let track = CGRect(x: rect.minX + inset, y: rect.minY + 48.5 - 2.5,
                               width: rect.width - inset*2, height: 5)
            Draw.fillPill(ctx, track, toggleOff)
            Draw.fillPill(ctx, CGRect(x: track.minX, y: track.minY,
                                      width: track.width * v, height: track.height), T.teal500)
            // tick strip
            let ticks = 10
            for i in 0..<ticks {
                let tx = track.minX + track.width * (CGFloat(i) + 0.5) / CGFloat(ticks)
                Draw.fill(ctx, Draw.pill(CGRect(x: tx - 1, y: rect.minY + 56.5, width: 2, height: 2)),
                          NSColor.white.withAlphaComponent(0.28))
            }
            let kx = track.minX + track.width * v
            let kb = CGRect(x: kx - 11, y: track.midY - 11, width: 22, height: 22)
            Draw.shadow(ctx, rect: kb, radius: 11, CSSShadow.sm, scale: scale)
            Draw.fillPill(ctx, kb, .white)
        case .popup(let text, let swatch):
            let pf = T.font(SettingsMetrics.rowFont, 400)
            let tw = Draw.lineWidth(text, font: pf)
            let chevW: CGFloat = 14
            let swW: CGFloat = swatch == nil ? 0 : 22
            let box = CGRect(x: rect.maxX - rightPad - (tw + chevW + swW + 20),
                             y: rect.midY - 13, width: tw + chevW + swW + 20, height: 26)
            Draw.fillRounded(ctx, box, 6, NSColor.white.withAlphaComponent(0.10))
            var tx = box.minX + 8
            if let sw = swatch {
                let s = CGRect(x: tx, y: box.midY - 8, width: 16, height: 16)
                Draw.fillRounded(ctx, s, 4, sw)
                if let g = symbol("plus", size: 9, scale: scale) {
                    let side = CGFloat(g.width) / scale
                    Draw.image(ctx, g, in: CGRect(x: s.midX - side/2, y: s.midY - side/2,
                                                  width: side, height: side))
                }
                tx += swW
            }
            Draw.text(ctx, text, x: tx, lineTop: box.midY - 8, lineHeight: 16, font: pf, color: label)
            if let g = symbol("chevron.up.chevron.down", size: 9, scale: scale) {
                let side = CGFloat(g.width) / scale
                Draw.image(ctx, g, in: CGRect(x: box.maxX - 8 - side/2 - 3,
                                              y: box.midY - side/2, width: side, height: side))
            }
        case .tonePad: break
        }
    }

    // MARK: - Sleep pane

    static func drawSleepPane(_ ctx: CGContext, scale: CGFloat) {
        let M = SettingsMetrics.self
        hits = []
        let tile = CGRect(x: M.groupX, y: M.titleCenterY - 10, width: 20, height: 20)
        Draw.fillRounded(ctx, tile, 5, SettingsPane.sleep.tile)
        if let g = symbol(SettingsPane.sleep.symbol, size: 12, scale: scale) {
            let side = CGFloat(g.width) / scale
            Draw.image(ctx, g, in: CGRect(x: tile.midX - side/2, y: tile.midY - side/2,
                                          width: side, height: side))
        }
        Draw.text(ctx, "Sleep", x: M.groupX + 30, lineTop: M.titleCenterY - 11,
                  lineHeight: 22, font: T.font(17, 700), color: label)

        // card 1: master toggle (icon-led, 47.8 pt) + Volume slider
        let c1 = CGRect(x: M.groupX, y: SleepPane.card1Top, width: M.groupW,
                        height: SleepPane.masterRowH + M.sliderRowH)
        Draw.fillRounded(ctx, c1, M.groupRadius, groupFill)
        drawRow(ctx, SoundPane.Row(label: "Sleep", control: .toggle(Settings.shared.sleepEnabled), trailingGlyph: nil,
                                   leadingSymbol: SettingsPane.sleep.symbol,
                                   leadingTint: SettingsPane.sleep.tile),
                rect: CGRect(x: c1.minX, y: c1.minY, width: c1.width,
                             height: SleepPane.masterContentH),   // content is top-aligned
                scale: scale)
        hits.append(Hit(label: "Sleep", rect: CGRect(x: c1.minX, y: c1.minY,
                                                     width: c1.width, height: SleepPane.masterRowH),
                        kind: .toggle))
        let vy = c1.minY + SleepPane.masterRowH
        Draw.fillRect(ctx, CGRect(x: M.groupX + 12, y: vy, width: M.groupW - 24, height: 1), hairline)
        drawRow(ctx, SoundPane.Row(label: "Volume",
                                   control: .slider(SleepPane.volumeKnobFraction,
                                                    badge: SleepPane.volumeLabel),
                                   trailingGlyph: nil),
                rect: CGRect(x: c1.minX, y: vy, width: c1.width, height: M.sliderRowH), scale: scale)
        hits.append(Hit(label: "Volume", rect: CGRect(x: c1.minX, y: vy,
                                                      width: c1.width, height: M.sliderRowH),
                        kind: .slider))

        // "Sleep Triggers" header + its trailing control
        let hy = SleepPane.triggersCardTop - 26
        Draw.text(ctx, "Sleep Triggers", x: M.groupX, lineTop: hy, lineHeight: 18,
                  font: T.font(M.sectionFont, 400), color: sectionCol)
        let ctl = CGRect(x: M.groupX + M.groupW - 14, y: hy + 1, width: 13, height: 13)
        ctx.saveGState()
        ctx.addPath(Draw.pill(ctl.insetBy(dx: 0.5, dy: 0.5)))
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.45).cgColor)
        ctx.setLineWidth(1); ctx.strokePath()
        ctx.restoreGState()

        // triggers
        let c2 = CGRect(x: M.groupX, y: SleepPane.triggersCardTop, width: M.groupW,
                        height: M.rowH * CGFloat(SleepPane.triggers.count))
        Draw.fillRounded(ctx, c2, M.groupRadius, groupFill)
        ctx.saveGState()
        ctx.clip(to: CGRect(x: 0, y: 0, width: M.windowW, height: M.windowH))
        for (i, t) in SleepPane.triggers.enumerated() {
            let ry = c2.minY + M.rowH * CGFloat(i)
            if i > 0 {
                Draw.fillRect(ctx, CGRect(x: M.groupX + 12, y: ry, width: M.groupW - 24, height: 1), hairline)
            }
            let cy = ry + M.rowH/2
            // checkbox
            let box = CGRect(x: SleepPane.checkX, y: cy - SleepPane.checkSize/2,
                             width: SleepPane.checkSize, height: SleepPane.checkSize)
            if SleepTriggers.shared.enabled.contains(t.label) {
                Draw.fillRounded(ctx, box, 3.5, T.teal500)
                if let g = symbol("checkmark", size: 9, scale: scale) {
                    let side = CGFloat(g.width) / scale
                    Draw.image(ctx, g, in: CGRect(x: box.midX - side/2, y: box.midY - side/2,
                                                  width: side, height: side))
                }
            } else {
                Draw.fillRounded(ctx, box, 3.5, NSColor.white.withAlphaComponent(0.14))
            }
            // app-style icon tile
            let it = CGRect(x: SleepPane.iconX, y: cy - SleepPane.iconSize/2,
                            width: SleepPane.iconSize, height: SleepPane.iconSize)
            Draw.fillRounded(ctx, it, 4.5, t.tint)
            if let g = symbol(t.symbol, size: 10.5, scale: scale) {
                let side = CGFloat(g.width) / scale
                Draw.image(ctx, g, in: CGRect(x: it.midX - side/2, y: it.midY - side/2,
                                              width: side, height: side))
            }
            Draw.text(ctx, t.label, x: SleepPane.labelX, lineTop: cy - 8, lineHeight: 16,
                      font: T.font(M.rowFont, 400), color: label)
            if let p = t.popup {
                let pf = T.font(M.rowFont, 400)
                let tw = Draw.lineWidth(p, font: pf)
                Draw.text(ctx, p, x: M.groupX + M.groupW - 11.3 - 16 - tw, lineTop: cy - 8,
                          lineHeight: 16, font: pf, color: labelDim)
                if let g = symbol("chevron.up.chevron.down", size: 9, scale: scale) {
                    let side = CGFloat(g.width) / scale
                    Draw.image(ctx, g, in: CGRect(x: M.groupX + M.groupW - 11.3 - side/2 - 5,
                                                  y: cy - side/2, width: side, height: side))
                }
            }
        }
        ctx.restoreGState()
    }

    // MARK: - Stats pane

    /// Reuses the Sound pane's measured chrome: 41.9 pt rows, 10 pt cards,
    /// 12 pt hairline inset, 13 pt labels, and the same value pill as the
    /// "100%" badge. Only the arrangement is inferred.
    static func drawStatsPane(_ ctx: CGContext, scale: CGFloat) {
        let M = SettingsMetrics.self
        let tile = CGRect(x: M.groupX, y: M.titleCenterY - 10, width: 20, height: 20)
        Draw.fillRounded(ctx, tile, 5, SettingsPane.stats.tile)
        if let g = symbol(SettingsPane.stats.symbol, size: 12, scale: scale) {
            let side = CGFloat(g.width) / scale
            Draw.image(ctx, g, in: CGRect(x: tile.midX - side/2, y: tile.midY - side/2,
                                          width: side, height: side))
        }
        Draw.text(ctx, "Stats", x: M.groupX + 30, lineTop: M.titleCenterY - 11,
                  lineHeight: 22, font: T.font(17, 700), color: label)

        var y: CGFloat = 60
        Draw.text(ctx, "Total Usage", x: M.groupX, lineTop: y, lineHeight: 18,
                  font: T.font(M.sectionFont, 400), color: sectionCol)
        y += 21
        Draw.text(ctx, UsageStore.shared.sinceText, x: M.groupX, lineTop: y, lineHeight: 16,
                  font: T.font(11, 400), color: labelOff)
        y += 24

        let u = UsageStore.shared
        let totals = [("Keystrokes", u.keystrokesText), ("Dings", u.dingsText), ("Clicks", u.clicksText)]
        let card1 = CGRect(x: M.groupX, y: y, width: M.groupW,
                           height: M.rowH * CGFloat(totals.count))
        Draw.fillRounded(ctx, card1, M.groupRadius, groupFill)
        for (i, m) in totals.enumerated() {
            let ry = y + M.rowH * CGFloat(i)
            if i > 0 {
                Draw.fillRect(ctx, CGRect(x: M.groupX + 12, y: ry, width: M.groupW - 24, height: 1), hairline)
            }
            Draw.text(ctx, m.0, x: M.groupX + 18, lineTop: ry + M.rowH/2 - 8,
                      lineHeight: 16, font: T.font(M.rowFont, 400), color: label)
            valuePill(ctx, m.1, rightOf: M.groupX + M.groupW, centerY: ry + M.rowH/2,
                      emphasised: false)
        }
        y += card1.height + 26

        Draw.text(ctx, "Favourite Switches", x: M.groupX, lineTop: y, lineHeight: 18,
                  font: T.font(M.sectionFont, 400), color: sectionCol)
        y += 32

        // ranked live, highest first, with the switch's own swatch
        let all = Catalog.groups.flatMap { $0.items }
        let favs = u.favourites.compactMap { f -> (String, NSColor, NSColor, String)? in
            guard let m = all.first(where: { $0.name == f.name }) else { return nil }
            return (f.name, m.top, m.bottom, u.countText(f.count))
        }
        if favs.isEmpty {
            Draw.text(ctx, "No keystrokes recorded yet.", x: M.groupX, lineTop: y + 4,
                      lineHeight: 18, font: T.font(M.rowFont, 400), color: labelOff)
            return
        }
        let card2 = CGRect(x: M.groupX, y: y, width: M.groupW,
                           height: M.rowH * CGFloat(favs.count))
        Draw.fillRounded(ctx, card2, M.groupRadius, groupFill)
        for (i, sw) in favs.enumerated() {
            let ry = y + M.rowH * CGFloat(i)
            if i > 0 {
                Draw.fillRect(ctx, CGRect(x: M.groupX + 12, y: ry, width: M.groupW - 24, height: 1), hairline)
            }
            // the app's own 18 pt keycap swatch, as measured on the switches panel
            let s = CGRect(x: M.groupX + 18, y: ry + M.rowH/2 - 9, width: 18, height: 18)
            drawSwatch(ctx, s, top: sw.1, bottom: sw.2)
            Draw.text(ctx, sw.0, x: s.maxX + 8, lineTop: ry + M.rowH/2 - 8,
                      lineHeight: 16, font: T.font(M.rowFont, 400), color: label)
            valuePill(ctx, sw.3, rightOf: M.groupX + M.groupW, centerY: ry + M.rowH/2,
                      emphasised: i == 0)
        }
    }

    /// Same pill as the Sound pane's "100%" badge.
    private static func valuePill(_ ctx: CGContext, _ text: String, rightOf: CGFloat,
                                  centerY: CGFloat, emphasised: Bool) {
        let f = T.font(11, 500)
        let w = Draw.lineWidth(text, font: f)
        let pill = CGRect(x: rightOf - 11.3 - (w + 18), y: centerY - 10, width: w + 18, height: 20)
        if emphasised {
            Draw.fillPill(ctx, pill, T.rose.withAlphaComponent(0.22))
        }
        ctx.saveGState()
        ctx.addPath(Draw.pill(pill.insetBy(dx: 0.5, dy: 0.5)))
        ctx.setStrokeColor((emphasised ? T.rose.withAlphaComponent(0.45)
                                       : NSColor.white.withAlphaComponent(0.22)).cgColor)
        ctx.setLineWidth(1); ctx.strokePath()
        ctx.restoreGState()
        Draw.text(ctx, text, x: pill.midX - w/2, lineTop: pill.midY - 7, lineHeight: 14,
                  font: f, color: emphasised ? T.srgb(255, 150, 165) : label)
    }

    /// The switches panel's keycap chip: gradient through the plus cut-out,
    /// then the two overlay borders.
    private static func drawSwatch(_ ctx: CGContext, _ r: CGRect, top: NSColor, bottom: NSColor) {
        ctx.saveGState()
        ctx.addPath(Draw.roundedPath(r, SwitchesMetrics.swatchRadius)); ctx.clip()
        ctx.saveGState()
        ctx.addPath(SVGPath.path(Art.swatch, viewBox: 26, size: r.width, origin: r.origin)); ctx.clip()
        let cs = CGColorSpaceCreateDeviceRGB()
        let g = CGGradient(colorsSpace: cs, colors: [top.cgColor, bottom.cgColor] as CFArray,
                           locations: [0, 1])!
        ctx.drawLinearGradient(g, start: CGPoint(x: r.midX, y: r.minY),
                               end: CGPoint(x: r.midX, y: r.maxY), options: [])
        ctx.restoreGState(); ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(Draw.roundedPath(r.insetBy(dx: 0.5, dy: 0.5), SwitchesMetrics.swatchRadius - 0.5))
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.15).cgColor)
        ctx.setLineWidth(1); ctx.strokePath()
        ctx.restoreGState()
        Draw.borderTop(ctx, rect: r, radius: SwitchesMetrics.swatchRadius, width: 1,
                       color: NSColor.white.withAlphaComponent(0.35))
    }

    /// The pad is a dot grid with a brighter cross through the knob column/row.
    private static func drawTonePad(_ ctx: CGContext, _ pad: CGRect, knob: CGPoint) {
        let cols = 16, rows = 9
        let inset: CGFloat = 22
        let inner = pad.insetBy(dx: inset, dy: inset)
        let dx = inner.width / CGFloat(cols - 1), dy = inner.height / CGFloat(rows - 1)
        let kc = Int((CGFloat(cols - 1) * knob.x).rounded())
        let kr = Int((CGFloat(rows - 1) * knob.y).rounded())
        for c in 0..<cols {
            for r in 0..<rows {
                let p = CGPoint(x: inner.minX + dx * CGFloat(c), y: inner.minY + dy * CGFloat(r))
                let lit = (c == kc || r == kr)
                let d: CGFloat = lit ? 3.0 : 2.4
                Draw.fill(ctx, Draw.pill(CGRect(x: p.x - d/2, y: p.y - d/2, width: d, height: d)),
                          lit ? padDotLit : padDot)
            }
        }
        let k = CGPoint(x: inner.minX + dx * CGFloat(kc), y: inner.minY + dy * CGFloat(kr))
        let kr2 = CGRect(x: k.x - 9, y: k.y - 9, width: 18, height: 18)
        Draw.shadow(ctx, rect: kr2, radius: 9, CSSShadow.sm, scale: 2)
        Draw.fillPill(ctx, kr2, .white)
    }
}
