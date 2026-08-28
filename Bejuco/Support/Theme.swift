import SwiftUI

extension Color {
    static let bejucoGreen = Color(red: 0.06, green: 0.31, blue: 0.23)
    static let bejucoLeaf = Color(red: 0.18, green: 0.55, blue: 0.36)
    static let bejucoSand = Color(red: 0.97, green: 0.95, blue: 0.89)
    static let bejucoAlert = Color(red: 0.78, green: 0.18, blue: 0.12)
}

struct BejucoCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
    }
}

struct StatusDot: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 9, height: 9)
    }
}

