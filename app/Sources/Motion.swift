import AppKit

/// A cubic-bézier timing function, same parameterisation as CSS.
struct Easing {
    let x1, y1, x2, y2: CGFloat
    static let easeOut   = Easing(x1: 0,   y1: 0,  x2: 0.2, y2: 1)   // cubic-bezier(0,0,.2,1)
    static let easeInOut = Easing(x1: 0.4, y1: 0,  x2: 0.2, y2: 1)   // Tailwind default
    static let knob      = Easing(x1: 0.25, y1: 0.1, x2: 0.25, y2: 1)
    static let linear    = Easing(x1: 0,   y1: 0,  x2: 1,   y2: 1)

    func callAsFunction(_ t: CGFloat) -> CGFloat {
        if t <= 0 { return 0 }; if t >= 1 { return 1 }
        // Newton solve for the parametric u where bezierX(u) == t
        func bx(_ u: CGFloat) -> CGFloat {
            let v = 1 - u
            return 3*v*v*u*x1 + 3*v*u*u*x2 + u*u*u
        }
        func by(_ u: CGFloat) -> CGFloat {
            let v = 1 - u
            return 3*v*v*u*y1 + 3*v*u*u*y2 + u*u*u
        }
        var u = t
        for _ in 0..<8 {
            let e = bx(u) - t
            if abs(e) < 1e-6 { break }
            let d = 3*(1-u)*(1-u)*x1 + 6*(1-u)*u*(x2-x1) + 3*u*u*(1-x2)
            if abs(d) < 1e-6 { break }
            u -= e/d
            u = max(0, min(1, u))
        }
        return by(u)
    }
}

/// One animatable scalar with CSS transition semantics.
struct Anim {
    var value: CGFloat
    var from: CGFloat
    var target: CGFloat
    var elapsed: CGFloat = 0
    var duration: CGFloat
    var delay: CGFloat = 0
    var easing: Easing

    init(_ v: CGFloat, duration: CGFloat, easing: Easing = .easeOut, delay: CGFloat = 0) {
        value = v; from = v; target = v
        self.duration = duration; self.easing = easing; self.delay = delay
    }

    var isRunning: Bool { elapsed < delay + duration && from != target }

    mutating func set(_ t: CGFloat) {
        guard t != target else { return }
        from = value; target = t; elapsed = 0
        if Motion.reduced { value = t; from = t; elapsed = delay + duration }
    }

    /// Jump with no transition — what removing the transition class does.
    mutating func snapTo(_ t: CGFloat) {
        value = t; from = t; target = t; elapsed = delay + duration
    }

    mutating func tick(_ dt: CGFloat) {
        guard from != target else { value = target; return }
        elapsed += dt
        let t = max(0, elapsed - delay)
        if t >= duration { value = target; from = target; return }
        value = from + (target - from) * easing(t / duration)
    }
}

enum Motion {
    /// Forced on by --motion's reduced-motion check so the path is testable
    /// without changing the tester's system settings.
    static var forceInstant = false

    /// Honour the system Reduce Motion setting; transitions collapse to 0ms.
    static var reduced: Bool {
        forceInstant || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
}
