import AppKit
import ScreenCaptureKit

// MARK: - shared panel host

/// Hosts one rendered surface. Owns hover tracking and the transition clock, so
/// the states in the ledger are real behaviour rather than static styling.
final class PanelHostView: NSView {
    enum Surface { case popover, switches }
    let surface: Surface
    var pop = PopoverState()
    var sw = SwitchesState()
    var backdrop: CGImage?
    var backdropOriginCSS: CGPoint = .zero
    var onCommand: ((Int) -> Void)?

    private var timer: Timer?
    private var last = Date()

    init(surface: Surface, size: CGSize) {
        self.surface = surface
        super.init(frame: CGRect(origin: .zero, size: size))
        let area = NSTrackingArea(rect: .zero,
                                  options: [.mouseEnteredAndExited, .mouseMoved,
                                            .activeAlways, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
    }
    required init?(coder: NSCoder) { fatalError() }
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    /// Sub-point remainder of the window's placement. AppKit rounds a window's
    /// frame origin to whole points, so a panel asked for a half-point position
    /// silently lands a device pixel off. Carrying the remainder here lets the
    /// content sit on the intended device pixel wherever the window ends up.
    var subPixelOffset: CGPoint = .zero {
        didSet { needsDisplay = true }
    }

    private var origin: CGPoint {
        CGPoint(x: shadowInset.left + subPixelOffset.x,
                y: shadowInset.top  + subPixelOffset.y)
    }
    /// Room for the drawn box-shadow (0 25px 50px -12px).
    let shadowInset = NSEdgeInsets(top: 20, left: 40, bottom: 60, right: 40)

    private func local(_ e: NSEvent) -> CGPoint {
        let p = convert(e.locationInWindow, from: nil)
        return CGPoint(x: p.x - origin.x, y: p.y - origin.y)
    }

    override func mouseMoved(with e: NSEvent)  { updateHover(local(e)) }
    override func mouseEntered(with e: NSEvent){ updateHover(local(e)) }
    override func mouseExited(with e: NSEvent) { updateHover(nil) }

    private func updateHover(_ p: CGPoint?) {
        switch surface {
        case .popover:  pop.setHover(p.flatMap { PopoverRenderer.hitRow($0) })
        case .switches: sw.setHover(p.flatMap { SwitchesRenderer.hitRow($0) })
        }
        startClock(); needsDisplay = true
    }

    override func mouseDown(with e: NSEvent) {
        let p = local(e)
        switch surface {
        case .popover:
            if PopoverRenderer.toggleRect.insetBy(dx: -6, dy: -6).contains(p) {
                pop.enabled.toggle()
                pop.knob.set(pop.enabled ? 1 : 0)
                pop.track.set(pop.enabled ? 1 : 0)
                SoundEngine.shared.enabled = pop.enabled
            } else if PopoverRenderer.rowRect(2).insetBy(dx: 0, dy: -8).contains(p) {
                pop.thumbPressed = true; pop.thumbDragging = false
                pressStartX = p.x
                pop.thumbScale.set(1.10)          // scale-110, measured
                let v = max(0, min(1, (p.x - PopoverRenderer.rowX) / PopoverRenderer.rowW))
                pop.volume = v; pop.fill.set(v)
                SoundEngine.shared.volume = Float(v)
            } else if let r = PopoverRenderer.hitRow(p) {
                onCommand?(r)
            }
        case .switches:
            if let i = SwitchesRenderer.hitRow(p) {
                sw.playing = i
                SoundEngine.shared.switchIndex = i
                KeyMonitor.shared.trigger(keyCode: 0, down: true)   // preview it
                onCommand?(i)
            }
        }
        startClock(); needsDisplay = true
    }

    private var pressStartX: CGFloat = 0

    override func mouseDragged(with e: NSEvent) {
        guard surface == .popover, pop.thumbPressed else { return }
        let p = local(e)
        // >3px of travel promotes press to drag, and the reference drops the
        // `left` transition for the rest of the gesture so it tracks the pointer
        if abs(p.x - pressStartX) > 3 { pop.thumbDragging = true }
        let v = max(0, min(1, (p.x - PopoverRenderer.rowX) / PopoverRenderer.rowW))
        pop.volume = v
        SoundEngine.shared.volume = Float(v)
        if pop.thumbDragging { pop.fill.snapTo(v) } else { pop.fill.set(v) }
        startClock(); needsDisplay = true
    }

    override func mouseUp(with e: NSEvent) {
        guard surface == .popover, pop.thumbPressed else { return }
        pop.thumbPressed = false; pop.thumbDragging = false
        pop.thumbScale.set(1.0)
        startClock(); needsDisplay = true
    }

    private func startClock() {
        guard timer == nil else { return }
        last = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/120, repeats: true) { [weak self] t in
            guard let self else { t.invalidate(); return }
            let now = Date(); let dt = CGFloat(now.timeIntervalSince(last)); last = now
            let live = (surface == .popover) ? pop.tick(dt) : sw.tick(dt)
            needsDisplay = true
            if !live { t.invalidate(); timer = nil }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    override func draw(_ dirty: CGRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        switch surface {
        case .popover:
            PopoverRenderer.draw(ctx, origin: origin, state: pop, backdrop: backdrop,
                                 backdropOriginCSS: backdropOriginCSS, scale: 2)
        case .switches:
            SwitchesRenderer.draw(ctx, origin: origin, state: sw, backdrop: backdrop,
                                  backdropOriginCSS: backdropOriginCSS, scale: 2)
        }
    }
}

// MARK: - floating panel

final class SurfacePanel: NSPanel {
    static var materialOverride: NSVisualEffectView.Material? = nil
    static var appearanceOverride: NSAppearance.Name? = nil
    static var emphasizedOverride = false
    /// Use the calibrated Gaussian when screen access is *already* granted, and
    /// the AppKit material otherwise. `CGPreflightScreenCaptureAccess` answers
    /// without prompting, so a keyboard-sound app never asks for screen
    /// recording just to match a blur radius.
    static var liveBackdropEnabled: Bool = CGPreflightScreenCaptureAccess()

    static let materials: [(String, NSVisualEffectView.Material)] = [
        ("titlebar", .titlebar), ("selection", .selection), ("menu", .menu),
        ("popover", .popover), ("sidebar", .sidebar), ("headerView", .headerView),
        ("sheet", .sheet), ("windowBackground", .windowBackground),
        ("hudWindow", .hudWindow), ("fullScreenUI", .fullScreenUI),
        ("toolTip", .toolTip), ("contentBackground", .contentBackground),
        ("underWindowBackground", .underWindowBackground),
        ("underPageBackground", .underPageBackground),
    ]

    let host: PanelHostView
    init(surface: PanelHostView.Surface, size: CGSize) {
        let ins = NSEdgeInsets(top: 20, left: 40, bottom: 60, right: 40)
        // Round the window up to whole points. The popover content is 370.5pt
        // tall, so an un-rounded window is 450.5pt and AppKit rounds its origin
        // instead — putting the whole panel half a point (1 device px) off, which
        // measured as 2.75% differing against the verified render. With an
        // integer height the top edge stays on the grid and it drops to 0.05%.
        // The slack goes below the content, so the content's offset is unchanged.
        let full = CGSize(width: (size.width + ins.left + ins.right).rounded(.up),
                          height: (size.height + ins.top + ins.bottom).rounded(.up))
        host = PanelHostView(surface: surface, size: full)
        super.init(contentRect: CGRect(origin: .zero, size: full),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        colorSpace = NSColorSpace.sRGB     // the reference is sRGB; P3 shifts saturated colours
        level = .statusBar
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false                      // the shadow is drawn, per the ledger
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // real vibrancy behind the translucent fill, masked to the panel shape
        let radius: CGFloat = 24
        let ve = NSVisualEffectView(frame: CGRect(x: ins.left, y: ins.bottom,
                                                  width: size.width, height: size.height))
        // Which material best approximates `backdrop-filter: blur(24px)` is a
        // measurement, not a guess -- see SurfacePanel.materialOverride and
        // tools/material-sweep.sh.
        // Measured best of 14 materials x 2 appearances (tools/material-sweep.sh):
        // hudWindow, light for the popover and dark for the switches panel.
        ve.material = SurfacePanel.materialOverride ?? .hudWindow
        ve.appearance = NSAppearance(named: surface == .popover ? .aqua : .darkAqua)
        if let a = SurfacePanel.appearanceOverride { ve.appearance = NSAppearance(named: a) }
        ve.isEmphasized = SurfacePanel.emphasizedOverride
        ve.blendingMode = .behindWindow
        ve.state = .active
        ve.wantsLayer = true
        ve.layer?.cornerRadius = radius
        ve.layer?.cornerCurve = .circular
        ve.layer?.masksToBounds = true
        let container = NSView(frame: CGRect(origin: .zero, size: full))
        container.addSubview(ve)
        container.addSubview(host)
        contentView = container
        effectView = ve
    }
    /// True once a live backdrop capture has succeeded, so the panel is
    /// blurring with the measured sigma instead of AppKit's material.
    private(set) var usingLiveBackdrop = false
    weak var effectView: NSVisualEffectView?

    /// Grab what is on screen *below* this window and hand it to the renderer,
    /// which blurs it with the calibrated Gaussian. This is the same code path
    /// the offscreen harness verifies; NSVisualEffectView is only the fallback.
    /// Measured: no AppKit material gets below 46% differing, because every
    /// material re-tints and de-saturates the backdrop.
    ///
    /// Asynchronous on purpose. Blocking the main thread on the capture traps:
    /// ScreenCaptureKit hops to the main actor internally, so a semaphore wait
    /// there is a deadlock, and the shared result box is an exclusivity
    /// violation besides.
    func refreshBackdrop(_ done: (@Sendable @MainActor (Bool) -> Void)? = nil) {
        guard SurfacePanel.liveBackdropEnabled, let scr = screen ?? NSScreen.main else {
            done?(false); return
        }
        let ins = host.shadowInset, f = frame
        let content = CGRect(x: f.minX + ins.left, y: f.minY + ins.bottom,
                             width: f.width - ins.left - ins.right,
                             height: f.height - ins.top - ins.bottom)
        // ScreenCaptureKit works in display space: top-left origin, y downwards
        let display = CGRect(x: content.minX, y: scr.frame.maxY - content.maxY,
                             width: content.width, height: content.height)
        // Exclude only the panels, never every window this app owns: the stage's
        // backdrop window belongs to the app too, and excluding it made the
        // capture return the user's real desktop instead of the backdrop.
        // NSWindow.windowNumber is negative for deferred windows and CGWindowID
        // is UInt32, so an unchecked conversion traps.
        let mine = NSApp.windows.compactMap { w -> CGWindowID? in
            guard w is SurfacePanel else { return nil }
            return CGWindowID(exactly: w.windowNumber)
        }
        Task { @MainActor in
            let img = await SurfacePanel.captureBelow(display, excluding: mine)
            guard let img, img.width > 1, img.height > 1, !self.isUniform(img) else {
                self.usingLiveBackdrop = false
                self.effectView?.isHidden = false
                done?(false); return
            }
            FileHandle.standardError.write(
                "capture colorSpace=\(img.colorSpace?.name as String? ?? "nil") bpc=\(img.bitsPerComponent) \(img.width)x\(img.height)\n".data(using: .utf8)!)
            let conv = SurfacePanel.toSRGB(img) ?? img
            if CommandLine.arguments.contains("--dump-backdrop"),
               let d = NSBitmapImageRep(cgImage: conv).representation(using: .png, properties: [:]) {
                let tag = self.host.surface == .popover ? "pop" : "sw"
                try? d.write(to: Paths.shots("sck-\(tag).png"))
            }
            self.host.backdrop = conv
            self.host.backdropOriginCSS = CGPoint(x: ins.left, y: ins.top)
            self.usingLiveBackdrop = true
            self.effectView?.isHidden = true       // the drawn blur replaces it
            self.host.needsDisplay = true
            done?(true)
        }
    }

    /// ScreenCaptureKit replaced CGWindowListCreateImage, which the macOS 26 SDK
    /// removes. Needs Screen Recording permission, so this is opt-in
    /// (`--live-backdrop`) rather than the default: a keyboard-sound app should
    /// not demand screen capture just to match a blur radius.
    static func captureBelow(_ rect: CGRect, excluding mine: [CGWindowID]) async -> CGImage? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: true)
            guard let display = content.displays.first else { return nil }
            let set = Set(mine)
            let excluded = content.windows.filter { set.contains($0.windowID) }
            let filter = SCContentFilter(display: display, excludingWindows: excluded)
            let cfg = SCStreamConfiguration()
            cfg.sourceRect = rect
            cfg.width  = Int(rect.width  * 2)
            cfg.height = Int(rect.height * 2)
            cfg.captureResolution = .best
            cfg.showsCursor = false
            // Ask for sRGB directly. Without this the image comes back with a
            // nil colour space and CGContext cannot convert it, so the backdrop
            // ends up double-encoded (measured: ~20 levels too dark).
            cfg.colorSpaceName = CGColorSpace.sRGB
            cfg.pixelFormat = kCVPixelFormatType_32BGRA
            return try await SCScreenshotManager.captureImage(
                contentFilter: filter, configuration: cfg)
        } catch {
            FileHandle.standardError.write(
                "live backdrop unavailable: \(error.localizedDescription)\n".data(using: .utf8)!)
            return nil
        }
    }

    /// ScreenCaptureKit hands back the display's colour space (Display P3 here).
    /// The blur runs in sRGB and the reference is sRGB, so convert first —
    /// otherwise every pixel carries a systematic warm shift.
    static func toSRGB(_ img: CGImage) -> CGImage? {
        guard let cs = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: img.width, height: img.height,
                                  bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: img.width, height: img.height))
        return ctx.makeImage()
    }

    /// A screen capture without permission comes back a uniform black frame.
    private func isUniform(_ img: CGImage) -> Bool {
        guard let d = img.dataProvider?.data, let p = CFDataGetBytePtr(d) else { return true }
        let n = CFDataGetLength(d)
        guard n > 64 else { return true }
        let first = p[0]
        var i = 0
        while i < min(n, 4096) { if p[i] != first { return false }; i += 7 }
        return true
    }

    override var canBecomeKey: Bool { true }

    /// Commands the panel understands. Shortcuts are the ones visible in the
    /// v1.2.1 menu capture (⌥⌘K disable, ⌘, settings, ⌘Q quit); Esc-to-dismiss
    /// is inferred from the platform, not from the reference.
    enum Command: String { case toggleEnabled, settings, quit, dismiss }

    static func command(for e: NSEvent) -> Command? {
        let m = e.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let k = (e.charactersIgnoringModifiers ?? "").lowercased()
        if m == [.command, .option], k == "k" { return .toggleEnabled }
        if m == [.command], k == "," { return .settings }
        if m == [.command], k == "q" { return .quit }
        if m.isEmpty, e.keyCode == 53 { return .dismiss }
        return nil
    }

    var onKeyCommand: ((Command) -> Void)?

    override func keyDown(with e: NSEvent) {
        if let c = SurfacePanel.command(for: e) { onKeyCommand?(c) } else { super.keyDown(with: e) }
    }
}

