import AppKit

/// Minimal SVG path-data parser. The vector artwork (play glyph, checkmark,
/// keycap swatch, ellipsis) is reused from the reference as artwork, the same
/// way a clone reuses a bitmap asset.
enum SVGPath {

    static func path(_ d: String, viewBox: CGFloat, size: CGFloat,
                     origin: CGPoint = .zero) -> CGPath {
        let p = parse(d)
        let s = size / viewBox
        var t = CGAffineTransform(translationX: origin.x, y: origin.y).scaledBy(x: s, y: s)
        return p.copy(using: &t) ?? p
    }

    static func parse(_ d: String) -> CGPath {
        let p = CGMutablePath()
        var i = d.startIndex
        var cur = CGPoint.zero, start = CGPoint.zero
        var lastCtrl: CGPoint? = nil, lastQCtrl: CGPoint? = nil
        var cmd: Character = "M"

        func skipSep() {
            while i < d.endIndex, d[i] == " " || d[i] == "," || d[i] == "\n" || d[i] == "\t" || d[i] == "\r" {
                i = d.index(after: i)
            }
        }
        func num() -> CGFloat {
            skipSep()
            var s = ""
            if i < d.endIndex, d[i] == "-" || d[i] == "+" { s.append(d[i]); i = d.index(after: i) }
            var seenDot = false, seenExp = false
            while i < d.endIndex {
                let c = d[i]
                if c.isNumber { s.append(c) }
                else if c == "." && !seenDot && !seenExp { seenDot = true; s.append(c) }
                else if (c == "e" || c == "E") && !seenExp { seenExp = true; s.append(c) }
                else if (c == "-" || c == "+") && (s.last == "e" || s.last == "E") { s.append(c) }
                else { break }
                i = d.index(after: i)
            }
            return CGFloat(Double(s) ?? 0)
        }
        func flag() -> Bool {
            skipSep()
            guard i < d.endIndex else { return false }
            let v = d[i] == "1"; i = d.index(after: i); return v
        }
        func moreArgs() -> Bool {
            skipSep()
            guard i < d.endIndex else { return false }
            let c = d[i]
            return c.isNumber || c == "-" || c == "+" || c == "."
        }

        while i < d.endIndex {
            skipSep()
            guard i < d.endIndex else { break }
            if d[i].isLetter { cmd = d[i]; i = d.index(after: i) }
            let rel = cmd.isLowercase
            let C = Character(cmd.uppercased())

            switch C {
            case "M":
                var first = true
                repeat {
                    var pt = CGPoint(x: num(), y: num())
                    if rel { pt = CGPoint(x: cur.x + pt.x, y: cur.y + pt.y) }
                    if first { p.move(to: pt); start = pt; first = false } else { p.addLine(to: pt) }
                    cur = pt
                } while moreArgs()
                lastCtrl = nil; lastQCtrl = nil
            case "L":
                repeat {
                    var pt = CGPoint(x: num(), y: num())
                    if rel { pt = CGPoint(x: cur.x + pt.x, y: cur.y + pt.y) }
                    p.addLine(to: pt); cur = pt
                } while moreArgs()
                lastCtrl = nil; lastQCtrl = nil
            case "H":
                repeat {
                    let v = num(); let x = rel ? cur.x + v : v
                    cur = CGPoint(x: x, y: cur.y); p.addLine(to: cur)
                } while moreArgs()
                lastCtrl = nil; lastQCtrl = nil
            case "V":
                repeat {
                    let v = num(); let y = rel ? cur.y + v : v
                    cur = CGPoint(x: cur.x, y: y); p.addLine(to: cur)
                } while moreArgs()
                lastCtrl = nil; lastQCtrl = nil
            case "C":
                repeat {
                    var c1 = CGPoint(x: num(), y: num())
                    var c2 = CGPoint(x: num(), y: num())
                    var pt = CGPoint(x: num(), y: num())
                    if rel {
                        c1 = CGPoint(x: cur.x + c1.x, y: cur.y + c1.y)
                        c2 = CGPoint(x: cur.x + c2.x, y: cur.y + c2.y)
                        pt = CGPoint(x: cur.x + pt.x, y: cur.y + pt.y)
                    }
                    p.addCurve(to: pt, control1: c1, control2: c2)
                    lastCtrl = c2; lastQCtrl = nil; cur = pt
                } while moreArgs()
            case "S":
                repeat {
                    var c2 = CGPoint(x: num(), y: num())
                    var pt = CGPoint(x: num(), y: num())
                    if rel {
                        c2 = CGPoint(x: cur.x + c2.x, y: cur.y + c2.y)
                        pt = CGPoint(x: cur.x + pt.x, y: cur.y + pt.y)
                    }
                    let c1 = lastCtrl.map { CGPoint(x: 2*cur.x - $0.x, y: 2*cur.y - $0.y) } ?? cur
                    p.addCurve(to: pt, control1: c1, control2: c2)
                    lastCtrl = c2; lastQCtrl = nil; cur = pt
                } while moreArgs()
            case "Q":
                repeat {
                    var c = CGPoint(x: num(), y: num())
                    var pt = CGPoint(x: num(), y: num())
                    if rel {
                        c = CGPoint(x: cur.x + c.x, y: cur.y + c.y)
                        pt = CGPoint(x: cur.x + pt.x, y: cur.y + pt.y)
                    }
                    p.addQuadCurve(to: pt, control: c)
                    lastQCtrl = c; lastCtrl = nil; cur = pt
                } while moreArgs()
            case "T":
                repeat {
                    var pt = CGPoint(x: num(), y: num())
                    if rel { pt = CGPoint(x: cur.x + pt.x, y: cur.y + pt.y) }
                    let c = lastQCtrl.map { CGPoint(x: 2*cur.x - $0.x, y: 2*cur.y - $0.y) } ?? cur
                    p.addQuadCurve(to: pt, control: c)
                    lastQCtrl = c; lastCtrl = nil; cur = pt
                } while moreArgs()
            case "A":
                repeat {
                    let rx = num(), ry = num(), rot = num()
                    let large = flag(), sweep = flag()
                    var pt = CGPoint(x: num(), y: num())
                    if rel { pt = CGPoint(x: cur.x + pt.x, y: cur.y + pt.y) }
                    addArc(p, from: cur, to: pt, rx: rx, ry: ry, rotDeg: rot, large: large, sweep: sweep)
                    cur = pt; lastCtrl = nil; lastQCtrl = nil
                } while moreArgs()
            case "Z":
                p.closeSubpath(); cur = start; lastCtrl = nil; lastQCtrl = nil
            default:
                i = d.index(after: i)
            }
        }
        return p
    }

