import AppKit

/// The view that draws surface D. Same code path for the shipping window and
/// for `--settings-verify`, so what gets measured is what the app renders.
final class SettingsView: NSView {
    var selected: SettingsPane = .sound
    var scrollY: CGFloat = 0
    var scale: CGFloat = 2
    /// Painted only by the verify pass; on screen the window's own
    /// NSVisualEffectViews supply it.
    var opaqueBackdrop: NSColor? = nil

    override var isFlipped: Bool { true }

    override func draw(_ dirty: CGRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        if let bg = opaqueBackdrop {
            Draw.fillRect(ctx, bounds, bg)
            // the sidebar reads darker than the detail pane in the reference
            Draw.fillRect(ctx, CGRect(x: 0, y: 0, width: SettingsMetrics.sidebarW, height: bounds.height),
                          NSColor.black.withAlphaComponent(0.14))
        }
        SettingsRenderer.drawSidebar(ctx, height: bounds.height, selected: selected, scale: scale)
        switch selected {
        case .sound:
            SettingsRenderer.drawSoundPane(ctx, scrollY: scrollY, scale: scale)
        case .sleep:
            SettingsRenderer.drawSleepPane(ctx, scale: scale)
        case .stats:
            SettingsRenderer.drawStatsPane(ctx, scale: scale)
        default:
            // Every other pane exists in the reference's sidebar but its
            // contents are never shown. Saying so beats inventing them.
            let x = SettingsMetrics.groupX
            Draw.text(ctx, selected.title, x: x, lineTop: SettingsMetrics.titleCenterY - 11,
                      lineHeight: 22, font: T.font(17, 700), color: SettingsRenderer.label)
            Draw.text(ctx, "Not published in any reference.", x: x, lineTop: 70,
                      lineHeight: 18, font: T.font(13, 400), color: SettingsRenderer.labelDim)
            Draw.text(ctx, "The sidebar proves this pane exists; the review video", x: x, lineTop: 92,
                      lineHeight: 18, font: T.font(13, 400), color: SettingsRenderer.labelOff)
            Draw.text(ctx, "only ever opens Sound.", x: x, lineTop: 112,
                      lineHeight: 18, font: T.font(13, 400), color: SettingsRenderer.labelOff)
        }
    }

    // MARK: interaction
    private func hitSidebar(_ p: CGPoint) -> SettingsPane? {
        guard p.x < SettingsMetrics.sidebarW else { return nil }
        var y = SettingsMetrics.firstItemCenterY
        var first = true
        for (header, panes) in SettingsPane.sections {
            if header != nil {
                if !first { y += SettingsMetrics.itemToHeader }
                y += SettingsMetrics.headerToFirst
            }
            for pane in panes {
                if abs(p.y - y) <= SettingsMetrics.itemH/2 { return pane }
                y += SettingsMetrics.itemH; first = false
            }
            y -= SettingsMetrics.itemH
        }
        return nil
    }

    /// Which Sleep trigger row, if any, is under this point.
    private func hitTrigger(_ p: CGPoint) -> String? {
        guard selected == .sleep, p.x > SettingsMetrics.sidebarW else { return nil }
        let top = SleepPane.triggersCardTop
        let i = Int((p.y - top) / SettingsMetrics.rowH)
        guard p.y >= top, i >= 0, i < SleepPane.triggers.count else { return nil }
        return SleepPane.triggers[i].label
    }

    /// Slider / tone-pad drags keep the row they started on.
    private var dragging: SettingsRenderer.Hit?

    private func applySound(_ h: SettingsRenderer.Hit, _ p: CGPoint) {
        let S = Settings.shared
        switch h.kind {
        case .toggle:
            switch h.label {
            case "Sound":                       S.enabled.toggle()
            case "Stereo panning":              S.stereoPanning.toggle()
            case "Spatial audio":               S.spatialAudio.toggle()
            case "Pitch variation":             S.pitchVariation.toggle()
            case "Ignore rapid key events":     S.ignoreRapidKeyEvents.toggle()
            case "Disable audible modifier keys": S.disableAudibleModifiers.toggle()
            case "Sleep":                       S.sleepEnabled.toggle()
            default: break
            }
        case .slider:
            // the track spans the card inset by 12.6 pt on each side
            let x0 = h.rect.minX + 12.6, w = h.rect.width - 25.2
            let v = Double(max(0, min(1, (p.x - x0) / w)))
            if h.label == "Volume" { selected == .sleep ? (S.sleepVolume = v) : (S.volume = v) }
            if h.label == "Effects volume" { S.effectsVolume = v }
        case .popup:
            if h.label == "Play sound through" {
                var opts = [AudioDevices.systemDefaultLabel] + AudioDevices.outputs().map { $0.name }
                opts = opts.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
                let i = opts.firstIndex(of: S.playSoundThrough) ?? 0
                S.playSoundThrough = opts[(i + 1) % opts.count]
            }
            if h.label == "Switch sound" {
                let n = Catalog.groups.flatMap { $0.items }.count
                S.switchIndex = (S.switchIndex + 1) % n         // cycle; no menu in the reference
                KeyMonitor.shared.trigger(keyCode: 0, down: true)
            }
        case .pad:
            let inset: CGFloat = 22
            let inner = h.rect.insetBy(dx: inset, dy: inset)
            S.tonePad = CGPoint(x: Double(max(0, min(1, (p.x - inner.minX) / inner.width))),
                                y: Double(max(0, min(1, (p.y - inner.minY) / inner.height))))
        }
        needsDisplay = true
    }

