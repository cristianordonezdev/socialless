import SwiftUI

enum Theme {
    static let accent = Color("AccentColor")
    static let background = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 24))
    }
}

struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.headline).frame(maxWidth: .infinity, minHeight: 48)
        }.buttonStyle(.borderedProminent).buttonBorderShape(.roundedRectangle(radius: 16))
    }
}

struct PlatformMark: View {
    let platform: SocialPlatform
    var body: some View {
        Image(systemName: platform.symbol).font(.system(size: 24))
            .frame(width: 52, height: 52)
            .foregroundStyle(Theme.accent)
            .background(Theme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
            .accessibilityHidden(true)
    }
}

struct Footnote: View {
    let text: String
    var body: some View {
        Text(text).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }
}

