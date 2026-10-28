import SwiftUI

// MARK: - MainTabView
// Thanh điều hướng chính của ứng dụng Zev

struct MainTabView: View {
    @State private var selectedTab: Int = 0
    
    init() {
        // Tuỳ biến giao diện TabBar UIKit
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
            HomeView()
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                    Text("Trang chủ")
                }
                .tag(0)
            
            GameListView()
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "gamecontroller.fill" : "gamecontroller")
                    Text("Game & Mod")
                }
                .tag(1)
            
            FileDownloadView()
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "arrow.down.circle.fill" : "arrow.down.circle")
                    Text("Tải File")
                }
                .tag(2)
            
            ProfileView()
                .tabItem {
                    Image(systemName: selectedTab == 3 ? "person.crop.circle.fill" : "person.crop.circle")
                    Text("Tài khoản")
                }
                .tag(3)
        }
        .accentColor(ZevTheme.Colors.primary)
    }
}