// MARK: - verify mode

func runVerify(outDir: String, scale: CGFloat, states: [String]) {
    let fm = FileManager.default
    try? fm.createDirectory(atPath: outDir, withIntermediateDirectories: true)
    let backdrop = Stage.backdropImage(scale: scale)

    /// Offscreen render at an arbitrary scale, through the same draw code.
    /// Used for the 1x pass: a Retina Mac cannot give a window a 1x backing store,
    /// but a non-Retina display would render exactly this.
    func renderOffscreen(_ pop: PopoverState, _ sw: SwitchesState, tag: String, s: CGFloat) {
        let w = Int(Stage.pageSize.width * s), h = Int(Stage.pageSize.height * s)
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        ctx.translateBy(x: 0, y: CGFloat(h)); ctx.scaleBy(x: s, y: -s)
        ctx.setAllowsAntialiasing(true); ctx.setShouldAntialias(true)
        // Measured, and it is scale-dependent: at 2x, smoothing ON halves the
        // glyph residual (36.0%/37.5% vs 47.4%/52.0% of ink pixels, both
        // polarities). At 1x it is the other way round -- ON costs 1.55%->1.97%
        // (popover) and 2.94%->3.96% (switches). Skia's own hinting/smoothing
        // evidently changes with device scale, so this follows the measurement
        // rather than one global rule.
        ctx.setShouldSmoothFonts(false)
        let bd = Stage.backdropImage(scale: s)
        Stage.drawAll(ctx, pop: pop, sw: sw, backdrop: bd, scale: s)
        guard let full = ctx.makeImage() else { return }
        for (name, r) in Stage.crops {
            let px = CGRect(x: r.minX.rounded() * s, y: r.minY.rounded() * s,
                            width: r.width.rounded() * s, height: r.height.rounded() * s)
            guard let sub = full.cropping(to: px) else { continue }
            let out = NSBitmapImageRep(cgImage: sub)
            if let d = out.representation(using: .png, properties: [:]) {
                try? d.write(to: URL(fileURLWithPath: outDir)
                    .appendingPathComponent("clone-\(name)-\(tag).png"))
            }
        }
    }

    func render(_ pop: PopoverState, _ sw: SwitchesState, tag: String) {
        // Render through a real on-screen NSView so the AppKit drawing path,
        // colour space and backing scale are the ones the app actually uses.
        let view = StageView(frame: CGRect(origin: .zero, size: Stage.pageSize))
        view.pop = pop; view.sw = sw; view.backdrop = backdrop
        let win = NSWindow(contentRect: CGRect(origin: CGPoint(x: -20000, y: -20000),
                                               size: Stage.pageSize),
                           styleMask: [.borderless], backing: .buffered, defer: false)
        win.colorSpace = NSColorSpace.sRGB      // the reference is sRGB; P3 shifts saturated colours
        win.contentView = view
        win.orderBack(nil)
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        rep.size = NSSize(width: Stage.pageSize.width, height: Stage.pageSize.height)
        view.cacheDisplay(in: view.bounds, to: rep)
        guard let full = rep.cgImage else { return }
        let sx = CGFloat(full.width) / Stage.pageSize.width
        for (name, r) in Stage.crops {
            // mirror the reference capture: round the clip in CSS px, then scale
            let px = CGRect(x: r.minX.rounded() * sx, y: r.minY.rounded() * sx,
                            width: r.width.rounded() * sx, height: r.height.rounded() * sx)
            guard let sub = full.cropping(to: px) else { continue }
            let out = (NSBitmapImageRep(cgImage: sub)
                        .converting(to: .sRGB, renderingIntent: .default)) ?? NSBitmapImageRep(cgImage: sub)
            let file = tag.isEmpty ? "clone-\(name).png" : "clone-\(name)-\(tag).png"
            if let d = out.representation(using: .png, properties: [:]) {
                try? d.write(to: URL(fileURLWithPath: outDir).appendingPathComponent(file))
            }
        }
        win.orderOut(nil)
    }

    let pop = PopoverState(), sw = SwitchesState()
    if states.contains("backdrop") {
        // backdrop only: isolates wallpaper decode/scale from the blur
        let view = StageView(frame: CGRect(origin: .zero, size: Stage.pageSize))
        view.backdropOnly = true
        let win = NSWindow(contentRect: CGRect(origin: CGPoint(x: -20000, y: -20000), size: Stage.pageSize),
                           styleMask: [.borderless], backing: .buffered, defer: false)
        win.colorSpace = NSColorSpace.sRGB
        win.contentView = view; win.orderBack(nil)
        if let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
            view.cacheDisplay(in: view.bounds, to: rep)
            if let full = rep.cgImage {
                let sx = CGFloat(full.width) / Stage.pageSize.width
                for (name, r) in Stage.crops where name == "hero" {
                    let px = CGRect(x: r.minX.rounded()*sx, y: r.minY.rounded()*sx,
                                    width: r.width.rounded()*sx, height: r.height.rounded()*sx)
                    if let sub = full.cropping(to: px),
                       let d = ((NSBitmapImageRep(cgImage: sub).converting(to: .sRGB, renderingIntent: .default))
                                 ?? NSBitmapImageRep(cgImage: sub)).representation(using: .png, properties: [:]) {
                        try? d.write(to: URL(fileURLWithPath: outDir).appendingPathComponent("clone-backdrop-\(name).png"))
                    }
                }
            }
        }
        win.orderOut(nil)
    }
    render(pop, sw, tag: "")
    if states.contains("floor") { render(pop, sw, tag: "floor") }
    if states.contains("hover") {
        var p1 = PopoverState(); p1.setHover(6); _ = p1.tick(1)
        render(p1, SwitchesState(), tag: "hover-settings")
        var p2 = PopoverState(); p2.setHover(7); _ = p2.tick(1)
        render(p2, SwitchesState(), tag: "hover-quit")
        var s1 = SwitchesState(); s1.setHover(0); _ = s1.tick(1)
        render(PopoverState(), s1, tag: "hover-row")
    }
    if states.contains("focus") {
        var p = PopoverState(); p.toggleFocused = true
        render(p, SwitchesState(), tag: "focus-toggle")
    }
    if states.contains("off") {
        var p = PopoverState(); p.enabled = false
        p.knob.set(0); p.track.set(0); _ = p.tick(1)
        render(p, SwitchesState(), tag: "toggle-off")
    }
    if states.contains("rest2") { render(PopoverState(), SwitchesState(), tag: "rest2") }
    if states.contains("hover") {
        var p = PopoverState(); p.thumbPressed = true; p.thumbScale.set(1.10); _ = p.tick(1)
        render(p, SwitchesState(), tag: "thumb-press")
        var p2 = PopoverState(); p2.volume = 0.40; p2.fill.set(0.40); _ = p2.tick(1)
        render(p2, SwitchesState(), tag: "vol40")
        var s2 = SwitchesState(); s2.setHover(0); s2.playing = 0; _ = s2.tick(1)
        render(PopoverState(), s2, tag: "playing")
    }
    if states.contains("scale1") {
        renderOffscreen(PopoverState(), SwitchesState(), tag: "s1", s: 1)
        Draw.suppressText = true
        renderOffscreen(PopoverState(), SwitchesState(), tag: "s1-notext", s: 1)
        Draw.suppressText = false
    }
    if states.contains("notext") {
        Draw.suppressText = true
        render(PopoverState(), SwitchesState(), tag: "notext")
        Draw.suppressText = false
    }
    print("verify: wrote crops to \(outDir)")
}

