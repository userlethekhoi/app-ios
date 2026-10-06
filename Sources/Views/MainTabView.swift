import SwiftUI

public struct MainTabView: View {
    @State private var selectedTab: AppTab = .explore

    public init() {
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.backgroundColor = UIColor(Color.iappayBackground)
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
    }

    public var body: some View {
        ZStack {
            Color.iappayBackground.ignoresSafeArea()
            content
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomTabBar(selection: $selectedTab)
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .explore:
            ExploreStoreView()
        case .installed:
            InstalledView()
        case .library:
            LibraryView()
        case .settings:
            SettingsView()
        }
    }
}

private enum AppTab: Int, CaseIterable, Identifiable {
    case explore, installed, library, settings

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .explore: return "Khám phá"
        case .installed: return "Đã cài đặt"
        case .library: return "Thư viện"
        case .settings: return "Cài đặt"
        }
    }

    var glyph: AppGlyph {
        switch self {
        case .explore: return .compass
        case .installed: return .layers
        case .library: return .folder
        case .settings: return .settings
        }
    }
}

private struct BottomTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.iappayBorder)
                .frame(height: 0.5)
            HStack(spacing: 0) {
                ForEach(AppTab.allCases) { tab in
                    Button { selection = tab } label: {
                        VStack(spacing: 3) {
                            GlyphView(tab.glyph, size: 22, color: selection == tab ? .iappayAccent : .iappayTextMuted)
                            Text(tab.title)
                                .font(.system(size: 10, weight: selection == tab ? .semibold : .regular))
                        }
                        .foregroundColor(selection == tab ? .iappayAccent : .iappayTextMuted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 49)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color.iappaySurface.opacity(0.98))
        }
    }
}
