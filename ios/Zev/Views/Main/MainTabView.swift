import SwiftUI

// MARK: - MainTabView
// Gồm 2 tab chính: Main (icon ngôi nhà) và Cá nhân (icon con người)

struct MainTabView: View {
    @State private var selectedTab: Int = 0
    
    init() {
        // Tuỳ biến giao diện TabBar UIKit chuẩn Dark Mode
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color(hex: "#111218"))
        
        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.iconColor = UIColor(Color(hex: "#8B91A8"))
        itemAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(Color(hex: "#8B91A8"))]
        
        itemAppearance.selected.iconColor = UIColor(Color(hex: "#6C63FF"))
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(Color(hex: "#6C63FF"))]
        
        appearance.stackedLayoutAppearance = itemAppearance
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Main (icon ngôi nhà)
            GameMainView()
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                    Text("Main")
                }
                .tag(0)
            
            // Tab 2: Cá nhân (icon con người)
            ProfileView()
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "person.fill" : "person")
                    Text("Cá nhân")
                }
                .tag(1)
        }
        .accentColor(ZevTheme.Colors.primary)
    }
}