    /// SVG endpoint-parameterised elliptical arc -> centre parameterisation -> béziers.
    private static func addArc(_ p: CGMutablePath, from p0: CGPoint, to p1: CGPoint,
                               rx: CGFloat, ry: CGFloat, rotDeg: CGFloat,
                               large: Bool, sweep: Bool) {
        if rx == 0 || ry == 0 { p.addLine(to: p1); return }
        var rx = abs(rx), ry = abs(ry)
        let phi = rotDeg * .pi / 180
        let dx2 = (p0.x - p1.x) / 2, dy2 = (p0.y - p1.y) / 2
        let x1 =  cos(phi) * dx2 + sin(phi) * dy2
        let y1 = -sin(phi) * dx2 + cos(phi) * dy2
        let lam = (x1*x1)/(rx*rx) + (y1*y1)/(ry*ry)
        if lam > 1 { let s = sqrt(lam); rx *= s; ry *= s }
        var num = rx*rx*ry*ry - rx*rx*y1*y1 - ry*ry*x1*x1
        let den = rx*rx*y1*y1 + ry*ry*x1*x1
        if num < 0 { num = 0 }
        var co = sqrt(num / max(den, .leastNonzeroMagnitude))
        if large == sweep { co = -co }
        let cx1 =  co * rx * y1 / ry
        let cy1 = -co * ry * x1 / rx
        let cx = cos(phi)*cx1 - sin(phi)*cy1 + (p0.x + p1.x)/2
        let cy = sin(phi)*cx1 + cos(phi)*cy1 + (p0.y + p1.y)/2
        func ang(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
            let dot = ux*vx + uy*vy
            let len = sqrt(ux*ux+uy*uy) * sqrt(vx*vx+vy*vy)
            var a = acos(max(-1, min(1, dot/len)))
            if ux*vy - uy*vx < 0 { a = -a }
            return a
        }
        let t1 = ang(1, 0, (x1-cx1)/rx, (y1-cy1)/ry)
        var dt = ang((x1-cx1)/rx, (y1-cy1)/ry, (-x1-cx1)/rx, (-y1-cy1)/ry)
        if !sweep && dt > 0 { dt -= 2 * .pi }
        if sweep && dt < 0 { dt += 2 * .pi }

        let segs = Int(ceil(abs(dt) / (.pi / 2)))
        let d = dt / CGFloat(max(segs, 1))
        let k = 4.0 / 3.0 * tan(d / 4)
        var th = t1
        for _ in 0..<max(segs, 1) {
            let c1 = CGPoint(x: cos(th) - k * sin(th), y: sin(th) + k * cos(th))
            let e  = CGPoint(x: cos(th + d), y: sin(th + d))
            let c2 = CGPoint(x: e.x + k * sin(th + d), y: e.y - k * cos(th + d))
            func map(_ q: CGPoint) -> CGPoint {
                CGPoint(x: cos(phi)*rx*q.x - sin(phi)*ry*q.y + cx,
                        y: sin(phi)*rx*q.x + cos(phi)*ry*q.y + cy)
            }
            p.addCurve(to: map(e), control1: map(c1), control2: map(c2))
            th += d
        }
    }
}