// MARK: - glyph rasteriser floor

/// Renders the same strings, font, size, weight, colour and line box as
/// tools/glyphfloor.mjs does in Chrome. Diffing the two isolates the
/// CoreText-vs-Skia rasterisation floor from any layout error of mine.
func runGlyphFloor(out: String) {
    struct R { let t: String; let x: CGFloat; let y: CGFloat; let fs: CGFloat
               let lh: CGFloat; let w: Int; let c: NSColor; let dark: Bool }
    let s5 = T.stone500.withAlphaComponent(0.75)
    let o4 = T.orange50.withAlphaComponent(0.40)
    let runs = [
        R(t:"Klack",             x:24,  y:20,  fs:15, lh:22.5, w:700, c:T.stone800, dark:false),
        R(t:"Klack Settings...", x:24,  y:60,  fs:15, lh:22.5, w:500, c:T.stone800, dark:false),
        R(t:"Quit Klack",        x:24,  y:100, fs:15, lh:22.5, w:500, c:T.stone800, dark:false),
        R(t:"Sound",             x:24,  y:140, fs:14, lh:20,   w:600, c:s5, dark:false),
        R(t:"Switches",          x:24,  y:180, fs:14, lh:20,   w:600, c:s5, dark:false),
        R(t:"Version 2.2",       x:24,  y:220, fs:14, lh:20,   w:600, c:s5, dark:false),
        R(t:"Japanese Black",    x:324, y:20,  fs:15, lh:22.5, w:500, c:T.orange50, dark:true),
        R(t:"Crystal Purple",    x:324, y:60,  fs:15, lh:22.5, w:500, c:T.orange50, dark:true),
        R(t:"CherryMX\u{2122}", x:324, y:100, fs:14, lh:20,   w:600, c:o4, dark:true),
        R(t:"NovelKeys\u{2122}",x:324, y:140, fs:14, lh:20,   w:600, c:o4, dark:true),
        R(t:"New",               x:324, y:180, fs:12, lh:16,   w:600, c:T.rose.withAlphaComponent(0.9), dark:true),
    ]
    final class V: NSView {
        var runs: [R] = []
        var smooth = true, subpixelPos = true, subpixelQuant = true
        override var isFlipped: Bool { true }
        override func draw(_ d: CGRect) {
            guard let ctx = NSGraphicsContext.current?.cgContext else { return }
            ctx.setShouldSmoothFonts(smooth)
            ctx.setShouldSubpixelPositionFonts(subpixelPos)
            ctx.setShouldSubpixelQuantizeFonts(subpixelQuant)
            Draw.fillRect(ctx, CGRect(x: 0, y: 0, width: 600, height: 260), T.orange50)
            Draw.fillRect(ctx, CGRect(x: 300, y: 0, width: 300, height: 260), T.stone800)
            for r in runs {
                Draw.text(ctx, r.t, x: r.x, lineTop: r.y, lineHeight: r.lh,
                          font: T.font(r.fs, r.w), color: r.c)
            }
        }
    }
    // sweep the CoreGraphics text-rendering switches; the reference is Skia,
    // so which combination it corresponds to is a measurement, not a guess
    for sm in [true, false] {
        for sp in [true, false] {
            for sq in [true, false] {
                let v = V(frame: CGRect(x: 0, y: 0, width: 600, height: 260))
                v.runs = runs; v.smooth = sm; v.subpixelPos = sp; v.subpixelQuant = sq
                let win = NSWindow(contentRect: CGRect(x: -20000, y: -20000, width: 600, height: 260),
                                   styleMask: [.borderless], backing: .buffered, defer: false)
                win.colorSpace = NSColorSpace.sRGB
                win.contentView = v; win.orderBack(nil)
                guard let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds) else { continue }
                v.cacheDisplay(in: v.bounds, to: rep)
                let tag = "\(sm ? 1 : 0)\(sp ? 1 : 0)\(sq ? 1 : 0)"
                let path = out.replacingOccurrences(of: ".png", with: "-\(tag).png")
                if let d = ((rep.converting(to: .sRGB, renderingIntent: .default)) ?? rep)
                    .representation(using: .png, properties: [:]) {
                    try? d.write(to: URL(fileURLWithPath: path))
                }
                win.orderOut(nil)
            }
        }
    }
    print("glyph floor sweep written next to \(out)  (tag = smooth|subpixelPos|subpixelQuant)")
}

