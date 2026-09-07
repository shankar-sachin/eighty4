import SwiftUI

/// One-level Geometry Dash clone: the cube auto-runs, ↑ or enter jumps.
final class GeoDashGame: Game {
    struct Obstacle {
        let x: Double
        let w: Double
        let h: Double
        let spike: Bool
    }

    let title = "GEODASH"

    private let floorY = 172.0
    private let playerX = 56.0
    private let cube = 18.0
    private let speed = 150.0
    private let gravity = 1150.0
    private let jumpV = -370.0
    let levelLength = 4600.0

    private(set) var scroll = 0.0
    private var y = 172.0        // cube bottom
    private var vy = 0.0
    private var grounded = true
    private var jumpQueued = false
    private var last: TimeInterval?
    private var deadUntil: TimeInterval?
    private(set) var attempts = 1
    private(set) var won = false
    private var rotation = 0.0

    let obstacles: [Obstacle] = {
        var o: [Obstacle] = []
        func spike(_ x: Double) { o.append(Obstacle(x: x, w: 18, h: 18, spike: true)) }
        func block(_ x: Double, _ h: Double = 36, _ w: Double = 36) { o.append(Obstacle(x: x, w: w, h: h, spike: false)) }
        spike(420); spike(640); spike(658)
        block(900); spike(1000)
        spike(1200); spike(1218); spike(1236)
        block(1450, 36); block(1486, 72)
        spike(1780); block(1880, 36, 72); spike(1952)
        spike(2200); spike(2218)
        block(2400); spike(2436); block(2500, 36)
        spike(2750); spike(2768); spike(2786)
        block(3000, 36, 108); spike(3160)
        spike(3400); block(3480, 36); spike(3516); spike(3534)
        spike(3800); spike(3818); block(3900, 36, 72); spike(4030); spike(4048)
        spike(4300); spike(4318); spike(4336)
        return o
    }()

    var progress: Double { min(1, scroll / levelLength) }

    func press(_ key: KeyID) {
        if key == .up || key == .enter { jumpQueued = true }
    }

    func update(now: TimeInterval) {
        guard let l = last else { last = now; return }
        let dt = min(now - l, 1.0 / 30)
        last = now
        if won { return }
        if let d = deadUntil {
            if now >= d { restart() }
            return
        }
        if jumpQueued {
            jumpQueued = false
            if grounded { vy = jumpV; grounded = false }
        }
        scroll += speed * dt
        vy += gravity * dt
        let prevBottom = y
        y += vy * dt
        grounded = false
        if !grounded { rotation += dt * 4 }

        if y >= floorY { y = floorY; vy = 0; grounded = true }

        let px0 = playerX + 3, px1 = playerX + cube - 3
        let top = y - cube
        for o in obstacles {
            let ox0 = o.x - scroll, ox1 = ox0 + o.w
            let oTop = floorY - o.h
            if px1 <= ox0 || px0 >= ox1 { continue }
            if o.spike {
                // Triangle hitbox: only the middle third near the tip counts as lethal.
                let centerX = (ox0 + ox1) / 2
                let halfWidthAtBottom = o.w / 2
                let lethalTop = oTop + o.h * 0.3
                if y > lethalTop && abs((playerX + cube / 2) - centerX) < halfWidthAtBottom + cube / 2 - 6 {
                    die(now); return
                }
            } else {
                if prevBottom <= oTop + 2 && y >= oTop {
                    y = oTop; vy = 0; grounded = true
                } else if y > oTop + 2 && top < floorY {
                    die(now); return
                }
            }
        }
        if scroll > levelLength { won = true }
    }

    private func die(_ now: TimeInterval) {
        deadUntil = now + 0.9
    }

    private func restart() {
        scroll = 0; y = floorY; vy = 0; grounded = true
        deadUntil = nil
        attempts += 1
        rotation = 0
    }

