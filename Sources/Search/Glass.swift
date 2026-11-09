import SwiftUI
import AppKit

// The frame is glass, and each space lights it.
//
// With the tabs down the side, everything around the page's card — the
// column, the gaps, the band the window's buttons sit in — is one pane of
// frosted glass with the desktop behind it. A space's colour is not painted
// on that pane: it is a lamp at the column's foot, where the spaces are
// chosen, and its light rises through the glass and thins out toward the far
// corner, which answers with a second, fainter hue. Change space and the
// lamp changes; nothing else in the frame has a colour of its own.
//
// The tab you are on is a brighter piece of the same glass (see Lozenge),
// and what floats over the page is Apple's own (see glassPanel).

/// A space's light: the hue at the lamp, the hue at the far corner, and how
/// much colour the two carry. A fixed set, each tuned to sit beside any page
/// all day in a light window and in a dark one; a space keeps its theme by
/// `id` (see Space.theme).
struct Theme: Identifiable, Equatable {
    let id: String
    let name: String
    /// Hues, in degrees round OKLCH's wheel: 30 is red-orange, 150 green,
    /// 260 blue, 330 pink.
    let near: Double
    let far: Double
    /// 1 for a full theme; less for the quiet ones, down to Graphite, which
    /// is all but grey.
    let strength: Double

    static let all: [Theme] = [
        Theme(id: "dawn", name: "Dawn", near: 55, far: 8, strength: 1),
        Theme(id: "ember", name: "Ember", near: 30, far: 72, strength: 1),
        Theme(id: "sand", name: "Sand", near: 85, far: 58, strength: 0.5),
        Theme(id: "moss", name: "Moss", near: 152, far: 118, strength: 0.9),
        Theme(id: "tide", name: "Tide", near: 205, far: 256, strength: 1),
        Theme(id: "glacier", name: "Glacier", near: 236, far: 196, strength: 0.55),
        Theme(id: "iris", name: "Iris", near: 296, far: 340, strength: 1),
        Theme(id: "graphite", name: "Graphite", near: 262, far: 262, strength: 0.08),
    ]

    static func named(_ id: String?) -> Theme? {
        id.flatMap { id in all.first { $0.id == id } }
    }

    /// What a space wears before anyone chose: Dawn for the first, and for
    /// any other one of the rest, always the same one for the same space.
    static func standing(for space: Space) -> Theme {
        if space.isFirst { return all[0] }
        return all[1 + Int(space.id.uuid.15) % (all.count - 1)]
    }

    /// The theme's colours in a light window or a dark one.
    func lit(dark: Bool) -> Lit {
        let k = strength
        return dark
            ? Lit(near: Theme.oklch(0.38, 0.08 * k, near),
                  far: Theme.oklch(0.32, 0.062 * k, far),
                  hot: Theme.oklch(0.41, 0.10 * k, near).opacity(0.28),
                  disc: (Theme.oklch(0.66, 0.16 * k, near), Theme.oklch(0.58, 0.15 * k, far)),
                  accent: Theme.oklch(0.8, 0.13 * k, near))
            : Lit(near: Theme.oklch(0.89, 0.07 * k, near),
                  far: Theme.oklch(0.925, 0.05 * k, far),
                  hot: Theme.oklch(0.92, 0.0875 * k, near).opacity(0.34),
                  disc: (Theme.oklch(0.66, 0.16 * k, near), Theme.oklch(0.58, 0.15 * k, far)),
                  accent: Theme.oklch(0.56, 0.17 * k, near))
    }

    struct Lit {
        /// The lamp's light and the far corner's, at full strength; the
        /// frame thins them (see FrameGlow).
        let near: Color
        let far: Color
        /// Right at the lamp.
        let hot: Color
        /// The theme at full strength, for where it is chosen from a list
        /// of themes: a small disc in a menu or in Settings.
        let disc: (Color, Color)
        /// For the few small things that take the space's colour: the icon
        /// of the space you are in, among the others at the column's foot.
        let accent: Color
    }

    /// A colour by lightness, chroma and hue. OKLCH rather than HSB so that
    /// every theme is as light as every other: at one lightness HSB's yellow
    /// glares and its blue goes dark, and a set tuned by eye in one hue has
    /// to be tuned again in the next. Out of sRGB's reach, a channel is cut
    /// off at its end; at these chromas few are.
    static func oklch(_ l: Double, _ c: Double, _ h: Double) -> Color {
        let a = c * cos(h * .pi / 180), b = c * sin(h * .pi / 180)
        let l_ = l + 0.3963377774 * a + 0.2158037573 * b
        let m_ = l - 0.1055613458 * a - 0.0638541728 * b
        let s_ = l - 0.0894841775 * a - 1.2914855480 * b
        let l3 = l_ * l_ * l_, m3 = m_ * m_ * m_, s3 = s_ * s_ * s_
        func gamma(_ x: Double) -> Double {
            let x = min(1, max(0, x))
            return x <= 0.0031308 ? 12.92 * x : 1.055 * pow(x, 1 / 2.4) - 0.055
        }
        return Color(.sRGB,
                     red: gamma(4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3),
                     green: gamma(-1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3),
                     blue: gamma(-0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3),
                     opacity: 1)
    }
}