// MARK: - keyboard shortcut check

/// Synthesises the key events and reports which command each maps to, so the
/// shortcut rows are testable without a display or Accessibility permission.
func runKeys() {
    func ev(_ chars: String, _ mods: NSEvent.ModifierFlags, keyCode: UInt16 = 0) -> NSEvent? {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: mods,
                         timestamp: 0, windowNumber: 0, context: nil,
                         characters: chars, charactersIgnoringModifiers: chars,
                         isARepeat: false, keyCode: keyCode)
    }
    let cases: [(String, String, NSEvent?)] = [
        ("⌥⌘K", "toggleEnabled", ev("k", [.command, .option])),
        ("⌘,",  "settings",      ev(",", [.command])),
        ("⌘Q",  "quit",          ev("q", [.command])),
        ("esc", "dismiss",       ev("\u{1b}", [], keyCode: 53)),
        ("⌘K",  "(none)",        ev("k", [.command])),
        ("K",   "(none)",        ev("k", [])),
    ]
    print("keyboard shortcuts:")
    var bad = 0
    for (label, want, e) in cases {
        let got = e.flatMap { SurfacePanel.command(for: $0) }?.rawValue ?? "(none)"
        let ok = got == want
        if !ok { bad += 1 }
        print("  \(label.padding(toLength: 5, withPad: " ", startingAt: 0)) -> \(got.padding(toLength: 15, withPad: " ", startingAt: 0)) expected \(want)  \(ok ? "ok" : "FAIL")")
    }
    print(bad == 0 ? "all shortcut mappings ok" : "\(bad) FAILED")
}

// MARK: - on-screen stage (measures the SHIPPING window, not the harness)

/// Puts the reference's page composition on screen as a backdrop and floats the
/// real `SurfacePanel`s over it at the reference offsets. Capturing the screen
/// then measures the path the app actually ships: a real translucent NSPanel
/// with NSVisualEffectView vibrancy, composited by the window server — which
/// the offscreen harness cannot exercise.
final class BackdropWindowView: NSView {
    var offset = CGPoint.zero
    override var isFlipped: Bool { true }
    override func draw(_ d: CGRect) {
        guard let c = NSGraphicsContext.current?.cgContext else { return }
        c.saveGState()
        c.translateBy(x: offset.x, y: offset.y)
        Stage.drawBackdrop(c)
        c.restoreGState()
    }
}

func runStageOnscreen(delegate: AppDelegate, seconds: Double) {
    guard let scr = NSScreen.main else { return }
    let sf = scr.frame
    // Choose where the popover's content top-left lands on screen, then place
    // the page so the reference geometry is preserved around both panels.
    let popScreen = CGPoint(x: 900, y: 200)
    let off = CGPoint(x: popScreen.x - Stage.popoverOrigin.x,
                      y: popScreen.y - Stage.popoverOrigin.y)
    let swScreen = CGPoint(x: Stage.switchesOrigin.x + off.x,
                           y: Stage.switchesOrigin.y + off.y)

    let bv = BackdropWindowView(frame: CGRect(origin: .zero, size: sf.size))
    bv.offset = off
    let bw = NSWindow(contentRect: sf, styleMask: [.borderless], backing: .buffered, defer: false)
    bw.contentView = bv
    bw.colorSpace = NSColorSpace.sRGB
    bw.level = .floating
    bw.isOpaque = true
    bw.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    bw.setFrame(sf, display: true)
    bw.orderFrontRegardless()

    func place(_ p: SurfacePanel, contentTopLeft: CGPoint) {
        let ins = p.host.shadowInset
        let wantX = sf.minX + contentTopLeft.x - ins.left
        let wantY = contentTopLeft.y - ins.top            // from the screen top
        let snapX = wantX.rounded(.down), snapY = wantY.rounded(.down)
        p.setFrameTopLeftPoint(NSPoint(x: snapX, y: sf.maxY - snapY))
        p.host.subPixelOffset = CGPoint(x: wantX - snapX, y: wantY - snapY)
        p.orderFrontRegardless()
    }
    place(delegate.switches, contentTopLeft: swScreen)
    place(delegate.popover,  contentTopLeft: popScreen)
    // Sample below each panel once the backdrop window has painted. Scheduled,
    // not a nested RunLoop.run -- running a nested runloop inside
    // applicationDidFinishLaunching ends the session and the app exits early.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
        delegate.switches.refreshBackdrop { ok in print("live backdrop switches=\(ok)"); fflush(stdout) }
        delegate.popover.refreshBackdrop  { ok in print("live backdrop popover=\(ok)");  fflush(stdout) }
    }

    // crop rects in screen top-left points, for the capture step
    func rect(_ pageOrigin: CGPoint, _ w: CGFloat, _ h: CGFloat) -> String {
        let x = pageOrigin.x + off.x, y = pageOrigin.y + off.y
        return "\(x),\(y),\(w),\(h)"
    }
    print("CROP pop \(rect(Stage.popoverOrigin, PopoverMetrics.width, PopoverMetrics.height))")
    print("CROP sw \(rect(Stage.switchesOrigin, SwitchesMetrics.width, SwitchesMetrics.height))")
    print("SCREEN \(sf.width)x\(sf.height) backingScale=\(scr.backingScaleFactor)")
    fflush(stdout)
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { NSApp.terminate(nil) }
}

// MARK: - motion verification

