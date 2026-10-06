import FamilyControls
import ManagedSettings
import SwiftUI

/// A 52pt app tile. Awake: ink border on paper. Napping: dashed muted border, faded
/// glyph and a "z" badge. Real apps render through Apple's `Label(token)`, which shows
/// the real icon and name without reset ever learning which app it is.
struct AppTile: View {
    var item: NapItem
    var napping = false
    /// Switched off on the home screen: stays awake on the next rest.
    var isOff = false
    var size: CGFloat = 52
    var radius: CGFloat = Theme.Radius.tile
    var showsName = true

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                glyph
                    .frame(width: size, height: size)
                    .inkSurface(
                        RoundedRectangle(cornerRadius: radius, style: .continuous),
                        fill: napping ? Theme.paper.opacity(0.6) : Theme.paper,
                        stroke: napping ? Theme.muted : Theme.ink,
                        dashed: napping
                    )
                if napping {
                    Text("z")
                        .font(RFont.display(14))
                        .padding(.vertical, 2)
                        .padding(.horizontal, 5)
                        .inkSurface(Capsule())
                        .offset(x: 7, y: -7)
                }
            }
            if showsName {
                name
                    .font(RFont.body(11))
                    .foregroundStyle(napping || isOff ? Theme.subtle : Theme.body)
                    .lineLimit(1)
            }
        }
        .opacity(isOff ? 0.35 : 1)
        .overlay(alignment: .topLeading) {
            if isOff {
                Text("awake")
                    .font(RFont.mono(9))
                    .padding(.vertical, 2)
                    .padding(.horizontal, 5)
                    .inkSurface(Capsule())
                    .offset(x: -4, y: -7)
            }
        }
        .animation(.easeOut(duration: 0.2), value: isOff)
        .accessibilityValue(isOff ? "stays awake" : (napping ? "napping" : "will nap"))
    }

    @ViewBuilder private var glyph: some View {
        switch item {
        case .demo(let app):
            Text(app.initial)
                .font(RFont.mono(size * 0.27, .medium))
                .foregroundStyle(napping ? Theme.nappingGlyph : Theme.subtle)
        case .app(let token):
            Label(token).labelStyle(.iconOnly).scaleEffect(size / 40).opacity(napping ? 0.45 : 1)
        case .category(let token):
            Label(token).labelStyle(.iconOnly).scaleEffect(size / 40).opacity(napping ? 0.45 : 1)
        case .web(let token):
            Label(token).labelStyle(.iconOnly).scaleEffect(size / 40).opacity(napping ? 0.45 : 1)
        }
    }

    @ViewBuilder private var name: some View {
        switch item {
        case .demo(let app): Text(app.name)
        case .app(let token): Label(token).labelStyle(.titleOnly)
        case .category(let token): Label(token).labelStyle(.titleOnly)
        case .web(let token): Label(token).labelStyle(.titleOnly)
        }
    }
}

/// The 4-column grid of chosen apps on Ready and Resting.
struct AppGrid: View {
    var items: [NapItem]
    var napping = false
    var isOff: (NapItem) -> Bool = { _ in false }
    var onTap: ((NapItem) -> Void)?

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
            ForEach(items) { item in
                AppTile(item: item, napping: napping, isOff: isOff(item))
                    .contentShape(Rectangle())
                    .onTapGesture { onTap?(item) }
            }
        }
    }
}