    override func mouseDragged(with e: NSEvent) {
        guard let h = dragging else { return }
        applySound(h, convert(e.locationInWindow, from: nil))
    }
    override func mouseUp(with e: NSEvent) { dragging = nil }

    override func mouseDown(with e: NSEvent) {
        let p = convert(e.locationInWindow, from: nil)
        if selected == .sound || selected == .sleep {
            if let h = SettingsRenderer.hits.first(where: { $0.rect.contains(p) }) {
                if h.kind == .slider || h.kind == .pad { dragging = h }
                applySound(h, p)
                return
            }
        }
        if let label = hitTrigger(p) {
            var s = SleepTriggers.shared.enabled
            if s.contains(label) { s.remove(label) } else { s.insert(label) }
            SleepTriggers.shared.enabled = s
            Settings.shared.sleepTriggers = s
            SleepTriggers.shared.poll()
            needsDisplay = true
            return
        }
        if let pane = hitSidebar(p), !pane.isComingSoon {
            selected = pane; scrollY = 0; needsDisplay = true
            window?.title = pane.title
        }
    }

    override func scrollWheel(with e: NSEvent) {
        guard selected == .sound else { return }
        scrollY = max(0, min(320, scrollY - e.scrollingDeltaY))
        needsDisplay = true
    }
}

final class SettingsWindowController: NSWindowController {
    let view = SettingsView(frame: CGRect(x: 0, y: 0,
                                          width: SettingsMetrics.windowW,
                                          height: SettingsMetrics.windowH))
    convenience init() {
        let w = NSWindow(contentRect: CGRect(x: 0, y: 0,
                                             width: SettingsMetrics.windowW,
                                             height: SettingsMetrics.windowH),
                         styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                         backing: .buffered, defer: false)
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.isMovableByWindowBackground = true
        w.appearance = NSAppearance(named: .darkAqua)   // the reference frame is dark
        w.center()
        self.init(window: w)

        // sidebar and detail materials, the native way to get this window's look
        let container = NSView(frame: view.bounds)
        let side = NSVisualEffectView(frame: CGRect(x: 0, y: 0,
                                                    width: SettingsMetrics.sidebarW,
                                                    height: view.bounds.height))
        side.material = .sidebar; side.blendingMode = .behindWindow; side.state = .active
        side.autoresizingMask = [.height]
        let body = NSVisualEffectView(frame: CGRect(x: SettingsMetrics.sidebarW, y: 0,
                                                    width: view.bounds.width - SettingsMetrics.sidebarW,
                                                    height: view.bounds.height))
        body.material = .underWindowBackground; body.blendingMode = .behindWindow; body.state = .active
        body.autoresizingMask = [.width, .height]
        container.addSubview(side); container.addSubview(body); container.addSubview(view)
        w.contentView = container
    }

    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

/// Offscreen render of surface D at an arbitrary scale, so the reference frame's
/// own scale (1.946 px/pt) can be reproduced and measured with the same script.
func renderSettings(out: String, scale: CGFloat, pane: SettingsPane, scrollY: CGFloat) {
    let W = SettingsMetrics.windowW, H = SettingsMetrics.windowH
    guard let ctx = CGContext(data: nil, width: Int((W*scale).rounded()), height: Int((H*scale).rounded()),
                              bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpace(name: CGColorSpace.sRGB)!,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
    ctx.translateBy(x: 0, y: CGFloat(ctx.height)); ctx.scaleBy(x: scale, y: -scale)
    ctx.setShouldSmoothFonts(scale >= 2)
    let v = SettingsView(frame: CGRect(x: 0, y: 0, width: W, height: H))
    v.selected = pane; v.scrollY = scrollY; v.scale = scale
    // The reference sits over an unknown desktop, so an exact colour match is
    // not on offer. A flat ground keeps the geometry measurable.
    v.opaqueBackdrop = T.srgb(70, 74, 104)
    let g = NSGraphicsContext(cgContext: ctx, flipped: true)
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = g
    v.draw(v.bounds)
    NSGraphicsContext.restoreGraphicsState()
    guard let img = ctx.makeImage() else { return }
    if let d = NSBitmapImageRep(cgImage: img).representation(using: .png, properties: [:]) {
        try? d.write(to: URL(fileURLWithPath: out))
    }
    print("settings render -> \(out)  (\(Int(W))x\(Int(H))pt at \(scale) px/pt)")
}