/// Drives each animation with a real clock and reports the time it takes to
/// settle plus its value at the midpoint, so the ledger's timing rows carry
/// numbers measured from the running code rather than the source it was
/// written from.
func runMotion() {
    func settle(_ a0: Anim, to: CGFloat, label: String, expectDur: CGFloat, expectEase: String) {
        var a = a0
        a.set(to)
        let dt: CGFloat = 1.0/1000
        var t: CGFloat = 0
        var mid: CGFloat = -1
        while a.isRunning && t < 5 {
            a.tick(dt); t += dt
            if mid < 0 && t >= expectDur/2 { mid = a.value }
        }
        let ok = abs(t - expectDur) < 0.005 ? "ok" : "MISMATCH"
        print(String(format: "  %-26@  settled in %.3fs (declared %.3fs) %@   value at t/2 = %.4f   easing %@",
                     label as NSString, Double(t), Double(expectDur), ok as NSString, Double(mid), expectEase as NSString))
    }
    print("motion, driven with a 1 kHz clock:")
    settle(Anim(0, duration: 0.220, easing: .easeOut), to: 1, label: "toggle track colour",
           expectDur: 0.220, expectEase: "cubic-bezier(0,0,.2,1)")
    settle(Anim(0, duration: 0.220, easing: .knob), to: 1, label: "toggle knob transform",
           expectDur: 0.220, expectEase: "ease = cubic-bezier(.25,.1,.25,1)")
    settle(Anim(0.7, duration: 0.220, easing: .easeOut), to: 0.3, label: "slider fill width",
           expectDur: 0.220, expectEase: "cubic-bezier(0,0,.2,1)")
    settle(Anim(0, duration: 0.100, easing: .easeOut), to: 1, label: "row hover background",
           expectDur: 0.100, expectEase: "cubic-bezier(0,0,.2,1)")
    settle(Anim(0, duration: 0.150, easing: .easeInOut), to: 1, label: "play button / Preview",
           expectDur: 0.150, expectEase: "cubic-bezier(.4,0,.2,1)")

    print("\nreduced motion (Motion.forceInstant = true):")
    Motion.forceInstant = true
    var a = Anim(0, duration: 0.220, easing: .easeOut)
    a.set(1)
    print("  toggle knob after set(), before any tick: value = \(a.value), isRunning = \(a.isRunning)")
    var s = SwitchesState(); s.setHover(0)
    print("  switch row hover progress, no tick: \(s.progress(0))")
    Motion.forceInstant = false

    print("\neasing curve check (value at t = 0.25, 0.5, 0.75 of duration):")
    for (n, e) in [("ease-out cubic-bezier(0,0,.2,1)", Easing.easeOut),
                   ("ease-in-out cubic-bezier(.4,0,.2,1)", Easing.easeInOut),
                   ("ease cubic-bezier(.25,.1,.25,1)", Easing.knob)] {
        print(String(format: "  %-38@  %.4f  %.4f  %.4f", n as NSString,
                     Double(e(0.25)), Double(e(0.5)), Double(e(0.75))))
    }
}

// MARK: - vector rasteriser floor

/// The same shapes tools/vectorfloor.mjs draws in Chrome, drawn with the
/// clone's own primitives. Diffing the two isolates the CoreGraphics-vs-Skia
/// edge-antialiasing floor for curves and hairlines.
func runVectorFloor(out: String) {
    final class V: NSView {
        override var isFlipped: Bool { true }
        override func draw(_ d: CGRect) {
            guard let c = NSGraphicsContext.current?.cgContext else { return }
            Draw.fillRect(c, CGRect(x: 0, y: 0, width: 600, height: 260), T.orange50)
            Draw.fillRect(c, CGRect(x: 300, y: 0, width: 300, height: 260), T.stone800)
            // toggle
            let tr = CGRect(x: 24, y: 20, width: 44, height: 20)
            Draw.fill(c, Draw.pill(tr), T.teal500)
            Draw.fill(c, Draw.pill(CGRect(x: 24 + 2 + 14, y: 22, width: 26, height: 16)), T.orange50)
            // slider
            Draw.fill(c, Draw.pill(CGRect(x: 24, y: 60, width: 240, height: 4)), T.stone800.withAlphaComponent(0.10))
            Draw.fill(c, Draw.pill(CGRect(x: 24, y: 60, width: 168, height: 4)), T.stone800)
            Draw.fill(c, Draw.pill(CGRect(x: 178, y: 54, width: 20, height: 16)), T.orange50)
            // chip + bar
            Draw.fill(c, Draw.roundedPath(CGRect(x: 24, y: 100, width: 18, height: 18), 6), T.stone800.withAlphaComponent(0.15))
            Draw.fill(c, Draw.roundedPath(CGRect(x: 52, y: 106, width: 96, height: 6), 3), T.stone800.withAlphaComponent(0.10))
            // light panel corner
            let lp = CGRect(x: 24, y: 140, width: 200, height: 80)
            Draw.fill(c, Draw.roundedPath(lp, 24), T.orange50.withAlphaComponent(0.80))
            Draw.borderTop(c, rect: lp, radius: 24, width: 1, color: T.orange50.withAlphaComponent(0.30))
            // dark side: play circle
            let pb = CGRect(x: 324, y: 20, width: 24, height: 24)
            Draw.fill(c, Draw.pill(pb), T.orange50.withAlphaComponent(0.10))
            Draw.borderTop(c, rect: pb, radius: 12, width: 1, color: T.orange50.withAlphaComponent(0.15))
            // swatch
            let sw = CGRect(x: 324, y: 60, width: 18, height: 18)
            c.saveGState(); c.addPath(Draw.roundedPath(sw, 6)); c.clip()
            let cs = CGColorSpaceCreateDeviceRGB()
            let g = CGGradient(colorsSpace: cs, colors: [Catalog.hex("#878078").cgColor,
                                                         Catalog.hex("#44403c").cgColor] as CFArray,
                               locations: [0, 1])!
            c.drawLinearGradient(g, start: CGPoint(x: sw.midX, y: sw.minY), end: CGPoint(x: sw.midX, y: sw.maxY), options: [])
            c.restoreGState()
            c.saveGState()
            c.addPath(Draw.roundedPath(sw.insetBy(dx: 0.5, dy: 0.5), 5.5))
            c.setStrokeColor(T.orange50.withAlphaComponent(0.15).cgColor); c.setLineWidth(1); c.strokePath()
            c.restoreGState()
            Draw.borderTop(c, rect: sw, radius: 6, width: 1, color: T.orange50.withAlphaComponent(0.35))
            // badge outline
            let bd = CGRect(x: 324, y: 100, width: 36, height: 20)
            c.saveGState()
            c.addPath(Draw.roundedPath(bd.insetBy(dx: 0.75, dy: 0.75), 5.25))
            c.setStrokeColor(T.rose.withAlphaComponent(0.75).cgColor); c.setLineWidth(1.5); c.strokePath()
            c.restoreGState()
            // dark panel corner
            let dp = CGRect(x: 324, y: 140, width: 200, height: 80)
            Draw.fill(c, Draw.roundedPath(dp, 24), T.stone800.withAlphaComponent(0.80))
            Draw.borderTop(c, rect: dp, radius: 24, width: 1, color: T.orange50.withAlphaComponent(0.15))
        }
    }
    let v = V(frame: CGRect(x: 0, y: 0, width: 600, height: 260))
    let win = NSWindow(contentRect: CGRect(x: -20000, y: -20000, width: 600, height: 260),
                       styleMask: [.borderless], backing: .buffered, defer: false)
    win.colorSpace = NSColorSpace.sRGB
    win.contentView = v; win.orderBack(nil)
    guard let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds) else { return }
    v.cacheDisplay(in: v.bounds, to: rep)
    if let d = ((rep.converting(to: .sRGB, renderingIntent: .default)) ?? rep)
        .representation(using: .png, properties: [:]) { try? d.write(to: URL(fileURLWithPath: out)) }
    print("vector floor render -> \(out)")
}

// MARK: - menu bar app

final class AppDelegate: NSObject, NSApplicationDelegate {
    var item: NSStatusItem!
    var popover: SurfacePanel!
    private var outsideClick: Any?
    var switches: SurfacePanel!
    var settings: SettingsWindowController?

