import AppKit
import CoreText
import CoreImage

/// Drawing primitives with CSS semantics, so every ledger row maps to one call.
/// All of these assume a **flipped** context: origin top-left, y increasing down,
/// units = logical px, exactly like the reference's CSS pixel space.
enum Draw {

    /// Set by --verify's `notext` pass, to build an exact glyph mask for the
    /// residual split (text rasterisation vs everything else).
    static var suppressText = false

    // MARK: - paths

    /// CSS `border-radius` uses **circular** corners, not a continuous squircle.
    static func roundedPath(_ r: CGRect, _ radius: CGFloat) -> CGPath {
        let rad = min(radius, min(r.width, r.height) / 2)
        return CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil)
    }

    /// Rounded rect with per-corner radii, in CSS order: TL, TR, BR, BL.
    /// Built for a flipped context, so "top" is minY.
    static func roundedPath(_ r: CGRect, _ tl: CGFloat, _ tr: CGFloat,
                            _ br: CGFloat, _ bl: CGFloat) -> CGPath {
        let p = CGMutablePath()
        let (x0, y0, x1, y1) = (r.minX, r.minY, r.maxX, r.maxY)
        p.move(to: CGPoint(x: x0 + tl, y: y0))
        p.addLine(to: CGPoint(x: x1 - tr, y: y0))
        if tr > 0 { p.addArc(tangent1End: CGPoint(x: x1, y: y0), tangent2End: CGPoint(x: x1, y: y0 + tr), radius: tr) }
        p.addLine(to: CGPoint(x: x1, y: y1 - br))
        if br > 0 { p.addArc(tangent1End: CGPoint(x: x1, y: y1), tangent2End: CGPoint(x: x1 - br, y: y1), radius: br) }
        p.addLine(to: CGPoint(x: x0 + bl, y: y1))
        if bl > 0 { p.addArc(tangent1End: CGPoint(x: x0, y: y1), tangent2End: CGPoint(x: x0, y: y1 - bl), radius: bl) }
        p.addLine(to: CGPoint(x: x0, y: y0 + tl))
        if tl > 0 { p.addArc(tangent1End: CGPoint(x: x0, y: y0), tangent2End: CGPoint(x: x0 + tl, y: y0), radius: tl) }
        p.closeSubpath()
        return p
    }

    /// A capsule — CSS `rounded-full` on a non-square box.
    static func pill(_ r: CGRect) -> CGPath {
        roundedPath(r, min(r.width, r.height) / 2)
    }

    // MARK: - text

    /// Blink rounds the font's ascent/descent to integers before computing the
    /// line box, so its baseline sits a fraction of a pixel away from the one
    /// CoreText's metrics give. Measured per size with tools/baseline.mjs by
    /// locating the ink bottom of "HHHH" (which sits on the baseline):
    ///
    ///     size  lh     Chrome baseline   CoreText formula   correction
    ///     15    22.5   17.000            16.9189            +0.0811
    ///     14    20     15.000            15.2910            -0.2910
    ///     12    16     12.500            12.5352            -0.0352
    ///
    /// The correction is a metrics difference, independent of line-height;
    /// half-leading is already handled by the caller's lineHeight.
    static func metricCorrection(size: CGFloat) -> CGFloat {
        switch size {
        case 15: return  0.0811
        case 14: return -0.2910
        case 12: return -0.0352
        default: return 0
        }
    }

    /// Baseline offset inside a CSS line box: half-leading + ascent, corrected
    /// to Blink's rounded metrics.
    static func baseline(in lineHeight: CGFloat, font: NSFont) -> CGFloat {
        let a = font.ascender, d = -font.descender
        return (lineHeight - (a + d)) / 2 + a
             + metricCorrection(size: font.pointSize)
    }

    static func lineWidth(_ s: String, font: NSFont, tracking: CGFloat = 0) -> CGFloat {
        var attrs: [NSAttributedString.Key: Any] = [.font: font]
        if tracking != 0 { attrs[.kern] = tracking }
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: attrs))
        return CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    }

    /// Draw `s` with its CSS line box top at `lineTop`, left edge at `x`.
    @discardableResult
    static func text(_ ctx: CGContext, _ s: String, x: CGFloat, lineTop: CGFloat,
                     lineHeight: CGFloat, font: NSFont, color: NSColor,
                     tracking: CGFloat = 0) -> CGFloat {
        var attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        if tracking != 0 { attrs[.kern] = tracking }
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: attrs))
        if suppressText { return CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil)) }
        ctx.saveGState()
        ctx.textMatrix = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: 0)
        // Chrome snaps the baseline to a whole device pixel; do the same, in
        // device space, so it holds wherever the panel origin lands.
        let raw = CGPoint(x: x, y: lineTop + baseline(in: lineHeight, font: font))
        let dev = ctx.convertToDeviceSpace(raw)
        let snapped = ctx.convertToUserSpace(CGPoint(x: dev.x, y: dev.y.rounded()))
        ctx.textPosition = CGPoint(x: x, y: snapped.y)
        CTLineDraw(line, ctx)
        ctx.restoreGState()
        return CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    }

    // MARK: - fills

    /// `ctx.draw(_:in:)` assumes a y-up context; in our flipped space it would
    /// mirror the image, so un-flip locally around the destination rect.
    static func image(_ ctx: CGContext, _ img: CGImage, in r: CGRect) {
        ctx.saveGState()
        ctx.translateBy(x: 0, y: r.midY)
        ctx.scaleBy(x: 1, y: -1)
        ctx.translateBy(x: 0, y: -r.midY)
        ctx.interpolationQuality = .high
        ctx.draw(img, in: r)
        ctx.restoreGState()
    }

    static func fill(_ ctx: CGContext, _ path: CGPath, _ color: NSColor) {
        ctx.saveGState()
        ctx.addPath(path); ctx.setFillColor(color.cgColor); ctx.fillPath()
        ctx.restoreGState()
    }

    /// Chrome pixel-snaps box edges at paint time, so a 1px rule at a
    /// half-pixel offset comes out crisp rather than spread over two rows.
    /// Without this the clone is clean at 2x (everything lands on the grid) and
    /// every hairline goes soft at 1x — 69% of the 1x residual was these rules.
    static func snapped(_ ctx: CGContext, _ r: CGRect) -> CGRect {
        let a = ctx.convertToDeviceSpace(CGPoint(x: r.minX, y: r.minY))
        let b = ctx.convertToDeviceSpace(CGPoint(x: r.maxX, y: r.maxY))
        var x0 = a.x.rounded(), x1 = b.x.rounded()
        var y0 = min(a.y, b.y).rounded(), y1 = max(a.y, b.y).rounded()
        if x1 - x0 < 1, r.width > 0 { x1 = x0 + 1 }
        if y1 - y0 < 1, r.height > 0 { y1 = y0 + 1 }
        if x0 > x1 { swap(&x0, &x1) }
        let p0 = ctx.convertToUserSpace(CGPoint(x: x0, y: y0))
        let p1 = ctx.convertToUserSpace(CGPoint(x: x1, y: y1))
        return CGRect(x: min(p0.x, p1.x), y: min(p0.y, p1.y),
                      width: abs(p1.x - p0.x), height: abs(p1.y - p0.y))
    }

    /// Rounded fill on the device grid, matching Chrome's paint-time snapping.
    static func fillRounded(_ ctx: CGContext, _ r: CGRect, _ radius: CGFloat,
                            _ color: NSColor, snap: Bool = true) {
        let box = snap ? snapped(ctx, r) : r
        fill(ctx, roundedPath(box, radius), color)
    }

    /// Pill fill on the device grid; the radius follows the snapped box.
    static func fillPill(_ ctx: CGContext, _ r: CGRect, _ color: NSColor, snap: Bool = true) {
        let box = snap ? snapped(ctx, r) : r
        fill(ctx, pill(box), color)
    }

    static func fillRect(_ ctx: CGContext, _ r: CGRect, _ color: NSColor) {
        ctx.saveGState()
        ctx.setFillColor(color.cgColor); ctx.fill(snapped(ctx, r))
        ctx.restoreGState()
    }

    /// CSS `linear-gradient(to bottom, top → bottom)`.
    static func vGradient(_ ctx: CGContext, _ path: CGPath, _ top: NSColor, _ bottom: NSColor) {
        ctx.saveGState()
        ctx.addPath(path); ctx.clip()
        let cs = CGColorSpaceCreateDeviceRGB()
        let g = CGGradient(colorsSpace: cs, colors: [top.cgColor, bottom.cgColor] as CFArray,
                           locations: [0, 1])!
        let b = path.boundingBox
        ctx.drawLinearGradient(g, start: CGPoint(x: b.midX, y: b.minY),
                               end: CGPoint(x: b.midX, y: b.maxY), options: [])
        ctx.restoreGState()
    }

    // MARK: - border-top only, on a rounded box

    /// `border-top: 1px solid c` with the other three borders at 0 width.
    /// The painted region is outer-rounded-rect minus the padding box, which for
    /// a top-only border is a 1px band that tapers away around the top corners.
    static func borderTop(_ ctx: CGContext, rect: CGRect, radius: CGFloat,
                          width: CGFloat, color: NSColor) {
        let outer = roundedPath(rect, radius)
        // padding box: top inset by `width`; corner radii lose `width` vertically.
        let innerRect = CGRect(x: rect.minX, y: rect.minY + width,
                               width: rect.width, height: rect.height - width)
        let inner = ellipticalCornerPath(innerRect, rx: radius, ryTop: max(0, radius - width), ryBottom: radius)
        ctx.saveGState()
        let p = CGMutablePath()
        p.addPath(outer); p.addPath(inner)
        ctx.addPath(p); ctx.setFillColor(color.cgColor)
        ctx.drawPath(using: .eoFill)
        ctx.restoreGState()
    }

    /// Rounded rect whose top corners are elliptical (rx != ry).
    static func ellipticalCornerPath(_ r: CGRect, rx: CGFloat, ryTop: CGFloat, ryBottom: CGFloat) -> CGPath {
        let p = CGMutablePath()
        let (x0, y0, x1, y1) = (r.minX, r.minY, r.maxX, r.maxY)
        let k: CGFloat = 0.5522847498307936
        p.move(to: CGPoint(x: x0 + rx, y: y0))
        p.addLine(to: CGPoint(x: x1 - rx, y: y0))
        p.addCurve(to: CGPoint(x: x1, y: y0 + ryTop),
                   control1: CGPoint(x: x1 - rx + rx * k, y: y0),
                   control2: CGPoint(x: x1, y: y0 + ryTop - ryTop * k))
        p.addLine(to: CGPoint(x: x1, y: y1 - ryBottom))
        p.addCurve(to: CGPoint(x: x1 - rx, y: y1),
                   control1: CGPoint(x: x1, y: y1 - ryBottom + ryBottom * k),
                   control2: CGPoint(x: x1 - rx + rx * k, y: y1))
        p.addLine(to: CGPoint(x: x0 + rx, y: y1))
        p.addCurve(to: CGPoint(x: x0, y: y1 - ryBottom),
                   control1: CGPoint(x: x0 + rx - rx * k, y: y1),
                   control2: CGPoint(x: x0, y: y1 - ryBottom + ryBottom * k))
        p.addLine(to: CGPoint(x: x0, y: y0 + ryTop))
        p.addCurve(to: CGPoint(x: x0 + rx, y: y0),
                   control1: CGPoint(x: x0, y: y0 + ryTop - ryTop * k),
                   control2: CGPoint(x: x0 + rx - rx * k, y: y0))
        p.closeSubpath()
        return p
    }

    // MARK: - box-shadow

    /// Renders a CSS box-shadow for `path` into the context.
    /// Spread inflates the shape; the blur is a true Gaussian at the calibrated sigma.
    static func shadow(_ ctx: CGContext, rect: CGRect, radius: CGFloat,
                       _ s: CSSShadow, scale: CGFloat) {
        let sigma = T.shadowSigma(cssBlur: s.blur)
        let pad = ceil(sigma * 3) + 2
        let shapeRect = rect.insetBy(dx: -s.spread, dy: -s.spread)
        guard shapeRect.width > 0, shapeRect.height > 0 else { return }
        let boxCSS = shapeRect.insetBy(dx: -pad, dy: -pad)
        let px = CGSize(width: boxCSS.width * scale, height: boxCSS.height * scale)

        guard let buf = CGContext(data: nil, width: Int(px.width.rounded()), height: Int(px.height.rounded()),
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        buf.scaleBy(x: scale, y: scale)
        buf.translateBy(x: -boxCSS.minX, y: -boxCSS.minY)
        let shapeRadius = max(0, radius + s.spread)
        buf.addPath(roundedPath(shapeRect, shapeRadius))
        buf.setFillColor(NSColor.black.cgColor)
        buf.fillPath()
        guard let mask = buf.makeImage() else { return }

        let ci = CIImage(cgImage: mask)
        let blurred: CIImage
        if sigma > 0.01 {
            let f = CIFilter(name: "CIGaussianBlur")!
            f.setValue(ci, forKey: kCIInputImageKey)
            f.setValue(sigma * scale, forKey: kCIInputRadiusKey)
            blurred = (f.outputImage ?? ci).cropped(to: ci.extent)
        } else {
            blurred = ci
        }
        guard let out = CIContext(options: [.workingColorSpace: NSNull()])
            .createCGImage(blurred, from: ci.extent) else { return }

        ctx.saveGState()
        ctx.setAlpha(s.color.alphaComponent)
        ctx.clip(to: boxCSS.offsetBy(dx: s.dx, dy: s.dy), mask: out)
        ctx.setFillColor(s.color.withAlphaComponent(1).cgColor)
        ctx.fill(boxCSS.offsetBy(dx: s.dx, dy: s.dy))
        ctx.restoreGState()
    }

    // MARK: - backdrop-filter: blur()

    /// Blur of the page content behind `rect`, clipped to `path`.
    /// Chrome clips the backdrop to the element's border box **first** and then
    /// filters with edge-pixel duplication, so content outside the element does
    /// not bleed inwards. Measured with tools/calib3.mjs; sampling beyond the
    /// element instead put ~20% of the residual on the panel edges.
    static func backdropBlur(_ ctx: CGContext, backdrop: CGImage, backdropOriginCSS: CGPoint,
                             scale: CGFloat, rect: CGRect, path: CGPath, sigma: CGFloat) {
        let sx = (rect.minX - backdropOriginCSS.x) * scale
        let sy = (rect.minY - backdropOriginCSS.y) * scale
        let crop = CGRect(x: sx.rounded(), y: sy.rounded(),
                          width: (rect.width * scale).rounded(),
                          height: (rect.height * scale).rounded())
            .intersection(CGRect(x: 0, y: 0, width: backdrop.width, height: backdrop.height))
        guard !crop.isNull, crop.width > 1, crop.height > 1,
              let sub = backdrop.cropping(to: crop) else { return }

        let extent = CGRect(x: 0, y: 0, width: crop.width, height: crop.height)
        let ci = CIImage(cgImage: sub).clampedToExtent()      // edge duplication
        let f = CIFilter(name: "CIGaussianBlur")!
        f.setValue(ci, forKey: kCIInputImageKey)
        f.setValue(sigma * scale, forKey: kCIInputRadiusKey)
        let blurred = (f.outputImage ?? ci).cropped(to: extent)
        guard let out = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])
            .createCGImage(blurred, from: extent) else { return }

        let placed = CGRect(x: backdropOriginCSS.x + crop.minX / scale,
                            y: backdropOriginCSS.y + crop.minY / scale,
                            width: crop.width / scale, height: crop.height / scale)
        ctx.saveGState()
        ctx.addPath(path); ctx.clip()
        image(ctx, out, in: placed)
        ctx.restoreGState()
    }

    /// CSS `mask-image: linear-gradient(to bottom, black, transparent)`.
    static func withVerticalFadeMask(_ ctx: CGContext, rect: CGRect, _ body: (CGContext) -> Void) {
        let scale: CGFloat = 4
        guard let buf = CGContext(data: nil, width: Int(rect.width * scale), height: Int(rect.height * scale),
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceGray(),
                                  bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return }
        let cs = CGColorSpaceCreateDeviceGray()
        // clip(to:mask:) with a grayscale image treats 0 as "paint", 1 as "block",
        // so the CSS mask (opaque at top -> transparent at bottom) inverts to
        // black at the top of the image and white at the bottom.
        let g = CGGradient(colorsSpace: cs,
                           colors: [NSColor.black.cgColor, NSColor.white.cgColor] as CFArray,
                           locations: [0, 1])!
        buf.drawLinearGradient(g, start: CGPoint(x: 0, y: buf.height),
                               end: CGPoint(x: 0, y: 0), options: [])
        guard let mask = buf.makeImage() else { return }
        ctx.saveGState()
        ctx.clip(to: rect, mask: mask)
        body(ctx)
        ctx.restoreGState()
    }
}
