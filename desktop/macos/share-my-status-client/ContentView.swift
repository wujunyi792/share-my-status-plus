//
//  ContentView.swift
//  share-my-status-client
//

import SwiftUI

/// Main content view with tabs
struct ContentView: View {
    @EnvironmentObject var configuration: AppConfiguration
    @EnvironmentObject var reporter: StatusReporter
    
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            StatusTabView()
                .tabItem {
                    Label("状态", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(0)
            
            SettingsTabView()
                .tabItem {
                    Label("设置", systemImage: "gear")
                }
                .tag(1)
        }
        .frame(minWidth: 650, idealWidth: 750, maxWidth: .infinity,
               minHeight: 550, idealHeight: 600, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppConfiguration())
        .environmentObject(StatusReporter())
}