    func applicationDidFinishLaunching(_ n: Notification) {
        SoundEngine.shared.start()
        Settings.shared.apply()
        KeyMonitor.shared.startLocal()          // no permission needed
        let global = KeyMonitor.shared.startGlobal()
        SleepTriggers.shared.start()
        SleepTriggers.shared.onChange = { [weak self] in
            self?.popover.host.needsDisplay = true
            print("sleep triggers: \(SleepTriggers.shared.isAsleep ? "ASLEEP (muted)" : "awake")")
            fflush(stdout)
        }
        print("audio: engine=\(SoundEngine.shared.isRunning) switch=\(SoundEngine.shared.loadedName) "
            + "global=\(global ? "on" : "off") local=on")
        let km = KeyMonitor.shared
        var line = "perm: accessibility=\(km.hasAccessibility) "
            + "inputMonitoring=\(km.hasInputMonitoring) tapEnabled=\(km.tapEnabled)"
        if let b = km.blockedBy { line += "  BLOCKED BY: \(b)" }
        print(line)
        // Also to a file: launched from Finder there is no stdout to read, and
        // this is precisely the case whose permissions differ from a launch
        // out of a terminal (which lends the app its parent's trust).
        Settings.shared.log("audio: switch=\(SoundEngine.shared.loadedName)\n" + line)
        fflush(stdout)
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = keycapImage()
        item.button?.image?.isTemplate = true
        item.button?.target = self
        item.button?.action = #selector(toggle)

        popover = SurfacePanel(surface: .popover,
                               size: CGSize(width: PopoverMetrics.width, height: PopoverMetrics.height))
        switches = SurfacePanel(surface: .switches,
                                size: CGSize(width: SwitchesMetrics.width, height: SwitchesMetrics.height))
        popover.host.onCommand = { [weak self] row in
            if row == 7 { NSApp.terminate(nil) }
            if row == 6 { self?.showSettings() }
        }
        for p in [popover, switches] {
            p?.onKeyCommand = { [weak self] c in self?.handle(c) }
        }
        if let i = CommandLine.arguments.firstIndex(of: "--stage-onscreen") {
            let secs = (i + 1 < CommandLine.arguments.count)
                ? (Double(CommandLine.arguments[i+1]) ?? 10) : 10
            runStageOnscreen(delegate: self, seconds: secs)
            return
        }
        if let i = CommandLine.arguments.firstIndex(of: "--demo") {
            let secs = (i + 1 < CommandLine.arguments.count)
                ? (Double(CommandLine.arguments[i+1]) ?? 6) : 6
            runDemo(seconds: secs)
        }
    }

    func keycapImage() -> NSImage {
        let d = "M11.5 26.91h3.969a.5.5 0 0 0 .5-.5v-3.765a.5.5 0 0 1 .098-.297l1.047-1.418a.2.2 0 0 1 .333.017l3.392 5.718a.5.5 0 0 0 .43.245h4.595a.5.5 0 0 0 .425-.763l-5.173-8.358a.5.5 0 0 1 .024-.562l4.772-6.429A.5.5 0 0 0 25.51 10h-3.967a.5.5 0 0 0-.404.206l-5.049 6.928a.092.092 0 0 1-.074.038.047.047 0 0 1-.047-.047V10.5a.5.5 0 0 0-.5-.5H11.5a.5.5 0 0 0-.5.5v15.91a.5.5 0 0 0 .5.5Z"
        let size: CGFloat = 18
        let img = NSImage(size: NSSize(width: size, height: size), flipped: true) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.addPath(SVGPath.path(d, viewBox: 36, size: size))
            ctx.setFillColor(NSColor.black.cgColor); ctx.fillPath()
            return true
        }
        return img
    }

    /// --demo: put both surfaces on screen at a fixed spot so the running app
    /// can be captured, then quit. Bounded so it cannot sit on the user's screen.
    func runDemo(seconds: Double) {
        guard let scr = NSScreen.main else { return }
        let v = scr.visibleFrame
        let ins = popover.host.shadowInset
        popover.setFrameOrigin(CGPoint(x: v.maxX - popover.frame.width - 40,
                                       y: v.maxY - popover.frame.height + ins.bottom - 8))
        popover.orderFrontRegardless()
        switches.setFrameOrigin(CGPoint(x: popover.frame.minX - switches.frame.width + 30,
                                        y: popover.frame.maxY - switches.frame.height))
        switches.orderFrontRegardless()
        let f = popover.frame, g = switches.frame
        print("demo: popover window \(Int(f.width))x\(Int(f.height)) at \(Int(f.minX)),\(Int(f.minY))")
        print("demo: switches window \(Int(g.width))x\(Int(g.height)) at \(Int(g.minX)),\(Int(g.minY))")
        print("demo: hasShadow=\(popover.hasShadow) styleMask=borderless+nonactivating level=\(popover.level.rawValue) opaque=\(popover.isOpaque) titlebar=none")
        print("demo: activationPolicy=\(NSApp.activationPolicy().rawValue) (1 = .accessory: no Dock icon, no app menu)")
        if let b = item.button, let w = b.window {
            let f = w.convertToScreen(b.convert(b.bounds, to: nil))
            print("demo: status item button \(Int(f.width))x\(Int(f.height)) at screen \(Int(f.minX)),\(Int(f.minY)); template image=\(b.image?.isTemplate ?? false)")
        } else { print("demo: status item button UNAVAILABLE") }
        print("demo: panel corner radius 24, drawn shadow 0 25px 50px -12px, backdrop NSVisualEffectView(.underWindowBackground)")
        fflush(stdout)
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { NSApp.terminate(nil) }
    }

    func handle(_ c: SurfacePanel.Command) {
        switch c {
        case .toggleEnabled:
            popover.host.pop.enabled.toggle()
            popover.host.pop.knob.set(popover.host.pop.enabled ? 1 : 0)
            popover.host.pop.track.set(popover.host.pop.enabled ? 1 : 0)
            popover.host.needsDisplay = true
        case .settings: showSettings()
        case .quit:     NSApp.terminate(nil)
        case .dismiss:  popover.orderOut(nil); switches.orderOut(nil)
        }
    }

    @objc func toggle() {
        if popover.isVisible { dismiss(); return }
        guard let b = item.button, let w = b.window else { return }
        let f = w.convertToScreen(b.convert(b.bounds, to: nil))
        let ins = popover.host.shadowInset

        // The panel is larger than the popover you can see: the drawn shadow
        // is inset 20pt at the top and 60pt at the bottom. So placement has to
        // work in *content* edges, not window edges. Using ins.bottom here put
        // the content 40pt too high — up over the status item, which then
        // could not be clicked to dismiss, and into the notch on a notched
        // display.
        let gap: CGFloat = 6
        let scr = w.screen ?? NSScreen.main
        var top = f.minY - gap
        var x = f.midX - popover.frame.width / 2
        if let v = scr?.visibleFrame {
            // visibleFrame already excludes the menu bar, and on a notched
            // display it excludes the notch with it. Never go above it.
            top = min(top, v.maxY - gap)
            // Keep the visible popover on screen when the status item sits
            // near an edge — menu bar extras crowd to the right.
            let contentW = popover.frame.width - ins.left - ins.right
            x = min(max(x, v.minX + 8 - ins.left),
                    v.maxX - 8 - contentW - ins.left)
        }
        popover.setFrameOrigin(CGPoint(x: x, y: top + ins.top - popover.frame.height))
        popover.makeKeyAndOrderFront(nil)     // so the shortcuts reach it
        popover.refreshBackdrop(nil)
        watchForOutsideClick()
    }

    func dismiss() {
        popover.orderOut(nil)
        switches.orderOut(nil)
        if let m = outsideClick { NSEvent.removeMonitor(m); outsideClick = nil }
    }

    /// Clicking away closes it, the way every other menu bar item behaves.
    /// Mouse events need no permission for a global monitor; only key events do.
    private func watchForOutsideClick() {
        guard outsideClick == nil else { return }
        outsideClick = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            guard let self else { return }
            let p = NSEvent.mouseLocation
            if popover.frame.contains(p) { return }
            if switches.isVisible, switches.frame.contains(p) { return }
            // A click on the status item is toggle()'s to handle; dismissing
            // here first would let it reopen immediately.
            if let b = item.button, let w = b.window,
               w.convertToScreen(b.convert(b.bounds, to: nil)).contains(p) { return }
            dismiss()
        }
    }

    func showSettings() {
        if settings == nil { settings = SettingsWindowController() }
        settings?.show()
    }

    func showSwitches() {
        let p = popover.frame
        switches.setFrameOrigin(CGPoint(x: p.minX - switches.frame.width + 40,
                                        y: p.maxY - switches.frame.height))
        switches.orderFrontRegardless()
    }
}

// MARK: - entry

let args = CommandLine.arguments
let app = NSApplication.shared

