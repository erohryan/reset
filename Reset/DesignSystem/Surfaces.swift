import SwiftUI

/// Cream graph paper with a 20pt grid. On resting screens it's Soft with an ink grid at 6%.
struct GraphPaper: View {
    var base: Color = Theme.paper
    var line: Color = Theme.gridLine
    var spacing: CGFloat = 20

    var body: some View {
        Canvas { context, size in
            var path = Path()
            for x in stride(from: 0, through: size.width, by: spacing) {
                path.addRect(CGRect(x: x, y: 0, width: 1, height: size.height))
            }
            for y in stride(from: 0, through: size.height, by: spacing) {
                path.addRect(CGRect(x: 0, y: y, width: size.width, height: 1))
            }
            context.fill(path, with: .color(line))
        }
        .background(base)
        .ignoresSafeArea()
    }

    static func resting(_ casing: Casing) -> GraphPaper {
        GraphPaper(base: casing.soft.color, line: Theme.ink.opacity(0.06))
    }
}

/// The Lab Notebook surface: fill, 1.5pt ink outline and a hard offset shadow with no blur.
struct InkSurface<S: InsettableShape>: ViewModifier {
    var shape: S
    var fill: Color = Theme.paper
    var shadow: CGFloat = 0
    var stroke: Color = Theme.ink
    var dashed = false

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    if shadow > 0 { shape.fill(Theme.ink).offset(y: shadow) }
                    shape.fill(fill)
                }
            }
            .overlay {
                shape.strokeBorder(stroke, style: StrokeStyle(lineWidth: Theme.border, dash: dashed ? [4, 3] : []))
            }
    }
}

extension View {
    func inkSurface<S: InsettableShape>(
        _ shape: S,
        fill: Color = Theme.paper,
        shadow: CGFloat = 0,
        stroke: Color = Theme.ink,
        dashed: Bool = false
    ) -> some View {
        modifier(InkSurface(shape: shape, fill: fill, shadow: shadow, stroke: stroke, dashed: dashed))
    }

    func inkCard(radius: CGFloat = Theme.Radius.card, fill: Color = Theme.paper) -> some View {
        inkSurface(RoundedRectangle(cornerRadius: radius, style: .continuous), fill: fill)
    }

    /// Every screen enters with opacity 0→1 and a 6pt rise over 350ms.
    func screenTransition() -> some View {
        transition(.opacity.combined(with: .offset(y: 6)).animation(Theme.screenIn))
    }
}

/// Standard screen frame: graph paper behind, design padding, vertical stack.
struct ScreenFrame<Content: View>: View {
    var resting = false
    var spacing: CGFloat = Theme.Screen.gap
    @ViewBuilder var content: Content
    @Environment(\.casing) private var casing

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, Theme.Screen.top)
        .padding(.horizontal, Theme.Screen.sides)
        .padding(.bottom, Theme.Screen.bottom)
        .background {
            if resting { GraphPaper.resting(casing) } else { GraphPaper() }
        }
        .foregroundStyle(Theme.ink)
    }
}