extension Space {
    /// The theme it wears: its own, or the one it stands in until it has one.
    var light: Theme { Theme.named(theme) ?? Theme.standing(for: self) }
}

// MARK: - the frame

/// The window's width, for the column's piece of the frame's light to line
/// up with the window's (see FrameGlass). Nothing, before the window is up.
private struct WindowWidthKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var windowWidth: CGFloat {
        get { self[WindowWidthKey.self] }
        set { self[WindowWidthKey.self] = newValue }
    }
}

/// The frosted pane and the space's light in it.
///
/// Drawn twice: once under everything, the window's whole size, and once by
/// the column as its own ground. The column needs one of its own because it
/// travels — folded away it comes out over the page, and for a moment after
/// ⌘S it slides in over a page that has not yet made room — and with no
/// ground it would be titles lying on a web page. Its piece is cut from the
/// same picture, at the place the column rests in, so that beside the page
/// the two are one pane with no seam.
struct FrameGlass: View {
    let theme: Theme
    /// The lamp's side: the column's.
    var onRight = false
    /// The column's width, when this is its piece; nil for the window's.
    var column: CGFloat? = nil

    @Environment(\.windowWidth) private var windowWidth

    var body: some View {
        ZStack {
            Frost()
            GeometryReader { geo in
                let whole = CGSize(width: max(windowWidth, geo.size.width), height: geo.size.height)
                FrameGlow(theme: theme, onRight: onRight)
                    .frame(width: whole.width, height: whole.height)
                    // The column's piece: the picture's near end on the left,
                    // its far end when the column is on the right.
                    .frame(width: geo.size.width, height: geo.size.height,
                           alignment: column != nil && onRight ? .trailing : .leading)
                    .clipped()
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The light alone: a wash the frame's whole size, the lamp's light from the
/// near bottom corner, the answer from the far top one, and the lamp's own
/// warmth right where the spaces are.
private struct FrameGlow: View {
    let theme: Theme
    let onRight: Bool

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let lit = theme.lit(dark: scheme == .dark)
        let near: UnitPoint = onRight ? .bottomTrailing : .bottomLeading
        let far: UnitPoint = onRight ? .topLeading : .topTrailing
        ZStack {
            LinearGradient(colors: [lit.near.opacity(0.22), lit.far.opacity(0.18)],
                           startPoint: UnitPoint(x: onRight ? 0.7 : 0.3, y: 1),
                           endPoint: UnitPoint(x: onRight ? 0.3 : 0.7, y: 0))
            EllipticalGradient(colors: [lit.near.opacity(0.46), lit.near.opacity(0)],
                               center: near, startRadiusFraction: 0, endRadiusFraction: 0.62)
            EllipticalGradient(colors: [lit.far.opacity(0.44), lit.far.opacity(0)],
                               center: far, startRadiusFraction: 0, endRadiusFraction: 0.6)
            // The lamp: a fixed size whatever the window's, since the spaces
            // it lights are.
            EllipticalGradient(colors: [lit.hot, lit.hot.opacity(0)],
                               center: .center, startRadiusFraction: 0, endRadiusFraction: 0.36)
                .frame(width: 420, height: 340)
                .offset(x: onRight ? 144 : -144, y: 146)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: near == .bottomLeading ? .bottomLeading : .bottomTrailing)
        }
        // One space's light giving way to the next's.
        .animation(Motion.reduced ? nil : .easeInOut(duration: 0.75), value: theme)
    }
}

/// The frost: what is behind the window, blurred, as a sidebar of the Mac's
/// own is. Kept lit while the window is behind another: a browser is read
/// from behind as often as from in front, and a frame that turned to flat
/// grey each time would be the one thing on screen that changed.
private struct Frost: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

// MARK: - pieces of glass

/// The tab you are on, on the frame: not a grey laid over it but a brighter
/// piece of the same glass, with the light catching its top edge and a
/// little shadow under it. On white (the strip, a panel) it is the grey it
/// always was.
struct Lozenge: View {
    @Environment(\.greys) private var greys
    @Environment(\.colorScheme) private var scheme
    var radius: CGFloat = Metrics.rowRadius
    /// The live pin among the squares, which wears its own grey on white.
    var pin = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if greys.glass {
            let dark = scheme == .dark
            shape
                .fill(greys.wash)
                .overlay {
                    shape.strokeBorder(
                        LinearGradient(colors: [.white.opacity(dark ? 0.24 : 0.95), .white.opacity(dark ? 0.07 : 0.55)],
                                       startPoint: .top, endPoint: .bottom),
                        lineWidth: 0.75)
                }
                .shadow(color: .black.opacity(dark ? 0.32 : 0.11), radius: 4, y: 2)
        } else {
            shape.fill(pin ? greys.pinLive : greys.wash)
        }
    }
}

extension View {
    /// What floats over the page — the address field, a card of choices — as
    /// a piece of Apple's glass, which bends what is under it.
    func glassPanel(radius: CGFloat) -> some View {
        glassEffect(.regular, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}
