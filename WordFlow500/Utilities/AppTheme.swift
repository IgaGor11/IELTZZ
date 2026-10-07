import SwiftUI

enum AppTheme {
    static let tint = Color.indigo
    static let success = Color.green
    static let error = Color.red

    static var background: Color {
        Color(uiColor: .systemGroupedBackground)
    }

    static var secondaryBackground: Color {
        Color(uiColor: .secondarySystemGroupedBackground)
    }
}

struct AppBackground: View {
    var body: some View {
        ZStack {
            AppTheme.background
            Circle()
                .fill(Color.indigo.opacity(0.18))
                .frame(width: 340, height: 340)
                .blur(radius: 60)
                .offset(x: -180, y: -260)
            Circle()
                .fill(Color.cyan.opacity(0.13))
                .frame(width: 300, height: 300)
                .blur(radius: 70)
                .offset(x: 190, y: 300)
        }
        .ignoresSafeArea()
    }
}

private struct GlassCardModifier: ViewModifier {
    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.08), radius: 18, y: 8)
    }
}

extension View {
    func glassCard(padding: CGFloat = 20) -> some View {
        modifier(GlassCardModifier(padding: padding))
    }
}

