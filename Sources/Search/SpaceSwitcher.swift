import SwiftUI
import AppKit

/// The spaces at the column's foot, side by side in a small capsule of
/// glass, each as its icon. The one you are in is a lit piece of that glass,
/// its icon in its theme's colour and its name beside it; the light in the
/// frame rises from where they sit (see Glass.swift). A click on another goes there; a
/// click on the one you are in, or a right-click anywhere, opens the spaces'
/// menu, as the single icon did (see SpaceDot, which still stands in for
/// this where there are more spaces than fit, across the top, and in the
/// column of icons).
struct SpaceSwitcher: View {
    @ObservedObject var browser: Browser
    @Environment(\.colorScheme) private var scheme
    @Namespace private var lamp

    /// The capsule's height: what the column's foot is as tall as.
    static let height: CGFloat = 28
    fileprivate static let bead: CGFloat = 22
    /// One that isn't lit: its icon and the air round it.
    fileprivate static let slot: CGFloat = 24
    fileprivate static let nameMost: CGFloat = 76
    private static let most = 5
    private static let font = NSFont.systemFont(ofSize: 11.5, weight: .medium)

    /// Past this many, the capsule would crowd the doors beside it out of a
    /// column of the usual width.
    static func fits(_ spaces: [Space]) -> Bool { spaces.count <= most }

    /// How wide it is drawn, added up rather than measured, for the foot to
    /// know what room is left beside it (see SideFoot.room).
    static func width(_ spaces: [Space], live: Space) -> CGFloat {
        let name = min(nameMost, ceil((live.name as NSString).size(withAttributes: [.font: font]).width))
        let others = CGFloat(max(0, spaces.count - 1))
        return 6 + others * (slot + 1) + 7 + 13 + 5 + name + 8
    }

    var body: some View {
        let dark = scheme == .dark
        HStack(spacing: 1) {
            ForEach(Array(browser.spaces.enumerated()), id: \.element.id) { index, space in
                Bead(space: space, number: index + 1,
                     live: space.id == browser.spaceID && !browser.makingSpace, lamp: lamp) {
                    if space.id == browser.spaceID {
                        SpaceMenu.show(for: browser)
                    } else {
                        browser.switchSpace(to: space.id)
                    }
                }
            }
        }
        .padding(3)
        .background {
            // Raised from the frame: lighter than it, the light on its top
            // half and along its top edge, its shadow under it.
            Capsule(style: .continuous)
                .fill(Color.white.opacity(dark ? 0.10 : 0.5))
                .overlay {
                    Capsule(style: .continuous)
                        .fill(LinearGradient(colors: [.white.opacity(dark ? 0.10 : 0.6), .white.opacity(0)],
                                             startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.46)))
                }
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(LinearGradient(colors: [.white.opacity(dark ? 0.26 : 0.95), .white.opacity(dark ? 0.08 : 0.6)],
                                                     startPoint: .top, endPoint: .bottom), lineWidth: 0.75)
                }
                .shadow(color: .black.opacity(dark ? 0.45 : 0.16), radius: 6, y: 4)
                .shadow(color: .black.opacity(dark ? 0.35 : 0.08), radius: 1, y: 1)
        }
        .overlay { RightClick { SpaceMenu.menu(for: browser) } }
        .animation(Motion.glide, value: browser.spaceID)
        .animation(Motion.glide, value: browser.makingSpace)
        .animation(Motion.settle, value: browser.spaces)
    }
}

/// One space in the capsule.
private struct Bead: View {
    @Environment(\.greys) private var greys
    @Environment(\.colorScheme) private var scheme
    let space: Space
    /// Its place among them, which is its key: ⌃1–⌃9.
    let number: Int
    let live: Bool
    let lamp: Namespace.ID
    let act: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: act) {
            HStack(spacing: 5) {
                Image(systemName: space.symbol)
                    .font(.system(size: 10.5, weight: .semibold))
                    .frame(width: 13, height: 13)
                    // The one place the theme's colour is said outright,
                    // and only as much of it as an icon holds.
                    .foregroundStyle(live ? space.light.lit(dark: scheme == .dark).accent
                                     : hovering ? Palette.ink : greys.quiet)
                if live {
                    Text(space.name)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .frame(maxWidth: SpaceSwitcher.nameMost)
                        .fixedSize(horizontal: true, vertical: false)
                        .transition(.opacity)
                }
            }
            .padding(.leading, live ? 7 : 0)
            .padding(.trailing, live ? 8 : 0)
            .frame(minWidth: SpaceSwitcher.slot)
            .frame(height: SpaceSwitcher.bead)
            .background {
                if live {
                    lit.matchedGeometryEffect(id: "lamp", in: lamp)
                } else if hovering {
                    Capsule(style: .continuous).fill(greys.hover)
                }
            }
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(number <= 9 ? "\(space.name)   ⌃\(number)" : space.name)
        .animation(Motion.quick, value: hovering)
    }

    /// The space you are in: a lit piece of the glass, as the tab you are
    /// on is (see Lozenge), and no more than that. It was the theme's two
    /// colours at full strength with a glow of its own once, and was the
    /// loudest thing in a frame where nothing else raises its voice (said
    /// so, 9 Nov 2026). The frame already says which space this is.
    private var lit: some View {
        let dark = scheme == .dark
        return Capsule(style: .continuous)
            .fill(Color.white.opacity(dark ? 0.16 : 0.84))
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(dark ? 0.26 : 1), .white.opacity(dark ? 0.06 : 0.6)],
                                                 startPoint: .top, endPoint: .bottom), lineWidth: 0.75)
            }
            .shadow(color: .black.opacity(dark ? 0.3 : 0.12), radius: 2.5, y: 1)
    }
}

extension Theme {
    /// The theme as a small disc, for a menu.
    var swatch: NSImage {
        let colours = lit(dark: false).disc
        return NSImage(size: NSSize(width: 14, height: 14), flipped: false) { rect in
            let disc = NSBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5))
            NSGradient(starting: NSColor(colours.0), ending: NSColor(colours.1))?.draw(in: disc, angle: -45)
            return true
        }
    }
}

/// The themes as a row of discs, the one the space wears ringed and named:
/// Settings › Appearance, for the space on screen. A space's menu has the
/// same list (see SpaceMenu).
struct ThemeSwatches: View {
    @ObservedObject var browser: Browser

    var body: some View {
        let here = browser.space
        HStack(spacing: 8) {
            ForEach(Theme.all) { theme in
                let on = here.light == theme
                let colours = theme.lit(dark: false).disc
                Button {
                    withAnimation(Motion.settle) { browser.setSpaceTheme(here.id, to: theme) }
                } label: {
                    Circle()
                        .fill(LinearGradient(colors: [colours.0, colours.1],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 22, height: 22)
                        .padding(4)
                        .overlay(Circle().strokeBorder(on ? Palette.ink : .clear, lineWidth: 2))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help(theme.name)
                .accessibilityLabel(theme.name)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
            Text(here.light.name)
                .font(.system(size: 12))
                .foregroundStyle(Palette.muted)
                .padding(.leading, 6)
        }
    }
}