/// The reference's vector artwork, verbatim.
enum Art {
    static let play = "M6.40625 23.8633C6.875 23.8633 7.27344 23.6758 7.74219 23.4062L21.4062 15.5078C22.3789 14.9336 22.7188 14.5586 22.7188 13.9375C22.7188 13.3164 22.3789 12.9414 21.4062 12.3789L7.74219 4.46875C7.27344 4.19922 6.875 4.02344 6.40625 4.02344C5.53906 4.02344 5 4.67969 5 5.69922V22.1758C5 23.1953 5.53906 23.8633 6.40625 23.8633Z"
    static let check = "M11.618 25.327q-1.294 0-2.127-.967l-6.037-7.108q-.39-.446-.54-.846t-.15-.854q0-1.011.68-1.68.68-.671 1.72-.67 1.117 0 1.853.86l4.554 5.442L20.648 5.25q.435-.669.918-.948.485-.278 1.185-.278 1.029 0 1.722.666.693.665.693 1.667 0 .364-.125.757a3 3 0 0 1-.393.793L13.825 24.213q-.747 1.114-2.207 1.114"
    /// Stop square shown while a switch is previewing.
    static let stop = "M4 20.5117C4 22.1406 4.98438 23.1016 6.625 23.1016H20.4648C22.1172 23.1016 23.0898 22.1406 23.0898 20.5117V6.58984C23.0898 4.96094 22.1172 4 20.4648 4H6.625C4.98438 4 4 4.96094 4 6.58984V20.5117Z"
    static let ellipsis = "M4.5 12a1.5 1.5 0 113 0 1.5 1.5 0 01-3 0zm6 0a1.5 1.5 0 113 0 1.5 1.5 0 01-3 0zm6 0a1.5 1.5 0 113 0 1.5 1.5 0 01-3 0z"
    /// 26×26 keycap swatch: solid square with a plus knocked out (nonzero winding).
    static let swatch = "M26 0v26H0V0h26ZM13 7l-.117.007A1 1 0 0 0 12 8l-.001 3.999L8 12a1 1 0 0 0-1 1l.007.117A1 1 0 0 0 8 14l3.999-.001L12 18a1 1 0 0 0 1 1l.117-.007A1 1 0 0 0 14 18l-.001-4.001L18 14a1 1 0 0 0 1-1l-.007-.117A1 1 0 0 0 18 12l-4.001-.001L14 8a1 1 0 0 0-1-1Z"
    static let apple = "M19.374 7.995c-.114.088-2.11 1.213-2.11 3.716 0 2.894 2.54 3.919 2.616 3.945-.011.062-.403 1.402-1.34 2.768-.834 1.2-1.707 2.4-3.033 2.4s-1.668-.77-3.199-.77c-1.492 0-2.022.796-3.236.796s-2.06-1.112-3.033-2.478C4.91 16.77 4 14.278 4 11.914 4 8.122 6.466 6.11 8.892 6.11c1.29 0 2.365.848 3.174.848.77 0 1.973-.898 3.439-.898.556 0 2.553.05 3.868 1.935M8.07 5.213h1.586v-.98c0-1.987 1.272-2.706 2.41-2.706s2.42.72 2.42 2.706v.98h1.584v-.807C16.07 1.442 14.13 0 12.066 0 10.009 0 8.07 1.442 8.07 4.406z"
}