    func draw(_ ctx: inout GraphicsContext, size: CGSize) {
        // Background
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
            Gradient(colors: [Color(red: 0.16, green: 0.05, blue: 0.45), Color(red: 0.45, green: 0.1, blue: 0.6)]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
        // Ground
        ctx.fill(Path(CGRect(x: 0, y: floorY, width: size.width, height: size.height - floorY)),
                 with: .color(Color(red: 0.12, green: 0.03, blue: 0.3)))
        ctx.stroke(Path { p in p.move(to: CGPoint(x: 0, y: floorY)); p.addLine(to: CGPoint(x: size.width, y: floorY)) },
                   with: .color(.white), lineWidth: 1.5)
        // Ground stripes for motion
        let stripeOffset = CGFloat(scroll.truncatingRemainder(dividingBy: 40))
        for i in 0..<10 {
            let x = CGFloat(i) * 40 - stripeOffset
            ctx.fill(Path(CGRect(x: x, y: floorY + 8, width: 20, height: 2)), with: .color(.white.opacity(0.15)))
        }
        // Obstacles
        for o in obstacles {
            let x = CGFloat(o.x - scroll)
            if x > size.width || x + CGFloat(o.w) < 0 { continue }
            let top = CGFloat(floorY - o.h)
            if o.spike {
                var p = Path()
                p.move(to: CGPoint(x: x, y: floorY))
                p.addLine(to: CGPoint(x: x + CGFloat(o.w) / 2, y: top))
                p.addLine(to: CGPoint(x: x + CGFloat(o.w), y: floorY))
                p.closeSubpath()
                ctx.fill(p, with: .color(.black))
                ctx.stroke(p, with: .color(.white), lineWidth: 1.5)
            } else {
                let r = CGRect(x: x, y: top, width: o.w, height: o.h)
                ctx.fill(Path(r), with: .color(.black))
                ctx.stroke(Path(r), with: .color(.white), lineWidth: 1.5)
                ctx.stroke(Path(r.insetBy(dx: 6, dy: 6)), with: .color(.white.opacity(0.4)), lineWidth: 1)
            }
        }
        // Player
        if deadUntil == nil {
            let r = CGRect(x: playerX, y: y - cube, width: cube, height: cube)
            var c = ctx
            c.translateBy(x: r.midX, y: r.midY)
            if !grounded { c.rotate(by: .radians(rotation)) }
            let local = CGRect(x: -cube / 2, y: -cube / 2, width: cube, height: cube)
            c.fill(Path(local), with: .color(Color(red: 1, green: 0.85, blue: 0.1)))
            c.stroke(Path(local), with: .color(.black), lineWidth: 2)
            c.fill(Path(CGRect(x: -5, y: -5, width: 4, height: 4)), with: .color(.black))
            c.fill(Path(CGRect(x: 1, y: -5, width: 4, height: 4)), with: .color(.black))
            c.fill(Path(CGRect(x: -4, y: 2, width: 8, height: 2)), with: .color(.black))
        } else {
            // death burst
            for i in 0..<8 {
                let a = Double(i) / 8 * 2 * .pi
                let p = CGPoint(x: playerX + cube / 2 + cos(a) * 14, y: y - cube / 2 + sin(a) * 14)
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - 2, y: p.y - 2, width: 4, height: 4)), with: .color(.yellow))
            }
        }
        // Progress bar
        let barW = size.width - 80
        ctx.fill(Path(roundedRect: CGRect(x: 40, y: 6, width: barW, height: 6), cornerRadius: 3), with: .color(.black.opacity(0.5)))
        ctx.fill(Path(roundedRect: CGRect(x: 40, y: 6, width: barW * progress, height: 6), cornerRadius: 3), with: .color(.green))
        ctx.drawText("\(Int(progress * 100))%", at: CGPoint(x: size.width - 36, y: 3), size: 10)
        ctx.drawText("Attempt \(attempts)", at: CGPoint(x: size.width / 2, y: 22), size: 12, anchor: .top)
        if won {
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black.opacity(0.45)))
            ctx.drawText("LEVEL COMPLETE!", at: CGPoint(x: size.width / 2, y: size.height / 2 - 14), size: 20, anchor: .center)
            ctx.drawText("100%   press CLEAR", at: CGPoint(x: size.width / 2, y: size.height / 2 + 12), size: 12, anchor: .center)
        }
    }
}