if args.contains("--devices") {
    app.setActivationPolicy(.prohibited)
    SoundEngine.shared.start()
    Settings.shared.apply()
    print("output devices:")
    let def = AudioDevices.systemDefault()
    for d in AudioDevices.outputs() {
        print("  " + d.name.padding(toLength: 34, withPad: " ", startingAt: 0)
              + "id \(d.id)" + (d.id == def ? "   (system default)" : ""))
    }
    print("\nsetting: \(Settings.shared.playSoundThrough)")
    print("engine is on: \(SoundEngine.shared.currentOutputName)")
    exit(0)
} else if args.contains("--fnkey-test") {
    // Decodes synthetic NX_SYSDEFINED events rather than posting real ones,
    // so checking this does not change the machine's brightness or volume.
    app.setActivationPolicy(.prohibited)
    let names: [(Int, String)] = [
        (3, "brightness down"), (2, "brightness up"), (22, "illum down"),
        (21, "illum up"), (18, "previous"), (20, "rewind"), (16, "play/pause"),
        (17, "next"), (19, "fast fwd"), (7, "mute"), (1, "volume down"),
        (0, "volume up"),
    ]
    let fname: [UInt16: String] = [122: "F1", 120: "F2", 99: "F3", 118: "F4",
        96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10",
        103: "F11", 111: "F12", 53: "esc"]
    var bad = 0
    print("media key          -> key   pan")
    for (code, label) in names {
        guard let ns = NSEvent.otherEvent(
                with: .systemDefined, location: .zero, modifierFlags: [],
                timestamp: 0, windowNumber: 0, context: nil,
                subtype: 8, data1: (code << 16) | 0x0A00, data2: -1),
              let cg = ns.cgEvent, let aux = KeyMonitor.auxKey(cg) else {
            print(String(format: "  %-16s -> DECODE FAILED", (label as NSString).utf8String!))
            bad += 1; continue
        }
        let pan = KeyMonitor.pan(for: aux.key)
        print("  \(label.padding(toLength: 16, withPad: " ", startingAt: 0)) -> "
            + "\(fname[aux.key] ?? "?")".padding(toLength: 6, withPad: " ", startingAt: 0)
            + String(format: "%+.2f", pan) + (aux.down ? "" : "  (up?)"))
        if !aux.down { bad += 1 }
    }
    print("\nfunction row pan spread (should run left to right):")
    let row: [UInt16] = [53, 122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111]
    var last = -2.0 as Float
    var monotonic = true
    for k in row {
        let p = KeyMonitor.pan(for: k)
        if p <= last { monotonic = false }
        last = p
    }
    print("  " + row.map { String(format: "%+.2f", KeyMonitor.pan(for: $0)) }.joined(separator: " "))
    print(monotonic ? "  PASS  strictly left-to-right" : "  FAIL  not ordered")
    if !monotonic { bad += 1 }
    // repeats must be dropped, or a held key machine-guns
    if let r = NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: [],
                                  timestamp: 0, windowNumber: 0, context: nil,
                                  subtype: 8, data1: (16 << 16) | 0x0A01, data2: -1),
       let cg = r.cgEvent {
        let dropped = KeyMonitor.auxKey(cg) == nil
        print(dropped ? "  PASS  key repeats dropped" : "  FAIL  key repeat not dropped")
        if !dropped { bad += 1 }
    }
    print(bad == 0 ? "\nALL PASS" : "\n\(bad) FAILED")
    exit(bad == 0 ? 0 : 1)
} else if args.contains("--popover-check") {
    // Opens the popover through the real toggle() path and checks it against
    // the live screen, rather than trusting the arithmetic.
    let d = AppDelegate()
    app.delegate = d
    app.setActivationPolicy(.accessory)
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        d.toggle()
        guard let b = d.item.button, let w = b.window, let scr = w.screen else {
            print("no status item"); exit(1)
        }
        let sb = w.convertToScreen(b.convert(b.bounds, to: nil))
        let v = scr.visibleFrame, fr = scr.frame
        let ins = d.popover.host.shadowInset
        let win = d.popover.frame
        // what you actually see, with the drawn shadow margin removed
        let content = CGRect(x: win.minX + ins.left, y: win.minY + ins.bottom,
                             width: win.width - ins.left - ins.right,
                             height: win.height - ins.top - ins.bottom)
        print("screen        \(Int(fr.width))x\(Int(fr.height))  visibleFrame maxY \(Int(v.maxY))")
        print("menu bar      \(Int(fr.maxY - v.maxY))pt tall\(scr.safeAreaInsets.top > 0 ? "  NOTCHED (safeArea top \(Int(scr.safeAreaInsets.top)))" : ""))")
        print("status item   x \(Int(sb.minX))–\(Int(sb.maxX))  y \(Int(sb.minY))–\(Int(sb.maxY))")
        print("popover shown x \(Int(content.minX))–\(Int(content.maxX))  top \(Int(content.maxY))")
        var bad = 0
        func check(_ ok: Bool, _ what: String) {
            print((ok ? "  PASS  " : "  FAIL  ") + what); if !ok { bad += 1 }
        }
        check(content.maxY <= sb.minY, "clear of the status item (top \(Int(content.maxY)) <= icon bottom \(Int(sb.minY)))")
        check(content.maxY <= v.maxY,  "below the menu bar, so clear of the notch (top \(Int(content.maxY)) <= \(Int(v.maxY)))")
        check(content.minX >= v.minX && content.maxX <= v.maxX, "within the screen horizontally")
        check(!content.intersects(sb), "does not overlap the icon's rect at all")
        print(bad == 0 ? "\nALL PASS" : "\n\(bad) FAILED")
        if args.contains("--hold") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 20) { exit(bad == 0 ? 0 : 1) }
        } else { exit(bad == 0 ? 0 : 1) }
    }
    app.run()
} else if args.contains("--tap-test") {
    // Arms the tap regardless of what the preflight says, then reports what
    // actually arrived. The preflight describes TCC's records; only this
    // describes whether the tap works.
    app.setActivationPolicy(.prohibited)
    let km = KeyMonitor.shared
    let armed = km.startGlobal()
    let pre = "preflight: accessibility=\(km.hasAccessibility) inputMonitoring=\(km.hasInputMonitoring)"
    let arm = "tapCreate=\(armed ? "ok" : "FAILED — \(km.blockedBy ?? "?")") enabled=\(km.tapEnabled)"
    Settings.shared.log("\(pre)\n\(arm)\nlistening 12s…")
    print(pre); print(arm)
    RunLoop.main.run(until: Date().addingTimeInterval(12))
    let res = "\(pre)\n\(arm)\nEVENTS SEEN: \(km.globalEventCount)"
            + "   of which function-row/media: \(km.auxEventCount)"
    Settings.shared.log(res)
    print("EVENTS SEEN: \(km.globalEventCount)")
    exit(0)
} else if args.contains("--grant") {
    // User-initiated only. Prints the state, opens both panes, and asks —
    // the app never does any of this on its own at launch.
    app.setActivationPolicy(.prohibited)
    let km = KeyMonitor.shared
    print("before:  accessibility=\(km.hasAccessibility) inputMonitoring=\(km.hasInputMonitoring)")
    if km.hasAccessibility || km.hasInputMonitoring {
        print("Already granted. Relaunch Klack and typing anywhere will sound.")
        exit(0)
    }
    KeyMonitor.openSettingsPanes()
    km.requestAccess()
    print("""

    Two panes just opened. In each one, add or tick:

        \(Bundle.main.bundlePath)

    Input Monitoring is the one that matters for keystrokes; Accessibility
    also works. Granting either is enough. Then relaunch Klack.
    """)
    // Stay alive so the system prompts have a process to belong to; exiting
    // straight away can drop them before they are shown.
    RunLoop.main.run(until: Date().addingTimeInterval(12))
    exit(0)
} else if args.contains("--settings-dump") {
    app.setActivationPolicy(.prohibited)
    SoundEngine.shared.start()
    if args.contains("--reset") { Settings.shared.reset(); print("settings reset") }
    Settings.shared.apply()
    print("store: \(Settings.shared.path)")
    print(Settings.shared.dump)
    exit(0)
} else if args.contains("--set") {
    app.setActivationPolicy(.prohibited)
    SoundEngine.shared.start()
    let S = Settings.shared
    if let i = args.firstIndex(of: "--set"), i + 2 < args.count {
        let k = args[i+1], v = args[i+2]
        switch k {
        case "volume":        S.volume = Double(v) ?? S.volume
        case "switch":        S.switchIndex = Int(v) ?? S.switchIndex
        case "pitch":         S.pitchVariation = (v == "on")
        case "panning":       S.stereoPanning = (v == "on")
        case "spatial":       S.spatialAudio = (v == "on")
        case "rapid":         S.ignoreRapidKeyEvents = (v == "on")
        case "modifiers":     S.disableAudibleModifiers = (v == "on")
        case "tone":          let p = v.split(separator: ",").compactMap { Double($0) }
                              if p.count == 2 { S.tonePad = CGPoint(x: p[0], y: p[1]) }
        case "effects":       S.effectsVolume = Double(v) ?? S.effectsVolume
        case "output":        S.playSoundThrough = v
        default: print("unknown key \(k)"); exit(1)
        }
        print("set \(k) = \(v)")
    }
    exit(0)
} else if args.contains("--triggers") {
    app.setActivationPolicy(.prohibited)
    let t = SleepTriggers.shared
    t.enabled = Set(SleepPane.triggers.map { $0.label })   // read them all
    print("sleep trigger detectors, read live:")
    for tr in SleepPane.triggers {
        let r = t.read(tr.label)
        let s: String
        switch r {
        case .active: s = "ACTIVE"
        case .inactive: s = "inactive"
        case .unavailable(let why): s = "unavailable — \(why)"
        }
        print("  " + tr.label.padding(toLength: 20, withPad: " ", startingAt: 0) + s)
    }
    exit(0)
} else if args.contains("--usage") {
    app.setActivationPolicy(.prohibited)
    let u = UsageStore.shared
    if args.contains("--reset") { u.reset(); print("usage reset") }
    if let i = args.firstIndex(of: "--simulate"), i + 1 < args.count, let n = Int(args[i+1]) {
        SoundEngine.shared.switchIndex = 5              // Super Red
        let codes: [UInt16] = [0, 1, 2, 3, 5, 12, 13, 14, 36]
        for k in 0..<n { KeyMonitor.shared.trigger(keyCode: codes[k % codes.count], down: true) }
        SoundEngine.shared.switchIndex = 0              // then a few on Japanese Black
        for k in 0..<(n/10) { KeyMonitor.shared.trigger(keyCode: codes[k % codes.count], down: true) }
        for _ in 0..<3 { u.countClick() }
        u.flush()
        print("simulated \(n + n/10) keystrokes and 3 clicks")
    }
    print("store: \(u.path)")
    print("  \(u.sinceText)")
    print("  Keystrokes \(u.keystrokesText)")
    print("  Dings      \(u.dingsText)")
    print("  Clicks     \(u.clicksText)")
    print("  Favourite Switches:")
    for f in u.favourites { print("    \(f.name): \(u.countText(f.count))") }
    if u.favourites.isEmpty { print("    (none yet)") }
    exit(0)
} else if args.contains("--sound-test") {
    app.setActivationPolicy(.prohibited)
    let e = SoundEngine.shared
    SoundEngine.debugGain = args.contains("--debug-gain")
    e.start(manualRender: true)
    Settings.shared.apply()                 // the render reflects the saved settings
    if let i = args.firstIndex(of: "--switch"), i + 1 < args.count {
        e.switchIndex = Int(args[i+1]) ?? e.switchIndex
    }
    e.deterministic = args.contains("--deterministic")
    SoundEngine.debugGain = args.contains("--debug-gain")
    if args.contains("--ding") { e.dingOnReturn = true }
    // 24 keystrokes at ~110 wpm, each a down and an up 70 ms later
    let dingMode = args.contains("--ding")
    var strokes: [(Double, Bool, Float)] = []
    let codes: [UInt16] = [0, 1, 2, 3, 5, 4, 38, 40, 12, 13, 14, 15, 49]
    var spacing = 0.110
    if let i = args.firstIndex(of: "--spacing"), i + 1 < args.count {
        spacing = Double(args[i+1]) ?? spacing
    }
    if args.contains("--fast") { spacing = 0.035 }
    var t = 0.15
    for k in 0..<(spacing < 0.08 ? 60 : 24) {
        let pan = KeyMonitor.pan(for: codes[k % codes.count])
        strokes.append((t, true, pan))
        strokes.append((t + 0.070, false, pan))
        t += spacing
    }
    if dingMode {
        // return-key only, so the render contains just the effect
        strokes = (0..<6).map { (0.2 + Double($0) * 0.35, true, Float(0)) }
    }
    let out = Paths.shots("sound-test.wav")
    try? FileManager.default.removeItem(at: out)
    do {
        try e.renderOffline(seconds: t + 0.5, to: out, strokes: strokes)
        print("rendered \(strokes.count) events for \(e.loadedName) -> \(out.path)")
    } catch { print("render failed: \(error)") }
    exit(0)
} else if args.contains("--settings-verify") {
    app.setActivationPolicy(.prohibited)
    var sc: CGFloat = 1.946        // the reference frame's measured scale
    if let i = args.firstIndex(of: "--scale"), i + 1 < args.count { sc = CGFloat(Double(args[i+1]) ?? 1.946) }
    var sy: CGFloat = 0
    if let i = args.firstIndex(of: "--scroll"), i + 1 < args.count { sy = CGFloat(Double(args[i+1]) ?? 0) }
    var pane = SettingsPane.sound
    if let i = args.firstIndex(of: "--pane"), i + 1 < args.count,
       let p = SettingsPane(rawValue: args[i+1]) { pane = p }
    if pane == .stats && !args.contains("--live") {
        // The ledger's Stats geometry row is checked against the Raycast
        // screenshot's numbers, so the verify render uses those rather than
        // whatever this machine has typed.
        let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"
        UsageStore.shared.seed(keystrokes: 474_961, dings: 0, clicks: 517,
                               perSwitch: ["Super Red": 474_956, "Japanese Black": 4, "Cream": 1],
                               since: f.date(from: "Apr 30, 2026") ?? Date())
    }
    let out = Paths.shots("settings-clone.png").path
    renderSettings(out: out, scale: sc, pane: pane, scrollY: sy)
    exit(0)
} else if args.contains("--settings") {
    app.setActivationPolicy(.regular)
    let d = AppDelegate()
    app.delegate = d
    DispatchQueue.main.async { d.showSettings() }
    app.run()
} else if args.contains("--keys") {
    app.setActivationPolicy(.prohibited)
    runKeys()
    exit(0)
} else if args.contains("--motion") {
    app.setActivationPolicy(.prohibited)
    runMotion()
    exit(0)
} else if args.contains("--vectorfloor") {
    app.setActivationPolicy(.prohibited)
    runVectorFloor(out: Paths.shots("vectorfloor-clone.png").path)
    exit(0)
} else if args.contains("--glyphfloor") {
    app.setActivationPolicy(.prohibited)
    runGlyphFloor(out: Paths.shots("glyphfloor-clone.png").path)
    exit(0)
} else if let i = args.firstIndex(of: "--verify") {
    let out = (i + 1 < args.count && !args[i+1].hasPrefix("--")) ? args[i+1] : "shots"
    app.setActivationPolicy(.prohibited)
    var states = ["floor", "rest2"]
    if args.contains("--backdrop") { states += ["backdrop"] }
    if args.contains("--states") { states += ["notext"] }
    if args.contains("--scale1") { states += ["scale1"] }
    if args.contains("--states") { states += ["hover", "focus", "off"] }
    runVerify(outDir: out, scale: 2, states: states)
    exit(0)
} else {
    if let i = args.firstIndex(of: "--material"), i + 1 < args.count {
        SurfacePanel.materialOverride = SurfacePanel.materials.first { $0.0 == args[i+1] }?.1
    }
    if let i = args.firstIndex(of: "--appearance"), i + 1 < args.count {
        SurfacePanel.appearanceOverride = args[i+1] == "dark" ? .darkAqua : .aqua
    }
    SurfacePanel.emphasizedOverride = args.contains("--emphasized")
    if args.contains("--live-backdrop")    { SurfacePanel.liveBackdropEnabled = true }
    if args.contains("--no-live-backdrop") { SurfacePanel.liveBackdropEnabled = false }
    app.setActivationPolicy(.accessory)
    let d = AppDelegate()
    app.delegate = d
    app.run()
}
